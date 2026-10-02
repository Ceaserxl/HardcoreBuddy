"""Profession overviews remain useful between unlocks and at maximum skill."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local snapshot
A.Professions.Read=function() return snapshot end
local function setSkills(skill,cap,known)
    snapshot={skills={bandage=skill,cooking=skill,dummy=0},baseSkills={bandage=skill,cooking=skill},
        maxSkills={bandage=cap,cooking=cap},known={}}
    for _,recipe in ipairs(A.Professions.recipes.bandage) do snapshot.known[recipe.spellId]=known end
    A.professions=snapshot
end
for _,state in ipairs({{0,0,false},{1,75,true},{49,75,true},{50,75,true},{125,150,true},
    {225,225,true},{225,300,true},{300,300,true},{150,225,false},{150,225}}) do
    setSkills(unpack(state))
    for _,tab in ipairs({"First Aid","Cooking"}) do
        A:Navigate("training")
        for _,button in ipairs(A.window.filters) do if button.filter==tab then MOCK.Click(button); break end end
        assert(A.state.filter==tab and not A.state.detail and not A:CanGoBack(),"Profession tabs open as root Companion pages")
        assert(A.document.professionPage and A.document.cards[1].title==tab and #A.document.cards>=2)
        for _,card in ipairs(A.document.cards) do assert(#card.blocks>0,"No empty profession sections") end
        assert(A.document.cards[1].note:find(state[1]==0 and "Not learned" or "Skill ",1,true))
        if state[1]==49 then assert(A.document.cards[1].blocks[1].title:find("Journeyman",1,true),"Show upcoming training before eligibility") end
        if state[2]==300 then assert(A.document.cards[1].blocks[1].title:find(state[1]==300 and "Maximum" or "Artisan",1,true),"Completed training has an explicit status") end
        local root=A.state
        local action=A.document.cards[2].blocks[1].action
        assert(action,"Recommended supplies open their details")
        A:Activate(action); assert(A:CanGoBack())
        A:Back(); assert(A.state==root,"Supply details return to the profession tab")
    end
end
setSkills(nil,nil,nil)
for _,tab in ipairs({"First Aid","Cooking"}) do
    A.state={view="training",filter=tab}; A:Refresh(true)
    assert(A.document.cards[1].note:find("Skill unavailable",1,true))
    assert(A.document.cards[1].blocks[1].title=="Profession data unavailable")
end
setSkills(125,150,true)
local context=A:GetContext()
context.faction="Alliance"
assert(A.Professions.NextTraining(context,"cooking").body:find("Shandrina",1,true))
context.faction="Horde"
assert(A.Professions.NextTraining(context,"cooking").body:find("Wulan",1,true))
context.faction=nil
assert(not A.Professions.NextTraining(context,"cooking").body:find("Wulan",1,true))
setSkills(225,225,true)
context=A:GetContext(); context.characterLevel=34; context.level=60
assert(not A.Professions.NextTraining(context,"bandage").requirementsMet,"Preview levels do not bypass actual character requirements")
for _,tab in ipairs({"First Aid","Cooking"}) do
    local action=A.Companion.TabAction(tab)
    assert(action.view=="training" and action.filter==tab,"Overview links match sidebar destinations")
end
print("PASS: First Aid/Cooking root navigation, recommendations, unknown/unlearned/intermediate/max skills, faction routes and real-level training gates.")
''')
