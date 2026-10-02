"""Health-based ranks, learned recipe fallback, expanded ranks and coin costs."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local recipes=A.Professions.recipes.bandage
local context=A:GetContext()
context.professions={available=true,skills={bandage=300,dummy=0},known={}}
for _,r in ipairs(recipes) do
    context.professions.known[r.spellId]=true
    local found
    for _,item in ipairs(A.Data.Items.items) do if item.itemId==r.itemId then found=item end end
    assert(found and tonumber(found.detail:match("Heals (%d+)"))==r.healing,"Healing matches bundled item effect")
end
local state={view="supplies",detail={kind="supplyFamily",family="bandage"}}
local function doc() return A.Companion.Build(context,state) end
local function ids(d)
    local ids={}; local count=0
    for _,c in ipairs(d.cards) do for _,b in ipairs(c.blocks) do if b.supply then
        assert(not ids[b.itemId],"No duplicate bandage rows")
        ids[b.itemId]=b; count=count+1
    end end end
    return ids,count
end
context.maxHealth=640
local d=doc(); local rows,count=ids(d)
assert(count==2 and rows[6451] and rows[14530])
assert(d.cards[1].itemLayout and d.cards[1].quantityRecord, "Standard supply details layout and controls")
assert(d.cards[1].itemSectionTitle=="Highest Rank Available")
assert(rows[6451].rightColumn and not rows[14530].rightColumn,"Other ranks right, selected bandage left")
for _,c in ipairs(d.cards) do assert(c.title~="Bandages","No redundant Bandages heading") end
assert(not rows[6451].readOnlyTarget and rows[6451].editTarget,"Recommended lower rank remains editable")
context.maxHealth=641; assert(ids(doc())[8544],"Next healing tier after boundary")
context.maxHealth=2000; d=doc(); rows,count=ids(d)
assert(count==1 and rows[14530] and #d.cards==1,"Same rank hides Highest section")
context.maxHealth=4000; assert(select(2,ids(doc()))==1,"Health above all ranks uses strongest")
context.maxHealth=700
for i=5,#recipes do context.professions.known[recipes[i].spellId]=false end
d=doc(); rows,count=ids(d)
assert(count==2 and rows[3531] and rows[8544],"Uncraftable recommendation is a real item row")
assert(rows[8544].body:find("cannot make it yet",1,true) and rows[8544].action.kind=="item","Requirement subtext and clickable details")
context.professions.skills.bandage=80
assert(ids(doc())[3530],"Crafting skill gates known recipes")
state.showAllBandages=true
assert(select(2,ids(doc()))==10,"Show all includes every remaining rank once")
state.showAllBandages=nil; context.maxHealth=nil
assert(ids(doc())[3530],"Unknown health uses actual craftable rank")
assert(doc().cards[1].itemLayout,"Unknown health retains standard item layout")
context.professions.skills.bandage=0
assert(select(2,ids(doc()))==0,"Unlearned profession never claims a craftable rank")
context.maxHealth=640; context.professions.skills.bandage=300
for _,r in ipairs(recipes) do context.professions.known[r.spellId]=true end
A.GetContext=function() return context end
A.state=state; A:Refresh(true)
local original=A.state
A:Activate({kind="bandageRanks"})
assert(state.showAllBandages and select(2,ids(A.document))==10)
for _,c in ipairs(A.document.cards) do assert(c.title~="First Aid training","Completed First Aid has no empty training heading") end
A:Activate({kind="bandageRanks"})
assert(not state.showAllBandages and select(2,ids(A.document))==2 and A.state==original)
local target
for _,b in ipairs(A.window.cards[1].content.blocks) do if b.block and b.block.itemId==6451 then target=b end end
assert(target); MOCK.Click(target)
assert(A.document.isDetail and A.window.cards[1].detailQuantity.quantity:IsShown(),"Recommended lower rank opens editable details")
A:Back(); assert(A.state==original)

local saved=A.Data.ClassSpells.Mage
A.Data.ClassSpells.Mage={[2]={{id=100,cost=12345},{id=101,cost=0}}}
GetSpellInfo=function(id) return "Spell "..id,nil,135846 end
GetCoinTextureString=nil
local costs=A.ClassSpells.Build({characterClass="Mage",level=1},{}).cards[1].blocks
assert(costs[1].body:find("UI-GoldIcon",1,true) and costs[1].body:find("UI-SilverIcon",1,true) and costs[1].body:find("UI-CopperIcon",1,true))
assert(costs[2].body=="Listed cost: Free")
GetCoinTextureString=function(amount,size) assert(amount==12345 and size==12); return "native coins" end
assert(A.ClassSpells.Build({characterClass="Mage",level=1},{}).cards[1].blocks[1].body=="Listed cost: native coins")
A.Data.ClassSpells.Mage=saved
print("PASS: Full-health boundaries, craft/recipe gates, fallback, duplicate suppression, all ranks, editable recommendations and trainer coin formatting.")
''')
