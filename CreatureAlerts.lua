local addonName, addon = ...
local H={seen={},groups={},plates={},pending={}}
addon.CreatureAlerts=H
local names={rare="Rare",rareelite="Rare elite",elite="Elite",worldboss="Boss"}

function H:Suppressed()
    return (UnitOnTaxi and UnitOnTaxi("player")) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
end

function H:Mark(unit)
    if not SetRaidTarget or not GetRaidTargetIndex or GetRaidTargetIndex(unit) then return end
    if IsInRaid and IsInRaid() and not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then return end
    pcall(SetRaidTarget,unit,4) -- Green triangle; preserve existing marks.
end

function H:Present()
    if self:Suppressed() then return end
    local now=GetTime()
    local best,key
    for id,candidate in pairs(self.pending) do
        local _,instanceType=IsInInstance()
        if not UnitExists(candidate.unit) or UnitGUID(candidate.unit)~=candidate.guid or now-candidate.time>2
            or UnitIsDeadOrGhost(candidate.unit) or not self.settings[candidate.category].enabled
            or UnitClassification(candidate.unit)~=candidate.classification
            or UnitReaction(candidate.unit,"player")~=candidate.reactionValue
            or (candidate.reaction=="Neutral" and (not self.settings[candidate.category].nonHostile or not UnitCanAttack("player",candidate.unit)))
            or (candidate.category=="elites" and (instanceType=="party" or instanceType=="raid"))
            or self.groups[candidate.group].alerted then
            self.pending[id]=nil
        elseif not best or candidate.priority>best.priority or (candidate.priority==best.priority and candidate.firstSeen<best.firstSeen) then
            best,key=candidate,id
        end
    end
    if not best then return end
    -- Allow an urgent rare to replace an elite, but let speech finish first.
    if self.lastPresented and now-self.lastPresented<4 then return end
    if self.warning:IsShown() and best.priority<=(self.warning.priority or 0) then return end
    self.pending[key]=nil
    self.seen[key].alerted=true
    self.groups[best.group].alerted=true
    self.lastPresented=now
    self:Mark(best.unit)
    self:Show(best.name,best.level,best.classification,best.reaction,best.category,true)
    self.warning.priority=best.priority
end

function H:Inspect(unit,retryMarker)
    if not self.settings or not UnitExists or not UnitExists(unit) then return end
    if self:Suppressed() then return end
    if UnitIsPlayer(unit) or (UnitPlayerControlled and UnitPlayerControlled(unit)) or UnitIsDeadOrGhost(unit) then return end
    local classification=UnitClassification(unit)
    if not names[classification] then return end
    local reaction=UnitReaction(unit,"player")
    if not reaction then return end
    local hostile=reaction<=3
    local neutralAttackable=reaction==4 and UnitCanAttack("player",unit)
    local elite=classification~="rare"
    local rare=classification=="rare" or classification=="rareelite"
    local _,instanceType=IsInInstance()
    local dungeon=instanceType=="party" or instanceType=="raid"
    local category
    if rare and self.settings.rares.enabled and (hostile or (neutralAttackable and self.settings.rares.nonHostile)) then category="rares"
    elseif not dungeon and elite and self.settings.elites.enabled and (hostile or (neutralAttackable and self.settings.elites.nonHostile)) then category="elites" end
    if not category then return end
    local guid,name=UnitGUID(unit),UnitName(unit)
    if not guid or not name then return end
    local now=GetTime()
    local key=guid..(hostile and ":hostile" or ":nonhostile")
    local npcID=guid:match("^Creature%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-") or guid
    local group=npcID..":"..category..":"..(hostile and "hostile" or "neutral")
    local grouped=self.groups[group]
    if not grouped or now-grouped.lastSeen>=30 then grouped={}; self.groups[group]=grouped end
    grouped.lastSeen=now
    local seen=self.seen[key]
    if not seen or now-seen.lastSeen>=30 then seen={}; self.seen[key]=seen end
    seen.lastSeen=now
    if retryMarker then self:Mark(unit) end
    if seen.alerted or grouped.alerted then return end
    local previous=self.pending[key]
    self.pending[key]={guid=guid,unit=unit,name=name,level=UnitLevel(unit),classification=classification,
        reaction=hostile and "Hostile" or "Neutral",reactionValue=reaction,category=category,group=group,
        priority=category=="rares" and (hostile and 4 or 3) or (hostile and 2 or 1),
        time=now,firstSeen=previous and previous.firstSeen or now}
    if not self.collecting then self:Present() end
end

function H:SyncTargetButton()
    if InCombatLockdown and InCombatLockdown() then return end
    local b=self.targetButton
    if not b then return end
    UnregisterStateDriver(b,"visibility")
    b:Hide()
    b:SetAttribute("type",nil)
    if self.warning:IsShown() and self.warning.targetName then
        b:SetAttribute("type","macro")
        b:SetAttribute("macrotext","/targetexact "..self.warning.targetName)
        RegisterStateDriver(b,"visibility","[combat] hide; show")
    end
end

function H:Show(name,level,classification,reaction,category,targetable)
    local f=self.warning
    local hostileElite=reaction=="Hostile" and (classification=="elite" or classification=="rareelite" or classification=="worldboss")
    local rare=classification=="rare" or classification=="rareelite"
    if hostileElite or rare then
        self.screenFlash.elapsed=0
        if reaction=="Hostile" then self.screenFlash.wash:SetColorTexture(0.9,0.02,0.01,1)
        else self.screenFlash.wash:SetColorTexture(0.78,0.82,0.88,1) end
        self.screenFlash:SetAlpha(0)
        self.screenFlash:Show()
    end
    local color=reaction=="Hostile" and {1,0.38,0.27} or {0.94,0.76,0.43}
    f.title:SetText(reaction.." "..(names[classification] or "Elite").." detected")
    f.title:SetTextColor(unpack(color)); f.accent:SetVertexColor(unpack(color))
    f.icon:SetTexture(category=="rares" and "Interface\\Icons\\Spell_Nature_FarSight" or "Interface\\Icons\\Ability_Warrior_BattleShout")
    f.name:SetText(name.."  |  Level "..(level and level>0 and level or "??"))
    f.hint:SetText("Click to target")
    f.elapsed=0; f.duration=self.settings[category].duration; f.category=category; f.priority=0
    f:SetAlpha(1); f:Show()
    f.targetName=targetable and name or nil
    self:SyncTargetButton()
    if self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
    local volume=self.settings[category].volume
    if self.settings[category].sound and volume>0 and PlaySoundFile then
        local kind=category=="rares" and (reaction=="Hostile" and "HostileRareVoiceV1" or "NeutralRareVoiceV1") or "EliteSirenV2"
        local _,handle=PlaySoundFile("Interface\\AddOns\\"..addonName.."\\Media\\CreatureSounds\\"..kind..volume..".wav","Master")
        self.soundHandle=handle
    end
end

function H:Scan()
    if self:Suppressed() then
        self.pending={}; self.warning:Hide(); self.screenFlash:Hide()
        if self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
        return
    end
    self.collecting=true
    self:Inspect("target"); self:Inspect("mouseover")
    for unit in pairs(self.plates) do self:Inspect(unit) end
    self.collecting=nil
    self:Present()
    local now=GetTime()
    for id,record in pairs(self.seen) do if now-record.lastSeen>=30 then self.seen[id]=nil; self.pending[id]=nil end end
    for id,record in pairs(self.groups) do if now-record.lastSeen>=30 then self.groups[id]=nil end end
end

function H:Initialize()
    addon.db.creatureAlerts=type(addon.db.creatureAlerts)=="table" and addon.db.creatureAlerts or {}
    self.settings=addon.db.creatureAlerts
    for _,key in ipairs({"rares","elites"}) do
        local s=type(self.settings[key])=="table" and self.settings[key] or {}
        self.settings[key]=s
        if s.enabled==nil then s.enabled=true end
        if s.sound==nil then s.sound=true end
        if s.nonHostile==nil then s.nonHostile=true end
        local volume=tonumber(s.volume)
        s.volume=volume and volume==volume and math.max(0,math.min(100,math.floor(volume/10+0.5)*10)) or 70
        local duration=tonumber(s.duration)
        if not s.tenSecondDefault and duration==5 then duration=10 end
        s.tenSecondDefault=true
        s.duration=duration and duration==duration and math.max(1,math.min(30,duration)) or 10
    end
    local f=CreateFrame("Frame","HardcoreBuddyCreatureWarning",UIParent,"BackdropTemplate")
    self.warning=f
    local flash=CreateFrame("Frame",nil,UIParent)
    self.screenFlash=flash
    flash:SetAllPoints(UIParent); flash:SetFrameStrata("FULLSCREEN"); flash:EnableMouse(false)
    local wash=flash:CreateTexture(nil,"BACKGROUND")
    flash.wash=wash
    wash:SetAllPoints(flash); wash:SetColorTexture(0.9,0.02,0.01,1)
    flash:SetScript("OnUpdate",function(_,elapsed)
        flash.elapsed=flash.elapsed+elapsed
        if flash.elapsed>=3.2 then flash:SetAlpha(0); flash:Hide()
        else flash:SetAlpha(0.22*math.sin(math.pi*flash.elapsed/0.8)^2) end
    end)
    flash:Hide()
    f:SetSize(560,76); f:SetPoint("TOP",UIParent,"TOP",0,-110)
    f:SetFrameStrata("HIGH"); f:EnableMouse(false); addon.Skin.Paint(f,"card")
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8",edgeFile="Interface\\Buttons\\WHITE8x8",edgeSize=1})
    f:SetBackdropColor(0.035,0.042,0.052,0.97)
    f:SetBackdropBorderColor(0.24,0.27,0.30,1)
    f.accent=f:CreateTexture(nil,"ARTWORK")
    f.accent:SetColorTexture(1,1,1,1); f.accent:SetPoint("TOPLEFT",1,-1); f.accent:SetPoint("BOTTOMLEFT",1,1); f.accent:SetWidth(3)
    f.icon=f:CreateTexture(nil,"ARTWORK"); f.icon:SetSize(42,42); f.icon:SetPoint("LEFT",17,0)
    f.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    addon.Skin.Unsnap(f.icon)
    for _,entry in ipairs({{"title",12,-8},{"name",21,-27}}) do
        local label=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        label:SetFont(STANDARD_TEXT_FONT,entry[2],""); label:SetPoint("TOPLEFT",74,entry[3])
        label:SetSize(470,28); label:SetJustifyH("LEFT"); label:SetWordWrap(false)
        f[entry[1]]=label
    end
    f.hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f.hint:SetFont(STANDARD_TEXT_FONT,10,""); f.hint:SetPoint("TOPLEFT",74,-57)
    f.hint:SetSize(470,14); f.hint:SetJustifyH("LEFT")
    f.hint:SetTextColor(0.65,0.65,0.56)
    f:SetScript("OnUpdate",function(_,elapsed)
        f.hint:SetText(InCombatLockdown and InCombatLockdown() and "Click to target (after combat)" or "Click to target")
        f.elapsed=f.elapsed+elapsed
        if f.elapsed>=f.duration+0.5 then f:Hide()
        elseif f.elapsed>f.duration then f:SetAlpha(1-(f.elapsed-f.duration)/0.5) end
    end)
    f:Hide()
    if RegisterStateDriver and UnregisterStateDriver then
        local b=CreateFrame("Button","HardcoreBuddyCreatureTarget",UIParent,"SecureActionButtonTemplate")
        self.targetButton=b
        b:SetSize(560,76); b:SetPoint("TOP",UIParent,"TOP",0,-110)
        b:SetFrameStrata("HIGH"); b:SetFrameLevel(f:GetFrameLevel()+5)
        b:RegisterForClicks("AnyUp","AnyDown"); b:Hide()
    end
    f:HookScript("OnHide",function() self:SyncTargetButton() end)
end

function H:LayoutSettings(parent,x,y,width,height,section,visible)
    if not self.settings then return end
    if not self.page and visible then
        local p=CreateFrame("Frame",nil,parent); self.page=p; p.checks={}
        local function text(value,size,top)
            local t=p:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            t:SetFont(STANDARD_TEXT_FONT,size,""); t:SetPoint("TOPLEFT",20,top); t:SetWidth(650)
            t:SetJustifyH("LEFT"); t:SetText(value); return t
        end
        p.title=text("",22,-16); p.title:SetTextColor(unpack(addon.Skin.colors.gold))
        text("Warns when a creature appears on a nameplate, your target, or mouseover.",13,-52)
        for i,entry in ipairs({{"enabled","Enable warnings"},{"sound","Play alert sound"},{"nonHostile","Include attackable neutral elites"}}) do
            local key=entry[1]
            local b=CreateFrame("CheckButton",nil,p,"BackdropTemplate"); p.checks[key]=b
            b:SetSize(24,24); b:SetPoint("TOPLEFT",20,-88-(i-1)*40); addon.Skin.Paint(b,"edit")
            b.mark=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.mark:SetAllPoints(); b.mark:SetTextColor(unpack(addon.Skin.colors.gold))
            b.mark:SetJustifyH("CENTER"); b.mark:SetJustifyV("MIDDLE")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetPoint("LEFT",b,"RIGHT",10,0); b.label:SetText(entry[2])
            b:SetScript("OnClick",function()
                self.settings[p.category][key]=b:GetChecked() and true or false
                b.mark:SetText(b:GetChecked() and "X" or "")
                if key=="sound" and not b:GetChecked() and self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
                if key=="enabled" and not b:GetChecked() and self.warning.category==p.category then self.warning:Hide() end
            end)
        end
        text("Display duration (seconds, 1-30)",13,-216)
        p.duration=CreateFrame("EditBox",nil,p,"BackdropTemplate")
        local edit=p.duration; edit:SetSize(52,28); edit:SetPoint("TOPLEFT",20,-242)
        addon.Skin.Paint(edit,"edit"); edit:SetFont(STANDARD_TEXT_FONT,14,""); edit:SetAutoFocus(false); edit:SetNumeric(true); edit:SetMaxLetters(2); edit:SetJustifyH("CENTER")
        local function commit() self.settings[p.category].duration=math.max(1,math.min(30,tonumber(edit:GetText()) or 10)); edit:SetText(tostring(self.settings[p.category].duration)) end
        edit:SetScript("OnEditFocusLost",commit); edit:SetScript("OnEnterPressed",function() commit(); edit:ClearFocus() end)
        edit:SetScript("OnEscapePressed",function() edit:SetText(tostring(self.settings[p.category].duration)); edit:ClearFocus() end)
        local b=CreateFrame("Button",nil,p,"BackdropTemplate"); p.preview=b
        b:SetSize(160,30); b:SetPoint("TOPLEFT",92,-241)
        b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText("Preview warning")
        b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
        addon.Skin.Button(b,"utility")
        b:SetScript("OnEnter",function() addon.Skin.ButtonState(b,false,true,false) end)
        b:SetScript("OnLeave",function() addon.Skin.ButtonState(b,false,false,false) end)
        b:SetScript("OnClick",function() edit:ClearFocus(); self:Show("Example creature",30,p.category=="rares" and "rare" or "elite","Hostile",p.category) end)
        p.volumeLabel=text("",13,-289)
        local slider=CreateFrame("Slider",nil,p,"BackdropTemplate"); p.volume=slider
        slider:SetPoint("TOPLEFT",20,-316); slider:SetSize(230,18); slider:SetOrientation("HORIZONTAL")
        addon.Skin.Paint(slider,"edit"); slider:SetMinMaxValues(0,100); slider:SetValueStep(10); slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
        local thumb=slider:GetThumbTexture(); thumb:SetSize(12,22); thumb:SetVertexColor(unpack(addon.Skin.colors.gold))
        slider:SetScript("OnValueChanged",function(_,value)
            if not p.category then return end
            local volume=math.max(0,math.min(100,math.floor(value/10+0.5)*10))
            self.settings[p.category].volume=volume; p.volumeLabel:SetText("Alert volume: "..volume.."%")
            if self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
        end)
        local neutral=CreateFrame("Button",nil,p,"BackdropTemplate"); p.neutralPreview=neutral
        neutral:SetSize(180,30); neutral:SetPoint("TOPLEFT",264,-241)
        neutral.label=neutral:CreateFontString(nil,"OVERLAY","GameFontHighlight"); neutral.label:SetAllPoints(); neutral.label:SetText("Preview neutral rare")
        neutral.label:SetJustifyH("CENTER"); neutral.label:SetJustifyV("MIDDLE"); addon.Skin.Button(neutral,"utility")
        neutral:SetScript("OnEnter",function() addon.Skin.ButtonState(neutral,false,true,false) end)
        neutral:SetScript("OnLeave",function() addon.Skin.ButtonState(neutral,false,false,false) end)
        neutral:SetScript("OnClick",function() edit:ClearFocus(); self:Show("Example rare",30,"rare","Neutral","rares") end)
        text("Rares: spoken warning. Elites: siren. Green triangle marks detected creatures.\nAlerts re-arm after 30 seconds out of sight; paused during flights and while dead.",12,-352)
        p:SetScript("OnHide",function() edit:ClearFocus() end)
    end
    local p=self.page; if not p then return end
    if p.category and p.category~=(section=="Rares" and "rares" or "elites") then p.duration:ClearFocus() end
    p.category=section=="Rares" and "rares" or "elites"
    p:ClearAllPoints(); p:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y); p:SetSize(width,height); p:SetShown(visible)
    p.title:SetText(section=="Rares" and "Rare warnings" or "Elite warnings")
    for key,b in pairs(p.checks) do b:SetChecked(self.settings[p.category][key]); b.mark:SetText(b:GetChecked() and "X" or ""); b:Show() end
    p.checks.nonHostile.label:SetText(p.category=="rares" and "Include attackable neutral rares" or "Include attackable neutral elites")
    p.neutralPreview:SetShown(p.category=="rares")
    p.volume:SetValue(self.settings[p.category].volume)
    p.volumeLabel:SetText("Alert volume: "..self.settings[p.category].volume.."%")
    if not p.duration:HasFocus() then p.duration:SetText(tostring(self.settings[p.category].duration)) end
end

local events=CreateFrame("Frame"); H.events=events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,unit)
    if event=="ADDON_LOADED" then
        if unit~=addonName then return end
        H:Initialize(); events:UnregisterEvent("ADDON_LOADED")
        for _,name in ipairs({"PLAYER_REGEN_ENABLED","PLAYER_ENTERING_WORLD","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","UNIT_FACTION","UNIT_CLASSIFICATION_CHANGED"}) do events:RegisterEvent(name) end
    elseif event=="PLAYER_REGEN_ENABLED" then H:SyncTargetButton()
    elseif event=="NAME_PLATE_UNIT_REMOVED" then H.plates[unit]=nil
    elseif event=="NAME_PLATE_UNIT_ADDED" then H.plates[unit]=true; H:Inspect(unit)
    elseif event=="PLAYER_TARGET_CHANGED" then H:Inspect("target",true)
    elseif event=="UPDATE_MOUSEOVER_UNIT" then H:Inspect("mouseover")
    elseif event=="PLAYER_ENTERING_WORLD" then
        H.plates={}; H.pending={}; H.warning:Hide()
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
                local token=plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
                if token then H.plates[token]=true end
            end
        end
        H:Scan()
    elseif unit then H:Inspect(unit) end
end)
events:SetScript("OnUpdate",function(_,elapsed)
    H.elapsed=(H.elapsed or 0)+elapsed
    if H.elapsed>=1 then H.elapsed=0; if H.settings then H:Scan() end end
end)
