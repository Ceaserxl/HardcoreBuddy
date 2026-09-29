-- Exercise the profession-event -> cached character context -> actual supply
-- row path. Professions.Read API compatibility is tested separately; this file
-- supplies deterministic snapshots to verify live UI and saved-setting behavior.
local A,f=TestAddon,TestAddon.window
local P=A.Professions
local function copy(value)
    if type(value)~="table" then return value end
    local out={}; for k,v in pairs(value) do out[k]=copy(v) end; return out
end
local function restore(target,saved)
    for k in pairs(target) do target[k]=nil end
    for k,v in pairs(saved) do target[k]=copy(v) end
end
local saved={reader=P.Read,reading=P.reading,professions=A.professions,inventory=A.inventory,bags=copy(MOCK.bags),
    db=copy(A.db),character=copy(A.characterDB),state=copy(A.state),history=copy(A.history),
    lastClass=A.lastClass,shown=f:IsShown(),scroll=f.scroll:GetVerticalScroll(),
    needsRefresh=A.needsRefresh,needsLayout=A.needsLayout,layoutElapsed=A.layoutElapsed}
local checks,reads=0,0
local function check(value,message) assert(value,message); checks=checks+1 end
local function snapshot(bandage,dummy)
    local out={available=true,skills={bandage=bandage,dummy=dummy},known={}}
    for _,recipes in pairs(P.recipes) do for _,recipe in ipairs(recipes) do out.known[recipe.spellId]=false end end
    return out
end
local current=snapshot(math.max(P.recipes.bandage[2].craftSkill,P.recipes.bandage[3].craftSkill),100)
P.Read=function() reads=reads+1; return copy(current) end
local function learn(family,index)
    local recipe=P.recipes[family][index]
    current.known[recipe.spellId]=true
    return recipe.itemId
end
local bandage1=learn("bandage",1)
local bandage2=learn("bandage",2)
local dummy1=learn("dummy",1)
local anti1=learn("antivenom",1)
local anti2=P.recipes.antivenom[2].itemId
local anti3=P.recipes.antivenom[3].itemId
local function fire(event)
    local before=reads
    MOCK.Fire(event)
    check(reads>before,event.." did not refresh the profession snapshot")
end
local function find(predicate)
    while A.document.page>1 do MOCK.Click(f.previous) end
    for page=1,A.document.pages do
        for _,row in ipairs(f.cards[1].content.blocks) do
            if row:IsShown() and predicate(row.block) then return row end
        end
        if page<A.document.pages then MOCK.Click(f.nextPage) end
    end
end
local function familyRow(family)
    return find(function(block)
        if block.action and block.action.kind=="supplyFamily" and block.action.family==family then return true end
        if block.rankFamily==family then return true end
        for _,recipe in ipairs(P.recipes[family]) do if recipe.itemId==block.itemId then return true end end
    end)
end
local function expect(family,itemId)
    local row=familyRow(family)
    check(row~=nil,"Missing automatic family row: "..family)
    local displayId=itemId or (family=="dummy" and row.block.groupSupply and 4366 or nil)
    check(row.block.itemId==displayId,"Wrong automatic "..family.." recommendation")
    check(not row.choose:IsShown(),"Automatic recommendation offers manual Use")
    if itemId then check(row.quantity:IsShown(),"Current automatic recommendation cannot edit Carry")
    else check(not row.quantity:IsShown(),"Unknown/unlearned profession has an editable item target") end
    return row
end
local function supplies()
    MOCK.Click(f.tabs[1]); MOCK.Click(f.filters[5])
    check(A.state.filter=="Emergency")
end
local function modelBlock(stock,predicate)
    -- Stock filtering remains a model operation. Supplies no longer exposes a
    -- Missing control, so exercise the model without invoking hidden UI frames.
    local state=copy(A.state)
    state.stock,state.page,state.detail=stock,1,nil
    local document=A.Companion.Build(A:GetContext(),state)
    for page=1,document.pages do
        if page>1 then state.page=page; document=A.Companion.Build(A:GetContext(),state) end
        for _,card in ipairs(document.cards) do
            for _,block in ipairs(card.blocks) do if predicate(block) then return block end end
        end
    end
end
local function missingHidesUnavailableRanks()
    local previousStock=A.state.stock
    check(modelBlock("All",function(block) return block.autoRank end),"Unfiltered model lost unavailable automatic families")
    check(not modelBlock("Missing",function(block) return block.autoRank end),"Missing model filter includes an unknown or unlearned automatic rank")
    check(A.state.stock==previousStock,"Direct model filtering changed the live Supplies state")
end

f:Show(); A:SetProfile("mode","live"); supplies()
-- Old saved choices must not override detected skills or known recipes.
A.characterDB.ranks.bandage=bandage1
A.characterDB.ranks.dummy=P.recipes.dummy[3].itemId
A.characterDB.ranks.antivenom=anti3
MOCK.bags[0][3]=nil -- Replace the prior integration fixture's anti-venom stack.
MOCK.bags[0][4]={itemID=bandage1,stackCount=99}
MOCK.bags[0][5]={itemID=bandage2,stackCount=2}
MOCK.bags[0][6]={itemID=dummy1,stackCount=1}
MOCK.bags[0][7]={itemID=P.recipes.dummy[2].itemId,stackCount=7}
MOCK.bags[0][8]={itemID=anti1,stackCount=2}
MOCK.bags[0][9]={itemID=anti2,stackCount=4}
MOCK.bags[0][10]={itemID=anti3,stackCount=1}
MOCK.Fire("BAG_UPDATE_DELAYED")
fire("SKILL_LINES_CHANGED")
check(expect("bandage",bandage2).block.count==2,"Counts merged multiple bandage ranks")
check(expect("dummy",dummy1).block.count==1,"Counts merged multiple dummy ranks")
check(expect("antivenom",anti1).block.count==2,"Counts merged multiple anti-venom ranks or followed a saved pin")

-- A newly learned recipe updates without clicking or reopening the window.
local editing=expect("bandage",bandage2)
editing.quantity:SetFocus(); editing.quantity:SetText("11")
local bandage3=learn("bandage",3)
fire("SPELLS_CHANGED")
check(A.characterDB.targets[bandage2]==11,"Automatic upgrade lost the focused previous-rank Carry edit")
local upgraded=expect("bandage",bandage3)
check(not upgraded.quantity:HasFocus() and upgraded.quantity.targetKey==bandage3,"Automatic upgrade reused the previous-rank Carry input")
local dummy2=learn("dummy",2)
fire("SPELLS_CHANGED")
expect("dummy",dummy1) -- Known recipe alone cannot bypass Engineering rank.
current.skills.dummy=P.recipes.dummy[2].craftSkill
fire("SKILL_LINES_CHANGED")
check(expect("dummy",dummy2).block.count==7)
current.skills.bandage=P.recipes.bandage[6].craftSkill
local bandage6=learn("bandage",6)
fire("TRADE_SKILL_UPDATE")
expect("bandage",bandage6)
expect("antivenom",anti1) -- First Aid180 without the Strong book retains basic.
learn("antivenom",2)
fire("SPELLS_CHANGED")
check(expect("antivenom",anti2).block.count==4,"Learning Strong did not switch to its own bag count")

-- Preview changes class/level only; professions remain the current character's.
A:SetProfile("mode","preview"); A:SetProfile("characterClass","Mage"); A:SetLevel(1); supplies()
expect("bandage",bandage6); expect("dummy",dummy2)
expect("antivenom",anti2)
check(A:GetContext().professions.skills.bandage==current.skills.bandage)
A:SetLevel(60)
expect("bandage",bandage6); expect("dummy",dummy2)
expect("antivenom",anti2)
local dummy3=learn("dummy",3)
current.skills.dummy=P.recipes.dummy[3].craftSkill
fire("TRADE_SKILL_UPDATE")
expect("dummy",dummy3)

-- Changing Carry or invoking a legacy selection cannot select an inferior rank.
local row=expect("bandage",bandage6)
row.quantity:SetFocus(); row.quantity:SetText("17"); row.quantity.scripts.OnEnterPressed(row.quantity)
check(A.characterDB.targets[bandage6]==17)
expect("bandage",bandage6)
A:SetCarryTarget(bandage1,99)
A:SetCarryTarget(anti1,99)
A:SelectSupplyRank("bandage",bandage1)
A:SelectSupplyRank("dummy",dummy1)
A:SelectSupplyRank("antivenom",anti1)
A:Refresh()
expect("bandage",bandage6); expect("dummy",dummy3)
expect("antivenom",anti2)
check(A.characterDB.ranks.bandage==bandage1,"Carry unexpectedly rewrote the legacy bandage selection")
check(A.characterDB.ranks.antivenom==anti3,"Carry or legacy selection rewrote the anti-venom pin")
row=expect("antivenom",anti2)
row.quantity:SetFocus(); row.quantity:SetText("7"); row.quantity.scripts.OnEnterPressed(row.quantity)
check(A.characterDB.targets[anti2]==7 and expect("antivenom",anti2).block.missing==3)
local missingAnti=modelBlock("Missing",function(block) return block.itemId==anti2 end)
check(missingAnti~=nil,"Missing model filter omitted the selected anti-venom")
check(missingAnti.itemId==anti2,"Missing model filter selected the wrong anti-venom rank")
check(missingAnti.autoRank,"Missing model filter lost automatic rank metadata")
check(missingAnti.targetKey==anti2 and missingAnti.target==7,"Missing model filter lost the exact-item Carry target")
check(missingAnti.count==4 and missingAnti.missing==3,"Missing model filter changed the exact-item bag count")

-- Other anti-venom ranks remain reference-only; opening their item details
-- cannot reinstate a Carry editor or override the automatically selected rank.
row=expect("antivenom",anti2); MOCK.Click(row)
local antiLower=find(function(block) return block.itemId==anti1 end)
check(antiLower and antiLower.block.readOnlyTarget and not antiLower.quantity:IsShown() and not antiLower.choose:IsShown())
local antiSelected=find(function(block) return block.itemId==anti2 end)
check(antiSelected and antiSelected.quantity:IsShown() and not antiSelected.block.readOnlyTarget)
MOCK.Click(antiLower)
check(f.cards[1].content.blocks[1].block.itemId==anti1 and not f.cards[1].content.blocks[1].quantity:IsShown())
MOCK.Click(f.back); MOCK.Click(f.back)
expect("antivenom",anti2)

-- Rank reference pages remain browsable, with only the current rank editable.
row=expect("bandage",bandage6); MOCK.Click(row)
check(A.document.isDetail)
local lower=find(function(block) return block.itemId==bandage1 end)
check(lower and lower.block.readOnlyTarget and not lower.quantity:IsShown() and not lower.choose:IsShown(),"Reference-only lower rank is manually selectable")
local selected=find(function(block) return block.itemId==bandage6 end)
check(selected and not selected.block.readOnlyTarget and selected.quantity:IsShown() and not selected.choose:IsShown())
MOCK.Click(lower); check(A.document.isDetail)
check(f.cards[1].content.blocks[1].block.itemId==bandage1)
check(not f.cards[1].content.blocks[1].quantity:IsShown(),"Opening a lower-rank item detail restores editable Carry")
MOCK.Click(f.back); MOCK.Click(f.back)
expect("bandage",bandage6)

-- A skill upgrade can also make the currently open exact-item detail readonly
-- without changing its itemID. Commit its edit to that item before hiding it.
row=expect("bandage",bandage6); MOCK.Click(row)
selected=find(function(block) return block.itemId==bandage6 end); MOCK.Click(selected)
local exact=f.cards[1].content.blocks[1]
check(exact.block.itemId==bandage6 and exact.quantity:IsShown())
exact.quantity:SetFocus(); exact.quantity:SetText("19")
current.skills.bandage=300
local highest=learn("bandage",#P.recipes.bandage)
local higherTarget=A.characterDB.targets[highest]
fire("SKILL_LINES_CHANGED")
check(exact.block.itemId==bandage6 and exact.block.readOnlyTarget and not exact.quantity:IsShown() and not exact.quantity:HasFocus())
check(A.characterDB.targets[bandage6]==19 and A.characterDB.targets[highest]==higherTarget,"Readonly detail transition assigned Carry to the upgraded rank")
MOCK.Click(f.back); MOCK.Click(f.back)
expect("bandage",highest)
expect("antivenom",anti2) -- First Aid300 without Powerful's book still uses Strong.
learn("antivenom",3)
fire("SPELLS_CHANGED")
check(expect("antivenom",anti3).block.count==1,"Learning Powerful did not immediately update the exact item")
check(A:GetContext().professions.skills.antivenom==nil,"Anti-venom invented a separate profession skill")

-- No profession, an unavailable API, and unknown recipe knowledge never fall
-- back to a saved manual rank or claim a usable best item.
current=snapshot(0,0)
fire("SKILL_LINES_CHANGED")
expect("bandage",nil); expect("dummy",nil)
expect("antivenom",nil)
missingHidesUnavailableRanks()
current=snapshot(nil,nil)
fire("SKILL_LINES_CHANGED")
expect("bandage",nil); expect("dummy",nil)
expect("antivenom",nil)
current={available=false,skills={},known={}}
fire("PLAYER_ENTERING_WORLD")
expect("bandage",nil); expect("dummy",nil)
expect("antivenom",nil)
missingHidesUnavailableRanks()
current={available=true,skills={bandage=300,dummy=300},known={}}
fire("SPELLS_CHANGED")
expect("bandage",nil); expect("dummy",nil)
expect("antivenom",nil)
current=snapshot(300,300)
learn("bandage",#P.recipes.bandage); learn("dummy",#P.recipes.dummy)
learn("antivenom",#P.recipes.antivenom)
-- Hidden-window events still refresh the cache used at the next opening.
f:Hide(); fire("SKILL_LINES_CHANGED"); f:Show()
expect("bandage",P.recipes.bandage[#P.recipes.bandage].itemId)
expect("dummy",P.recipes.dummy[#P.recipes.dummy].itemId)
expect("antivenom",anti3)

-- A skill-header scan can itself emit SKILL_LINES_CHANGED. The event handler
-- must leave an in-progress reader alone rather than recursively re-enter it.
local before=reads
P.reading=true; MOCK.Fire("SKILL_LINES_CHANGED"); P.reading=saved.reading
check(reads==before,"Skill-line event recursively re-entered the profession reader")

A:CommitInputs(); P.Read=saved.reader
MOCK.bags=copy(saved.bags); A.inventory=saved.inventory; A.professions=saved.professions
restore(A.db,saved.db); restore(A.characterDB,saved.character)
A.state,A.history,A.lastClass=copy(saved.state),copy(saved.history),saved.lastClass
A:RestoreWindow(); A:Refresh(); f.scroll:SetVerticalScroll(saved.scroll); f:SetShown(saved.shown)
A.needsRefresh,A.needsLayout,A.layoutElapsed=saved.needsRefresh,saved.needsLayout,saved.layoutElapsed
print(string.format("PASS: %d automatic profession UI/event assertions: bandages, dummies and anti-venom follow skill/recipe updates; missing-book fallback, exact-item bag counts, live professions in Preview, legacy pins ignored, Carry independence, read-only references, unknown/unlearned states and hidden-window refresh.",checks))
