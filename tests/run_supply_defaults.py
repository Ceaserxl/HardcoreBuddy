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
assert(card.defaultChoice:IsShown() and not card.defaultChoice:IsEnabled())
local header,option
for _,r in ipairs(card.content.blocks) do if r:IsShown() then
    if r.block.title=="Alternatives" then header=r end
    if r.block.itemId==alternative.itemId then option=r end
end end
assert(header and option)
local hx=header.title:GetRect(); local ox=option.title:GetRect()
local ix=card.content.blocks[1].title:GetRect()
assert(hx==ox and ox==ix,"Alternatives heading aligns with item titles")
MOCK.Click(option)
card=A.window.cards[1]
assert(card.defaultChoice:IsEnabled() and card.defaultChoice.label:GetText()=="Set as default")
local state=A.state; local history=#A.history
MOCK.Click(card.defaultChoice)
assert(A.state==state and #A.history==history,"Selecting default preserves Back history")
assert(A.characterDB.supplyDefaults[group.family]==alternative.itemId)
assert(not card.defaultChoice:IsEnabled() and card.defaultChoice.label:GetText()=="Default item")
local selected=listed(alternative.itemId)
assert(selected and not listed(group.itemId),"Preference replaces the primary row")
assert(selected.category==S.Category(group),"Alternative keeps the original supply category")
A:Back(); assert(A.state==original and A.window.cards[1].defaultChoice:IsEnabled())
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
print("PASS: Alternative alignment, default switching/restoration, character persistence, availability and pooled controls.")
''')
