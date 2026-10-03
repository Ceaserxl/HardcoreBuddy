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
for _,case in ipairs({{items[18045],"No Higher Food Tier Available"},
    {items[8766],"No Higher Drink Tier Available"},{items[13445],"No Higher Elixir Rank Available"},
    {items[14530],"No Higher Bandage Rank Available"}}) do
    local empty=A.Guide.EmptySupplyRow("Next",case[1])
    assert(empty.title==case[2] and empty.disabled and empty.compactRow and not empty.action)
end
local firstScroll=A.Data.Scrolls.items[1]
local scrollPage=A.Companion.Detail({characterClass="Hunter",level=firstScroll.level,faction="Alliance"},{kind="item",item=firstScroll})
local emptyAlternatives
for i,b in ipairs(scrollPage.blocks) do if b.title=="Alternatives" then emptyAlternatives=scrollPage.blocks[i+1] end end
assert(emptyAlternatives and emptyAlternatives.title=="No Alternatives Available" and emptyAlternatives.disabled and emptyAlternatives.compactRow)
local custom={}
for key,value in pairs(items[118]) do custom[key]=value end
custom.userItem=true
local customPage=A.Companion.Detail(ctx,{kind="item",item=custom})
assert(customPage.quantityRecord and customPage.blocks[1].itemId==118,"Custom item and quantity controls remain")
for _,block in ipairs(customPage.blocks) do
    assert(block.title~="Alternatives" and block.title~="Next" and block.title~="Maximum Skill Reached","Custom items have no rank sections")
end
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
assert(A.Guide.SupplySubtitle(items[6372],ctx):find("+100%% swim speed"),"Percent stays beside amount")
assert(A.Guide.SupplySubtitle(A.Data.Scrolls.items[1],ctx)=="+5 Agility / 30 min","Scroll effect is concise")
local supplyDoc=A.Companion.Build(ctx,{view="supplies",filter="All"})
for _,c in ipairs(supplyDoc.cards) do for _,b in ipairs(c.blocks or {}) do
    if b.itemId==8951 then assert(b.body==A.Guide.SupplySubtitle(items[8951],ctx),"Main tabs use compact effects") end
end end
assert(A.Guide.NextSupply(items[1251],ctx).itemId==2581)
for _,level in ipairs({35,40,60}) do
    local foodContext={characterClass="Mage",level=level,faction="Alliance"}
    local nextFood=A.Guide.NextSupply(items[17222],foodContext)
    assert(nextFood and nextFood.level==40,"Level 35 food advances to level 40 even when the character already qualifies")
    local page=A.Companion.Detail(foodContext,{kind="item",item=items[17222]})
    for i,b in ipairs(page.blocks) do
        if b.title=="Next" then assert(page.blocks[i+1].itemId==nextFood.itemId,"Next renders higher cooked food") end
    end
end
for _,family in ipairs({"dummy","antivenom"}) do
    local page=A.Companion.Detail(ctx,{kind="supplyFamily",family=family})
    assert(page.itemLayout and page.quantityRecord and page.itemSectionTitle=="Recommended","Profession supplies use standard details")
    local materials,alternatives,nextSection
    for _,b in ipairs(page.blocks) do
        if b.title=="Materials" then materials=b end
        if b.title=="Alternatives" then alternatives=b end
        if b.title=="Next" then nextSection=b end
    end
    assert(materials and not materials.rightColumn and alternatives.rightColumn and nextSection.rightColumn)
end
for _,item in pairs(items) do
    if item.name=="Restorative Potion" or item.name=="Flask of Petrification" then
        assert(#A.Guide.SupplySubtitle(item,ctx)<80,"Special consumable descriptions are compact")
    end
end
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
for _,frame in ipairs(card.content.blocks) do if frame:IsShown() and frame.block.rightColumn and frame.block.itemId then
    assert(frame.block.supplyDetail and frame:GetHeight()==selected:GetHeight(),"Short alternative and Next rows match selected height")
    local x,y=frame:GetRect(); local ix,iy=frame.icon:GetRect(); local tx,ty=frame.title:GetRect()
    assert(ix-x==8 and iy-y==11 and tx-x==52 and ty-y==7,"Shared icon and title insets")
    assert(frame.title.fontSize==selected.title.fontSize and frame.body.fontSize==selected.body.fontSize)
end end
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
