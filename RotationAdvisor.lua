-- Classic Era Mage assistant. Recommendations never execute combat actions.
local _,A=...
local R={spells={},highlights={},dirty=true,elapsed=0}; A.RotationAdvisor=R
R.supported={MAGE="Mage"}
R.modes={disabled="Disabled",assistant="Assistant Mode"}
R.definitions={MAGE=A.MageRotation.definitions}
local ccIDs={118,6770,2094,1776,2637,9484,5782,6358}
local function clock() return GetTime and GetTime() or 0 end
local function combat() return InCombatLockdown and InCombatLockdown() or false end
local function info(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local value=C_Spell.GetSpellInfo(id)
        if value then return value end
    end
    if GetSpellInfo then
        local name,rank,icon,castTime,minRange,maxRange=GetSpellInfo(id)
        if name then return {name=name,rank=rank,iconID=icon,castTime=castTime,minRange=minRange,maxRange=maxRange} end
    end
end
local function known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown then return C_SpellBook.IsSpellKnown(id) end
    return IsSpellKnown and IsSpellKnown(id,false) or false
end
function R:Mode()
    local _,class=UnitClass("player")
    if not self.supported[class] then return "disabled" end
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
    -- Includes the level-60 spell books absent from trainer-only listings.
    if class=="MAGE" then
        for id,data in pairs(A.Data.MageRotationSpells) do
            local current=self.spells[data.key]
            local currentData=current and A.Data.MageRotationSpells[current.id]
            if known(id) and (not currentData or data.rank>currentData.rank) then
                local value=info(id)
                if value then self.spells[data.key]={id=id,name=value.name,icon=value.iconID,level=data.level,rank=value.rank} end
            end
        end
    end
    if class=="MAGE" and known(116) and self.spells.frostbolt and self.spells.frostbolt.id~=116 then
        local value=info(116)
        if value then self.spells.slowbolt={id=116,name=value.name,icon=value.iconID,rank=value.rank} end
    end
    -- Nova is selected for control, not damage. Rank 1 has the same root duration
    -- at a lower mana cost; keep exact rank matching on the action bar.
    if class=="MAGE" and known(122) then
        local value=info(122)
        if value then self.spells.nova={id=122,name=value.name,icon=value.iconID,level=10,rank=value.rank} end
    end
    if C_Spell and C_Spell.GetSpellSubtext then
        for _,spell in pairs(self.spells) do spell.rank=C_Spell.GetSpellSubtext(spell.id) end
    end
    for key,spell in pairs(self.spells) do
        local value=info(spell.id)
        spell.minRange=value and value.minRange or 0
        spell.maxRange=value and value.maxRange or nil
        spell.castTime=value and type(value.castTime)=="number" and value.castTime/1000 or nil
    end
    for _,id in ipairs(ccIDs) do local value=info(id); if value then self.ccNames[value.name]=true end end
    local live=class=="MAGE" and A.TalentAdvisor:ReadCurrent("MAGE",UnitLevel("player"))
    self.talents=live and live.ranks or {}
    self.talentsReady=not not live; self.talentRetryAt=clock()+2
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
        local name,_,count,dispel,duration,expiration,source,_,_,id=UnitAura(unit,index,filter)
        if name then return {name=name,applications=count,dispelName=dispel,duration=duration,expirationTime=expiration,sourceUnit=source,spellId=id} end
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
local function rangeValue(value)
    if value==true or value==1 then return true end
    if value==false or value==0 then return false end
end
local function actionSpell(slot)
    if not slot or not GetActionInfo then return end
    local kind,id,subtype=GetActionInfo(slot)
    -- Classic exposes the currently selected spell for spell macros. Let
    -- Blizzard resolve modifiers, targets and sequences instead of parsing text.
    if kind=="spell" or kind=="macro" and subtype=="spell" then return id end
    if kind=="macro" and subtype~="item" and GetMacroSpell then
        local spell,_,legacyID=GetMacroSpell(id)
        if type(legacyID)=="number" then return legacyID end
        if type(spell)=="number" then return spell end
    end
end
local function spellRange(spell,unit)
    local value
    if C_Spell and C_Spell.IsSpellInRange then
        value=rangeValue(C_Spell.IsSpellInRange(spell.id,unit))
        if value==nil then value=rangeValue(C_Spell.IsSpellInRange(spell.name,unit)) end
    end
    if value==nil and IsSpellInRange then value=rangeValue(IsSpellInRange(spell.name,unit)) end
    -- Some Classic spells report range only through their action-bar slot.
    if value==nil and unit=="target" and GetActionInfo then
        for button in pairs(R.highlights) do
            local slot=button.action or button.GetAttribute and button:GetAttribute("action")
            if actionSpell(slot)==spell.id then
                if C_ActionBar and C_ActionBar.IsActionInRange then value=rangeValue(C_ActionBar.IsActionInRange(slot)) end
                if value==nil and IsActionInRange then value=rangeValue(IsActionInRange(slot,unit)) end
                if value~=nil then return value end
            end
        end
    end
    return value
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
            local engaged=(threat~=nil and UnitAffectingCombat and UnitAffectingCombat(unit)) or UnitIsUnit and (UnitIsUnit(unit.."target","player") or UnitIsUnit(unit.."target","pet"))
            if engaged then count=count+1 end
            local near=close(unit,10)
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
        if c then return c.startTime,c.duration,c.isEnabled~=false and c.isEnabled~=0 end
    end
    if GetSpellCooldown then
        local start,duration,enabled=GetSpellCooldown(id); return start,duration,enabled~=0
    end
end
local function powerCosts(id)
    if C_Spell and C_Spell.GetSpellPowerCost then return C_Spell.GetSpellPowerCost(id) end
    if GetSpellPowerCost then return GetSpellPowerCost(id) end
end
-- Forecast natural mana regeneration only, not unobserved procs or potions.
function R:PowerForecast(s)
    local previous=self.powerSample
    local sample={time=s.time,power=s.power,kind=s.powerType}
    if previous and previous.kind==s.powerType and s.time>=previous.time and s.time-previous.time<3 then
        sample.spent=previous.spent
        if s.power and previous.power and s.power<previous.power then sample.spent=s.time end
    end
    local normal,casting
    if GetPowerRegen then normal,casting=GetPowerRegen() end
    if s.powerType==0 and GetManaRegen then normal,casting=GetManaRegen() end
    normal=type(normal)=="number" and math.max(0,normal) or 0
    casting=type(casting)=="number" and math.max(0,casting) or 0
    self.powerSample=sample
    s.normalRegen=normal
    s.regenDelay=sample.spent and math.max(0,5-(s.time-sample.spent)) or s.combat and 5 or 0
    local horizon=1 -- Give the player reaction time even when no GCD is running.
    local start,duration,enabled=cooldown(61304)
    if enabled~=false and type(start)=="number" and type(duration)=="number" and duration<=1.55 then
        horizon=math.max(horizon,start+duration-s.time)
    end
    local cast,finish,castID
    if UnitCastingInfo then
        local name,_,_,starting,ending,_,token,_,id=UnitCastingInfo("player")
        cast,finish,castID=name,ending,id
        if name and token then s.castToken="cast:"..tostring(token)
        elseif name and type(starting)=="number" then s.castToken="cast:"..tostring(id or name)..":"..starting end
    end
    local channel
    if not cast and UnitChannelInfo then
        local name,_,_,starting,ending=UnitChannelInfo("player"); channel,finish=name,ending
        if name and type(starting)=="number" then s.castToken="channel:"..name..":"..starting end
    end
    s.castEnd=(cast or channel) and type(finish)=="number" and finish/1000 or nil
    if (cast or channel) and type(finish)=="number" then horizon=math.max(horizon,math.min(10,finish/1000-s.time)) end
    local projected=s.power or 0
    if s.powerType==0 then
        -- Unknown five-second-rule state uses the conservative casting rate.
        local suppressed=cast or channel or not sample.spent and s.combat
        local delay=suppressed and horizon or math.min(horizon,math.max(0,5-(s.time-(sample.spent or -math.huge))))
        projected=projected+casting*delay+normal*(horizon-delay)
        -- Mana for an ordinary cast can be charged at completion. Reserve it
        -- before predicting the following spell; unknown cast cost is conservative.
        if cast then
            local costs=powerCosts(castID or cast)
            if not costs then projected=0 else
                for _,cost in ipairs(costs) do
                    if cost.type==0 then projected=projected-(cost.cost or 0) end
                end
            end
        elseif channel then projected=s.power or 0 end
    end
    s.projectedPower=math.max(0,math.min(s.maxPower or projected,projected))
    s.powerHorizon=horizon
end
local function affordableSoon(spell,s)
    if not s or s.powerType~=0 or not s.power then return false end
    local costs=powerCosts(spell.id)
    if not costs then return false end
    local found=false
    for _,cost in ipairs(costs) do
        if not cost.requiredAuraID or cost.requiredAuraID==0 or cost.hasRequiredAura then
            local amount=cost.minCost or cost.cost
            if type(amount)~="number" or type(cost.type)~="number" then return false end
            if amount>0 then
                local available=cost.type==s.powerType and s.projectedPower or UnitPower and UnitPower("player",cost.type)
                if not available or available<amount then return false end
                if cost.type==s.powerType then found=true end
            end
        end
    end
    return found
end
function R:SpellState(spell,unit,s)
    local liveInfo=info(spell.id)
    local castTime=liveInfo and type(liveInfo.castTime)=="number" and liveInfo.castTime/1000 or spell.castTime
    local usable,lowPower
    if C_Spell and C_Spell.IsSpellUsable then usable,lowPower=C_Spell.IsSpellUsable(spell.id)
    elseif IsUsableSpell then usable,lowPower=IsUsableSpell(spell.name) end
    local start,duration,enabled=cooldown(spell.id)
    local now=clock()
    local gcdStart,gcdDuration,gcdEnabled=cooldown(61304)
    local function activeGCD()
        return gcdEnabled~=false and type(gcdStart)=="number" and type(gcdDuration)=="number"
            and gcdDuration>0 and gcdDuration<=1.55 and gcdStart+gcdDuration>now
    end
    if not activeGCD() then
        -- These learned damage spells have no intrinsic cooldown in Classic Era.
        -- Do not interpret a longer school lockout as a global cooldown.
        local reference=self.spells.frostbolt or self.spells.fireball
        if reference then gcdStart,gcdDuration,gcdEnabled=cooldown(reference.id) end
    end
    local onGCD=activeGCD() and type(start)=="number" and type(duration)=="number"
        and math.abs(start-gcdStart)<.05 and duration<=gcdDuration+.05
    local gcdLength=activeGCD() and gcdDuration or 1.5
    -- Plan for the end of the current cast/GCD, with at least one second of
    -- reaction time. GCD-only spells remain eligible throughout the GCD.
    local ready=enabled~=false and type(start)=="number" and type(duration)=="number"
        and (start+duration<=now or onGCD or duration>gcdLength and start+duration-now<=math.max(1,s and s.powerHorizon or 0))
    local range
    if unit then
        range=spellRange(spell,unit)
        -- Ground-targeted spells do not necessarily expose unit range queries.
        if range==nil and s and s.targetDistance and spell.maxRange and spell.maxRange>0
            and (spell.id==(self.spells.blizzard and self.spells.blizzard.id) or spell.id==(self.spells.flamestrike and self.spells.flamestrike.id)) then
            range=s.targetDistance<=spell.maxRange and s.targetDistance>=(spell.minRange or 0)
        end
    end
    local plannedPower=affordableSoon(spell,s)
    local missingPower=lowPower==true or lowPower==1
    local powerPreview=missingPower and plannedPower
    local costs=powerCosts(spell.id); local cost
    for _,entry in ipairs(costs or {}) do if entry.type==0 then cost=entry.minCost or entry.cost end end
    -- Mounting is not a combat-rule failure: show what to cast after dismounting.
    local mountedPreview=s and s.mounted and not s.taxi and not missingPower and costs~=nil
    local usableNow=usable==true or usable==1 or mountedPreview
    local available=usableNow or powerPreview
    -- Reserve mana charged when the current cast finishes before planning another.
    if unit and s and cost and s.projectedPower and s.projectedPower<cost and s.casting then available=false end
    return {id=spell.id,name=spell.name,icon=spell.icon,rank=spell.rank,ready=not not ready,
        powerPreview=not not powerPreview,plannedPower=plannedPower,usable=not not available,usableNow=not not usableNow,cost=cost,castTime=castTime,
        cooldownRemaining=type(start)=="number" and type(duration)=="number" and not onGCD and math.max(0,start+duration-now) or 0,
        lowPower=missingPower,range=range,requiresRange=unit~=nil,minRange=spell.minRange,maxRange=spell.maxRange}
end
local function applyRangePreview(s,sample)
    for key,spell in pairs(s.spells) do
        spell.approaching=false
        local limit=spell.maxRange or nil
        if spell.range==false and type(limit)=="number" and limit>0 then
            if sample.closing then
                spell.approaching=sample.distance>limit and sample.distance<=limit+2
                    and sample.projected<=limit and sample.projected>=(spell.minRange or 0)
            end
        end
    end
end
function R:UpdateRangePreview(s)
    for _,spell in pairs(s.spells) do spell.approaching=false end
    local guid=UnitGUID and UnitGUID("target")
    if not self.supported[s.class] or not s.validTarget or s.targetPlayer or s.controlled or s.dead
        or not guid then self.approach=nil; return false end
    local now=s.time
    local previous=self.approach
    if previous and previous.guid==guid and previous.class==s.class and now>=previous.time and now-previous.time<.05 then return applyRangePreview(s,previous) end
    local sample={guid=guid,class=s.class,time=now}
    if UnitPosition then
        sample.px,sample.py,sample.pz,sample.map=UnitPosition("player")
        sample.x,sample.y,sample.z,sample.targetMap=UnitPosition("target")
    end
    self.approach=sample
    if not previous or previous.guid~=guid or previous.class~=s.class then return false end
    local dt=now-previous.time
    if dt<.05 or dt>.6 then return false end
    local function positioned(v)
        return type(v.x)=="number" and type(v.y)=="number" and type(v.z)=="number"
            and type(v.px)=="number" and type(v.py)=="number" and type(v.pz)=="number"
            and v.map~=nil and v.map==v.targetMap
    end
    if positioned(sample) and positioned(previous) then
        if sample.map~=previous.map then return false end
        local dx,dy,dz=sample.x-sample.px,sample.y-sample.py,sample.z-sample.pz
        local distance=math.sqrt(dx*dx+dy*dy+dz*dz)
        local ox,oy,oz=previous.x-previous.px,previous.y-previous.py,previous.z-previous.pz
        local closing=(math.sqrt(ox*ox+oy*oy+oz*oz)-distance)/dt
        -- Require the enemy itself to approach, not just the player running at it.
        local enemyClosing=distance>0 and -((sample.x-previous.x)*dx+(sample.y-previous.y)*dy+(sample.z-previous.z)*dz)/(distance*dt) or 0
        sample.distance=distance; sample.projected=distance-closing*.5
        sample.closing=closing>.5 and closing<=20 and enemyClosing>.5 and enemyClosing<=20
    end
    return applyRangePreview(s,sample)
end
local function auraRemaining(a,now)
    return a.expirationTime and a.expirationTime>0 and math.max(0,a.expirationTime-now) or math.huge
end
local function position(unit)
    if not UnitPosition then return end
    local x,y,z,map=UnitPosition(unit)
    if type(x)=="number" and type(y)=="number" and type(z)=="number" and map~=nil then return {x=x,y=y,z=z,map=map} end
end
local function distance(a,b)
    if a and b and a.map==b.map then return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
end
function R:MageSnapshot(s)
    local M=A.MageRotation
    if not self.talentsReady and s.time>=(self.talentRetryAt or 0) then
        local live=A.TalentAdvisor:ReadCurrent("MAGE",UnitLevel("player"))
        self.talents=live and live.ranks or {}; self.talentsReady=not not live; self.talentRetryAt=s.time+2
    end
    s.level=UnitLevel("player"); s.targetLevel=UnitLevel("target")
    s.talents=self.talents or {}; s.spellPower={}; s.spellCrit={}
    s.spellHit=GetCombatRatingBonus and CR_HIT_SPELL and GetCombatRatingBonus(CR_HIT_SPELL) or 0
    s.haste=UnitSpellHaste and math.max(0,UnitSpellHaste("player") or 0)/100 or 0
    for _,school in ipairs({3,5,7}) do
        s.spellPower[school]=GetSpellBonusDamage and GetSpellBonusDamage(school) or 0
        s.spellCrit[school]=GetSpellCritChance and GetSpellCritChance(school) or 0
    end
    s.grouped=IsInGroup and IsInGroup() or false
    local classification=UnitClassification and UnitClassification("target")
    s.targetBoss=classification=="worldboss" or (UnitLevel and UnitLevel("target")==-1)
    local creature,creatureID
    if UnitCreatureType then creature,creatureID=UnitCreatureType("target") end
    s.polyEligible=creatureID==1 or creatureID==7 or creatureID==8
        or creature~=nil and (creature==HUMANOID or creature==BEAST or creature==CRITTER)
    s.recentDamage=self.lastDamage and s.time-self.lastDamage<3 or false
    s.damageSchool=s.recentDamage and self.damageSchool or nil
    if IsFalling and IsFalling() and not s.taxi then self.fallingSince=self.fallingSince or s.time
    else self.fallingSince=nil end
    s.fallingFor=self.fallingSince and s.time-self.fallingSince or 0
    for i=1,40 do
        local a=aura("player",i,"HELPFUL"); if not a then break end
        for key,id in pairs(M.buffIDs) do if a.spellId==id then s.buffs[key]=auraRemaining(a,s.time) end end
        -- Brilliance shares the Intellect benefit; never overwrite group buffs.
        if a.spellId==23028 then s.buffs.intellect=auraRemaining(a,s.time) end
    end
    s.hasArmor=s.buffs.frostarmor or s.buffs.icearmor or s.buffs.magearmor
    for i=1,40 do
        local a=aura("player",i,"HARMFUL"); if not a then break end
        if a.dispelName=="Curse" or a.debuffType=="Curse" then s.curse=true end
        if a.spellId==M.buffIDs.hypothermia then s.buffs.hypothermia=auraRemaining(a,s.time) end
    end
    for i=1,40 do
        local a=aura("target",i,"HARMFUL"); if not a then break end
        local left=auraRemaining(a,s.time)
        if a.spellId==M.debuffIDs.scorch then s.scorchStacks=a.applications or 1; s.scorchRemaining=left end
        if a.spellId==M.debuffIDs.winterschill then s.winterChillStacks=a.applications or 1 end
        if a.name==self.names.nova or a.spellId==M.debuffIDs.frostbite then s.frozen=true; s.frozenRemaining=left end
        if a.name==self.names.frostbolt or a.name==self.names.cone then s.slowRemaining=left end
        if a.name==self.names.fireball or a.name==self.names.pyroblast or a.name==self.names.flamestrike then s.targetDotted=true end
        -- Unknown harmful effects could be periodic damage from another player.
        -- Only known harmless control/vulnerability effects permit Polymorph.
        if a.name~=self.names.nova and a.name~=self.names.frostbolt and a.name~=self.names.cone
            and a.spellId~=M.debuffIDs.scorch and a.spellId~=M.debuffIDs.winterschill and a.spellId~=M.debuffIDs.frostbite then s.targetDotted=true end
    end
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount and C_LossOfControl.GetActiveLossOfControlData then
        for i=1,math.min(20,C_LossOfControl.GetActiveLossOfControlDataCount()) do
            local effect=C_LossOfControl.GetActiveLossOfControlData(i)
            if effect and (not effect.timeRemaining or effect.timeRemaining>0) then
                s.rooted=s.rooted or effect.locType=="ROOT"
                s.stunned=s.stunned or effect.locType=="STUN" or effect.locType=="STUN_MECHANIC"
            end
        end
    end
    local guid=UnitGUID and UnitGUID("target")
    s.targetGUID=guid
    if not guid or not self.healthSample or self.healthSample.guid~=guid or not s.validTarget then
        self.healthSample={guid=guid,time=s.time,hp=s.targetHP}; self.immune={}; self.flamestrike=nil
    else
        local previous=self.healthSample
        if s.time-previous.time>=1 then
            local loss=previous.hp and s.targetHP and previous.hp-s.targetHP or 0
            if loss>0 and s.time-previous.time<4 then
                local rate=loss/(s.time-previous.time)
                previous.rate=previous.rate and previous.rate*.5+rate*.5 or rate
            else previous.rate=nil end
            previous.time=s.time; previous.hp=s.targetHP
        end
        if previous.rate and previous.rate>0 then s.timeToDie=math.min(120,s.targetHP/previous.rate) end
    end
    s.flamestrikeActive=self.flamestrike and self.flamestrike>s.time or false
    if UnitChannelInfo then
        local name,_,_,_,ending=UnitChannelInfo("player")
        for key,spell in pairs(self.spells) do if name==spell.name then s.channelKey=key end end
        s.channelRemaining=type(ending)=="number" and math.max(0,ending/1000-s.time) or 0
    end
    local player,target=position("player"),position("target")
    s.targetDistance=distance(player,target)
    if player and target and player.map==target.map and GetPlayerFacing then
        local facing=GetPlayerFacing()
        if facing then
            local dx,dy=target.x-player.x,target.y-player.y
            local length=math.sqrt(dx*dx+dy*dy)
            s.facingTarget=length>0 and (math.cos(facing)*dx+math.sin(facing)*dy)/length>.707 and math.abs(target.z-player.z)<4
        end
    end
    s.cluster=0; s.safeCluster=target~=nil and s.targetCombat and not s.controlled
    if s.safeCluster then
        local seen={}; local units={"target"}
        if C_NamePlate and C_NamePlate.GetNamePlates then
            for i,plate in ipairs(C_NamePlate.GetNamePlates()) do
                if i>40 then break end
                local unit=plate.namePlateUnitToken or plate.UnitFrame and plate.UnitFrame.unit
                if unit then units[#units+1]=unit end
            end
        end
        for _,unit in ipairs(units) do
            local id=UnitGUID(unit)
            if id and not seen[id] and hostile(unit) then
                seen[id]=true
                local d=distance(target,position(unit))
                if not d then s.safeCluster=false
                elseif d<=8 then
                    local engaged=UnitAffectingCombat and UnitAffectingCombat(unit)
                    local threat=UnitThreatSituation and UnitThreatSituation("player",unit)
                    if not engaged or threat==nil or self:Controlled(unit) then s.safeCluster=false
                    else s.cluster=s.cluster+1 end
                end
            end
        end
    end
end
function R:ObserveCombat()
    if not CombatLogGetCurrentEventInfo then return end
    local _,event,_,source,_,_,_,dest,_,_,_,id,_,school,amount=CombatLogGetCurrentEventInfo()
    local now=clock(); local player=UnitGUID("player"); local target=UnitGUID("target")
    if dest==player and (event=="SPELL_DAMAGE" or event=="RANGE_DAMAGE" or event=="SPELL_PERIODIC_DAMAGE" or event=="SWING_DAMAGE") then
        self.lastDamage=now; self.damageSchool=event=="SWING_DAMAGE" and 1 or school
    end
    if source==player then
        local key
        for k,spell in pairs(self.spells) do if spell.id==id then key=k; break end end
        if key and event=="SPELL_MISSED" and amount=="IMMUNE" and dest==target then
            self.immune=self.immune or {}; self.immune[key]=now+15
            if key=="frostbolt" or key=="slowbolt" then self.immune.frostbolt=now+15; self.immune.slowbolt=now+15 end
        elseif event=="SPELL_CAST_SUCCESS" and key=="flamestrike" then self.flamestrike=now+8 end
    end
end
function R:MageResources(s)
    if s.class~="MAGE" then return end
    local ranged=GetInventoryItemID and GetInventoryItemID("player",18)
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if ranged and instant and UnitRangedDamage then
        local _,_,_,_,_,classID,subclass=instant(ranged)
        if classID==2 and subclass==19 then
            local speed,low,high=UnitRangedDamage("player")
            if type(speed)=="number" and speed>0 and type(low)=="number" and type(high)=="number" then
                s.wandSpeed=speed; s.wandDamage=(low+high)/2*.9 -- Allow for misses/resists; no crit assumption.
            end
        end
    end
    local count=C_Item and C_Item.GetItemCount or GetItemCount
    local itemCooldown=C_Container and C_Container.GetItemCooldown or C_Item and C_Item.GetItemCooldown or GetItemCooldown
    local itemInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
    local usable=C_Item and C_Item.IsUsableItem or IsUsableItem
    if not count then return end
    local checkedPreparation=false
    for _,gem in ipairs(A.MageRotation.gems) do
        local owned=count(gem.id,false,false) or 0 -- Bags only; never plan around bank gems.
        if not checkedPreparation and s.spells[gem.key] then
            checkedPreparation=true
            if owned==0 then s.prepareGem=gem.key end
        end
        if owned>0 and not s.spells.managem and itemCooldown and itemInfo and usable then
            local start,duration,enabled=itemCooldown(gem.id)
            local name,_,_,_,_,_,_,_,_,icon=itemInfo(gem.id)
            local available=usable(gem.id)
            if name and (available==true or available==1) and (enabled==1 or enabled==true)
                and type(start)=="number" and type(duration)=="number" and start+duration<=s.time then
                s.spells.managem={id=gem.id,item=true,name=name,icon=icon,restore=gem.maximum,
                    ready=true,usable=true,usableNow=true,cooldownRemaining=0}
            end
        end
    end
end
function R:Snapshot()
    if self.dirty then self:RefreshSpells() end
    local s={class=self.class,spells={},buffs={},combat=combat(),validTarget=hostile("target"),time=clock()}
    s.dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    s.mounted=IsMounted and IsMounted() or false
    s.taxi=UnitOnTaxi and UnitOnTaxi("player") or false
    s.playerHealth=percent("player"); s.targetHealth,s.targetHP=percent("target")
    s.powerType=UnitPowerType and UnitPowerType("player") or 0
    s.powerPercent,s.power,s.maxPower=percent("player",s.powerType)
    self:PowerForecast(s)
    s.targetPowerType=UnitPowerType and UnitPowerType("target")
    if s.targetPowerType==0 then s.targetMana=percent("target",0) end
    s.moving=GetUnitSpeed and GetUnitSpeed("player")>0 or false
    s.casting=(UnitCastingInfo and UnitCastingInfo("player")) or (UnitChannelInfo and UnitChannelInfo("player"))
    s.attackingPlayer=UnitIsUnit and UnitIsUnit("targettarget","player") or false
    s.targetPlayer=UnitIsPlayer and UnitIsPlayer("target") or false
    s.targetCombat=UnitAffectingCombat and not not UnitAffectingCombat("target")
    s.targetClose=close("target",10); s.controlled=s.validTarget and self:Controlled("target")
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
    self:MageSnapshot(s)
    for key,spell in pairs(self.spells) do
        local selfSpell=A.MageRotation.selfSpells[key]
        s.spells[key]=self:SpellState(spell,not selfSpell and "target" or nil,s)
        s.spells[key].immune=self.immune and self.immune[key] and self.immune[key]>s.time or false
    end
    self:MageResources(s)
    self:UpdateRangePreview(s)
    return s
end
R.Decide=A.MageRotation.Decide
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
        -- Remove the gold baked into the artwork before tinting it bright red.
        -- Primary recommendations retain Blizzard's original artwork colors.
        texture:SetDesaturated(not not optional)
        if optional then texture:SetVertexColor(1,.15,.15,1)
        else texture:SetVertexColor(1,1,1,1) end
    end
end
local function matchesAction(spell,slot)
    if not spell then return false end
    if not spell.item then return actionSpell(slot)==spell.id end
    local kind,id,subtype=GetActionInfo(slot)
    if kind=="macro" and subtype=="item" then kind="item"
    elseif kind=="macro" and GetMacroItem then
        local _,link=GetMacroItem(id)
        id=type(link)=="string" and tonumber(link:match("item:(%d+)")); kind="item"
    end
    return kind=="item" and id==spell.id
end
function R:Highlight(spell,optional,additional)
    self.highlightCount=0; self.primaryHighlightCount=0; self.optionalHighlightCount=0
    for button,glow in pairs(self.highlights) do
        local slot=button.action or button.GetAttribute and button:GetAttribute("action")
        local match,isOptional=false,optional
        if slot and GetActionInfo and button:IsVisible() then
            match=matchesAction(spell,slot)
            if not match then
                for _,extra in ipairs(additional or {}) do
                    if matchesAction(extra,slot) then match=true; isOptional=true; break end
                end
            end
        end
        if match then colorHighlight(glow,isOptional) end
        glow:SetShown(match)
        if match then
            self.highlightCount=self.highlightCount+1
            if isOptional then self.optionalHighlightCount=self.optionalHighlightCount+1
            else self.primaryHighlightCount=self.primaryHighlightCount+1 end
        end
    end
end
local function retainable(s,key)
    local M=A.MageRotation
    if s.dead or s.taxi or not s.validTarget or s.targetPlayer or s.controlled or (s.buffs.iceblock or 0)>0 then return false end
    if s.channelKey=="evocation" or s.channelKey and (s.channelRemaining or 0)>1 then return false end
    if not M.Ready(s,key) or key=="shoot" and s.wanding then return false end
    if key=="pyroblast" and s.combat and (s.buffs.presence or 0)==0 then return false end
    if M.ground[key] then
        local kiteWindow=s.targetDistance and s.targetDistance>=20 and ((s.slowRemaining or 0)>2 or s.frozen)
            and (s.talents.improvedBlizzard or 0)>=2
        return s.safeCluster and (s.cluster or 0)>=3 and not s.moving
            and (s.playerHealth or 100)>55 and (s.powerPercent or 100)>35
            and (not s.attackingPlayer or key=="blizzard" and kiteWindow)
            and (key~="flamestrike" or not s.flamestrikeActive)
    elseif M.area[key] then
        return s.safeAOE and s.targetClose and (s.playerHealth or 100)>55 and (s.powerPercent or 100)>30
            and (key=="cone" and s.facingTarget or s.nearby>=3)
    end
    return true
end
function R:StabilizeRecommendation(s,key,reason,optional,urgent)
    local plan=self.castPlan
    if plan then
        local spell=s.spells[plan.key]
        local sameCast=s.castToken==plan.token
        local handoff=not s.castToken and s.time>=plan.finish-.15 and s.time<=plan.finish+1
        if not urgent and plan.target==s.targetGUID and spell and spell.id==plan.id
            and (sameCast or handoff) and retainable(s,plan.key) then
            if sameCast and s.castEnd then plan.finish=s.castEnd end -- Pushback can move the cast end.
            return plan.key,plan.reason,plan.optional
        end
        self.castPlan=nil
    end
    -- Commit to the next damage action, not to a transient numerical ranking.
    -- New casts start a new plan; emergency advice and invalid actions bypass it.
    local spell=key and s.spells[key]
    if not urgent and not optional and spell and (A.Data.MageRotationSpells[spell.id] or key=="shoot")
        and s.castToken and s.castEnd and s.targetGUID and retainable(s,key) then
        self.castPlan={token=s.castToken,finish=s.castEnd,target=s.targetGUID,key=key,id=spell.id,reason=reason,optional=optional}
    end
    return key,reason,optional
end
function R:Update()
    if not A.characterDB then return end
    if self.suspended or self:Mode()=="disabled" then
        self.approach=nil; self.powerSample=nil; self.healthSample=nil; self.immune=nil; self.lastDamage=nil; self.castPlan=nil
        self.current=nil; self.primary=nil; self.optional=nil; self.optionalActions={}; self.snapshot=nil; self.reason=self.suspended and "Loading character..." or "Enable Assistant Mode in Settings."; self:Highlight(nil)
    else
        self.snapshot=self:Snapshot()
        local key,reason,optional,urgent=self.Decide(self.snapshot)
        key,reason,optional=self:StabilizeRecommendation(self.snapshot,key,reason,optional,urgent)
        self.primary=key and self.snapshot.spells[key]
        self.optionalActions={}
        local choices=A.MageRotation.Optional(self.snapshot)
        for _,choice in ipairs(choices) do
            local spell=self.snapshot.spells[choice.key]
            if spell and spell~=self.primary then self.optionalActions[#self.optionalActions+1]=spell end
        end
        self.current=self.primary or self.optionalActions[1]
        self.reason=self.primary and reason or choices[1] and choices[1].reason or reason
        self.optional=not not (self.current and not self.primary)
        self:Highlight(self.primary,false,self.optionalActions)
    end
    if self.RefreshView then self:RefreshView() end
end
local events=CreateFrame("Frame"); R.events=events
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","SPELLS_CHANGED","SPELL_DATA_LOAD_RESULT","PLAYER_TALENT_UPDATE","PLAYER_REGEN_ENABLED","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","PLAYER_TARGET_CHANGED","START_AUTOREPEAT_SPELL","STOP_AUTOREPEAT_SPELL"}) do events:RegisterEvent(event) end
for _,event in ipairs({"UNIT_POWER_UPDATE","UNIT_POWER_FREQUENT","UNIT_MAXPOWER","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP"}) do events:RegisterEvent(event) end
for _,event in ipairs({"MODIFIER_STATE_CHANGED","UPDATE_MACROS","ACTIONBAR_UPDATE_STATE"}) do events:RegisterEvent(event) end
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
for _,event in ipairs({"COMBAT_LOG_EVENT_UNFILTERED","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","CHARACTER_POINTS_CHANGED","UNIT_AURA","LOSS_OF_CONTROL_ADDED","LOSS_OF_CONTROL_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if event=="COMBAT_LOG_EVENT_UNFILTERED" then
        if R:Mode()=="assistant" and R.class=="MAGE" and not R.suspended then R:ObserveCombat() end
        return
    end
    if event:sub(1,5)=="UNIT_" then
        if unit=="player" and event=="UNIT_SPELLCAST_INTERRUPTED" then R.castPlan=nil end
        if (unit=="player" or event=="UNIT_AURA" and unit=="target") and not R.suspended and R:Mode()~="disabled" then R:Update() end
        return
    end
    if event=="PLAYER_TARGET_CHANGED" or event=="PLAYER_LEAVING_WORLD" or event=="PLAYER_ENTERING_WORLD" then R.approach=nil; R.castPlan=nil end
    if event=="PLAYER_LEAVING_WORLD" then R.suspended=true; R.autoRepeat=nil; R.powerSample=nil; R:Highlight(nil); return end
    if event=="PLAYER_ENTERING_WORLD" then R.suspended=nil end
    if R.suspended then return end
    if event=="START_AUTOREPEAT_SPELL" then R.autoRepeat=true
    elseif event=="STOP_AUTOREPEAT_SPELL" then R.autoRepeat=nil end
    if event=="SPELLS_CHANGED" or event=="SPELL_DATA_LOAD_RESULT" or event=="PLAYER_TALENT_UPDATE" or event=="PLAYER_ENTERING_WORLD"
        or event=="PLAYER_EQUIPMENT_CHANGED" or event=="PLAYER_LEVEL_UP" or event=="CHARACTER_POINTS_CHANGED" then R.dirty=true end
    R:PrepareHighlights(); R:Update()
end)
events:SetScript("OnUpdate",function(_,elapsed)
    R.elapsed=R.elapsed+elapsed; if R.elapsed<.2 then return end; R.elapsed=0
    if not R.suspended and R:Mode()~="disabled" then R:Update() end
end)
