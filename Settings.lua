local _,A=...
local S={sections={"General","Gear Advisor","Auction House","Death Alerts","Death Banner","Low Health","Rares","Elites","Preparation"}}
A.Settings=S
local Skin=A.Skin

local function label(parent,text,size,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size,""); f:SetPoint("TOPLEFT",x,-y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,y,callback,width)
    local f=CreateFrame("Button",nil,parent,"BackdropTemplate")
    f:SetSize(width or 280,30); f:SetPoint("TOPLEFT",20,-y)
    f.label=label(f,text,13,10,0,(width or 280)-20); f.label:SetHeight(30); f.label:SetJustifyV("MIDDLE")
    Skin.Button(f,"utility")
    f:SetScript("OnEnter",function() Skin.ButtonState(f,f.selected,true,false) end)
    f:SetScript("OnLeave",function() Skin.ButtonState(f,f.selected,false,false) end)
    f:SetScript("OnClick",callback); return f
end
local function check(parent,text,y,get,set)
    local f=CreateFrame("CheckButton",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",20,-y); f:SetSize(24,24); Skin.Paint(f,"edit")
    f.mark=label(f,"",13,0,0,24); f.mark:SetHeight(24); f.mark:SetJustifyH("CENTER"); f.mark:SetJustifyV("MIDDLE")
    f.label=label(parent,text,14,54,y+3,670)
    function f:Sync() self:SetChecked(get()); self.mark:SetText(get() and "X" or "") end
    f:SetScript("OnClick",function(self) set(not not self:GetChecked()); self:Sync() end)
    return f
end

function A:OpenSettings(section)
    self:CreateWindow(); self:CommitInputs()
    self.state={view="settings",filter=section or "General",page=1}; self.history={}
    self.window.classMenu:Hide(); self.window:Show(); self:Refresh(true)
end

function S:CommitInputs()
    if A.LowHealth.page then A.LowHealth.page.threshold:ClearFocus() end
    if A.CreatureAlerts.page then A.CreatureAlerts.page.duration:ClearFocus() end
    if A.Deaths.options then
        A.Deaths.options.duration:ClearFocus(); A.Deaths.options.alertLevel:ClearFocus()
    end
end

function S:Create(parent)
    local scroll=CreateFrame("ScrollFrame","HardcoreBuddySettingsScroll",parent,"UIPanelScrollFrameTemplate")
    self.scroll=scroll
    local content=CreateFrame("Frame",nil,scroll,"BackdropTemplate"); self.content=content
    Skin.Paint(content,"card"); scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(self.range or 0,scroll:GetVerticalScroll()-delta*36)))
    end)
    scroll:SetScript("OnHide",function() self:CommitInputs() end)
    self.pages={}
    for _,name in ipairs({"General","Gear Advisor","Auction House"}) do
        local page=CreateFrame("Frame",nil,content); page:SetAllPoints(content); page:Hide(); self.pages[name]=page
        label(page,name,22,20,18,700):SetTextColor(unpack(Skin.colors.gold))
    end
    local general=self.pages.General
    label(general,"Window, access and field kit notifications.",13,20,56,700)
    general.minimap=check(general,"Show minimap button",102,function() return not A.db.minimapHidden end,function(value)
        A.db.minimapHidden=not value; A:PositionMinimapButton()
    end)
    general.kit=check(general,"Notify me when leveling unlocks field kit upgrades",150,function() return A.db.kitNotifications~=false end,function(value)
        A.db.kitNotifications=value; if not value and A.kitAlert then A.kitAlert:Hide() end
    end)
    general.reset=button(general,"Recenter main window",218,function() A:HandleSlashCommand("reset") end)
    label(general,"Open this tab anytime with /hcb settings.",12,20,276,700)
    label(general,"Carry quantities and item priorities stay in Supplies. Talent paths stay in Advisors.",12,20,318,700)

    local gear=self.pages["Gear Advisor"]
    label(gear,"Choose how equipment upgrades are shown and scored for your current character.",13,20,56,700)
    gear.enabled=check(gear,"Show gear advisor in item tooltips",102,function() return A.db.gearAdvisorEnabled~=false end,function(value)
        A.db.gearAdvisorEnabled=value; A.GearAdvisor:RefreshTooltips()
    end)
    label(gear,"Scoring profile",15,20,164,700):SetTextColor(unpack(Skin.colors.gold))
    label(gear,"Automatic follows your talents. A selected role overrides it for this character.",12,20,192,700)
    gear.profiles={}
    for i=1,5 do
        local b=button(gear,"",224+(i-1)*36,function(self)
            A.TalentAdvisor:Activate({kind="advisor",command="profile",id=self.profileID})
            A.AuctionUpgrades:Invalidate()
        end,400)
        gear.profiles[i]=b
    end
    label(gear,"Every usable armor type is scored on stats. These settings use your live character, even while planning another.",12,20,422,700)

    local auction=self.pages["Auction House"]
    label(auction,"Filters for the Upgrades tab at the auction house. Saved per character.",13,20,56,700)
    auction.armor=check(auction,"",102,function() return A.characterDB.auctionHighestArmorOnly==true end,function(value)
        A.characterDB.auctionHighestArmorOnly=value
        A.AuctionUpgrades:Invalidate()
        A.AuctionUpgrades:Refresh()
    end)
    label(auction,"When enabled, scan only your class's highest available armor type. Accessories and weapons are still included. Turn it off to compare all usable armor types.",12,20,150,700)
    auction.cache=label(auction,"",12,20,224,700)
    auction.diagnostics=button(auction,"View scan diagnostics",286,function() A.AuctionDiagnostics:Show() end)
end

function S:Layout(parent,left,top,width,height,section,visible)
    if not self.scroll and not visible then return end
    if not self.scroll then self:Create(parent) end
    self.scroll:SetShown(visible)
    if not visible then
        if A.LowHealth.page then A.LowHealth.page:Hide() end
        if A.CreatureAlerts.page then A.CreatureAlerts.page:Hide() end
        if A.Readiness.options then A.Readiness.options:Hide() end
        return
    end
    section=section or "General"
    local scale=math.min(1,(width-22)/760)
    local contentWidth=(width-22)/scale
    local contentHeight=section=="Gear Advisor" and 480 or 440
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top)
    self.scroll:SetSize(width-22,height)
    self.content:SetScale(scale); self.content:SetSize(contentWidth,math.max(contentHeight,height/scale))
    for name,page in pairs(self.pages) do page:SetShown(name==section) end
    local general=self.pages.General; general.minimap:Sync(); general.kit:Sync()
    local gear=self.pages["Gear Advisor"]; gear.enabled:Sync()
    local _,class=UnitClass("player")
    local profiles=A.Data.AdvisorGear[class] or {}
    local selected=A.characterDB.advisors and A.characterDB.advisors.gearProfile
    for i,b in ipairs(gear.profiles) do
        local profile=profiles[i-1]
        b:SetShown(i==1 or profile~=nil); b.profileID=profile and profile.id or nil
        b.label:SetText(i==1 and "Automatic from talents" or profile and profile.name or "")
        b.selected=selected==b.profileID; Skin.ButtonState(b,b.selected,false,false)
    end
    local auction=self.pages["Auction House"]; auction.armor:Sync()
    local profile=A.GearAdvisor:CurrentProfile()
    local armor=profile and ({"Cloth","Leather","Mail","Plate"})[A.GearAdvisor.HighestArmorSubclass(profile)] or "..."
    auction.armor.label:SetText("Best Armor: "..armor)
    local saved=A.characterDB.auctionLastScan
    auction.cache:SetText(saved and ("Last scan: "..saved.recordedAt..". Results are kept across reloads; rescan for current prices.")
        or "Your next auction scan will be saved automatically, including partial results.")
    local content=self.content
    if section=="Low Health" then A.LowHealth:LayoutSettings(content,0,0,contentWidth,contentHeight,true)
    elseif A.LowHealth.page then A.LowHealth.page:Hide() end
    if section=="Rares" or section=="Elites" then A.CreatureAlerts:LayoutSettings(content,0,0,contentWidth,contentHeight,section,true)
    elseif A.CreatureAlerts.page then A.CreatureAlerts.page:Hide() end
    if section=="Preparation" then A.Readiness:LayoutSettings(content,0,0,contentWidth,contentHeight,true)
    elseif A.Readiness.options then A.Readiness.options:Hide() end
    if section=="Death Alerts" or section=="Death Banner" then
        A.Deaths:LayoutPage(content,0,0,contentWidth,contentHeight,{filter=section=="Death Banner" and "Appearance" or "Options"})
        A.Deaths.host:Show()
    end
    self.range=math.max(0,self.content:GetHeight()*scale-height)
    self.scroll:UpdateScrollChildRect()
    self.scroll:SetVerticalScroll(self.section~=section and 0 or math.min(self.scroll:GetVerticalScroll(),self.range))
    self.section=section
end
