"""Classic crafted ammo tiers, essentials priority, and alternatives alignment."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local M,S=A.Ammunition,A.Supplies
local c=A:GetContext(); c.mode='preview'; c.characterClass='Hunter'; c.previewAmmo='arrows'; c.priorities={}
c.level=51; assert(M.Recommend(c).itemId==11285)
c.level=52; local arrow=M.Recommend(c)
assert(arrow.itemId==18042 and arrow.ammoDPS==17.5 and arrow.route:find('200 Thorium Shells',1,true))
local found=false
for _,row in ipairs(S.Build(c,{filter='Essentials'})) do
 if row.family=='ammunition' then found=true; assert(row.itemId==18042 and row.priority=='Essentials') end
end
assert(found,'Hunter ammunition is included in Essentials by default')
assert(arrow.options[1].itemId==11285,'Ordinary vendor arrows remain an alternative')
c.previewAmmo='bullets'
for _,tier in ipairs({{5,8067},{15,8068},{30,8069},{37,10512},{44,10513},{52,15997}}) do
 c.level=tier[1]; local ammo=M.Recommend(c)
 assert(ammo.itemId==tier[2] and ammo.ingredients and ammo.route:find('Engineering',1,true))
end
local context=A:GetContext(); local food
for _,row in ipairs(A.Planner.BuildList(context.characterClass,context.level,A.Planner.ContextFaction(context)).rows) do
 if row.family=='recovery' then food=row end
end
A:Activate({kind='item',item=food})
local card=A.window.cards[1]; local _,headingY=card.itemHeading:GetRect()
local alternatives
for _,row in ipairs(card.content.blocks) do
 if row:IsShown() and row.block.title=='Alternatives' then alternatives=row end
end
assert(alternatives,'Food alternatives are visible')
local _,y,_,h=alternatives:GetRect(); local _,hy,_,hh=card.itemHeading:GetRect()
assert(math.abs((y+h)-(hy+hh))<1,'Alternatives section starts at the food section top')
print('PASS: crafted ammo tiers, Thorium arrow exchange, hunter Essentials default and aligned alternatives.')
''')
