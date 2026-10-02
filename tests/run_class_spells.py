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
        for index,card in ipairs(nextDoc.cards) do
            local expanded=allDoc.cards[index]
            assert(expanded and expanded.title==card.title and #expanded.blocks==#card.blocks,
                "Expanding appends later sections without replacing next training")
            for i,row in ipairs(card.blocks) do
                assert(expanded.blocks[i].title==row.title and expanded.blocks[i].body==row.body,
                    "Next-training rows stay unchanged when expanded")
            end
        end
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
assert(build("Mage",40).cards[1].title=="Next training: Level 42")
assert(#build("Mage",40).cards==1 and #build("Mage",40).cards[1].blocks>0)
local alliance,horde=ids(build("Mage",19,true)),ids(build("Mage",19,true,"Horde"))
assert(alliance[3561] and not alliance[3567] and horde[3567] and not horde[3561],"Faction teleport spells")
local human=ids(build("Priest",1,true)); race=4
local nightElf=ids(build("Priest",1,true))
assert(human[19236] and not human[19296] and nightElf[19296] and not nightElf[19236],"Racial spells")
assert(ids(build("Mage",23))[12505].body:find("Requires talent: Spell 11366",1,true))
assert(build("Mage",40,false,nil,"no matching text").total==0)
assert(build("Mage",40,false,nil,nil,"preview").cards[1].note==nil)
local hunterPets=A.ClassSpells.PetEntries({characterClass="Hunter"})
local ranks,petRanks={},0
for level,entries in pairs(hunterPets) do
    for _,row in ipairs(entries) do
        assert(level>=10 and level<=60 and row.level==level)
        local key=row.action.id..":"..row.action.index
        assert(not ranks[key],"Each Hunter pet rank appears once")
        ranks[key]=row; petRanks=petRanks+1
        assert(row.icon and row.meta and row.body:find("training points",1,true))
    end
end
assert(ranks["screech:1"] and ranks["growl:1"] and ranks["greatstamina:10"],"Tamed and trainer ranks are covered")
assert(ranks["screech:1"].body:find("Tame ",1,true) and ranks["growl:1"].body:find("Pet trainer",1,true))
local expected=0
for _,ability in ipairs(A.Data.PetGuide.abilities) do
    for _,rank in ipairs(ability.ranks) do if rank.trainer or #rank.sources>0 then expected=expected+1 end end
end
assert(petRanks==expected,"All Hunter ranks with verified training sources are included")
local hunter=build("Hunter",9)
local nextPets=0
for _,card in ipairs(hunter.cards) do for _,row in ipairs(card.blocks) do if row.action and row.action.kind=="rank" then nextPets=nextPets+1; assert(row.level==10) end end end
assert(nextPets>0,"Next-level view includes Hunter pet unlocks")
local grimoires,bookIDs=0,{}
for level,entries in pairs(A.Data.DemonGrimoires) do
    for _,entry in ipairs(entries) do
        assert(level>=4 and level<=60 and entry.id and entry.itemId and entry.family)
        assert(not bookIDs[entry.itemId],"Shared Succubus/Incubus books are not duplicated")
        bookIDs[entry.itemId]=entry; grimoires=grimoires+1
    end
end
assert(grimoires==59 and bookIDs[16375].family=="Succubus / Incubus")
local warlock=ids(build("Warlock",3))
assert(warlock[6307] and warlock[6307].itemId==16321 and warlock[6307].body:find("Imp",1,true))
assert(ids(build("Warlock",39))[7811].body:find("Voidwalker",1,true))
assert(ids(build("Warlock",31))[19478].body:find("Felhunter",1,true))
assert(not ids(build("Mage",3,true))[6307],"Pet spells do not leak to other classes")
assert(build("Warlock",30,true,nil,"Incubus").total>0,"Search includes demon family")
assert(build("Hunter",10,true,nil,"Screech").total>0,"Search includes tame skills")
print("PASS: "..petRanks.." Hunter pet ranks with trainer/taming sources and 59 unique Warlock grimoires; separate next-level/all-future pet sections.")
for _,class in ipairs({"MAGE","HUNTER","WARRIOR"}) do
    MOCK.class=class; MOCK.level=40; A.db.profile.mode="live"; A.lastClass=nil; A:Navigate("training")
    local tab
    for _,button in ipairs(A.window.filters) do if button.filter=="Spells" then tab=button end end
    assert(tab and tab:IsVisible()); MOCK.Click(tab)
    assert(A.state.filter=="Spells" and A.document.cards[1].title:find("Next training"))
    assert(A.window.atLevel:IsShown() and A.window.atLevel.label:GetText()=="Show all future spells")
    for _,card in ipairs(A.window.cards) do if card:IsShown() and card.spellHeaders then
        assert(#card.spellHeaders==4,"Spell tables have four columns")
        for _,row in ipairs(card.content.blocks) do if row:IsShown() and row.block.spellColumns then
            assert(row:GetHeight()==32 and row.icon:GetWidth()==24 and #row.spellCells==4,"Compact spell rows retain native icons")
        end end
    end end
    local total=A.document.total
    local firstTitle=A.document.cards[1].title
    local firstRow=A.window.cards[1].content.blocks[1]
    local beforeX,beforeY=firstRow:GetRect()
    MOCK.Click(A.window.atLevel)
    assert(A.state.showAllFutureSpells and A.document.total>total and A.window.atLevel.label:GetText()=="Hide future spells")
    local afterX,afterY=A.window.cards[1].content.blocks[1]:GetRect()
    assert(A.document.cards[1].title==firstTitle and afterX==beforeX and afterY==beforeY,"Expanding keeps the heading and first row in place")
    MOCK.Click(A.window.atLevel); assert(not A.state.showAllFutureSpells and A.document.total==total)
    A.window.atLevel.scripts.OnLeave(A.window.atLevel)
    assert(A.window.atLevel.active==false and A.window.atLevel.skinButton.active==false,"Collapsed future spells clear selected styling")
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
