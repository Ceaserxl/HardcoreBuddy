"""Saved supply alternatives, availability gates and detail controls."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local S=A.Supplies; local P=A.Planner
A:Navigate("supplies")
local context=A:GetContext()
local group
for _,r in ipairs(P.BuildList(context.characterClass,context.level,P.ContextFaction(context)).rows) do
    if r.family=="wellfed" and #r.options>0 then group=r; break end
end
assert(group,"Fixture has food alternatives")
local alternative=group.options[1]
local function listed(id)
    for _,r in ipairs(S.Build(A:GetContext(),{})) do if r.item.itemId==id then return r end end
end
A:Activate({kind="item",item=group})
local original=A.state
local card=A.window.cards[1]
assert(not card.defaultChoice:IsShown(),"Default items hide Set as default")
local header,option
for _,r in ipairs(card.content.blocks) do if r:IsShown() then
    if r.block.title=="Alternatives" then header=r end
    if r.block.itemId==alternative.itemId then option=r end
end end
assert(header and option)
local hx=header.title:GetRect(); local ox=option.title:GetRect()
local ix=card.content.blocks[1].title:GetRect()
local backX=A.window.back:GetRect()
assert(hx==backX and ox==ix,"Heading aligns with Back; item text retains consistent padding")
assert(card.content.blocks[1]:GetRect()==backX and option:GetRect()==backX)
local qx,qy,qw=card.detailQuantity:GetRect()
local px,py=A.window.priorityChoice:GetRect()
assert(qy==py and qx+qw+8==px,"Keep on hand sits directly left of Priority")
for _,r in ipairs(card.content.blocks) do if r:IsShown() then
    if r.block.title=="Next" then assert(r.title:GetRect()==backX) end
    if r.block.fields then
        local dx,dy,dw=r:GetRect(); local px,py,pw=A.window.priorityChoice:GetRect()
        assert(dx+dw==px+pw,"Priority remains aligned with details right edge")
    end
end end
MOCK.Click(option)
card=A.window.cards[1]
assert(card.defaultChoice:IsShown() and card.defaultChoice:IsEnabled() and card.defaultChoice.label:GetText()=="Set as default")
local bx,by,bw=A.window.back:GetRect(); local dx,dy=card.defaultChoice:GetRect()
assert(dx==bx+bw+8 and dy==by,"Set as default sits immediately right of Back")
local state=A.state; local history=#A.history
MOCK.Click(card.defaultChoice)
assert(A.state==state and #A.history==history,"Selecting default preserves Back history")
assert(A.characterDB.supplyDefaults[group.family]==alternative.itemId)
assert(not card.defaultChoice:IsShown(),"Button hides immediately after setting default")
local selected=listed(alternative.itemId)
assert(selected and not listed(group.itemId),"Preference replaces the primary row")
assert(selected.category==S.Category(group),"Alternative keeps the original supply category")
A:Back(); assert(A.state==original and A.window.cards[1].defaultChoice:IsShown() and A.window.cards[1].defaultChoice:IsEnabled())
MOCK.Click(A.window.cards[1].defaultChoice)
assert(listed(group.itemId) and not listed(alternative.itemId),"Original choice can be restored")
A:Activate({kind="supplyDefault",item=alternative})
local saved=A.characterDB.supplyDefaults
assert(A:GetContext().supplyDefaults==saved,"Preference comes from character SavedVariables")
local future=A:GetContext(); future.level=60
local fallback
for _,r in ipairs(P.BuildList(future.characterClass,60,P.ContextFaction(future)).rows) do
    if r.family==group.family then fallback=r end
end
assert(fallback and S.PreferredItem(future,fallback).itemId==fallback.itemId,
    "An obsolete food choice does not suppress higher-level recommendations")
A:Activate({kind="supplyDefault",item={itemId=999999,family=group.family}})
assert(saved[group.family]==alternative.itemId,"Reject unlisted alternatives")
A:Navigate("supplies")
assert(not A.window.cards[1].defaultChoice:IsShown(),"Default button is hidden outside item details")
local bandage
for _,item in ipairs(A.Data.Items.items) do if item.itemId==1251 then bandage=item end end
A:Activate({kind="item",item=bandage})
local choice=A.window.cards[1].defaultChoice
assert(choice:IsShown() and choice:IsEnabled(),"A usable lower bandage rank offers Set as default")
local bx,by,bw=A.window.back:GetRect(); local dx,dy=choice:GetRect()
assert(dx==bx+bw+8 and dy==by,"Bandage default button sits immediately right of Back")
MOCK.Click(choice)
assert(A.characterDB.supplyDefaults.bandage==1251 and S.Selection(A:GetContext(),"bandage")==1251)
assert(not choice:IsShown(),"Selected bandage hides the default button")
A:Navigate("supplies")
local selectedBandage
for _,card in ipairs(A.document.cards) do for _,block in ipairs(card.blocks) do
    if block.action and block.action.family=="bandage" then selectedBandage=block end
end end
assert(selectedBandage and selectedBandage.itemId==1251 and selectedBandage.body=="Your default bandage",
    "The supplies list uses the saved bandage instead of the automatic rank")
local noSkill=A:GetContext(); noSkill.professions={skills={bandage=0},known={}}
assert(S.Selection(noSkill,"bandage")~=1251,"Unusable saved bandage falls back to live profession selection")
print("PASS: Alternative alignment, default switching/restoration, character persistence, availability and pooled controls.")
''')
