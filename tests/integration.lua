local A=TestAddon
local healId,drinkId
for _,r in ipairs(A.Planner.BuildList("Hunter",32).rows) do
    if r.family=="healing" then healId=r.itemId end
    if r.family=="drink" then drinkId=r.itemId end
end
MOCK.bags={[0]={{itemID=healId,stackCount=2},{itemID=drinkId,stackCount=20}},[1]={{itemID=healId,stackCount=1}},[-1]={{itemID=healId,stackCount=100}}}
C_Container={
    GetContainerNumSlots=function(bag) return bag==0 and 16 or (MOCK.bags[bag] and 16 or 0) end,
    GetContainerItemInfo=function(bag,slot) return MOCK.bags[bag] and MOCK.bags[bag][slot] end,
}
NUM_BAG_SLOTS,KEYRING_CONTAINER=4,-2
MOCK.Fire("ADDON_LOADED","AnotherAddon")
assert(not A.db)
MOCK.Fire("ADDON_LOADED","HardcoreBuddy")
assert(A.db==HardcoreBuddyDB and A.db.profile.characterClass=="Hunter" and A.db.profile.level==1)
assert(not A.window and #MOCK.messages==0)
assert(A.minimap and A.minimap:IsShown())
MOCK.Click(A.minimap); assert(A.window:IsShown())
MOCK.Click(A.minimap); assert(not A.window:IsShown())
A.minimap.scripts.OnEnter(A.minimap); assert(GameTooltip:NumLines()==4)
A.minimap.scripts.OnDragStart(A.minimap)
Minimap.scale=0.8
local mx,my=Minimap:GetCenter()
MOCK.cursorX=(mx+100)*0.8; MOCK.cursorY=my*0.8
A.minimap.scripts.OnUpdate(A.minimap)
assert(math.abs(A.db.minimapAngle)<0.0001)
Minimap.scale=1
A.minimap.scripts.OnDragStop(A.minimap)
MOCK.Click(A.minimap); assert(not A.window:IsShown())
MOCK.time=2
MOCK.Click(A.minimap); assert(A.window:IsShown())
MOCK.Click(A.minimap); assert(not A.window:IsShown())
assert(not A.minimap.scripts.OnUpdate)
SlashCmdList.HARDCOREBUDDY("")
local f=A.window
assert(f:GetWidth()==1040 and f:GetHeight()==660 and not f:IsResizable() and f.resize==nil)
assert(f:IsShown() and A.document.context.mode=="live")
assert(A.document.context.mode=="live" and A.document.context.level==32 and A.document.context.petLevel==20)
assert(not f.class.enabled and not f.plus.enabled)
local hp=A.Planner.HunterPlan(32,20)
assert(hp.abilities.screech.current.rank==1)
MOCK.pet=false
MOCK.Fire("UNIT_PET","player")
assert(A.document.context.petLevel==nil)
MOCK.pet=true; MOCK.petLevel=24
MOCK.Fire("UNIT_PET","player")
MOCK.Fire("PLAYER_LEVEL_UP",33)
assert(A.document.context.level==33)
MOCK.level=33; MOCK.Fire("PLAYER_XP_UPDATE","player")
assert(A.levelOverride==nil and A.document.context.level==33)
MOCK.Click(f.mode)
assert(A.document.context.level==33 and A.document.context.mode=="preview")
A:SetLevel(999); assert(A.db.profile.level==60)
A:SetLevel(-5); assert(A.db.profile.level==1)
f.level:SetFocus(); f.level:SetText("999"); f.level.scripts.OnEnterPressed(f.level)
assert(A.db.profile.level==60 and not f.level:HasFocus())
f.level:SetFocus(); f.level:SetText(""); f.level:ClearFocus()
assert(A.db.profile.level==1)
f.level.scripts.OnArrowPressed(f.level,"UP"); assert(A.db.profile.level==2)
f.level:SetFocus(); f.level:SetText("50"); MOCK.Click(f.plus)
assert(A.db.profile.level==51 and not f.level:HasFocus())
f.level:SetFocus(); f.level:SetText("40"); MOCK.Click(f.minus)
assert(A.db.profile.level==39)
-- Main page is the supply list with real quantities and no extra landing menu.
A:SetProfile("characterClass","Hunter"); A:SetLevel(32); A:SetProfile("mode","live")
MOCK.level=32; MOCK.Fire("PLAYER_ENTERING_WORLD")
assert(A.state.view=="supplies" and A.document.cards[1].supplyTable and f.tabs[1]:IsShown())
assert(not f.search:IsShown() and not f.searchLabel:IsShown() and not f.clear:IsShown(),"Supplies still exposes search controls")
assert(not f.missing or not f.missing:IsShown(),"Supplies still exposes Missing-only")
assert(not f.stockPanel or not f.stockPanel:IsShown(),"Supplies still shows the removed stock summary strip")
local function findRow(id)
    for _,frame in ipairs(f.cards[1].content.blocks) do
        if frame:IsVisible() and frame.block.itemId==id then return frame end
    end
end
local function modelSupply(id,stock)
    local state={view="supplies",filter="All",stock=stock}
    local first=A.Companion.Build(A:GetContext(),state)
    for page=1,first.pages do
        state.page=page
        for _,card in ipairs(A.Companion.Build(A:GetContext(),state).cards) do for _,block in ipairs(card.blocks) do
            if block.itemId==id then return block end
        end end
    end
end
MOCK.Click(f.filters[5]); assert(A.state.filter=="Potions")
local healing=findRow(healId); assert(healing and healing.block.count==3 and healing.block.status=="low")
assert(healing.count:GetText()=="3" and healing.quantity:GetText()=="5")
healing.quantity:SetFocus(); healing.quantity:SetText("9"); healing.quantity.scripts.OnEnterPressed(healing.quantity)
assert(A.characterDB.targets[healId]==9 and findRow(healId).block.missing==6)
MOCK.bags[0][1].stackCount=9; MOCK.bags[1]={}
MOCK.Fire("BAG_UPDATE_DELAYED")
assert(findRow(healId).block.count==9 and findRow(healId).block.status=="ready")
assert(not modelSupply(healId,"Missing"))
assert(findRow(healId))
healing=findRow(healId)
-- Text/count/status portions of the item line show the native tooltip; Carry
-- keeps its editing help. Coordinate dispatch also checks decorative overlays.
local hx,hy,hw,hh=healing:GetRect()
for _,offset in ipairs({100,hw-180,hw-45}) do
    MOCK.HoverAt(hx+offset,hy+hh/2)
    assert(GameTooltip.hyperlink=="item:"..healId and GameTooltip:NumLines()>0 and GameTooltip.owner==healing)
end
healing.scripts.OnLeave(healing); assert(not GameTooltip:IsShown())
healing.iconHit.scripts.OnEnter(healing.iconHit)
assert(GameTooltip.hyperlink=="item:"..healId and GameTooltip:NumLines()>0)
for _,failure in ipairs({"missingItem","emptyItem"}) do
    MOCK[failure]=true
    for _,target in ipairs({healing,healing.iconHit}) do
        target.scripts.OnEnter(target)
        assert(GameTooltip:IsShown() and GameTooltip:NumLines()>0 and GameTooltip.lines[1]==healing.block.title,"Uncached native item has no readable fallback")
        target.scripts.OnLeave(target); assert(not GameTooltip:IsShown())
    end
    MOCK[failure]=nil
end
MOCK.Click(healing); assert(A.document.isDetail and f.back:IsShown())
assert(A.document.cards[1].blocks[1].count==9)
assert(f.refs==nil and A.references==nil and A.ShowReferences==nil,"Sources UI was not removed")
local beforeSources=A.document
SlashCmdList.HARDCOREBUDDY("sources")
assert(A.document==beforeSources and A.references==nil,"Removed Sources slash route remains active")
MOCK.Click(f.back); assert(A.state.filter=="Potions" and A.state.view=="supplies")
-- Zero turns off restocking; Escape cancels an unfinished target; blank restores defaults.
healing=findRow(healId); healing.quantity:SetFocus(); healing.quantity:SetText("0"); healing.quantity:ClearFocus(); A:Refresh()
assert(findRow(healId).block.status=="off")
healing=findRow(healId); healing.quantity:SetFocus(); healing.quantity:SetText("30"); healing.quantity.scripts.OnEscapePressed(healing.quantity)
assert(A.characterDB.targets[healId]==0)
healing=findRow(healId); healing.quantity:SetFocus(); healing.quantity:SetText(""); healing.quantity:ClearFocus(); A:Refresh()
assert(A.characterDB.targets[healId]==nil and findRow(healId).block.target==5)
A.characterDB.targets[tostring(healId)]=11
A:SetCarryTarget(healId,""); A:Refresh()
assert(A.characterDB.targets[tostring(healId)]==nil and findRow(healId).block.target==5)
-- Automatic anti-venom counts and filters use the exact learned item.
MOCK.Click(f.filters[6]); assert(A.state.filter=="Emergency")
local savedProfessions=A.professions
local anti=A.Professions.recipes.antivenom[1]
A.professions={available=true,skills={bandage=anti.craftSkill,dummy=0},known={[anti.spellId]=true}}
MOCK.bags[0][3]={itemID=6452,stackCount=1}; MOCK.Fire("BAG_UPDATE_DELAYED")
A:Activate({kind="supplyFamily",family="antivenom"})
local rank=findRow(6452)
assert(rank.block.itemId==6452 and not rank.choose:IsShown() and rank.quantity:IsShown())
MOCK.Click(f.back); assert(findRow(6452).block.count==1)
assert(modelSupply(6452,"Missing").missing==2)
A:SetCarryTarget(6452,0); A:Refresh(); assert(not modelSupply(6452,"Missing"))
assert(findRow(6452).block.status=="off")
A:SetCarryTarget(6452,3); A:Refresh()
A.professions=savedProfessions; A:Refresh()
MOCK.Click(f.filters[5]); assert(A.state.filter=="Potions")
-- Bank contents are not counted, bags refresh in Preview, and unknown never becomes missing.
MOCK.Click(f.mode); assert(A:GetContext().mode=="preview")
A:SetProfile("characterClass","Hunter"); A:SetLevel(32)
MOCK.bags[0][1].stackCount=2; MOCK.Fire("BAG_UPDATE_DELAYED")
assert(findRow(healId).block.count==2)
local container=C_Container; C_Container=nil; MOCK.Fire("BAG_UPDATE_DELAYED")
assert(findRow(healId).block.status=="unknown" and findRow(healId).block.count==nil)
C_Container=container; MOCK.Fire("BAG_UPDATE_DELAYED")
-- Planning responds to actual coordinate dispatch; stale saved sizes are ignored.
local function clickAt(frame)
    local x,y,w,h=frame:GetRect(); assert(MOCK.ClickAt(x+w/2,y+h/2)==frame)
end
local function overlaps(a,b)
    local ax,ay,aw,ah=a:GetRect(); local bx,by,bw,bh=b:GetRect()
    return ax<bx+bw and bx<ax+aw and ay<by+bh and by<ay+ah
end
for _,width in ipairs({480,680,1400}) do
    A.db.window.width,A.db.window.height=width,400
    A:RestoreWindow(); A:Layout()
    assert(f:GetWidth()==1040 and f:GetHeight()==660 and f:GetScale()==1)
    assert(not overlaps(f.drag,f.mode) and not overlaps(f.drag,f.close))
    local old=A.db.profile.mode; clickAt(f.mode); assert(A.db.profile.mode~=old)
    clickAt(f.mode); assert(A.db.profile.mode==old)
end
-- Hidden dropdown is closed when navigating; pet guide still works in detail.
MOCK.Click(f.class); assert(f.classMenu:IsShown())
A:Navigate("petguide"); assert(not f.classMenu:IsShown() and A.document.total==17)
MOCK.Click(f.nextPage); assert(A.document.page==2)
MOCK.Click(f.previous); assert(A.document.page==1)
MOCK.Click(f.filters[3]); assert(A.state.filter=="Pets" and A.document.total==559)
f.search:SetText("broken tooth"); f.search.scripts.OnTextChanged(f.search,true)
assert(A.document.total==1 and A.document.cards[1].blocks[1].title=="Broken Tooth")
MOCK.Click(f.cards[1].content.blocks[1]); assert(A.document.isDetail)
assert(A.document.cards[1].blocks[2].meta=="Rare")
MOCK.Click(f.back); assert(f.search:GetText()=="broken tooth")
MOCK.Click(f.clear); assert(A.document.total==559)
MOCK.Click(f.atLevel)
for _,b in ipairs(A.document.cards[1].blocks) do assert(A.Data.PetGuide.pets[b.action.index].maxLevel<=32) end
f.search:SetText("%["); f.search.scripts.OnTextChanged(f.search,true); assert(A.document.total==0)
MOCK.Click(f.clear)
A:Navigate("petguide"); A:Activate({kind="family",id="owl"}); A:Activate({kind="ability",id="screech"})
assert(A.document.total==4)
MOCK.Click(f.cards[1].content.blocks[1]); assert(A.document.cards[1].title=="Screech - Rank 1")
MOCK.Click(f.back); MOCK.Click(f.back); assert(A.document.cards[1].title=="Owls")
A:SetProfile("characterClass","Warlock"); assert(not f.tabs[3]:IsShown() and A.state.view=="supplies")
A:Navigate("training"); assert(A.document.cards[1].title=="Demon companion")
local function validateLayout()
    assert(f.scroll:GetHeight()>65)
    assert(not overlaps(f.drag,f.mode))
    for _,c in ipairs(f.cards) do if c.shown then assert(c:GetWidth()>0 and c:GetHeight()>0) end end
end
for _,faction in ipairs({"Alliance","Horde"}) do
    MOCK.faction=faction; MOCK.Fire("PLAYER_ENTERING_WORLD")
    for _,class in ipairs(A.Planner.classes) do
        A:SetProfile("characterClass",class)
        for _,view in ipairs({"supplies","training","petguide"}) do
            if view~="petguide" or class=="Hunter" then
                A:Navigate(view); A:Refresh(); validateLayout()
                assert(A:GetContext().faction==faction,"Planning did not retain the actual character faction")
            end
        end
    end
end
-- The visible profession detail follows skill/recipe events, the real faction,
-- and the real quest level without reopening the panel or clicking a rank.
local professionReader,professionSnapshot=A.Professions.Read,A.professions
local professionFixture={available=true,skills={bandage=180,dummy=100,cooking=125},
    baseSkills={bandage=180,dummy=100,cooking=125},maxSkills={bandage=225,dummy=150,cooking=150},known={}}
for family,recipes in pairs(A.Professions.recipes) do for _,recipe in ipairs(recipes) do
    professionFixture.known[recipe.spellId]=recipe.craftSkill<=(family=="dummy" and 100 or 150)
end end
A.Professions.Read=function() return professionFixture end
local function documentContains(fragment)
    local function contains(block)
        for _,field in ipairs({"title","body","meta"}) do if tostring(block[field] or ""):find(fragment,1,true) then return true end end
        for _,child in ipairs(block.blocks or {}) do if contains(child) then return true end end
        for _,column in ipairs(block.columns or {}) do for _,child in ipairs(column) do if contains(child) then return true end end end
    end
    for _,card in ipairs(A.document.cards) do if contains(card) then return true end end
    return false
end
MOCK.faction="Alliance"; MOCK.level=32; MOCK.Fire("SKILL_LINES_CHANGED")
A:SetProfile("mode","preview"); A:SetProfile("characterClass","Hunter"); A:SetLevel(55)
A:Activate({kind="supplyFamily",family="bandage"})
assert(documentContains("Heavy Silk Bandage - next recipe") and documentContains("Deneb Walker"))
assert(documentContains("Tradable recipe") and documentContains("AH listings not checked"))
professionFixture.known[7929]=true; MOCK.Fire("SPELLS_CHANGED")
assert(documentContains("Mageweave Bandage - next recipe") and not documentContains("Heavy Silk Bandage - next recipe"))
MOCK.faction="Horde"; MOCK.Fire("PLAYER_ENTERING_WORLD")
assert(documentContains("Balai Lok'Wein") and not documentContains("Deneb Walker"))
professionFixture.skills.bandage,professionFixture.baseSkills.bandage=225,225
professionFixture.known[10840]=true; MOCK.Fire("SKILL_LINES_CHANGED")
assert(documentContains("Triage") and documentContains("Doctor Gregory Victor"))
assert(documentContains("your character is level 32"),"Planned level bypassed the actual Triage quest level")
MOCK.faction=nil; MOCK.Fire("PLAYER_ENTERING_WORLD")
assert(not documentContains("Doctor Gregory Victor") and not documentContains("Doctor Gustaf VanHowzen"))
professionFixture.skills.bandage,professionFixture.baseSkills.bandage=0,0
MOCK.Fire("SKILL_LINES_CHANGED"); assert(documentContains("Learn First Aid"))
professionFixture.skills.bandage=nil; MOCK.Fire("SKILL_LINES_CHANGED")
assert(documentContains("First Aid skill unavailable"))
A.Professions.Read,A.professions=professionReader,professionSnapshot

-- All is one continuous, categorized list. Nothing vanishes at the old
-- twelve-row boundary, and category navigation keeps search/stock/faction.
A:SetProfile("characterClass","Hunter"); A:SetLevel(60); A:Navigate("supplies")
A.state.filter,A.state.query,A.state.stock,A.state.page="All","","All",5
A:Refresh()
assert(#A.document.cards==8 and A.document.continuous and A.document.page==1 and A.document.pages==1)
assert(not f.previous:IsShown() and not f.nextPage:IsShown() and not f.pageText:IsShown())
local expectedCategories={"Food & drink","Buffs","Potions","Emergency","Class","Scrolls","Optional","User"}
local grouped,total={},0
for index,category in ipairs(expectedCategories) do
    local card=A.document.cards[index]
    assert(card.title==category and card.supplyTable and f.cards[index]:IsShown())
    grouped[category]={}
    for rowIndex,block in ipairs(card.blocks) do
        assert(block.category==category and f.cards[index].content.blocks[rowIndex]:IsShown())
        grouped[category][#grouped[category]+1]=tostring(block.itemId)..":"..block.title
        total=total+1
    end
end
assert(total==A.document.total and total>12,"All supplies still truncates the list to one page")
for index,category in ipairs(expectedCategories) do
    MOCK.Click(f.filters[index+2])
    local actual={}
    for page=1,A.document.pages do
        for _,card in ipairs(A.document.cards) do for _,block in ipairs(card.blocks) do
            if block.supply then actual[#actual+1]=tostring(block.itemId)..":"..block.title end
        end end
        if page<A.document.pages then MOCK.Click(f.nextPage) end
    end
    assert(table.concat(actual,"|")==table.concat(grouped[category],"|"),"All category contents differ from that category's full list")
end
-- Model filtering remains covered without exposing hidden UI actions. Any
-- stale Supplies query/stock state is cleared so there is no invisible filter.
local filtered=A.Companion.Build(A:GetContext(),{view="supplies",filter="All",query="Elixir",stock="Missing"})
for _,card in ipairs(filtered.cards) do for _,block in ipairs(card.blocks) do
    if block.supply then assert(block.missing>0 and block.title:find("Elixir",1,true)) end
end end
MOCK.Click(f.filters[1]); A.state.query,A.state.stock="Elixir","Missing"; A:Refresh()
assert((A.state.query or "")=="" and (A.state.stock or "All")=="All","Removed controls leave a hidden Supplies filter active")
assert(not f.search:IsShown() and not f.clear:IsShown())
assert(f.missing==nil and f.stockPanel==nil)
local faction=A:GetContext().faction
MOCK.Click(f.filters[3]); MOCK.Click(f.filters[1])
assert((A.state.query or "")=="" and (A.state.stock or "All")=="All" and A:GetContext().faction==faction)
assert(A.document.page==1 and A.document.pages==1 and not f.nextPage:IsShown())

-- Craftable item details separate their effect, crafting skill, profession
-- rank, recipe route, AH access, materials and use level into rendered fields.
for _,example in ipairs({{8951,195,29},{9030,215,32}}) do
    local item
    for _,record in ipairs(A.Data.Items.items) do if record.itemId==example[1] then item=record; break end end
    assert(item)
    A:Activate({kind="item",item=item})
    local fields,rendered
    for cardIndex,card in ipairs(A.document.cards) do for index,block in ipairs(card.blocks) do
        if block.fields then fields=block.fields; rendered=f.cards[cardIndex].content.blocks[index]; break end
    end end
    assert(fields and rendered and not rendered.block.body,"Item details still concatenate crafting information into a paragraph")
    local byLabel={}
    for index,field in ipairs(fields) do
        byLabel[field.label]=field
        assert(rendered.fields[index]:IsShown() and rendered.fields[index].label:GetText()==field.label)
        assert(rendered.fields[index].value:GetText()==field.value)
    end
    for _,label in ipairs({"Effect","Crafting","Profession rank","Recipe source","Recipe AH","Finished item AH","Materials","Use level"}) do
        assert(byLabel[label] and byLabel[label].value~="","Missing explicit item detail field: "..label)
    end
    assert(byLabel.Crafting.value:find("Alchemy",1,true) and byLabel.Crafting.value:find(tostring(example[2]),1,true))
    assert(byLabel["Profession rank"].value:find("Expert",1,true))
    assert(byLabel["Use level"].value=="Level "..example[3])
    assert(f.sidebar:IsShown(),"Item detail lost sidebar navigation")
    MOCK.Click(f.filters[5]); assert(not A.document.isDetail and A.state.filter=="Potions" and #A.history==0)
end
A:Navigate("training")
for _,index in ipairs({2,3,4}) do
    MOCK.Click(f.filters[index])
    assert(A.document.isDetail and A.state.detail.kind=="profession" and f.sidebar:IsShown())
    assert(#A.history<=1,"Profession category navigation keeps stacking stale detail history")
end
MOCK.Click(f.filters[1]); assert(not A.document.isDetail and #A.history==0)

-- Faction and trainer/quest level always belong to the actual character,
-- including a planned class/level; unknown faction stays explicit.
MOCK.level=11; MOCK.faction="Horde"; MOCK.Fire("PLAYER_ENTERING_WORLD")
A:SetProfile("mode","preview"); A:SetProfile("characterClass","Hunter"); A:SetLevel(55)
assert(A:GetContext().level==55 and A:GetContext().characterLevel==11 and A:GetContext().faction=="Horde")
MOCK.faction=nil; MOCK.Fire("PLAYER_ENTERING_WORLD")
assert(A:GetContext().faction==nil and A:GetContext().factionUnknown)
A:SetProfile("mode","live")
assert(A:GetContext().faction==nil and A:GetContext().factionUnknown and A:GetContext().characterLevel==11)
MOCK.level=32; MOCK.faction="Alliance"; MOCK.Fire("PLAYER_ENTERING_WORLD")
A:SetProfile("mode","preview"); A:SetProfile("characterClass","Hunter"); A:SetLevel(32); A:Navigate("supplies")
A:SetCarryTarget(healId,8); A:Refresh()
A:SaveWindow(); f:Hide(); assert(not A.db.window.visible)
local saved=A.db; A:Initialize(); assert(A.db==saved and A.db.profile.level==32 and A.characterDB.targets[healId]==8)
SlashCmdList.HARDCOREBUDDY("reset"); assert(f:IsShown() and f:GetWidth()==1040 and f:GetHeight()==660)
UIParent.width,UIParent.height=800,600; MOCK.Fire("UI_SCALE_CHANGED")
assert(f:GetWidth()==1040 and f:GetHeight()==660 and f:GetScale()<1)
assert(f:GetWidth()*f:GetScale()<=776 and f:GetHeight()*f:GetScale()<=576)
A.db.window.x,A.db.window.y=47,-31; A:RestoreWindow(); A:SaveWindow()
assert(math.abs(A.db.window.x-47)<.001 and math.abs(A.db.window.y+31)<.001,"Scaled Save/Restore drifts the saved center offset")
A:RestoreWindow(); A:SaveWindow()
assert(math.abs(A.db.window.x-47)<.001 and math.abs(A.db.window.y+31)<.001,"Repeated scaled restore changes window position")
UIParent.width,UIParent.height=1920,1080; MOCK.faction="Alliance"
A.db.window={visible=true}; A:RestoreWindow(); A:SetProfile("detailed",false)
print('PASS: Real-position planning clicks, fixed 1040x660 geometry and small-screen scaling, whole-row native item tooltips with uncached fallback, removed Sources routes, live bag updates, editable targets, stock filters, Pet Guide, persistence and 38 class/view/faction layouts.')
