-- Reproduce late switches using completion gaps and real event handlers.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local function record(name,expected,pass,p)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(p)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function begin(options)
    local x=F.reset(options or {cast={id=116,start=100,finish=103},distance=15})
    local p=F.evaluate()
    assert(F.main(p)=="frostbolt","Begin with an advertised Frostbolt")
    return x
end

for _,delay in ipairs({0,0.1,0.25,0.3,0.5,1,3}) do
    local x=begin()
    x.time=103+delay; x.cast=nil; x.targetHealth=140
    local p=F.evaluate()
    record("Completion gap "..delay.." seconds","Keep advertised Frostbolt until the next action starts",F.main(p)=="frostbolt",p)
    x.cast={id=116,token="new-cast",start=x.time,finish=x.time+3}
    F.event("UNIT_SPELLCAST_START","player","new-cast",116)
    record("Next START after gap "..delay,"Now plan Fire Blast for after the new cast",F.main(H.picks)=="fireblast",H.picks)
end

for _,event in ipairs({"SPELLS_CHANGED","PLAYER_TALENT_UPDATE","ACTIONBAR_SLOT_CHANGED","UPDATE_MACROS","PLAYER_REGEN_ENABLED"}) do
    for _,phase in ipairs({"late cast","after completion"}) do
        local x=begin()
        x.time=phase=="late cast" and 102.9 or 103.5
        if phase=="after completion" then x.cast=nil end
        x.targetHealth=140
        F.event(event)
        record(event.." during "..phase,"Keep the same Main across refresh events",F.main(H.picks)=="frostbolt",H.picks)
    end
end

local x=begin()
x.time=102.9; x.cast=nil; x.targetHealth=140
local p=F.evaluate()
record("Casting API temporarily disappears before completion","Keep Frostbolt",F.main(p)=="frostbolt",p)
x.time=103.4; p=F.evaluate()
record("API gap outlasts the former quarter-second timer","Keep Frostbolt",F.main(p)=="frostbolt",p)

x=begin(); x.cast.id=H.definitions.frostbolt.id; x.cast.token=41
F.evaluate(); x.cast=nil; x.time=103; x.targetHealth=140
F.event("UNIT_SPELLCAST_SUCCEEDED","player","guid-not-observed",H.definitions.frostbolt.id)
record("Completed hard cast is not mistaken for a consumed instant","Keep the next Frostbolt even without a START GUID",F.main(H.picks)=="frostbolt",H.picks)

x=begin({channel={id=5143,start=100,finish=105},distance=15})
F.event("UNIT_SPELLCAST_CHANNEL_START","player","channel-A",5143)
x.time=105; x.channel=nil; x.targetHealth=140
F.event("UNIT_SPELLCAST_CHANNEL_STOP","player","channel-A",5143)
record("Natural channel completion keeps the next spell","Keep Frostbolt",F.main(H.picks)=="frostbolt",H.picks)

x=begin({channel={id=5143,start=100,finish=105},distance=15})
F.event("UNIT_SPELLCAST_CHANNEL_START","player","channel-B",5143)
x.time=101; x.channel=nil; x.targetHealth=140
F.event("UNIT_SPELLCAST_CHANNEL_STOP","player","channel-B",5143,"Player-A")
record("An early channel cancellation permits a new decision","Main Fire Blast",F.main(H.picks)=="fireblast",H.picks)

x=begin(); x.time=103.5; x.cast=nil; x.targetHealth=140
F.event("UNIT_SPELLCAST_FAILED","player","failed-extra-press",116)
record("Failed extra press during the completion gap cannot release Main","Keep Frostbolt",F.main(H.picks)=="frostbolt",H.picks)

x=begin(); x.time=102.9; x.targetHealth=140
F.event("UNIT_SPELLCAST_INTERRUPTED","player","cast-A",116)
record("A matched interruption still permits a new decision","Main Fire Blast",F.main(H.picks)=="fireblast",H.picks)

x=begin(); x.time=104; x.cast=nil; x.targetGUID="Another-target"; x.targetHealth=140
p=F.evaluate()
record("Changing target still permits a new decision","Main Fire Blast",F.main(p)=="fireblast",p)

x=begin(); x.time=104; x.cast=nil; x.targetHealth=140; x.distance=50
p=F.evaluate()
record("Invalid range hides the held attack without a replacement","No Main",not F.main(p),p)
x.distance=15; p=F.evaluate()
record("Returning to range restores the same held spell","Main Frostbolt",F.main(p)=="frostbolt",p)

x=begin(); x.time=104; x.cast=nil; x.targetHealth=0; p=F.evaluate()
record("A dead target never retains a visible held attack","No Main",not F.main(p),p)

x=F.reset({targetHealth=140,distance=15,cast={id=116,start=100,finish=103}})
p=F.evaluate(); assert(F.main(p)=="fireblast")
x.cast=nil; x.time=104
F.event("UNIT_SPELLCAST_SUCCEEDED","player","instant-finish",H.definitions.fireblast.id)
record("Using the held instant consumes it even after a long handoff","Main Frostbolt",F.main(H.picks)=="frostbolt",H.picks)

x=F.reset({distance=15,power=120,maxPower=200,wand=false})
F.event("UNIT_SPELLCAST_START","player","deferred-start",116)
x.cast={id=116,token=41,start=100,finish=103}
p=F.evaluate()
local identity=H.state.token
x.time=102.9; x.cast.start=100.5; x.cast.finish=103.5; x.targetHealth=140
p=F.evaluate()
record("START before numeric API preserves identity through a late timing change","Main Frostbolt and START-event identity",F.main(p)=="frostbolt" and H.state.token==identity and identity=="cast:deferred-start",p)
x.time=103.5; x.power=70
F.event("UNIT_SPELLCAST_SUCCEEDED","player","deferred-start",116)
p=H.picks
record("Deferred START also matches the later success","Keep Frostbolt without reserving paid mana twice",F.main(p)=="frostbolt",p)

x=begin({channel={id=5143,start=100,finish=105},distance=15})
F.event("UNIT_SPELLCAST_CHANNEL_START","player","channel-C",5143)
x.time=105; x.targetHealth=140
F.event("UNIT_SPELLCAST_CHANNEL_STOP","player","channel-C",5143,"")
local _,context=F.evaluate()
record("Natural channel stop with stale API hides the ended channel, not its plan","Main Frostbolt; no active cast",F.main(H.picks)=="frostbolt" and not context.cast,H.picks)

for _,event in ipairs({"UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_INTERRUPTED"}) do
    x=F.reset({distance=15,power=120,maxPower=200,wand=false})
    F.event("UNIT_SPELLCAST_START","player","first-observed-at-end",116)
    x.cast={id=116,token=41,start=100,finish=103}
    x.time=103; x.power=70
    F.event(event,"player","first-observed-at-end",116)
    p,context=F.evaluate()
    local ended=event=="UNIT_SPELLCAST_SUCCEEDED" and context.cast and context.cast.paid or not context.cast
    record("Deferred identity first observed by "..event,"The event identity survives the following snapshot",ended and context.futurePower==70 and F.main(p)=="frostbolt",p)
end

return {cases=results,findings=findings,namedCount=#results}
