-- Report policy gaps explicitly. No production rules are changed by this audit.
local F=ScenarioFixture
local H=F.helper
local findings={}; local results={}; local count=0
local frost=F.build(3,40)
local fire=F.build(2,40)
local arcane=F.build(1,40)
local function record(name,expected,pass,actual,priority)
    count=count+1
    local r={name=name,expected=expected,passed=not not pass,actual=actual,priority=priority}
    results[#results+1]=r
    if not pass then findings[#findings+1]=r end
end
local function scenario(name,options,expected,predicate,priority)
    F.reset(options); local p,c=F.evaluate()
    record(name,expected,predicate(p,c),F.describe(p),priority)
end

scenario("Level 1 starter",{level=1},"Main Fireball",function(p) return F.main(p)=="fireball" end)
scenario("Level 4 Frostbolt learned",{level=4},"Main Frostbolt",function(p) return F.main(p)=="frostbolt" end)
scenario("Frost solo leveling",{talents=frost},"Main Frostbolt",function(p) return F.main(p)=="frostbolt" end)
scenario("Fire group fight",{talents=fire,grouped=true},"Main Fireball",function(p) return F.main(p)=="fireball" end)
scenario("Arcane leveling fallback",{talents=arcane},"Main Frostbolt",function(p) return F.main(p)=="frostbolt" end)
scenario("Fire solo opener",{talents=fire,combat=false,targetCombat=false},"Main Pyroblast",function(p) return F.main(p)=="pyroblast" end)
scenario("Fire solo slowed target",{talents=fire,targetAuras={{spellId=116,expirationTime=110}}},"Main Fireball",function(p) return F.main(p)=="fireball" end)
scenario("Improved Scorch on elite",{talents=fire,classification="elite",grouped=true},"Main Scorch",function(p) return F.main(p)=="scorch" end)
scenario("No Scorch ramp on normal mob",{talents=fire,grouped=true},"Main Fireball",function(p) return F.main(p)=="fireball" end)
scenario("Scorch already stacked",{talents=fire,classification="elite",grouped=true,targetAuras={{spellId=22959,applications=5,expirationTime=125}}},"Main Fireball",function(p) return F.main(p)=="fireball" end)
scenario("Scorch expiring",{talents=fire,classification="elite",grouped=true,targetAuras={{spellId=22959,applications=5,expirationTime=104}}},"Main Scorch",function(p) return F.main(p)=="scorch" end)
scenario("Low mana with wand",{power=100},"Main Shoot",function(p) return F.main(p)=="shoot" end)
scenario("No mana and no wand",{power=0,wand=false},"No Main",function(p) return not F.main(p) end)
scenario("Close attacker",{distance=5,attacked=true},"Nova beside Main",function(p) return F.main(p) and F.find(p,"nova") end)
scenario("Root already active",{distance=5,attacked=true,targetAuras={{spellId=122,expirationTime=107}}},"No repeat Nova; Main remains",function(p) return F.main(p) and not F.find(p,"nova") end)
scenario("Interruptible target",{targetCast={id=999,start=99,finish=102}},"Counterspell beside Main",function(p) return F.find(p,"counterspell") and F.main(p) end)
scenario("Uninterruptible target",{targetCast={id=999,start=99,finish=102,uninterruptible=true}},"No Counterspell",function(p) return not F.find(p,"counterspell") end)
scenario("Unengaged group target",{grouped=true,targetCombat=false},"No Main",function(p) return not F.main(p) end)
scenario("Polymorphed target",{targetAuras={{spellId=118,expirationTime=120}}},"No Main",function(p) return not F.main(p) end)
scenario("Unknown range",{unknownRange=true},"No Main",function(p) return not F.main(p) end)
scenario("Outside all spell ranges",{distance=50},"No Main",function(p) return not F.main(p) end)
scenario("Friendly target",{friendly=true},"No Main",function(p) return not F.main(p) end)
scenario("PvP target",{pvp=true},"No Main",function(p) return not F.main(p) end)
scenario("Tapped by another player",{tapped=true},"No Main",function(p) return not F.main(p) end)
scenario("Player dead",{dead=true},"No highlights",function(p) return #p==0 end)
scenario("Player on taxi",{taxi=true},"No highlights",function(p) return #p==0 end)
scenario("Player in Ice Block",{playerAuras={{spellId=11958,expirationTime=110}}},"No highlights",function(p) return #p==0 end)
scenario("Missing self buffs",{combat=false,target=false},"Intellect and armor",function(p) return F.find(p,"intellect") and F.find(p,"icearmor") end)
scenario("Healthy long buffs",{combat=false,target=false,playerAuras={{spellId=1461,expirationTime=700},{spellId=7302,expirationTime=700}}},"No Intellect or armor refresh",function(p) return not F.find(p,"intellect") and not F.find(p,"icearmor") end)
scenario("Buffs expire in five minutes",{combat=false,target=false,playerAuras={{spellId=1461,expirationTime=400},{spellId=7302,expirationTime=400}}},"Intellect and armor refresh",function(p) return F.find(p,"intellect") and F.find(p,"icearmor") end)
scenario("Stronger intellect elixir",{level=20,combat=false,target=false,playerAuras={{spellId=11390,expirationTime=400}}},"No weaker Intellect",function(p) return not F.find(p,"intellect") end)
scenario("Carried recovery supplies",{combat=false,target=false,health=700,power=500,inventory={[117]=5,[159]=5}},"Food and water",function(p) return F.find(p,"food") and F.find(p,"water") end)
scenario("Bank-only supplies",{combat=false,target=false,health=700,power=500},"No unowned food/water",function(p) return not F.find(p,"food") and not F.find(p,"water") end)
scenario("Drinking",{combat=false,target=false,power=200,names={[430]="Drink"},playerAuras={{spellId=430,name="Drink",expirationTime=120}}},"No preparation interruptions",function(p) return #p==0 end)
scenario("Emergency Ice Block",{health=150,attacked=true,talents=frost},"Ice Block",function(p) return F.find(p,"iceblock") end)
scenario("Curse on player",{cursed=true},"Remove Lesser Curse",function(p) return F.find(p,"decurse") end)

-- These expected outcomes describe actionable advice, distinct from merely
-- showing an intent. They expose the consequences of removing cooldown gates.
scenario("Unavailable Ice Block masks ready Cold Snap",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120}},
    "Ready Cold Snap is visible as an emergency option",function(p) return F.find(p,"coldsnap") end,"high")
scenario("Unavailable Barrier masks ready Mana Shield",{health=300,attacked=true,talents=frost,cooldowns={barrier=20}},
    "Ready Mana Shield is visible as an emergency option",function(p) return F.find(p,"manashield") end,"high")
scenario("Unavailable Fire Blast replaces usable main",{targetHealth=140,distance=15,wand=false,cooldowns={fireblast=7}},
    "Main is a usable filler or there is a separately visible usable fallback",function(p) return F.main(p)~="fireblast" end,"high")

local x=F.reset({power=120,maxPower=200,wand=false,defaultCost=50,cast={id=116,start=100,finish=103}})
local p=F.evaluate(); record("Cast start chooses affordable next attack","Main Frostbolt",F.main(p)=="frostbolt",F.describe(p))
x.time=103; x.power=70 -- Server charged the completed cast; casting API still shows it.
F.event("UNIT_SPELLCAST_SUCCEEDED","player","cast-A",116)
record("Mana charged before casting API clears","Committed Main stays visible with 70 mana for a 50-mana spell",F.main(H.picks)=="frostbolt",F.describe(H.picks),"high")
x.cast=nil; x.time=103.05; p=F.evaluate()
record("Casting API catches up after success","Main returns",F.main(p)=="frostbolt",F.describe(p))

x=F.reset({targetHealth=140,distance=15,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=101; x.targetHealth=1000
F.event("UNIT_SPELLCAST_INTERRUPTED","player","cast-A",116) -- Event before API clears.
x.cast=nil; x.time=101.1; p=F.evaluate()
record("Interrupt event precedes API clear","Immediately choose Frostbolt for the changed situation",F.main(p)=="frostbolt",F.describe(p),"medium")

x=F.reset({level=25,talents=F.build(2,25),grouped=true,classification="elite",cast={id=2948,start=100,finish=101.5},targetAuras={{spellId=22959,applications=4,expirationTime=125}}})
assert(x.talents.improvedScorch==1,"Partial Scorch scenario needs exactly one talent rank")
p=F.evaluate()
record("Partial Improved Scorch talent","Do not assume the next Scorch guarantees stack five",F.main(p)=="scorch",F.describe(p),"medium")

x=F.reset({defaultCost=50,power=50,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.power=500; x.time=101.5; p=F.evaluate()
record("Mana restored during an initially unaffordable cast","Fill an empty next-action plan after mana recovery",F.main(p)~=nil,F.describe(p),"medium")

x=F.reset({actionSlots={[1]={"spell",133}}})
x.actionSlots[1][2]=H.definitions.fireball.id
p=F.evaluate(); local best=p[1]; local kind,id=H.Glow.Action({action=1})
record("Preferred spell absent from action bars","Usable fallback or a visible missing-action notice",not best or best.kind==kind and best.id==id,F.describe(p).."; only Fireball is on bar","medium")

-- Context enumeration is a structural/safety smoke test, not an optimal-DPS
-- claim. Named tests above assess specific policy outcomes.
local combinations,violations,unavailableMain=0,0,0
for _,level in ipairs({1,4,10,20,40,60}) do
for _,tree in ipairs({3,2,1}) do
local talents=F.build(tree,level)
for _,health in ipairs({150,600,1000}) do
for _,power in ipairs({80,400,1000}) do
for _,classification in ipairs({"normal","elite"}) do
for _,distance in ipairs({5,25,50}) do
for _,grouped in ipairs({false,true}) do
for _,cd in ipairs({0,5}) do
    F.reset({level=level,talents=talents,health=health,power=power,classification=classification,distance=distance,grouped=grouped,allCooldowns=cd,
        attacked=distance==5,inventory={[5514]=1,[159]=20,[117]=20}})
    local picks,c=F.evaluate(); local mains,seen=0,{}
    for _,pick in ipairs(picks) do
        local spell=c.spells[pick.key]
        if pick.category=="main" then mains=mains+1; if spell.cooldown>0 then unavailableMain=unavailableMain+1 end end
        local unique=pick.kind..":"..pick.id
        if seen[unique] or not spell.known or spell.enemy and spell.range~=true then violations=violations+1 end
        seen[unique]=true
    end
    if mains>1 then violations=violations+1 end
    combinations=combinations+1
end end end end end end end end
record("Structural scenario matrix","No duplicate actions, multiple Mains, unknown spells, or out-of-range enemy advice",violations==0,
    combinations.." combinations; "..violations.." invariant violations; "..unavailableMain.." Main suggestions on cooldown")
return {cases=results,findings=findings,namedCount=count,matrixCount=combinations,matrixViolations=violations,cooldownMainCount=unavailableMain}
