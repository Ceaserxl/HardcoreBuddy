"""Two-column item details, separate quantity controls and alternatives."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
A:Navigate("supplies")
local item
for _,card in ipairs(A.document.cards) do for _,b in ipairs(card.blocks) do
    local i=b.action and b.action.item
    if i and i.options and #i.options>0 then item=i; break end
end end
-- Use a deterministic alternative when the current kit contains none.
if not item then
    item={}
    for k,v in pairs(A.document.cards[1].blocks[1].action.item) do item[k]=v end
    item.options={A.document.cards[1].blocks[2].action.item}
end
A:Activate({kind="item",item=item})
local card=A.window.cards[1]; local rows=card.content.blocks
local itemRow,details=rows[1],rows[2]
local x,y,w,h=itemRow:GetRect(); local dx,dy=details:GetRect()
assert(h==56 and dx>x+w and dy==y,"Item and details share a top edge in separate columns")
assert(not itemRow.quantity:IsShown() and card.detailQuantity:IsShown())
local ex,ey,ew,eh=card.detailQuantity:GetRect()
assert(ex==x and ey>y+h,"Quantity control is outside and below the item border")
local alternativeHeader,alternative
for _,r in ipairs(rows) do if r:IsShown() then
    if r.block.title=="Alternatives" then alternativeHeader=r end
    if alternativeHeader and r.block.action and r.block.action.kind=="item" then alternative=r; break end
end end
assert(alternativeHeader and alternativeHeader.skinKind=="note","Alternatives heading has no card border")
local ax,ay=alternativeHeader:GetRect(); local bx,by,bw,bh=alternative:GetRect()
assert(ax==x and bx==x and ay>ey+eh and by>=ay+alternativeHeader:GetHeight(),"Alternatives stay below the item in the left column")
local old=A.state; local id=alternative.block.action.item.itemId
MOCK.Click(alternative); assert(A.state.detail.item.itemId==id)
A:Back(); assert(A.state==old,"Back restores the original item")
local q=A.window.cards[1].detailQuantity.quantity
q:SetFocus(); q:SetText("13")
A:Navigate("supplies")
assert(A.characterDB.targets[item.itemId]==13,"Navigation commits the separate editor")
assert(not A.window.cards[1].detailQuantity:IsVisible(),"Separate editor hidden on supply list")
for _,c in ipairs(A.window.cards) do if c:IsShown() then for _,r in ipairs(c.content.blocks) do
    if r:IsShown() and r.block.supply then assert(r:GetHeight()==56 and not r.quantity:IsShown()) end
end end end
print("PASS: Item/details columns, compact rows, external quantity editor, borderless Alternatives and detail return paths.")
''')
