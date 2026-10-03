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

-- Unavailable options cannot hide a ready action in the same group.
scenario("Unavailable Ice Block masks ready Cold Snap",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120}},
    "Ready Cold Snap is visible as an emergency option",function(p) return F.find(p,"coldsnap") end,"high")
scenario("Unavailable Barrier masks ready Mana Shield",{health=300,attacked=true,talents=frost,cooldowns={barrier=20}},
    "Ready Mana Shield is visible as an emergency option",function(p) return F.find(p,"manashield") end,"high")
scenario("Unavailable Fire Blast replaces usable main",{targetHealth=140,distance=15,wand=false,cooldowns={fireblast=7}},
    "Main is a usable filler or there is a separately visible usable fallback",function(p) return F.main(p)~="fireblast" end,"high")
scenario("Cooling-down finisher is hidden",{targetHealth=140,distance=15,wand=false,cooldowns={fireblast=7}},
    "Gold Frostbolt without unavailable Fire Blast",function(p) return F.main(p)=="frostbolt" and not F.find(p,"fireblast") end)
scenario("Idle finisher inside two-second lead still requires waiting",{targetHealth=140,distance=15,wand=false,cooldowns={fireblast=1.5}},
    "Main Frostbolt",function(p) return F.main(p)=="frostbolt" end)
scenario("Finisher ready by cast completion",{targetHealth=140,distance=15,wand=false,cooldowns={fireblast=2.5},cast={id=116,start=100,finish=103}},
    "Main Fire Blast at the start of the current cast",function(p) return F.main(p)=="fireblast" end)
scenario("Ready emergency options replace unavailable choices",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120,barrier=20}},
    "Cold Snap and Mana Shield without unavailable Ice Block or Barrier",function(p)
        return not F.find(p,"iceblock") and F.find(p,"coldsnap") and not F.find(p,"barrier") and F.find(p,"manashield") end)
scenario("Ready Barrier keeps shield priority",{health=300,attacked=true,talents=frost},
    "Barrier without redundant Mana Shield",function(p) return F.find(p,"barrier") and not F.find(p,"manashield") end)
scenario("Unready emergency group is hidden",{health=150,attacked=true,talents=frost,cooldowns={iceblock=120,coldsnap=60}},
    "Neither unavailable survival action glows",function(p) return not F.find(p,"iceblock") and not F.find(p,"coldsnap") end)

local x=F.reset({power=120,maxPower=200,wand=false,defaultCost=50,cast={id=116,start=100,finish=103}})
local p=F.evaluate(); record("Cast start chooses affordable next attack","Main Frostbolt",F.main(p)=="frostbolt",F.describe(p))
x.time=103; x.power=70 -- Server charged the completed cast; casting API still shows it.
F.event("UNIT_SPELLCAST_SUCCEEDED","player","cast-A",116)
record("Mana charged before casting API clears","Committed Main stays visible with 70 mana for a 50-mana spell",F.main(H.picks)=="frostbolt",F.describe(H.picks),"high")
x.cast=nil; x.time=103.05; p=F.evaluate()
record("Casting API catches up after success","Main returns",F.main(p)=="frostbolt",F.describe(p))
x.cast={id=116,token="cast-B",start=103.1,finish=106.1}; x.time=103.1; p=F.evaluate()
record("Next same-spell cast reserves mana again","Previous success cannot make a new cast free",not F.main(p),F.describe(p))

x=F.reset({targetHealth=140,distance=15,wand=false,cooldowns={fireblast=7},cast={id=116,start=100,finish=103}})
F.evaluate(); x.cooldowns.fireblast=0; x.time=102.9; p=F.evaluate()
record("Cooldown readiness cannot replace a committed Main","Frostbolt remains Main without a late Fire Blast suggestion",
    F.main(p)=="frostbolt" and not F.find(p,"fireblast"),F.describe(p))
x.distance=50; p=F.evaluate()
record("Range loss hides committed attacks","No out-of-range attack",not F.main(p) and not F.find(p,"fireblast"),F.describe(p))

x=F.reset({targetHealth=140,distance=15,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.time=101; x.targetHealth=1000
F.event("UNIT_SPELLCAST_INTERRUPTED","player","cast-A",116) -- Event before API clears.
record("Interrupted API value is ignored immediately","New plan is visible even before the API clears",F.main(H.picks)=="frostbolt",F.describe(H.picks))
x.cast=nil; x.time=101.1; p=F.evaluate()
record("Interrupt event precedes API clear","Immediately choose Frostbolt for the changed situation",F.main(p)=="frostbolt",F.describe(p),"medium")

for _,event in ipairs({"UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED"}) do
    x=F.reset({targetHealth=140,distance=15,wand=false,cast={id=116,start=100,finish=103}})
    F.evaluate(); x.time=101; x.targetHealth=1000
    F.event(event,"player","extra-press",116)
    record(event.." for another same-spell cast","A different cast GUID cannot replace the committed finisher",F.main(H.picks)=="fireblast",F.describe(H.picks))
    x.cast=nil; F.evaluate(); F.event(event,"player","cast-A",116)
    record(event.." after API clear","The matching last observed cast releases its plan",F.main(H.picks)=="frostbolt",F.describe(H.picks))
end

x=F.reset({targetHealth=140,distance=15,wand=false,cast={id=116,token=41,start=100,finish=103}})
F.event("UNIT_SPELLCAST_START","player","numeric-cast",116)
x.time=101; x.targetHealth=1000; F.event("UNIT_SPELLCAST_INTERRUPTED","player","numeric-cast",116)
record("Numeric casting API with START GUID","Matched interruption clears the plan on legacy casting IDs",F.main(H.picks)=="frostbolt",F.describe(H.picks))

x=F.reset({power=120,maxPower=200,wand=false,defaultCost=50,cast={id=116,token=42,start=100,finish=103}})
F.event("UNIT_SPELLCAST_START","player","numeric-success",116)
x.time=103; x.power=70; F.event("UNIT_SPELLCAST_SUCCEEDED","player","numeric-success",116)
record("Numeric casting API success","A matched START GUID prevents double mana reservation",F.main(H.picks)=="frostbolt",F.describe(H.picks))

x=F.reset({targetHealth=140,distance=15,wand=false,cast={id=116,token="old-cast",start=100,finish=103}})
F.evaluate(); x.time=103.1; x.cast={id=116,token="new-cast",start=103.1,finish=106.1}; F.evaluate()
x.targetHealth=1000; F.event("UNIT_SPELLCAST_INTERRUPTED","player","old-cast",116)
record("Late interruption from an earlier cast","Old GUID cannot cancel a new same-spell cast",F.main(H.picks)=="fireblast",F.describe(H.picks))

x=F.reset({power=80,maxPower=200,wand=false,defaultCost=50,channel={id=5143,start=100,finish=105}})
F.event("UNIT_SPELLCAST_CHANNEL_START","player","channel-A",5143)
local _,channelContext=F.evaluate()
record("Channel cost is already paid","Channel snapshots do not reserve mana again",channelContext.futurePower==80,tostring(channelContext.futurePower))
x.time=101; x.targetHealth=140; x.distance=15
F.event("UNIT_SPELLCAST_CHANNEL_STOP","player","channel-A",5143,"Player-A")
record("Channel stop before API clear","Ended channel releases the previous Main",F.main(H.picks)=="fireblast",F.describe(H.picks))

x=F.reset({level=25,talents=F.build(2,25),grouped=true,classification="elite",cast={id=2948,start=100,finish=101.5},targetAuras={{spellId=22959,applications=4,expirationTime=125}}})
assert(x.talents.improvedScorch==1,"Partial Scorch scenario needs exactly one talent rank")
p=F.evaluate()
record("Partial Improved Scorch talent","Do not assume the next Scorch guarantees stack five",F.main(p)=="scorch",F.describe(p),"medium")
for _,rank in ipairs({1,2,3}) do
    for _,stacks in ipairs({4,5}) do
        x=F.reset({level=24+rank,talents=F.build(2,24+rank),grouped=true,classification="elite",cast={id=2948,start=100,finish=101.5},
            targetAuras={{spellId=22959,applications=stacks,expirationTime=103}}})
        assert(x.talents.improvedScorch==rank,"Scorch fixture must have the specified legal rank")
        p=F.evaluate()
        local expected=rank==3 and "fireball" or "scorch"
        record("Scorch refresh at rank "..rank.." with "..stacks.." stacks","Main "..expected,F.main(p)==expected,F.describe(p))
    end
end

x=F.reset({defaultCost=50,power=50,wand=false,cast={id=116,start=100,finish=103}})
F.evaluate(); x.power=500; x.time=101.5; p=F.evaluate()
record("Mana restored during an initially unaffordable cast","Fill an empty next-action plan after mana recovery",F.main(p)~=nil,F.describe(p),"medium")
x.targetHealth=140; x.distance=15; x.time=102.9; p=F.evaluate()
record("Recovered plan commits once populated","Late finisher cannot replace newly committed Frostbolt",F.main(p)=="frostbolt",F.describe(p))
x.power=50; p=F.evaluate()
record("Mana lost after a plan fills","Unaffordable committed spell is hidden",not F.main(p),F.describe(p))
x.power=500; p=F.evaluate()
record("Mana restored to an existing plan","The same committed Frostbolt returns",F.main(p)=="frostbolt",F.describe(p))

x=F.reset({actionSlots={[1]={"spell",133}}})
x.actionSlots[1][2]=H.definitions.fireball.id
local printMessage=TestAddon.Print; local notices={}
TestAddon.Print=function(_,message) notices[#notices+1]=message end
F.event("ACTIONBAR_SLOT_CHANGED")
TestAddon.Print=printMessage; p=H.picks
record("Preferred spell absent from action bars","Usable fallback or a visible missing-action notice",
    #notices==1 and notices[1]:find(H.SpellInfo(H.definitions.frostbolt.id),1,true),
    F.describe(p).."; only Fireball is on bar; chat: "..table.concat(notices," / "),"medium")

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
        local lead=pick.category=="main" and c.actionDelay or 0
        if seen[unique] or not spell.known or spell.enemy and spell.range~=true or spell.cooldown>lead then violations=violations+1 end
        seen[unique]=true
    end
    if mains>1 then violations=violations+1 end
    combinations=combinations+1
end end end end end end end end
record("Structural scenario matrix","No duplicate actions, multiple Mains, unknown spells, out-of-range enemy advice, or cooldown-gate violations",violations==0,
    combinations.." combinations; "..violations.." invariant violations; "..unavailableMain.." Main suggestions on cooldown")
return {cases=results,findings=findings,namedCount=count,matrixCount=combinations,matrixViolations=violations,cooldownMainCount=unavailableMain}
