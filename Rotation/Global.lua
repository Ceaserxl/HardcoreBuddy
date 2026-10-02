-- Classic Era shared rotation assistant. Recommendations never execute combat actions.
local _,A=...
local R={spells={},highlights={},dirty=true,elapsed=0}; A.RotationAdvisor=R
R.supported={}; R.classes={}
R.modes={disabled="Disabled",assistant="Assistant Mode"}
R.categories={
    main={name="Main",color={1,1,1},description="Main (Gold): your next combat action, including setup or an urgent response."},
    offensive={name="Offensive Support",color={.8,.25,1},description="Offensive Support (Purple): optional damage cooldowns supporting Main."},
    defensive={name="Defensive",color={1,.15,.15},description="Defensive (Red): protection, escape, interrupts and situational control."},
    preparation={name="Preparation & Recovery",color={.15,.55,1},description="Preparation & Recovery (Blue): buffs, food, drinks and mana recovery."},
}
R.categoryOrder={"main","offensive","defensive","preparation"}
R.lookahead=2
R.definitions={}
function R:RegisterClass(token,module)
    self.classes[token]=module; self.definitions[token]=module.definitions or {}
    self.supported[token]=module.combat and module.name or nil
end
function R:Class(token) return self.classes[token or self.class] end
function R.CanAdvise(s) return not s.dead and not s.taxi end
function R.Ready(s,key,immediate)
    local a=s.spells[key]
    if not a or not a.ready or a.immune then return false end
    local usable=a.usable
    if immediate and a.usableNow~=nil then usable=a.usableNow end
    if not usable then return false end
    if immediate and ((a.cooldownRemaining or 0)>.15 or a.powerPreview) then return false end
    return not a.requiresRange or a.range==true or a.approaching==true
end
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
    if not A.ConsumableBuffs.classes[class] then return "disabled" end
    local mode=A.characterDB and A.characterDB.rotationMode
    return mode=="assistant" and mode or "disabled"
end
function R:SetMode(mode)
    if not A.characterDB or not self.modes[mode] then return end
    local _,class=UnitClass("player")
    if mode=="assistant" and not A.ConsumableBuffs.classes[class] then return end
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
    for level,entries in pairs(A.Data.ClassSpells[A.ConsumableBuffs.classes[class]] or {}) do
        for _,entry in ipairs(entries) do
            if known(entry.id) then
                local value=info(entry.id); local key=value and byName[value.name]
                if key and (not self.spells[key] or level>self.spells[key].level) then
                    self.spells[key]={id=entry.id,name=value.name,icon=value.iconID,level=level,rank=value.rank}
                end
            end
        end
    end
    local module=self:Class(class)
    if module and module.spellData then
        for id,data in pairs(module.spellData) do
            local current=self.spells[data.key]
            local currentData=current and module.spellData[current.id]
            if known(id) and (not currentData or data.rank>currentData.rank) then
                local value=info(id)
                if value then self.spells[data.key]={id=id,name=value.name,icon=value.iconID,level=data.level,rank=value.rank} end
            end
        end
    end
    if module and module.RefreshSpells then module.RefreshSpells(self) end
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
    local live=module and module.usesTalents and A.TalentAdvisor:ReadCurrent(class,UnitLevel("player"))
    self.talents=live and live.ranks or {}
    self.talentsReady=not not live; self.talentRetryAt=clock()+2
    self.damageProfile=nil
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
    local out,durations={},{}
    for i=1,40 do
        local a=aura(unit,i,filter); if not a then break end
        if a.name then
            local remaining=a.expirationTime and a.expirationTime>0 and math.max(0,a.expirationTime-clock()) or math.huge
            if remaining>0 and remaining>=(out[a.name] or 0) then out[a.name]=remaining; durations[a.name]=a.duration end
        end
    end
    return out,durations
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
    -- A positive duel-distance check fits inside the requested 10-yard area.
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
    s.gcdRemaining=0
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
    local horizon=self.lookahead -- Reaction lead even when no GCD is running.
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
    s.castSpellID=castID
    if castID then local module=self:Class(s.class); s.rotationCast=module and module.spellData and module.spellData[castID]~=nil or false end
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
            if not costs then
                if s.rotationCast~=false then projected=0 end
            else
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
        local module=self:Class(s and s.class)
        local reference=module and module.GCDReference and module.GCDReference(self)
        if reference then gcdStart,gcdDuration,gcdEnabled=cooldown(reference.id) end
    end
    if s and activeGCD() then s.gcdRemaining=math.max(s.gcdRemaining or 0,gcdStart+gcdDuration-now) end
    local onGCD=activeGCD() and type(start)=="number" and type(duration)=="number"
        and math.abs(start-gcdStart)<.05 and duration<=gcdDuration+.05
    local gcdLength=activeGCD() and gcdDuration or 1.5
    -- Plan for the end of the current cast/GCD, with at least two seconds of
    -- reaction time. GCD-only spells remain eligible throughout the GCD.
    local ready=enabled~=false and type(start)=="number" and type(duration)=="number"
        and (start+duration<=now or onGCD or duration>gcdLength and start+duration-now<=math.max(self.lookahead,s and s.powerHorizon or 0))
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
-- Observe sustained health loss, including the downtime between discrete spell hits.
-- A single burst is not enough evidence to shorten the next cast.
function R:TargetLife(s,guid)
    s.timeToDie=nil; s.healthTrendDuration=nil; s.healthTrendLosses=nil; s.healthTrendRate=nil
    local hp,t=s.targetHP,s.time
    local previous=self.healthSample
    local changed=not previous or previous.guid~=guid or not guid or not s.validTarget
    if changed then
        self.immune={}
        local module=self:Class(s.class)
        if module and module.ResetTarget then module.ResetTarget(self) end
    end
    if not guid or not s.validTarget or type(hp)~="number" or hp<=0 then
        self.healthSample=nil; return
    end
    if changed or not previous.hp or hp>previous.hp or t<previous.time or t-previous.time>4 then
        self.healthSample={guid=guid,time=t,hp=hp,samples={{time=t,hp=hp}}}
        return
    end
    local samples=previous.samples
    local last=samples[#samples]
    if hp<previous.hp then previous.lastLoss=t end
    if hp~=last.hp or t-last.time>=1 then samples[#samples+1]={time=t,hp=hp} end
    previous.time=t; previous.hp=hp
    -- Retain the observation before the window boundary so its damage interval
    -- includes the full elapsed time rather than treating a hit as instant DPS.
    while #samples>2 and samples[2].time<t-8 do table.remove(samples,1) end
    while #samples>64 do table.remove(samples,1) end
    local duration=t-samples[1].time
    local loss=samples[1].hp-hp
    local hits=0
    for i=2,#samples do if samples[i].hp<samples[i-1].hp then hits=hits+1 end end
    s.healthTrendDuration=duration; s.healthTrendLosses=hits
    if duration>=4 and hits>=2 and loss>0 and previous.lastLoss and t-previous.lastLoss<=6 then
        s.healthTrendRate=loss/duration
        s.timeToDie=math.min(120,hp/s.healthTrendRate)
    end
end

function R:ObserveCombat()
    local module=self:Class()
    if module and module.ObserveCombat then module.ObserveCombat(self) end
end
-- Compatibility adapter; the shared module also serves non-Mage characters.
function R:OutOfCombatSupplies(s)
    local result=A.ConsumableBuffs:Recommend(s,function(unit,filter) return self:Auras(unit,filter) end,self)
    self.supplyChecks=A.ConsumableBuffs.checks
    return result
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
    s.wanding=self:Class() and self:Class().usesWand and (self.autoRepeat or active==true or active==1) or false
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
    local buffs,durations=self:Auras("player","HELPFUL")
    s.drinking=A.ConsumableBuffs.IsDrinking(buffs)
    s.buffDurations={}
    for key,name in pairs(self.names) do s.buffs[key]=buffs[name]; s.buffDurations[key]=(durations or {})[name] end
    local module=self:Class()
    s.level=UnitLevel("player")
    if module and module.Snapshot then module.Snapshot(self,s) end
    for key,spell in pairs(self.spells) do
        local selfSpell=module and module.selfSpells and module.selfSpells[key]
        s.spells[key]=self:SpellState(spell,not selfSpell and "target" or nil,s)
        s.spells[key].immune=module and module.IsImmune and module.IsImmune(self,s,key,spell) or false
    end
    if module and module.Resources then module.Resources(self,s) end
    self:UpdateRangePreview(s)
    if module and module.Profile then s.damageProfile=module.Profile(self,s) end
    return s
end
function R.Decide(s)
    if not R.CanAdvise(s) then return nil,"" end
    local module=R:Class(s.class)
    if module and module.combat and module.Decide then return module.Decide(s) end
    return nil,"No consumable preparation needed."
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
local function colorHighlight(glow,category)
    local style=R.categories[category] and category or "main"
    local definition=R.categories[style]
    if glow.style==style then return end
    glow.style=style
    for _,texture in ipairs({glow.ProcStartFlipbook,glow.ProcLoopFlipbook}) do
        texture:SetDesaturated(style~="main")
        texture:SetVertexColor(definition.color[1],definition.color[2],definition.color[3],1)
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
function R:Highlight(spell,additional)
    self.highlightCount=0; self.primaryHighlightCount=0; self.optionalHighlightCount=0
    for button,glow in pairs(self.highlights) do
        local slot=button.action or button.GetAttribute and button:GetAttribute("action")
        local match=false
        local matched=spell
        if slot and GetActionInfo and button:IsVisible() then
            match=matchesAction(spell,slot)
            if not match then
                for _,extra in ipairs(additional or {}) do
                    if matchesAction(extra,slot) then match=true; matched=extra; break end
                end
            end
        end
        if match then colorHighlight(glow,matched and matched.category) end
        glow:SetShown(match)
        if match then
            self.highlightCount=self.highlightCount+1
            if glow.style~="main" then self.optionalHighlightCount=self.optionalHighlightCount+1
            else self.primaryHighlightCount=self.primaryHighlightCount+1 end
        end
    end
end
local function retainable(s,key)
    if not R.CanAdvise(s) or not s.validTarget or s.targetPlayer or s.controlled or not R.Ready(s,key) then return false end
    local module=R:Class(s.class)
    return module and module.Retainable and module.Retainable(s,key) or false
end
function R:StabilizeRecommendation(s,key,reason,optional,urgent)
    self.lockStatus="unlocked"
    -- The interruption event can arrive before UnitCastingInfo clears the cast.
    -- Never create a fresh plan from that briefly stale cast snapshot.
    if self.interruptedCastToken then
        if s.castToken==self.interruptedCastToken then
            if not urgent then self.lockStatus="interrupted-cast"; return nil,"",false end
        else self.interruptedCastToken=nil end
    end
    local plan=self.castPlan
    if plan then
        local spell=s.spells[plan.key]
        local sameCast=s.castToken==plan.token
        local handoff=not s.castToken and s.time>=plan.finish-.15 and s.time<=plan.finish+1
        if not urgent and plan.target==s.targetGUID and (sameCast or handoff) then
            if sameCast and s.castEnd then plan.finish=s.castEnd end -- Pushback can move the cast end.
            if spell and spell.id==plan.id and retainable(s,plan.key) then
                self.lockStatus="held"
                return plan.key,plan.reason,plan.optional
            end
            -- Do not replace a temporarily unavailable plan with a different
            -- damage spell halfway through the cast. Hide it until valid again.
            self.lockStatus="suppressed-invalid-plan"
            return nil,"",false
        end
        self.castPlan=nil
        self.lockStatus=urgent and "urgent-override" or "released"
    end
    -- Commit to the next damage action, not to a transient numerical ranking.
    -- New casts start a new plan; emergency advice and invalid actions bypass it.
    local spell=key and s.spells[key]
    if not urgent and not optional and s.rotationCast~=false and s.castToken and s.castEnd and s.targetGUID
        and (spell and retainable(s,key) or not spell and s.castToken:sub(1,5)=="cast:") then
        self.castPlan={token=s.castToken,finish=s.castEnd,target=s.targetGUID,key=key,id=spell and spell.id,reason=reason,optional=optional}
        self.lockStatus="new-plan"
    end
    return key,reason,optional
end
local function diagnosticValue(value)
    if type(value)=="number" then
        if value~=value then return "unknown" end
        if value==math.huge then return "infinite" end
        return math.floor(value*1000+.5)/1000
    end
    if type(value)=="string" or type(value)=="boolean" then return value end
end
local function diagnosticFields(source,fields)
    local out={}
    for word in fields:gmatch("%S+") do out[word]=diagnosticValue(source and source[word]) end
    return out
end
-- Each entry stores only fields that changed since the prior sample. No samples
-- are dropped; the first entry contains the complete state.
local function diagnosticDelta(before,after)
    if type(after)~="table" then
        if before==after then return nil end
        return after==nil and {remove=true} or {value=after}
    end
    local fields={}; local changed=false
    for key,value in pairs(after) do
        local prior
        if type(before)=="table" then prior=before[key] end
        local patch=diagnosticDelta(prior,value)
        if patch then fields[key]=patch; changed=true end
    end
    if type(before)=="table" then
        for key in pairs(before) do if after[key]==nil then fields[key]={remove=true}; changed=true end end
    end
    if changed or type(before)~="table" then return {fields=fields} end
end
function R:BeginDiagnostics()
    if self.loggingInitialized or not A.characterDB then return end
    self.loggingInitialized=true; self.logging=true; self.tracePrevious=nil
    local previous=A.characterDB.rotationDiagnostics
    if previous and (previous.count or 0)>0 then
        -- Keep at most three sessions: current, previous and second previous.
        -- Replacing the second previous releases the oldest capture.
        local older=A.characterDB.rotationDiagnosticsPrevious
        A.characterDB.rotationDiagnosticsPrevious2=older and (older.count or 0)>0 and older or nil
        A.characterDB.rotationDiagnosticsPrevious=previous
    end
    A.characterDB.rotationDiagnostics={version=2,startedAt=time and time(),count=0,total=0,entries={}}
end
function R:TraceRotation(event,force)
    if not self.logging or not A.characterDB then return end
    local log=A.characterDB.rotationDiagnostics
    if not log then return end
    local s=self.snapshot or {}; local now=clock()
    local row={time=now,wallTime=time and time(),event=event or "poll",mode=self:Mode(),
        reason=self.reason,lock=self.lockStatus,decision=self.traceDecision,
        selected=diagnosticFields(self.current,"id name item category"),
        primary=diagnosticFields(self.primary,"id name item category"),
        damageProfile=diagnosticFields(s.damageProfile,"main school damage"),
        plan=diagnosticFields(self.castPlan,"key id token finish target"),
        castEvent=diagnosticFields(self.lastCastEvent,"event time id token target"),
        state=diagnosticFields(s,"class level targetLevel targetBoss grouped targetCombat targetDotted scorchStacks scorchRemaining winterChillStacks spellHit haste time combat dead taxi moving mounted wanding drinking casting castToken castSpellID rotationCast castEnd channelKey channelRemaining gcdRemaining targetGUID validTarget targetPlayer targetHP targetHealth targetDistance targetClose controlled frozen frozenRemaining slowRemaining timeToDie healthTrendDuration healthTrendLosses healthTrendRate playerHealth power maxPower powerPercent projectedPower powerHorizon regenDelay normalRegen targets nearby cluster safeAOE safeCluster attackingPlayer recentDamage interrupt"),
        spells={},buffs={},buffDurations={},highlights={},optional={},ooc={},supplyChecks={},
        talents={},talentsReady=self.talentsReady,spellPower={},spellCrit={},
        intellectBlocker=diagnosticFields(s.intellectBlocker,"id power remaining")}
    for key,value in pairs(s.talents or {}) do row.talents[key]=diagnosticValue(value) end
    for school,value in pairs(s.spellPower or {}) do row.spellPower[school]=diagnosticValue(value) end
    for school,value in pairs(s.spellCrit or {}) do row.spellCrit[school]=diagnosticValue(value) end
    for id,check in pairs(self.supplyChecks or {}) do
        row.supplyChecks[id]=diagnosticFields(check,"tracking owned family name spellID usable cooldownStart cooldownDuration enabled auraRemaining buffRemaining eligible itemInfoAvailable")
    end
    for key,value in pairs(s.buffs or {}) do row.buffs[key]=diagnosticValue(value) end
    for key,value in pairs(s.buffDurations or {}) do row.buffDurations[key]=diagnosticValue(value) end
    for key,spell in pairs(s.spells or {}) do
        local entry=diagnosticFields(spell,"id name item ready usable usableNow immune range requiresRange approaching powerPreview plannedPower cost castTime cooldownRemaining lowPower category")
        local module=self:Class(s.class)
        local estimate=module and module.Estimate and module.Estimate(s,key)
        if estimate then entry.estimate=diagnosticFields(estimate,"score damage cast cost school") end
        row.spells[key]=entry
    end
    for _,spell in ipairs(self.optionalActions or {}) do row.optional[#row.optional+1]=diagnosticFields(spell,"id name item category") end
    for _,spell in ipairs(self.oocActions or {}) do row.ooc[#row.ooc+1]=diagnosticFields(spell,"id name item category") end
    for button,glow in pairs(self.highlights) do
        if glow:IsShown() then
            local slot=button.action or button.GetAttribute and button:GetAttribute("action")
            local kind,id,subtype
            if slot and GetActionInfo then kind,id,subtype=GetActionInfo(slot) end
            row.highlights[#row.highlights+1]={button=button.GetName and button:GetName(),slot=slot,
                kind=kind,id=id,subtype=subtype,resolvedSpell=actionSpell(slot),style=glow.style}
        end
    end
    row.highlightCount=self.highlightCount
    row.time=nil -- Entry timestamp is stored once, outside the delta.
    log.count=log.count+1; log.total=log.count
    log.entries[log.count]={time=now,delta=diagnosticDelta(self.tracePrevious,row)}
    self.tracePrevious=row
end
function R:Diagnostics(command)
    self:BeginDiagnostics()
    command=command and command~="" and command or "status"
    if command=="mark" then self:TraceRotation("USER_MARK",true)
    elseif command~="status" then A:Print("Rotation logging is automatic. Use /hcb rotation log mark or status."); return end
    local log=A.characterDB.rotationDiagnostics
    A:Print("Rotation logging automatically | "..(log and log.count or 0).." samples. /hcb rotation log mark flags an issue.")
    if command=="status" then
        A:Print("After /reload or logout, current and previous logs are in "..A.DebugDump:SavedPath())
    end
end
function R:Update(event)
    if not A.characterDB then return end
    self:BeginDiagnostics()
    self.supplyChecks=nil
    if self.suspended or self:Mode()=="disabled" then
        self.traceDecision=nil; self.lockStatus="disabled"
        self.approach=nil; self.powerSample=nil; self.healthSample=nil; self.immune=nil; self.lastDamage=nil; self.castPlan=nil
        self.current=nil; self.primary=nil; self.optional=nil; self.optionalActions={}; self.oocActions={}; self.snapshot=nil; self.reason=self.suspended and "Loading character..." or "Enable Assistant Mode in Settings."; self:Highlight(nil)
    else
        self.snapshot=self:Snapshot()
        local key,reason,optional,urgent
        if self.supported[self.snapshot.class] then key,reason,optional,urgent=self.Decide(self.snapshot)
        else reason="No consumable preparation needed." end
        self.traceDecision=self.logging and {key=key,reason=reason,optional=optional,urgent=urgent} or nil
        key,reason,optional=self:StabilizeRecommendation(self.snapshot,key,reason,optional,urgent)
        local selected=key and self.snapshot.spells[key]
        if selected then selected.category=optional and "preparation" or "main" end
        self.primary=not optional and selected or nil
        self.optionalActions={}
        local module=self:Class(self.snapshot.class)
        local choices=module and module.Optional and module.Optional(self.snapshot) or {}
        for _,choice in ipairs(choices) do
            local spell=self.snapshot.spells[choice.key]
            if spell and spell~=selected then
                spell.category=choice.category
                self.optionalActions[#self.optionalActions+1]=spell
            end
        end
        self.current=selected or self.optionalActions[1]
        self.reason=selected and reason or choices[1] and choices[1].reason or reason
        self.optional=not not (self.current and not self.primary)
        self.oocActions={}
        if not self.snapshot.combat and not urgent and not self.castPlan and not self.snapshot.rotationCast then
            if selected and optional then self.oocActions[#self.oocActions+1]=selected end
            for _,spell in ipairs(self.optionalActions) do self.oocActions[#self.oocActions+1]=spell end
            for _,spell in ipairs(self:OutOfCombatSupplies(self.snapshot)) do self.oocActions[#self.oocActions+1]=spell end
        end
        if #self.oocActions>0 then
            self.primary=nil; self.current=self.oocActions[1]; self.optional=true
            self.reason="Prepare and recover. Blue actions can be used as needed."
            self:Highlight(nil,self.oocActions)
        else self:Highlight(selected,self.optionalActions) end
    end
    self:TraceRotation(event)
    if self.RefreshView then self:RefreshView() end
end
local events=CreateFrame("Frame"); R.events=events
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("UI_ERROR_MESSAGE")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","SPELLS_CHANGED","SPELL_DATA_LOAD_RESULT","PLAYER_TALENT_UPDATE","PLAYER_REGEN_ENABLED","ACTIONBAR_SLOT_CHANGED","ACTIONBAR_PAGE_CHANGED","PLAYER_TARGET_CHANGED","START_AUTOREPEAT_SPELL","STOP_AUTOREPEAT_SPELL"}) do events:RegisterEvent(event) end
for _,event in ipairs({"UNIT_POWER_UPDATE","UNIT_POWER_FREQUENT","UNIT_MAXPOWER","UNIT_SPELLCAST_SENT","UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_FAILED","UNIT_SPELLCAST_FAILED_QUIET","UNIT_SPELLCAST_START","UNIT_SPELLCAST_STOP","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP"}) do events:RegisterEvent(event) end
for _,event in ipairs({"MODIFIER_STATE_CHANGED","UPDATE_MACROS","ACTIONBAR_UPDATE_STATE"}) do events:RegisterEvent(event) end
events:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
for _,event in ipairs({"COMBAT_LOG_EVENT_UNFILTERED","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","CHARACTER_POINTS_CHANGED","UNIT_AURA","LOSS_OF_CONTROL_ADDED","LOSS_OF_CONTROL_UPDATE"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit,message,castID,sentSpellID)
    if event=="PLAYER_LOGOUT" then
        R:TraceRotation("PLAYER_LOGOUT",true)
        if A.characterDB and A.characterDB.rotationDiagnostics then A.characterDB.rotationDiagnostics.endedAt=time and time() end
        return
    end
    if event=="UI_ERROR_MESSAGE" then R:TraceRotation(event..":"..tostring(message or unit),true); return end
    if event=="COMBAT_LOG_EVENT_UNFILTERED" then
        if R:Mode()=="assistant" and R:Class() and R:Class().ObserveCombat and not R.suspended then R:ObserveCombat() end
        return
    end
    if event:sub(1,5)=="UNIT_" then
        if unit=="player" and event:sub(1,15)=="UNIT_SPELLCAST_" then
            local sent=event=="UNIT_SPELLCAST_SENT"
            R.lastCastEvent={event=event,time=clock(),id=sent and sentSpellID or castID,
                token=sent and castID or message,target=sent and message or nil}
        end
        if unit=="player" and event=="UNIT_SPELLCAST_INTERRUPTED" and type(message)=="string" then
            R.interruptedCastToken="cast:"..message
            if R.castPlan and R.castPlan.token==R.interruptedCastToken then R.castPlan=nil end
        end
        if (unit=="player" or event=="UNIT_AURA" and unit=="target") and not R.suspended and R:Mode()~="disabled" then R:Update(event) end
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
    R:PrepareHighlights(); R:Update(event)
end)
events:SetScript("OnUpdate",function(_,elapsed)
    R.elapsed=R.elapsed+elapsed; if R.elapsed<.2 then return end; R.elapsed=0
    if not R.suspended and R:Mode()~="disabled" then R:Update() end
end)

R.api={clock=clock,info=info,known=known,aura=aura,auraRemaining=auraRemaining,position=position,distance=distance,hostile=hostile}
