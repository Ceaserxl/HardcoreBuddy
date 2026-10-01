local _,A=...
local S={sections={"General","Gear Advisor","Talent Advisor","Auction House","Death Journal","Low Health","NPC Alerts","Zone Advisor","Debug"}}
A.Settings=S
local Skin=A.Skin
local aliases={Map="Zone Advisor",["Death Banner"]="Death Journal",["Death Alerts"]="Death Journal",Rares="NPC Alerts",Elites="NPC Alerts",Preparation="General"}
function S:Section(section) return aliases[section] or section or "General" end

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
    f.label=label(parent,text,12,54,y+3,math.max(240,parent:GetWidth()-74))
    function f:Sync() self:SetChecked(get()); self.mark:SetText(get() and "X" or "") end
    f:SetScript("OnClick",function(self) set(not not self:GetChecked()); self:Sync() end)
    return f
end

function A:OpenSettings(section)
    self:CreateWindow(); self:CommitInputs()
    self.state={view="settings",filter=self.Settings:Section(section),page=1}; self.history={}
    self.window.classMenu:Hide(); self.window:Show(); self:Refresh(true)
end

function S:OpenGearPage(page)
    A:CommitInputs()
    if page=="Gear Snapshot" then A:OpenSettings("Debug"); return end
    A.state.gearPage=page
    A:Refresh(true)
end

function S:CommitInputs()
    local gear=self.pages and self.pages["Gear Advisor"]
    if gear then for _,edit in ipairs(gear.weights) do edit:ClearFocus() end end
    if A.LowHealth.page then A.LowHealth.page.threshold:ClearFocus() end
    for _,page in pairs(A.CreatureAlerts.pages or {}) do page.duration:ClearFocus() end
    if A.Deaths.options then
        A.Deaths.options.duration:ClearFocus(); A.Deaths.options.alertLevel:ClearFocus()
        if A.Deaths.options.retention then A.Deaths.options.retention:ClearFocus() end
    end
end

function S:Create(parent)
    local scroll=CreateFrame("ScrollFrame","HardcoreBuddySettingsScroll",parent,"UIPanelScrollFrameTemplate")
    self.scroll=scroll
    local content=CreateFrame("Frame",nil,scroll,"BackdropTemplate"); self.content=content
    Skin.Paint(content,"note"); scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(self.range or 0,scroll:GetVerticalScroll()-delta*36)))
    end)
    scroll:SetScript("OnHide",function() self:CommitInputs() end)
    self.pages={}
    for _,name in ipairs({"General","Gear Advisor","Talent Advisor","Auction House","Stat Weights","NPC Alerts","Debug"}) do
        local page=CreateFrame("Frame",nil,content); page:SetAllPoints(content); page:Hide(); self.pages[name]=page
        label(page,name,22,12,12,700):SetTextColor(unpack(Skin.colors.gold))
    end
    local general=self.pages.General
    label(general,"Window, access and field kit notifications.",12,12,46,700)
    local access=Skin.Section(general,"Access & window",82,220,1)
    local kit=Skin.Section(general,"Field kit",82,220,2)
    general.minimap=check(access,"Show minimap button",56,function() return not A.db.minimapHidden end,function(value)
        A.db.minimapHidden=not value; A:PositionMinimapButton()
    end)
    general.kit=check(kit,"Notify me when leveling unlocks field kit upgrades",56,function() return A.db.kitNotifications~=false end,function(value)
        A.db.kitNotifications=value; if not value and A.kitAlert then A.kitAlert:Hide() end
    end)
    general.reset=button(access,"Recenter main window",112,function() A:HandleSlashCommand("reset") end)
    label(access,"Open settings with /hcb settings.",12,20,166,300)
    label(kit,"Manage Carry quantities and item priorities in Supplies. Find talent recommendations in Advisors.",12,20,118,300)
    general.contentHeight=668
    local npc=self.pages["NPC Alerts"]
    label(npc,"Configure rare and elite warnings independently.",12,12,46,700)
    npc.contentHeight=646

    local gear=self.pages["Gear Advisor"]
    gear.toggle=button(gear,"",18,function() A.GearAdvisor:SetEnabled(not A.GearAdvisor:IsEnabled()) end,200)
    gear.toggle:ClearAllPoints(); gear.toggle:SetPoint("TOPLEFT",520,-18)
    gear.profile=label(gear,"",12,12,46,700)
    label(gear,"Choose how upgrades are shown and scored. Scoring follows your Talent Advisor build and compares all usable armor types by stats.",12,12,72,700)
    local display=Skin.Section(gear,"Display & notifications",122,224,1)
    local equip=Skin.Section(gear,"Automatic equipment",122,224,2)
    local scoring=Skin.Section(gear,"Scoring weights",358,104)
    gear.enabled=check(display,"Show gear advice in item tooltips",54,function() return A.db.gearAdvisorEnabled~=false end,function(value)
        A.db.gearAdvisorEnabled=value; A.GearAdvisor:RefreshTooltips()
    end)
    gear.markers=check(display,"Mark upgrades in bags and quest rewards",104,function() return A.db.gearUpgradeMarkers~=false end,function(value)
        A.db.gearUpgradeMarkers=value
        if A.GearIndicators then A.GearIndicators:Invalidate() end
    end)
    gear.notify=check(display,"Notify me of upgrades in my bags",162,function() return A.db.gearBagNotify==true end,function(value)
        A.db.gearBagNotify=value; A.GearBagAdvisor:Changed()
    end)
    gear.autoEquip=check(equip,"Automatically equip gear upgrades",54,function() return A.db.gearAutoEquip==true end,function(value)
        A.db.gearAutoEquip=value; A.GearBagAdvisor:Changed()
    end)
    label(equip,"Waits until you are out of combat. Equipped quest items, including off-hand items, stay under your control.",12,20,110,300)
    gear.openWeights=button(scoring,"Stat Weights",52,function() self:OpenGearPage("Stat Weights") end)
    label(scoring,"Adjust individual stats or restore your build's defaults.",12,320,58,370)
    gear.contentHeight=474
    A.DebugDump:Create(self.pages.Debug)
    local weightsPage=self.pages["Stat Weights"]
    weightsPage.profile=label(weightsPage,"",12,12,46,700)
    label(weightsPage,"Saved for this character's scoring profile. Use 0 to ignore a stat. Enter to save; Escape to cancel.",12,12,76,700)
    gear.weightMessage=label(weightsPage,"",12,20,144,700)
    gear.weights={}
    gear.restore=button(weightsPage,"Restore Defaults",112,function()
        self:CommitInputs()
        A.GearAdvisor:ResetWeights(A.GearAdvisor:CurrentProfile())
        gear.weightMessage:SetText(""); A:Refresh()
    end,180)
    gear.restore:ClearAllPoints(); gear.restore:SetPoint("TOPLEFT",540,-112)
    for index,entry in ipairs(A.GearAdvisor.WeightFields) do
        local x=20+((index-1)%2)*360
        local y=176+math.floor((index-1)/2)*36
        label(weightsPage,entry[2],12,x,y+7,238)
        local edit=CreateFrame("EditBox",nil,weightsPage,"BackdropTemplate")
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
    weightsPage.contentHeight=192+math.ceil(#gear.weights/2)*36
    Skin.SectionBackdrop(weightsPage,164,weightsPage.contentHeight-176)

    local talent=self.pages["Talent Advisor"]
    talent.toggle=button(talent,"",18,function() A.TalentAdvisor:SetEnabled(not A.TalentAdvisor:IsEnabled()) end,200)
    talent.toggle:ClearAllPoints(); talent.toggle:SetPoint("TOPLEFT",520,-18)
    talent.context=label(talent,"",12,12,46,700)
    label(talent,"Choose your talent path here. Its scoring profile also controls gear advice, auction upgrades and item markers. Review your path before enabling automatic application.",12,12,76,700)
    talent.builds={}
    local maxBuilds=0
    for _,builds in pairs(A.Data.AdvisorBuilds) do maxBuilds=math.max(maxBuilds,#builds) end
    talent.spending=Skin.Section(talent,"Apply talent points",140,152)
    talent.apply=button(talent.spending,"Apply unused points",48,function() A.TalentAdvisor:ApplyUnused(false) end,280)
    talent.auto=check(talent.spending,"Automatically apply unused points",96,function() return A.characterDB.autoApplyTalents==true end,function(value)
        A.characterDB.autoApplyTalents=value
        if value then A.TalentAdvisor:ApplyUnused(true) else A.TalentAdvisor.applying=nil end
    end)
    label(talent.spending,"Uses your selected path. Stops if your learned talents do not match. Points cannot be undone without a respec.",12,340,48,350)
    talent.paths=Skin.Section(talent,"Talent paths",304,60+(maxBuilds+1)*52)
    for i=1,maxBuilds+1 do
        local b=button(talent.paths,"",52+(i-1)*52,function(self)
            A.TalentAdvisor:Activate({command=self.buildID and "build" or "defaultBuild",id=self.buildID,class=self.class})
        end,700)
        b:SetHeight(46); b.label:SetHeight(46); b.label:SetFont(STANDARD_TEXT_FONT,12,"")
        talent.builds[i]=b
    end
    talent.contentHeight=376+(maxBuilds+1)*52

    local auction=self.pages["Auction House"]
    label(auction,"Filters and saved scans for the auction house Upgrades tab.",12,12,46,700)
    local filters=Skin.Section(auction,"Armor filter",82,242,1)
    local scans=Skin.Section(auction,"Saved scans",82,242,2)
    auction.armor=check(filters,"",56,function() return A.characterDB.auctionHighestArmorOnly==true end,function(value)
        A.AuctionUpgrades:SetHighestArmorOnly(value)
    end)
    label(filters,"Scan only your class's highest available armor type. Accessories and weapons are included. Turn this off to compare all usable armor types.",12,20,102,300)
    auction.cache=label(scans,"",12,20,56,300)
    auction.diagnostics=button(scans,"View scan diagnostics",174,function() A.AuctionDiagnostics:Show() end)
    auction.contentHeight=336
end

function S:Layout(parent,left,top,width,height,section,visible)
    if not self.scroll and not visible then return end
    if not self.scroll then self:Create(parent) end
    self.scroll:SetShown(visible)
    if not visible then
        if A.LowHealth.page then A.LowHealth.page:Hide() end
        for _,page in pairs(A.CreatureAlerts.pages or {}) do page:Hide() end
        if A.Readiness.options then A.Readiness.options:Hide() end
        if A.MapAdvisor.controls then A.MapAdvisor.controls:Hide() end
        if A.MapAdvisor.iconPicker then A.MapAdvisor.iconPicker:Hide() end
        return
    end
    section=self:Section(section)
    local scale=math.min(1,(width-22)/760)
    local contentWidth=(width-22)/scale
    local pageName=section
    if section=="Gear Advisor" and A.state.gearPage=="Stat Weights" then pageName=A.state.gearPage end
    local contentHeight=self.pages[pageName] and self.pages[pageName].contentHeight or 440
    if section=="Death Journal" then contentHeight=1108 end
    if section=="Zone Advisor" then contentHeight=A.state.mapIconKind and A.MapAdvisor:IconPickerHeight() or A.MapAdvisor:SettingsHeight() end
    if pageName=="Debug" then A.DebugDump:Refresh() end
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top)
    self.scroll:SetSize(width-22,height)
    self.content:SetScale(scale); self.content:SetSize(contentWidth,math.max(contentHeight,height/scale))
    Skin.Paint(self.content,"note")
    for _,page in pairs(self.pages) do Skin.LayoutSections(page,contentWidth) end
    for name,page in pairs(self.pages) do page:SetShown(name==pageName) end
    local general=self.pages.General; general.minimap:Sync(); general.kit:Sync()
    local gear=self.pages["Gear Advisor"]; gear.enabled:Sync(); gear.markers:Sync(); gear.notify:Sync(); gear.autoEquip:Sync()
    gear.toggle.label:SetText(A.GearAdvisor:IsEnabled() and "Disable Gear Advisor" or "Enable Gear Advisor")
    local profile=A.GearAdvisor:CurrentProfile()
    gear.profile:SetText(profile and ("Scoring: "..profile.name) or "Character data loading")
    self.pages["Stat Weights"].profile:SetText(gear.profile:GetText())
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
    talent.toggle.label:SetText(A.TalentAdvisor:IsEnabled() and "Disable Talent Advisor" or "Enable Talent Advisor")
    talent.auto:Sync()
    local live=context.mode~="preview" and A.TalentAdvisor:ReadCurrent(class,context.level)
    talent.apply:SetEnabled(A.TalentAdvisor:IsEnabled() and live and live.unspent>0 and not A.TalentAdvisor.applying or false)
    talent.apply.label:SetText(A.TalentAdvisor.applying and "Applying talent points..." or "Apply unused points"..(live and (" ("..live.unspent..")") or ""))
    talent.auto:SetEnabled(context.mode~="preview")
    local builds=A.Data.AdvisorBuilds[class] or {}
    local selected,manual=A.TalentAdvisor:Build(class,context.level)
    talent.context:SetText(context.characterClass.." | Level "..context.level..(context.mode=="preview" and " | Planning another character" or " | Your character"))
    for i,b in ipairs(talent.builds) do
        local build=builds[i-1]
        b:SetShown(i==1 or build~=nil); b.buildID=build and build.id or nil; b.class=class
        local score=build and A.GearAdvisor.Profile(class,context.level,nil,build.profile)
        b.label:SetText(i==1 and ("Automatic Hardcore path\n"..(selected and selected.name or "")) or build and (build.name.."\nLevels "..build.minLevel.."-"..build.maxLevel.." | Scoring: "..(score and score.name or "Unavailable")) or "")
        b.selected=i==1 and not manual or manual and build and selected.id==build.id or false
        Skin.ButtonState(b,b.selected,nil,false)
    end
    talent.paths:SetHeight(60+(#builds+1)*52)
    talent.contentHeight=376+(#builds+1)*52
    if pageName=="Talent Advisor" then self.content:SetHeight(math.max(talent.contentHeight,height/scale)) end
    local auction=self.pages["Auction House"]; auction.armor:Sync()
    local armor=profile and ({"Cloth","Leather","Mail","Plate"})[A.GearAdvisor.HighestArmorSubclass(profile)] or "..."
    auction.armor.label:SetText("Best Armor: "..armor)
    local saved=A.characterDB.auctionLastScan
    auction.cache:SetText(saved and ("Last scan: "..saved.recordedAt..". Results are kept across reloads; rescan for current prices.")
        or "Your next auction scan will be saved automatically, including partial results.")
    local content=self.content
    if section=="Low Health" then A.LowHealth:LayoutSettings(content,0,0,contentWidth,contentHeight,true)
    elseif A.LowHealth.page then A.LowHealth.page:Hide() end
    if section=="NPC Alerts" then
        local half=(contentWidth-36)/2
        A.CreatureAlerts:LayoutSettings(self.pages["NPC Alerts"],12,82,half,552,"Rares",true)
        A.CreatureAlerts:LayoutSettings(self.pages["NPC Alerts"],24+half,82,half,552,"Elites",true)
    else for _,page in pairs(A.CreatureAlerts.pages or {}) do page:Hide() end end
    if section=="General" then A.Readiness:LayoutSettings(general,12,314,contentWidth-24,342,true)
    elseif A.Readiness.options then A.Readiness.options:Hide() end
    A.MapAdvisor:LayoutSettings(content,0,0,contentWidth,section=="Zone Advisor")
    if section=="Death Journal" then
        A.Deaths:LayoutPage(content,0,0,contentWidth,contentHeight,{filter="Settings"})
        A.Deaths.host:Show()
    end
    self.range=math.max(0,self.content:GetHeight()*scale-height)
    self.scroll:UpdateScrollChildRect()
    self.scroll:SetVerticalScroll(self.section~=pageName and 0 or math.min(self.scroll:GetVerticalScroll(),self.range))
    self.section=pageName
end
