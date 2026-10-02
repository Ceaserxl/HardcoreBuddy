-- Classic Era proof of concept. Recommendations never execute combat actions.
local _,A=...
local R={spells={},highlights={},dirty=true,elapsed=0}; A.RotationAdvisor=R
R.supported={MAGE="Mage",ROGUE="Rogue"}
R.modes={disabled="Disabled",assistant="Assistant Mode"}
R.definitions={
    MAGE={frostbolt=116,fireball=133,fireblast=2136,nova=122,explosion=1449,
        counterspell=2139,barrier=11426,shield=1463,evocation=12051,shoot=5019},
    ROGUE={strike=1752,eviscerate=2098,slice=5171,kick=1766,evasion=5277,
        riposte=14251,hemorrhage=16511,flurry=13877,cheapshot=1833,throw=2764},
}
local ccIDs={118,6770,2094,1776,2637,9484,5782,6358}
local function clock() return GetTime and GetTime() or 0 end
local function combat() return InCombatLockdown and InCombatLockdown() or false end
local function info(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local value=C_Spell.GetSpellInfo(id)
        if value then return value end
    end
    if GetSpellInfo then
        local name,rank,icon,castTime=GetSpellInfo(id)
        if name then return {name=name,rank=rank,iconID=icon,castTime=castTime} end
    end
end
local function known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    return IsSpellKnown and IsSpellKnown(id,false) or false
end
function R:Mode()
    local mode=A.characterDB and A.characterDB.rotationMode
    return mode=="assistant" and mode or "disabled"
end
function R:SetMode(mode)
    if not A.characterDB or not self.modes[mode] then return end
    local _,class=UnitClass("player")
    if mode=="assistant" and not self.supported[class] then return end
    A.characterDB.rotationMode=mode; self.dirty=true; self:Update()
    if A.window and A.window:IsShown() then A:Refresh() end
end
function R:RefreshSpells()
    local _,class=UnitClass("player"); self.class=class; self.spells={}; self.names={}; self.ccNames={}
    local byName={}
    for key,id in pairs(self.definitions[class] or {}) do
        local value=info(id)
        if value then
            self.names[key]=value.name; byName[value.name]=key
            if known(id) then self.spells[key]={id=id,name=value.name,icon=value.iconID,level=0,rank=value.rank} end
        end
    end
    for level,entries in pairs(A.Data.ClassSpells[self.supported[class]] or {}) do
        for _,entry in ipairs(entries) do
            if known(entry.id) then
                local value=info(entry.id); local key=value and byName[value.name]
                if key and (not self.spells[key] or level>self.spells[key].level) then
                    self.spells[key]={id=entry.id,name=value.name,icon=value.iconID,level=level,rank=value.rank}
                end
            end
        end
    end
    if C_Spell and C_Spell.GetSpellSubtext then
        for _,spell in pairs(self.spells) do spell.rank=C_Spell.GetSpellSubtext(spell.id) end
    end
    for _,id in ipairs(ccIDs) do local value=info(id); if value then self.ccNames[value.name]=true end end
    self.dirty=false
end
local function percent(unit,power)
    local value,maximum
    if power~=nil then
        if UnitPower and UnitPowerMax then value,maximum=UnitPower(unit,power),UnitPowerMax(unit,power) end
    elseif UnitHealth and UnitHealthMax then value,maximum=UnitHealth(unit),UnitHealthMax(unit) end
    if type(value)=="number" and type(maximum)=="number" and maximum>0 then
        return math.max(0,math.min(100,value/maximum*100)),value,maximum
    end
end
local function aura(unit,index,filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then return C_UnitAuras.GetAuraDataByIndex(unit,index,filter) end
    if UnitAura then
        local name,_,_,_,duration,expiration,source,_,_,id=UnitAura(unit,index,filter)
        if name then return {name=name,duration=duration,expirationTime=expiration,sourceUnit=source,spellId=id} end
    end
end
function R:Auras(unit,filter)
    local out={}
    for i=1,40 do
        local a=aura(unit,i,filter); if not a then break end
        if a.name then
            local remaining=a.expirationTime and a.expirationTime>0 and math.max(0,a.expirationTime-clock()) or math.huge
            if remaining>0 then out[a.name]=math.max(out[a.name] or 0,remaining) end
        end
    end
    return out
end
function R:Controlled(unit)
    for name in pairs(self:Auras(unit,"HARMFUL")) do if self.ccNames[name] then return true end end
    return false
end
local function hostile(unit)
    return UnitExists and UnitExists(unit) and UnitCanAttack and UnitCanAttack("player",unit)
        and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit))
end
local function close(unit,radius)
    radius=radius or 10
    if UnitPosition then
        local px,py,pz,pm=UnitPosition("player"); local x,y,z,m=UnitPosition(unit)
        if px and py and pz and x and y and z and pm and pm==m then
            return (px-x)^2+(py-y)^2+(pz-z)^2<=radius*radius
        end
    end
    -- A positive duel-distance check fits inside the Mage's 10-yard area.
    -- A negative check is not proof that an enemy is outside that area.
    if radius>=10 and CheckInteractDistance and CheckInteractDistance(unit,3) then return true end
    if radius==5 and R.spells.strike then
        local value
        if C_Spell and C_Spell.IsSpellInRange then value=C_Spell.IsSpellInRange(R.spells.strike.id,unit)
        elseif IsSpellInRange then value=IsSpellInRange(R.spells.strike.name,unit) end
        if value==true or value==1 then return true end
        if value==false or value==0 then return false end
    end
    return nil
end
function R:Enemies()
    local units={"target"}
    if C_NamePlate and C_NamePlate.GetNamePlates then
        for i,plate in ipairs(C_NamePlate.GetNamePlates()) do
            if i>40 then break end
            local unit=plate.namePlateUnitToken or plate.UnitFrame and plate.UnitFrame.unit
            if unit then units[#units+1]=unit end
        end
    end
    local seen,count,nearby,unsafe={},0,0,false
    for _,unit in ipairs(units) do
        local guid=UnitGUID and UnitGUID(unit)
        if guid and not seen[guid] and hostile(unit) then
            seen[guid]=true
            local threat=UnitThreatSituation and UnitThreatSituation("player",unit)
            local engaged=threat~=nil or UnitIsUnit and (UnitIsUnit(unit.."target","player") or UnitIsUnit(unit.."target","pet"))
            if engaged then count=count+1 end
            local near=close(unit,self.class=="ROGUE" and 5 or 10)
            if near then
                if engaged then nearby=nearby+1 end
                if not engaged or self:Controlled(unit) then unsafe=true end
            elseif near==nil then unsafe=true end -- Unknown proximity cannot establish safe AoE.
        end
    end
    return count,nearby,not unsafe
end
local function cooldown(id)
    if C_Spell and C_Spell.GetSpellCooldown then
        local c=C_Spell.GetSpellCooldown(id)
        if c then return c.startTime,c.duration,c.isEnabled~=false end
    elseif GetSpellCooldown then
        local start,duration,enabled=GetSpellCooldown(id); return start,duration,enabled~=0
    end
end
function R:SpellState(spell,unit)
    local usable,lowPower
    if C_Spell and C_Spell.IsSpellUsable then usable,lowPower=C_Spell.IsSpellUsable(spell.id)
    elseif IsUsableSpell then usable,lowPower=IsUsableSpell(spell.name) end
    local start,duration,enabled=cooldown(spell.id)
    local gcdStart,gcdDuration=cooldown(61304)
    local onGCD=start and gcdStart and duration and gcdDuration and math.abs(start-gcdStart)<.05 and math.abs(duration-gcdDuration)<.05
    local ready=enabled~=false and type(start)=="number" and type(duration)=="number"
        and (start+duration<=clock()+.05 or onGCD)
    local range
    if unit then
        if C_Spell and C_Spell.IsSpellInRange then range=C_Spell.IsSpellInRange(spell.id,unit)
        elseif IsSpellInRange then range=IsSpellInRange(spell.name,unit) end
        if range==1 then range=true elseif range==0 then range=false end
    end
    return {id=spell.id,name=spell.name,icon=spell.icon,rank=spell.rank,ready=not not ready,usable=usable==true or usable==1,
        lowPower=not not lowPower,range=range}
end
function R:Snapshot()
    if self.dirty then self:RefreshSpells() end
    local s={class=self.class,spells={},buffs={},combat=combat(),validTarget=hostile("target"),time=clock()}
    s.dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    s.mounted=IsMounted and IsMounted() or UnitOnTaxi and UnitOnTaxi("player")
    s.playerHealth=percent("player"); s.targetHealth=percent("target"); s.petHealth=percent("pet")
    s.hasPet=UnitExists and UnitExists("pet") or false
    s.powerType=UnitPowerType and UnitPowerType("player") or (self.class=="ROGUE" and 3 or 0)
    s.powerPercent,s.power=percent("player",s.powerType)
    s.targetPowerType=UnitPowerType and UnitPowerType("target")
    if s.targetPowerType==0 then s.targetMana=percent("target",0) end
    s.combo=GetComboPoints and GetComboPoints("player","target") or 0
    s.moving=GetUnitSpeed and GetUnitSpeed("player")>0 or false
    s.stealthed=IsStealthed and IsStealthed() or false
    s.casting=(UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))
    s.attackingPlayer=UnitIsUnit and UnitIsUnit("targettarget","player") or false
    s.targetPlayer=UnitIsPlayer and UnitIsPlayer("target") or false
    s.targetCombat=UnitAffectingCombat and not not UnitAffectingCombat("target")
    s.thrownEquipped=self.class=="ROGUE" and A.Ammunition.Kind()=="thrown"
    s.targetClose=close("target",self.class=="ROGUE" and 5 or 10); s.controlled=s.validTarget and self:Controlled("target")
    local currentSpell=C_Spell and C_Spell.IsCurrentSpell or IsCurrentSpell
    local active=self.spells.shoot and currentSpell and currentSpell(self.spells.shoot.id)
    s.wanding=self.class=="MAGE" and (self.autoRepeat or active==true or active==1) or false
    s.targets,s.nearby,s.safeAOE=self:Enemies()
    local cast,finish,uninterruptible
    if UnitCastingInfo then
        local name,_,_,_,ending,_,_,blocked=UnitCastingInfo("target")
        cast,finish,uninterruptible=name,ending,blocked
    end
    if not cast and UnitChannelInfo then
        local name,_,_,_,ending,_,blocked=UnitChannelInfo("target")
        cast,finish,uninterruptible=name,ending,blocked
    end
    s.interrupt=cast~=nil and uninterruptible~=true and type(finish)=="number" and finish/1000>clock()
    local buffs=self:Auras("player","HELPFUL")
    for key,name in pairs(self.names) do s.buffs[key]=buffs[name] end
    for key,spell in pairs(self.spells) do
        local selfSpell=key=="barrier" or key=="shield" or key=="evocation" or key=="evasion" or key=="flurry" or key=="slice"
        s.spells[key]=self:SpellState(spell,not selfSpell and "target" or nil)
    end
    return s
end
-- Pure priorities make the prototype replayable without protected API calls.
function R.Decide(s)
    if not R.supported[s.class] then return nil,"This proof of concept supports Rogue and Mage." end
    if s.dead or s.mounted then return nil,s.dead and "You are dead." or "Dismount to use the advisor." end
    if s.casting then return nil,"Finish your current cast or channel." end
    local function can(key) local a=s.spells[key]; return a and a.ready and a.usable and a.range~=false end
    local function choose(key,reason) return key,reason end
    if s.class=="MAGE" and not s.combat and s.powerPercent and s.powerPercent<25 and can("evocation") then return choose("evocation","Recover mana between pulls.") end
    if not s.validTarget then return nil,"Select a living enemy." end
    if s.targetPlayer then return nil,"PvE prototype: player targets are not supported." end
    if s.controlled then return nil,"Target is crowd controlled. Avoid breaking it." end
    local hp,thp,mp=s.playerHealth,s.targetHealth,s.powerPercent
    if s.class=="ROGUE" then
        if not s.combat and s.targetCombat==false and not s.stealthed and not s.moving
            and s.targetClose==false and s.thrownEquipped and can("throw") and s.spells.throw.range==true then
            return "throw","Optional: pull with Throw, then let the enemy come to you.",true
        end
        if s.combat and hp and hp<=35 and s.attackingPlayer and s.targetClose and not s.buffs.evasion and can("evasion") then return choose("evasion","Low health while taking melee attacks.") end
        if s.interrupt and can("kick") then return choose("kick","Interrupt the target's cast.") end
        if s.stealthed and can("cheapshot") then return choose("cheapshot","Open from stealth with a stun.") end
        if can("riposte") then return choose("riposte","Riposte is available after a parry.") end
        if (s.combo or 0)>=5 or (s.combo or 0)>=3 and thp and thp<=20 then
            if can("eviscerate") then return choose("eviscerate","Spend combo points before the target dies.") end
        end
        if (s.combo or 0)>=1 and thp and thp>40 and (s.buffs.slice or 0)<3 and can("slice") then return choose("slice","Maintain Slice and Dice while the target has health remaining.") end
        if s.combat and s.nearby>=2 and s.safeAOE and thp and thp>30 and not s.buffs.flurry and can("flurry") then return choose("flurry","Multiple engaged enemies verified nearby.") end
        if can("hemorrhage") then return choose("hemorrhage","Build combo points with your learned Hemorrhage talent.") end
        if can("strike") then return choose("strike","Build combo points.") end
        return nil,"Wait for energy, cooldowns, or move into melee range."
    end
    if s.interrupt and can("counterspell") then return choose("counterspell","Interrupt the target's cast.") end
    if s.combat and hp and hp<=60 and not s.buffs.barrier and can("barrier") then return choose("barrier","Protect yourself at low health.") end
    if s.combat and hp and hp<=40 and s.targetClose and s.safeAOE and can("nova") then return choose("nova","Root nearby attackers to create distance.") end
    if s.combat and hp and hp<=35 and mp and mp>35 and not s.buffs.barrier and not s.buffs.shield and can("shield") then return choose("shield","Low health with enough mana for Mana Shield.") end
    if mp and mp<=15 and not s.moving and can("shoot") then
        if s.wanding then return nil,"Wand attack active. Let it continue to conserve mana." end
        return choose("shoot","Conserve mana with your wand.")
    end
    if s.combat and s.nearby>=3 and s.safeAOE and s.targetClose and mp and mp>=40 and hp and hp>55 and can("explosion") then return choose("explosion","At least three engaged enemies verified close; adequate mana and health.") end
    if (s.moving or thp and thp<=18) and can("fireblast") then return choose("fireblast",s.moving and "Use an instant spell while moving." or "Finish a low-health target.") end
    if s.moving then return nil,"Stop moving to cast, or wait for an instant spell." end
    if can("frostbolt") then return choose("frostbolt","Frost leveling filler: damage and a slowing effect.") end
    if can("fireball") then return choose("fireball","Use Fireball until Frostbolt is learned.") end
    if can("shoot") then
        if s.wanding then return nil,"Wand attack active. Let it continue." end
        return choose("shoot","Use your wand while mana or spells are unavailable.")
    end
    return nil,"No usable spell: check mana, range and learned spells."
end
local function sizeHighlight(glow)
    local button=glow:GetParent()
    local width,height=button:GetWidth(),button:GetHeight()
    -- The loop follows the button, but the native template leaves its burst at
    -- 150px (art authored for a 42px button). Scale both phases together so the
    -- burst does not snap to a different size when it becomes the loop.
    glow:SetSize(width*1.4,height*1.4)
    glow.ProcStartFlipbook:SetSize(width*150/42,height*150/42)
end
function R:PrepareHighlights()
    if combat() then return end
    for _,prefix in ipairs({"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton","MultiBar5Button","MultiBar6Button","MultiBar7Button"}) do
        for i=1,12 do
            local button=_G[prefix..i]
            if button and not self.highlights[button] then
                -- Use Blizzard's actual burst and looping proc animation. Keep our
                -- instance separate from button.SpellActivationAlert so clearing
                -- a recommendation cannot dismiss the button's real spell proc.
                local glow=CreateFrame("Frame",nil,button,"ActionButtonSpellAlertTemplate")
                glow:SetPoint("CENTER",button,"CENTER",0,0)
                glow:SetFrameLevel(button:GetFrameLevel()+8); glow:EnableMouse(false)
                glow:HookScript("OnShow",function(self)
                    self.ProcStartFlipbook:SetAlpha(1)
                    self.ProcLoopFlipbook:SetAlpha(0)
                    self.ProcStartAnim:Play()
                end)
                glow:HookScript("OnHide",function(self)
                    self.ProcStartAnim:Stop()
                    self.ProcLoop:Stop()
                end)
                button:HookScript("OnSizeChanged",function() sizeHighlight(glow) end)
                sizeHighlight(glow); glow:Hide()
                self.highlights[button]=glow
            end
        end
    end
end
local function colorHighlight(glow,optional)
    local style=optional and "optional" or "primary"
    if glow.style==style then return end
    glow.style=style
    for _,texture in ipairs({glow.ProcStartFlipbook,glow.ProcLoopFlipbook}) do
        -- Remove the gold baked into the artwork before tinting it blue.
        -- Primary recommendations retain Blizzard's original artwork colors.
        texture:SetDesaturated(not not optional)
        if optional then texture:SetVertexColor(.2,.6,1,1)
        else texture:SetVertexColor(1,1,1,1) end
    end
end
function R:Highlight(spell,optional)
    self.highlightCount=0
    for button,glow in pairs(self.highlights) do
        local slot=button.action or button.GetAttribute and button:GetAttribute("action")
        local kind,id
        if slot and GetActionInfo then kind,id=GetActionInfo(slot) end
        local match=false
        if spell and kind=="spell" and button:IsVisible() then
            match=id==spell.id -- Lower ranks with the same name are not the recommended spell.
        end
        if match then colorHighlight(glow,optional) end
        glow:SetShown(match)
        if match then self.highlightCount=self.highlightCount+1 end
    end
end
function R:Update()
    if not A.characterDB then return end
    if self.suspended or self:Mode()=="disabled" then
        self.current=nil; self.optional=nil; self.snapshot=nil; self.reason=self.suspended and "Loading character..." or "Enable Assistant Mode in Settings."; self:Highlight(nil)
    else
        self.snapshot=self:Snapshot()
        local key,reason,optional=self.Decide(self.snapshot)
        self.current=key and self.snapshot.spells[key]; self.reason=reason; self.optional=not not (self.current and optional)
        self:Highlight(self:Mode()=="assistant" and self.current or nil,self.optional)
    end
    if self.RefreshView then self:RefreshView() end
end
local events=CreateFrame("Frame"); R.events=events
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","SPELLS_CHANGED","SPELL_DATA_LOAD_RESULT","PLAYER_TALENT_UPDATE","PLAYER_REGEN_ENABLED","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","PLAYER_TARGET_CHANGED","START_AUTOREPEAT_SPELL","STOP_AUTOREPEAT_SPELL"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LEAVING_WORLD" then R.suspended=true; R.autoRepeat=nil; R:Highlight(nil); return end
    if event=="PLAYER_ENTERING_WORLD" then R.suspended=nil end
    if R.suspended then return end
    if event=="START_AUTOREPEAT_SPELL" then R.autoRepeat=true
    elseif event=="STOP_AUTOREPEAT_SPELL" then R.autoRepeat=nil end
    if event=="SPELLS_CHANGED" or event=="SPELL_DATA_LOAD_RESULT" or event=="PLAYER_TALENT_UPDATE" or event=="PLAYER_ENTERING_WORLD" then R.dirty=true end
    R:PrepareHighlights(); R:Update()
end)
events:SetScript("OnUpdate",function(_,elapsed)
    R.elapsed=R.elapsed+elapsed; if R.elapsed<.2 then return end; R.elapsed=0
    if not R.suspended and R:Mode()~="disabled" then R:Update() end
end)
