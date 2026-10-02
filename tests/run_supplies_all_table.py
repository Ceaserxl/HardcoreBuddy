"""All-only supply table, stock labels, navigation and pooled-row restoration."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
lua.execute('''
local A=TestAddon
for _,class in ipairs({"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}) do
    MOCK.class=class; A.lastClass=nil; A:Navigate("supplies")
    local doc=A.document; local card=A.window.cards[1]
    assert(doc.cards[1].allSupplyTable and doc.cards[1].fullWidth)
    local total,categoryIndex,clickable=0,2
    for sectionIndex,section in ipairs(doc.cards) do if section.allSupplyTable then
      card=A.window.cards[sectionIndex]
      assert(section.title==A.Supplies.categories[categoryIndex],"All preserves category sections and order")
      categoryIndex=categoryIndex+1
      local _,size=card.title:GetFont(); assert(size==15,"All category headings have the same size")
      assert(#card.supplyHeaders==5)
      local previous
      for i,block in ipairs(section.blocks) do
        total=total+1
        assert(block.category==section.title,"Supply stays within its category section")
        local row=card.content.blocks[i]
        local x,y,w,h=row:GetRect()
        assert(h==36 and w==card.content:GetWidth(),"All rows use the full table width")
        if previous then assert(y==previous+1,"Continuous table rows have a one-pixel gap") end
        previous=y+h
        assert(row.category:GetText()==block.category and row.priority:GetText()==block.priority)
        assert(not row.quantity:IsShown() and not row.stockTrack:IsShown(),"Quantity editing stays in details")
        for _,edge in ipairs(row.statusBorder) do assert(not edge:IsShown(),"Table rows have no tile outlines") end
        local wanted=block.count==nil and (block.status=="choose" and "Choose rank" or "Unknown")
            or "("..block.count.."/"..(block.target or "?")..")"
        assert(row.stock:GetText()==wanted,"Table preserves supply stock states")
        if block.action and block.action.kind=="item" then clickable=clickable or row end
      end
    end end
    assert(total==doc.total,"Every supply appears in its category table")
    assert(clickable); local id=clickable.block.itemId
    MOCK.Click(clickable)
    assert(A.document.isDetail and A.state.detail.item.itemId==id,"Item rows open the selected item")
    assert(A.window.cards[1].content.blocks[1]:GetHeight()==56,"Detail item keeps its tile")
    A:Back(); assert(A.document.cards[1].allSupplyTable)
    for _,category in ipairs({"Food & Drink","Essentials","Buffs","Emergency","Class","User"}) do
        A.state.filter=category; A:Refresh(true)
        assert(not A.document.cards[1].allSupplyTable,"Other tabs retain their existing layout")
        for _,header in ipairs(A.window.cards[1].supplyHeaders) do assert(not header:IsShown()) end
        for _,c in ipairs(A.window.cards) do if c:IsShown() then
            for _,row in ipairs(c.content.blocks) do if row:IsShown() and row.block.supply then
                assert(row:GetHeight()==56 and not row.block.supplyColumns)
                assert(not row.category or not row.category:IsShown(),"Pooled table columns are hidden on tiles")
            end end
        end end
    end
end
print("PASS: All-only full-width supply table for nine classes; stock states, item navigation and unchanged category tiles.")
''')
if '--render' in sys.argv:
    lua.execute('TestAddon:Navigate("supplies")')
    output=ROOT/'.release'/'settings-previews'/'supplies-all-table.png'
    output.parent.mkdir(parents=True, exist_ok=True)
    composite(lua.globals().MOCK.frames, addon.window).save(output)
    print(output)
