do
    combat=true
    local oldCosts=C_Spell.GetSpellPowerCost
    C_Spell.GetSpellPowerCost=function(id) return {{type=0,cost=id==837 and 50 or 0,minCost=id==837 and 50 or 0}} end
    GetPowerRegen=function() return 20,5 end; GetManaRegen=GetPowerRegen
    units.player.power=45; R.powerSample=nil; usable[837]=false
    local s=R:Snapshot()
    check(s.spells.frostbolt.powerPreview,'Mana forecast highlights before spell is affordable')
    units.player.power=20; R.powerSample=nil; s=R:Snapshot()
    check(not s.spells.frostbolt.usable,'Large mana deficit is not forecast as ready')
    units.player.power=45; R.powerSample=nil; ready[61304]={startTime=now,duration=1.5,isEnabled=true}
    s=R:Snapshot(); check(s.powerHorizon==1.5 and s.projectedPower==52.5,'Forecast covers remaining GCD')
    ready[837]={startTime=now-6.6,duration=8,isEnabled=true}
    s=R:Snapshot(); check(s.spells.frostbolt.ready,'Cooldown ending during current GCD can be previewed')
    ready={}; units.player.power=80; casts.player=true; R.powerSample=nil
    s=R:Snapshot(); check(s.projectedPower==40 and not s.spells.frostbolt.usable,'Reserve the current cast mana before recommending the next')
    casts={}; usable={}; units.player.power=900
    local oldUsable=C_Spell.IsSpellUsable
    C_Spell.IsSpellUsable=function() return false,false end; IsMounted=function() return true end
    s=R:Snapshot(); check(s.spells.frostbolt.usable and R.Decide(s),'Mounted unusable flag allows a dismount preview')
    UnitOnTaxi=function() return true end; s=R:Snapshot(); check(not R.Decide(s),'Flight path is excluded')
    UnitOnTaxi=function() return false end; IsMounted=function() return false end; C_Spell.IsSpellUsable=oldUsable
    C_Spell.GetSpellPowerCost=oldCosts; GetManaRegen=nil; GetPowerRegen=nil; R.powerSample=nil
end
do
    auras.playerHELPFUL={{name='Clearcasting',spellId=12536,expirationTime=now+10},{name='Brilliance',spellId=23028,expirationTime=now+60}}
    auras.playerHARMFUL={{name='Test Curse',dispelName='Curse',expirationTime=now+10}}
    auras.targetHARMFUL={{name='Frost Nova',spellId=122,expirationTime=now+5},{name='Fire Vulnerability',spellId=22959,applications=3,expirationTime=now+20}}
    local s=R:Snapshot()
    check(s.buffs.clearcasting==10 and s.buffs.intellect==60,'Proc and group Intellect buffs detected by ID')
    check(s.curse and s.frozen and s.scorchStacks==3,'Curse, freeze and vulnerability stacks detected')
    auras={}
    local event={0,'SPELL_DAMAGE',false,'enemy','Enemy',0,0,'player','Player',0,0,123,'Fire',4,20}
    CombatLogGetCurrentEventInfo=function() return unpack(event) end
    R:ObserveCombat(); s=R:Snapshot(); check(s.recentDamage and s.damageSchool==4,'Incoming school informs wards')
    event={0,'SPELL_MISSED',false,'player','Player',0,0,'enemy','Enemy',0,0,837,'Frostbolt',16,'IMMUNE'}
    R:ObserveCombat(); s=R:Snapshot(); check(s.spells.frostbolt.immune and s.spells.slowbolt.immune,'Observed immunity applies to all ranks of Frostbolt')
    units.target.guid='other'; s=R:Snapshot(); check(not s.spells.frostbolt.immune,'Immunity does not leak to another enemy')
    units.target.guid='enemy'; R.lastDamage=nil; R:Snapshot()
    now=now+1; units.target.health=4500; s=R:Snapshot()
    check(s.timeToDie==9,'Target health trend estimates remaining fight duration')
    now=now+1; units.target.health=5000; s=R:Snapshot(); check(not s.timeToDie,'Healing invalidates stale kill-time estimates')
    units.target.x=32; range[837]=false; R.approach=nil; R:Snapshot()
    now=now+.2; units.target.x=31; s=R:Snapshot()
    check(s.spells.frostbolt.approaching,'Mage highlights before an approaching enemy reaches range')
    now=now+.2; units.target.x=32; s=R:Snapshot(); check(not s.spells.frostbolt.approaching,'Fleeing enemy does not create approach preview')
    units.target.x=15; range[837]=true; R.approach=nil
    units.add={health=100,max=100,x=17,y=0,z=0,map=1,guid='add'}
    units.add2={health=100,max=100,x=16,y=0,z=0,map=1,guid='add2'}
    C_NamePlate.GetNamePlates=function() return {{namePlateUnitToken='add'},{namePlateUnitToken='add2'},{namePlateUnitToken='target'}} end
    combat=true; s=R:Snapshot(); check(s.cluster==3 and s.safeCluster,'Ground AoE cluster deduplicates visible enemies')
    auras.addHARMFUL={{name='Polymorph',spellId=118,expirationTime=now+20}}
    s=R:Snapshot(); check(not s.safeCluster,'Crowd control prevents ground AoE')
    auras={}; units.add.x=nil; s=R:Snapshot(); check(not s.safeCluster,'Unknown enemy position prevents unsafe ground AoE')
    units.add=nil; units.add2=nil; C_NamePlate.GetNamePlates=function() return {} end
end
do
    local modern,modernAuras=C_Spell,C_UnitAuras
    C_Spell=nil; C_UnitAuras=nil
    GetSpellInfo=function(id) local v=spellData[id]; if v then return v.name,'Rank',v.iconID,v.castTime,0,v.maxRange end end
    GetSpellCooldown=function() return 0,0,1 end
    IsUsableSpell=function() return true,false end
    IsSpellInRange=function(name) return name=='Frostbolt' and 1 or 0 end
    UnitAura=function(u,i,filter) if u=='player' and i==1 and filter=='HARMFUL' then return 'Curse',nil,1,'Curse',10,now+10,'target',nil,nil,123 end end
    R.dirty=true; local s=R:Snapshot()
    check(s.spells.frostbolt.range==true and s.curse,'Legacy spell and aura adapters support Mage advice')
    C_Spell,C_UnitAuras=modern,modernAuras; UnitAura=nil; R.dirty=true
end
do
    local original=A.TalentAdvisor.ReadCurrent
    A.TalentAdvisor.ReadCurrent=function() return {ranks={firePower=5,improvedFireball=5}} end
    R.talentsReady=false; R.talentRetryAt=now
    local s=R:Snapshot(); check(s.talents.firePower==5,'Retry obtains actual allocated talents after client data loads')
    A.TalentAdvisor.ReadCurrent=function() return {ranks={piercingIce=3}} end
    R.events.scripts.OnEvent(R.events,'PLAYER_TALENT_UPDATE')
    check(R.talents.piercingIce==3 and not R.talents.firePower,'Respec replaces old talent bonuses')
    A.TalentAdvisor.ReadCurrent=original
    spellData[25304]={name='Frostbolt',iconID=135846,castTime=3000,minRange=0,maxRange=30}
    learned[25304]=true; R:RefreshSpells()
    check(R.spells.frostbolt.id==25304,'Learned book-only Frostbolt rank is available without a trainer entry')
    learned[25304]=nil; R:RefreshSpells(); check(R.spells.frostbolt.id==837,'Unlearned higher spell rank is never selected')
    UnitCreatureType=function() return 'Localized Humanoid',7 end
    s=R:Snapshot(); check(s.polyEligible,'Polymorph eligibility uses locale-independent creature ID')
    UnitCreatureType=function() return 'Localized Undead',6 end
    s=R:Snapshot(); check(not s.polyEligible,'Undead targets are not Polymorph candidates')
    C_LossOfControl={GetActiveLossOfControlDataCount=function() return 1 end,GetActiveLossOfControlData=function() return {locType='STUN',timeRemaining=2} end}
    s=R:Snapshot(); check(s.stunned,'Live stun state reaches Blink priority')
    C_LossOfControl=nil
    GetSpellBonusDamage=function(school) return school==3 and 123 or 0 end
    s=R:Snapshot(); check(s.spellPower[3]==123 and s.spellPower[5]==0,'Current school-specific gear bonuses reach the damage scorer')
    GetSpellBonusDamage=function() return 0 end
end
MOCK.class='ROGUE'; check(R:Mode()=='disabled','Old Rogue saved mode no longer enables removed prototype')
MOCK.class='MAGE'; R:Update()
print('PASS: '..count..' Mage rotation, live adapter, UI and highlight regression checks.')
