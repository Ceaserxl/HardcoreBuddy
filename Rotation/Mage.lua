-- Classic Era Mage priorities. All output is advice; never casts or targets.
local _,A=...
local M={name="Mage",combat=true,usesTalents=true,usesWand=true}; A.MageRotation=M
local R=A.RotationAdvisor
local clock,info,known,aura,auraRemaining,position,distance,hostile=R.api.clock,R.api.info,R.api.known,R.api.aura,R.api.auraRemaining,R.api.position,R.api.distance,R.api.hostile
M.spellData=A.Data.MageRotationSpells
M.definitions={
    fireball=133,frostbolt=116,fireblast=2136,missiles=5143,scorch=2948,pyroblast=11366,
    explosion=1449,blizzard=10,flamestrike=2120,cone=120,blastwave=11113,
    counterspell=2139,nova=122,barrier=11426,shield=1463,iceblock=11958,blink=1953,
    coldsnap=12472,evocation=12051,shoot=5019,polymorph=118,decurse=475,
    intellect=1459,frostarmor=168,icearmor=7302,magearmor=6117,fireward=543,frostward=6143,
    presence=12043,arcanepower=12042,combustion=11129,slowfall=130,
    agate=759,jade=3552,citrine=10053,ruby=10054,
}
M.gems={{key="ruby",id=8008,maximum=1200},{key="citrine",id=8007,maximum=925},
    {key="jade",id=5513,maximum=650},{key="agate",id=5514,maximum=425}}
M.selfSpells={explosion=true,nova=true,cone=true,blastwave=true,barrier=true,shield=true,
    iceblock=true,blink=true,coldsnap=true,evocation=true,intellect=true,frostarmor=true,
    icearmor=true,magearmor=true,fireward=true,frostward=true,presence=true,arcanepower=true,combustion=true,decurse=true,slowfall=true}
M.area={explosion=true,nova=true,cone=true,blastwave=true,blizzard=true,flamestrike=true}
M.ground={blizzard=true,flamestrike=true}
for _,gem in ipairs(M.gems) do M.selfSpells[gem.key]=true end
M.buffIDs={clearcasting=12536,presence=12043,arcanepower=12042,combustion=11129,iceblock=11958,hypothermia=41425}
M.debuffIDs={scorch=22959,winterschill=12579,frostbite=12494}

local function rank(s,key) return s.talents and s.talents[key] or 0 end
local function remaining(s,key) return s.buffs and s.buffs[key] or 0 end
local ready=A.RotationAdvisor.Ready
M.Ready=ready

-- Estimated direct throughput, not a claim of simulator-perfect DPS. Current
-- rank, cast time, school spell power/crit and actual allocated talents matter.
function M.Estimate(s,key)
    local a=s.spells[key]; local d=a and A.Data.MageRotationSpells[a.id]
    if not d then return nil end
    local cast=a.castTime
    if cast==nil then
        cast=d.cast
        if key=="fireball" then cast=cast-.1*rank(s,"improvedFireball") end
        if key=="frostbolt" then cast=cast-.1*rank(s,"improvedFrostbolt") end
        cast=math.max(0,cast)/(1+(s.haste or 0))
    end
    if key=="missiles" or key=="blizzard" then cast=d.cast/(1+(s.haste or 0)) end
    if remaining(s,"presence")>0 and cast>0 and key~="missiles" and key~="blizzard" then cast=0 end
    local damage=d.damage+d.coefficient*((s.spellPower or {})[d.school] or 0)
    local crit=((s.spellCrit or {})[d.school] or 0)/100
    if key=="scorch" or key=="fireblast" then crit=crit+.02*rank(s,"incinerate") end
    if key=="flamestrike" then crit=crit+.05*rank(s,"improvedFlamestrike") end
    if s.frozen and (s.frozenRemaining or 0)>cast then crit=crit+.1*rank(s,"shatter") end
    local critBonus=.5
    local multiplier=1+.01*rank(s,"arcaneInstability")
    if d.school==3 then
        multiplier=multiplier+.02*rank(s,"firePower")
        critBonus=critBonus+1.5*.08*rank(s,"ignite")
        multiplier=multiplier*(1+.03*(s.scorchStacks or 0))
    elseif d.school==5 then
        multiplier=multiplier+.02*rank(s,"piercingIce")
        critBonus=critBonus*(1+.2*rank(s,"iceShards"))
        crit=crit+.02*(s.winterChillStacks or 0)
    end
    if remaining(s,"arcanepower")>0 then multiplier=multiplier*1.3 end
    if key=="cone" and rank(s,"improvedConeOfCold")>0 then multiplier=multiplier*(1.05+.1*rank(s,"improvedConeOfCold")) end
    local minimumDamage=damage*multiplier*.85 -- Conservative noncritical finisher allowance.
    if key~="blizzard" then damage=damage*(1+math.min(1,crit)*critBonus) end
    damage=damage*multiplier
    -- Classic hit penalty rises sharply against enemies three levels higher.
    -- Unknown/boss level uses the conservative +3 case; talents differ by school.
    local difference=s.targetBoss and 3 or s.targetLevel and s.targetLevel>0 and math.max(0,s.targetLevel-(s.level or 60)) or 0
    local miss=difference<=2 and .04+.01*difference or .17+.11*(difference-3)
    local talentHit=d.school==7 and .02*rank(s,"arcaneFocus") or .02*rank(s,"elementalPrecision")
    damage=damage*(1-math.max(.01,math.min(.99,miss-talentHit-(s.spellHit or 0)/100)))
    local direct=damage
    -- Fireball's short refresh interval clips its own DoT; do not add every tick.
    local dotFraction=key=="fireball" and math.min(1,math.max(1.5,cast)/8) or 1
    damage=damage+(d.dot or 0)*dotFraction*multiplier
    local cost=a.cost or d.mana
    if remaining(s,"clearcasting")>0 then cost=0 end
    return {score=damage/math.max(1.5,cast),damage=direct,minimumDamage=minimumDamage,cast=cast,cost=cost,school=d.school}
end

-- Pick a stable filler from character data, never from target lifetime or momentary
-- availability. The live adapter caches this until spells/talents/gear/level change.
function M.BuildProfile(s)
    local character={spells=s.spells,talents=s.talents,spellPower=s.spellPower,spellCrit=s.spellCrit,
        spellHit=s.spellHit,haste=s.haste,level=s.level,targetLevel=s.level,buffs={}}
    local main,best
    for _,key in ipairs({"frostbolt","fireball","missiles"}) do
        local estimate=M.Estimate(character,key)
        if estimate and (not best or estimate.score>best.score) then main,best=key,estimate end
    end
    local order={}
    if main then order[1]=main end
    for _,key in ipairs({"frostbolt","fireball","scorch","missiles"}) do
        if key~=main and s.spells[key] then order[#order+1]=key end
    end
    return {main=main,order=order,damage=best and best.damage,school=best and best.school}
end
function M.Profile(self,s)
    if not self.damageProfile then self.damageProfile=M.BuildProfile(s) end
    return self.damageProfile
end
local function profile(s) return s.damageProfile or M.BuildProfile(s) end
local function threatened(s) return s.combat and (s.attackingPlayer or s.recentDamage) end
local function validEnemy(s) return s.validTarget and not s.targetPlayer and not s.controlled end

-- Situational actions have independent highlights; they do not rerank damage.
function M.Situational(s,add)
    local hp,mp=s.playerHealth or 100,s.powerPercent or 100
    local danger=threatened(s)
    if validEnemy(s) and s.interrupt then add("counterspell","Interrupt the enemy cast.",true) end
    if s.curse then add("decurse","Remove the curse on you.",true) end
    if danger and (s.rooted or s.stunned) then add("blink","Break the root or stun; check your landing direction.",true) end
    if danger and hp<70 and remaining(s,"fireward")==0 and s.damageSchool==4 then add("fireward","Absorb incoming fire damage.",true) end
    if danger and hp<70 and remaining(s,"frostward")==0 and s.damageSchool==16 then add("frostward","Absorb incoming frost damage.",true) end
    if danger and hp<85 and remaining(s,"barrier")==0 then add("barrier","Absorb incoming damage.",true) end
    if not validEnemy(s) then return end
    if danger and s.targetClose and not s.frozen and s.safeAOE then
        local bolt=M.Estimate(s,"frostbolt")
        local setup=not s.grouped and not s.targetBoss and rank(s,"shatter")>0 and ready(s,"frostbolt")
            and bolt and s.targetHP and s.targetHP>bolt.damage*(s.rotationCast and s.casting and 2 or 1) and mp>15
        if hp<65 or setup then
            if not add("nova","Root the attacker and make room for your next cast.",true) and hp<65 and s.facingTarget then
                add("cone","Slow the attacker in front of you.",true)
            end
        end
    end
    if danger and hp<40 and (s.targets or 0)>=2 and s.polyEligible and not s.targetDotted then
        add("polymorph","Control the selected attacker.",true)
    end
    if s.combat and s.grouped and s.targetCombat and mp<10 and hp>75 and not danger then
        add("evocation","Recover mana while the enemy is occupied.",true)
    end
    local plan=profile(s)
    local durable=s.targetBoss or s.grouped and s.targetHP and plan.damage and s.targetHP>plan.damage*4
    if s.combat and durable and mp>45 and hp>50 then
        if remaining(s,"arcanepower")==0 then add("arcanepower","Increase damage for this fight.",true) end
        if plan.school==3 and remaining(s,"combustion")==0 then add("combustion","Increase critical strikes for fire spells.",true) end
        if remaining(s,"presence")==0 then add("presence","Make your next damage cast instant.",true) end
    end
end

-- Optional upkeep is independent of the single primary action. Expiring buffs
-- remain visible through movement/casts and can coexist with urgent advice.
function M.BuffRefresh(left)
    return A.ConsumableBuffs.RefreshDue(left)
end
function M.Optional(s)
    local actions,seen={},{}
    if s.class~="MAGE" or not R.CanAdvise(s) or remaining(s,"iceblock")>0 or s.channelKey=="evocation" then return actions end
    local mp=s.powerPercent or 100
    local refreshLeft
    local function add(key,reason,immediate)
        if seen[key] then return true end
        if ready(s,key,immediate) then
            seen[key]=true
            actions[#actions+1]={key=key,reason=reason,buffColor=refreshLeft and (refreshLeft>0 and "refresh" or "primary")}
            return true
        end
    end
    local armorRemaining=math.max(remaining(s,"frostarmor"),remaining(s,"icearmor"),remaining(s,"magearmor"))
    -- A presence-only snapshot cannot establish an expiration time.
    if armorRemaining==0 and s.hasArmor==true then armorRemaining=math.huge end
    local durations=s.buffDurations or {}
    refreshLeft=remaining(s,"intellect")
    if mp>40 and not s.intellectBlocked and M.BuffRefresh(refreshLeft,durations.intellect) then add("intellect","Refresh Arcane Intellect before it expires.") end
    local armorDuration
    for _,key in ipairs({"frostarmor","icearmor","magearmor"}) do if remaining(s,key)==armorRemaining then armorDuration=durations[key] end end
    refreshLeft=armorRemaining
    if mp>40 and M.BuffRefresh(armorRemaining,armorDuration) then
        local preferred=(rank(s,"arcaneMeditation")>0 or s.grouped) and "magearmor" or "icearmor"
        if not add(preferred,"Maintain your armor buff.") then
            for _,key in ipairs({"icearmor","frostarmor","magearmor"}) do
                if add(key,"Maintain your armor buff.") then break end
            end
        end
    end
    refreshLeft=remaining(s,"barrier")
    if mp>40 and M.BuffRefresh(refreshLeft,durations.barrier) then add("barrier","Refresh Ice Barrier before it expires.") end
    refreshLeft=nil
    -- A usable mana gem remains auxiliary through casts and movement. It must
    -- not replace the next damage action whenever a cast finishes.
    if s.combat and ready(s,"managem",true)
        and (s.maxPower or 0)-(s.power or 0)>=(s.spells.managem.restore or math.huge) then
        add("managem","Restore mana without wasting the gem's recovery.")
    end
    if not s.combat and not s.casting and not s.targetCombat then
        if mp<25 and ready(s,"evocation",true) then add("evocation","Recover mana before pulling.") end
    end
    M.Situational(s,add)
    return actions
end

function M.Decide(s)
    if s.class~="MAGE" or not R.CanAdvise(s) or remaining(s,"iceblock")>0 then return nil,"" end
    local hp,mp=s.playerHealth or 100,s.powerPercent or 100
    local danger=threatened(s)
    local function choose(key,why) return key,why,false,false end
    local function emergency(key,why) if ready(s,key,true) then return key,why,false,true end end
    -- Only immediate survival emergencies replace the damage highlight.
    if hp<=18 and danger and remaining(s,"hypothermia")==0 and ready(s,"iceblock",true) then return emergency("iceblock","Emergency immunity at critical health.") end
    if (s.fallingFor or 0)>1.5 and remaining(s,"slowfall")==0 and ready(s,"slowfall",true) then return emergency("slowfall","Slow the fall before landing.") end
    if danger and hp<30 then
        if (s.rooted or s.stunned) and ready(s,"blink",true) then return emergency("blink","Break the root or stun to escape.") end
        if remaining(s,"barrier")==0 and ready(s,"barrier",true) then return emergency("barrier","Absorb damage at critical health.") end
        if validEnemy(s) and s.targetClose and not s.frozen and s.safeAOE and ready(s,"nova",true) then return emergency("nova","Root nearby attackers to escape.") end
        if remaining(s,"barrier")==0 and remaining(s,"shield")==0 and mp>40 and ready(s,"shield",true) then return emergency("shield","Emergency protection; consumes mana when hit.") end
        if ready(s,"coldsnap",true) and ((s.spells.barrier and not s.spells.barrier.ready)
            or (s.spells.iceblock and not s.spells.iceblock.ready and remaining(s,"hypothermia")==0)) then return emergency("coldsnap","Restore a defensive Frost cooldown.") end
    end
    if not s.combat and not s.casting and not s.targetCombat and mp>80 and s.prepareGem and ready(s,s.prepareGem,true)
        and (s.power or 0)-(s.spells[s.prepareGem].cost or math.huge)>=(s.maxPower or 0)*.3 then
        return s.prepareGem,"Conjure a mana gem before the next pull.",true,false
    end
    if not validEnemy(s) or s.channelKey=="evocation" or s.channelKey and (s.channelRemaining or 0)>1 then return nil,"" end
    local plan=profile(s)
    -- A distant opener and a consumed Presence proc are explicit exceptions.
    if ready(s,"pyroblast") and remaining(s,"presence")>0 then return choose("pyroblast","Use Presence of Mind for an instant Pyroblast.") end
    if not s.combat and not s.targetCombat and not s.casting and not s.targetDotted
        and s.targetDistance and s.targetDistance>=25 and hp>=80 and ready(s,"pyroblast",true) then
        local opener=M.Estimate(s,"pyroblast"); local filler=plan.main and M.Estimate(s,plan.main)
        if opener and filler and opener.damage>filler.damage and (s.power or 0)>=opener.cost+filler.cost then return choose("pyroblast","Open from a safe distance.") end
    end
    -- Fixed, safe AoE priority; observed enemies and CC protection are mandatory.
    local kite=s.targetDistance and s.targetDistance>=20 and ((s.slowRemaining or 0)>2 or s.frozen) and rank(s,"improvedBlizzard")>=2
    if s.combat and s.safeCluster and (s.cluster or 0)>=3 and hp>55 and mp>35 and (not s.attackingPlayer or kite) then
        if not s.attackingPlayer and not s.flamestrikeActive and ready(s,"flamestrike") then return choose("flamestrike","Place Flamestrike on the engaged group.") end
        if ready(s,"blizzard") then return choose("blizzard","Channel Blizzard on the engaged group.") end
    end
    if s.combat and s.safeAOE and (s.nearby or 0)>=3 and s.targetClose and hp>55 and mp>30 then
        for _,key in ipairs({"blastwave","explosion"}) do if ready(s,key) then return choose(key,"Area damage for the nearby engaged group.") end end
    end
    -- Cheap, short wand finishes and noncritical instant kills need no lifespan forecast.
    if s.combat and not s.casting and hp>=75 and not s.recentDamage and not s.targetClose
        and s.targets==1 and ready(s,"shoot") and (s.wandDamage or 0)>0 and s.targetHP and s.targetHP>0
        and remaining(s,"clearcasting")==0 and (not s.attackingPlayer or s.targetDistance and s.targetDistance>=25 and (s.slowRemaining or 0)>=5)
        and s.targetHP<=s.wandDamage*(mp<25 and 3 or 1) then
        if s.wanding then return nil,"" end
        return choose("shoot","Finish with your wand and conserve mana.")
    end
    if ready(s,"fireblast") then
        local finish=M.Estimate(s,"fireblast")
        if finish and s.targetHP and s.targetHP>0 and s.targetHP<=finish.minimumDamage then return choose("fireblast","Finish with instant damage.") end
    end
    if plan.school==3 and s.combat and (s.grouped or s.targetBoss) and rank(s,"improvedScorch")>0 and ready(s,"scorch")
        and s.targetHP and plan.damage and s.targetHP>plan.damage*3 and ((s.scorchStacks or 0)<5 or (s.scorchRemaining or 0)<5) then
        return choose("scorch","Build or refresh Fire Vulnerability.")
    end
    for _,key in ipairs(plan.order) do if ready(s,key) then return choose(key,key==plan.main and "Your main attack for this build." or "Available fallback for your main attack.") end end
    if ready(s,"fireblast") then return choose("fireblast","Instant damage while your other attacks are unavailable.") end
    if s.safeAOE and s.targetClose and s.facingTarget and ready(s,"cone") then return choose("cone","Damage and slow the attacker in front of you.") end
    if ready(s,"shoot") and not s.wanding then return choose("shoot","Use your wand while mana or spells recover.") end
    return nil,""
end

function M.RefreshSpells(self)
    if known(116) and self.spells.frostbolt and self.spells.frostbolt.id~=116 then
        local value=info(116)
        if value then self.spells.slowbolt={id=116,name=value.name,icon=value.iconID,rank=value.rank} end
    end
    if known(122) then
        local value=info(122)
        if value then self.spells.nova={id=122,name=value.name,icon=value.iconID,level=10,rank=value.rank} end
    end
end
function M.IsImmune(self,s,key,spell)
    local definition=M.spellData[spell.id]
    local fireImmune=definition and definition.school==3 and definition.damage>0
        and self.immune and self.immune.fireSchool and self.immune.fireSchool>s.time
    return not not (fireImmune or self.immune and self.immune[key] and self.immune[key]>s.time)
end

function M.Snapshot(self,s)
    local intellectRanks={[1459]=2,[1460]=7,[1461]=15,[10156]=22,[10157]=31}
    local intellectPower=self.spells.intellect and intellectRanks[self.spells.intellect.id]
    if not self.talentsReady and s.time>=(self.talentRetryAt or 0) then
        local live=A.TalentAdvisor:ReadCurrent("MAGE",UnitLevel("player"))
        self.talents=live and live.ranks or {}; self.talentsReady=not not live; self.talentRetryAt=s.time+2; self.damageProfile=nil
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
        local elixirPower=a.spellId==11396 and 25 or a.spellId==3166 and 6
        if intellectPower and elixirPower and elixirPower>=intellectPower and auraRemaining(a,s.time)>0 then
            s.intellectBlocked=true
            s.intellectBlocker={id=a.spellId,power=elixirPower,remaining=auraRemaining(a,s.time)}
        end
        for key,id in pairs(M.buffIDs) do if a.spellId==id then s.buffs[key]=auraRemaining(a,s.time) end end
        -- Brilliance shares the Intellect benefit; never overwrite group buffs.
        if a.spellId==23028 and auraRemaining(a,s.time)>=(s.buffs.intellect or 0) then
            s.buffs.intellect=auraRemaining(a,s.time); s.buffDurations.intellect=a.duration
        end
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
    self:TargetLife(s,guid)
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
function M.ObserveCombat(self)
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
            -- Fire Blast is pure direct Fire damage. Its IMMUNE result supplies
            -- school evidence; control/slow immunity and ordinary resists do not.
            if key=="fireblast" and school==4 then self.immune.fireSchool=now+15 end
        elseif event=="SPELL_DAMAGE" and school==4 and dest==target and self.immune then
            self.immune.fireSchool=nil
            if key then self.immune[key]=nil end
        elseif event=="SPELL_CAST_SUCCESS" and key=="flamestrike" then self.flamestrike=now+8 end
    end
end
function M.Resources(self,s)
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
    for _,gem in ipairs(M.gems) do
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

function M.Retainable(s,key)
    if (s.buffs.iceblock or 0)>0 then return false end
    if s.channelKey=="evocation" or s.channelKey and (s.channelRemaining or 0)>1 then return false end
    if not M.Ready(s,key) or key=="shoot" and s.wanding then return false end
    if key=="pyroblast" and s.combat and (s.buffs.presence or 0)==0 then return false end
    if M.ground[key] then
        local kiteWindow=s.targetDistance and s.targetDistance>=20 and ((s.slowRemaining or 0)>2 or s.frozen)
            and (s.talents.improvedBlizzard or 0)>=2
        return s.safeCluster and (s.cluster or 0)>=3
            and (s.playerHealth or 100)>55 and (s.powerPercent or 100)>35
            and (not s.attackingPlayer or key=="blizzard" and kiteWindow)
            and (key~="flamestrike" or not s.flamestrikeActive)
    elseif key=="nova" then
        return s.safeAOE and s.targetClose and not s.frozen and s.attackingPlayer
    elseif M.area[key] then
        return s.safeAOE and s.targetClose and (s.playerHealth or 100)>55 and (s.powerPercent or 100)>30
            and (key=="cone" and s.facingTarget or s.nearby>=3)
    end
    return true
end

R:RegisterClass("MAGE",M)

function M.GCDReference(self) return self.spells.frostbolt or self.spells.fireball end
function M.ResetTarget(self) self.flamestrike=nil end
