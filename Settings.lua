local _,A=...
local S={sections={"General","Gear Advisor","Talent Advisor","Auction House","Death Alerts","Death Banner","Low Health","Rares","Elites","Preparation"}}
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
    local gear=self.pages and self.pages["Gear Advisor"]
    if gear then for _,edit in ipairs(gear.weights) do edit:ClearFocus() end end
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
    for _,name in ipairs({"General","Gear Advisor","Talent Advisor","Auction House"}) do
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
    label(general,"Carry quantities and item priorities stay in Supplies. Point-by-point talent advice stays in Advisors.",12,20,318,700)

    local gear=self.pages["Gear Advisor"]
    gear.profile=label(gear,"",14,20,52,700)
    label(gear,"Choose how equipment upgrades are shown and scored. Scoring follows your live character's Talent Advisor build and compares all usable armor types by stats.",13,20,84,700)
    gear.enabled=check(gear,"Show gear advisor in item tooltips",142,function() return A.db.gearAdvisorEnabled~=false end,function(value)
        A.db.gearAdvisorEnabled=value; A.GearAdvisor:RefreshTooltips()
    end)
    gear.markers=check(gear,"Mark gear upgrades in bags and quest rewards",184,function() return A.db.gearUpgradeMarkers~=false end,function(value)
        A.db.gearUpgradeMarkers=value
        if A.GearIndicators then A.GearIndicators:Invalidate() end
    end)
    label(gear,"Stat weights",18,20,240,360):SetTextColor(unpack(Skin.colors.gold))
    label(gear,"Saved for this character's scoring profile. Use 0 to ignore a stat. Enter to save; Escape to cancel.",12,20,280,700)
    gear.weightMessage=label(gear,"",12,20,302,700)
    gear.weights={}
    gear.restore=button(gear,"Restore Defaults",232,function()
        self:CommitInputs()
        A.GearAdvisor:ResetWeights(A.GearAdvisor:CurrentProfile())
        gear.weightMessage:SetText(""); A:Refresh()
    end,180)
    gear.restore:ClearAllPoints(); gear.restore:SetPoint("TOPLEFT",540,-232)
    for index,entry in ipairs(A.GearAdvisor.WeightFields) do
        local x=20+((index-1)%2)*360
        local y=332+math.floor((index-1)/2)*36
        label(gear,entry[2],12,x,y+7,238)
        local edit=CreateFrame("EditBox",nil,gear,"BackdropTemplate")
        gear.weights[index]=edit; edit.weightKey=entry[1]
        edit:SetSize(90,28); edit:SetPoint("TOPLEFT",x+246,-y)
        edit:SetFont(STANDARD_TEXT_FONT,13,""); edit:SetAutoFocus(false); edit:SetMaxLetters(16)
        edit:SetJustifyH("CENTER"); Skin.Paint(edit,"edit")
        edit:SetScript("OnEditFocusLost",function(e)
            if not e.profile then return end
            local value=tonumber(e:GetText())
            if value~=e.profile.weights[e.weightKey] then
                if not A.GearAdvisor:SetWeight(e.profile,e.weightKey,value) then
                    gear.weightMessage:SetText("Enter a number from 0 to 1,000,000.")
                    gear.weightMessage:SetTextColor(unpack(Skin.colors.red))
                else
                    gear.weightMessage:SetText(""); e.profile.weights[e.weightKey]=value
                end
            end
            e:SetText(tostring(e.profile.weights[e.weightKey]))
        end)
        edit:SetScript("OnEnterPressed",function(e) e:ClearFocus() end)
        edit:SetScript("OnEscapePressed",function(e)
            if e.profile then e:SetText(tostring(e.profile.weights[e.weightKey])) end
            gear.weightMessage:SetText(""); e:ClearFocus()
        end)
        edit:SetScript("OnTabPressed",function(e)
            e:ClearFocus(); local nextEdit=gear.weights[index%#gear.weights+1]
            nextEdit:SetFocus(); nextEdit:HighlightText()
        end)
    end
    gear.contentHeight=348+math.ceil(#gear.weights/2)*36

    local talent=self.pages["Talent Advisor"]
    talent.context=label(talent,"",14,20,56,700)
    label(talent,"Choose your talent path here. Its scoring profile also controls gear advice, auction upgrades and item markers. Selecting a path does not spend talent points.",12,20,88,700)
    talent.builds={}
    local maxBuilds=0
    for _,builds in pairs(A.Data.AdvisorBuilds) do maxBuilds=math.max(maxBuilds,#builds) end
    for i=1,maxBuilds+1 do
        local b=button(talent,"",156+(i-1)*52,function(self)
            A.TalentAdvisor:Activate({command=self.buildID and "build" or "defaultBuild",id=self.buildID,class=self.class})
        end,700)
        b:SetHeight(46); b.label:SetHeight(46); b.label:SetFont(STANDARD_TEXT_FONT,12,"")
        talent.builds[i]=b
    end
    talent.contentHeight=176+(maxBuilds+1)*52

    local auction=self.pages["Auction House"]
    label(auction,"Filters for the Upgrades tab at the auction house. Saved per character.",13,20,56,700)
    auction.armor=check(auction,"",102,function() return A.characterDB.auctionHighestArmorOnly==true end,function(value)
        A.AuctionUpgrades:SetHighestArmorOnly(value)
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
    local contentHeight=section=="Talent Advisor" and self.pages["Talent Advisor"].contentHeight or section=="Gear Advisor" and self.pages["Gear Advisor"].contentHeight or 440
    if section=="Gear Advisor" then
        local gear=self.pages["Gear Advisor"]
        gear.snapshotTop=gear.contentHeight+12
        contentHeight=gear.snapshotTop+A.GearSnapshot:Layout(gear,gear.snapshotTop)+20
    end
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top)
    self.scroll:SetSize(width-22,height)
    self.content:SetScale(scale); self.content:SetSize(contentWidth,math.max(contentHeight,height/scale))
    for name,page in pairs(self.pages) do page:SetShown(name==section) end
    local general=self.pages.General; general.minimap:Sync(); general.kit:Sync()
    local gear=self.pages["Gear Advisor"]; gear.enabled:Sync(); gear.markers:Sync()
    local profile=A.GearAdvisor:CurrentProfile()
    gear.profile:SetText(profile and ("Scoring: "..profile.name) or "Character data loading")
    for _,edit in ipairs(gear.weights) do
        if edit.profile and profile and (edit.profile.class~=profile.class or edit.profile.id~=profile.id) then edit:ClearFocus() end
        if not edit:HasFocus() then
            edit.profile=profile
            edit:SetText(profile and tostring(profile.weights[edit.weightKey]) or "")
        end
        edit:SetEnabled(profile~=nil)
    end
    gear.restore:SetEnabled(profile~=nil)
    local context=A:GetContext()
    -- Presentation class names are used by the planner; build data uses tokens.
    local tokens={Druid="DRUID",Hunter="HUNTER",Mage="MAGE",Paladin="PALADIN",Priest="PRIEST",Rogue="ROGUE",Shaman="SHAMAN",Warlock="WARLOCK",Warrior="WARRIOR"}
    local class=tokens[context.characterClass]
    local talent=self.pages["Talent Advisor"]
    local builds=A.Data.AdvisorBuilds[class] or {}
    local selected,manual=A.TalentAdvisor:Build(class,context.level)
    talent.context:SetText(context.characterClass.." | Level "..context.level..(context.mode=="preview" and " | Planning another character" or " | Your character"))
    for i,b in ipairs(talent.builds) do
        local build=builds[i-1]
        b:SetShown(i==1 or build~=nil); b.buildID=build and build.id or nil; b.class=class
        local score=build and A.GearAdvisor.Profile(class,context.level,nil,build.profile)
        b.label:SetText(i==1 and ("Automatic Hardcore path\n"..(selected and selected.name or "")) or build and (build.name.."\nLevels "..build.minLevel.."-"..build.maxLevel.." | Scoring: "..(score and score.name or "Unavailable")) or "")
        b.selected=i==1 and not manual or manual and build and selected.id==build.id or false
        Skin.ButtonState(b,b.selected,false,false)
    end
    local auction=self.pages["Auction House"]; auction.armor:Sync()
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
