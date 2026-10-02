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
    spellData[10230]={name='Frost Nova',iconID=135848,castTime=0,minRange=0,maxRange=0}; learned[10230]=true
    R:RefreshSpells(); check(R.spells.nova.id==122,'Defensive Nova uses Rank 1 even when a higher damage rank is learned')
    learned[122]=nil; R:RefreshSpells(); check(R.spells.nova.id==10230,'Do not invent Rank 1 if the client does not report it learned')
    learned[122]=true; learned[10230]=nil; R:RefreshSpells()
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
do
    local s=state({'frostbolt','fireball','fireblast','counterspell','iceblock'})
    s.time=100; s.targetGUID='enemy'; s.castToken='cast:1'; s.castEnd=103
    local function choose(key,urgent)
        return R:StabilizeRecommendation(s,key,key..' reason',false,urgent)
    end
    R.castPlan=nil
    check(choose('frostbolt')=='frostbolt' and R.castPlan,'First next-cast recommendation creates a plan')
    s.time=102.9
    check(choose('fireblast')=='frostbolt','Changing damage scores cannot swap the highlight at the end of a cast')
    s.castToken=nil; s.castEnd=nil; s.time=103.05
    check(choose('fireball')=='frostbolt','Cast completion retains the spell the player was preparing to press')
    s.time=104.1; check(choose('fireball')=='fireball' and not R.castPlan,'Idle handoff expires instead of holding stale advice forever')
    s.time=110; s.castToken='cast:2'; s.castEnd=113; choose('frostbolt')
    s.castToken='cast:3'; s.castEnd=115
    check(choose('fireball')=='fireball','Starting the next cast permits a fresh plan even for repeated spells')
    check(choose('counterspell',true)=='counterspell' and not R.castPlan,'Interrupt priority immediately overrides a damage plan')
    choose('frostbolt'); check(choose('iceblock',true)=='iceblock','Survival priority immediately overrides a damage plan')
    choose('frostbolt'); s.targetGUID='other'
    check(choose('fireball')=='fireball','Target changes cannot inherit the previous enemy plan')
    R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.immune=true
    check(choose('fireball')=='fireball','New immunity invalidates the committed spell')
    s.spells.frostbolt.immune=nil; R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.range=false
    check(choose('fireball')=='fireball','Losing range invalidates the committed spell')
    s.spells.frostbolt.range=true; R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.usable=false
    check(choose('fireball')=='fireball','Insufficient mana does not preserve an impossible cast')
    s.spells.frostbolt.usable=true; R.castPlan=nil; choose('frostbolt'); s.controlled=true
    local key=R:StabilizeRecommendation(s,nil,'',false,false)
    check(not key and not R.castPlan,'Crowd control immediately clears the plan')
    s.controlled=false; s.time=110; s.castToken='cast:4'; s.castEnd=113; choose('frostbolt')
    s.castEnd=114; choose('fireball'); check(R.castPlan.finish==114,'Pushback extends the existing plan without replacing it')
    s.castToken=nil; s.castEnd=nil; s.time=111
    check(choose('fireball')=='fireball','An early stop cancels the plan rather than waiting for the old cast end')
    s=state({'explosion','frostbolt'}); s.time=120; s.targetGUID='enemy'; s.castToken='cast:5'; s.castEnd=123
    s.targetClose=true; s.nearby=3; R.castPlan=nil; choose('explosion'); s.safeAOE=false
    check(choose('frostbolt')=='frostbolt','New area danger overrides a committed AoE spell')
    R.castPlan=nil; s.safeAOE=true; choose('explosion'); s.playerHealth=30
    check(choose('frostbolt')=='frostbolt','Health dropping below area safety thresholds invalidates the area plan')
    s=state({'frostbolt','counterspell'}); s.interrupt=true
    local _,_,_,urgent=R.Decide(s); check(urgent==true,'Actual interrupt decisions are marked urgent for the stabilizer')
    s.interrupt=false; _,_,_,urgent=R.Decide(s); check(not urgent,'Ordinary damage decisions can be stabilized')
    -- Reproduce the report through the live update/highlight path, not only the helper.
    local oldCasting=UnitCastingInfo; local oldDecide=R.Decide
    local candidate='frostbolt'; local endTime=now+2
    UnitCastingInfo=function(u) if u=='player' then return 'Frostbolt',nil,nil,(endTime-2)*1000,endTime*1000,false,'live-cast',false,837 end end
    R.Decide=function() return candidate,'test',false,false end
    R.castPlan=nil; R:Update(); local starts=glow.ProcStartAnim.plays
    check(R.current.id==837 and glow:IsShown(),'Live cast holds the first next spell')
    candidate='fireblast'; now=endTime-.1; R:Update()
    check(R.current.id==837 and glow.ProcStartAnim.plays==starts,'End-of-cast reranking neither swaps nor restarts the glow')
    UnitCastingInfo=function() end; now=endTime+.05; R:Update()
    check(R.current.id==837 and glow:IsShown(),'Glow remains on the prepared spell immediately after cast completion')
    now=endTime+1.1; R:Update(); check(R.current.id==2136,'Live idle handoff eventually allows new advice')
    UnitCastingInfo=oldCasting; R.Decide=oldDecide; R.castPlan=nil; R:Update()
end
do
    local oldItem,oldContainer,oldInventory,oldRanged=C_Item,C_Container,GetInventoryItemID,UnitRangedDamage
    local owned,cd,subclass=1,0,19
    C_Item={GetItemCount=function(id,bank) check(bank==false,'Gem count excludes bank'); return id==8008 and owned or 0 end,
        GetItemInfo=function() return 'Mana Ruby',nil,nil,nil,nil,nil,nil,nil,nil,123 end,
        IsUsableItem=function() return true end,
        GetItemInfoInstant=function() return 1,nil,nil,nil,nil,2,subclass end}
    C_Container={GetItemCooldown=function() return cd,120,1 end}
    GetInventoryItemID=function() return 1 end
    UnitRangedDamage=function() return 1.5,40,60 end
    local function resources()
        local s={class='MAGE',time=200,spells={ruby={}}}; R:MageResources(s); return s
    end
    local s=resources(); check(s.wandSpeed==1.5 and s.wandDamage==45,'Live wand damage read conservatively')
    check(s.spells.managem and s.spells.managem.item and not s.prepareGem,'Carried gem becomes item recommendation')
    cd=150; s=resources(); check(not s.spells.managem,'Live gem cooldown suppresses use')
    owned=0; s=resources(); check(s.prepareGem=='ruby' and not s.spells.managem,'Consumed gem enables preparation')
    subclass=2; s=resources(); check(not s.wandDamage,'Do not treat other ranged weapons as wands')
    local oldCount,oldCooldown,oldInfo,oldUsable=GetItemCount,GetItemCooldown,GetItemInfo,IsUsableItem
    GetItemCount=C_Item.GetItemCount; GetItemInfo=C_Item.GetItemInfo; IsUsableItem=C_Item.IsUsableItem
    GetItemCooldown=C_Container.GetItemCooldown; C_Item=nil; C_Container=nil; owned=1; cd=0
    s=resources(); check(s.spells.managem and s.spells.managem.id==8008,'Legacy gem API fallback')
    GetItemCount,GetItemCooldown,GetItemInfo,IsUsableItem=oldCount,oldCooldown,oldInfo,oldUsable
    C_Item,C_Container,GetInventoryItemID,UnitRangedDamage=oldItem,oldContainer,oldInventory,oldRanged
    local oldAction,oldMacro=GetActionInfo,GetMacroItem
    GetActionInfo=function() return 'item',8008 end
    R:Highlight({id=8008,item=true}); check(glow:IsShown(),'Direct mana gem action highlights')
    GetActionInfo=function() return 'macro',8008,'item' end
    R:Highlight({id=8008,item=true}); check(glow:IsShown(),'Resolved item macro highlights')
    GetActionInfo=function() return 'macro',1 end
    GetMacroItem=function() return 'Mana Ruby','item:8008' end
    R:Highlight({id=8008,item=true}); check(glow:IsShown(),'Legacy item macro highlights')
    R:Highlight({id=8008}); check(not glow:IsShown(),'Item macro is never treated as matching spell')
    GetActionInfo,GetMacroItem=oldAction,oldMacro
end
do
    local oldSnapshot,oldAction,oldView=R.Snapshot,GetActionInfo,R.RefreshView
    local s=state({'frostbolt','intellect','barrier','ruby'})
    s.combat=false; s.moving=true; s.prepareGem='ruby'; s.spells.ruby.cost=1200
    s.buffs.intellect=100; s.buffs.barrier=100; s.targetGUID='movement-test'; s.time=now
    R.Snapshot=function() return s end; R.RefreshView=function() end
    GetActionInfo=function(slot)
        return 'spell',slot==1 and s.spells.frostbolt.id or slot==2 and s.spells.barrier.id or s.spells.intellect.id
    end
    R.castPlan=nil; R:Update()
    check(R.primary==s.spells.frostbolt and glow:IsShown(),'Moving keeps primary highlighted')
    local starts=glow.ProcStartAnim.plays
    s.moving=false; R:Update()
    check(R.primary==s.spells.frostbolt and glow:IsShown(),'Stopping cannot replace primary with off-bar gem preparation')
    check(glow.ProcStartAnim.plays==starts,'Stopping preserves primary animation')
    check(#R.optionalActions==1 and R.optionalActions[1]==s.spells.ruby,'Stationary gem preparation remains independently optional')
    s.buffs.intellect=nil; s.buffs.barrier=nil; R:Update()
    check(glow.style=='primary' and R.highlights[other].style=='optional' and R.highlights[lower].style=='optional',
        'One gold damage action coexists with red Barrier and Intellect')
    check(R.primaryHighlightCount==1 and R.optionalHighlightCount==2,'Primary and optional counts remain separate')
    local barrierStarts=R.highlights[other].ProcStartAnim.plays
    s.combat=true; s.moving=true; s.casting=true; R:Update()
    check(R.highlights[other]:IsShown() and R.highlights[lower]:IsShown(),'Missing buffs persist through movement, combat and casts')
    s.moving=false; R:Update()
    check(glow:IsShown() and R.highlights[other].ProcStartAnim.plays==barrierStarts,'Stopping leaves primary and optional animations intact')
    s.buffs.intellect=100; R:Update()
    check(not R.highlights[lower]:IsShown() and R.highlights[other]:IsShown(),'Applying one buff clears only its optional highlight')
    s.casting=false; s.attackingPlayer=true; s.playerHealth=70; R:Update()
    check(R.primary==s.spells.barrier and R.highlights[other].style=='primary','Urgent Barrier is gold, not duplicate red')
    check(not glow:IsShown() and R.primaryHighlightCount==1,'Urgent action replaces the only primary')
    s.playerHealth=100; s.attackingPlayer=false; R:Update()
    check(R.highlights[other].style=='optional' and glow:IsShown(),'Barrier returns to optional when emergency passes')
    s.dead=true; R:Update(); check(R.highlightCount==0,'Death clears primary and all optional highlights')
    s.dead=false; R:Update(); R:SetMode('disabled')
    check(R.highlightCount==0 and #R.optionalActions==0,'Disabled clears every recommendation')
    R.Snapshot,GetActionInfo,R.RefreshView=oldSnapshot,oldAction,oldView
    R:SetMode('assistant')
end
MOCK.class='ROGUE'; check(R:Mode()=='disabled','Old Rogue saved mode no longer enables removed prototype')
MOCK.class='MAGE'; R:Update()
print('PASS: '..count..' Mage rotation, live adapter, UI and highlight regression checks.')
