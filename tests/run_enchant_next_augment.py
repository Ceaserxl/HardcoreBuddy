"""Next upgrades cross armor-kit/enchant families for selected and applied augments."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua, addon=boot()
lua.execute('''
local A=TestAddon; local E=A.Enchants
local current=0
GetInventoryItemID=function(_,slot) if slot==8 then return 10008 end end
GetInventoryItemLink=function(_,slot) if slot==8 then return "item:10008:"..current..":0:0" end end
C_Item.GetItemInfo=function() return "Boots",nil,2,60,1,"Armor","Cloth",1,"INVTYPE_FEET",123,0,4 end
local ctx={mode="live",level=60,characterClass="Mage",inventory={available=true,counts={}}}
local weights={armor=1,stamina=20}
E.Profile=function() return {class="MAGE",id=1,weights=weights} end
local function nextAugment(action)
    local page=E.Detail(ctx,action)
    for i,b in ipairs(page.blocks) do if b.title=="Next" then
        local row=page.blocks[i+1]
        return row.action and E.byId[row.action.spellId],row
    end end
end
local kit=E.byId[19058]
local enchant=E.byId[7863]
local nextItem=nextAugment({slotId=8,spellId=kit.spellId})
assert(nextItem and not nextItem.armorKit,"Selected kit advances to better enchant")
current=kit.enchantId
assert(nextAugment({slotId=8})==nextItem,"Applied kit advances to the same enchant")
weights={armor=10,stamina=1}
local nextKit=nextAugment({slotId=8,spellId=enchant.spellId})
assert(nextKit and nextKit.armorKit,"Selected enchant advances to better armor kit")
current=enchant.enchantId
assert(nextAugment({slotId=8})==nextKit,"Applied enchant advances to the same armor kit")
current=nextKit.enchantId
local none,row=nextAugment({slotId=8})
assert(not none and row.disabled,"No lower-scoring sidegrade at the top")
ctx.level=1; weights={armor=1,stamina=20}; current=15
local future=nextAugment({slotId=8})
assert(future and future.spellId==2165,"Next eligible tier is preferred over a distant max-level upgrade")
print("PASS: Selected/applied kits and enchants cross families, respect weights and earliest tier, and exclude downgrades.")
''')
