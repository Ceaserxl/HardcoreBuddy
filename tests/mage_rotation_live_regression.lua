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
    check(s.gcdRemaining==1.5,'Snapshot records remaining GCD independently of spell cooldown readiness')
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
    -- Level 42 capture: water already restores mana, so preserve Evocation.
    local oldDrink=spellData[1135]; local oldAuras=auras
    spellData[1135]={name='Localized Drink'}
    auras={playerHELPFUL={{name='Localized Drink',spellId=1135,duration=30,expirationTime=now+30}}}
    local snapshot=R:Snapshot()
    check(snapshot.drinking,'Live shared snapshot identifies the localized drinking aura')
    local s=state({'evocation','intellect','icearmor'}); s.combat=false; s.powerPercent=17.23; s.drinking=snapshot.drinking
    check(not optional(s,'evocation'),'Recorded 17 percent mana while drinking does not suggest Evocation')
    s.powerPercent=60
    check(optional(s,'intellect') and optional(s,'icearmor'),'Drinking leaves unrelated preparation advice available')
    auras.playerHELPFUL={}; s.drinking=R:Snapshot().drinking; s.powerPercent=17.23
    check(not s.drinking and optional(s,'evocation'),'Low-mana Evocation returns if drinking stops')
    auras.playerHELPFUL={{name='Localized Drink',spellId=1135,expirationTime=now-1}}
    check(not R:Snapshot().drinking,'Expired water aura does not block recovery')
    local modern=C_Spell; C_Spell=nil
    local oldInfo=GetSpellInfo; GetSpellInfo=function(id) if id==1135 then return 'Localized Drink' end end
    check(A.ConsumableBuffs.IsDrinking({['Localized Drink']=30}),'Legacy localized spell lookup recognizes drinking')
    GetSpellInfo=function() end
    check(not A.ConsumableBuffs.IsDrinking({Drink=30}),'Unknown localized aura does not invent drinking state')
    C_Spell=modern; GetSpellInfo=oldInfo; spellData[1135]=oldDrink; auras=oldAuras
end
do
    auras.playerHELPFUL={{name='Clearcasting',spellId=12536,expirationTime=now+10},{name='Brilliance',spellId=23028,expirationTime=now+60}}
    auras.playerHARMFUL={{name='Test Curse',dispelName='Curse',expirationTime=now+10}}
    auras.targetHARMFUL={{name='Frost Nova',spellId=122,expirationTime=now+5},{name='Fire Vulnerability',spellId=22959,applications=3,expirationTime=now+20}}
    local s=R:Snapshot()
    check(s.buffs.clearcasting==10 and s.buffs.intellect==60,'Proc and group Intellect buffs detected by ID')
    check(s.curse and s.frozen and s.scorchStacks==3,'Curse, freeze and vulnerability stacks detected')
    local oldNames=R.names
    R.names={intellect='Intellect',icearmor='Ice Armor'}
    auras.playerHELPFUL={{name='Intellect',expirationTime=now+300},
        {name='Brilliance',spellId=23028,expirationTime=now+30},
        {name='Ice Armor',expirationTime=now+45}}
    s=R:Snapshot()
    check(s.buffs.intellect==300 and s.buffs.icearmor==45,'Live snapshot retains armor time and longest Intellect coverage')
    auras.playerHELPFUL={{name='Brilliance',spellId=23028,expirationTime=now+30}}
    s=R:Snapshot(); check(s.buffs.intellect==30,'Expiring Brilliance feeds early Intellect refresh')
    R.names=oldNames
    auras={}
    local event={0,'SPELL_DAMAGE',false,'enemy','Enemy',0,0,'player','Player',0,0,123,'Fire',4,20}
    CombatLogGetCurrentEventInfo=function() return unpack(event) end
    R:ObserveCombat(); s=R:Snapshot(); check(s.recentDamage and s.damageSchool==4,'Incoming school informs wards')
    event={0,'SPELL_MISSED',false,'player','Player',0,0,'enemy','Enemy',0,0,837,'Frostbolt',16,'IMMUNE'}
    R:ObserveCombat(); s=R:Snapshot(); check(s.spells.frostbolt.immune and s.spells.slowbolt.immune,'Observed immunity applies to all ranks of Frostbolt')
    units.target.guid='other'; s=R:Snapshot(); check(not s.spells.frostbolt.immune,'Immunity does not leak to another enemy')
    units.target.guid='enemy'; R.lastDamage=nil; R:Snapshot()
    local oldFireball=R.spells.fireball
    R.spells.fireball={id=133,name='Fireball',castTime=1.5}
    local blast=R.spells.fireblast
    check(blast~=nil,'Live fixture has learned Fire Blast')
    event={0,'SPELL_MISSED',false,'player','Player',0,0,'enemy','Enemy',0,0,blast.id,'Fire Blast',4,'IMMUNE'}
    R:ObserveCombat(); s=R:Snapshot()
    check(s.spells.fireblast.immune and s.spells.fireball.immune,'Pure damage immunity blocks the Fire school')
    check(not s.spells.frostbolt.immune,'Fire immunity leaves Frostbolt available')
    units.target.guid='fire-other'; s=R:Snapshot()
    check(not s.spells.fireblast.immune and not s.spells.fireball.immune,'School immunity never leaks to another target')
    units.target.guid='enemy'; R:Snapshot()
    R:ObserveCombat(); now=now+16; s=R:Snapshot()
    check(not s.spells.fireball.immune,'Observed school immunity expires and permits reassessment')
    R:ObserveCombat()
    event={0,'SPELL_DAMAGE',false,'player','Player',0,0,'enemy','Enemy',0,0,blast.id,'Fire Blast',4,100}
    R:ObserveCombat(); s=R:Snapshot()
    check(not s.spells.fireblast.immune and not s.spells.fireball.immune,'Successful Fire damage clears stale immunity')
    event={0,'SPELL_MISSED',false,'player','Player',0,0,'enemy','Enemy',0,0,blast.id,'Fire Blast',4,'RESIST'}
    R:ObserveCombat(); s=R:Snapshot()
    check(not s.spells.fireball.immune,'A normal resist does not imply school immunity')
    R.spells.fireball=oldFireball
    R.healthSample=nil; R:Snapshot()
    now=now+1; units.target.health=4500; s=R:Snapshot()
    check(not s.timeToDie,'One burst does not establish target death time')
    now=now+2; units.target.health=4000; s=R:Snapshot()
    check(not s.timeToDie,'Two hits still require four seconds of observation')
    now=now+1; s=R:Snapshot()
    check(s.timeToDie==16,'Sustained target trend includes time between spell hits')
    now=now+.2; units.target.health=5000; s=R:Snapshot(); check(not s.timeToDie,'Healing immediately invalidates kill-time estimates')
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
    local s=state({'frostbolt','fireball','fireblast','scorch','counterspell','iceblock'})
    s.time=100; s.targetGUID='enemy'; s.castToken='cast:1'; s.castEnd=103
    local function choose(key,urgent)
        return R:StabilizeRecommendation(s,key,key..' reason',false,urgent)
    end
    R.castPlan=nil
    check(choose('frostbolt')=='frostbolt' and R.castPlan,'First next-cast recommendation creates a plan')
    s.time=102.9
    check(choose('fireblast')=='frostbolt','Changing damage scores cannot swap the highlight at the end of a cast')
    check(choose('scorch')=='frostbolt','Late Scorch upkeep cannot replace planned Frostbolt')
    s.spells.frostbolt.usable=false
    check(choose('scorch')==nil,'Temporary power failure cannot substitute Scorch near completion')
    s.spells.frostbolt.usable=true
    check(choose('scorch')=='frostbolt','Original plan returns after transient power failure')
    s.castToken=nil; s.castEnd=nil; s.time=103.05
    check(choose('fireball')=='frostbolt','Cast completion retains the spell the player was preparing to press')
    s.time=104.1; check(choose('fireball')=='fireball' and not R.castPlan,'Idle handoff expires instead of holding stale advice forever')
    s.time=110; s.castToken='cast:2'; s.castEnd=113; choose('frostbolt')
    s.castToken='cast:3'; s.castEnd=115
    check(choose('fireball')=='fireball','Starting the next cast permits a fresh plan even for repeated spells')
    R.castPlan=nil
    R:StabilizeRecommendation(s,nil,'',false,false)
    check(choose('scorch')==nil,'An empty cast-start plan does not introduce a late damage choice')
    s.castToken='cast:3b'; check(choose('scorch')=='scorch','Next cast start can select Scorch')
    check(choose('counterspell',true)=='counterspell' and not R.castPlan,'Interrupt priority immediately overrides a damage plan')
    choose('frostbolt'); check(choose('iceblock',true)=='iceblock','Survival priority immediately overrides a damage plan')
    choose('frostbolt'); s.targetGUID='other'
    check(choose('fireball')=='fireball','Target changes cannot inherit the previous enemy plan')
    R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.immune=true
    check(choose('fireball')==nil,'New immunity invalidates the committed spell without a late replacement')
    s.spells.frostbolt.immune=nil; R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.range=false
    check(choose('fireball')==nil,'Losing range invalidates the committed spell without a late replacement')
    s.spells.frostbolt.range=true; R.castPlan=nil; choose('frostbolt'); s.spells.frostbolt.usable=false
    check(choose('fireball')==nil,'Insufficient mana does not preserve an impossible cast without a late replacement')
    s.spells.frostbolt.usable=true; R.castPlan=nil; choose('frostbolt'); s.controlled=true
    local key=R:StabilizeRecommendation(s,nil,'',false,false)
    check(not key and R.castPlan,'Crowd control suppresses the plan without late reranking')
    s.controlled=false; s.time=110; s.castToken='cast:4'; s.castEnd=113; choose('frostbolt')
    s.castEnd=114; choose('fireball'); check(R.castPlan.finish==114,'Pushback extends the existing plan without replacing it')
    s.castToken=nil; s.castEnd=nil; s.time=111
    check(choose('fireball')=='fireball','An early stop cancels the plan rather than waiting for the old cast end')
    s=state({'explosion','frostbolt'}); s.time=120; s.targetGUID='enemy'; s.castToken='cast:5'; s.castEnd=123
    s.targetClose=true; s.nearby=3; R.castPlan=nil; choose('explosion'); s.safeAOE=false
    check(choose('frostbolt')==nil,'New area danger overrides a committed AoE spell without a late replacement')
    R.castPlan=nil; s.safeAOE=true; choose('explosion'); s.playerHealth=30
    check(choose('frostbolt')==nil,'Health dropping below area safety thresholds invalidates the area plan without a late replacement')
    s=state({'frostbolt','counterspell'}); s.interrupt=true
    local _,_,_,urgent=R.Decide(s); check(not urgent and optional(s,'counterspell'),'Interrupt stays independent of the primary cast lock')
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
        local s={class='MAGE',time=200,spells={ruby={}}}; R:Class("MAGE").Resources(R,s); return s
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
    s.combat=false; s.moving=true; s.spells.ruby.cost=1200
    s.buffs.intellect=301; s.buffs.barrier=301; s.targetGUID='movement-test'; s.time=now
    R.Snapshot=function() return s end; R.RefreshView=function() end
    GetActionInfo=function(slot)
        return 'spell',slot==1 and s.spells.frostbolt.id or slot==2 and s.spells.barrier.id or s.spells.intellect.id
    end
    R.castPlan=nil; R:Update()
    check(R.primary==s.spells.frostbolt and glow:IsShown(),'Moving keeps primary highlighted')
    local starts=glow.ProcStartAnim.plays
    s.prepareGem='ruby'; R:Update()
    check(R.current==s.spells.ruby and not R.optional,'Gem preview stays available while moving')
    s.moving=false; R:Update()
    check(R.current==s.spells.ruby and not R.optional and not glow:IsShown(),'Stopping restores stationary gem preparation even when off-bar')
    check(R.primary==s.spells.ruby,'OOC gem preparation is a gold primary')
    s.prepareGem=nil; R:Update(); check(glow:IsShown(),'Finishing preparation restores damage advice')
    s.buffs.intellect=nil; s.buffs.barrier=nil; R:Update()
    check(R.primaryHighlightCount==2 and R.optionalHighlightCount==0,'OOC Intellect and Barrier are simultaneous gold primaries')
    s.combat=true; R:Update()
    check(glow.style=='primary' and R.highlights[other].style=='primary' and R.highlights[lower].style=='primary',
        'One gold damage action coexists with red Barrier and Intellect')
    check(R.primaryHighlightCount==1 and R.optionalHighlightCount==2,'Primary and optional counts remain separate')
    local barrierStarts=R.highlights[other].ProcStartAnim.plays
    s.combat=true; s.moving=true; s.casting=true; R:Update()
    check(R.highlights[other]:IsShown() and R.highlights[lower]:IsShown(),'Missing buffs persist through movement, combat and casts')
    s.moving=false; R:Update()
    check(glow:IsShown() and R.highlights[other].ProcStartAnim.plays==barrierStarts,'Stopping leaves primary and optional animations intact')
    s.buffs.intellect=1800; R:Update()
    check(not R.highlights[lower]:IsShown() and R.highlights[other]:IsShown(),'Applying one buff clears only its optional highlight')
    s.casting=false; s.attackingPlayer=true; s.playerHealth=20; R:Update()
    check(R.primary==s.spells.barrier and R.highlights[other].style=='primary','Urgent Barrier is gold, not duplicate red')
    check(not glow:IsShown() and R.primaryHighlightCount==1,'Urgent action replaces the only primary')
    s.playerHealth=100; s.attackingPlayer=false; R:Update()
    check(R.highlights[other].style=='primary' and glow:IsShown(),'Barrier returns to optional when emergency passes')
    s.dead=true; R:Update(); check(R.highlightCount==0,'Death clears primary and all optional highlights')
    s.dead=false; R:Update(); R:SetMode('disabled')
    check(R.highlightCount==0 and #R.optionalActions==0,'Disabled clears every recommendation')
    R.Snapshot,GetActionInfo,R.RefreshView=oldSnapshot,oldAction,oldView
    R:SetMode('assistant')
end
do
    local oldItem,oldContainer,oldBuild,oldAuras=C_Item,C_Container,A.Supplies.Build,R.Auras
    local owned,active,cooling={ [1]=1,[2]=1,[3]=1,[4]=1 },{},false
    local rows={
        {itemId=1,family='recovery',tracking=true,item={level=1}},
        {itemId=2,family='drink',tracking=true,item={level=1}},
        {itemId=3,family='elixir',category='Elixirs',tracking=true,item={level=1,detail='Increases armor for 1 hour.'}},
        {itemId=4,family='scroll-spirit',category='Scrolls',tracking=true,item={level=1}},
    }
    C_Item={GetItemCount=function(id,bank) check(not bank,'Preparation excludes bank stock'); return owned[id] or 0 end,
        GetItemSpell=function(id) return 'Buff'..id,100+id end,
        GetItemInfo=function(id) return 'Item'..id,nil,nil,nil,nil,nil,nil,nil,nil,123 end,
        IsUsableItem=function() return true end}
    C_Container={GetItemCooldown=function() return cooling and 200 or 0,cooling and 120 or 0,1 end}
    A.Supplies.Build=function() return rows end; R.Auras=function() return active,{Buff3=1200,Buff4=1200,['Localized Well Fed']=1200,['Localized Mana Regeneration']=1200} end
    R.supplyAdviceAt=nil
    local s={class='MAGE',level=40,time=200,buffs={},spells={},playerHealth=50,powerPercent=50}
    check(#R:OutOfCombatSupplies(s)==4,'Food drink elixir and scroll can be recommended together')
    check(R.supplyChecks[2].owned==1 and R.supplyChecks[2].eligible and R.supplyChecks[2].usable,'Supply trace records water ownership and availability')
    active={Buff1=20,Buff2=20,Buff3=301,Buff4=301}
    check(#R:OutOfCombatSupplies(s)==0,'Active recovery and healthy buff durations suppress repeated use')
    active.Buff3=300; active.Buff4=300
    check(#R:OutOfCombatSupplies(s)==2,'Long consumable buffs refresh in final five minutes')
    owned[3]=0; rows[4].tracking=false
    check(#R:OutOfCombatSupplies(s)==0,'Missing or untracked consumables never highlighted')
    active={}; s.playerHealth=100; s.powerPercent=100
    check(#R:OutOfCombatSupplies(s)==0,'Full resources do not suggest recovery')
    s.playerHealth=50; s.powerPercent=50; cooling=true
    check(#R:OutOfCombatSupplies(s)==0,'Consumable cooldowns respected')
    check(not R.supplyChecks[2].eligible and R.supplyChecks[2].cooldownDuration==120,'Supply trace explains cooldown suppression')
    cooling=false; s.combat=true
    check(#R:OutOfCombatSupplies(s)==0,'Preparation items cannot enter combat recommendations')
    s.combat=false; s.playerHealth=100; s.powerPercent=100
    local oldFoodInfo=spellData[19705]; local oldManaInfo=spellData[18194]
    spellData[19705]={name='Localized Well Fed'}; spellData[18194]={name='Localized Mana Regeneration'}
    rows[#rows+1]={itemId=5,family='wellfed',tracking=true,priority='Optional',item={level=45}}
    rows[#rows+1]={itemId=6,family='manafood',tracking=true,priority='Essentials',item={level=30}}
    owned[5]=1; owned[6]=1
    local food=R:OutOfCombatSupplies(s)
    check(#food==1 and food[1].id==6,'One class-preferred buff food is suggested even at full health and mana')
    active['Localized Well Fed']=301
    check(#R:OutOfCombatSupplies(s)==0,'Lasting Well Fed suppresses food independently of eating aura')
    active['Localized Well Fed']=300
    check(#R:OutOfCombatSupplies(s)==1,'Buff food refresh appears in final five minutes')
    active.Buff6=20
    -- Both food items share the same eating spell in the real client.
    local originalSpell=C_Item.GetItemSpell
    C_Item.GetItemSpell=function(id) if id==5 or id==6 then return 'Eating',1000 end return originalSpell(id) end
    active.Eating=20
    check(#R:OutOfCombatSupplies(s)==0,'Eating blocks repeated buff-food suggestions before Well Fed applies')
    active={['Localized Mana Regeneration']=900}
    check(#R:OutOfCombatSupplies(s)==0,'Mana food lasting buff is also respected')
    active={}; owned[5]=0; owned[6]=0
    check(#R:OutOfCombatSupplies(s)==0,'Buff food requires carried stock')
    spellData[19705]=oldFoodInfo; spellData[18194]=oldManaInfo
    C_Item,C_Container,A.Supplies.Build,R.Auras=oldItem,oldContainer,oldBuild,oldAuras
    R.supplyAdviceAt=nil; R.supplyAdviceRows=nil
end
MOCK.class='ROGUE'; check(R:Mode()=='assistant' and not R.supported.ROGUE,'Rogue shares preparation without reviving its removed combat prototype')
MOCK.class='MAGE'; R:Update()
do
    local actionInfo=GetActionInfo
    GetActionInfo=function() return 'spell',837 end
    R:Highlight({id=837,buffColor='refresh'},false)
    check(glow.style=='refresh' and glow.ProcLoopFlipbook.vertexColor[3]==1 and glow.ProcLoopFlipbook.vertexColor[1]==.15,'Expiring buff has blue animation')
    local starts=glow.ProcStartAnim.plays
    R:Highlight({id=837,buffColor='primary'},true)
    check(glow.style=='primary' and not glow.ProcLoopFlipbook.desaturated,'Missing buff is gold even in optional group')
    check(glow.ProcStartAnim.plays==starts,'Blue-to-gold transition does not restart animation')
    GetActionInfo=actionInfo; R:Update()
end
do
    check(R.logging,'Rotation diagnostics start automatically')
    local oldIntellect=R.spells.intellect; local oldAuras=auras
    R.spells.intellect={id=1461,name='Arcane Intellect'}
    auras={playerHELPFUL={{name='Greater Intellect',spellId=11396,expirationTime=now+1,duration=3600}}}
    local snap=R:Snapshot()
    check(snap.intellectBlocked and snap.intellectBlocker.power==25,'Greater Intellect blocks weaker learned rank until expiration')
    check(not optional(snap,'intellect'),'Blocked Intellect does not highlight even during refresh window')
    R.spells.intellect={id=10157,name='Arcane Intellect'}
    snap=R:Snapshot(); check(not snap.intellectBlocked,'Rank five Intellect is stronger than the elixir')
    R.spells.intellect={id=1459,name='Arcane Intellect'}
    auras.playerHELPFUL[1]={name='Lesser Intellect',spellId=3166,expirationTime=now+100,duration=3600}
    snap=R:Snapshot(); check(snap.intellectBlocked,'Lesser Intellect blocks rank one')
    auras.playerHELPFUL={}; snap=R:Snapshot(); check(not snap.intellectBlocked,'Expired elixir restores normal Intellect recommendation')
    R.spells.intellect=oldIntellect; auras=oldAuras
    local log=A.characterDB.rotationDiagnostics
    check(log.version==2 and log.count>0,'Current session is a persisted delta trace')
    local total=log.count
    R:TraceRotation('poll'); R:TraceRotation('poll')
    check(log.count==total+2,'Every prediction sample is retained')
    local oldPrint=A.Print; A.Print=function() end
    R:Diagnostics('mark')
    local patch=log.entries[log.count].delta
    check(patch.fields.event.value=='USER_MARK','Automatic log supports issue markers')
    for i=1,305 do R:TraceRotation('retention-test',true) end
    check(log.count>300 and #log.entries==log.count,'Complete session is not truncated to a ring buffer')
    local original=log
    R.loggingInitialized=nil; R:BeginDiagnostics()
    check(A.characterDB.rotationDiagnosticsPrevious==original and A.characterDB.rotationDiagnostics.count==0,'Reload initialization archives prior session and creates fresh log')
    local current=A.characterDB.rotationDiagnostics
    local secondPrevious=A.characterDB.rotationDiagnosticsPrevious2
    R:BeginDiagnostics(); check(A.characterDB.rotationDiagnostics==current,'World transitions cannot rotate the log twice')
    check(A.characterDB.rotationDiagnosticsPrevious2==secondPrevious,'World transitions preserve second previous capture')
    R:Update(); check(current.count==1 and current.entries[1].delta.fields.state,'New session starts with full state')
    local function replay(before,patch)
        if not patch then return before end
        if patch.remove then return nil end
        if patch.fields then
            local out=type(before)=='table' and before or {}
            for key,value in pairs(patch.fields) do out[key]=replay(out[key],value) end
            return out
        end
        return patch.value
    end
    local restored=replay(nil,current.entries[1].delta)
    check(restored.state.power==R.snapshot.power and restored.selected.id==R.current.id,'Full sample can be reconstructed from first delta')
    check(type(restored.state.drinking)=='boolean' and type(restored.state.gcdRemaining)=='number'
        and restored.state.drinking==R.snapshot.drinking and restored.state.gcdRemaining==R.snapshot.gcdRemaining,
        'Diagnostic replay retains drinking state and remaining GCD')
    local savedPower=R.snapshot.power
    R.snapshot.power=1; R:TraceRotation('delta-test',true)
    restored=replay(restored,current.entries[2].delta)
    check(restored.state.power==1 and restored.event=='delta-test','Later delta preserves and changes the correct fields')
    R:TraceRotation('delta-test',true)
    check(current.entries[3].delta==nil,'Unchanged false fields do not inflate every log sample')
    R.snapshot.power=savedPower
    R.events.scripts.OnEvent(R.events,'PLAYER_LOGOUT')
    check(current.entries[current.count].delta.fields.event.value=='PLAYER_LOGOUT','Logout records final state')
    R:Diagnostics('off'); check(R.logging,'Legacy off command cannot silently disable automatic capture')
    -- Simulate enough reloads to evict the oldest capture, preserving samples.
    local discarded=A.characterDB.rotationDiagnosticsPrevious
    R.loggingInitialized=nil; R:BeginDiagnostics()
    check(A.characterDB.rotationDiagnosticsPrevious==current and A.characterDB.rotationDiagnosticsPrevious2==discarded,'Second reload retains two completed sessions')
    R:Update(); local third=A.characterDB.rotationDiagnostics
    R.loggingInitialized=nil; R:BeginDiagnostics()
    check(A.characterDB.rotationDiagnosticsPrevious==third and A.characterDB.rotationDiagnosticsPrevious2==current,'Third reload evicts the oldest completed session')
    check(A.characterDB.rotationDiagnostics~=third,'Retention includes a fresh current session')
    R.loggingInitialized=nil; R:BeginDiagnostics()
    check(A.characterDB.rotationDiagnosticsPrevious==third and A.characterDB.rotationDiagnosticsPrevious2==current,'Empty sessions do not evict useful captures')
    R:Update()
    A.Print=oldPrint
end

-- First live log: opening pull casts must not be masked by drinking advice.
do
    local oldSnapshot,oldSupplies,oldView=R.Snapshot,R.OutOfCombatSupplies,R.RefreshView
    local s=state({'frostbolt'}); s.combat=false; s.time=100; s.targetGUID='pull'
    s.casting=true; s.castToken='cast:pull'; s.castEnd=103; s.rotationCast=true
    R.Snapshot=function() return s end; R.RefreshView=function() end
    R.OutOfCombatSupplies=function() return {{id=1645,item=true,name='Moonberry Juice'}} end
    R.castPlan=nil; R:Update('UNIT_SPELLCAST_START')
    check(R.primary==s.spells.frostbolt and #R.oocActions==0,'Opening Frostbolt stays primary before combat flag is set')
    s.casting=false; s.castToken=nil; s.rotationCast=nil; s.time=103.1
    R:Update('UNIT_SPELLCAST_STOP')
    check(R.primary==s.spells.frostbolt,'Opening cast handoff preserves damage instead of water')
    s.combat=true; s.casting=true; s.castToken='cast:second'; s.castEnd=106
    s.spells.managem={id=5513,item=true,restore=650,ready=true,usable=true}; s.power=3000
    R:Update('UNIT_SPELLCAST_START'); local primary=R.primary
    check(R.optionalActions[1]==s.spells.managem,'Mana gem remains auxiliary during damage cast')
    s.casting=false; s.castToken=nil; s.time=106.1; R:Update('UNIT_SPELLCAST_STOP')
    check(R.primary==primary and R.optionalActions[1]==s.spells.managem,'Gem does not steal primary at cast completion')
    R.castPlan=nil; s.rotationCast=false; s.castToken='cast:opening'; s.castEnd=111
    R:StabilizeRecommendation(s,nil,'',false,false)
    check(R.castPlan==nil,'Opening interaction cannot create an empty damage plan')
    R.Snapshot,R.OutOfCombatSupplies,R.RefreshView=oldSnapshot,oldSupplies,oldView
    R.castPlan=nil; R:Update()
end


-- Replay the short burst which previously forced a premature Scorch choice.
do
    local sample=R.healthSample
    R.healthSample=nil
    local function observe(t,hp,guid)
        local snapshot={time=t,targetHP=hp,validTarget=true}
        R:TargetLife(snapshot,guid or 'trend-regression')
        return snapshot
    end
    observe(177.05,1604)
    observe(178.502,1224)
    observe(180.671,825)
    local snapshot=observe(181.068,825)
    check(snapshot.timeToDie>2.5,'Recorded burst does not predict death before the next Frostbolt')
    snapshot=observe(181.292,825)
    check(snapshot.timeToDie>2.5,'Recorded cast-start trend preserves time for Frostbolt')
    local decision=state({'frostbolt','scorch'},41)
    decision.targetHP=825; decision.timeToDie=snapshot.timeToDie
    decision.talents.frostbolt=5
    local score=M.Estimate(decision,'frostbolt').score
    decision.timeToDie=nil
    check(M.Estimate(decision,'frostbolt').score==score,'Recorded trend does not penalize the full Frostbolt cast')
    local before=snapshot.timeToDie
    snapshot=observe(182.292,825)
    check(snapshot.timeToDie>before,'Between-hit downtime lengthens the estimate')
    snapshot=observe(183,900)
    check(not snapshot.timeToDie,'Healing resets rolling health history')
    observe(184,800); observe(187,600)
    snapshot=observe(189,600)
    check(snapshot.timeToDie~=nil,'Idle intervals between spells retain the rolling trend')
    snapshot=observe(192,600); snapshot=observe(194,600)
    check(not snapshot.timeToDie,'Stalled damage stops publishing stale death predictions')
    R.healthSample=nil
    observe(184,800); observe(187,600)
    snapshot=observe(187.2,600,'different-target')
    check(not snapshot.timeToDie,'Target changes cannot inherit death estimates')
    observe(188.2,500); observe(191.2,400)
    snapshot=observe(196.3,300)
    check(not snapshot.timeToDie,'A long observation gap resets confidence')
    R.healthSample=nil
    for i=0,100 do snapshot=observe(i*.1,2000-i*5) end
    check(#R.healthSample.samples<=64,'Health history remains bounded under rapid damage')
    snapshot=observe(11,0)
    check(not snapshot.timeToDie and not R.healthSample,'Dead targets clear the health history')
    R.healthSample=sample
end

-- The Lesser Infernal log had 240 HP, a 1.657-second trend, and Fire immunity.
do
    local s=state({'frostbolt','scorch','fireball','fireblast'},41)
    s.spells.frostbolt.castTime=2.5; s.spellPower[5]=200; s.targetHP=240; s.timeToDie=1.657
    local score=M.Estimate(s,'frostbolt').score
    s.timeToDie=nil
    check(M.Estimate(s,'frostbolt').score==score,'A lethal Frostbolt is not penalized by its own death forecast')
    s.timeToDie=1.657; s.spells.fireblast.immune=true
    decide(s,'frostbolt','Lethal Frostbolt beats nonlethal Scorch after an immune Fire Blast')
    s.targetHP=825
    check(M.Estimate(s,'frostbolt').score==score,'A short death forecast no longer penalizes the normal attack')
    s.spells.fireball.immune=true; s.spells.scorch.immune=true
    decide(s,'frostbolt','Observed Fire immunity leaves the finishing Frostbolt')
end

-- Instant attempts and failures are logged, not just spells with cast bars.
do
    local handler=R.events.scripts.OnEvent
    handler(R.events,'UNIT_SPELLCAST_SENT','player','Enemy','attempt-token',8413)
    check(R.lastCastEvent.id==8413 and R.lastCastEvent.token=='attempt-token' and R.lastCastEvent.target=='Enemy','Sent spell records the spell and destination')
    handler(R.events,'UNIT_SPELLCAST_FAILED','player','attempt-token',8413)
    check(R.lastCastEvent.id==8413 and R.lastCastEvent.event=='UNIT_SPELLCAST_FAILED','Failed instant spell retains its identity')
    handler(R.events,'UNIT_SPELLCAST_SUCCEEDED','player','success-token',8413)
    check(R.lastCastEvent.id==8413 and R.lastCastEvent.token=='success-token' and not R.lastCastEvent.target,'Successful instant spell uses the standard event argument order')
    local log=A.characterDB.rotationDiagnostics
    local fields=log.entries[log.count].delta.fields.castEvent.fields
    check(fields.event.value=='UNIT_SPELLCAST_SUCCEEDED','Attempt metadata is persisted in the diagnostic delta')
end

-- Level-41 solo Frost talents should inform control as well as damage.
do
    local s=state({'frostbolt','nova'},41)
    s.spellPower[5]=200; s.talents.shatter=5; s.talents.iceShards=5
    s.talents.improvedFrostbolt=5; s.talents.piercingIce=3
    s.grouped=false; s.attackingPlayer=true; s.targetClose=true; s.targetHP=1200
    decide(s,'frostbolt','Healthy solo Shatter Mage keeps its damage primary'); check(optional(s,'nova'),'Proactive Shatter root has an independent highlight')
    s.channelKey='evocation'; decide(s,nil,'Proactive Nova does not interrupt mana recovery'); s.channelKey=nil
    s.safeAOE=false; check(not optional(s,'nova'),'Proactive Nova respects nearby crowd control')
    s.safeAOE=true; s.frozen=true; s.frozenRemaining=5
    decide(s,'frostbolt','Use frozen-target Frostbolt after Nova'); check(not optional(s,'nova'),'Do not root an already frozen target')
    s.frozen=false; s.grouped=true
    check(not optional(s,'nova'),'Do not impose solo rooting on grouped damage')
    s.grouped=false; s.targetHP=100
    check(not optional(s,'nova'),'Do not spend Nova on a target within one finishing cast')
    s.targetHP=1200; s.rotationCast=true; s.casting=true
    s.targetHP=M.Estimate(s,'frostbolt').damage*1.5
    check(not optional(s,'nova'),'Pending current damage prevents a wasteful finishing Nova')
    s.casting=nil; s.rotationCast=nil
    check(not optional(s,'nova'),'Finishing Nova does not flash between successive Frostbolts')
    s.targetHP=793; s.spellPower[5]=153; s.spellCrit[5]=4.779; s.talents.elementalPrecision=2
    check(math.abs(M.Estimate(s,'frostbolt').damage-401.933)<.001,'Fixture matches the recorded Frostbolt damage estimate')
    check(not optional(s,'nova'),'Recorded 793 health target does not invite an offensive root between casts')
    s.casting=true; s.rotationCast=true
    check(not optional(s,'nova'),'Starting the next Frostbolt preserves the recorded no-root advice')
    s.targetHP=M.Estimate(s,'frostbolt').damage*3
    check(optional(s,'nova'),'Durable target retains offensive Nova during a Frostbolt')
    s.casting=nil; s.rotationCast=nil
    check(optional(s,'nova'),'Durable target retains offensive Nova between Frostbolts')
    s.targetHP=100; s.playerHealth=50
    check(optional(s,'nova'),'Low health still allows defensive Nova on a nearly dead target')
    s.playerHealth=100; s.spellPower[5]=200
    s.casting=nil; s.rotationCast=nil; s.targetHP=1200; s.talents.shatter=0
    check(not optional(s,'nova'),'No Shatter means no extra offensive Nova priority')
    s.talents.shatter=5; s.targetBoss=true
    check(not optional(s,'nova'),'Bosses do not get the solo Shatter root recommendation')
    s.targetBoss=false; s.targetClose=false
    check(not optional(s,'nova'),'Nova requires a nearby attacker')
    s.targetClose=true; s.spells.nova.immune=true
    check(not optional(s,'nova'),'Observed root immunity blocks proactive Nova')
    s.spells.nova.immune=false; s.targetGUID='nova-plan'; s.time=10
    s.casting=true; s.rotationCast=true; s.castToken='cast:root-plan'; s.castEnd=12.5
    R.castPlan=nil
    local key=R:StabilizeRecommendation(s,'frostbolt','Main attack',false,false)
    check(key=='frostbolt' and R.castPlan.key=='frostbolt' and optional(s,'nova'),'Cast starts with damage plus independent Nova')
    s.frozen=true
    key=R:StabilizeRecommendation(s,'frostbolt','damage',false,false)
    check(key=='frostbolt' and R.lockStatus=='held' and not optional(s,'nova'),'A new freeze clears only Nova and leaves the damage highlight steady')
    R.castPlan=nil
    local old=R.snapshot
    R.snapshot=s; R.tracePrevious=nil; R:TraceRotation('talent-context',true)
    local fields=A.characterDB.rotationDiagnostics.entries[A.characterDB.rotationDiagnostics.count].delta.fields
    check(fields.talents.fields.shatter.value==5 and fields.talents.fields.iceShards.value==5,'Actual talent ranks persist in the combat trace')
    check(fields.spellPower.fields[5].value==200 and fields.state.fields.grouped.value==false,'School stats and solo context persist in the combat trace')
    R.snapshot=old
end

-- Shared consumables work without any Mage rotation implementation.
do
    local B=A.ConsumableBuffs
    local oldItem,oldContainer,oldBuild,oldMage=C_Item,C_Container,A.Supplies.Build,A.MageRotation
    local oldInfo=C_Spell.GetSpellInfo
    local active={}
    local rows={
        {itemId=1,family='wellfed',tracking=true,priority='Essentials',item={level=1,classes={'All'}}},
        {itemId=2,family='drink',tracking=true,item={level=1,classes={'All'}}},
        {itemId=3,family='elixir',category='Elixirs',tracking=true,item={level=1,classes={'Rogue'},detail='Buff for 1 hour.'}},
        {itemId=4,family='mage-elixir',category='Elixirs',tracking=true,item={level=1,classes={'Mage'},detail='Buff for 1 hour.'}},
        {itemId=5,family='scroll-intellect',category='Scrolls',tracking=true,item={level=1,classes={'All'}}},
    }
    local contextClass
    A.Supplies.Build=function(context) contextClass=context.characterClass; return rows end
    C_Item={GetItemCount=function(_,bank) check(not bank,'Shared consumables use carried stock'); return 1 end,
        GetItemSpell=function(id) return 'Use'..id,100+id end,
        GetItemInfo=function(id) return 'Item'..id,nil,nil,nil,nil,nil,nil,nil,nil,123 end,
        IsUsableItem=function() return true end}
    C_Container={GetItemCooldown=function() return 0,0,1 end}
    C_Spell.GetSpellInfo=function(id)
        if id==19705 then return {name='Well Fed'} end
        if id==1459 then return {name='Arcane Intellect'} end
        return oldInfo(id)
    end
    A.MageRotation=nil
    local cache={}
    local snapshot={class='ROGUE',level=41,time=100,playerHealth=100,powerPercent=20,buffs={},spells={}}
    local function choices() return B:Recommend(snapshot,function() return active,{} end,cache) end
    local function has(list,id) for _,a in ipairs(list) do if a.id==id then return a end end end
    for class,name in pairs(B.classes) do
        snapshot.class=class; local list=choices()
        check(contextClass==name,'Shared supply context uses '..name)
        check(has(list,1)~=nil,name..' can receive buff-food advice without Mage code')
        check((has(list,2)~=nil)==not not B.manaClasses[class],name..' water advice follows its resource type')
        check((has(list,3)~=nil)==(class=='ROGUE'),name..' respects consumable class restrictions')
        check((has(list,4)~=nil)==(class=='MAGE'),name..' cannot receive another class exclusive elixir')
    end
    local oldPower,oldMax=UnitPower,UnitPowerMax
    snapshot.class='DRUID'; snapshot.powerType=3
    UnitPower=function() return 950 end; UnitPowerMax=function() return 1000 end
    check(not has(choices(),2),'A shifted Druid does not drink because its energy is low')
    UnitPower=function() return 100 end
    check(has(choices(),2)~=nil,'A shifted Druid checks its actual mana for recovery')
    UnitPower,UnitPowerMax=oldPower,oldMax; snapshot.powerType=nil
    snapshot.class='ROGUE'; active={['Well Fed']=301,Use3=301}
    check(#choices()==0,'Shared healthy food and elixir buffs do not warn')
    active={['Well Fed']=300,Use3=300}
    local list=choices()
    check(has(list,1).buffColor=='refresh' and has(list,3).buffColor=='refresh','Shared food/elixir warning glows are blue at five minutes')
    active={}; list=choices()
    check(has(list,1).buffColor=='primary' and has(list,3).buffColor=='primary','Shared missing buffs remain gold')
    snapshot.class='PRIEST'; active={['Arcane Intellect']=1000}
    check(not has(choices(),5),'An external class buff blocks redundant Intellect scroll advice')
    snapshot.combat=true; check(#choices()==0,'Shared preparation does not suggest consuming food in combat')
    snapshot.combat=false; snapshot.dead=true; check(#choices()==0,'Shared preparation stops while dead')
    snapshot.dead=false; snapshot.taxi=true; check(#choices()==0,'Shared preparation stops on a taxi')
    snapshot.taxi=false; snapshot.channelKey='anything'; check(#choices()==0,'Shared preparation does not interrupt channels')
    C_Item,C_Container,A.Supplies.Build,A.MageRotation=oldItem,oldContainer,oldBuild,oldMage
    C_Spell.GetSpellInfo=oldInfo
end

-- Non-Mage preparation reaches the normal action-bar highlight path.
do
    local oldSnapshot,oldRecommend,oldAction,oldView=R.Snapshot,A.ConsumableBuffs.Recommend,GetActionInfo,R.RefreshView
    local oldClass=MOCK.class; MOCK.class='ROGUE'
    R.Snapshot=function() return {class='ROGUE',level=41,time=now,combat=false,buffs={},spells={}} end
    A.ConsumableBuffs.Recommend=function() return {{id=1,item=true,name='Buff Food',buffColor='primary'}} end
    GetActionInfo=function() return 'item',1 end
    R.RefreshView=function() end; R.castPlan=nil; R:Update()
    check(R.current.item and R.current.id==1 and R.highlightCount>0,'A Rogue receives shared consumable item highlights')
    check(not R.traceDecision.key,'Shared Rogue support never creates a combat spell recommendation')
    R.Snapshot,A.ConsumableBuffs.Recommend,GetActionInfo,R.RefreshView=oldSnapshot,oldRecommend,oldAction,oldView
    MOCK.class=oldClass; R.dirty=true; R:Update()
end

-- All nine class boundaries resolve through one global coordinator.
do
    local total=0
    for token,name in pairs(A.ConsumableBuffs.classes) do
        local module=R:Class(token); total=total+1
        check(module and module.name==name and type(module.definitions)=='table','Registered '..name..' class file')
        check((module.combat==true)==(token=='MAGE'),'Only the approved Mage combat profile is active')
        local s=state({'frostbolt'}); s.class=token
        if token~='MAGE' then check(R.Decide(s)==nil,name..' cannot fall through into Mage combat choices') end
    end
    check(total==9,'Nine Classic classes share the global dispatcher')
end
-- Moving changes telemetry, never the recommendation or optional-action list.
do
    local profiles={}
    local s=state({'frostbolt','evocation'}); s.combat=false; s.powerPercent=10; profiles[#profiles+1]=s
    s=state({'frostbolt','evocation'}); s.powerPercent=5; s.timeToDie=30; s.targetCombat=true; profiles[#profiles+1]=s
    s=state({'fireball','pyroblast'}); s.combat=false; s.targetCombat=false; s.targetDistance=30; profiles[#profiles+1]=s
    s=state({'frostbolt','blizzard','flamestrike'}); s.cluster=4; s.safeCluster=true; profiles[#profiles+1]=s
    s=state({'frostbolt','shoot'}); s.targetHP=40; s.wandDamage=50; s.wandSpeed=1.5; profiles[#profiles+1]=s
    s=state({'cone'}); s.targetClose=true; s.facingTarget=true; profiles[#profiles+1]=s
    s=state({'fireball','presence'}); s.timeToDie=30; profiles[#profiles+1]=s
    for i,profile in ipairs(profiles) do
        profile.moving=false; local still=R.Decide(profile)
        local optionalStill=M.Optional(profile)
        profile.moving=true; local moving=R.Decide(profile)
        local optionalMoving=M.Optional(profile)
        check(still==moving,'Movement does not change profile '..i..' primary')
        check(#optionalStill==#optionalMoving,'Movement does not clear profile '..i..' optional choices')
        for n,v in ipairs(optionalStill) do check(v.key==optionalMoving[n].key,'Moving preserves the same optional action') end
    end
    s=state({'frostbolt','blizzard'}); s.cluster=4; s.safeCluster=true; s.targetGUID='movement-ground'; s.time=10
    s.castToken='cast:ground'; s.castEnd=12.5; s.rotationCast=true
    R.castPlan=nil
    local key=R:StabilizeRecommendation(s,'blizzard','Area damage',false,false)
    s.moving=true
    check(R:StabilizeRecommendation(s,'frostbolt','other',false,false)==key and R.lockStatus=='held','Movement cannot suppress a committed ground-spell plan')
    R.castPlan=nil
end

-- Recorded interruption arrives while UnitCastingInfo still reports the old cast.
do
    local s=state({'frostbolt','nova','counterspell'})
    s.time=10; s.targetGUID='interrupted'; s.castToken='cast:cancelled'; s.castEnd=12.5; s.rotationCast=true
    s.targetClose=true; s.attackingPlayer=true
    R.castPlan=nil
    R:StabilizeRecommendation(s,'nova','setup',false,false)
    local update=R.Update; R.Update=function() end
    R.events.scripts.OnEvent(R.events,'UNIT_SPELLCAST_INTERRUPTED','player','different-cast',8408)
    check(R.castPlan and R.castPlan.key=='nova','An unrelated interrupted token cannot clear the active plan')
    check(R:StabilizeRecommendation(s,'frostbolt','damage',false,false)=='nova','Active cast keeps its plan after unrelated interruption')
    R.events.scripts.OnEvent(R.events,'UNIT_SPELLCAST_INTERRUPTED','player','cancelled',8408)
    check(not R.castPlan,'Matching interruption cancels the plan')
    check(not R:StabilizeRecommendation(s,'frostbolt','damage',false,false) and not R.castPlan and R.lockStatus=='interrupted-cast','Stale interrupted cast cannot create a late Frostbolt plan')
    check(R:StabilizeRecommendation(s,'counterspell','interrupt',false,true)=='counterspell','Urgent interrupt remains available during stale snapshot')
    s.castToken=nil; s.castEnd=nil
    check(R:StabilizeRecommendation(s,'frostbolt','damage',false,false)=='frostbolt' and not R.interruptedCastToken,'Cleared cast resumes normal decisions')
    s.castToken='cast:new'; s.castEnd=13
    check(R:StabilizeRecommendation(s,'frostbolt','damage',false,false)=='frostbolt' and R.castPlan,'New cast can create its own plan')
    R.Update=update; R.castPlan=nil; R.interruptedCastToken=nil
end

-- Former short-lifetime scorer failure cannot change the stable main attack.
do
    local s=state({'frostbolt','scorch','missiles'},41)
    s.targetHP=438; s.timeToDie=2.478; s.spellPower={[5]=153,[7]=72}; s.spellCrit={[5]=5.033,[7]=5.033,[3]=5.033}
    s.spells.frostbolt.castTime=2.5; s.talents.piercingIce=3; s.talents.iceShards=5
    local score=M.Estimate(s,'missiles').score
    decide(s,'frostbolt','Short lifetime does not switch Frostbolt to Missiles or Scorch')
    s.timeToDie=nil
    check(M.Estimate(s,'missiles').score==score,'Death forecast has no effect on damage comparisons')
    decide(s,'frostbolt','Removing the lifetime forecast preserves the same recommendation')
end

-- Stable character profiles ignore target fluctuations and coexist with utility.
do
    local s=state({'frostbolt','fireball','scorch','missiles','fireblast','counterspell','nova'},41)
    s.talents={improvedFrostbolt=5,iceShards=5,shatter=5,piercingIce=3,frostChanneling=3}
    s.spellPower={[5]=153,[3]=72,[7]=72}; s.spellCrit={[5]=5,[3]=5,[7]=5}
    local owner={}; local chosen=M.Profile(owner,s); s.damageProfile=chosen
    check(chosen.main=='frostbolt','Recorded Frost build selects Frostbolt as its stable main attack')
    for _,lifetime in ipairs({.1,1,2.478,60}) do
        s.timeToDie=lifetime; s.frozen=lifetime<3; s.frozenRemaining=5
        s.scorchStacks=5; s.winterChillStacks=5; s.buffs.arcanepower=10
        s.attackingPlayer=true; s.powerPercent=20; s.moving=true
        check(M.Profile(owner,s)==chosen and R.Decide(s)=='frostbolt','Target and resource fluctuations preserve the main attack')
    end
    s.spells.frostbolt.immune=true
    check(R.Decide(s)=='fireball','Observed immunity follows the fixed fallback order')
    s.spells.frostbolt.immune=false; s.spells.frostbolt.usable=false; s.spells.fireball.usable=false
    check(R.Decide(s)=='scorch','Insufficient mana can reach the cheaper fixed fallback')
    s.spells.frostbolt.usable=true; s.spells.fireball.usable=true
    s.interrupt=true; s.grouped=false; s.frozen=false; s.targetClose=true; s.targetHP=3000; s.powerPercent=100
    check(R.Decide(s)=='frostbolt' and optional(s,'counterspell') and optional(s,'nova'),'Main attack, interrupt and Shatter root coexist')
    s.targetHP=10; s.spells.fireblast.cooldownRemaining=0
    check(R.Decide(s)=='fireblast','A conservative instant finisher overrides the filler')
    s.targetHP=M.Estimate(s,'fireblast').minimumDamage+1
    check(R.Decide(s)=='frostbolt','Expected critical damage alone does not justify a finisher')
    s.spellPower[3]=2000
    check(M.Profile(owner,s)==chosen,'A live profile remains fixed until character refresh')
    owner.damageProfile=nil
    check(M.Profile(owner,s).main=='fireball','Rebuilding the profile incorporates new school-specific gear')
    local oldProfile=R.damageProfile; R.damageProfile={main='sentinel'}
    R:RefreshSpells(); check(not R.damageProfile,'Live spell/talent/equipment refresh invalidates the profile')
    R.damageProfile=oldProfile
end

-- The live renderer keeps utility highlights alongside a cast-start primary.
do
    local oldSnapshot,oldAction,oldView=R.Snapshot,GetActionInfo,R.RefreshView
    local s=state({'frostbolt','counterspell','nova'},41)
    s.talents={shatter=5}; s.time=now; s.targetGUID='independent-utility'; s.attackingPlayer=true
    s.grouped=false; s.targetClose=true; s.targetHP=5000; s.interrupt=true
    s.castToken='cast:independent'; s.castEnd=now+2.5; s.rotationCast=true; s.casting=true
    R.Snapshot=function() return s end; R.RefreshView=function() end
    GetActionInfo=function(slot) return 'spell',slot==1 and s.spells.frostbolt.id or slot==2 and s.spells.counterspell.id or s.spells.nova.id end
    R.castPlan=nil; R:Update()
    check(glow:IsShown() and glow.style=='primary' and R.highlights[other].style=='optional' and R.highlights[lower].style=='optional','Live renderer shows gold damage and red interrupt/root together')
    local starts=glow.ProcStartAnim.plays
    s.frozen=true; s.interrupt=false; R:Update()
    check(glow:IsShown() and not R.highlights[other]:IsShown() and not R.highlights[lower]:IsShown(),'Ending utility conditions clears only their highlights')
    check(glow.ProcStartAnim.plays==starts and R.lockStatus=='held','Utility changes do not restart or replace the primary glow')
    R.Snapshot,R.RefreshView,GetActionInfo=oldSnapshot,oldView,oldAction; R.castPlan=nil
end

print('PASS: '..count..' Mage rotation, live adapter, UI and highlight regression checks.')
