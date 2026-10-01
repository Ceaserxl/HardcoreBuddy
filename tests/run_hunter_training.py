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
assert(#card.blocks==2 and card.note:find("temporary tame",1,true))
local claw,growl=card.blocks[1],card.blocks[2]
assert(claw.title=="Claw | Rank 3" and claw.titleColor[1]>claw.titleColor[2])
assert(claw.body:find("Black Bear Patriarch",1,true) and claw.body:find("Loch Modan",1,true))
assert(growl.title=="Growl | Rank 3" and growl.body:find("pet trainer",1,true))
assert(claw.action.kind=="rank" and claw.action.id=="claw" and claw.action.index==3)
context.petLevel=10
assert(H.Card(context).blocks[1].title=="Claw | Rank 2")
context.petLevel=20; context.level=15
assert(H.Card(context).blocks[1].title=="Claw | Rank 2")
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
assert(H.Card(context).blocks[1].title=="Claw | Rank 3")
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
assert(A.document.cards[1].blocks[1].title=="Claw | Rank 3")
local r,g=unpack(A.window.cards[1].content.blocks[1].title.color)
assert(r>g,"Missing available rank is rendered red")
GetSpellBookItemName=function() return "Claw","Rank 3" end
MOCK.FireAll("PET_BAR_UPDATE")
assert(A.document.cards[1].blocks[1].title=="Claw | Rank 3")
local r,g=unpack(A.window.cards[1].content.blocks[1].title.color)
assert(g>r,"Learned available rank is rendered green")
A:Activate(A.document.cards[1].blocks[1].action)
assert(A.document.isDetail)
A:Back(); assert(A.state.filter=="Class")
A:Navigate("training")
assert(A.document.cards[1].title=="Overview")
assert(A.window.filters[1].active and A.window.filters[2].filter=="Pet Training")
local overview=A.document.cards[1]
assert(overview.blocks[1].title=="Before you pull")
assert(overview.blocks[2].title=="Shared cooldowns and Self Found")
for _,b in ipairs(overview.blocks) do assert(b.title~="Pet Training" and b.title~="Pet Guide") end
MOCK.Click(A.window.filters[2])
assert(A.state.filter=="Pet Training" and A.document.cards[1].title=="Pet training")
assert(A.window.filters[2].active and not A.window.filters[1].active)
assert(A.document.cards[1].blocks[1].title=="Train a new pet skill")
for _,b in ipairs(A.document.cards[1].blocks) do
    assert(not b.action or b.action.kind~="profession")
end
A:Activate(A.document.cards[1].blocks[1].action)
assert(A.document.isDetail and A.window.filters[2].active)
A:Back(); assert(A.state.filter=="Pet Training")
MOCK.Click(A.window.filters[1])
assert(A.document.cards[1].title==overview.title and A.window.filters[1].active)
MOCK.Click(A.window.filters[2])
assert(A.state.filter=="Pet Training" and A.window.filters[2].active)
MOCK.Click(A.window.filters[3]); assert(A.state.view=="petguide")
MOCK.Click(A.window.back); assert(A.state.view=="training" and A.document.cards[1].title=="Overview")
MOCK.Click(A.window.filters[4]); assert(A.state.detail.family=="bandage" and A.window.filters[4].active)
MOCK.class="MAGE"; A.lastClass=nil; A:Navigate("training")
assert(A.window.filters[2].filter=="First Aid" and A.document.cards[1].title=="Field advice")
MOCK.class="HUNTER"; A.lastClass=nil; A:Navigate("supplies"); A.state.filter="Class"; A:Refresh()
print("PASS: Separate Hunter Overview and Pet Training pages, navigation highlights, guide return and profession tabs.")
print("PASS: Actual/localized pet ranks, upgrades, tame sources, trainer skills, separate level gates, unknown/max ranks, preview, Class/All and pet-event refresh.")
''')
composite(lua.globals().MOCK['frames'],addon['window']).convert('RGB').save(ROOT/'docs/layout-previews/hunter-class-training.png')
