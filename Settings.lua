local _,A=...
local S={sections={"General","Zone Advisor","Gear Advisor","Talent Advisor","Auction House","Death Journal","Low Health","NPC Alerts","Debug"}}
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
    f:SetSize(width or 280,28); f:SetPoint("TOPLEFT",16,-y)
    f.label=label(f,text,13,10,0,(width or 280)-20); f.label:SetHeight(28); f.label:SetJustifyV("MIDDLE"); f.label:SetJustifyH("CENTER")
    Skin.Button(f,"utility")
    f:SetScript("OnEnter",function() Skin.ButtonState(f,f.selected,true,false) end)
    f:SetScript("OnLeave",function() Skin.ButtonState(f,f.selected,false,false) end)
    f:SetScript("OnClick",callback); return f
end
local function check(parent,text,y,get,set)
    local f=CreateFrame("CheckButton",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",16,-y); f:SetSize(24,24); Skin.Paint(f,"edit")
    f.mark=label(f,"",13,0,0,24); f.mark:SetHeight(24); f.mark:SetJustifyH("CENTER"); f.mark:SetJustifyV("MIDDLE")
    f.label=label(parent,text,12,50,y+3,math.max(240,parent:GetWidth()-74))
    function f:Sync() self:SetChecked(get()); self.mark:SetText(get() and "X" or "") end
    f:SetScript("OnClick",function(self) set(not not self:GetChecked()); self:Sync() end)
    return f
end

function A:OpenSettings(section)
    self:CreateWindow(); self:CommitInputs()
    self.state={view="settings",filter=self.Settings:Section(section),page=1}; self.history={}
    self.window.classMenu:Hide(); self.window:Show(); self:Refresh(true)
end

function S:RegisterBlizzardOptions()
    if self.blizzardPanel then return end
    local modern=Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory
    if not modern and not InterfaceOptions_AddCategory then return end
    local panel=CreateFrame("Frame",nil,UIParent); panel.name="HardcoreBuddy"; panel:Hide()
    label(panel,"HardcoreBuddy",22,16,16,600):SetTextColor(unpack(Skin.colors.gold))
    label(panel,"Configure supplies, advisors, alerts and appearance in HardcoreBuddy.",13,16,52,600)
    panel.open=button(panel,"Open HardcoreBuddy Settings",92,function()
        for _,frame in ipairs({SettingsPanel or false,InterfaceOptionsFrame or false,GameMenuFrame or false}) do
            if frame and frame:IsShown() then
                if HideUIPanel then HideUIPanel(frame) else frame:Hide() end
            end
        end
        A:OpenSettings("General")
    end,280)
    self.blizzardPanel=panel
    if modern then
        self.blizzardCategory=Settings.RegisterCanvasLayoutCategory(panel,"HardcoreBuddy")
        Settings.RegisterAddOnCategory(self.blizzardCategory)
    else InterfaceOptions_AddCategory(panel) end
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

function S:SyncDependencies()
    if not self.pages or self.syncingDependencies then return end
    self.syncingDependencies=true
    local function watch(control)
        if control and not control.settingsDependencyHook then
            control.settingsDependencyHook=true
            control:HookScript("OnClick",function() self:SyncDependencies() end)
        end
    end
    local function enable(control,value,caption)
        if not control then return end
        Skin.ControlEnabled(control,value)
        if caption then caption:SetAlpha(value and 1 or 0.4) end
    end
    local gear=self.pages["Gear Advisor"]
    local gearOn=A.GearAdvisor:IsEnabled()
    for _,panel in ipairs(gear.sectionCards) do Skin.GroupEnabled(panel,gearOn) end
    for _,edit in ipairs(gear.weights) do enable(edit,gearOn and edit.profile~=nil) end
    enable(gear.restore,gearOn and A.GearAdvisor:CurrentProfile()~=nil)
    enable(self.pages["Auction House"].armor,gearOn)
    local talent=self.pages["Talent Advisor"]
    local talentOn=A.TalentAdvisor:IsEnabled()
    Skin.GroupEnabled(talent.paths,talentOn)
    enable(talent.auto,talentOn and A:GetContext().mode~="preview")
    if not talentOn then enable(talent.apply,false)
    else enable(talent.apply,talent.apply:IsEnabled()) end
    watch(talent.auto)
    local low=A.LowHealth.page
    if low then
        local s=A.LowHealth.settings
        for _,b in pairs(low.checks) do watch(b) end
        enable(low.checks.sound,s.enabled)
        enable(low.threshold,s.enabled)
        enable(low.preview,s.enabled)
        enable(low.volume,s.enabled and s.sound,low.volumeLabel)
        low.soundHint:SetAlpha(s.enabled and s.sound and 1 or 0.4)
        for _,caption in ipairs(low.thresholdLabels or {}) do caption:SetAlpha(s.enabled and 1 or 0.4) end
    end
    for _,page in pairs(A.CreatureAlerts.pages or {}) do
        local s=A.CreatureAlerts.settings[page.category]
        for _,b in pairs(page.checks) do watch(b) end
        enable(page.checks.sound,s.enabled); enable(page.checks.nonHostile,s.enabled)
        enable(page.duration,s.enabled,page.durationLabel)
        enable(page.preview,s.enabled); enable(page.neutralPreview,s.enabled and s.nonHostile)
        enable(page.volume,s.enabled and s.sound,page.volumeLabel)
        page.soundHint:SetAlpha(s.enabled and s.sound and 1 or 0.4)
    end
    local death=A.Deaths.options
    if death then
        local s=A.Deaths.db.settings
        for _,b in pairs(death.checks) do watch(b) end
        enable(death.checks.sound,s.alerts)
        enable(death.checks.locked,s.alerts or s.mini)
        for _,control in ipairs({death.duration,death.alertLevel,death.preview}) do enable(control,s.alerts) end
        for _,caption in ipairs(death.alertCaptions or {}) do caption:SetAlpha(s.alerts and 1 or 0.4) end
        for _,control in ipairs({death.scaleDown,death.scaleUp,death.resetPositions}) do enable(control,s.alerts or s.mini) end
        death.scaleText:SetAlpha((s.alerts or s.mini) and 1 or 0.4)
        for _,control in ipairs({death.soundPrev,death.soundChoice,death.soundNext,death.volume}) do enable(control,s.alerts and s.sound) end
        death.volumeLabel:SetAlpha(s.alerts and s.sound and 1 or 0.4)
        death.soundLabel:SetAlpha(s.alerts and s.sound and 1 or 0.4)
        local appearance=A.Deaths.appearance
        if appearance then
            Skin.GroupEnabled(appearance.styleSection,s.alerts)
            Skin.GroupEnabled(appearance.positionSection,s.alerts)
            -- Text-only alerts have no background to adjust.
            enable(appearance.opacity,s.alerts and s.alertStyle~="Text-only",appearance.opacityText)
            for _,b in pairs(appearance.styles) do watch(b) end
        end
    end
    local map=A.MapAdvisor.controls
    if map then
        local s=A.MapAdvisor:Settings()
        enable(map.tintColor,s.reveal=="tint"); enable(map.sliders.tintAlpha,s.reveal=="tint")
        local any=false
        for key,b in pairs(map.icons) do enable(b,s[key]); any=any or s[key] end
        enable(map.sliders.iconSize,any); enable(map.sliders.iconAlpha,any)
        map.noticeHint:SetAlpha(s.notify and 1 or 0.4)
    end
    local readiness=A.Readiness.options
    if readiness then
        for _,b in pairs(readiness.checks) do watch(b) end
        enable(readiness.previewPanel,A.Readiness.settings.panel)
        enable(readiness.previewReminder,A.Readiness.settings.departure)
        readiness.reminderHelp:SetAlpha(A.Readiness.settings.departure and 1 or 0.4)
    end
    self.syncingDependencies=nil
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
        page.title=label(page,name,22,0,0,700); page.title:SetTextColor(unpack(Skin.colors.gold))
    end
    local general=self.pages.General
    general.subtitle=label(general,"Window, access and field kit notifications.",12,0,34,700)
    local access=Skin.Section(general,"Access & window",62,154,1)
    local kit=Skin.Section(general,"Field kit",62,154,2)
    general.minimap=check(access,"Show minimap button",46,function() return not A.db.minimapHidden end,function(value)
        A.db.minimapHidden=not value; A:PositionMinimapButton()
    end)
    general.kit=check(kit,"Notify me when leveling unlocks field kit upgrades",46,function() return A.db.kitNotifications~=false end,function(value)
        A.db.kitNotifications=value; if not value and A.kitAlert then A.kitAlert:Hide() end
    end)
    general.reset=button(access,"Recenter main window",82,function() A:HandleSlashCommand("reset") end)
    label(access,"Author: CeaserXL (CXL)",12,16,122,300)
    label(kit,"Manage Carry quantities and item priorities in Supplies. Find talent recommendations in Advisors.",12,16,86,300)
    general.contentHeight=486
    local npc=self.pages["NPC Alerts"]
    npc.subtitle=label(npc,"Configure rare and elite warnings independently.",12,0,34,700)
    npc.contentHeight=430

    local gear=self.pages["Gear Advisor"]
    gear.toggle=button(gear,"",0,function() A.GearAdvisor:SetEnabled(not A.GearAdvisor:IsEnabled()) end,200)
    gear.toggle:ClearAllPoints(); gear.toggle:SetPoint("TOPRIGHT",-12,0)
    gear.toggle:SetHeight(28); gear.toggle.label:SetHeight(28); gear.toggle.label:SetJustifyH("CENTER")
    gear.profile=label(gear,"",12,0,34,700)
    gear.description=label(gear,"Choose how upgrades are shown and scored. Scoring follows your Talent Advisor build and compares all usable armor types by stats.",12,0,54,700)
    local display=Skin.Section(gear,"Display & notifications",96,172,1)
    local equip=Skin.Section(gear,"Automatic equipment",96,172,2)
    local scoring=Skin.Section(gear,"Scoring weights",280,84)
    gear.enabled=check(display,"Show gear advice in item tooltips",46,function() return A.db.gearAdvisorEnabled~=false end,function(value)
        A.db.gearAdvisorEnabled=value; A.GearAdvisor:RefreshTooltips()
    end)
    gear.markers=check(display,"Mark upgrades in bags and quest rewards",86,function() return A.db.gearUpgradeMarkers~=false end,function(value)
        A.db.gearUpgradeMarkers=value
        if A.GearIndicators then A.GearIndicators:Invalidate() end
    end)
    gear.notify=check(display,"Notify me of upgrades in my bags",126,function() return A.db.gearBagNotify==true end,function(value)
        A.db.gearBagNotify=value; A.GearBagAdvisor:Changed()
    end)
    gear.autoEquip=check(equip,"Automatically equip gear upgrades",46,function() return A.db.gearAutoEquip==true end,function(value)
        A.db.gearAutoEquip=value; A.GearBagAdvisor:Changed()
    end)
    label(equip,"Waits until you are out of combat. Equipped quest items, including off-hand items, stay under your control.",12,16,90,300)
    gear.openWeights=button(scoring,"Stat Weights",42,function() self:OpenGearPage("Stat Weights") end)
    label(scoring,"Adjust individual stats or restore your build's defaults.",12,320,46,370)
    gear.contentHeight=376
    A.DebugDump:Create(self.pages.Debug)
    local weightsPage=self.pages["Stat Weights"]
    weightsPage.profile=label(weightsPage,"",12,0,34,700)
    weightsPage.description=label(weightsPage,"Saved for this character's scoring profile. Use 0 to ignore a stat. Enter to save; Escape to cancel.",12,0,60,700)
    gear.weightMessage=label(weightsPage,"",12,16,86,700)
    gear.weights={}
    gear.restore=button(weightsPage,"Restore Defaults",90,function()
        self:CommitInputs()
        A.GearAdvisor:ResetWeights(A.GearAdvisor:CurrentProfile())
        gear.weightMessage:SetText(""); A:Refresh()
    end,180)
    gear.restore:ClearAllPoints(); gear.restore:SetPoint("TOPLEFT",540,-90)
    for index,entry in ipairs(A.GearAdvisor.WeightFields) do
        local x=16+((index-1)%2)*360
        local y=112+math.floor((index-1)/2)*36
        local caption=label(weightsPage,entry[2],12,x,y+7,238)
        local edit=CreateFrame("EditBox",nil,weightsPage,"BackdropTemplate")
        gear.weights[index]=edit; edit.weightKey=entry[1]; edit.caption=caption
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
    weightsPage.contentHeight=124+math.ceil(#gear.weights/2)*36
    Skin.SectionBackdrop(weightsPage,100,weightsPage.contentHeight-112)

    local talent=self.pages["Talent Advisor"]
    talent.toggle=button(talent,"",0,function() A.TalentAdvisor:SetEnabled(not A.TalentAdvisor:IsEnabled()) end,200)
    talent.toggle:ClearAllPoints(); talent.toggle:SetPoint("TOPRIGHT",-12,0)
    talent.toggle:SetHeight(28); talent.toggle.label:SetHeight(28); talent.toggle.label:SetJustifyH("CENTER")
    talent.context=label(talent,"",12,0,34,700)
    talent.description=label(talent,"Choose your talent path here. Its scoring profile also controls gear advice, auction upgrades and item markers. Review your path before enabling automatic application.",12,0,54,700)
    talent.builds={}
    local maxBuilds=0
    for _,builds in pairs(A.Data.AdvisorBuilds) do maxBuilds=math.max(maxBuilds,#builds) end
    talent.spending=Skin.Section(talent,"Apply talent points",160+maxBuilds*46,124)
    talent.apply=button(talent.spending,"Apply unused points",42,function() A.TalentAdvisor:ApplyUnused(false) end,280)
    talent.auto=check(talent.spending,"Automatically apply unused points",46,function() return A.characterDB.autoApplyTalents==true end,function(value)
        A.characterDB.autoApplyTalents=value
        if value then A.TalentAdvisor:ApplyUnused(true) else A.TalentAdvisor.applying=nil end
    end)
    label(talent.spending,"Uses your selected path. Stops if your learned talents do not match. Points cannot be undone without a respec.",12,16,86,700)
    talent.paths=Skin.Section(talent,"Talent paths",100,48+maxBuilds*46)
    for i=1,maxBuilds do
        local b=button(talent.paths,"",42+(i-1)*46,function(self)
            A.TalentAdvisor:Activate({command=self.automatic and "defaultBuild" or "build",id=self.buildID,class=self.class})
        end,700)
        b:SetHeight(40); b.label:SetHeight(40); b.label:SetFont(STANDARD_TEXT_FONT,12,"")
        talent.builds[i]=b
    end
    talent.contentHeight=296+maxBuilds*46

    local auction=self.pages["Auction House"]
    auction.subtitle=label(auction,"Filters and saved scans for the auction house Upgrades tab.",12,0,34,700)
    local filters=Skin.Section(auction,"Armor filter",62,182,1)
    local scans=Skin.Section(auction,"Saved scans",62,182,2)
    auction.armor=check(filters,"",56,function() return A.characterDB.auctionHighestArmorOnly==true end,function(value)
        A.AuctionUpgrades:SetHighestArmorOnly(value)
    end)
    label(filters,"Scan only your class's highest available armor type. Accessories and weapons are included. Turn this off to compare all usable armor types.",12,16,102,300)
    auction.cache=label(scans,"",12,16,56,300)
    auction.diagnostics=button(scans,"View scan diagnostics",132,function() A.AuctionDiagnostics:Show() end)
    auction.contentHeight=256
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
    local contentHeight=self.pages[pageName] and self.pages[pageName].contentHeight or 282
    if section=="Death Journal" then contentHeight=682 end
    if section=="Zone Advisor" then contentHeight=A.state.mapIconKind and A.MapAdvisor:IconPickerHeight() or A.MapAdvisor:SettingsHeight() end
    if pageName=="Debug" then A.DebugDump:Refresh() end
    self.scroll:ClearAllPoints(); self.scroll:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top)
    self.scroll:SetSize(width-22,height)
    self.content:SetScale(scale); self.content:SetSize(contentWidth,math.max(contentHeight,height/scale))
    Skin.Paint(self.content,"note")
    for _,page in pairs(self.pages) do Skin.LayoutSections(page,contentWidth) end
    for name,page in pairs(self.pages) do
        local context=page.profile or page.context or page.subtitle
        Skin.SettingsHeader(page,contentWidth,page.title,context,page.toggle or (name=="Stat Weights" and self.pages["Gear Advisor"].restore),page.description)
    end
    local spending=self.pages["Talent Advisor"].spending
    local auto=self.pages["Talent Advisor"].auto
    auto:ClearAllPoints(); auto:SetPoint("TOPLEFT",spending,"TOPLEFT",spending:GetWidth()/2+22,-46)
    auto.label:ClearAllPoints(); auto.label:SetPoint("LEFT",auto,"RIGHT",10,0); auto.label:SetWidth(spending:GetWidth()/2-56)
    for name,page in pairs(self.pages) do page:SetShown(name==pageName) end
    local half=(contentWidth-24)/2
    for i,edit in ipairs(self.pages["Gear Advisor"].weights) do
        local x=16+((i-1)%2)*(half+12)
        local y=112+math.floor((i-1)/2)*36
        edit:ClearAllPoints(); edit:SetPoint("TOPLEFT",x+half-122,-y)
        edit.caption:ClearAllPoints(); edit.caption:SetPoint("TOPLEFT",x,-y-7); edit.caption:SetWidth(half-138)
    end
    local generalPage=self.pages.General
    generalPage.reset:SetWidth(generalPage.sectionCards[1]:GetWidth()-32)
    generalPage.reset.label:SetWidth(generalPage.reset:GetWidth()-20)
    local auctionPage=self.pages["Auction House"]
    auctionPage.diagnostics:SetWidth(auctionPage.sectionCards[2]:GetWidth()-32)
    auctionPage.diagnostics.label:SetWidth(auctionPage.diagnostics:GetWidth()-20)
    local apply=self.pages["Talent Advisor"].apply
    apply:SetWidth((spending:GetWidth()-12)/2-32); apply.label:SetWidth(apply:GetWidth()-20)
    A.DebugDump:Layout(contentWidth)
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
    local automatic=A.TalentAdvisor:DefaultBuild(class,context.level)
    talent.context:SetText(context.characterClass.." | Level "..context.level..(context.mode=="preview" and " | Planning another character" or " | Your character"))
    for i,b in ipairs(talent.builds) do
        local build=builds[i]
        b:SetShown(build~=nil); b.buildID=build and build.id or nil; b.class=class
        b.automatic=build and automatic and build.id==automatic.id or false
        local score=build and A.GearAdvisor.Profile(class,context.level,nil,build.profile)
        b.label:SetText(build and (build.name..(not manual and selected and selected.id==build.id and " (Automatic)" or "").."\nLevels "..build.minLevel.."-"..build.maxLevel.." | Scoring: "..(score and score.name or "Unavailable")) or "")
        b:SetWidth(talent.paths:GetWidth()-32); b.label:SetWidth(b:GetWidth()-20); b.label:SetJustifyH("LEFT")
        b.selected=build and selected and selected.id==build.id or false
        Skin.ButtonState(b,b.selected,nil,false)
    end
    talent.paths:SetHeight(48+#builds*46)
    talent.spending.sectionTop=talent.paths.sectionTop+talent.paths:GetHeight()+12
    Skin.LayoutSections(talent,contentWidth)
    talent.contentHeight=296+#builds*46
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
        local half=(contentWidth-24)/2
        A.CreatureAlerts:LayoutSettings(self.pages["NPC Alerts"],0,62,half,356,"Rares",true)
        A.CreatureAlerts:LayoutSettings(self.pages["NPC Alerts"],12+half,62,half,356,"Elites",true)
    else for _,page in pairs(A.CreatureAlerts.pages or {}) do page:Hide() end end
    if section=="General" then A.Readiness:LayoutSettings(general,0,228,contentWidth-12,246,true)
    elseif A.Readiness.options then A.Readiness.options:Hide() end
    A.MapAdvisor:LayoutSettings(content,0,0,contentWidth,section=="Zone Advisor")
    if section=="Death Journal" then
        A.Deaths:LayoutPage(content,0,0,contentWidth,contentHeight,{filter="Settings"})
        A.Deaths.host:Show()
    end
    self:SyncDependencies()
    self.range=math.max(0,self.content:GetHeight()*scale-height)
    self.scroll:UpdateScrollChildRect()
    self.scroll:SetVerticalScroll(self.section~=pageName and 0 or math.min(self.scroll:GetVerticalScroll(),self.range))
    self.section=pageName
end
