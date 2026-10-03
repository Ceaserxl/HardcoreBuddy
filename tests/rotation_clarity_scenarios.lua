-- Choices at decision boundaries, not just isolated snapshots of each rule.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local frost,fire=F.build(3,40),F.build(2,40)
local function record(name,expected,pass,picks)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(picks)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function scenario(name,options,main,includes,excludes)
    F.reset(options)
    local p=F.evaluate()
    local pass=F.main(p)==(main or nil)
    for _,key in ipairs(includes or {}) do pass=pass and F.find(p,key)~=nil end
    for _,key in ipairs(excludes or {}) do pass=pass and F.find(p,key)==nil end
    record(name,"Main "..(main or "none").."; include "..table.concat(includes or {},", ").."; exclude "..table.concat(excludes or {},", "),pass,p)
end

scenario("Healthy mana does not wand at eleven percent target health",{targetHealth=110,distance=15},"fireblast",nil,{"shoot"})
scenario("Healthy mana does not wand when finisher is out of range",{targetHealth=110,distance=25},"frostbolt",nil,{"shoot"})
scenario("Low mana still conserves during a finish",{targetHealth=110,distance=15,power=100},"shoot")
scenario("Idle player does not wait for a one-second finisher cooldown",{targetHealth=140,distance=15,cooldowns={fireblast=1}},"frostbolt")
scenario("Idle player does not wait for a two-second finisher cooldown",{targetHealth=140,distance=15,cooldowns={fireblast=2}},"frostbolt")
scenario("Finisher is ready by the remaining GCD",{targetHealth=140,distance=15,gcd=1.5,gcdSpells=true,cooldowns={fireblast=1}},"fireblast")
scenario("Finisher is not ready by the remaining GCD",{targetHealth=140,distance=15,gcd=1.5,gcdSpells=true,cooldowns={fireblast=1.6}},"frostbolt")
scenario("Short cast does not extend cooldown eligibility to two seconds",{targetHealth=140,distance=15,cast={id=116,start=100,finish=100.5},cooldowns={fireblast=1}},"frostbolt")
scenario("Long cast plans a finisher ready at completion",{targetHealth=140,distance=15,cast={id=116,start=100,finish=103},cooldowns={fireblast=2}},"fireblast")
scenario("Affordable attack beats a resource forecast",{power=30,wand=false,regen=10,costs={fireball=20}},"fireball")
scenario("Two-second resource forecast remains when no attack is affordable",{power=30,wand=false,regen=10},"frostbolt")
scenario("Resource forecast cannot bypass a cooldown",{power=30,wand=false,regen=10,cooldowns={frostbolt=1}},"fireball")
scenario("Full cast window includes confirmed regeneration",{power=60,wand=false,regen=20,cast={id=116,start=100,finish=103}},"frostbolt")

local x=F.reset({power=140})
local p=F.evaluate()
record("Enter wand conservation below fifteen percent","Main Shoot",F.main(p)=="shoot",p)
x.power=160; p=F.evaluate()
record("Mana tick across fifteen percent does not bounce to a spell","Main Shoot until twenty-five percent",F.main(p)=="shoot",p)
x.power=240; p=F.evaluate()
record("Wand conservation remains stable below recovery threshold","Main Shoot",F.main(p)=="shoot",p)
x.power=250; p=F.evaluate()
record("Recovered mana returns to the normal filler","Main Frostbolt",F.main(p)=="frostbolt",p)
x.power=160; p=F.evaluate()
record("Small mana loss does not immediately re-enter wand mode","Main Frostbolt",F.main(p)=="frostbolt",p)
x.power=140; F.evaluate(); x.power=160; x.targetGUID="Another-target"; p=F.evaluate()
record("New target does not inherit previous target's conservation state","Main Frostbolt",F.main(p)=="frostbolt",p)
x.power=140; F.evaluate(); x.playerAuras={{spellId=12536,expirationTime=120}}; p=F.evaluate()
record("Clearcasting ends wand conservation","Main Frostbolt",F.main(p)=="frostbolt",p)
scenario("No automatic wand pull with insufficient spell mana",{combat=false,targetCombat=false,power=0},false,nil,{"shoot"})
scenario("Low mana but affordable slow still opens safely",{combat=false,targetCombat=false,power=100},"frostbolt",nil,{"shoot"})

scenario("Fire utility points alone do not switch the filler",{level=16,grouped=true,talents={impact=5,flameThrowing=2}},"frostbolt")
scenario("Actual Fire damage investments choose Fireball in a group",{grouped=true,talents=fire},"fireball")
scenario("Actual Frost damage investments retain Frostbolt",{grouped=true,talents=frost},"frostbolt")
scenario("Fire solo retains a healthy existing slow",{talents=fire,targetAuras={{spellId=116,expirationTime=110}}},"fireball")
scenario("Fire solo renews a slow about to expire",{talents=fire,targetAuras={{spellId=116,expirationTime=101}}},"frostbolt")
scenario("Do not build Scorch stacks on a nearly dead elite",{talents=fire,grouped=true,classification="elite",targetHealth=100},"fireball",nil,{"scorch"})
scenario("Build Scorch on a healthy durable target",{talents=fire,grouped=true,classification="elite"},"scorch")
scenario("Do not suggest Combustion before a pull",{talents=fire,combat=false,targetCombat=false,classification="elite"},"pyroblast",nil,{"combustion"})
scenario("Do not spend Combustion on routine leveling targets",{talents=fire,grouped=true},"fireball",nil,{"combustion"})
scenario("Combustion remains available on an engaged durable target",{talents=fire,grouped=true,classification="elite"},"scorch",{"combustion"})
scenario("Combustion is not a low-mana suggestion",{talents=fire,grouped=true,classification="elite",power=400},"scorch",nil,{"combustion"})
scenario("No damage cooldown on a controlled target",{level=60,talents=F.build(1,60),grouped=true,classification="elite",targetAuras={{spellId=118,expirationTime=120}}},false,nil,{"arcanePower"})
scenario("No damage cooldown outside attack range",{talents=fire,grouped=true,classification="elite",distance=50},false,nil,{"combustion"})
scenario("No Combustion for a committed Frost attack",{talents=fire,classification="elite",targetAuras={{spellId=22959,applications=5,expirationTime=125}}},"frostbolt",nil,{"combustion"})
x=F.reset({level=60,talents=F.build(1,60),grouped=true,classification="elite"})
H.immunities[x.targetGUID]={frostbolt=120,fireball=120,fireblast=120,scorch=120,missiles=120}
p=F.evaluate()
record("Arcane Power does not accompany a wand fallback","Shoot without Arcane Power",F.main(p)=="shoot" and not F.find(p,"arcanePower"),p)

scenario("Solo refresh respects existing Mage Armor",{combat=false,target=false,playerAuras={{spellId=6117,expirationTime=200}}},false,{"magearmor"},{"icearmor","frostarmor"})
scenario("Group refresh respects existing physical armor",{combat=false,target=false,grouped=true,playerAuras={{spellId=7302,expirationTime=200}}},false,{"icearmor"},{"magearmor"})
scenario("No armor in a group defaults to Mage Armor",{combat=false,target=false,grouped=true},false,{"magearmor"},{"icearmor"})
scenario("Older physical armor can refresh with learned Ice Armor",{combat=false,target=false,playerAuras={{spellId=168,expirationTime=200}}},false,{"icearmor"},{"magearmor","frostarmor"})
scenario("Hostile opener hides preparation until it completes",{talents=fire,combat=false,targetCombat=false,cast={id=11366,start=100,finish=106}},"frostbolt",nil,{"intellect","icearmor","conjureGem"})
scenario("Unknown cast does not invite preparation interruptions",{combat=false,target=false,cast={id=8690,start=100,finish=110}},false,nil,{"intellect","icearmor","conjureGem"})
scenario("Evocation channel hides preparation and attacks",{combat=false,target=false,power=100,health=500,channel={id=12051,start=100,finish=108},inventory={[159]=5,[117]=5}},false,nil,{"water","food","intellect","icearmor","conjureGem","evocation"})
scenario("Carried water takes precedence over Evocation",{combat=false,target=false,power=100,inventory={[159]=5}},false,{"water"},{"evocation"})
scenario("Evocation remains a fallback without water",{combat=false,target=false,power=100},false,{"evocation"},{"water"})
scenario("Water on cooldown permits Evocation fallback",{combat=false,target=false,power=100,inventory={[159]=5},itemCooldown=10},false,{"evocation"},{"water"})
scenario("Food and water still coexist",{combat=false,target=false,power=100,health=500,inventory={[159]=5,[117]=5}},false,{"food","water"},{"evocation"})
scenario("Disabled recovery items are not suggested",{combat=false,target=false,power=400,health=500,inventory={[159]=5,[117]=5},itemEnabled=false},false,nil,{"water","food"})
scenario("Real harmful Hypothermia blocks Ice Block",{talents=frost,attacked=true,health=150,playerHarmful={{spellId=41425,expirationTime=130}}},"frostbolt",nil,{"iceblock"})
scenario("Cold Snap does not promise to remove Hypothermia",{talents=frost,attacked=true,health=150,playerHarmful={{spellId=41425,expirationTime=130}},cooldowns={iceblock=120}},"frostbolt",nil,{"iceblock","coldsnap"})
scenario("Cold Snap can still reset a missing Barrier with Hypothermia",{talents=frost,attacked=true,health=150,playerHarmful={{spellId=41425,expirationTime=130}},cooldowns={iceblock=120,barrier=20}},"frostbolt",{"coldsnap"},{"iceblock"})
scenario("Cold Snap is unnecessary when Barrier remains active",{talents=frost,attacked=true,health=250,playerAuras={{spellId=11426,expirationTime=130}},cooldowns={barrier=20}},"frostbolt",nil,{"coldsnap"})

for _,event in ipairs({"ACTIONBAR_SLOT_CHANGED","UPDATE_MACROS","PLAYER_REGEN_ENABLED"}) do
    x=F.reset({cast={id=116,start=100,finish=103},distance=15})
    F.evaluate(); x.time=102.8; x.targetHealth=140
    F.event(event)
    record(event.." does not replace a committed attack","Main Frostbolt, despite new finisher conditions",F.main(H.picks)=="frostbolt",H.picks)
end
x=F.reset({grouped=true,cast={id=116,start=100,finish=103},distance=15})
F.evaluate(); x.targetCombat=false; p=F.evaluate()
record("Commitment cannot bypass group pull safety","No Main when target is no longer engaged",not F.main(p),p)
x=F.reset({cast={id=116,start=100,finish=103},distance=15})
F.evaluate(); x.cast=nil; x.time=103.1; x.combat=false
x.playerAuras={{spellId=430,name="drink",expirationTime=120}}; x.names[430]="drink"
p=F.evaluate()
record("Handoff cannot recommend breaking newly started recovery","No Main while drinking",not F.main(p),p)

x=F.reset({targetHealth=140,distance=15})
F.evaluate(); F.event("UNIT_SPELLCAST_SUCCEEDED","player","instant-A",H.definitions.fireblast.id)
record("Successful finisher waits for the cooldown API update","Main Frostbolt, no repeat Fire Blast",F.main(H.picks)=="frostbolt" and not F.find(H.picks,"fireblast"),H.picks)
x.time=100.3; p=F.evaluate()
record("Finisher does not flash during cooldown propagation","Main Frostbolt",F.main(p)=="frostbolt",p)
x.time=100.7; x.cooldowns.fireblast=7; p=F.evaluate()
record("Reported cooldown replaces the brief success guard","Main Frostbolt",F.main(p)=="frostbolt",p)

x=F.reset({targetHealth=140,distance=15,cast={id=116,start=100,finish=103}})
F.evaluate(); x.cast=nil; x.time=103.05
F.event("UNIT_SPELLCAST_SUCCEEDED","player","instant-B",H.definitions.fireblast.id)
record("Using the held instant clears the old cast handoff","Main Frostbolt without a blank handoff",F.main(H.picks)=="frostbolt",H.picks)

x=F.reset({distance=5,attacked=true})
F.event("UNIT_SPELLCAST_SUCCEEDED","player","nova-A",H.definitions.nova.id)
record("Successful Nova is not repeated before its aura arrives","No Nova; Main remains",F.main(H.picks)=="frostbolt" and not F.find(H.picks,"nova"),H.picks)
x=F.reset({targetCast={id=999,start=99,finish=102}})
F.event("UNIT_SPELLCAST_SUCCEEDED","player","interrupt-A",H.definitions.counterspell.id)
record("Successful interrupt is not repeated on a stale target cast","No Counterspell; Main remains",F.main(H.picks)=="frostbolt" and not F.find(H.picks,"counterspell"),H.picks)

return {cases=results,findings=findings,namedCount=#results}
