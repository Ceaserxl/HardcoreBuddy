-- Classic Era Mage priorities. All output is advice; never casts or targets.
local _,A=...
local M={}; A.MageRotation=M
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
local function ready(s,key,immediate)
    local a=s.spells[key]
    if not a or not a.ready or a.immune then return false end
    local usable=a.usable
    if immediate and a.usableNow~=nil then usable=a.usableNow end
    if not usable then return false end
    if immediate and ((a.cooldownRemaining or 0)>.15 or a.powerPreview) then return false end
    return not a.requiresRange or a.range==true or a.approaching==true
end
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
        -- Ignite benefits are discounted on targets that will die before its ticks.
        critBonus=critBonus+1.5*.08*rank(s,"ignite")*math.min(1,(s.timeToDie or 8)/4)
        multiplier=multiplier*(1+.03*(s.scorchStacks or 0))
    elseif d.school==5 then
        multiplier=multiplier+.02*rank(s,"piercingIce")
        critBonus=critBonus*(1+.2*rank(s,"iceShards"))
        crit=crit+.02*(s.winterChillStacks or 0)
    end
    if remaining(s,"arcanepower")>0 then multiplier=multiplier*1.3 end
    if key=="cone" and rank(s,"improvedConeOfCold")>0 then multiplier=multiplier*(1.05+.1*rank(s,"improvedConeOfCold")) end
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
    local dotFraction=key=="fireball" and math.min(1,math.max(1.5,cast)/8) or math.min(1,(s.timeToDie or 12)/12)
    damage=damage+(d.dot or 0)*dotFraction*multiplier
    local cost=a.cost or d.mana
    if remaining(s,"clearcasting")>0 then cost=0 end
    local score=damage/math.max(1.5,cast)
    if s.attackingPlayer and s.targetClose and cast>0 then
        local protection=key=="missiles" and .2*rank(s,"improvedArcaneMissiles")
            or d.school==3 and .35*rank(s,"burningSoul") or 0
        if remaining(s,"barrier")==0 then score=score*(.7+.3*math.min(1,protection)) end
    end
    if s.timeToDie and cast>s.timeToDie then score=score*.15 end
    if s.powerPercent and s.powerPercent<30 and cost>0 then
        score=score/(1+cost/math.max(1,s.maxPower or 1000))
    end
    return {score=score,damage=direct,cast=cast,cost=cost,school=d.school}
end

-- Optional upkeep is independent of the single primary action. Expiring buffs
-- remain visible through movement/casts and can coexist with urgent advice.
function M.Optional(s)
    local actions={}
    if s.class~="MAGE" or s.dead or s.taxi or remaining(s,"iceblock")>0 or s.channelKey=="evocation" then return actions end
    local mp=s.powerPercent or 100
    local function add(key,reason)
        if ready(s,key) then actions[#actions+1]={key=key,reason=reason}; return true end
    end
    local armorRemaining=math.max(remaining(s,"frostarmor"),remaining(s,"icearmor"),remaining(s,"magearmor"))
    -- A presence-only snapshot cannot establish an expiration time.
    if armorRemaining==0 and s.hasArmor==true then armorRemaining=math.huge end
    if mp>40 and remaining(s,"intellect")<=60 then add("intellect","Refresh Arcane Intellect before it expires.") end
    if mp>40 and armorRemaining<=60 then
        local preferred=(rank(s,"arcaneMeditation")>0 or s.grouped) and "magearmor" or "icearmor"
        if not add(preferred,"Maintain your armor buff.") then
            for _,key in ipairs({"icearmor","frostarmor","magearmor"}) do
                if add(key,"Maintain your armor buff.") then break end
            end
        end
    end
    if mp>40 and remaining(s,"barrier")<=5 then add("barrier","Refresh Ice Barrier before it expires.") end
    if not s.combat and not s.casting and not s.targetCombat and not s.moving and not s.mounted then
        if mp<25 and ready(s,"evocation",true) then add("evocation","Recover mana before pulling.") end
    end
    return actions
end

function M.Decide(s)
    if s.class~="MAGE" then return nil,"Rotation Advisor currently supports Mage." end
    if s.dead or s.taxi then return nil,"" end
    local hp,mp=s.playerHealth or 100,s.powerPercent or 100
    local threatened=s.combat and (s.attackingPlayer or s.recentDamage)
    local function can(key,now) return ready(s,key,now) end
    local urgentPhase=true
    local function choose(key,why,optional) return key,why or "",optional,urgentPhase end
    -- Never suggest cancelling an active defensive immunity or clipping Evocation.
    if remaining(s,"iceblock")>0 then return nil,"" end
    if hp<=18 and threatened and remaining(s,"hypothermia")==0 and can("iceblock",true) then return choose("iceblock","Emergency immunity at critical health.") end
    if s.validTarget and not s.targetPlayer and s.interrupt and can("counterspell",true) and not s.controlled then return choose("counterspell","Interrupt the enemy cast.") end
    if (s.fallingFor or 0)>1.5 and remaining(s,"slowfall")==0 and can("slowfall",true) then return choose("slowfall","Slow the fall before landing.") end
    if threatened and (s.rooted or s.stunned) and can("blink",true) then return choose("blink","Break the root or stun; check your landing direction.") end
    if s.curse and can("decurse",true) then return choose("decurse","Remove the curse on you.") end
    if threatened and hp<85 and remaining(s,"barrier")==0 and can("barrier") then return choose("barrier","Absorb incoming damage and prevent pushback.") end
    if threatened and hp<70 and s.damageSchool==4 and remaining(s,"fireward")==0 and can("fireward") then return choose("fireward","Absorb the fire damage hitting you.") end
    if threatened and hp<70 and s.damageSchool==16 and remaining(s,"frostward")==0 and can("frostward") then return choose("frostward","Absorb the frost damage hitting you.") end
    local escape=threatened and hp<65 and s.targetClose and not s.frozen
    if escape and s.safeAOE and can("nova",true) then return choose("nova","Freeze nearby attackers to make room for a cast.") end
    if escape and s.safeAOE and s.facingTarget and can("cone",true) then return choose("cone","Slow the attackers in front of you.") end
    if threatened and hp<30 and remaining(s,"barrier")==0 and remaining(s,"shield")==0 and mp>40 and can("shield") then return choose("shield","Emergency protection; consumes mana when hit.") end
    if threatened and hp<30 and can("coldsnap",true) and
        ((s.spells.barrier and not s.spells.barrier.ready) or (s.spells.iceblock and not s.spells.iceblock.ready and remaining(s,"hypothermia")==0)) then
        return choose("coldsnap","Restore a defensive Frost cooldown.")
    end
    if threatened and hp<40 and s.targets>=2 and s.validTarget and not s.targetPlayer and s.polyEligible and not s.controlled and not s.targetDotted and can("polymorph",true) then
        return choose("polymorph","Control this attacker while dealing with the others.")
    end
    -- Optional upkeep is evaluated separately and never replaces damage advice.
    urgentPhase=false
    if s.combat and not s.casting and not s.channelKey and can("managem",true)
        and (s.maxPower or 0)-(s.power or 0)>=(s.spells.managem.restore or math.huge) then
        return "managem","Restore mana without wasting the gem's recovery.",false,true
    end
    if not s.combat and not s.casting and not s.targetCombat and not s.moving and not s.mounted
        and mp>80 and s.prepareGem and can(s.prepareGem,true)
        and (s.power or 0)-(s.spells[s.prepareGem].cost or math.huge)>=(s.maxPower or 0)*.3 then
        return choose(s.prepareGem,"Conjure a mana gem before the next pull.",true)
    end
    if not s.validTarget or s.targetPlayer or s.controlled then return nil,"" end
    if s.channelKey=="evocation" or s.channelKey and (s.channelRemaining or 0)>1 then return nil,"" end
    local survivalChannel=s.combat and mp<10 and hp>75 and not s.attackingPlayer and not s.recentDamage
        and s.grouped and s.targetCombat and (s.timeToDie or 0)>12
    if survivalChannel and not s.moving and can("evocation",true) then return choose("evocation","Recover mana while the enemy is occupied.") end
    local best,bestEstimate
    for _,key in ipairs({"fireball","frostbolt","scorch","missiles","pyroblast"}) do
        if can(key) then
            local e=M.Estimate(s,key)
            if e and (key~="pyroblast" or remaining(s,"presence")>0) then
                if not bestEstimate or e.score>bestEstimate.score then best,bestEstimate=key,e end
            end
        end
    end
    -- Spend the long opening cast before combat, never while an enemy is closing.
    if not s.combat and not s.targetCombat and not s.casting and not s.moving and not s.targetDotted
        and s.targetDistance and s.targetDistance>=25 and hp>=80 and can("pyroblast",true) then
        local opener=M.Estimate(s,"pyroblast")
        local filler=M.Estimate(s,"fireball") or M.Estimate(s,"frostbolt")
        if opener and filler and opener.damage>filler.damage and (s.power or 0)>=opener.cost+filler.cost then
            return choose("pyroblast","Open from a safe distance before the enemy is engaged.")
        end
    end
    -- A slow buys casting time when soloing, regardless of the damage build.
    if can("frostbolt") and not s.frozen and (s.slowRemaining or 0)<1.5 and not s.targetClose
        and not s.targetBoss and not s.grouped and (not s.combat or s.attackingPlayer)
        and (s.timeToDie or 15)>4 then best="frostbolt"; bestEstimate=M.Estimate(s,best) end
    if threatened and not s.frozen and (s.slowRemaining or 0)<1.5 and s.targetDistance and s.targetDistance>8
        and s.targetDistance<18 and can("slowbolt") and not s.targetBoss then
        return choose("slowbolt","Apply a quick slow before the attacker reaches you.")
    end
    if best and bestEstimate then
        if s.combat and bestEstimate.school==3 and rank(s,"improvedScorch")>0 and can("scorch")
            and (s.timeToDie or 0)>10 and ((s.scorchStacks or 0)<5 or (s.scorchRemaining or 0)<5) then
            return choose("scorch","Build or refresh Fire Vulnerability for this longer fight.")
        end
        if s.combat and (s.timeToDie or 0)>12 and mp>45 and hp>50 then
            if remaining(s,"arcanepower")==0 and can("arcanepower",true) then return choose("arcanepower","Increase damage for the longer fight.") end
            if bestEstimate.school==3 and remaining(s,"combustion")==0 and can("combustion",true) then return choose("combustion","Increase critical strikes for your fire spells.") end
        end
        if s.combat and can("presence",true) and remaining(s,"presence")==0 and bestEstimate.cast>=2.5
            and (s.moving or (s.timeToDie or 0)>8) then return choose("presence","Make the next damage cast instant.") end
    end
    -- Ground AoE requires a confirmed cluster around the target; never invent
    -- positions or select a ground location for the player.
    local aoe,aoeScore
    local function area(key,targets)
        if can(key) then
            local e=M.Estimate(s,key)
            if e and (not aoeScore or e.score*targets>aoeScore) then aoe,aoeScore=key,e.score*targets end
        end
    end
    local kiteWindow=s.targetDistance and s.targetDistance>=20 and ((s.slowRemaining or 0)>2 or s.frozen) and rank(s,"improvedBlizzard")>=2
    if s.combat and s.safeCluster and (s.cluster or 0)>=3 and hp>55 and mp>35 and (not s.attackingPlayer or kiteWindow) and not s.moving then
        if not s.flamestrikeActive and not s.attackingPlayer then area("flamestrike",s.cluster) end
        area("blizzard",s.cluster)
    end
    if s.combat and s.safeAOE and s.nearby>=3 and hp>55 and mp>30 and s.targetClose then
        area("blastwave",s.nearby)
        if s.facingTarget then area("cone",1) end -- Facing the target does not prove every enemy is in the cone.
        area("explosion",s.nearby)
    end
    if aoe then return choose(aoe,M.ground[aoe] and "Place the area spell on the engaged group." or "Area damage for the nearby engaged group.") end
    -- Estimate whole wand shots conservatively; do not trade safety for regen.
    if s.combat and not s.casting and not s.moving and hp>=75 and not s.recentDamage and not s.targetClose
        and s.targets==1 and can("shoot") and s.wandDamage and s.wandDamage>0 and (s.wandSpeed or 0)>0
        and s.targetHP and s.targetHP>0 and remaining(s,"clearcasting")==0 then
        local seconds=math.ceil(s.targetHP/s.wandDamage)*s.wandSpeed
        local recovered=math.max(0,seconds-(s.regenDelay or 5))*(s.normalRegen or 0)
        local castSeconds=bestEstimate and math.ceil(s.targetHP/math.max(1,bestEstimate.damage))*math.max(1.5,bestEstimate.cast) or math.huge
        local safeWindow=not s.attackingPlayer or s.targetDistance and s.targetDistance>=25 and (s.slowRemaining or 0)>=seconds
        if safeWindow and (seconds<=math.min(3,castSeconds+1) or mp<35 and seconds<=6 and recovered>0) then
            if s.wanding then return nil,"" end
            return choose("shoot","Finish with the wand while conserving and recovering mana.")
        end
    end
    if can("fireblast") then
        local e=M.Estimate(s,"fireblast")
        if s.moving or (e and s.targetHP and s.targetHP<=e.damage) or (s.frozen and (s.frozenRemaining or 0)<1.5) then
            return choose("fireblast","Instant damage while moving or finishing the target.")
        end
        if not best then return choose("fireblast","Instant damage while other damage casts are unavailable.") end
    end
    if s.moving and s.safeAOE and s.targetClose and s.facingTarget and can("cone") then return choose("cone","Instant damage and a slow while moving.") end
    if best then return choose(best,"Best available damage cast for your learned ranks and talents.") end
    if can("shoot") and not s.wanding then return choose("shoot","Use your wand while mana or spells recover.") end
    return nil,""
end
