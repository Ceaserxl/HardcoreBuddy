"""Shared supply detail layout, effect copy and exact recipe stock requirements."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
lua.execute('''
local A=TestAddon
local ctx=A:GetContext()
ctx.inventory={available=true,counts={[2589]=1}}
local items={}
for _,item in ipairs(A.Data.Items.items) do items[item.itemId]=item end
for _,id in ipairs({117,159,118,8951,21217,1251,2581}) do
    local item=assert(items[id],"Fixture exists: "..id)
    local detail=A.Companion.Detail(ctx,{kind="item",item=item})
    assert(detail.itemLayout and detail.blocks[1].itemId==id)
    assert(detail.blocks[1].supplyDetail and not detail.blocks[1].body:find("Must remain seated",1,true))
    local headings={}; local materials={}
    for _,b in ipairs(detail.blocks) do
        assert(not b.fields and b.title~="Item details","No legacy prose section")
        if b.plain and not b.itemId then headings[b.title]=b end
        if b.materialCount then materials[b.itemId]=b; assert(not b.rightColumn and b.readOnlyTarget) end
    end
    assert(headings.Materials and not headings.Materials.rightColumn)
    assert(headings.Alternatives.rightColumn and headings.Next.rightColumn)
    local recipe=A.Data.AuctionRecipes[id]
    if recipe then
        for _,pair in ipairs(recipe.reagents) do
            local b=assert(materials[pair[1]],"Every reagent listed")
            assert(b.target==pair[2] and b.count==(ctx.inventory.counts[pair[1]] or 0))
        end
    end
end
local blocks=A.Crafting.MaterialBlocks(items[2581],ctx)
assert(blocks[1].count==1 and blocks[1].target==2 and blocks[1].status=="low")
ctx.inventory.available=false
assert(A.Crafting.MaterialBlocks(items[2581],ctx)[1].count==nil,"Unknown bags stay unknown")
assert(A.Guide.SupplySubtitle(items[1251],ctx):find("health",1,true))
assert(A.Guide.SupplySubtitle(items[8951],ctx):find("+250 armor",1,true))
assert(A.Guide.NextSupply(items[1251],ctx).itemId==2581)
A.GetContext=function() return ctx end
A:Navigate("supplies")
A:Activate({kind="item",item=items[21217]})
local card=A.window.cards[1]
local selected=card.content.blocks[1]
local alternatives,materials
for _,frame in ipairs(card.content.blocks) do if frame:IsShown() then
    if frame.block.title=="Alternatives" then alternatives=frame end
    if frame.block.title=="Materials" then materials=frame end
end end
local sx,sy,sw=selected:GetRect()
local mx,my=materials:GetRect()
local ax,ay=alternatives:GetRect()
assert(mx==sx and my>sy and ax>sx+sw,"Materials below selected; alternatives right")
assert(selected:GetHeight()>=56 and selected.body:GetHeight()>0)
-- Enchant future ranks can be inspected without changing the recommendation.
GetInventoryItemID=function(_,slot) if slot==9 then return 10009 end end
GetInventoryItemLink=function(_,slot) if slot==9 then return "item:10009:0:0:0" end end
C_Item.GetItemInfo=function() return "Bracers",nil,2,60,1,"Armor","Cloth",1,"INVTYPE_WRIST",123,0,4 end
ctx.level=1; ctx.characterClass="Mage"; A.characterDB.enchantMode="level"
local enchant=A.Enchants.Detail(ctx,{slotId=9})
local upcoming
for i,b in ipairs(enchant.blocks) do
    if b.title=="Next" then upcoming=enchant.blocks[i+1] end
end
assert(upcoming and upcoming.action,"Next enchant rank exists")
local nextDetail=A.Enchants.Detail(ctx,upcoming.action)
assert(nextDetail.blocks[2].title==upcoming.title,"Future rank opens its own effect and materials")
assert(A.Enchants.Detail(ctx,{slotId=9}).blocks[2].title==enchant.blocks[2].title,"Browsing preserves recommendation")
''')
target = ROOT / '.release' / 'supply-detail-standardized.png'
target.parent.mkdir(exist_ok=True)
composite(lua.globals().MOCK.frames, addon.window).save(target)
print('PASS: Shared layout, effects, recipe quantities, unknown stock and rank progression.')
print(target)
