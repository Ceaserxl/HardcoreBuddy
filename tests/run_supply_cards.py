"""Supply stock labels and quantity editing through item details."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
A:Navigate("supplies")
A.state.filter="Food & Drink"; A:Refresh(true)
local function first() return A.window.cards[1].content.blocks[1] end
local function find(id)
    for _,card in ipairs(A.window.cards) do
        if card:IsShown() then for _,row in ipairs(card.content.blocks) do
            if row:IsShown() and row.block.itemId==id then return row end
        end end
    end
end
local row=first(); local id=row.block.itemId; local count=row.block.count
assert(not row.genericTitle and row:GetHeight()==56,"Supply rows are compact without a generic title")
for _,item in ipairs(A.Data.Items.items) do
    assert(A.Supplies.GenericTitle(item):match("^%a+$"),"Every generic title is one word")
end
assert(count>0 and row.stock:GetText()=="("..count.."/"..row.block.target..")")
assert(not row.quantity:IsShown() and not row.count:IsShown())
local _,py=row.priority:GetCenter(); local _,sy=row.stock:GetCenter()
assert(py>sy and row.stockTrack:IsShown(),"Classification is above stock and bar")
MOCK.Click(row)
row=first(); assert(A.document.isDetail and not row.quantity:IsShown())
local function editor() return A.window.cards[1].detailQuantity.quantity end
local edit=editor(); local x,y,w,h=edit:GetRect()
assert(MOCK.HitTest(x+w/2,y+h/2)==edit,"Editor is clickable")
edit:SetFocus(); edit:SetText("17"); edit.scripts.OnEnterPressed(edit)
assert(A.characterDB.targets[id]==17 and first().stock:GetText()=="("..count.."/17)")
edit=editor(); edit:SetFocus(); edit:SetText("90"); edit.scripts.OnEscapePressed(edit)
assert(A.characterDB.targets[id]==17,"Escape cancels")
edit=editor(); edit:SetFocus(); edit:SetText("19")
MOCK.Click(A.window.back)
assert(A.characterDB.targets[id]==19 and not find(id).quantity:IsShown(),"Back saves and hides editor")
local context=A:GetContext(); local original=A.GetContext
context.inventory={available=true,counts={}}
A.GetContext=function() return context end
A:Refresh()
assert(find(id).stock:GetText()=="(0/19)")
context.targets[id]=0; A:Refresh()
assert(find(id).stock:GetText()=="(0/0)","Zero owned shows quantity with zero target")
context.inventory.counts[id]=23; context.targets[id]=20; A:Refresh()
assert(find(id).stock:GetText()=="(23/20)" and find(id).stockFill:GetWidth()==60,"Surplus is shown, bar capped")
context.inventory.available=false; A:Refresh()
assert(find(id).stock:GetText()=="Unknown","Unavailable counts must not become Missing")
context.inventory.available=true
context.professions={available=true,skills={dummy=0,bandage=0},known={}}
A.state.filter="Emergency"; A:Refresh(true)
local dummy
for _,card in ipairs(A.window.cards) do if card:IsShown() then
    for _,r in ipairs(card.content.blocks) do
        if r:IsShown() and r.block.action and r.block.action.family=="dummy" then dummy=r end
    end
end end
assert(dummy and dummy.block.groupSupply and dummy.priority:GetText()=="Optional","Unlearned target dummies have classification")
-- Profession placeholders keep meaningful icons without pretending a recipe is learned.
for _,filter in ipairs({"Emergency","All"}) do
    for _,skills in ipairs({{bandage=0,dummy=0},{bandage=300,dummy=0},{}}) do
        context.professions={skills=skills,known={}}
        for _,family in ipairs({"bandage","antivenom"}) do
            for _,recipe in ipairs(A.Professions.recipes[family]) do context.professions.known[recipe.spellId]=false end
        end
        A.state.filter=filter; A:Refresh(true)
        local seen={}
        for _,card in ipairs(A.window.cards) do if card:IsShown() then
            for _,r in ipairs(card.content.blocks) do
                local b=r.block
                if r:IsShown() and b and b.groupSupply and b.action and (b.action.family=="bandage" or b.action.family=="antivenom") then
                    seen[b.action.family]=true
                    assert(b.icon and r.icon:IsShown() and r.icon.texture and not r.icon.texture:find("QuestionMark",1,true),"Unlearned profession family has a visible icon")
                    assert(not b.itemId and not b.body:find("Best learned recipe",1,true),"Icon does not claim a selected recipe")
                end
            end
        end end
        assert(seen.bandage and seen.antivenom,"Both profession families remain visible")
    end
end
context.professions={available=true,skills={dummy=0,bandage=0},known={}}
A.state.filter="Emergency"; A:Refresh(true)
local recipes=A.Professions.recipes.dummy
for _,recipe in ipairs(recipes) do context.professions.known[recipe.spellId]=false end
context.professions.skills.dummy=300; context.professions.known[recipes[1].spellId]=true
A:Refresh()
MOCK.Click(find(recipes[1].itemId))
local selected=find(recipes[1].itemId)
assert(not selected.quantity:IsShown(),"Rank list has no embedded editor")
MOCK.Click(selected)
editor():SetFocus(); editor():SetText("7")
context.professions.known[recipes[2].spellId]=true; A:Refresh()
assert(editor():HasFocus() and editor():GetText()=="7","All-item controls preserve an old rank's active edit")
editor():ClearFocus()
assert(A.characterDB.targets[recipes[1].itemId]==7,"Recipe upgrade saves the old item's focused target")
assert(A.window.cards[1].detailQuantity:IsShown(),"Old recipe retains controls like every supply item")
A:Back(); MOCK.Click(find(recipes[2].itemId))
assert(editor():IsVisible(),"Current recipe has a separate editor")
A.GetContext=original
A:Navigate("advisors")
for _,card in ipairs(A.window.cards) do if card:IsShown() then
    for _,r in ipairs(card.content.blocks) do
        assert(not r:IsShown() or not r.genericTitle or not r.genericTitle:IsShown(),"Pooled titles hide outside supplies")
    end
end end
print("PASS: Supply labels, stock placement, zero/unknown/surplus, details editing, Enter/Escape/Back and optional target dummies.")
''')
