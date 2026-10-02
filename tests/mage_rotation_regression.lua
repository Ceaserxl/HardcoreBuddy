local A=TestAddon; local R=A.RotationAdvisor; local M=A.MageRotation
local count=0
local function check(ok,why) count=count+1; assert(ok,why) end
local function state(keys,level)
    local s={class='MAGE',level=level or 60,spells={},buffs={},talents={},spellPower={},spellCrit={},
        combat=true,grouped=true,validTarget=true,playerHealth=100,targetHealth=100,targetHP=5000,
        powerPercent=100,power=5000,maxPower=5000,targets=1,nearby=1,safeAOE=true,targetClose=false}
    for _,key in ipairs(keys or {'frostbolt','fireball'}) do
        local id=M.definitions[key]
        for spellID,d in pairs(A.Data.MageRotationSpells) do
            local current=A.Data.MageRotationSpells[id]
            if d.key==key and d.level<=s.level and (not current or d.rank>current.rank) then id=spellID end
        end
        local d=A.Data.MageRotationSpells[id]
        s.spells[key]={id=id,ready=true,usable=true,range=true,requiresRange=not M.selfSpells[key],cost=d and d.mana or 0}
    end
    return s
end
local function decide(s,expected,label)
    local actual=R.Decide(s)
    check(actual==expected,(label or '')..': expected '..tostring(expected)..', got '..tostring(actual))
end
local function optional(s,key)
    for _,choice in ipairs(M.Optional(s)) do if choice.key==key then return true end end
    return false
end
check(not R.supported.ROGUE and not R.definitions.ROGUE,'Rogue prototype removed')
do
    local s=state({'frostbolt','intellect','icearmor','magearmor','barrier'})
    s.buffs={intellect=61,icearmor=61,barrier=6}; s.hasArmor=true
    check(#M.Optional(s)==0,'Healthy buff durations do not prompt refresh')
    s.buffs={intellect=60,icearmor=60,barrier=5}
    check(optional(s,'intellect') and optional(s,'magearmor') and optional(s,'barrier'),'Buff refresh windows begin before expiration')
    check(#M.Optional(s)==3,'Only one armor choice accompanies other expiring buffs')
    decide(s,'frostbolt','Early refresh leaves damage primary intact')
    s.buffs.intellect=1800; s.buffs.icearmor=1800; s.buffs.barrier=60
    check(#M.Optional(s)==0,'Fresh durations clear all early refresh prompts')
    s.buffs={intellect=math.huge,magearmor=math.huge,barrier=math.huge}
    check(#M.Optional(s)==0,'Unknown or unlimited durations do not prompt refresh')
    s.buffs={intellect=30,icearmor=30,barrier=3}; s.powerPercent=10
    check(#M.Optional(s)==0,'Early refresh respects mana reserve')
end
do
    local s=state({'fireball','pyroblast'}); s.combat=false; s.grouped=false; s.targetDistance=30
    decide(s,'pyroblast','Dedicated distant Pyroblast opener beats sustained throughput')
    for _,field in ipairs({'combat','targetCombat','casting','moving','targetDotted'}) do
        s[field]=true; check(R.Decide(s)~='pyroblast','No long opener with '..field); s[field]=false
    end
    s.targetDistance=15; check(R.Decide(s)~='pyroblast','No long opener close to enemy')
    s.targetDistance=nil; check(R.Decide(s)~='pyroblast','Unknown distance cannot authorize opener')
    s.targetDistance=30; s.power=1; check(R.Decide(s)~='pyroblast','Opener reserves mana for following cast')
    s=state({'frostbolt','shoot'}); s.targetHP=40; s.wandDamage=50; s.wandSpeed=1.5
    decide(s,'shoot','Wand finishes without another mana expenditure')
    s.wanding=true; decide(s,nil,'Wand finisher never toggles active Shoot off'); s.wanding=false
    s.targetHP=150; s.powerPercent=20; s.normalRegen=30; s.regenDelay=1
    decide(s,'shoot','Short low-mana finish permits regeneration')
    s.regenDelay=5; decide(s,'frostbolt','No invented regen before five-second rule expires')
    s.regenDelay=1
    s.attackingPlayer=true; check(R.Decide(s)~='shoot','Closing attacker suppresses deliberate wand finish')
    s.targetDistance=30; s.slowRemaining=10; decide(s,'shoot','Distant slowed attacker permits short wand finish')
    s.attackingPlayer=false
    for _,field in ipairs({'recentDamage','moving','targetClose','casting'}) do
        s[field]=true; check(R.Decide(s)~='shoot','No deliberate wand finishing with '..field); s[field]=false
    end
    s.wandDamage=nil; decide(s,'frostbolt','Unknown wand damage preserves filler')
    s=state({'frostbolt'}); s.spells.managem={id=8008,item=true,restore=1200,ready=true,usable=true}
    s.power=3500; decide(s,'managem','Use carried gem when full restoration fits')
    s.power=4000; decide(s,'frostbolt','Do not waste gem restoration')
    s.power=3500; s.spells.managem.ready=false; decide(s,'frostbolt','Respect shared gem cooldown')
    s.spells.managem.ready=true; s.casting=true; decide(s,'frostbolt','Gem does not interrupt current cast')
    s.casting=false; s.spells.counterspell={ready=true,usable=true}; s.interrupt=true
    decide(s,'counterspell','Enemy interrupt takes priority over mana gem')
    s=state({'frostbolt','ruby'}); s.combat=false; s.prepareGem='ruby'; s.spells.ruby.cost=1200
    decide(s,'ruby','Stationary preparation takes priority before pulling')
    local _,_,isOptional=R.Decide(s); check(isOptional,'Gem preparation retains optional glow')
    s.prepareGem=nil; decide(s,'frostbolt','Owned gem does not prompt reconjuring')
    s.prepareGem='ruby'; s.moving=true; decide(s,'ruby','Movement preserves optional preparation preview')
    s.moving=false; s.spells.ruby.cost=4900; decide(s,'frostbolt','Preparation preserves combat mana reserve')
end
-- Every level and all three talent emphases can choose only a learned rank.
for level=1,60 do
    for _,build in ipairs({'fire','frost','arcane'}) do
        local s=state({},level)
        for id,d in pairs(A.Data.MageRotationSpells) do
            if d.level<=level and not M.area[d.key] and d.key~='pyroblast' then
                local old=s.spells[d.key]
                if not old or d.rank>A.Data.MageRotationSpells[old.id].rank then
                    s.spells[d.key]={id=id,ready=true,usable=true,range=true,requiresRange=true,cost=d.mana}
                end
            end
        end
        if build=='fire' then s.talents={firePower=5,ignite=5}; s.spellCrit[3]=20
        elseif build=='frost' then s.talents={piercingIce=3,iceShards=5}; s.spellCrit[5]=20
        else s.talents={arcaneInstability=3,improvedArcaneMissiles=5}; s.spellPower[7]=100 end
        for _,mounted in ipairs({false,true}) do
            s.mounted=mounted
            local key=R.Decide(s)
            check(key and s.spells[key] and A.Data.MageRotationSpells[s.spells[key].id].level<=level,'Valid learned recommendation at level '..level..' / '..build)
        end
    end
end
local s=state({'fireball'},1); decide(s,'fireball','Starting mage has Fireball')
s.mounted=true; decide(s,'fireball','Mounted does not clear the highlight')
s.moving=true; s.casting='Fireball'; decide(s,'fireball','Movement/casting preserve next-spell guidance')
for _,gate in ipairs({'dead','taxi','targetPlayer','controlled'}) do s=state(); s[gate]=true; decide(s,nil,gate) end
s=state(); s.class='ROGUE'; decide(s,nil,'No residual Rogue priorities')
s=state({'frostbolt'}); s.spells.frostbolt.range=nil; decide(s,nil,'Unknown range is not in range')
s.spells.frostbolt.range=false; s.spells.frostbolt.approaching=true; decide(s,'frostbolt','Approaching target preview')
s.spells.frostbolt.immune=true; decide(s,nil,'Observed immunity blocks spell')
s=state({'frostbolt'}); s.spells.frostbolt.ready=false; decide(s,nil,'Cooldown blocks unavailable spells')
s=state({'frostbolt'}); s.spells.frostbolt.usable=false; decide(s,nil,'Other usability failures respected')
s=state({'frostbolt','counterspell'}); s.interrupt=true; decide(s,'counterspell','Interrupt priority')
s.spells.counterspell.usable=false; s.spells.counterspell.usableNow=true; decide(s,'counterspell','Interrupt uses current mana instead of reserving the cast it cancels')
s.spells.counterspell.cooldownRemaining=.8; decide(s,'frostbolt','Interrupt must actually be ready')
s=state({'frostbolt','barrier'}); s.playerHealth=70; s.attackingPlayer=true; decide(s,'barrier','Shield under pressure')
s.buffs.barrier=20; decide(s,'frostbolt','Do not overwrite shield')
s=state({'frostbolt','iceblock','counterspell'}); s.playerHealth=10; s.recentDamage=true; s.interrupt=true
decide(s,'iceblock','Emergency survival beats damage')
s.buffs.iceblock=10; decide(s,nil,'Never encourage cancelling Ice Block')
s.buffs.iceblock=nil; s.buffs.hypothermia=20; decide(s,'counterspell','Hypothermia forbids Ice Block')
s=state({'frostbolt','blink'}); s.rooted=true; s.attackingPlayer=true; decide(s,'blink','Escape root')
s=state({'frostbolt','decurse'}); s.curse=true; decide(s,'decurse','Self curse removal')
s=state({'frostbolt','slowfall'}); s.fallingFor=2; decide(s,'slowfall','Sustained fall recommends Slow Fall')
s.buffs.slowfall=10; decide(s,'frostbolt','Existing Slow Fall is respected')
s=state({'frostbolt','counterspell'}); s.interrupt=true; s.validTarget=false; decide(s,nil,'Never interrupt a friendly target')
s=state({'frostbolt','fireblast'}); s.channelKey='missiles'; s.channelRemaining=3; decide(s,nil,'Do not encourage clipping a damage channel')
s.channelRemaining=.8; check(R.Decide(s)~=nil,'Next spell leads the end of a damage channel')
s=state({'frostbolt','counterspell'}); s.channelKey='missiles'; s.channelRemaining=3; s.interrupt=true
decide(s,'counterspell','Interrupt can override a running channel')
s=state({'frostbolt','fireward','frostward'}); s.recentDamage=true; s.playerHealth=60; s.damageSchool=4
decide(s,'fireward','Fire ward matches incoming school'); s.damageSchool=16; decide(s,'frostward','Frost ward matches incoming school')
s=state({'frostbolt','nova','cone'}); s.attackingPlayer=true; s.targetClose=true; s.playerHealth=50
decide(s,'nova','Root to survive melee'); s.safeAOE=false; decide(s,'frostbolt','Do not break CC with Nova')
s.safeAOE=true; s.frozen=true; decide(s,'frostbolt','Do not re-root an already frozen enemy')
s=state({'frostbolt','shield'}); s.attackingPlayer=true; s.playerHealth=25
decide(s,'shield','Mana Shield emergency'); s.powerPercent=20; decide(s,'frostbolt','Do not drain last mana on Mana Shield')
s=state({'frostbolt','coldsnap','barrier'}); s.playerHealth=20; s.attackingPlayer=true; s.spells.barrier.ready=false
decide(s,'coldsnap','Cold Snap restores defensive cooldown')
s=state({'frostbolt','polymorph'}); s.attackingPlayer=true; s.targets=2; s.polyEligible=true; s.playerHealth=35
decide(s,'polymorph','Control eligible extra attacker'); s.targetDotted=true; decide(s,'frostbolt','Do not sheep a dotted target')
s=state({'fireball','intellect','frostarmor'}); s.combat=false
check(optional(s,'intellect') and optional(s,'frostarmor'),'Prepull buffs coexist')
decide(s,'fireball','Prepull buffs do not replace primary'); s.buffs.intellect=100
check(not optional(s,'intellect') and optional(s,'frostarmor'),'Only missing buff remains optional')
s.hasArmor=true; decide(s,'fireball','No repeat armor buff')
s=state({'frostbolt','evocation'}); s.combat=false; s.powerPercent=10
check(optional(s,'evocation'),'Safe optional mana recovery'); s.mounted=true
check(not optional(s,'evocation'),'Do not channel on mount'); decide(s,'frostbolt','Mounted preview remains')
s=state({'frostbolt','evocation'}); s.powerPercent=5; s.timeToDie=30; s.targetCombat=true
decide(s,'evocation','Safe grouped recovery'); s.recentDamage=true; decide(s,'frostbolt','Do not channel under damage')
s=state({'frostbolt','shoot'}); s.spells.frostbolt.usable=false; decide(s,'shoot','Wand fallback')
s.wanding=true; decide(s,nil,'Never toggle active wand off')
s=state({'fireball','frostbolt'}); s.grouped=false; s.attackingPlayer=true; s.slowRemaining=0; s.targetDistance=25
decide(s,'frostbolt','Solo approach gets slow regardless of spec')
s=state({'frostbolt','fireblast'}); s.moving=true; decide(s,'fireblast','Instant while moving')
s.moving=false; s.targetHP=10; decide(s,'fireblast','Fast finisher')
s=state({'frostbolt','fireblast'},6); s.spells.frostbolt.id=116; s.targetHP=1000
check(M.Estimate(s,'fireblast').score>M.Estimate(s,'frostbolt').score,'Fixture reproduces Fire Blast raw throughput advantage')
decide(s,'frostbolt','Do not spend Fire Blast as routine filler just for higher instant throughput')
s.spells.frostbolt.usable=false; decide(s,'fireblast','Fire Blast remains a fallback when other casts cannot be used')
s=state({'fireball','scorch'}); s.talents.improvedScorch=3; s.timeToDie=30
decide(s,'scorch','Fire vulnerability on long fight'); s.scorchStacks=5; s.scorchRemaining=20
decide(s,'fireball','Do not rebuild full Scorch stacks')
s.scorchRemaining=2; decide(s,'scorch','Refresh vulnerability before expiry')
s=state({'fireball','arcanepower','combustion'}); s.timeToDie=30
decide(s,'arcanepower','Use burst in long fight'); s.buffs.arcanepower=10; decide(s,'combustion','Combustion for fire damage')
s.timeToDie=2; decide(s,'fireball','Save cooldowns on dying target')
s=state({'fireball','presence'}); s.moving=true; decide(s,'presence','Presence while moving')
s=state({'fireball','pyroblast'}); s.buffs.presence=10; decide(s,'pyroblast','Instant Pyroblast with Presence')
s=state({'frostbolt','explosion','blizzard','flamestrike','blastwave'}); s.nearby=0; s.cluster=4; s.safeCluster=true; s.targetClose=false
decide(s,'flamestrike','Ground cluster opening'); s.flamestrikeActive=true; decide(s,'blizzard','Do not repeatedly overwrite ground DoT')
s.safeCluster=false; s.nearby=4; s.targetClose=true; decide(s,'blastwave','Close area fallback'); s.safeAOE=false; decide(s,'frostbolt','Unknown/unsafe proximity suppresses AoE')
s=state({'fireball','frostbolt','missiles','scorch'})
local base=M.Estimate(s,'frostbolt').score; s.spellPower[5]=400
check(M.Estimate(s,'frostbolt').score>base,'School-specific equipped spell damage changes estimates')
s.spellPower[5]=0; s.spellCrit[5]=20; s.talents.iceShards=5
check(M.Estimate(s,'frostbolt').score>base,'Actual crit and Ice Shards improve frost estimate')
base=M.Estimate(s,'frostbolt').score; s.talents.shatter=5; s.frozen=true; s.frozenRemaining=10
check(M.Estimate(s,'frostbolt').score>base,'Shatter requires freeze lasting through cast')
s.frozenRemaining=.1; check(M.Estimate(s,'frostbolt').score==base,'Expiring freeze does not invent Shatter crits')
s.buffs.clearcasting=10; check(M.Estimate(s,'missiles').cost==0,'Clearcasting makes damage cost zero')
s=state({'fireball','frostbolt'}); s.spellPower[3]=1000; decide(s,'fireball','Fire gear selects fire damage')
s.spellPower[3]=0; s.spellPower[5]=1000; decide(s,'frostbolt','Frost gear selects frost damage')
s=state({'missiles'}); s.targetLevel=63; local withoutFocus=M.Estimate(s,'missiles').score
s.talents.arcaneFocus=5; check(M.Estimate(s,'missiles').score>withoutFocus,'Arcane Focus affects damage against higher-level enemies')
s=state({'fireball'}); local normalCast=M.Estimate(s,'fireball').cast
s.talents.improvedFireball=5; check(M.Estimate(s,'fireball').cast==normalCast-.5,'Talent cast time fallback applies when live spell time is unavailable')
s=state({'missiles'}); s.haste=.5; check(M.Estimate(s,'missiles').cast<5,'Haste shortens the channel used in damage estimates')
s=state({'blizzard','frostbolt'}); s.attackingPlayer=true; s.targetDistance=25; s.slowRemaining=4
s.talents.improvedBlizzard=3; s.cluster=4; s.safeCluster=true; decide(s,'blizzard','Solo kiting supports Improved Blizzard on a known cluster')
s.targetDistance=10; s.slowRemaining=4; decide(s,'frostbolt','Do not channel Blizzard with pursuing enemies too close')

-- Live adapter fixtures. Only learned spells are available, with controllable APIs.
local now,combat=100,false
GetTime=function() return now end; InCombatLockdown=function() return combat end
MOCK.class='MAGE'
local spellData={
 [116]={name='Frostbolt',iconID=135846,castTime=1500,minRange=0,maxRange=30},
 [205]={name='Frostbolt',iconID=135846,castTime=1800,minRange=0,maxRange=30},
 [837]={name='Frostbolt',iconID=135846,castTime=2200,minRange=0,maxRange=30},
 [2136]={name='Fire Blast',iconID=135807,castTime=0,minRange=0,maxRange=20},
 [122]={name='Frost Nova',iconID=135848,castTime=0,minRange=0,maxRange=0},
 [118]={name='Polymorph',iconID=136071,castTime=1500,minRange=0,maxRange=30},
 [5019]={name='Shoot',iconID=135139,castTime=0,minRange=0,maxRange=30},
}
local learned={[116]=true,[205]=true,[837]=true,[2136]=true,[122]=true,[5019]=true}
local ready,range,usable={},{[837]=true,[2136]=true,[5019]=true},{}
C_Spell={GetSpellInfo=function(id) return spellData[id] end,
 GetSpellCooldown=function(id) return ready[id] or {startTime=0,duration=0,isEnabled=true} end,
 IsSpellUsable=function(id) return usable[id]~=false,usable[id]==false end,
 IsSpellInRange=function(id) return range[id] end,
 GetSpellSubtext=function(id) return id==837 and 'Rank 3' or nil end}
IsPlayerSpell=function(id) return learned[id] or false end
GetSpellBonusDamage=function() return 0 end; GetSpellCritChance=function() return 0 end
IsInGroup=function() return true end
local units={player={health=1000,max=1000,power=900,maxPower=1000,x=0,y=0,z=0,map=1,guid='player'},
 target={health=5000,max=5000,power=0,maxPower=0,x=15,y=0,z=0,map=1,guid='enemy'}}
UnitExists=function(u) return units[u]~=nil end
UnitGUID=function(u) return units[u] and units[u].guid end
UnitHealth=function(u) return units[u] and units[u].health or 0 end
UnitHealthMax=function(u) return units[u] and units[u].max or 0 end
UnitPower=function(u) return units[u] and units[u].power or 0 end
UnitPowerMax=function(u) return units[u] and units[u].maxPower or 0 end
UnitPowerType=function() return 0 end
UnitCanAttack=function(_,u) return u~='player' and units[u]~=nil end
UnitIsDeadOrGhost=function(u) return units[u] and units[u].dead end
UnitIsPlayer=function() return false end
UnitIsUnit=function(a,b) return a==b end
UnitAffectingCombat=function() return combat end
UnitThreatSituation=function() return combat and 0 or nil end
UnitPosition=function(u) local v=units[u]; if v then return v.x,v.y,v.z,v.map end end
GetUnitSpeed=function() return 0 end; GetPlayerFacing=function() return 0 end
IsMounted=function() return false end; UnitOnTaxi=function() return false end
UnitClassification=function() return 'normal' end
local casts={}; UnitCastingInfo=function(u) if casts[u] then return 'Frostbolt',nil,nil,now*1000,(now+2)*1000,false,1,false,837 end end
UnitChannelInfo=function() end
local auras={}; C_UnitAuras={GetAuraDataByIndex=function(u,i,filter) return auras[u..filter] and auras[u..filter][i] end}
C_NamePlate={GetNamePlates=function() return {} end}
A.TalentAdvisor.ReadCurrent=function() return nil,'Talent data unavailable in this fixture' end
R.dirty=true; R:RefreshSpells()
check(R.spells.frostbolt.id==837,'Highest actually learned rank selected')
check(not R.spells.fireball,'Unknown spells are not invented')
check(R.spells.slowbolt.id==116,'Rank-one Frostbolt is retained for quick control')
combat=true
