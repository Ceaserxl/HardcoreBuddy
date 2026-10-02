local A=TestAddon; local R=A.RotationAdvisor; local M=A.MageRotation
local count=0
local function check(ok,why) count=count+1; assert(ok,why) end
local function state(keys,level)
    local s={class='MAGE',level=level or 60,spells={},buffs={},talents={},spellPower={},spellCrit={},
        buffDurations={intellect=1200,icearmor=1200,magearmor=1200,barrier=100},
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
check(not R.supported.ROGUE and R.classes.ROGUE and not R.classes.ROGUE.combat,'Rogue class boundary does not restore the old combat prototype')
check(M.BuffRefresh(300,3600) and not M.BuffRefresh(300.001,3600),'Hour buff warning starts at five minutes')
check(M.BuffRefresh(300,1800) and not M.BuffRefresh(301,1800),'Self buff warning uses five minutes instead of a percentage')
check(M.BuffRefresh(60,60),'Short self buffs also fall within the five-minute threshold')
check(M.BuffRefresh(300,nil) and M.BuffRefresh(0,nil) and not M.BuffRefresh(math.huge,nil),'Known remaining time works without duration; indefinite buffs do not warn')
do
    local s=state({'frostbolt','intellect','icearmor','magearmor','barrier'})
    s.buffs={intellect=301,icearmor=301,barrier=301}; s.hasArmor=true
    check(#M.Optional(s)==0,'Healthy buff durations do not prompt refresh')
    s.buffs={intellect=300,icearmor=300,barrier=300}
    check(optional(s,'intellect') and optional(s,'magearmor') and optional(s,'barrier'),'Buff refresh windows begin before expiration')
    check(#M.Optional(s)==3,'Only one armor choice accompanies other expiring buffs')
    decide(s,'frostbolt','Early refresh leaves damage primary intact')
    s.buffs.intellect=1800; s.buffs.icearmor=1800; s.buffs.barrier=301
    check(#M.Optional(s)==0,'Fresh durations clear all early refresh prompts')
    s.buffs={intellect=math.huge,magearmor=math.huge,barrier=math.huge}
    check(#M.Optional(s)==0,'Unknown or unlimited durations do not prompt refresh')
    s.buffs={intellect=30,icearmor=30,barrier=3}; s.powerPercent=10
    check(#M.Optional(s)==0,'Early refresh respects mana reserve')
end
do
    local s=state({'fireball','pyroblast'}); s.combat=false; s.grouped=false; s.targetDistance=30
    decide(s,'pyroblast','Dedicated distant Pyroblast opener beats sustained throughput')
    for _,field in ipairs({'combat','targetCombat','casting','targetDotted'}) do
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
    s.regenDelay=5; decide(s,'shoot','Short wand finish is stable across regeneration timing')
    s.regenDelay=1
    s.attackingPlayer=true; check(R.Decide(s)~='shoot','Closing attacker suppresses deliberate wand finish')
    s.targetDistance=30; s.slowRemaining=10; decide(s,'shoot','Distant slowed attacker permits short wand finish')
    s.attackingPlayer=false
    for _,field in ipairs({'recentDamage','targetClose','casting'}) do
        s[field]=true; check(R.Decide(s)~='shoot','No deliberate wand finishing with '..field); s[field]=false
    end
    s.wandDamage=nil; decide(s,'frostbolt','Unknown wand damage preserves filler')
    s=state({'frostbolt'}); s.spells.managem={id=8008,item=true,restore=1200,ready=true,usable=true}
    s.power=3500; decide(s,'frostbolt','Mana gem leaves damage primary intact')
    check(optional(s,'managem'),'Full restoration fits: gem remains auxiliary')
    s.power=4000; decide(s,'frostbolt','Do not waste gem restoration')
    check(not optional(s,'managem'),'Gem auxiliary respects full restoration threshold')
    s.power=3500; s.spells.managem.ready=false; decide(s,'frostbolt','Respect shared gem cooldown')
    s.spells.managem.ready=true; s.casting=true; decide(s,'frostbolt','Gem does not interrupt current cast')
    check(optional(s,'managem'),'Gem auxiliary persists while casting and moving'); s.moving=true
    check(optional(s,'managem'),'Movement preserves gem auxiliary'); s.moving=false
    s.casting=false; s.spells.counterspell={ready=true,usable=true}; s.interrupt=true
    decide(s,'frostbolt','Enemy interrupt leaves damage primary intact'); check(optional(s,'counterspell') and optional(s,'managem'),'Interrupt and mana gem can coexist')
    s=state({'frostbolt','ruby'}); s.combat=false; s.prepareGem='ruby'; s.spells.ruby.cost=1200
    decide(s,'ruby','Stationary preparation takes priority before pulling')
    local _,_,isOptional=R.Decide(s); check(isOptional,'Gem preparation retains optional glow')
    s.prepareGem=nil; decide(s,'frostbolt','Owned gem does not prompt reconjuring')
    s.prepareGem='ruby'; s.moving=true; decide(s,'ruby','Movement preserves optional preparation preview')
    s.mounted=true; decide(s,'ruby','Mounted gem preparation remains visible'); s.mounted=false
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
s.spells.frostbolt.range=false; check(not R.Ready(s,'frostbolt'),'Current range is required for a ranged spell')
s.spells.frostbolt.immune=true; decide(s,nil,'Observed immunity blocks spell')
s=state({'frostbolt'}); s.spells.frostbolt.ready=false; decide(s,nil,'Cooldown blocks unavailable spells')
s=state({'frostbolt'}); s.spells.frostbolt.usable=false; decide(s,nil,'Other usability failures respected')
s=state({'frostbolt','counterspell'}); s.interrupt=true; decide(s,'frostbolt','Interrupt does not replace damage'); check(optional(s,'counterspell'),'Interrupt gets an independent highlight')
s.spells.counterspell.usable=false; s.spells.counterspell.usableNow=true; check(optional(s,'counterspell'),'Interrupt uses current mana instead of reserving the cast it cancels')
s.spells.counterspell.cooldownRemaining=.8; check(not optional(s,'counterspell'),'Interrupt must actually be ready')
s=state({'frostbolt','barrier'}); s.playerHealth=70; s.attackingPlayer=true; decide(s,'frostbolt','Shield under pressure does not replace damage'); check(optional(s,'barrier'),'Shield has its own highlight')
s.buffs.barrier=20; decide(s,'frostbolt','Do not overwrite shield')
s=state({'frostbolt','iceblock','counterspell'}); s.playerHealth=10; s.recentDamage=true; s.interrupt=true
decide(s,'iceblock','Emergency survival beats damage')
s.buffs.iceblock=10; decide(s,nil,'Never encourage cancelling Ice Block')
s.buffs.iceblock=nil; s.buffs.hypothermia=20; decide(s,'frostbolt','Hypothermia forbids Ice Block'); check(optional(s,'counterspell'),'Interrupt still lights with hypothermia')
s=state({'frostbolt','blink'}); s.rooted=true; s.attackingPlayer=true; decide(s,'frostbolt','Noncritical escape does not replace damage'); check(optional(s,'blink'),'Root escape is highlighted alongside damage')
s=state({'frostbolt','decurse'}); s.curse=true; decide(s,'frostbolt','Curse removal does not replace damage'); check(optional(s,'decurse'),'Self curse removal gets its own highlight')
s=state({'frostbolt','slowfall'}); s.fallingFor=2; decide(s,'slowfall','Sustained fall recommends Slow Fall')
s.buffs.slowfall=10; decide(s,'frostbolt','Existing Slow Fall is respected')
s=state({'frostbolt','counterspell'}); s.interrupt=true; s.validTarget=false; decide(s,nil,'Never interrupt a friendly target')
s=state({'frostbolt','fireblast'}); s.channelKey='missiles'; s.channelRemaining=3; decide(s,nil,'Do not encourage clipping a damage channel')
s.channelRemaining=2; check(R.Decide(s)~=nil,'Next spell previews the final two seconds of a damage channel')
s=state({'frostbolt','counterspell'}); s.channelKey='missiles'; s.channelRemaining=3; s.interrupt=true
decide(s,nil,'Damage channel remains uninterrupted'); check(optional(s,'counterspell'),'Interrupt highlights independently during a running channel')
s=state({'frostbolt','fireward','frostward'}); s.recentDamage=true; s.playerHealth=60; s.damageSchool=4
check(optional(s,'fireward') and not optional(s,'frostward'),'Fire ward matches incoming school'); s.damageSchool=16; check(optional(s,'frostward') and not optional(s,'fireward'),'Frost ward matches incoming school')
s=state({'frostbolt','nova','cone'}); s.attackingPlayer=true; s.targetClose=true; s.playerHealth=50
decide(s,'frostbolt','Noncritical root does not replace damage'); check(optional(s,'nova'),'Root can light alongside damage'); s.safeAOE=false; check(not optional(s,'nova'),'Do not break CC with Nova')
s.safeAOE=true; s.frozen=true; check(not optional(s,'nova'),'Do not re-root an already frozen enemy')
s=state({'frostbolt','shield'}); s.attackingPlayer=true; s.playerHealth=25
decide(s,'shield','Mana Shield emergency'); s.powerPercent=20; decide(s,'frostbolt','Do not drain last mana on Mana Shield')
s=state({'frostbolt','coldsnap','barrier'}); s.playerHealth=20; s.attackingPlayer=true; s.spells.barrier.ready=false
decide(s,'coldsnap','Cold Snap restores defensive cooldown')
s=state({'frostbolt','polymorph'}); s.attackingPlayer=true; s.targets=2; s.polyEligible=true; s.playerHealth=35
check(optional(s,'polymorph'),'Control eligible extra attacker'); s.targetDotted=true; check(not optional(s,'polymorph'),'Do not sheep a dotted target')
s=state({'fireball','intellect','frostarmor'}); s.combat=false
check(optional(s,'intellect') and optional(s,'frostarmor'),'Prepull buffs coexist')
decide(s,'fireball','Prepull buffs do not replace primary'); s.buffs.intellect=301
check(not optional(s,'intellect') and optional(s,'frostarmor'),'Only missing buff remains optional')
s.hasArmor=true; decide(s,'fireball','No repeat armor buff')
s=state({'frostbolt','evocation'}); s.combat=false; s.powerPercent=10
check(optional(s,'evocation'),'Safe optional mana recovery'); s.mounted=true
check(optional(s,'evocation'),'Mounted recovery remains visible as a preview'); decide(s,'frostbolt','Mounted preview remains')
s=state({'frostbolt','evocation'}); s.powerPercent=5; s.timeToDie=30; s.targetCombat=true
decide(s,'frostbolt','Recovery does not replace damage'); check(optional(s,'evocation'),'Safe grouped recovery'); s.recentDamage=true; check(not optional(s,'evocation'),'Do not channel under damage')
s=state({'frostbolt','shoot'}); s.spells.frostbolt.usable=false; decide(s,'shoot','Wand fallback')
s.wanding=true; decide(s,nil,'Never toggle active wand off')
s=state({'fireball','frostbolt'}); s.grouped=false; s.attackingPlayer=true; s.slowRemaining=0; s.targetDistance=25
decide(s,M.BuildProfile(s).main,'Solo approach does not rerank the learned main attack')
s=state({'frostbolt','fireblast'}); s.moving=true; decide(s,'frostbolt','Movement alone does not replace Frostbolt with Fire Blast')
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
decide(s,'fireball','Burst does not replace damage'); check(optional(s,'arcanepower') and optional(s,'combustion'),'Burst cooldowns have independent highlights'); s.buffs.arcanepower=10; check(not optional(s,'arcanepower') and optional(s,'combustion'),'Active burst does not repeat')
s.targetHP=20; check(not optional(s,'combustion'),'Save cooldowns on a low-health target')
s=state({'fireball','presence'}); s.moving=true; s.timeToDie=30; check(optional(s,'presence'),'Presence remains available during movement'); decide(s,'fireball','Presence does not replace damage')
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
GetUnitSpeed=function() error("Rotation must not read movement speed") end; GetPlayerFacing=function() return 0 end
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
