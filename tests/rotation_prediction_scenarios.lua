-- Check WHEN the forecast appears, before resource/aura thresholds are crossed.
local F=ScenarioFixture
local H=F.helper
local results,findings={},{}
local fire=F.build(2,40)
local function record(name,expected,pass,picks)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(picks)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function scenario(name,options,main,include,exclude)
    F.reset(options)
    local p,c=F.evaluate()
    local pass=F.main(p)==main
    if include then pass=pass and F.find(p,include)~=nil end
    if exclude then pass=pass and F.find(p,exclude)==nil end
    record(name,"Main "..(main or "none")..(include and "; include "..include or "")..(exclude and "; exclude "..exclude or ""),pass,p)
    return p,c
end

scenario("Plan wand at START before mana falls below threshold",{
    power=220,costs={frostbolt=100},cast={id=116,start=100,finish=103}},"shoot")
scenario("Do not plan an expensive finisher using pre-cast mana",{
    power=290,targetHealth=140,distance=15,costs={frostbolt=100},cast={id=116,start=100,finish=103}},"frostbolt")
scenario("Plan spell when confirmed regeneration covers conservation threshold",{
    power=140,regen=20,cast={id=116,start=100,finish=103}},"frostbolt")
scenario("Mana gem appears at START before the mana threshold",{
    power=480,costs={frostbolt=100},inventory={[5514]=1},cast={id=116,start=100,finish=103}},"frostbolt","gem")
scenario("Forecast cannot recommend a cooling-down mana gem",{
    power=480,costs={frostbolt=100},inventory={[5514]=1},itemCooldown=120,cast={id=116,start=100,finish=103}},"frostbolt",nil,"gem")
scenario("Idle mana gem threshold remains unchanged",{power=480,inventory={[5514]=1}},"frostbolt",nil,"gem")
scenario("Mana Shield keeps live emergency resources",{
    power=400,health=300,attacked=true,costs={frostbolt=200},cast={id=116,start=100,finish=103}},"frostbolt","manashield")
scenario("Scorch refresh is planned before the current cast completes",{
    talents=fire,grouped=true,classification="elite",cast={id=133,start=100,finish=103},
    targetAuras={{spellId=22959,applications=5,expirationTime=107}}},"scorch")
scenario("Scorch refresh anticipates the remaining GCD too",{
    talents=fire,grouped=true,classification="elite",gcd=1.5,
    targetAuras={{spellId=22959,applications=5,expirationTime=106}}},"scorch")
scenario("Healthy Scorch duration does not trigger a premature refresh",{
    talents=fire,grouped=true,classification="elite",cast={id=133,start=100,finish=103},
    targetAuras={{spellId=22959,applications=5,expirationTime=120}}},"fireball")
scenario("A Scorch already being cast supplies its own guaranteed refresh",{
    talents=fire,grouped=true,classification="elite",cast={id=2948,start=100,finish=101.5},
    targetAuras={{spellId=22959,applications=5,expirationTime=103}}},"fireball")
scenario("Plan slow refresh with a buffer after the cast ends",{
    talents=fire,cast={id=133,start=100,finish=103},targetAuras={{spellId=116,expirationTime=105}}},"frostbolt")
scenario("A slow that lasts through the following action permits Fireball",{
    talents=fire,cast={id=133,start=100,finish=103},targetAuras={{spellId=116,expirationTime=110}}},"fireball")
scenario("Already-paid channel mana is not reserved twice",{
    power=180,costs={missiles=100},channel={id=5143,start=100,finish=105}},"frostbolt")

local x=F.reset({power=220,costs={frostbolt=100},cast={id=116,start=100,finish=103}})
local p=F.evaluate()
x.time=102.9; x.power=700; p=F.evaluate()
record("Early prediction cannot switch in the queue window","Keep the advertised wand despite later mana changes",F.main(p)=="shoot",p)
x.time=103.4; x.cast=nil; p=F.evaluate()
record("Early prediction also survives cast completion","Keep the advertised wand",F.main(p)=="shoot",p)

-- Inspect the value sent to Glow:Apply inside START, before another poll runs.
local apply=H.Glow.Apply
local applied
H.Glow.Apply=function(self,picks) applied=F.main(picks); return apply(self,picks) end
x=F.reset({talents=fire})
F.event("UNIT_SPELLCAST_START","player","early-prediction",116)
record("START publishes the next glow before UnitCastingInfo appears","Fireball sent to Glow:Apply inside START",applied=="fireball" and H.state.token=="cast:early-prediction",H.picks)
x.time=100.05; x.cast={id=116,token=51,start=100,finish=102.5}
F.helper:Tick()
record("Authoritative casting data keeps the early plan","Same Fireball and START identity",applied=="fireball" and H.state.token=="cast:early-prediction",H.picks)
x.time=102.4; x.targetHealth=140; x.distance=15
F.helper:Tick()
record("Late finisher conditions cannot overwrite early glow","Fireball remains Main",applied=="fireball",H.picks)
x.time=102.5; x.cast=nil
F.event("UNIT_SPELLCAST_SUCCEEDED","player","early-prediction",116)
record("Successful completion retains the event-start prediction","Fireball remains Main",applied=="fireball",H.picks)

x=F.reset({power=220,costs={frostbolt=100}})
F.event("UNIT_SPELLCAST_START","player","early-mana",116)
record("Deferred API still reserves mana during START","Wand sent to Glow:Apply immediately",applied=="shoot",H.picks)
F.event("UNIT_SPELLCAST_INTERRUPTED","player","early-mana",116)
record("Interrupted deferred cast releases reserved mana and plan","Frostbolt can be planned again",applied=="frostbolt",H.picks)
H.Glow.Apply=apply

return {cases=results,findings=findings,namedCount=#results}
