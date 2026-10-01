"""Faction recommendations, inclusive range edges and Companion navigation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local function build(faction,level,all,query)
    return A.LevelingZones.Build({faction=faction,level=level,mode="live"},
        {view="training",filter="Zones",showAllZones=all,query=query})
end
for _,faction in ipairs({"Alliance","Horde"}) do
    for level=1,60 do
        local d=build(faction,level)
        assert(d.total>0 and d.pages==1 and d.continuous)
        local expected=0
        for _,z in ipairs(A.Data.LevelingZones) do
            assert(A.Data.MapZones[z.map],"Valid map destination")
            local band=z[faction] or z.both
            if band and level>=band[1]-3 and level<=band[2]+3 then expected=expected+1 end
        end
        assert(d.total==expected,"Exact inclusive +/-3 filtering")
        for _,r in ipairs(d.cards[1].blocks) do assert(level>=r.low-3 and level<=r.high+3) end
    end
end
assert(build("Alliance",7,false,"Westfall").total==1)
assert(build("Alliance",6,false,"Westfall").total==0)
assert(build("Alliance",23,false,"Westfall").total==1)
assert(build("Alliance",24,false,"Westfall").total==0)
assert(build("Horde",15,true,"Westfall").total==0)
assert(build("Alliance",15,true,"Barrens").total==0)
assert(build(nil,20).total==0 and build(nil,20).cards[1].blocks[1].title=="Faction unavailable")
assert(build("Alliance",32,false,"Stranglethorn").cards[1].blocks[1].title:find("North"))
assert(build("Alliance",44,false,"Stranglethorn").cards[1].blocks[1].title:find("South"))
for _,class in ipairs({"HUNTER","WARRIOR"}) do
    MOCK.class=class; A.db.profile.mode="live"; A.lastClass=nil; A:Navigate("training")
    local tab
    for _,b in ipairs(A.window.filters) do if b.filter=="Zones" then tab=b end end
    assert(tab and tab:IsVisible()); MOCK.Click(tab)
    assert(A.state.filter=="Zones" and A.document.cards[1].title=="Recommended leveling zones")
    assert(A.window.atLevel.label:GetText()=="Show all")
    local filtered=A.document.total
    MOCK.Click(A.window.atLevel)
    assert(A.state.showAllZones and A.document.total>filtered and A.window.atLevel.label:GetText()=="Near my level")
    MOCK.Click(A.window.atLevel); assert(not A.state.showAllZones and A.document.total==filtered)
    local opened
    local activate=A.MapAdvisor.Activate
    A.MapAdvisor.Activate=function(_,action) opened=action.id end
    A:Activate(A.document.cards[1].blocks[1].action)
    assert(opened==A.document.cards[1].blocks[1].map)
    A.MapAdvisor.Activate=activate
end
A.db.profile.mode="preview"; A.db.profile.level=58; A.db.profile.characterClass="Warrior"; A:Refresh()
assert(A.document.cards[1].note:find("Planned level 58",1,true))
for _,row in ipairs(A.document.cards[1].blocks) do assert(row.high>=55) end
print("PASS: Zones navigation, all levels 1-60 for both factions, exact filter edges, search, Show all, map links and planned levels.")
''')
