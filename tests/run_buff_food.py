"""Class-aware buff-food priorities without duplicate recommendations."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local S=A.Supplies
local caster={Mage=true,Priest=true,Warlock=true}
local noMana={Warrior=true,Rogue=true}
local checks=0
for _,class in ipairs({"Warrior","Rogue","Hunter","Druid","Paladin","Shaman","Mage","Priest","Warlock"}) do
 for level=1,60 do
  local context=A:GetContext(); context.characterClass=class; context.level=level
  context.priorities={}; context.supplyDefaults={}
  local counts={wellfed=0,manafood=0}; local essential=0
  for _,r in ipairs(S.Build(context,{filter="Food & Drink"})) do
   if counts[r.family] then
    counts[r.family]=counts[r.family]+1
    assert(r.priority=="Essentials" or r.priority=="Optional",class.." food priority")
    assert(r.category=="Food & Drink","Both food types remain on Food & Drink")
    if r.priority=="Essentials" then essential=essential+1 end
   end
  end
  assert(counts.wellfed==1 and counts.manafood==(not noMana[class] and level>=10 and 1 or 0))
  assert(essential==1,"One primary buff food per class and level")
  local buffCount=0
  for _,r in ipairs(S.Build(context,{filter="Essentials"})) do
   if counts[r.family] then buffCount=buffCount+1 end
  end
  assert(buffCount==1,"Essentials excludes secondary food")
  checks=checks+1
 end
end
local context=A:GetContext(); context.characterClass="Mage"; context.level=40
context.priorities={wellfed="Essentials",manafood="Optional"}
assert(S.Priority(context,{family="wellfed"})=="Essentials")
assert(S.Priority(context,{family="manafood"})=="Optional","Manual priorities take precedence")
A:Navigate("supplies"); A.state.filter="Food & drink"; A:Refresh(true)
assert(A.state.filter=="Food & Drink" and A.document.cards[1].title=="Food & Drink")
assert(A.window.filters[3].label:GetText()=="Food & Drink")
print("PASS: "..checks.." class/level combinations, food deduplication, priorities, manual overrides and renamed navigation.")
''')
