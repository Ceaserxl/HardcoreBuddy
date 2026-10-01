local _,A=...
local M,Skin=A.MapAdvisor,A.Skin
local DEFAULT_DISTANCE,MAX_ATTEMPTS,RETRY_SECONDS=1.8,3,3

function M:OpenNPCs(cluster)
    if not cluster then return end
    local ids,seen={},{}
    for _,record in ipairs(cluster.records or {}) do
        if A.Data.MapNPCs[record.id] and not seen[record.id] then ids[#ids+1]=record.id; seen[record.id]=true end
    end
    if #ids==0 then return end
    A:CreateWindow(); A:CommitInputs()
    A.history=A.history or {}; A.history[#A.history+1]=A.state
    A.state={view="advisors",filter="Map",mapNPCs=ids,mapNPCPage=1}
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
    f.modelBorder:SetPoint("TOPLEFT",312,0)
    local function label(y,size,height)
        local t=f.info:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        t:SetFont(STANDARD_TEXT_FONT,size,""); t:SetPoint("TOPLEFT",16,-y)
        t:SetWidth(264); t:SetHeight(height); t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
        return t
    end
    f.title=label(16,18,48); f.title:SetTextColor(unpack(Skin.colors.gold))
    f.details=label(72,12,32)
    f.note=label(116,12,92)
    f.paging=label(222,12,20)
    f.help=label(342,12,58)
    f.help:SetText("Drag to rotate. Scroll to zoom.\nUse Reset view to re-center.")
    local model=CreateFrame("PlayerModel",nil,f.modelBorder); f.model=model
    model:SetPoint("CENTER"); model:SetSize(392,392)
    f.status=CreateFrame("Frame",nil,f.modelBorder)
    f.status:SetAllPoints(); f.status:SetFrameLevel(model:GetFrameLevel()+5)
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
        -- Rebuild the native full-body camera before applying user zoom. A second
        -- pass after loading handles models whose camera data arrives later.
        model:SetPosition(0,0,0)
        model:SetModelScale(1)
        model:RefreshCamera()
        model:SetPortraitZoom(0)
        model:SetCamDistanceScale(self.distance or DEFAULT_DISTANCE)
        model:SetFacing(self.facing or 0.35)
    end
    function f:Loaded()
        if not self:IsVisible() or not self.npcID or not self.waiting then return end
        local id=model:GetModelFileID()
        if not id or id<=0 then return end
        self.waiting=nil; self.settle=0; self.settlePass=0
        self:ApplyCamera()
        self:Status("loaded")
    end
    function f:RequestModel(reset)
        if not self:IsVisible() or not self.npcID then return end
        if reset then self.attempts=0 end
        self.attempts=(self.attempts or 0)+1
        self.waiting=0; self.animationTime=0; self.settle=nil; self.dragging=nil
        model:ClearModel()
        self:Status("loading")
        -- Missing or uncached creature displays can throw or return no model.
        -- Both cases follow the same bounded retry schedule.
        pcall(model.SetCreature,model,self.npcID)
    end
    model:SetScript("OnModelLoaded",function() f:Loaded() end)
    model:EnableMouse(true); model:EnableMouseWheel(true)
    model:SetScript("OnMouseDown",function(_,button)
        if button=="LeftButton" then f.dragging=GetCursorPosition(); f.settle=nil end
    end)
    model:SetScript("OnMouseUp",function() f.dragging=nil end)
    model:SetScript("OnMouseWheel",function(_,delta)
        f.settle=nil
        f.distance=math.max(0.5,math.min(8,(f.distance or DEFAULT_DISTANCE)-delta*0.15))
        f:ApplyCamera()
    end)
    model:SetScript("OnUpdate",function(_,elapsed)
        if not f:IsVisible() or not f.npcID then return end
        if f.dragging then
            local x=GetCursorPosition(); f.facing=(f.facing or 0.35)+(x-f.dragging)*0.015; f.dragging=x; model:SetFacing(f.facing)
        end
        if f.waiting then
            f.waiting=f.waiting+elapsed
            f.animationTime=(f.animationTime or 0)+elapsed
            for i,dot in ipairs(f.dots) do dot:SetAlpha(0.25+0.75*(0.5+0.5*math.sin(f.animationTime*5-(i-1)*1.2))) end
            f:Loaded()
            if f.waiting and f.waiting>=RETRY_SECONDS then
                if f.attempts<MAX_ATTEMPTS then f:RequestModel()
                else
                    f.waiting=nil; model:ClearModel()
                    f:Status("failed")
                end
            end
        elseif f.settle then
            f.settle=f.settle+elapsed
            if f.settle>=0.5 or f.settle>=0.15 and f.settlePass==0 then
                f:ApplyCamera(); f.settlePass=1
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
        f:ApplyCamera(); f.settle=0; f.settlePass=0
    end)
    f:SetScript("OnHide",function()
        f.dragging=nil; f.waiting=nil; f.settle=nil; f.npcID=nil; model:ClearModel()
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
    f.info:SetHeight(frameHeight); f.modelBorder:SetSize(width/scale-312,frameHeight)
    local modelSize=math.min(f.modelBorder:GetWidth(),frameHeight)-24
    f.model:SetSize(modelSize,modelSize)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    local ids=A.state.mapNPCs
    local index=math.max(1,math.min(#ids,A.state.mapNPCPage or 1)); A.state.mapNPCPage=index
    local id=ids[index]; local npc=A.Data.MapNPCs[id]
    f.title:SetText(npc.name)
    f.details:SetText("Level "..(npc.min or "?")..(npc.max and npc.max~=npc.min and ("-"..npc.max) or "").." | "..self:IconLabel(npc.kind))
    f.note:SetText(npc.note or "Recorded spawn area; this is a model preview, not a live sighting.")
    f.paging:SetText("NPC "..index.." of "..#ids)
    f.previous:SetEnabled(index>1); f.next:SetEnabled(index<#ids)
    if f.npcID~=id then
        f.npcID=id; f.distance=DEFAULT_DISTANCE; f.facing=0.35
        f:RequestModel(true)
    end
    return frameHeight*scale
end
