import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
lua.execute('''
local A=TestAddon
local H=A.HunterTraining
local context={characterClass="Hunter",level=20,petLevel=20,mode="live",faction="Alliance"}
UnitExists=function(unit) return unit=="pet" end
HasPetSpells=function() return 3 end
GetSpellInfo=function(id) if id==16827 then return "Griffe" elseif id==2649 then return "Grondement" end end
GetSpellBookItemName=function(slot,book)
    assert(book=="pet")
    if slot==1 then return "Griffe","Rang 2" elseif slot==2 then return "Grondement","Rang 1" end
    return "Attack",""
end
local snapshot=H.Read()
assert(snapshot.available and snapshot.spells.claw.rank==2 and snapshot.spells.growl.rank==1)
local card=H.Card(context)
assert(#card.blocks==3)
local claw,growl=card.blocks[1],card.blocks[2]
assert(claw.title:find("Current: Rank 2",1,true) and claw.title:find("Upgrade: Rank 3",1,true))
assert(claw.body:find("Black Bear Patriarch",1,true) and claw.body:find("Loch Modan",1,true))
assert(growl.title:find("Upgrade: Rank 3",1,true) and growl.body:find("pet trainer",1,true))
assert(claw.action.kind=="rank" and claw.action.id=="claw" and claw.action.index==3)
context.petLevel=10
assert(H.Card(context).blocks[1].title:find("Next: Rank 3",1,true))
context.petLevel=20; context.level=15
assert(not H.Card(context).blocks[1].title:find("Upgrade:",1,true))
context.level=20
local calls=0
HasPetSpells=function() calls=calls+1; return 3 end
context.mode="preview"
assert(H.Card(context).note:find("Return",1,true) and calls==0)
context.mode="live"
UnitExists=function() return false end
assert(H.Card(context).note:find("Summon",1,true))
UnitExists=function() return true end
HasPetSpells=function() return nil end
assert(not H.Read().available)
HasPetSpells=function() return 1 end
GetSpellBookItemName=function() return "Claw",nil end
assert(H.Card(context).blocks[1].title:find("rank unknown",1,true))
GetSpellBookItemName=function() return "Claw","Rank 8" end
assert(H.Card(context).blocks[1].body=="Highest listed rank learned.")
GetSpellBookItemName=function() return "Claw","Rank 2" end
local doc=A.Companion.Build(context,{view="supplies",filter="Class"})
assert(doc.cards[1].title=="Pet spell upgrades")
local all=A.Companion.Build(context,{view="supplies",filter="All"})
local found=false
for _,c in ipairs(all.cards) do if c.title=="Pet spell upgrades" then found=true end end
assert(found)
context.characterClass="Mage"
assert(#A.Companion.Build(context,{view="supplies",filter="Class"}).cards==1)
MOCK.class="HUNTER"; MOCK.level=20
UnitLevel=function(unit) return 20 end
A:SetProfile("mode","live"); A:Navigate("supplies")
A.state.filter="Class"; A:Refresh()
assert(A.document.cards[1].blocks[1].title:find("Rank 2",1,true))
GetSpellBookItemName=function() return "Claw","Rank 3" end
MOCK.FireAll("PET_BAR_UPDATE")
assert(A.document.cards[1].blocks[1].title:find("Current: Rank 3",1,true))
A:Activate(A.document.cards[1].blocks[1].action)
assert(A.document.isDetail)
A:Back(); assert(A.state.filter=="Class")
print("PASS: Actual/localized pet ranks, upgrades, tame sources, trainer skills, separate level gates, unknown/max ranks, preview, Class/All and pet-event refresh.")
''')
composite(lua.globals().MOCK['frames'],addon['window']).convert('RGB').save(ROOT/'docs/layout-previews/hunter-class-training.png')
