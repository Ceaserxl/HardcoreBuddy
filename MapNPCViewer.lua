local _,A=...
local M,Skin=A.MapAdvisor,A.Skin
local DEFAULT_DISTANCE,MAX_ATTEMPTS,RETRY_SECONDS=1.8,3,3

local function finite(value)
    return type(value)=="number" and value==value and math.abs(value)<math.huge
end
local function readBounds(actor)
    -- Classic Era returns six scalars; newer API documentation describes two
    -- vectors. Normalize both shapes before using any coordinates.
    local minX,minY,minZ,maxX,maxY,maxZ=actor:GetMaxBoundingBox()
    if type(minX)=="table" or type(minX)=="userdata" then
        local bottom,top=minX,minY
        if type(top)~="table" and type(top)~="userdata" then return end
        minX,minY,minZ,maxX,maxY,maxZ=bottom.x,bottom.y,bottom.z,top.x,top.y,top.z
    end
    if not (finite(minX) and finite(minY) and finite(minZ) and finite(maxX) and finite(maxY) and finite(maxZ)) then return end
    local dx,dy,dz=maxX-minX,maxY-minY,maxZ-minZ
    if dx<0 or dy<0 or dz<0 then return end
    local radius=math.sqrt(dx*dx+dy*dy+dz*dz)/2
    if not finite(radius) or radius<=0 then return end
    return {x=(minX+maxX)/2,y=(minY+maxY)/2,z=(minZ+maxZ)/2,radius=radius}
end

function M:OpenNPCs(cluster)
    if not cluster then return end
    local ids,seen={},{}
    for _,record in ipairs(cluster.records or {}) do
        if A.Data.MapNPCs[record.id] and not seen[record.id] then ids[#ids+1]=record.id; seen[record.id]=true end
    end
    if #ids==0 then return end
    A:CreateWindow(); A:CommitInputs()
    A.history=A.history or {}; A.history[#A.history+1]=A.state
    A.state={view="training",filter="Zone Advisor",mapNPCs=ids,mapNPCPage=1}
    GameTooltip:Hide()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        if HideUIPanel then HideUIPanel(WorldMapFrame) else WorldMapFrame:Hide() end
    end
    A.window:Show(); A:Refresh(true)
end

local function createViewer(parent)
    local f=CreateFrame("Frame",nil,parent)
    f.info=CreateFrame("Frame",nil,f,"BackdropTemplate"); Skin.Paint(f.info,"card")
    f.info:SetPoint("TOPLEFT"); f.info:SetSize(296,416)
    f.modelBorder=CreateFrame("Frame",nil,f,"BackdropTemplate"); Skin.Paint(f.modelBorder,"card")
    f.modelBorder:SetPoint("TOPLEFT",296+Skin.layout.columnGap,0)
    local function label(y,size,height)
        local t=f.info:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        t:SetFont(STANDARD_TEXT_FONT,size,""); t:SetPoint("TOPLEFT",16,-y)
        t:SetWidth(264); t:SetHeight(height); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
        return t
    end
    f.title=label(16,22,48); Skin.TextStyle(f.title,"page")
    f.details=label(72,12,32)
    f.note=label(116,12,92)
    f.paging=label(222,12,20)
    f.help=label(342,12,58)
    f.help:SetText("Drag to rotate. Scroll to zoom.\nUse Reset view to re-center.")
    Skin.TextStyle(f.details,"subtitle"); Skin.TextStyle(f.note,"subtitle"); Skin.TextStyle(f.help,"subtitle")
    -- Resolve NPC -> creature display through the native PlayerModel, then use
    -- a ModelScene actor's actual bounds instead of creature portrait cameras.
    local scene=CreateFrame("ModelScene",nil,f.modelBorder); f.scene=scene
    scene:SetPoint("TOPLEFT",1,-1); scene:SetPoint("BOTTOMRIGHT",-1,1)
    scene:SetCameraFieldOfView(math.rad(35)); scene:SetCameraNearClip(0.01); scene:SetCameraFarClip(100)
    scene:SetCameraOrientationByAxisVectors(-1,0,0,0,-1,0,0,0,1)
    scene:SetLightVisible(true); scene:SetLightAmbientColor(0.7,0.7,0.7)
    scene:SetLightDiffuseColor(0.8,0.8,0.8); scene:SetLightDirection(-1,0,-1)
    local actor=scene:CreateActor(); f.actor=actor
    local model=CreateFrame("PlayerModel",nil,f.modelBorder); f.model=model
    model:SetPoint("CENTER"); model:SetSize(1,1); model:SetAlpha(0); model:EnableMouse(false)
    f.status=CreateFrame("Frame",nil,f.modelBorder)
    f.status:SetAllPoints(); f.status:SetFrameLevel(scene:GetFrameLevel()+5)
    f.loading=f.status:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f.loading:SetFont(STANDARD_TEXT_FONT,16,""); f.loading:SetPoint("CENTER",0,12)
    f.loading:SetSize(300,42); f.loading:SetJustifyH("CENTER")
    f.dots={}
    for i=1,3 do
        local dot=f.status:CreateTexture(nil,"ARTWORK")
        dot:SetTexture("Interface\\Buttons\\WHITE8x8"); dot:SetVertexColor(unpack(Skin.colors.gold))
        dot:SetSize(8,8); dot:SetPoint("CENTER",(i-2)*20,-24); f.dots[i]=dot
    end

    function f:Status(state)
        self.modelState=state; self.status:SetShown(state~="loaded")
        self.retry:SetShown(state=="failed"); self.reset:SetShown(state=="loaded"); self.help:SetShown(state=="loaded")
        self.loading:SetText(state=="failed" and "Model unavailable" or "Loading Model....")
        for _,dot in ipairs(self.dots) do dot:SetShown(state=="loading") end
    end

    function f:ApplyCamera()
        local bounds=self.bounds; if not bounds then return end
        local facing=self.facing or 0.35
        local c,s=math.cos(facing),math.sin(facing)
        actor:SetScale(1/bounds.radius); actor:SetYaw(facing)
        actor:SetPosition((-bounds.x*c+bounds.y*s)/bounds.radius,(-bounds.x*s-bounds.y*c)/bounds.radius,-bounds.z/bounds.radius)
        local aspect=math.max(0.1,scene:GetWidth()/math.max(1,scene:GetHeight()))
        local half=math.atan(math.tan(math.rad(35)/2)*math.min(1,aspect))
        local distance=1.08/math.sin(half)*(self.distance or DEFAULT_DISTANCE)/DEFAULT_DISTANCE
        scene:SetCameraPosition(distance,0,0)
        self.cameraDistance=distance
    end
    function f:FailModel(reason)
        self.modelError=tostring(reason or "Model unavailable")
        self.waiting=nil; self.settle=nil; self.dragging=nil; self.bounds=nil
        actor:SetShown(false)
        self:Status("failed")
    end
    function f:UpdateCamera()
        local ok,reason=pcall(self.ApplyCamera,self)
        if not ok then self:FailModel(reason) end
        return ok
    end
    function f:Loaded()
        if not self:IsVisible() or not self.npcID or not self.waiting then return end
        local id=model:GetModelFileID()
        if not id or id<=0 then return end
        local display=model:GetDisplayInfo()
        if not display or display<=0 then return end
        if self.requestedDisplay~=display then
            self.requestedDisplay=display
            local ok,result=pcall(actor.SetModelByCreatureDisplayID,actor,display)
            -- Do not restart a failed/uncached display on every rendered frame.
            -- The existing three-second retry timer owns subsequent requests.
            if not ok or result==false then return end
        end
        local actorFile=actor:GetModelFileID()
        if not actorFile or actorFile<=0 then return end
        if self.boundsReadFailed then return end
        local ok,bounds=pcall(readBounds,actor)
        if not ok then self.boundsReadFailed=true; self.modelError=tostring(bounds); return end
        if not bounds then return end
        self.bounds=bounds
        self.waiting=nil; self.settle=0; self.settlePass=0
        if not self:UpdateCamera() then return end
        actor:SetShown(true)
        self:Status("loaded")
    end
    function f:RequestModel(reset)
        if not self:IsVisible() or not self.npcID then return end
        if reset then self.attempts=0 end
        self.attempts=(self.attempts or 0)+1
        self.waiting=0; self.animationTime=0; self.settle=nil; self.dragging=nil; self.boundsPoll=0
        self.boundsReadFailed=nil; self.modelError=nil
        self.requestedDisplay=nil; self.bounds=nil; actor:SetShown(false); actor:ClearModel()
        actor:SetScale(1); actor:SetPosition(0,0,0); actor:SetYaw(0)
        model:ClearModel()
        self:Status("loading")
        -- Missing or uncached creature displays can throw or return no model.
        -- Both cases follow the same bounded retry schedule.
        pcall(model.SetCreature,model,self.npcID)
    end
    model:SetScript("OnModelLoaded",function() f:Loaded() end)
    scene:EnableMouse(true); scene:EnableMouseWheel(true)
    scene:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then f.dragging=GetCursorPosition(); f.settle=nil end
    end)
    scene:SetScript("OnMouseUp",function() f.dragging=nil end)
    scene:SetScript("OnMouseWheel",function(_,delta)
        f.settle=nil
        f.distance=math.max(0.5,math.min(8,(f.distance or DEFAULT_DISTANCE)-delta*0.15))
        f:UpdateCamera()
    end)
    model:SetScript("OnUpdate",function(_,elapsed)
        if not f:IsVisible() or not f.npcID then return end
        if f.dragging then
            local x=GetCursorPosition(); f.facing=(f.facing or 0.35)+(x-f.dragging)*0.015; f.dragging=x; f:UpdateCamera()
        end
        if f.waiting then
            f.waiting=f.waiting+elapsed
            f.animationTime=(f.animationTime or 0)+elapsed
            for i,dot in ipairs(f.dots) do dot:SetAlpha(0.25+0.75*(0.5+0.5*math.sin(f.animationTime*5-(i-1)*1.2))) end
            f.boundsPoll=(f.boundsPoll or 0)+elapsed
            if f.boundsPoll>=0.1 then f.boundsPoll=0; f:Loaded() end
            if f.waiting and f.waiting>=RETRY_SECONDS then
                if f.attempts<MAX_ATTEMPTS then f:RequestModel()
                else
                    model:ClearModel(); f:FailModel(f.modelError)
                end
            end
        elseif f.settle then
            f.settle=f.settle+elapsed
            if f.settle>=0.5 or f.settle>=0.15 and f.settlePass==0 then
                if not f:UpdateCamera() then return end
                f.settlePass=1
                if f.settle>=0.5 then f.settle=nil end
            end
        end
    end)
    local function button(text,x,y,click)
        local b=CreateFrame("Button",nil,f.info,"BackdropTemplate")
        b:SetPoint("TOPLEFT",x,-y); b:SetSize(126,30); Skin.Button(b,"utility")
        b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(text)
        b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
        b:SetScript("OnClick",click); return b
    end
    f.previous=button("Previous NPC",16,252,function() A.state.mapNPCPage=A.state.mapNPCPage-1; A:Refresh(true) end)
    f.next=button("Next NPC",154,252,function() A.state.mapNPCPage=A.state.mapNPCPage+1; A:Refresh(true) end)
    f.retry=button("Retry Model",16,298,function() f:RequestModel(true) end)
    f.retry:SetParent(f.status); f.retry:ClearAllPoints(); f.retry:SetPoint("CENTER",0,-36); f.retry:Hide()
    f.reset=button("Reset view",154,298,function()
        f.distance=DEFAULT_DISTANCE; f.facing=0.35; f.dragging=nil
        if f:UpdateCamera() then f.settle=0; f.settlePass=0 end
    end)
    f:SetScript("OnHide",function()
        f.dragging=nil; f.waiting=nil; f.settle=nil; f.npcID=nil; model:ClearModel(); actor:SetShown(false); actor:ClearModel()
    end)
    return f
end

function M:LayoutViewer(parent,width,visible,height)
    visible=visible and A.state.mapNPCs~=nil
    if not self.viewer and not visible then return 0 end
    if not self.viewer then self.viewer=createViewer(parent) end
    local f=self.viewer; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/728,(height or 416)/416)
    local frameHeight=(height or 416)/scale
    f:SetScale(scale); f:SetSize(width/scale,frameHeight)
    f.info:SetHeight(frameHeight); f.modelBorder:SetSize(width/scale-296-Skin.layout.columnGap,frameHeight)
    f.scene:SetSize(f.modelBorder:GetWidth()-2,frameHeight-2)
    if f.bounds then f:UpdateCamera() end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    local ids=A.state.mapNPCs
    local index=math.max(1,math.min(#ids,A.state.mapNPCPage or 1)); A.state.mapNPCPage=index
    local id=ids[index]; local npc=A.Data.MapNPCs[id]
    f.title:SetText(npc.name)
    f.details:SetText("Level "..(npc.min or "?")..(npc.max and npc.max~=npc.min and ("-"..npc.max) or "").." | "..self:IconLabel(npc.kind))
    f.note:SetText(npc.note or "Recorded spawn area; this is a model preview, not a live sighting.")
    f.paging:SetText("NPC "..index.." of "..#ids)
    -- Fit the text to its content instead of reserving large empty text boxes.
    local y=16
    for _,entry in ipairs({{f.title,Skin.layout.titleGap},{f.details,Skin.layout.contentGap},
        {f.note,Skin.layout.sectionGap},{f.paging,Skin.layout.contentGap}}) do
        local text,gap=entry[1],entry[2]
        text:ClearAllPoints(); text:SetPoint("TOPLEFT",f.info,"TOPLEFT",16,-y)
        text:SetHeight(0); local h=text:GetStringHeight(); text:SetHeight(h)
        y=y+h+gap
    end
    f.previous:ClearAllPoints(); f.previous:SetPoint("TOPLEFT",16,-y)
    f.next:ClearAllPoints(); f.next:SetPoint("TOPLEFT",150,-y)
    y=y+30+Skin.layout.sectionGap
    f.reset:ClearAllPoints(); f.reset:SetPoint("TOPLEFT",150,-y)
    f.help:ClearAllPoints(); f.help:SetPoint("TOPLEFT",16,-y-30-Skin.layout.contentGap)
    f.previous:SetEnabled(index>1); f.next:SetEnabled(index<#ids)
    if f.npcID~=id then
        f.npcID=id; f.distance=DEFAULT_DISTANCE; f.facing=0.35
        f:RequestModel(true)
    end
    return frameHeight*scale
end
