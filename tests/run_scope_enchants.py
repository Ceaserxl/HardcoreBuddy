"""Ranged scopes and conditional off-hand rows use the shared enchant flow."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local E=A.Enchants
local gear={}; local checks=0
local function check(ok,msg) checks=checks+1; assert(ok,msg) end
GetInventoryItemID=function(_,slot) return gear[slot] and 10000+slot end
GetInventoryItemLink=function(_,slot)
    local g=gear[slot]; return g and "item:"..(10000+slot)..":"..(g.enchant or 0)..":0:0"
end
C_Item.GetItemInfo=function(link)
    local g=gear[tonumber(link:match("item:(%d+)"))-10000]
    return "Equipped",link,2,60,1,"Weapon","",1,g.loc,123,0,g.class or 2,g.subclass
end
UnitRangedDamage=function() return 2 end
local ctx={mode="live",level=40,characterClass="Hunter",inventory={available=true,counts={}}}
local function slot(id) for _,g in ipairs(E.Scan(ctx)) do if g.slotId==id then return g end end end
local function card(id) for _,b in ipairs(E.Card(ctx).blocks) do if b.action.slotId==id then return b end end end
for _,sub in ipairs({2,3,18}) do
    gear[18]={loc=sub==2 and "INVTYPE_RANGED" or "INVTYPE_RANGEDRIGHT",subclass=sub}
    local g=slot(18)
    check(g.recommendation.itemId==10548,"Sniper scope recommended on each ranged weapon type")
    check(card(18).enchantStatus=="Not Enchanted","Missing scope uses normal missing row")
    check(#E.Options(ctx,g)==1 and #E.Options(ctx,g,true)==5,"Lesser ranks toggle")
    gear[18].enchant=664
    check(slot(18).status=="ready" and card(18).enchantStatus=="Enchanted","Applied scope detected")
    gear[18].enchant=30
    check(slot(18).status=="upgrade" and card(18).enchantStatus=="Alternative","Old scope recognized")
end
gear[18].enchant=0
local d=E.Detail(ctx,{slotId=18}); local materials=0
for _,b in ipairs(d.blocks) do
    if b.materialCount then materials=materials+1; check(b.count==0 and b.target>0,"Materials counted") end
end
check(materials==3,"Sniper crafting materials")
check(E.Subtitle(slot(18).recommendation):find("Engineering 240",1,true),"Correct crafting profession")
A.characterDB.enchantMode="max"; ctx.level=5
check(slot(18).recommendation.itemId==4405,"Max mode still respects scope use level")
ctx.level=4; check(not slot(18).recommendation,"No scope below level five")
ctx.level=60; local hit=E.byId[22779]
check(E.Score(hit,E.Profile(ctx))==3*E.Profile(ctx).weights.hit,"Hunter ranged hit score")
for _,class in ipairs({"Warrior","Rogue"}) do
    ctx.characterClass=class
    check(card(18) and slot(18).recommendation.itemId==10548,"Physical ranged fallback")
    check(E.Score(hit,E.Profile(ctx))==0,"Ranged hit is not melee hit")
end
for _,sub in ipairs({16,19}) do
    gear[18].subclass=sub
    check(not card(18) and #slot(18).options==0,"Thrown and wands excluded")
end
ctx.characterClass="Mage"; check(not card(18),"Caster has no scope row")
ctx.characterClass="Rogue"
gear[17]={loc="INVTYPE_WEAPONOFFHAND",subclass=15}
check(card(17) and #slot(17).options>0,"Dual wield off-hand shown")
gear[17].enchant=slot(17).recommendation.enchantId
check(card(17).enchantStatus=="Enchanted","Off-hand enchant detected independently")
ctx.characterClass="Warrior"; gear[17]={loc="INVTYPE_SHIELD",class=4,subclass=6}
check(card(17) and #slot(17).options>0,"Enchantable shield shown")
gear[17]={loc="INVTYPE_HOLDABLE",class=4,subclass=0}
check(not card(17),"Held-in-hand excluded")
gear[17]=nil; check(not card(17),"Empty off-hand excluded")
print("PASS: "..checks.." ranged/off-hand enchant checks")
''')
