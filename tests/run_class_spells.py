"""Bundled nine-class training, restrictions, live UI and asynchronous spell data."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local race=1
function UnitRace() return "Human","Human",race end
function GetSpellInfo(id) return "Spell "..id,"Rank 2",135846 end
local function build(class,level,all,faction,query,mode)
    return A.ClassSpells.Build({characterClass=class,level=level,faction=faction or "Alliance",mode=mode or "live"},
        {showAllFutureSpells=all,query=query})
end
local function ids(doc)
    local result={}
    for _,card in ipairs(doc.cards) do for _,row in ipairs(card.blocks) do if row.spellId then result[row.spellId]=row end end end
    return result
end
local count,classes=0,0
for class,levels in pairs(A.Data.ClassSpells) do
    classes=classes+1
    local seen={}
    for level,entries in pairs(levels) do
        assert(level>=1 and level<=60)
        for _,entry in ipairs(entries) do
            assert(not seen[entry.id],"No duplicate trainer spell")
            seen[entry.id]=true; count=count+1
        end
    end
    for level=1,60 do
        local nextDoc,allDoc=build(class,level),build(class,level,true)
        assert(nextDoc.pages==1 and allDoc.continuous)
        assert(nextDoc.total<=allDoc.total)
        local nextLevel
        for _,row in pairs(ids(nextDoc)) do
            assert(row.level>level and row.level<=60 and row.icon==135846)
            nextLevel=nextLevel or row.level; assert(row.level==nextLevel)
            assert(row.title:find("Rank 2",1,true))
        end
        for _,row in pairs(ids(allDoc)) do
            assert(row.level>level and (not nextLevel or row.level>=nextLevel))
        end
        if level==60 then assert(allDoc.total==0 and nextDoc.total==0) end
    end
end
assert(classes==9 and count==1324)
assert(build("Mage",40).cards[1].title=="Next training: level 42")
local alliance,horde=ids(build("Mage",19,true)),ids(build("Mage",19,true,"Horde"))
assert(alliance[3561] and not alliance[3567] and horde[3567] and not horde[3561],"Faction teleport spells")
local human=ids(build("Priest",1,true)); race=4
local nightElf=ids(build("Priest",1,true))
assert(human[19236] and not human[19296] and nightElf[19296] and not nightElf[19236],"Racial spells")
assert(ids(build("Mage",23))[12505].body:find("Requires talent: Spell 11366",1,true))
assert(build("Mage",40,false,nil,"no matching text").total==0)
assert(build("Mage",40,false,nil,nil,"preview").cards[1].note:find("Planned level 40",1,true))
for _,class in ipairs({"MAGE","HUNTER","WARRIOR"}) do
    MOCK.class=class; MOCK.level=40; A.db.profile.mode="live"; A.lastClass=nil; A:Navigate("training")
    local tab
    for _,button in ipairs(A.window.filters) do if button.filter=="Spells" then tab=button end end
    assert(tab and tab:IsVisible()); MOCK.Click(tab)
    assert(A.state.filter=="Spells" and A.document.cards[1].title:find("Next training"))
    assert(A.window.atLevel:IsShown() and A.window.atLevel.label:GetText()=="Show all future spells")
    local total=A.document.total
    MOCK.Click(A.window.atLevel)
    assert(A.state.showAllFutureSpells and A.document.total>total and A.window.atLevel.label:GetText()=="Next training level")
    MOCK.Click(A.window.atLevel); assert(not A.state.showAllFutureSpells and A.document.total==total)
end
-- Missing spell data is requested once, then refreshes only the visible Spells page.
local requests,loaded={},{}
C_Spell={GetSpellInfo=function(id) if loaded[id] then return {name="Loaded "..id,iconID=135846} end end,
    GetSpellSubtext=function() return "Rank 3" end,
    RequestLoadSpellData=function(id) requests[id]=(requests[id] or 0)+1 end}
local missing=build("Mage",40); build("Mage",40)
local first=next(ids(missing))
assert(first and requests[first]==1 and ids(missing)[first].title:find("loading",1,true))
loaded[first]=true; A.needsRefresh=false; MOCK.FireAll("SPELL_DATA_LOAD_RESULT",first,true)
assert(A.needsRefresh and ids(build("Mage",40))[first].title=="Loaded "..first.." | Rank 3")
local failed
for id in pairs(requests) do if id~=first then failed=id; break end end
MOCK.FireAll("SPELL_DATA_LOAD_RESULT",failed,false); build("Mage",40)
assert(requests[failed]==1,"Failed spell requests do not loop")
A:Navigate("supplies"); A.needsRefresh=false
MOCK.FireAll("SPELL_DATA_LOAD_RESULT",failed,true); assert(not A.needsRefresh)
print("PASS: 1324 spell entries; all 9 classes across levels 1-60; faction/race/talent labels; search, planning, navigation and lazy loading.")
''')
