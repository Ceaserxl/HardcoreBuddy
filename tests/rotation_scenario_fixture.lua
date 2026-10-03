-- Synthetic encounter inputs for policy testing, not a damage simulator.
local A,H=TestAddon,TestAddon.RotationHelper
local F={}; local x
local levels={frostbolt=4,fireball=1,fireblast=6,scorch=22,pyroblast=20,missiles=8,nova=10,counterspell=24,
    intellect=1,frostarmor=1,icearmor=30,magearmor=34,barrier=40,manashield=20,iceblock=30,coldsnap=20,
    decurse=18,evocation=20,arcanePower=40,combustion=40,shoot=5,conjureGem=28}
local talentNames={pyroblast="pyroblast",barrier="iceBarrier",iceblock="iceBlock",coldsnap="coldSnap",arcanePower="arcanePower",combustion="combustion"}
local ranges={frostbolt=30,fireball=35,fireblast=20,scorch=30,pyroblast=35,missiles=30,counterspell=30,shoot=30}
local cooldownAbilities={fireblast=true,nova=true,counterspell=true,barrier=true,iceblock=true,coldsnap=true,evocation=true,arcanePower=true,combustion=true}
function F.build(tree,level)
    local ranks,points={},math.max(0,level-9)
    if tree==3 then
        for i,key in ipairs(A.Data.AdvisorBuilds.MAGE[1].steps) do if i<=points then ranks[key]=(ranks[key] or 0)+1 end end
        return ranks
    end
    local wanted=tree==2 and {"combustion","firePower","criticalMass","improvedScorch","pyroblast","burningSoul","ignite","improvedFireball","flameThrowing","impact","incinerate"}
        or {"arcanePower","arcaneInstability","arcaneMind","arcaneMeditation","arcaneConcentration","arcaneFocus","arcaneSubtlety","improvedArcaneMissiles","improvedCounterspell"}
    local order={}; for index,key in ipairs(wanted) do order[key]=index end
    local candidates={}
    for key,node in pairs(A.Data.AdvisorTalents.MAGE) do
        candidates[#candidates+1]=key
        if node.tree~=tree then order[key]=1000+node.tree*100+node.tier end
    end
    table.sort(candidates,function(a,b)
        if (order[a] or 100)~=(order[b] or 100) then return (order[a] or 100)<(order[b] or 100) end
        return a<b
    end)
    local treePoints={0,0,0}
    for spent=0,points-1 do
        local chosen
        for _,key in ipairs(candidates) do
            local node=A.Data.AdvisorTalents.MAGE[key]
            if (ranks[key] or 0)<node.maxRank and treePoints[node.tree]>=(node.tier-1)*5
                and (not node.prerequisite or (ranks[node.prerequisite] or 0)==A.Data.AdvisorTalents.MAGE[node.prerequisite].maxRank) then chosen=key; break end
        end
        assert(chosen,"Fixture must provide a legal talent point")
        ranks[chosen]=(ranks[chosen] or 0)+1
        local node=A.Data.AdvisorTalents.MAGE[chosen]; treePoints[node.tree]=treePoints[node.tree]+1
    end
    return ranks
end
local function readySpells()
    local byID={}
    for key,def in pairs(H.classes.MAGE.spells) do
        if def.root then byID[def.root]=key end
        for _,id in ipairs(def.ranks or {}) do byID[id]=key end
    end
    for level=1,60 do for _,spell in ipairs(A.Data.ClassSpells.Mage[level] or {}) do
        for _,parent in ipairs(spell.requiredIds or {}) do if byID[parent] then byID[spell.id]=byID[parent] end end
    end end
    x.byID=byID; x.known={}
    for key,def in pairs(H.classes.MAGE.spells) do
        if def.root and x.level>=(levels[key] or 1) and (not talentNames[key] or (x.talents[talentNames[key]] or 0)>0) then x.known[def.root]=true end
    end
    local creates={759,3552,10053,10054}
    for i,level in ipairs({28,38,48,58}) do if x.level>=level then x.known[creates[i]]=true end end
    for level=1,x.level do for _,spell in ipairs(A.Data.ClassSpells.Mage[level] or {}) do
        for _,parent in ipairs(spell.requiredIds or {}) do if x.known[parent] then x.known[spell.id]=true end end
    end end
end
function F.reset(options)
    x={time=100,level=40,health=1000,maxHealth=1000,power=1000,maxPower=1000,targetHealth=1000,targetMax=1000,
        target=true,combat=true,targetCombat=true,grouped=false,distance=25,classification="normal",attacked=false,
        targetGUID="Creature-A",playerAuras={},playerHarmful={},targetAuras={},inventory={},talents={},cooldowns={},costs={},defaultCost=50,
        actionSlots={},macroSpells={},names={},regen=0}
    for k,v in pairs(options or {}) do x[k]=v end
    local talents={}; for k,v in pairs(x.talents) do talents[k]=v end; x.talents=talents
    readySpells()
    MOCK.class="MAGE"; MOCK.level=x.level
    A.characterDB.rotationHelperEnabled=false
    H.state={}; H.recent={}; H.immunities={}; H.supplyItems=nil; H.suspended=nil
    H.lastCast=nil; H.finishedCast=nil
    H.Glow.warnedMissing={}
    H:Rebuild()
    return x
end
function F.evaluate()
    local c=H:Snapshot()
    local picks; picks,H.state=H.Select(c,H.module,H.state)
    return picks,c
end
function F.find(picks,key) for _,p in ipairs(picks) do if p.key==key then return p end end end
function F.main(picks) for _,p in ipairs(picks) do if p.category=="main" then return p.key end end end
function F.describe(picks)
    local out={}
    for _,p in ipairs(picks) do out[#out+1]=p.category..":"..p.key end
    return #out>0 and table.concat(out,", ") or "none"
end
function F.event(event,...)
    A.characterDB.rotationHelperEnabled=true
    H.frame.scripts.OnEvent(H.frame,event,...)
end
F.helper=H

GetTime=function() return x.time end
UnitLevel=function() return x.level end
IsPlayerSpell=function(id) return x.known[id]==true end
IsSpellKnown=IsPlayerSpell
GetSpellInfo=function(id) return x.names[id] or x.byID[id] or "Spell"..id,"Rank",135846,3000 end
C_Spell=nil
GetSpellPowerCost=function(id) return {{type=0,cost=x.byID[id]=="shoot" and 0 or x.costs[x.byID[id]] or x.defaultCost}} end
GetSpellCooldown=function(id)
    local duration=x.cooldowns[x.byID[id]] or cooldownAbilities[x.byID[id]] and x.allCooldowns or 0
    if type(duration)=="table" then
        return duration.start or x.time,duration.duration or 0,duration.enabled==nil and 1 or duration.enabled
    end
    if duration==0 and x.gcdSpells then duration=x.gcd or 0 end
    if id==61304 then duration=x.gcd or 0 end
    return duration>0 and x.time or 0,duration,1
end
GetManaRegen=function() return 20,x.regen end
UnitPower=function() return x.power end
UnitPowerMax=function() return x.maxPower end
UnitPowerType=function() return 0 end
UnitHealth=function(u) return u=="player" and x.health or x.targetHealth end
UnitHealthMax=function(u) return u=="player" and x.maxHealth or x.targetMax end
UnitGUID=function(u) return u=="player" and "Player-A" or x.target and x.targetGUID end
UnitCanAttack=function() return x.target and not x.friendly end
UnitIsDeadOrGhost=function(u) return u=="player" and x.dead or u=="target" and x.targetHealth<=0 or false end
UnitOnTaxi=function() return x.taxi end
UnitAffectingCombat=function(u) if u=="player" then return x.combat else return x.targetCombat end end
IsInGroup=function() return x.grouped end
UnitIsPlayer=function() return x.pvp end
UnitIsTapDenied=function() return x.tapped end
UnitClassification=function() return x.classification end
UnitIsUnit=function() return x.attacked end
IsSpellInRange=function(name)
    if x.unknownRange then return nil end
    return x.distance<=(ranges[name] or 30) and 1 or 0
end
CheckInteractDistance=function() return x.distance<10 end
UnitCastingInfo=function(u)
    local c=u=="player" and x.cast or u=="target" and x.targetCast
    if c then
        local token=c.token or "cast-A"
        if c.noID then token=nil end
        return x.byID[c.id] or "Cast",nil,nil,c.start*1000,c.finish*1000,false,token,c.uninterruptible,c.id
    end
end
UnitChannelInfo=function(u)
    local c=u=="player" and x.channel
    if c then return x.byID[c.id] or "Channel",nil,nil,c.start*1000,c.finish*1000,false,false,c.id end
end
C_UnitAuras={GetAuraDataByIndex=function(u,i,filter)
    if u=="player" and filter=="HARMFUL" then
        return x.playerHarmful[i] or x.cursed and i==1 and {spellId=999,dispelName="Curse"} or nil
    end
    return (u=="player" and x.playerAuras or x.targetAuras)[i]
end}
C_NamePlate=nil
GetItemCount=function(id) return x.inventory[id] or 0 end
C_Item.GetItemCount=GetItemCount
GetItemCooldown=function() return x.time,x.itemCooldown or 0,x.itemEnabled==nil and 1 or x.itemEnabled end
GetInventoryItemLink=function() return x.wand~=false and x.level>=5 and "item:11287" end
GetItemInfoInstant=function() return 11287,nil,nil,"INVTYPE_RANGEDRIGHT" end
A.TalentAdvisor.ReadCurrent=function() return {ranks=x.talents} end
A.Inventory.Read=function() return {available=true,counts=x.inventory} end
GetActionInfo=function(slot)
    local s=x.actionSlots[slot]; if s then return s[1],s[2],s[3] end
end
GetMacroSpell=function(id) return x.macroSpells[id] end
InCombatLockdown=function() return x.combat end
return F
