import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot,composite,ROOT
lua,a=boot()
lua.execute('''
local A=TestAddon
local loaded=false
C_Item.GetItemInfo=function(id)
 if id==6948 then return "Hearthstone",nil,nil,nil,1 end
 if id==12345 and loaded then return "Test Item",nil,nil,nil,12 end
end
assert(A.Supplies.categories[8]=="Optional" and A.Supplies.categories[9]=="User")
A:Navigate("supplies"); MOCK.Click(A.window.filters[9])
local entry=A.window.userEntry
assert(entry:IsVisible())
local hint=entry.hint:GetText()
assert(not entry.remove)
entry.input:SetText("not an item"); MOCK.Click(entry.add); assert(#A.characterDB.userItems==0)
entry.input:SetText("|Hitem:6948:0:0|h[Hearthstone]|h"); MOCK.Click(entry.add)
assert(#A.characterDB.userItems==1 and A.document.cards[1].blocks[1].title=="Hearthstone")
assert(entry.hint:GetText()==hint)
assert(not A:EditUserItem("6948") and #A.characterDB.userItems==1)
A.inventory={available=true,counts={[6948]=1}}
A:SetCarryTarget(6948,3); A:Refresh()
local row=A.document.cards[1].blocks[1]
assert(row.count==1 and row.target==3 and row.missing==2)
A:Activate(row.action); assert(A.document.isDetail and not entry:IsShown())
assert(A.window.userRemove:IsVisible())
A:Back(); assert(entry:IsShown())
assert(not A.window.userRemove:IsShown())
assert(A:EditUserItem("12345"))
loaded=true; A.events.scripts.OnEvent(A.events,"GET_ITEM_INFO_RECEIVED",12345,true); A:Refresh()
assert(A.characterDB.userItems[2].name=="Test Item")
assert(A:EditUserItem("12345",true) and #A.characterDB.userItems==1)
assert(A:EditUserItem("12345"))
A:Activate({kind="item",item=A.characterDB.userItems[2]})
MOCK.Click(A.window.userRemove)
assert(#A.characterDB.userItems==1 and A.state.filter=="User" and not A.window.userRemove:IsShown())
assert(A.characterDB.targets[6948]==3)
assert(not A:EditUserItem("999",true))
assert(A.window.filters[5].navIcon.texture~=A.window.filters[4].navIcon.texture)
local saved=A.characterDB
A:Initialize(); assert(A.characterDB==saved and #A.characterDB.userItems==1)
A:Navigate("supplies"); MOCK.Click(A.window.filters[9])
print("PASS: User add/link parsing, invalid input, duplicates, uncached resolution, bag counts, carry targets, remove, persistence, details/back and distinct Emergency icon.")
''')
composite(lua.globals().MOCK['frames'],a['window']).convert('RGB').save(ROOT/'docs/layout-previews/hardcorebuddy-user-items.png')
