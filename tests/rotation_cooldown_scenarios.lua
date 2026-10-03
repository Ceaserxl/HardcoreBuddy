-- Fifty end-to-end cooldown scenarios using real rebuild/snapshot/selection.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local frost,fire,arcane=F.build(3,40),F.build(2,40),F.build(1,60)
assert(arcane.arcanePower==1,"Arcane Power scenarios require a legal build that learned it")
local function record(name,expected,pass,picks)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(picks)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function scenario(name,options,main,includes,excludes)
    F.reset(options); local picks=F.evaluate()
    local pass=F.main(picks)==(main or nil)
    for _,key in ipairs(includes or {}) do pass=pass and F.find(picks,key)~=nil end
    for _,key in ipairs(excludes or {}) do pass=pass and F.find(picks,key)==nil end
    record(name,"Main "..(main or "none").."; include "..table.concat(includes or {},", ").."; exclude "..table.concat(excludes or {},", "),pass,picks)
end

-- 1-12: learned ranks, GCD normalization, boundaries, and cast completion.
scenario("Level 1 Fireball during GCD",{level=1,gcd=1.5,gcdSpells=true},"fireball")
scenario("Level 4 Frostbolt during GCD",{level=4,gcd=1.5,gcdSpells=true},"frostbolt")
scenario("Finisher ready now",{targetHealth=140,distance=15},"fireblast")
scenario("Finisher ready in one second",{targetHealth=140,distance=15,cooldowns={fireblast=1}},"fireblast")
scenario("Finisher at two-second boundary",{targetHealth=140,distance=15,cooldowns={fireblast=2}},"fireblast")
scenario("Finisher beyond two-second boundary",{targetHealth=140,distance=15,cooldowns={fireblast=2.01}},"frostbolt",nil,{"fireblast"})
scenario("Finisher with long cooldown",{targetHealth=140,distance=15,cooldowns={fireblast=7}},"frostbolt",nil,{"fireblast"})
scenario("Finisher cooldown disabled",{targetHealth=140,distance=15,cooldowns={fireblast={enabled=0}}},"frostbolt",nil,{"fireblast"})
scenario("Finisher cooldown expired",{targetHealth=140,distance=15,cooldowns={fireblast={start=90,duration=8}}},"fireblast")
scenario("Finisher ready before current cast ends",{targetHealth=140,distance=15,cooldowns={fireblast=2.5},cast={id=116,start=100,finish=103}},"fireblast")
scenario("Finisher ready exactly when cast ends",{targetHealth=140,distance=15,cooldowns={fireblast=3},cast={id=116,start=100,finish=103}},"fireblast")
scenario("Finisher still unavailable when cast ends",{targetHealth=140,distance=15,cooldowns={fireblast=3.01},cast={id=116,start=100,finish=103}},"frostbolt",nil,{"fireblast"})

-- 13-23: immediate defensive readiness, with usable emergency fallbacks.
scenario("Counterspell ignores GCD",{gcd=1.5,gcdSpells=true,targetCast={id=999,start=99,finish=102}},"frostbolt",{"counterspell"})
scenario("Counterspell on long cooldown",{cooldowns={counterspell=20},targetCast={id=999,start=99,finish=102}},"frostbolt",nil,{"counterspell"})
scenario("Counterspell not yet ready",{cooldowns={counterspell=0.1},targetCast={id=999,start=99,finish=102}},"frostbolt",nil,{"counterspell"})
scenario("Counterspell ready now",{targetCast={id=999,start=99,finish=102}},"frostbolt",{"counterspell"})
scenario("Nova cooldown prevents repeat root",{distance=5,attacked=true,cooldowns={nova=10}},"frostbolt",nil,{"nova"})
scenario("Nova ignores GCD",{distance=5,attacked=true,gcd=1.5,gcdSpells=true},"frostbolt",{"nova"})
scenario("Cold Snap replaces unavailable Ice Block",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120}},"frostbolt",{"coldsnap"},{"iceblock"})
scenario("Both survival cooldowns unavailable",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120,coldsnap=60}},"frostbolt",nil,{"iceblock","coldsnap"})
scenario("Mana Shield replaces unavailable Barrier",{health=300,attacked=true,talents=frost,cooldowns={barrier=20}},"frostbolt",{"manashield"},{"barrier"})
scenario("Ready Barrier keeps priority",{health=300,attacked=true,talents=frost},"frostbolt",{"barrier"},{"manashield"})
scenario("Shield fallback still respects mana",{health=300,power=300,attacked=true,talents=frost,cooldowns={barrier=20}},"frostbolt",nil,{"barrier","manashield"})

-- 24-38: optional damage, item cooldowns, recovery and preparation.
scenario("Arcane Power ready",{level=60,talents=arcane,classification="elite",grouped=true},"fireball",{"arcanePower"})
scenario("Arcane Power cooling down",{level=60,talents=arcane,classification="elite",grouped=true,cooldowns={arcanePower=180}},"fireball",nil,{"arcanePower"})
scenario("Combustion ready",{talents=fire,grouped=true},"fireball",{"combustion"})
scenario("Combustion cooling down",{talents=fire,grouped=true,cooldowns={combustion=180}},"fireball",nil,{"combustion"})
scenario("Mana gem ready",{power=400,inventory={[5514]=1}},"frostbolt",{"gem"})
scenario("Mana gem cooling down",{power=400,inventory={[5514]=1},itemCooldown=120},"frostbolt",nil,{"gem"})
scenario("Mana gem cooldown disabled",{power=400,inventory={[5514]=1},itemEnabled=0},"frostbolt",nil,{"gem"})
scenario("Evocation ready out of combat",{combat=false,target=false,power=100},false,{"evocation"})
scenario("Evocation unavailable out of combat",{combat=false,target=false,power=100,cooldowns={evocation=120}},false,nil,{"evocation"})
scenario("Self buffs ignore GCD",{combat=false,target=false,gcd=1.5,gcdSpells=true},false,{"intellect","icearmor"})
scenario("Preparation Barrier cooling down",{combat=false,target=false,talents=frost,cooldowns={barrier=20}},false,nil,{"barrier"})
scenario("Food ready",{combat=false,target=false,health=500,inventory={[117]=5}},false,{"food"})
scenario("Food cooling down",{combat=false,target=false,health=500,inventory={[117]=5},itemCooldown=10},false,nil,{"food"})
scenario("Water ready",{combat=false,target=false,power=400,inventory={[159]=5}},false,{"water"})
scenario("Water cooling down",{combat=false,target=false,power=400,inventory={[159]=5},itemCooldown=10},false,nil,{"water"})

-- 39-40: readiness does not override range or crowd control.
scenario("Ready finisher outside its range",{targetHealth=140,distance=25},"frostbolt",nil,{"fireblast"})
scenario("Ready finisher on controlled target",{targetHealth=140,distance=15,targetAuras={{spellId=118,expirationTime=120}}},false,nil,{"fireblast"})

-- 41-50: time-ordered transitions and the previous audit fixes.
local x=F.reset({targetHealth=140,distance=15,cooldowns={fireblast={start=100,duration=7}}})
local before=F.evaluate(); x.time=105; local p=F.evaluate()
record("Countdown enters the planning window","Frostbolt first, Fire Blast with two seconds left",F.main(before)=="frostbolt" and F.main(p)=="fireblast",p)

x=F.reset({targetHealth=140,distance=15,cooldowns={fireblast={start=100,duration=7}},cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=102.9; x.cooldowns.fireblast=0; p=F.evaluate()
record("Readiness change preserves committed attack","Frostbolt stays Main through the cast",F.main(p)=="frostbolt" and not F.find(p,"fireblast"),p)
x.time=103.1; x.cast={id=116,token="cast-B",start=103.1,finish=106.1}; p=F.evaluate()
record("Next cast reconsiders ready finisher","Fire Blast becomes Main at next cast start",F.main(p)=="fireblast",p)
x.cooldowns.fireblast=7; p=F.evaluate()
record("Committed spell starts a long cooldown","Hide unavailable Main without switching late",not F.main(p) and not F.find(p,"fireblast"),p)

x=F.reset({power=50,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.power=500; x.time=101.5; p=F.evaluate()
record("Empty plan fills after mana recovery","Frostbolt becomes Main",F.main(p)=="frostbolt",p)

x=F.reset({power=120,maxPower=200,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=103; x.power=70; F.event("UNIT_SPELLCAST_SUCCEEDED","player","cast-A",116)
record("Paid cast still visible in casting API","Do not subtract the completed cast twice",F.main(H.picks)=="frostbolt",H.picks)

x=F.reset({targetHealth=140,distance=15,cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=101; x.targetHealth=1000; F.event("UNIT_SPELLCAST_INTERRUPTED","player","cast-A",116)
record("Matching interruption before API clear","Replan Frostbolt immediately",F.main(H.picks)=="frostbolt",H.picks)

x=F.reset({targetHealth=140,distance=15,cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=101; x.targetHealth=1000; F.event("UNIT_SPELLCAST_FAILED","player","extra-press",116)
record("Unrelated failed press","Keep committed Fire Blast",F.main(H.picks)=="fireblast",H.picks)

x=F.reset({level=25,talents=F.build(2,25),classification="elite",grouped=true,cast={id=2948,start=100,finish=101.5},
    targetAuras={{spellId=22959,applications=4,expirationTime=125}}})
p=F.evaluate()
record("Partial Scorch talent during cast","Continue Scorch without assuming a fifth stack",F.main(p)=="scorch",p)

x=F.reset({targetHealth=140,distance=15,cooldowns={fireblast=7}})
x.actionSlots[1]={"spell",H.definitions.frostbolt.id}
local printMessage=TestAddon.Print; local notices={}
TestAddon.Print=function(_,message) notices[#notices+1]=message end
F.event("ACTIONBAR_SLOT_CHANGED"); TestAddon.Print=printMessage
record("Gated spell does not generate missing-bar chat","No warning for unavailable Fire Blast",#notices==0 and F.main(H.picks)=="frostbolt",H.picks)

assert(#results==50,"Cooldown regression suite must run exactly 50 scenarios")
return {cases=results,findings=findings,namedCount=#results}
