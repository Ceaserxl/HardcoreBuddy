local _,A=...
local M,Skin=A.MapAdvisor,A.Skin

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

function M:LayoutViewer(parent,width,visible)
    visible=visible and A.state.mapNPCs~=nil
    if not self.viewer and not visible then return 0 end
    if not self.viewer then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.viewer=f; Skin.Paint(f,"card")
        local function label(y,size)
            local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); t:SetFont(STANDARD_TEXT_FONT,size,"")
            t:SetPoint("TOPLEFT",16,-y); t:SetWidth(680); t:SetJustifyH("LEFT"); return t
        end
        f.title=label(14,18); f.title:SetTextColor(unpack(Skin.colors.gold))
        f.details=label(43,12); f.note=label(67,12)
        f.loading=label(143,12)
        local model=CreateFrame("PlayerModel",nil,f); f.model=model
        -- A wide, shallow viewport crops the native full-body camera vertically.
        model:SetPoint("TOP",f,"TOP",0,-166); model:SetSize(224,224)
        local function camera(self)
            self:SetPortraitZoom(0)
            self:SetCamDistanceScale(f.distance or 1.4)
            self:SetPosition(0,0,0)
            self:SetFacing(f.facing or 0.35)
            self:RefreshCamera()
        end
        model:SetScript("OnModelLoaded",function(self)
            if not f:IsShown() then return end
            f.loading:SetText("Drag to rotate. Use the mouse wheel to zoom.")
            camera(self)
        end)
        model:EnableMouse(true); model:EnableMouseWheel(true)
        model:SetScript("OnMouseDown",function(_,button) if button=="LeftButton" then f.dragging=GetCursorPosition() end end)
        model:SetScript("OnMouseUp",function() f.dragging=nil end)
        model:SetScript("OnMouseWheel",function(self,delta)
            f.distance=math.max(0.5,math.min(4,(f.distance or 1.4)-delta*0.15)); camera(self)
        end)
        model:SetScript("OnUpdate",function(self,elapsed)
            if f.dragging then
                local x=GetCursorPosition(); f.facing=(f.facing or 0.35)+(x-f.dragging)*0.015; f.dragging=x; self:SetFacing(f.facing)
            end
            if f.waiting then
                f.waiting=f.waiting+elapsed
                local id=self.GetModelFileID and self:GetModelFileID()
                if id and id>0 then f.waiting=nil; camera(self); f.loading:SetText("Drag to rotate. Use the mouse wheel to zoom.")
                elseif f.waiting>5 then f.waiting=nil; f.loading:SetText("Model unavailable from the client. Use Retry to request it again.") end
            end
        end)
        local function button(text,x,click)
            local b=CreateFrame("Button",nil,f,"BackdropTemplate"); b:SetPoint("TOPLEFT",x,-104); b:SetSize(140,28); Skin.Button(b,"utility")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(text)
            b:SetScript("OnClick",click); return b
        end
        f.previous=button("Previous NPC",16,function() A.state.mapNPCPage=A.state.mapNPCPage-1; A:Refresh(true) end)
        f.next=button("Next NPC",172,function() A.state.mapNPCPage=A.state.mapNPCPage+1; A:Refresh(true) end)
        f.retry=button("Retry model",556,function() f.npcID=nil; A:Refresh() end)
        f.paging=label(111,12); f.paging:ClearAllPoints(); f.paging:SetPoint("TOPLEFT",330,-111); f.paging:SetWidth(220)
        f:SetScript("OnHide",function() f.dragging=nil; f.waiting=nil; f.npcID=nil; model:ClearModel() end)
    end
    local f=self.viewer; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/728); f:SetScale(scale); f:SetSize(width/scale,406)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",0,0)
    local ids=A.state.mapNPCs
    local index=math.max(1,math.min(#ids,A.state.mapNPCPage or 1)); A.state.mapNPCPage=index
    local id=ids[index]; local npc=A.Data.MapNPCs[id]
    f.title:SetText(npc.name)
    f.details:SetText("Level "..(npc.min or "?")..(npc.max and npc.max~=npc.min and ("-"..npc.max) or "").." | "..self:IconLabel(npc.kind))
    f.note:SetText(npc.note or "Recorded spawn area; this is a model preview, not a live sighting.")
    f.paging:SetText("NPC "..index.." of "..#ids.." in this marker")
    f.previous:SetEnabled(index>1); f.next:SetEnabled(index<#ids)
    if f.npcID~=id then
        f.npcID=id; f.distance=1.4; f.facing=0.35; f.waiting=0
        f.model:ClearModel(); f.loading:SetText("Loading NPC model...")
        f.model:SetPortraitZoom(0); f.model:SetFacing(f.facing)
        local ok=pcall(f.model.SetCreature,f.model,id)
        if not ok then f.waiting=nil; f.loading:SetText("Model unavailable from the client. Use Retry to request it again.") end
    end
    return 416*scale
end
