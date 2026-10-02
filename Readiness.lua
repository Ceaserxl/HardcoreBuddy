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
local function button(parent,label,width,action)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width,28); b.label=text(b,12,0,0,width,label)
    b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    A.Skin.Button(b,"utility"); b:SetScript("OnClick",action)
    return b
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
function R:SuppliesChanged()
    -- Supply preferences do not fire bag events. Coalesce edits into the next
    -- frame, after quantity focus handlers and the main window finish updating.
    self.refreshAt=GetTime()
end
function R:Open()
    self.toast:Hide()
    A:CreateWindow(); A.db.profile.mode="live"
    -- This is a fresh live-character destination, even after planning an alt.
    A.lastClass=nil
    A.state={view="supplies",filter="Essentials",page=1}; A.history={}
    A.window:Show(); A:Refresh(true)
end
function R:BuildFrames()
    local f=CreateFrame("Frame",nil,UIParent,"SecureHandlerStateTemplate,BackdropTemplate"); self.panel=f
    f:EnableMouse(true)
    f:SetSize(330,240); f:SetPoint("RIGHT",UIParent,"RIGHT",-36,35)
    f:SetFrameStrata("MEDIUM"); f:SetClampedToScreen(true); A.Skin.Paint(f,"card")
    f:SetMovable(true); f:RegisterForDrag("LeftButton")
    local anchors={TOPLEFT=true,TOP=true,TOPRIGHT=true,LEFT=true,CENTER=true,RIGHT=true,BOTTOMLEFT=true,BOTTOM=true,BOTTOMRIGHT=true}
    local position=self.settings and self.settings.position
    if type(position)=="table" and anchors[position.point] and anchors[position.relative]
        and type(position.x)=="number" and type(position.y)=="number"
        and math.abs(position.x)<100000 and math.abs(position.y)<100000 then
        f:ClearAllPoints(); f:SetPoint(position.point,UIParent,position.relative,position.x,position.y)
    end
    local function stopDrag()
        if not self.dragging then return end
        f:StopMovingOrSizing(); self.dragging=nil
        local point,_,relative,x,y=f:GetPoint()
        self.settings.position={point=point,relative=relative,x=x,y=y}
    end
    f:SetScript("OnDragStart",function() self.dragging=true; f:StartMoving() end)
    f:SetScript("OnDragStop",stopDrag); f:SetScript("OnHide",stopDrag)
    f.title=text(f,15,14,-12,270,"Missing essentials"); f.title:SetTextColor(unpack(A.Skin.colors.gold))
    f.summary=text(f,11,14,-34,300); f.summary:SetTextColor(unpack(A.Skin.colors.muted))
    f.rows={}
    for i=1,4 do
        local row=CreateFrame("Button",nil,f,"SecureActionButtonTemplate,BackdropTemplate"); f.rows[i]=row
        row:RegisterForClicks("AnyUp","AnyDown")
        row:SetPoint("TOPLEFT",12,-58-(i-1)*50); row:SetSize(306,46)
        A.Skin.Paint(row,"edit"); row:SetBackdropBorderColor(0,0,0,0)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("TOPLEFT",5,-5)
        row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
        row.name=text(row,12,42,-5,164); row.name:SetWordWrap(false); row.name:SetHeight(16)
        row.vendor=text(row,10,42,-25,256); row.vendor:SetWordWrap(false); row.vendor:SetHeight(14)
        row.vendor:SetTextColor(unpack(A.Skin.colors.muted))
        row.need=text(row,12,214,-10,84); row.need:SetJustifyH("RIGHT"); row.need:SetWordWrap(false); row.need:SetHeight(18)
        row:SetScript("OnEnter",function()
            GameTooltip:SetOwner(row,"ANCHOR_LEFT"); GameTooltip:SetText(row.name:GetText(),1,0.82,0,1)
            GameTooltip:AddLine(row.vendorName and ("Click to mark "..row.vendorName.." on the map and minimap. Vendor stock may vary.")
                or "No known vendor in this zone for this item. Open Essentials for acquisition details.",0.8,0.8,0.7,true)
            if row.vendorLocation and row.vendorLocation.alternativeName then
                GameTooltip:AddLine("Equivalent food: "..row.vendorLocation.alternativeName,1,.82,.3,true)
                GameTooltip:AddLine("Choose it as your default in Supplies to track and restock it.",.8,.8,.7,true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("PostClick",function(_,_,down)
            if not down and row.vendorLocation then A.VendorMarker:Set(row.vendorLocation,row.vendorLocation.alternativeName or row.name:GetText()) end
        end)
    end
    f.more=text(f,10,14,0,300); f.more:SetTextColor(unpack(A.Skin.colors.muted))
    f.hint=text(f,10,14,0,136,"Drag to move"); f.hint:SetTextColor(unpack(A.Skin.colors.muted))
    f.hint:ClearAllPoints(); f.hint:SetPoint("BOTTOMLEFT",14,18)
    f.review=button(f,"Review supplies",144,function() self:Open() end)
    f.review:SetPoint("BOTTOMRIGHT",-12,12)
    f:SetScript("OnUpdate",function()
        if self.previewUntil and not self.dragging and GetTime()>=self.previewUntil then
            self.previewUntil=nil; self.previewRows=nil; self:Refresh()
        end
    end)
    local close=CreateFrame("Button",nil,f,"BackdropTemplate"); f.close=close
    close:SetSize(22,22); close:SetPoint("TOPRIGHT",-6,-6); A.Skin.Button(close,"utility")
    close.label=text(close,12,5,-3,16,"x")
    close:SetScript("OnClick",function()
        if self.previewUntil then self.previewUntil=nil; self.previewRows=nil; f:Hide(); self:Refresh()
        else self.dismissed=true; if RegisterStateDriver then RegisterStateDriver(f,"visibility","hide") end; f:Hide() end
    end)
    if RegisterStateDriver then RegisterStateDriver(f,"visibility","hide") end
    f:Hide()
    local toast=CreateFrame("Button",nil,UIParent); self.toast=toast
    A.Skin.Hover(toast)
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
function R:ShowPanel(missing,preview)
    if InCombatLockdown() then return end
    local f=self.panel; local count=math.min(4,#missing)
    f:SetFrameStrata(preview and "DIALOG" or "MEDIUM")
    A.Skin.Rebase(f,preview and ((A.window and A.window:GetFrameLevel() or 20)+20) or 10)
    f.summary:SetText((preview and "Preview | " or "")..#missing.." supplies below target")
    for i,row in ipairs(f.rows) do
        local item=missing[i]; row:SetShown(i<=count)
        if i<=count then
            local getIcon=C_Item and C_Item.GetItemIconByID or GetItemIcon
            row.icon:SetTexture(getIcon and getIcon(item.itemId) or "Interface\\Icons\\INV_Misc_Bag_08")
            row.name:SetText(item.name)
            local vendor=not preview and A.VendorServices and A.VendorServices:FindSupplyVendor(item.itemId)
            row.vendorName=vendor and vendor.name or nil
            row.vendorLocation=vendor or nil
            row.vendor:SetText(vendor and (vendor.name..(vendor.alternativeName and " (equivalent food)" or "")) or "No known vendor in this zone")
            row:SetAttribute("type",vendor and "macro" or nil)
            row:SetAttribute("macrotext",vendor and ("/targetexact "..vendor.name:gsub("[\r\n]","")) or nil)
            A.Skin.Hover(row,vendor~=nil)
            row.need:SetText("("..(item.count or 0).."/"..item.target..")")
            row.need:SetTextColor(unpack(item.count==0 and A.Skin.colors.red or A.Skin.colors.amber))
        end
    end
    local bottom=58+count*50
    f.more:SetShown(#missing>count)
    if #missing>count then
        f.more:ClearAllPoints(); f.more:SetPoint("TOPLEFT",14,-bottom)
        f.more:SetText("+ "..(#missing-count).." more in Essentials"); bottom=bottom+20
    end
    f:SetHeight(bottom+48)
    if RegisterStateDriver then RegisterStateDriver(f,"visibility","[combat] hide; show") end
    f:Show()
end
function R:ShowReminder(count,preview)
    self.toast:SetFrameStrata(preview and "DIALOG" or "HIGH")
    self.toast:SetFrameLevel(preview and ((A.window and A.window:GetFrameLevel() or 20)+20) or 10)
    self.toast.title:SetText((preview and "Preview: " or "HardcoreBuddy: ")..count.." essentials below target")
    self.toast.elapsed=0; self.toast:SetAlpha(1); self.toast:Show()
end
function R:Preview(kind)
    if InCombatLockdown() then A:Print("Preview preparation reminders after combat."); return end
    if kind=="reminder" then
        self:ShowReminder(math.max(1,#self:Missing(self:LiveContext())),true)
    else
        -- Fixed examples make the layout preview useful even with full bags.
        self.previewRows={
            {itemId=117,name="Tough Jerky",count=6,target=20,missing=14},
            {itemId=118,name="Minor Healing Potion",count=0,target=5,missing=5},
            {itemId=1251,name="Linen Bandage",count=8,target=20,missing=12},
        }
        self.previewUntil=GetTime()+20
        self:ShowPanel(self.previewRows,true)
        self.panel.summary:SetText("Preview | Example supplies")
    end
end
function R:Refresh()
    if not self.settings then return end
    -- Secure vendor-target buttons hide through their state driver in combat.
    if InCombatLockdown() then
        if self.dragging then self.panel:StopMovingOrSizing(); self.dragging=nil end
        if not RegisterStateDriver then self.panel:Hide() end
        self.resting=IsResting and IsResting() and true or false; self.departure=nil
        self.toast:Hide(); self.previewUntil=nil; self.previewRows=nil; return
    end
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
    if self.dragging and not unsafe then return end
    if RegisterStateDriver then RegisterStateDriver(self.panel,"visibility","hide") end
    self.panel:Hide()
    if unsafe then self.previewUntil=nil; self.previewRows=nil; self.toast:Hide(); return end
    if self.previewUntil and now>=self.previewUntil then self.previewUntil=nil; self.previewRows=nil end
    if not self.settings.panel and not self.departure and not self.previewUntil then return end
    local missing=self:Missing(self:LiveContext())
    if self.previewUntil then
        self:ShowPanel(self.previewRows,true); self.panel.summary:SetText("Preview | Example supplies")
    elseif resting and self.settings.panel and not self.dismissed and #missing>0 then
        self:ShowPanel(missing)
    end
    if self.departure then
        self.departure=nil -- One opportunity per departure, even with empty/unknown bags.
        if #missing>0 and (not self.lastReminder or now-self.lastReminder>=300) then
            self.lastReminder=now
            self:ShowReminder(#missing)
        end
    end
end
function R:LayoutSettings(parent,left,top,width,height,visible)
    if not self.settings then return end
    if not self.options then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.options=f; A.Skin.Paint(f,"card")
        A.Skin.TextStyle(text(f,15,16,-16,700,"Preparation reminders"),"section")
        A.Skin.TextStyle(text(f,12,16,-38,700,"Quiet, optional reminders based on your Essentials priorities and Carry quantities."),"subtitle")
        f.checks={}
        for i,entry in ipairs({{"panel","Show missing essentials while resting in a city or inn"},
            {"departure","Remind me when leaving a resting area with missing essentials"}}) do
            local key,label=entry[1],entry[2]
            local check=CreateFrame("CheckButton",nil,f,"BackdropTemplate")
            check:SetSize(24,24); check:SetPoint("TOPLEFT",20,-76); A.Skin.Paint(check,"edit")
            check.mark=text(check,13,7,-4,16); check.label=text(check,12,34,-4,300,label)
            check:SetScript("OnClick",function(b)
                self.settings[key]=b:GetChecked() and true or false; b.mark:SetText(self.settings[key] and "X" or "")
                self.dismissed=nil; self:Refresh()
            end)
            f.checks[key]=check
        end
        f.previewPanel=button(f,"Preview missing essentials",210,function() self:Preview("panel") end)
        f.previewPanel:SetPoint("TOPLEFT",20,-154)
        f.previewReminder=button(f,"Preview reminder",174,function() self:Preview("reminder") end)
        f.previewReminder:SetPoint("TOPLEFT",f.previewPanel,"TOPRIGHT",12,0)
        f.priorityHelp=text(f,12,16,-148,330,"Essentials covers your core supplies. Advanced covers situational survival tools; other supplies start as Optional. Open an item to change its priority. Your choices follow that item's family as ranks improve.")
        f.reminderHelp=text(f,12,390,-148,330,"Set Keep on hand to 0 to skip restocking. Unknown bag or profession data does not trigger a shortage. Reminders are silent, stay out of combat, and are limited to one every five minutes.")
    end
    local f=self.options; f:SetShown(visible)
    if not visible then return end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top); f:SetSize(width,height)
    local gap=A.Skin.layout.columnGap
    local half=(width-gap)/2
    for i,key in ipairs({"panel","departure"}) do
        local check=f.checks[key]
        check:ClearAllPoints(); check:SetPoint("TOPLEFT",16+(i-1)*(half+gap),-64)
        check.label:SetWidth(half-66)
    end
    f.previewPanel:ClearAllPoints(); f.previewPanel:SetPoint("TOPLEFT",16,-112); f.previewPanel:SetWidth(half-32)
    f.previewReminder:ClearAllPoints(); f.previewReminder:SetPoint("TOPLEFT",half+gap+16,-112); f.previewReminder:SetWidth(half-32)
    f.priorityHelp:SetWidth(half-32)
    f.reminderHelp:ClearAllPoints(); f.reminderHelp:SetPoint("TOPLEFT",half+gap+16,-148); f.reminderHelp:SetWidth(half-32)
    for key,check in pairs(f.checks) do check:SetChecked(self.settings[key]); check.mark:SetText(self.settings[key] and "X" or "") end
end
local events=CreateFrame("Frame"); R.events=events
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
    elseif event=="PLAYER_REGEN_DISABLED" then
        if not RegisterStateDriver then R.panel:Hide() end
        R.toast:Hide()
    end
    R.refreshAt=GetTime()+0.5
end)
events:SetScript("OnUpdate",function()
    if R.refreshAt and GetTime()>=R.refreshAt then R.refreshAt=nil; R:Refresh() end
end)
