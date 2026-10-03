-- Shared consumable preparation through the real adapter/selector on all classes.
local F=ScenarioFixture
local H=F.helper
local A=TestAddon
local D=A.Data.ConsumableBuffs
local results,findings={},{}
local function record(name,expected,pass,p)
    local row={name=name,expected=expected,passed=not not pass,actual=F.describe(p)}
    results[#results+1]=row
    if not pass then findings[#findings+1]=row end
end
local function setup(options,class,learned)
    options=options or {}; if options.combat==nil then options.combat=false end
    options.target=false
    local x=F.reset(options)
    if class then MOCK.class=class end
    for _,id in ipairs(learned or {}) do x.known[id]=true end
    H:Rebuild()
    return x
end
local function item(p,id) return F.find(p,"buffItem:"..id) end
local function scenario(name,options,expected,absent,class,learned)
    setup(options,class,learned)
    local p=F.evaluate()
    local pass=expected==nil or F.find(p,expected)~=nil
    for _,key in ipairs(absent or {}) do pass=pass and not F.find(p,key) end
    record(name,"Include "..(expected or "none required").."; exclude "..table.concat(absent or {},","),pass,p)
end

scenario("Carried Greater Intellect wins over level-40 Intellect",{inventory={[9179]=2}},"buffItem:9179",{"intellect"})
scenario("Learned highest Intellect wins over carried elixir",{level=60,inventory={[9179]=2}},"intellect",{"buffItem:9179"})
scenario("Active Greater Intellect suppresses weaker Mage spell",{playerAuras={{spellId=11396,expirationTime=1000}}},nil,{"intellect"})
scenario("Expiring stronger elixir still cannot be downgraded",{playerAuras={{spellId=11396,expirationTime=101}}},nil,{"intellect"})
scenario("Expiring stronger elixir highlights its own refill",{inventory={[9179]=2},playerAuras={{spellId=11396,expirationTime=400}}},"buffItem:9179",{"intellect"})
scenario("Healthy active elixir does not waste another dose",{inventory={[9179]=2},playerAuras={{spellId=11396,expirationTime=401}}},nil,{"intellect","buffItem:9179"})
scenario("Weaker Wisdom is upgraded without waiting for expiry",{level=14,playerAuras={{spellId=3166,expirationTime=1000}}},"intellect")
scenario("Wisdom aura blocks rank-one Intellect",{level=10,playerAuras={{spellId=3166,expirationTime=400}}},nil,{"intellect"})
scenario("Agility aura cannot be mistaken for Intellect",{playerAuras={{spellId=3160,expirationTime=400}}},"intellect")
scenario("Arcane Elixir cannot be mistaken for Intellect",{playerAuras={{spellId=11390,expirationTime=400}}},"intellect")
scenario("Sages actual 18 Intellect blocks the 15-point spell",{playerAuras={{spellId=17535,expirationTime=400}}},nil,{"intellect"})
scenario("Received Arcane Brilliance suppresses consumable Intellect",{inventory={[9179]=2},playerAuras={{spellId=23028,expirationTime=400}}},nil,{"buffItem:9179"},"HUNTER")
scenario("Expired stronger buff releases the weaker available option",{level=10,playerAuras={{spellId=3166,expirationTime=99}}},"intellect")
scenario("Unknown aura duration does not prompt a replacement",{inventory={[9179]=2},playerAuras={{spellId=11396}}},nil,{"intellect","buffItem:9179"})
scenario("Stronger unavailable-level elixir is not advertised",{level=20,inventory={[9179]=2}},"intellect",{"buffItem:9179"})
scenario("Cooldown waits for the strongest source without consuming a weaker one",{inventory={[9179]=2,[3383]=2},itemCooldown=3},nil,{"intellect","buffItem:9179","buffItem:3383"})
scenario("Disabled item cooldown prevents a marker",{inventory={[9179]=2},itemEnabled=false},nil,{"buffItem:9179"})
scenario("No routine buff consumption during combat",{combat=true,inventory={[9179]=2,[8951]=2,[21217]=2}},nil,{"intellect","buffItem:9179","buffItem:8951","buffItem:21217"})
scenario("Health elixir stacks independently with Fortitude",{level=60,inventory={[3825]=2,[10307]=2}},"buffItem:3825",{"buffItem:10307"},"PRIEST",{10938})
scenario("Priest learned Fortitude beats carried stamina scroll",{level=60,inventory={[10307]=2}},"fortitude",{"buffItem:10307"},"PRIEST",{10938})
scenario("Equal-strength free Fortitude beats a scroll",{level=20,inventory={[1711]=2}},"fortitude",{"buffItem:1711"},"PRIEST",{1244})
scenario("Priest Divine Spirit beats a spirit scroll",{level=60,inventory={[10306]=2}},"divineSpirit",{"buffItem:10306"},"PRIEST",{27841})
scenario("Received Prayer of Spirit suppresses a weaker scroll",{level=60,inventory={[10306]=2},playerAuras={{spellId=27681,expirationTime=400}}},nil,{"buffItem:10306"},"PALADIN")
scenario("Received Fortitude suppresses stamina scroll on Warrior",{level=60,inventory={[10307]=2},playerAuras={{spellId=10938,expirationTime=400}}},nil,{"buffItem:10307"},"WARRIOR")
scenario("Stronger talent-modified active value is preserved",{level=20,inventory={[1711]=2},playerAuras={{spellId=1244,expirationTime=400,points={10}}}},nil,{"buffItem:1711","fortitude"},"PRIEST",{1244})
scenario("Stronger Agility scroll wins over weaker elixir",{level=30,inventory={[1477]=2,[3390]=2}},"buffItem:1477",{"buffItem:3390"},"ROGUE")
scenario("Stronger Agility elixir wins over scroll",{level=40,inventory={[4425]=2,[9187]=2}},"buffItem:9187",{"buffItem:4425"},"ROGUE")
scenario("Mongoose is not replaced by equal Agility without its crit",{level=60,inventory={[9187]=2},playerAuras={{spellId=17538,expirationTime=200}}},nil,{"buffItem:9187"},"ROGUE")
scenario("Defense elixir and armor scroll choose one strongest source",{inventory={[8951]=2,[4421]=2}},"buffItem:8951",{"buffItem:4421"})
scenario("Mage physical armor does not conflict with armor elixirs",{inventory={[8951]=2},playerAuras={{spellId=7302,expirationTime=1000}}},"buffItem:8951")
scenario("Rogue receives no Intellect consumable marker",{inventory={[9179]=2,[4419]=2}},nil,{"buffItem:9179","buffItem:4419"},"ROGUE")
scenario("Mage receives no Agility consumable marker",{inventory={[9187]=2}},nil,{"buffItem:9187"})
scenario("Buff food is suggested even at full health and mana",{inventory={[21217]=2}},"buffItem:21217")
scenario("Caster food preference selects carried mana food",{inventory={[21217]=2,[17222]=2}},"buffItem:21217",{"buffItem:17222"})
scenario("Rogue food preference selects stat food",{inventory={[21217]=2,[17222]=2}},"buffItem:17222",{"buffItem:21217"},"ROGUE")
scenario("Healthy Well Fed prevents another meal",{inventory={[21217]=2},playerAuras={{spellId=25941,expirationTime=401}}},nil,{"buffItem:21217"})
scenario("Well Fed refresh starts at five minutes",{inventory={[21217]=2},playerAuras={{spellId=25941,expirationTime=400}}},"buffItem:21217")
scenario("Stronger mana food prevents a downgrade near expiry",{inventory={[21217]=2},playerAuras={{spellId=18194,expirationTime=150}}},nil,{"buffItem:21217"})
scenario("Higher stat food suppresses a weaker meal",{inventory={[17222]=2},playerAuras={{spellId=25661,expirationTime=400}}},nil,{"buffItem:17222"},"WARRIOR")
scenario("Buff meal takes precedence over a second recovery meal",{health=300,inventory={[21217]=2,[117]=5}},"buffItem:21217",{"food"})
scenario("Brain Food eating aura suppresses all preparation",{inventory={[21217]=2,[9179]=2,[159]=3},power=300,playerAuras={{spellId=25691,expirationTime=120}}},nil,{"buffItem:21217","buffItem:9179","water","intellect"})
scenario("Recovery potions are not routine buff markers",{inventory={[1710]=2}},nil,{"buffItem:1710"})

local x=setup({inventory={[9179]=2}})
F.event("UNIT_SPELLCAST_SUCCEEDED","player","consume-intellect",11396)
record("Successful use hides the marker before aura propagation","No repeat dose or weaker spell",not item(H.picks,9179) and not F.find(H.picks,"intellect"),H.picks)
x.inventory[9179]=nil; x.playerAuras={{spellId=11396,expirationTime=3700}}
F.event("BAG_UPDATE_DELAYED")
record("Consumed last dose is removed without prompting a weaker buff","No Intellect downgrade",not item(H.picks,9179) and not F.find(H.picks,"intellect"),H.picks)
x.playerAuras={}; x.time=102; H:Tick()
record("No carried refill falls back once the stronger buff is gone","Learned Intellect",F.find(H.picks,"intellect")~=nil,H.picks)

x=setup({level=36,inventory={[9179]=2}})
local before=F.evaluate()
x.level=37
local unlocked=F.evaluate()
record("Level-up unlocks an already carried elixir without a bag event","Greater Intellect appears only at its use level",
    not item(before,9179) and item(unlocked,9179)~=nil,unlocked)
local read=A.Inventory.Read
x=setup({inventory={[9179]=2}})
A.Inventory.Read=function() return {available=false,counts={}} end
local unknown=F.evaluate()
A.Inventory.Read=read
local recovered=F.evaluate()
record("Temporary inventory failure is retried instead of caching empty bags","No unverified item, then recover the carried elixir",
    not item(unknown,9179) and item(recovered,9179)~=nil,recovered)

-- Run actual item/macro matching and native-loop application, not just picks.
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local frame=create(kind,name,parent,template)
    function frame:GetSize() return self:GetWidth(),self:GetHeight() end
    if template=="ActionButtonSpellAlertTemplate" then
        local loop={playing=false}
        function loop:Play() self.playing=true end
        function loop:Stop() self.playing=false end
        function loop:IsPlaying() return self.playing end
        frame.ProcLoop=loop; frame.ProcStartFlipbook=frame:CreateTexture(); frame.ProcLoopFlipbook=frame:CreateTexture()
    end
    return frame
end
x=setup({inventory={[9179]=2}})
x.actionSlots[1]={"item",9179}
x.actionSlots[2]={"macro",91}
x.actionSlots[3]={"spell",H.definitions.intellect.id}
local getMacroItem=GetMacroItem
GetMacroItem=function(id) if id==91 then return "Elixir of Greater Intellect","item:9179" end end
local buttons={}
for slot=1,3 do
    local button=CreateFrame("Button",nil,UIParent)
    button.action=slot; button:SetSize(36,36); button:Show()
    H.Glow:Register(button); buttons[slot]=button
end
local p=F.evaluate(); H.Glow:Apply(p)
local direct=H.Glow.seen[buttons[1]]
local macro=H.Glow.seen[buttons[2]]
local spell=H.Glow.seen[buttons[3]]
record("Chosen consumable gets the actual native item glow","Direct item and macro glow; conflicting spell stays dark",
    direct.glow:IsShown() and direct.glow.ProcLoop:IsPlaying() and macro.glow:IsShown() and not spell.glow:IsShown(),p)
x.playerAuras={{spellId=11396,expirationTime=3700}}
F.event("UNIT_AURA","player")
record("Aura event immediately clears both item and macro markers","Both consumable glows stop; weaker spell stays dark",
    not direct.glow:IsShown() and not macro.glow:IsShown() and not spell.glow:IsShown(),H.picks)
CreateFrame=create; GetMacroItem=getMacroItem

local full={}
for id in pairs(D.items) do full[id]=2 end
local violations=0
for _,class in ipairs({"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","SHAMAN","MAGE","WARLOCK","DRUID"}) do
    local pass=true
    for level=1,60 do
        setup({level=level,inventory=full},class)
        local p,c=F.evaluate()
        local groups={}
        for _,pick in ipairs(p) do
            local meta=pick.kind=="item" and D.items[pick.id] or D.auras[pick.id]
            if meta and meta.group then
                if groups[meta.group] then violations=violations+1; pass=false end
                groups[meta.group]=true
            end
            if class~="MAGE" and pick.category~="preparation" then violations=violations+1; pass=false end
        end
    end
    local accessible=false
    for _,tab in ipairs(A.Companion.Tabs({characterClass=H.module.name})) do if tab=="Rotation Helper" then accessible=true end end
    local page=H:Document({})
    pass=pass and accessible and page.cards[1].headerAction~=nil
        and (class=="MAGE" or page.cards[1].note:find("Buff preparation",1,true)~=nil)
    record(class.." has shared buffs without conflicts from level 1 to 60","One source per group; accessible enable page; only Mage has combat advice",pass,{})
end
return {cases=results,findings=findings,namedCount=#results,matrixCount=540,matrixViolations=violations}
