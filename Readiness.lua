-- Optional preparation reminders. Unknown stock never becomes a shortage.
local addonName,A=...
local R={}; A.Readiness=R
local function text(parent,size,x,y,width,value)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size,""); f:SetPoint("TOPLEFT",x,y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetWordWrap(true); f:SetText(value or "")
    f:SetShadowColor(0,0,0,1); f:SetShadowOffset(1,-1)
    return f
end
function R:LiveContext()
    local context=A:GetContext()
    local _,token=UnitClass("player")
    local class
    for _,name in ipairs(A.Planner.classes) do if name:upper()==token then class=name; break end end
    if not class then return nil end
    context.characterClass=class
    context.level=UnitLevel("player"); context.characterLevel=context.level; context.mode="live"
    if type(context.level)~="number" or context.level<1 or context.level>60 then return nil end
    context.inventory=A.Inventory.Read()
    return context
end
function R:Missing(context)
    local rows={}
    if not context then return rows end
    for _,record in ipairs(A.Supplies.Build(context,{filter="Essentials"})) do
        if record.tracking and record.missing and record.missing>0 then rows[#rows+1]=record end
    end
    return rows
end
function R:Open()
    A:CreateWindow(); A.db.profile.mode="live"
    A.state={view="supplies",filter="Essentials",page=1}; A.history={}
    A.window:Show(); A:Refresh(true)
end
function R:BuildFrames()
    local f=CreateFrame("Button",nil,UIParent,"BackdropTemplate"); self.panel=f
    f:SetSize(290,180); f:SetPoint("RIGHT",UIParent,"RIGHT",-36,35)
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); A.Skin.Paint(f,"card")
    f.title=text(f,14,12,-12,244,"Missing essentials"); f.title:SetTextColor(unpack(A.Skin.colors.gold))
    f.body=text(f,12,12,-38,264)
    f.hint=text(f,10,12,-151,264,"Click to review carry quantities")
    f:SetScript("OnClick",function() self:Open() end)
    local close=CreateFrame("Button",nil,f,"BackdropTemplate"); f.close=close
    close:SetSize(22,22); close:SetPoint("TOPRIGHT",-6,-6); A.Skin.Button(close,"utility")
    close.label=text(close,12,5,-3,16,"x")
    close:SetScript("OnClick",function() self.dismissed=true; f:Hide() end)
    f:Hide()
    local toast=CreateFrame("Button",nil,UIParent); self.toast=toast
    toast:SetSize(350,52); toast:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-48,-318)
    toast:SetFrameStrata("HIGH"); toast:SetClampedToScreen(true)
    toast.title=text(toast,13,0,-3,350); toast.title:SetTextColor(unpack(A.Skin.colors.gold))
    toast.body=text(toast,11,0,-25,350,"Click to review your supplies")
    toast:SetScript("OnClick",function() toast:Hide(); self:Open() end)
    toast:SetScript("OnUpdate",function(_,elapsed)
        toast.elapsed=(toast.elapsed or 0)+elapsed
        if toast.elapsed>=4.5 then toast:Hide()
        elseif toast.elapsed>4 then toast:SetAlpha(1-(toast.elapsed-4)/0.5) end
    end)
    toast:Hide()
end
function R:Refresh()
    if not self.settings then return end
    local resting=IsResting and IsResting() and true or false
    local now=GetTime()
    if self.resting~=resting then
        if self.resting==true and not resting and self.settings.departure then self.departure=now end
        self.dismissed=nil; self.resting=resting
    end
    local _,instance=IsInInstance()
    local unsafe=InCombatLockdown() or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
        or (UnitOnTaxi and UnitOnTaxi("player")) or instance=="party" or instance=="raid"
    if resting or not self.settings.departure or (self.departure and now-self.departure>20) then self.departure=nil end
    self.panel:Hide()
    if unsafe then self.toast:Hide(); return end
    if not self.settings.panel and not self.departure then return end
    local missing=self:Missing(self:LiveContext())
    if resting and self.settings.panel and not self.dismissed and #missing>0 then
        local lines={}
        for i=1,math.min(4,#missing) do lines[#lines+1]=missing[i].name.."  -  need "..missing[i].missing end
        if #missing>4 then lines[#lines+1]="+ "..(#missing-4).." more in Essentials" end
        self.panel.body:SetText(table.concat(lines,"\n"))
        local bodyHeight=self.panel.body:GetStringHeight()
        self.panel.body:SetHeight(bodyHeight)
        self.panel.hint:ClearAllPoints(); self.panel.hint:SetPoint("TOPLEFT",12,-48-bodyHeight)
        self.panel:SetHeight(76+bodyHeight); self.panel:Show()
    end
    if self.departure then
        self.departure=nil -- One opportunity per departure, even with empty/unknown bags.
        if #missing>0 and (not self.lastReminder or now-self.lastReminder>=300) then
            self.lastReminder=now
            self.toast.title:SetText("HardcoreBuddy: "..#missing.." essentials below target")
            self.toast.elapsed=0; self.toast:SetAlpha(1); self.toast:Show()
        end
    end
end
function R:LayoutSettings(parent,left,top,width,height,visible)
    if not self.settings then return end
    if not self.options then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.options=f; A.Skin.Paint(f,"card")
        text(f,22,20,-18,700,"Preparation reminders"):SetTextColor(unpack(A.Skin.colors.gold))
        text(f,12,20,-56,700,"Quiet, optional reminders based on your Essentials priorities and Carry quantities.")
        f.checks={}
        for i,entry in ipairs({{"panel","Show missing essentials while resting in a city or inn"},
            {"departure","Remind me when leaving a resting area with missing essentials"}}) do
            local key,label=entry[1],entry[2]
            local check=CreateFrame("CheckButton",nil,f,"BackdropTemplate")
            check:SetSize(24,24); check:SetPoint("TOPLEFT",20,-102-(i-1)*48); A.Skin.Paint(check,"edit")
            check.mark=text(check,13,7,-4,16); text(check,12,34,-4,650,label)
            check:SetScript("OnClick",function(b)
                self.settings[key]=b:GetChecked() and true or false; b.mark:SetText(self.settings[key] and "X" or "")
                self.dismissed=nil; self:Refresh()
            end)
            f.checks[key]=check
        end
        text(f,12,20,-224,690,"Essentials covers your core supplies. Advanced covers situational survival tools; other supplies start as Optional. Open an item to change its priority. Your choices follow that item's family as ranks improve.")
        text(f,12,20,-296,690,"Set Carry to 0 to skip restocking. Unknown bag or profession data does not trigger a shortage. Reminders are silent, stay out of combat, and are limited to one every five minutes.")
    end
    local f=self.options; f:SetShown(visible)
    if not visible then return end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top); f:SetSize(width,height)
    for key,check in pairs(f.checks) do check:SetChecked(self.settings[key]); check.mark:SetText(self.settings[key] and "X" or "") end
end
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        if name~=addonName then return end
        A.db.preparation=type(A.db.preparation)=="table" and A.db.preparation or {}
        R.settings=A.db.preparation
        if R.settings.panel==nil then R.settings.panel=true end
        if R.settings.departure==nil then R.settings.departure=true end
        R:BuildFrames()
        for _,e in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_UPDATE_RESTING","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA",
            "BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","UNIT_INVENTORY_CHANGED","GET_ITEM_INFO_RECEIVED",
            "PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","SKILL_LINES_CHANGED","SPELLS_CHANGED"}) do events:RegisterEvent(e) end
        events:UnregisterEvent("ADDON_LOADED")
    elseif event=="PLAYER_ENTERING_WORLD" then
        -- Loading screens and logging into an inn are never departures.
        R.resting=IsResting and IsResting() and true or false; R.departure=nil
    elseif event=="PLAYER_REGEN_DISABLED" then R.panel:Hide(); R.toast:Hide() end
    R.refreshAt=GetTime()+0.5
end)
events:SetScript("OnUpdate",function()
    if R.refreshAt and GetTime()>=R.refreshAt then R.refreshAt=nil; R:Refresh() end
end)
