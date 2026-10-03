"""Fixed card-row geometry across supply tabs, detail text lengths and empty states."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua, addon=boot()
lua.execute('''
local A=TestAddon; local checked=0
local function checkRows()
    for _,card in ipairs(A.window.cards) do if card:IsShown() then
        for _,frame in ipairs(card.content.blocks) do if frame:IsShown() then
            local b=frame.block
            if b and (b.supply or b.supplyDetail or b.enchantRow or b.compactRow) and not b.supplyColumns then
                assert(frame:GetHeight()==56,(b.title or "Row").." has inconsistent height")
                checked=checked+1
            end
        end end
    end end
end
for _,filter in ipairs(A.Supplies.filters) do
    A.state={view="supplies",filter=filter}; A:Refresh(true); checkRows()
end
for _,catalog in ipairs({A.Data.Items.items,A.Data.Scrolls.items}) do
    for _,item in ipairs(catalog) do
        A.state={view="supplies",filter="All",detail={kind="item",item=item}}
        A:Refresh(true); checkRows()
    end
end
local blocks={}
for _,body in ipairs({"","+9 Stamina","A description that wraps onto a second line with crafting requirements"}) do
    blocks[#blocks+1]={title="Selected item",body=body,supply=true,supplyDetail=true,itemId=118,count=0,target=5,status="missing"}
    blocks[#blocks+1]={title="Alternative item",body=body,supplyDetail=true,itemId=118,rightColumn=true}
    blocks[#blocks+1]={title="Enchant item",body=body,enchantRow=true,enchantStatus="Not Enchanted",enchantTone="missing",itemId=118}
end
blocks[#blocks+1]=A.Guide.EmptySupplyRow("Alternatives")
A.state={view="supplies",filter="All",detail={kind="card",card={title="Row sizing audit",itemLayout=true,blocks=blocks}}}
A:Refresh(true); checkRows()
assert(checked>100,"Audit covers catalog rows, not just fixtures")
print("PASS: "..checked.." supply card rows have fixed 56px height; single/two-line, materials, enchants and empty rows included.")
''')
target=ROOT/'.release'/'supply-row-height-audit.png'
target.parent.mkdir(exist_ok=True)
composite(lua.globals().MOCK.frames,addon.window).save(target)
