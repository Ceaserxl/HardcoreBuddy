-- 100 cast-identity cases: four API forms, five timing revisions and five
-- lifecycle outcomes. Combined with the existing suites, exactly 200 scenarios.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local modes={
    {name="API GUID",id=116,token="original-cast",event="UNIT_SPELLCAST_START"},
    {name="Numeric API ID plus START GUID",id=116,token=41,event="UNIT_SPELLCAST_START"},
    {name="Channel plus START GUID",id=5143,channel=true,event="UNIT_SPELLCAST_CHANNEL_START"},
    {name="No API ID plus START GUID",id=116,noID=true,event="UNIT_SPELLCAST_START"},
}
local changes={
    {name="finish delayed",start=0,finish=0.5},
    {name="half-second timing shift",start=0.5,finish=0.5},
    {name="one-second timing shift",start=1,finish=1},
    {name="timing shortened",start=-0.5,finish=-0.5},
    {name="repeated timing shifts",start=0.25,finish=0.25,repeats=2},
}
local outcomes={"committed", "paid", "interrupted", "unrelated failure", "new cast"}
local function castFor(mode,second,start,finish)
    local token=mode.token
    if second then token=type(token)=="number" and 42 or "next-cast" end
    return {id=mode.id,token=token,noID=mode.noID,start=start,finish=finish}
end
for _,mode in ipairs(modes) do
for _,change in ipairs(changes) do
for _,outcome in ipairs(outcomes) do
    local key=mode.channel and "channel" or "cast"
    local options={power=120,maxPower=200,wand=false,distance=15}
    options[key]=castFor(mode,false,100,103)
    local x=F.reset(options)
    F.event(mode.event,"player","original-cast",mode.id)
    local before=H.state.token
    local initial=F.main(H.picks)=="frostbolt"
    local stable=true
    local p,c
    for step=1,change.repeats or 1 do
        x.time=100.5+step*0.1
        x[key].start=x[key].start+change.start
        x[key].finish=x[key].finish+change.finish
        x.targetHealth=140
        p,c=F.evaluate()
        stable=stable and F.main(p)=="frostbolt" and H.state.token==before
            and c.cast and math.abs(c.cast.finish-x[key].finish)<0.0001
    end
    local pass=initial and stable
    local expected="Keep Main and cast identity, update observed cast timing"
    if outcome=="paid" then
        x.time=x[key].finish; x.power=70
        F.event("UNIT_SPELLCAST_SUCCEEDED","player","original-cast",mode.id)
        p,c=F.evaluate()
        expected="Success retains the plan and does not reserve paid mana again"
        pass=pass and F.main(p)=="frostbolt" and c.futurePower==70 and H.state.token==before
    elseif outcome=="interrupted" then
        F.event(mode.channel and "UNIT_SPELLCAST_CHANNEL_STOP" or "UNIT_SPELLCAST_INTERRUPTED","player","original-cast",mode.id,"Player-A")
        p,c=F.evaluate()
        expected="Matching end event releases the plan despite revised API timing"
        pass=pass and F.main(p)=="fireblast" and c.cast==nil
    elseif outcome=="unrelated failure" then
        F.event("UNIT_SPELLCAST_FAILED","player","extra-press",mode.id)
        p=H.picks
        expected="An unrelated cast GUID cannot release the revised cast"
        pass=pass and F.main(p)=="frostbolt" and H.state.token==before
    elseif outcome=="new cast" then
        -- Cover both sequential casts and a replacement START whose interval
        -- overlaps the old cast (for example, clipping a channel).
        x.time=x[key].finish+(change.start==0 and 0.1 or -0.2)
        x[key]=castFor(mode,true,x.time,x.time+3)
        F.event(mode.event,"player","next-cast",mode.id)
        p=H.picks
        expected="A real new START has a new identity and may select the finisher"
        pass=pass and F.main(p)=="fireblast" and H.state.token~=before
    end
    local row={name=mode.name.." / "..change.name.." / "..outcome,expected=expected,passed=not not pass,
        actual=F.describe(p).."; initial="..tostring(initial).."; stable during timing revision="..tostring(stable)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end end end
assert(#results==100,"Cast identity suite must execute exactly 100 combinations")
return {cases=results,findings=findings,namedCount=#results}
