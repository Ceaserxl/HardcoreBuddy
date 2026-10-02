"""Faction recommendations, inclusive range edges and Companion navigation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
A:Navigate("advisors")
assert(A.state.view=="training" and A.state.filter=="Gear","Legacy Advisors route opens Companion Gear")
local function build(faction,level,all,query)
    return A.LevelingZones.Build({faction=faction,level=level,mode="live"},
        {view="training",filter="Zone Advisor",showAllZones=all,query=query})
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
        for _,r in ipairs(d.cards[2].blocks) do assert(level>=r.low-3 and level<=r.high+3) end
    end
end
assert(build("Alliance",7,false,"Westfall").total==1)
assert(build("Alliance",6,false,"Westfall").total==0)
assert(build("Alliance",23,false,"Westfall").total==1)
assert(build("Alliance",24,false,"Westfall").total==0)
assert(build("Horde",15,true,"Westfall").total==0)
assert(build("Alliance",15,true,"Barrens").total==0)
assert(build(nil,20).total==0 and build(nil,20).cards[2].blocks[1].title=="Faction unavailable")
assert(build("Alliance",32,false,"Stranglethorn").cards[2].blocks[1].title:find("North"))
assert(build("Alliance",44,false,"Stranglethorn").cards[2].blocks[1].title:find("South"))
for _,class in ipairs({"HUNTER","WARRIOR"}) do
    MOCK.class=class; A.db.profile.mode="live"; A.lastClass=nil; A:Navigate("training")
    local tab
    for _,b in ipairs(A.window.filters) do if b.filter=="Zone Advisor" then tab=b end end
    assert(tab and tab:IsVisible()); MOCK.Click(tab)
    for _,b in ipairs(A.window.filters) do assert(not b:IsShown() or b.filter~="Zones","Only one zone tab") end
    assert(A.state.filter=="Zone Advisor" and A.document.cards[2].title=="Recommended leveling zones")
    assert(A.window.atLevel.label:GetText()=="Show All")
    local header=A.window.cards[1].headerButton
    local hx,hy,hw,hh=header:GetRect()
    local ax,ay,aw,ah=A.window.atLevel:GetRect()
    local cx,cy,cw,ch=A.window.clear:GetRect()
    local sx,sy,sw,sh=A.window.search:GetRect()
    assert(ax+aw+8==hx and ay==hy,"Show All sits immediately left of Settings")
    assert(cx+cw==hx+hw and sx+sw+A.Skin.layout.columnGap==cx,"Expanded search row ends at the Settings edge")
    assert(A.window.atLevel:GetParent()==A.window.cards[1],"Show All scrolls with its title")
    local filtered=A.document.total
    MOCK.Click(A.window.atLevel)
    assert(A.state.showAllZones and A.document.total>filtered and A.window.atLevel.label:GetText()=="Near my level")
    MOCK.Click(A.window.atLevel); assert(not A.state.showAllZones and A.document.total==filtered)
    local source=A.state
    local destination=A.document.cards[2].blocks[1].map
    local opened
    WorldMapFrame=WorldMapFrame or CreateFrame("Frame")
    WorldMapFrame.SetMapID=function(_,id) opened=id end
    A:Activate(A.document.cards[2].blocks[1].action)
    assert(A.state.view=="training" and A.state.filter=="Zone Advisor" and A.state.mapZone==destination)
    assert(not opened,"Zone row must not open the world map")
    assert(A.document.cards[1].title==A.Data.MapZones[destination].name)
    assert(not A.window.atLevel:IsShown() and A.window.atLevel:GetParent()==A.window,"Header toggle resets on zone details")
    local zoneState=A.state
    A.MapAdvisor:Activate({command="zones"})
    local choice=A.document.cards[1].blocks[2].action
    A:Activate(choice)
    assert(A.state.mapZone==choice.id and not A.state.mapZonePicker)
    A:Back(); assert(A.state==zoneState and A.state.mapZonePicker,"Back restores zone browser")
    A:Back(); assert(A.state==zoneState and not A.state.mapZonePicker,"Back restores selected zone")
    local zoneCard=A.window.cards[1]
    assert(zoneCard.headerButton:IsShown() and zoneCard.headerButton.label:GetText()=="Open Map")
    MOCK.Click(zoneCard.headerButton)
    assert(opened==destination,"Header button opens the selected zone map")
    WorldMapFrame:Hide()
    A:Back(); assert(A.state==source and A.state.filter=="Zone Advisor","Back restores recommendations")
    assert(A.window.cards[1].headerButton.label:GetText()=="Settings","Root settings button restored")

end
A.db.profile.mode="preview"; A.db.profile.level=58; A.db.profile.characterClass="Warrior"; A:Refresh()
assert(A.document.cards[2].note:find("Planned level 58",1,true))
for _,row in ipairs(A.document.cards[2].blocks) do assert(row.high>=55) end
print("PASS: Zones navigation, all levels 1-60 for both factions, exact filter edges, search, Show all, zone detail links, map button, Back and planned levels.")
''')
