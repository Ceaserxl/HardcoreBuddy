local A,H=TestAddon,TestAddon.RotationHelper
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
MOCK.class="MAGE"
local X={}
local function reset()
    X={time=100,power=1000,maxPower=1000,health=1000,targetHealth=1000,targetMax=1000,
        target=true,targetGUID="Creature-test",combat=true,targetCombat=true,range=true,
        learned={[116]=true,[133]=true,[2136]=true,[1459]=true,[168]=true},costs={[116]=50,[133]=60,[2136]=40},
        cooldowns={},auras={player={},target={}},inventory={},talents={},macro=116}
    H.state={}; H.recent={}; H.immunities={}; H.supplyItems=nil
end
reset()
GetTime=function() return X.time end
GetSpellInfo=function(id) return "Spell"..id,"Rank",135846,3000 end
C_Spell=nil
IsPlayerSpell=function(id) return X.learned[id] or false end
IsSpellKnown=IsPlayerSpell
GetSpellPowerCost=function(id) return {{type=0,cost=X.costs[id] or 0}} end
GetSpellCooldown=function(id)
    local cd=X.cooldowns[id] or (X.gcd and {X.time,1.5}) or {0,0}
    return cd[1],cd[2],cd[3]==nil and 1 or cd[3]
end
GetManaRegen=function() return 20,X.regen or 0 end
UnitPower=function() return X.power end
UnitPowerMax=function() return X.maxPower end
UnitPowerType=function() return 0 end
UnitHealth=function(u) return u=="player" and X.health or X.targetHealth end
UnitHealthMax=function(u) return u=="player" and 1000 or X.targetMax end
UnitGUID=function(u) return u=="player" and "Player-test" or X.target and X.targetGUID end
UnitCanAttack=function() return X.target end
UnitIsDeadOrGhost=function(u) return u=="player" and X.dead or u=="target" and X.targetHealth<=0 or false end
UnitOnTaxi=function() return X.taxi end
UnitAffectingCombat=function(u) if u=="player" then return X.combat else return X.targetCombat end end
IsInGroup=function() return X.grouped end
UnitIsPlayer=function() return X.pvp end
UnitIsTapDenied=function() return X.tapped end
UnitClassification=function() return X.elite and "elite" or "normal" end
UnitIsUnit=function() return X.attacked end
IsSpellInRange=function() if X.range==nil then return nil else return X.range and 1 or 0 end end
CheckInteractDistance=function() return X.near end
UnitCastingInfo=function(u)
    local cast=u=="player" and X.cast or u=="target" and X.targetCast
    if cast then return "Spell"..cast.id,nil,nil,cast.start*1000,cast.finish*1000,false,cast.start,cast.uninterruptible,cast.id end
end
UnitChannelInfo=function() end
C_UnitAuras={GetAuraDataByIndex=function(u,i,filter)
    if filter=="HARMFUL" and u=="player" then return X.cursed and i==1 and {spellId=999,dispelName="Curse"} or nil end
    return X.auras[u] and X.auras[u][i]
end}
C_NamePlate=nil
GetItemCount=function(id) return X.inventory[id] or 0 end
C_Item.GetItemCount=GetItemCount
GetItemCooldown=function() return 0,0,1 end
GetInventoryItemLink=function() return X.wand and "item:11287" end
GetItemInfoInstant=function() return 11287,nil,nil,"INVTYPE_RANGEDRIGHT" end
A.TalentAdvisor.ReadCurrent=function() return {ranks=X.talents} end
A.Inventory.Read=function() return {available=true,counts=X.inventory} end
local function rebuild() H:Rebuild() end
local function evaluate()
    local c=H:Snapshot(); local p; p,H.state=H.Select(c,H.module,H.state)
    return p,c
end
local function find(p,key) for _,v in ipairs(p) do if v.key==key then return v end end end
local function main(p) for _,v in ipairs(p) do if v.category=="main" then return v.key end end end
rebuild()
check(not H:Enabled(),"Default off: previous prototype does not silently enable")
local p,c=evaluate()
check(main(p)=="frostbolt","Solo safety favors learned Frostbolt")
X.learned[116]=nil; rebuild(); p=evaluate()
check(main(p)=="fireball","Level 1 / untrained Frostbolt uses Fireball")
X.learned[116]=true; X.learned[205]=true; rebuild(); p=evaluate()
check(p[1].id==205,"Highest LEARNED rank, not character level")
X.learned[205]=nil; X.learned[7322]=nil; rebuild()

X.gcd=true; p=evaluate(); check(main(p)=="frostbolt","GCD must not hide the next action")
X.gcd=false; X.cooldowns[116]={100,2}; p=evaluate(); check(main(p)=="frostbolt","Short cooldown does not gate Main")
X.cooldowns[116]={100,60}; p=evaluate(); check(main(p)=="frostbolt","Long cooldown does not replace Main with a fallback")
X.cooldowns[116]={100,60,0}; p=evaluate(); check(main(p)=="frostbolt","Disabled cooldown state does not gate Main")
X.cooldowns[116]=nil
X.power=30; X.regen=10; p,c=evaluate(); check(main(p)=="frostbolt" and c.futurePower==50,"Forecast confirmed casting regen")
X.regen=0; p=evaluate(); check(main(p)==nil,"Cannot spend unknown future mana")
X.power=80; X.cast={id=116,start=100,finish=103}; p,c=evaluate()
check(c.futurePower==30 and main(p)==nil,"Reserve mana committed to the current cast")
X.cast=nil; H.state={}; X.power=1000

X.cast={id=116,start=100,finish=103}; p=evaluate()
check(main(p)=="frostbolt","Choose next attack at cast start")
X.time=102.9; X.targetHealth=140; p=evaluate()
check(main(p)=="frostbolt","Late finisher must not replace committed next attack")
X.cast=nil; X.time=103.05; p=evaluate(); check(main(p)=="frostbolt","Keep plan through cast handoff")
X.cast={id=116,start=103.1,finish=106.1}; X.time=103.1; p=evaluate()
check(main(p)=="fireblast","Reconsider at next cast START")
X.range=false; p=evaluate(); check(not main(p),"Out of range hides plan; does not show a substitute")
X.range=true; p=evaluate(); check(main(p)=="fireblast","Returning in range restores committed plan")
X.targetGUID="Creature-next"; X.targetHealth=1000; p=evaluate(); check(main(p)=="frostbolt","New target clears previous plan")
X.targetHealth=0; p=evaluate(); check(not main(p),"Dead targets clear primary")
reset(); rebuild()

X.grouped=true; X.targetCombat=false; p=evaluate(); check(not main(p),"No new pulls into unengaged group targets")
X.targetCombat=true; p=evaluate(); check(main(p)=="frostbolt","Engaged group target is eligible")
X.auras.target={{spellId=118,expirationTime=150}}; p=evaluate(); check(not main(p),"Do not break Polymorph")
X.auras.target={{spellId=122,expirationTime=110}}; p=evaluate(); check(main(p)=="frostbolt","Rooted targets remain valid for ranged damage")
X.auras.target={}; X.range=nil; p=evaluate(); check(not main(p),"Unknown range is not in range")
X.range=true; X.pvp=true; p=evaluate(); check(not main(p),"PvE policy does not advise player targets")
X.pvp=false; X.tapped=true; p=evaluate(); check(not main(p),"Do not attack other players' tapped targets")
reset(); X.learned[122]=true; X.learned[2139]=true; X.near=true; X.attacked=true; rebuild()
X.targetCast={id=100,start=99,finish=102}; p=evaluate()
check(main(p)=="frostbolt" and find(p,"nova") and find(p,"counterspell"),"Defensives coexist with stable main")
X.targetCast.uninterruptible=true; p=evaluate(); check(not find(p,"counterspell"),"Respect uninterruptible casts")
X.auras.target={{spellId=122,expirationTime=110}}; p=evaluate(); check(not find(p,"nova"),"Do not repeat Nova into a root")
X.auras.target={}; H.immunities[X.targetGUID]={nova=110}; p=evaluate()
check(main(p)=="frostbolt" and not find(p,"nova"),"Root immunity does not imply Frost damage immunity")
H.immunities[X.targetGUID]={frostbolt=110}; p=evaluate(); check(main(p)=="fireball","Observed Frostbolt immunity uses Fire fallback")
X.time=111; p=evaluate(); check(main(p)=="frostbolt","Immunity evidence expires")
reset(); X.talents={improvedFireball=5,ignite=5}; rebuild()
p=evaluate(); check(main(p)=="frostbolt","Fire solo establishes a slow first")
X.cast={id=116,start=100,finish=103}; p=evaluate(); check(main(p)=="fireball","Fire talents guide NEXT cast after slow opener")
X.cast=nil; H.state={}; X.grouped=true; p=evaluate(); check(main(p)=="fireball","Fire talents guide engaged group damage")
X.learned[2948]=true; X.talents.improvedScorch=3; X.elite=true; rebuild(); p=evaluate()
check(main(p)=="scorch","Improved Scorch only on durable targets with the talent")
X.auras.target={{spellId=22959,applications=4,expirationTime=125}}; X.cast={id=2948,start=100,finish=101.5}; H.state={}; p=evaluate()
check(main(p)=="fireball","Account for pending fifth Scorch stack")
reset(); X.combat=false; X.target=false; rebuild(); p=evaluate()
check(find(p,"intellect") and find(p,"frostarmor"),"Preparation can show multiple buffs")
X.auras.player={{spellId=1459,expirationTime=401},{spellId=168,expirationTime=401}}; p=evaluate()
check(not find(p,"intellect") and not find(p,"frostarmor"),"Buffs above five minutes are not refreshed")
X.time=101; p=evaluate(); check(find(p,"intellect") and find(p,"frostarmor"),"Five-minute refresh threshold")
X.auras.player={{spellId=11390,expirationTime=400}}; p=evaluate(); check(not find(p,"intellect"),"Stronger intellect elixir suppresses weak self buff")
X.inventory={[159]=5,[117]=5}; H.supplyItems=nil; X.power=100; X.health=700; p=evaluate()
check(find(p,"water") and find(p,"food"),"Shared recovery suggests carried food and drink")
X.auras.player={{spellId=430,name="Spell430",expirationTime=130}}; p=evaluate()
check(#p==0,"Do not interrupt drinking with preparation or another drink")
X.auras.player={}; X.combat=true; p=evaluate(); check(not find(p,"water") and not find(p,"food"),"Recovery items are out-of-combat only")
X.dead=true; p=evaluate(); check(#p==0,"Death clears all advice")
X.dead=false; X.taxi=true; p=evaluate(); check(#p==0,"Flight clears all advice")

-- Only simulate the native animation object; production uses Blizzard's XML.
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local f=create(kind,name,parent,template)
    function f:GetSize() return self:GetWidth(),self:GetHeight() end
    if template=="ActionButtonSpellAlertTemplate" then
        local anim={starts=0,playing=false}
        function anim:Play() self.starts=self.starts+1; self.playing=true end
        function anim:Stop() self.playing=false end
        function anim:IsPlaying() return self.playing end
        f.ProcLoop=anim; f.ProcStartFlipbook=f:CreateTexture(); f.ProcLoopFlipbook=f:CreateTexture()
    end
    return f
end
reset(); rebuild()
InCombatLockdown=function() return X.lockdown end
GetActionInfo=function(slot) if slot==1 then return "spell",116 elseif slot==2 then return "macro",1 end end
GetMacroSpell=function() return X.macro end
local direct=CreateFrame("Button","ActionButton1",UIParent); direct.action=1; direct:SetSize(36,36)
local macro=CreateFrame("Button","ActionButton2",UIParent); macro.action=2; macro:SetSize(36,36)
direct.SpellActivationAlert={native=true}
H.Glow:Discover()
local pick={{key="frostbolt",id=116,kind="spell",category="main"}}
H.Glow:Apply(pick)
local dg,mg=H.Glow.seen[direct],H.Glow.seen[macro]
check(dg.glow:IsShown() and mg.glow:IsShown(),"Direct spell and resolved macro both glow")
for i=1,50 do H.Glow:Apply(pick) end
check(dg.glow.ProcLoop.starts==1 and mg.glow.ProcLoop.starts==1,"Stable recommendation does not restart animation")
check(direct.SpellActivationAlert.native,"Native proc ownership is untouched")
for _,category in ipairs({"main","defensive","offensive","preparation"}) do
    pick[1].category=category; H.Glow:Apply(pick)
    check(dg.boost:IsShown() and dg.boost.ProcLoop:IsPlaying(),category.." has a running intensity pass")
    check(dg.boost:GetAlpha()==0.65 and dg.boost.ProcLoopFlipbook.blendMode=="ADD",category.." uses added light")
    check(dg.glow:GetWidth()==dg.boost:GetWidth() and dg.glow:GetHeight()==dg.boost:GetHeight(),category.." retains identical glow bounds")
    local color=dg.boost.ProcLoopFlipbook.vertexColor
    check(color[1]==H.colors[category][1] and color[2]==H.colors[category][2] and color[3]==H.colors[category][3],category.." keeps its own color")
end
pick[1].category="main"; H.Glow:Apply(pick)
check(dg.glow.ProcLoop.starts==1 and dg.boost.ProcLoop.starts==1,"Both intensity passes stay continuous through repeated/category updates")
X.macro=133; H.Glow:Apply(pick); check(not mg.glow:IsShown(),"Modifier macro changing spells clears stale glow")
check(not mg.boost:IsShown() and not mg.boost.ProcLoop:IsPlaying(),"Modifier changes also clear the intensity pass")
direct:Hide(); check(not dg.glow:IsShown(),"Hidden bar cannot leave an orphan glow")
check(not dg.boost:IsShown() and not dg.boost.ProcLoop:IsPlaying(),"Hidden bar clears both passes")
direct:Show(); H.Glow:Apply(pick); check(dg.glow:IsShown(),"Shown bar regains recommendation")
check(dg.boost:IsShown(),"Shown bar regains intensity pass")
local newcomer=CreateFrame("Button",nil,UIParent); X.lockdown=true; H.Glow:Register(newcomer)
check(not H.Glow.seen[newcomer],"Do not create children on protected buttons in combat")
X.lockdown=false; H.Glow:Register(newcomer); check(H.Glow.seen[newcomer],"Can register additional action bars out of combat")
H:SetEnabled(true); check(H.frame.scripts.OnUpdate,"Enabled helper updates")
X.cast={id=116,start=100,finish=103}; H.state={}; H:Tick()
X.targetHealth=140; H.frame.scripts.OnEvent(H.frame,"UNIT_SPELLCAST_FAILED","player","failed",2136)
check(main(H.picks)=="frostbolt","Failed extra key press does not replace an ongoing cast's plan")
H.frame.scripts.OnEvent(H.frame,"PLAYER_LEAVING_WORLD")
check(not H:Enabled() and not H.frame.scripts.OnUpdate,"World transition suspends updates")
H.frame.scripts.OnEvent(H.frame,"UNIT_SPELLCAST_SUCCEEDED","player","stale",116)
check(#H.picks==0,"Late world events cannot revive cleared glows")
H.frame.scripts.OnEvent(H.frame,"PLAYER_ENTERING_WORLD")
check(H:Enabled() and H.frame.scripts.OnUpdate,"Entering world restores saved enabled preference")
H:SetEnabled(false); check(not H.frame.scripts.OnUpdate and not dg.glow:IsShown(),"Disable stops updates and clears only our glows")
check(not dg.boost:IsShown() and not dg.boost.ProcLoop:IsPlaying(),"Disable also clears intensity pass")

-- Missing spells: local notices only, exact ranks, all lanes, and paged/macros.
local savedPrint,savedActions,savedMacro=A.Print,GetActionInfo,GetMacroSpell
local notices,slots={},{}
A.Print=function(_,message) notices[#notices+1]=message end
GetActionInfo=function(slot) local a=slots[slot]; if a then return unpack(a) end end
GetMacroSpell=function(id) return id==77 and 116 end
H.Glow.warnedMissing={}
H.Glow:NotifyMissing(pick)
check(#notices==1 and notices[1]:find("Spell116",1,true) and notices[1]:find("missing from your action bars",1,true),"Missing spell is named in local chat")
for i=1,100 do H.Glow:NotifyMissing(pick) end
H.Glow:NotifyMissing({}); H.Glow:NotifyMissing(pick)
check(#notices==1,"Missing spell warns once across repeated ticks and recommendation changes")
H.Glow.warnedMissing={}; notices={}; slots[120]={"spell",116}
H.Glow:NotifyMissing(pick); check(#notices==0,"Unregistered hidden/paged spell slot is still present")
slots[120]={"macro",77}; H.Glow:NotifyMissing(pick)
check(#notices==0,"Legacy resolved spell macro prevents false missing notice")
slots[120]={"macro",116,"spell"}; H.Glow:NotifyMissing(pick)
check(#notices==0,"Modern resolved macro prevents false missing notice")
slots[120]={"spell",205}; H.Glow:NotifyMissing(pick)
check(#notices==1,"A different spell rank does not falsely match the recommended rank")
H.Glow.warnedMissing={}; notices={}; slots={}
for i,category in ipairs({"main","defensive","offensive","preparation"}) do
    H.Glow:NotifyMissing({{id=10000+i,kind="spell",category=category}})
    check(#notices==i,category.." warns about a missing recommended spell")
end
H.Glow:NotifyMissing({{id=159,kind="item",category="preparation"}})
check(#notices==4,"Item advice does not generate a missing-spell warning")
reset(); rebuild(); H.Glow.warnedMissing={}; notices={}
H:SetEnabled(true)
check(#notices==1 and notices[1]:find("Spell116",1,true),"Enabled runtime sends missing-spell notices")
H:Tick(); H:SetEnabled(false); H:Tick()
check(#notices==1,"Runtime repeats and disabling do not spam notices")
A.Print,GetActionInfo,GetMacroSpell=savedPrint,savedActions,savedMacro
H.Glow.warnedMissing={}
reset(); X.learned[122]=true; X.learned[865]=true
local has=H.Glow.HasSpell
H.Glow.HasSpell=function(_,id) return id==865 end
rebuild(); check(H.definitions.nova.id==865,"Nova uses a learned rank that is on the bar")
H.Glow.HasSpell=function(_,id) return id==122 or id==865 end
rebuild(); check(H.definitions.nova.id==122,"Prefer low-cost control rank when actually on the bar")
H.Glow.HasSpell=has
reset(); X.combat=false; X.target=false; X.learned[11958]=true; X.auras.player={{spellId=11958,expirationTime=105}}; rebuild()
p=evaluate(); check(#p==0,"An active Ice Block pauses suggestions until usable again")
reset(); X.grouped=true; X.talents={criticalMass=3,improvedScorch=3,improvedFrostbolt=5}; rebuild(); p=evaluate()
check(main(p)=="fireball","Specialization considers the entire tree, not only selected damage talents")
reset(); X.learned[5019]=true; X.wand=true; X.targetHealth=100; X.elite=true; rebuild(); p=evaluate()
check(main(p)=="frostbolt","Ten percent of an elite is not assumed to be wand/Fire Blast finishing range")
local legacyInfo,legacyCooldown=GetSpellInfo,GetSpellCooldown
C_Spell={GetSpellInfo=function(id) local name,_,icon,cast=legacyInfo(id); return {name=name,iconID=icon,castTime=cast} end,
    GetSpellCooldown=function(id) local start,duration,enabled=legacyCooldown(id); return {startTime=start,duration=duration,isEnabled=enabled==1} end,
    GetSpellPowerCost=GetSpellPowerCost,IsSpellInRange=function() return X.range end}
X.gcd=true; p=evaluate(); check(main(p)=="frostbolt","Modern C_Spell API path respects GCD and boolean range")
X.range=nil; p=evaluate(); check(not main(p),"Modern unknown range is rejected")
C_Spell=nil; X.range=true; X.gcd=false
-- The shared change applies to every lane and to item actions, not just Main.
local gateContext=H:Snapshot()
for _,category in ipairs({"main","defensive","offensive","preparation"}) do
    for _,kind in ipairs({"spell","item"}) do
        gateContext.spells.probe={id=999,kind=kind,known=true,cost=0,cooldown=math.huge,range=true}
        local picks=H.Select(gateContext,{rules={{spell="probe",category=category,when=function() return "Needed" end}}},{})
        check(find(picks,"probe"),category.." "..kind.." highlight ignores cooldown duration")
    end
end
local action=GetActionInfo
GetActionInfo=function() return "macro",116,"spell" end
local kind,id=H.Glow.Action(macro); check(kind=="spell" and id==116,"Resolved modern macro actions do not interpret a spell ID as a macro index")
GetActionInfo=action
reset(); X.health=150; X.learned[11958]=true; rebuild()
local guid,attack,combatAPI,same=UnitGUID,UnitCanAttack,UnitAffectingCombat,UnitIsUnit
UnitGUID=function(u) if u=="nameplate1" or u=="nameplate2" then return "Creature-add" end; return guid(u) end
UnitCanAttack=function(_,u) return u=="nameplate1" or u=="nameplate2" or X.target end
UnitAffectingCombat=function(u) return u=="nameplate1" or u=="nameplate2" or combatAPI(u) end
UnitIsUnit=function(u) return u=="nameplate1target" or u=="nameplate2target" end
C_NamePlate={GetNamePlates=function() return {{namePlateUnitToken="nameplate1"},{namePlateUnitToken="nameplate2"}} end}
p,c=evaluate()
check(c.attacked and not c.targetAttacking and c.attackers==1 and c.enemiesObserved==2,"Observed attackers include adds and deduplicate GUIDs")
check(find(p,"iceblock"),"Emergency advice can respond to an add while the selected target attacks someone else")
UnitGUID,UnitCanAttack,UnitAffectingCombat,UnitIsUnit=guid,attack,combatAPI,same; C_NamePlate=nil
X.auras.target={{spellId=6215,expirationTime=130}}; p=evaluate(); check(not main(p),"Shared CC protection includes another class's Fear")
local modernAuras=C_UnitAuras; C_UnitAuras=nil
UnitAura=function(u,i,filter)
    local aura=modernAuras.GetAuraDataByIndex(u,i,filter)
    if aura then return aura.name or "Aura",nil,aura.applications,aura.dispelName,30,aura.expirationTime,"player",nil,nil,aura.spellId end
end
p=evaluate(); check(not main(p),"Legacy UnitAura preserves control detection")
C_UnitAuras=modernAuras
MOCK.class="ROGUE"; H:Rebuild(); check(not H.module,"Unsupported classes have no pretend rotation")
print("PASS: "..checks.." rotation scenario, cast-commitment, macro, lifecycle and native-glow checks")
