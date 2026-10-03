import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua,a=boot()
lua.execute('''
local A=TestAddon
assert(#A.Data.Scrolls.items==24)
for level=1,60 do
    local context={characterClass="Hunter",level=level,inventory={available=true,counts={[3012]=2,[1477]=4}},targets={[1477]=7}}
    local rows=A.Supplies.Build(context,{filter="Scrolls"})
    assert(#rows==(level>=10 and 5 or level>=5 and 4 or 2))
    local seen={}
    for _,row in ipairs(rows) do
        assert(row.category=="Scrolls" and row.item.level<=level and not seen[row.family])
        seen[row.family]=true
        for _,item in ipairs(A.Data.Scrolls.items) do
            assert(item.family~=row.family or item.level>level or item.level<=row.item.level)
        end
        if row.itemId==1477 then assert(row.count==4 and row.target==7 and row.missing==3) end
    end
end
local expected={Hunter=5,Rogue=3,Warrior=4,Paladin=6,Shaman=6,Druid=6,Mage=4,Priest=4,Warlock=4}
for class,count in pairs(expected) do
    for level=1,60 do
        local rows=A.Supplies.Build({characterClass=class,level=level},{filter="Scrolls"})
        for _,r in ipairs(rows) do
            assert(A.Planner.MatchesClass(r.item,class) and r.item.level<=level)
            if class=="Mage" or class=="Priest" or class=="Warlock" then
                assert(r.family~="scroll-agility" and r.family~="scroll-strength")
            end
        end
        if level==60 then assert(#rows==count,class) end
    end
end
A:Navigate("supplies")
for _,button in ipairs(A.window.filters) do if button.label:GetText()=="Scrolls" then MOCK.Click(button); break end end
assert(A.state.filter=="Scrolls" and A.document.total==5)
local block=A.document.cards[1].blocks[1]
A:Activate(block.action)
assert(A.document.isDetail and A.document.cards[1].title:find("Scroll"))
A:Back(); assert(A.state.filter=="Scrolls")
A:SetCarryTarget(1477,9); A:Refresh()
assert(A.characterDB.targets[1477]==9)
print("PASS: 24 scroll ranks, all 60 level boundaries, exact-rank stock/targets, Scrolls navigation and item details/back.")
''')
if '--render' in sys.argv:
    composite(lua.globals().MOCK['frames'],a['window']).convert('RGB').save(ROOT/'docs/layout-previews/hardcorebuddy-scrolls.png')
