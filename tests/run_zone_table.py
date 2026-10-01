"""Zone table category isolation, clickable rows, pooling and model return."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local M=A.MapAdvisor
local mapID
for id in pairs(A.Data.MapZones) do
    local kinds={}
    for _,r in ipairs(M:Records(id,true)) do kinds[r.npc.kind]=true end
    if kinds.rare and kinds.elite then mapID=id; break end
end
assert(mapID)
A:Navigate("training"); A.state.filter="Zone Advisor"; A:Refresh(true)
local root=A.state
A:Activate({kind="mapAdvisor",command="zone",id=mapID})
local zoneState=A.state
local d=A.document
assert(#d.cards==1 and d.cards[1].title==A.Data.MapZones[mapID].name and d.cards[1].npcTable)
assert(d.cards[1].headerAction.label=="Open Map")
for _,row in ipairs(d.cards[1].blocks) do assert(row.action.command=="npc" and row.npcColumns) end
local s=M:Settings(); local saved=s.rare; s.rare=false
for i,kind in ipairs({"all","rare","elite","boss","danger"}) do
    local f=A.window.cards[1]
    local button=f.npcFilters[i]; local x,y,w,h=button:GetRect()
    assert(MOCK.HitTest(x+w/2,y+h/2)==button,"Category filter is clickable")
    MOCK.Click(button)
    assert(A.state==zoneState and A.state.zoneNPCFilter==kind and button.active)
    local expected=0
    for _,r in ipairs(M:Records(mapID,true)) do if kind=="all" or r.npc.kind==kind then expected=expected+1 end end
    local actual=0
    for _,row in ipairs(A.document.cards[1].blocks) do
        if row.npcColumns then actual=actual+1; assert(kind=="all" or row.npcKind==kind) end
    end
    assert(actual==expected,"Exact category results independent of marker settings")
    assert(s.rare==false,"Table filtering does not change map markers")
end
MOCK.Click(A.window.cards[1].npcFilters[2])
local row=A.window.cards[1].content.blocks[1]
assert(row.block.npcKind=="rare" and not row.title:IsShown() and row.npcCells[2]:IsShown())
local x,y,w,h=row:GetRect(); assert(MOCK.HitTest(x+w/2,y+h/2)==row,"Entire table row clickable")
row.scripts.OnEnter(row); assert(GameTooltip:IsShown() and GameTooltip.lines[1]==row.block.title)
local id=row.block.action.id
MOCK.Click(row); assert(M.viewer.npcID==id and A.state.mapNPCs[1]==id)
A:Back(); assert(A.state==zoneState and A.state.zoneNPCFilter=="rare")
A:Back(); assert(A.state==root and A.document.zoneRecommendations)
for _,b in ipairs(A.window.cards[1].npcFilters) do assert(not b:IsShown(),"Table controls hidden after returning to overview") end
for _,r in ipairs(A.window.cards[1].content.blocks) do
    for _,cell in ipairs(r.npcCells or {}) do assert(not cell:IsVisible(),"No table text leaks into overview cards") end
end
s.rare=saved
print("PASS: Zone title, single table, all five category filters, marker independence, row hit tests, model Back and pooled controls.")
''')
