-- Fifty additional safety, resource, cast and action-bar cases. Together with
-- the cooldown suite these exercise 100 distinct scenarios without runtime edits.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local frost=F.build(3,40)
local function record(name,expected,pass,picks)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(picks)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function scenario(name,options,main,includes,excludes,setup)
    local x=F.reset(options)
    if setup then setup(x) end
    local picks=F.evaluate()
    local pass=F.main(picks)==(main or nil)
    for _,key in ipairs(includes or {}) do pass=pass and F.find(picks,key)~=nil end
    for _,key in ipairs(excludes or {}) do pass=pass and F.find(picks,key)==nil end
    record(name,"Main "..(main or "none").."; include "..table.concat(includes or {},", ").."; exclude "..table.concat(excludes or {},", "),pass,picks)
end
local function paused(name,options)
    F.reset(options); local picks=F.evaluate()
    record(name,"No highlights",#picks==0,picks)
end

-- 1-20: targeting, incapacitation, range, crowd control and immunity evidence.
scenario("Friendly unit is not an attack target",{friendly=true},false)
scenario("Player target is outside PvE advice",{pvp=true},false)
scenario("Another player's tagged target",{tapped=true},false)
scenario("Dead enemy target",{targetHealth=0},false)
scenario("Combat without a target",{target=false},false)
paused("Dead character clears every category",{dead=true,talents=frost,health=0,attacked=true})
paused("Taxi clears every category",{taxi=true,talents=frost})
paused("Active Ice Block pauses every category",{playerAuras={{spellId=11958,expirationTime=110}},talents=frost})
scenario("Unengaged party target avoids a pull",{grouped=true,targetCombat=false},false)
scenario("Engaged party target permits an attack",{grouped=true,targetCombat=true},"frostbolt")
scenario("Danger suppresses optional Arcane Power",{level=60,talents=F.build(1,60),grouped=true,classification="elite",attacked=true},"frostbolt",nil,{"arcanePower"})
scenario("Unknown spell range is not assumed safe",{unknownRange=true},false)
scenario("Enemy outside every learned spell range",{distance=50},false)
scenario("Polymorph blocks damage",{targetAuras={{spellId=118,expirationTime=120}}},false)
scenario("Another class's Fear blocks damage",{targetAuras={{spellId=6215,expirationTime=120}}},false)
scenario("A root permits damage but not repeat Nova",{distance=5,attacked=true,targetAuras={{spellId=122,expirationTime=120}}},"frostbolt",nil,{"nova"})
scenario("Observed Frostbolt immunity uses Fireball",{},"fireball",nil,{"frostbolt"},function(x) H.immunities[x.targetGUID]={frostbolt=110} end)
scenario("Root immunity does not block Frostbolt",{distance=5,attacked=true},"frostbolt",nil,{"nova"},function(x) H.immunities[x.targetGUID]={nova=110} end)
scenario("Both damage schools immune uses Arcane fallback",{},"missiles",nil,{"frostbolt","fireball"},function(x) H.immunities[x.targetGUID]={frostbolt=110,fireball=110} end)
scenario("Immunity on a different creature is ignored",{},"frostbolt",nil,nil,function() H.immunities["Other-creature"]={frostbolt=110} end)

-- 21-40: buffs, exact resource thresholds and survival conditions.
scenario("Long-duration self buffs are retained",{combat=false,target=false,playerAuras={{spellId=1461,expirationTime=701},{spellId=7302,expirationTime=701}}},false,nil,{"intellect","icearmor"})
scenario("Self buffs at five-minute refresh boundary",{combat=false,target=false,playerAuras={{spellId=1461,expirationTime=400},{spellId=7302,expirationTime=400}}},false,{"intellect","icearmor"})
scenario("Stronger intellect elixir prevents refresh",{combat=false,target=false,playerAuras={{spellId=11390,expirationTime=200}}},false,nil,{"intellect"})
scenario("Weaker intellect buff can be replaced",{combat=false,target=false,playerAuras={{spellId=3160,expirationTime=200}}},false,{"intellect"})
scenario("Group preparation chooses Mage Armor",{combat=false,target=false,grouped=true},false,{"magearmor"},{"icearmor","frostarmor"})
paused("Eating pauses buffs and other preparation",{combat=false,target=false,health=500,power=400,names={[433]="Food"},playerAuras={{spellId=433,name="Food",expirationTime=120}}})
scenario("No carried recovery items means no food or water",{combat=false,target=false,health=500,power=400},false,nil,{"food","water"})
scenario("Spent mana gem is removed after bag update",{power=400,inventory={[5514]=1}},"frostbolt",nil,{"gem"},function(x)
    F.evaluate(); x.inventory[5514]=0; F.event("BAG_UPDATE_DELAYED")
end)
scenario("Exactly enough mana for an attack",{power=50,wand=false},"frostbolt")
scenario("Guaranteed regeneration funds the next attack",{power=30,wand=false,regen=10},"frostbolt")
scenario("Insufficient predicted mana yields no attack",{power=29,wand=false,regen=10},false)
scenario("Low mana conserves resources with wand",{power=100},"shoot")
scenario("Clearcasting suppresses wand conservation",{power=100,playerAuras={{spellId=12536,expirationTime=110}}},"frostbolt",nil,{"shoot"})
scenario("Low-health elite is not assumed to be a finisher",{classification="elite",targetHealth=100,distance=15},"frostbolt",nil,{"shoot","fireblast"})
scenario("Finisher respects the mana threshold",{power=250,targetHealth=140,distance=15},"frostbolt",nil,{"fireblast"})
scenario("Mana gem threshold does not overconsume",{power=450,inventory={[5514]=1}},"frostbolt",nil,{"gem"})
scenario("Ice Block health threshold is strict",{talents=frost,health=200,attacked=true},"frostbolt",nil,{"iceblock"})
scenario("Hypothermia blocks Ice Block",{talents=frost,health=150,attacked=true,playerAuras={{spellId=41425,expirationTime=120}}},"frostbolt",nil,{"iceblock"})
scenario("Existing Mana Shield is not reapplied",{health=300,power=500,attacked=true,playerAuras={{spellId=1463,expirationTime=120}}},"frostbolt",nil,{"manashield"})
scenario("Existing Barrier prevents a second shield",{talents=frost,health=300,power=500,attacked=true,playerAuras={{spellId=11426,expirationTime=120}}},"frostbolt",nil,{"barrier","manashield"})

-- 41-50: event order, same-cast timing updates and action-bar notices.
local x=F.reset({cast={id=116,start=100,finish=103},distance=15})
F.evaluate(); x.time=101; x.targetGUID="New-target"; x.targetHealth=140
local p=F.evaluate()
record("Target switch releases old target's plan","Choose finisher for the new target",F.main(p)=="fireblast",p)

x=F.reset({cast={id=116,start=100,finish=103},distance=15})
F.evaluate(); x.cast=nil; x.time=103.3; x.targetHealth=140; p=F.evaluate()
record("Cast completion does not expire the advertised next action","Keep Frostbolt through the handoff",F.main(p)=="frostbolt",p)

x=F.reset({cast={id=116,token="same-cast",start=100,finish=103},distance=15})
F.evaluate(); x.time=101; x.cast.start=100.5; x.cast.finish=103.5; x.targetHealth=140; p=F.evaluate()
record("Same cast GUID with revised timing","Keep Frostbolt when timing changes without a new cast",F.main(p)=="frostbolt",p)

x=F.reset({combat=false,target=false})
local _,context=F.evaluate(); F.event("UNIT_SPELLCAST_SUCCEEDED","player","buff-A",context.spells.intellect.id)
record("Successful buff waits for aura update","Do not immediately repeat Intellect",not F.find(H.picks,"intellect"),H.picks)

local function notices(options,configure,repeatTick)
    local state=F.reset(options); if configure then configure(state) end
    local original=TestAddon.Print; local messages={}
    TestAddon.Print=function(_,message) messages[#messages+1]=message end
    F.event("ACTIONBAR_SLOT_CHANGED")
    if repeatTick then state.time=state.time+100; H:Tick(); H:Tick() end
    TestAddon.Print=original
    return H.picks,messages
end
p,context=notices({},function(state)
    state.actionSlots[1]={"macro",77}; state.macroSpells[77]=H.definitions.frostbolt.id
end)
record("Resolved conditional macro satisfies the bar check","No missing-spell notice",F.main(p)=="frostbolt" and #context==0,p)
p,context=notices({},function(state) state.actionSlots[120]={"spell",H.definitions.frostbolt.id} end)
record("Hidden action page satisfies the bar check","No missing-spell notice",F.main(p)=="frostbolt" and #context==0,p)
p,context=notices({},nil,true)
record("Missing spell chat is suppressed after first notice","Exactly one named notice across repeated ticks",#context==1 and context[1]:find("frostbolt",1,true),p)
p,context=notices({},function(state) state.actionSlots[1]={"spell",116} end)
record("Old spell rank does not conceal missing current rank","Report the missing recommended rank",#context==1,p)
p,context=notices({distance=50})
record("Out-of-range advice produces no missing-spell noise","No Main and no notice",not F.main(p) and #context==0,p)

F.reset({}); MOCK.class="ROGUE"; H:SetEnabled(true)
record("Unsupported class remains disabled","No rotation recommendations",not H:Enabled() and #H.picks==0,H.picks)

assert(#results==50,"Extended suite must contain exactly 50 additional scenarios")
return {cases=results,findings=findings,namedCount=#results}
