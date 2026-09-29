"""Actual TOC boot: instance routing, guide coverage, navigation, and pooled UI."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

ROOT = Path(__file__).resolve().parents[1]
lua, addon = boot()
lua.execute("""
local A,I,D=TestAddon,TestAddon.Instances,TestAddon.Data.Instances
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local function click(frame)
    local x,y,w,h=frame:GetRect()
    check(MOCK.HitTest(x+w/2,y+h/2)==frame,"Control covered: "..(frame.filter or "current instance"))
    MOCK.Click(frame)
end
local function nav(label)
    for _,button in ipairs(A.window.filters) do
        if button:IsShown() and button.filter==label then click(button); return end
    end
    error("Missing navigation: "..label)
end
local function allText(value)
    local out={}
    local function visit(v)
        if type(v)=="string" then out[#out+1]=v
        elseif type(v)=="table" then for key,child in pairs(v) do if key~="action" then visit(child) end end end
    end
    visit(value); return table.concat(out," ")
end
local function instance(map,kind,name)
    IsInInstance=function() return map~=nil,kind end
    GetInstanceInfo=function() return name,kind,1,"Normal",40,0,false,map end
    MOCK.Fire("PLAYER_ENTERING_WORLD")
end
local dungeonCount,raidCount,ids=0,0,{}
local expectedMaps={[389]=1,[43]=1,[36]=1,[33]=1,[34]=1,[48]=1,[90]=1,[47]=1,[189]=4,[129]=1,
    [70]=1,[209]=1,[349]=3,[109]=1,[230]=1,[229]=2,[429]=3,[289]=1,[329]=2,
    [409]=1,[249]=1,[469]=1,[309]=1,[509]=1,[531]=1,[533]=1}
for map,count in pairs(expectedMaps) do check(#I.byMap[map]==count,"Missing map or wing: "..map) end
for _,g in ipairs(D.guides) do
    check(not ids[g.id],"Duplicate guide ID"); ids[g.id]=true
    if g.kind=="raids" then raidCount=raidCount+1 else dungeonCount=dungeonCount+1 end
    check(g.low<=g.high and g.high<=60,"Invalid Classic level band")
    for _,id in ipairs(g.pack) do
        check(D.tools[id]~=nil,"Missing pack item")
        check(D.uses[g.id] and D.uses[g.id][id],"Missing item use for "..g.id.." / "..id)
    end
end
check(dungeonCount==28 and raidCount==7,"Classic coverage")
for id,t in pairs(D.tools) do check(t.itemId==id and t.icon and #t.description>15,"Item description/icon missing") end

-- Directory tiles, not just direct model calls, lead to the correct guide.
A:Navigate("dungeons")
local tile=A.window.cards[1].content.blocks[1].columns[1].blocks[1]
click(tile)
check(A.state.instance=="rfc","Directory tile opened wrong guide")
A:Back()
check(A.document.total==28,"Directory Back did not restore")

-- Every instance opens directly to levels and packing, with working supply links.
instance(nil,"none","World")
MOCK.class="HUNTER"; MOCK.level=60; A:SetProfile("mode","live")
for _,g in ipairs(D.guides) do
    A:Navigate(g.kind); A:Activate({kind="instance",id=g.id})
    check(A.state.instance==g.id and A.document.guide.id==g.id,"Wrong selected instance")
    check(A.document.pages==1 and A.document.continuous,"Packing list was paginated away")
    check(#A.document.cards>=1 and #A.document.cards<=2,"Packing list grew extra sections")
    check(A.document.cards[1].note:find(tostring(g.low),1,true),"Level range missing")
    local text=allText(A.document.cards)
    for _,title in ipairs({"Dangerous mobs","Bosses","WATCH FOR","Before you enter","Route at a glance","First time here?"}) do
        check(not text:find(title,1,true),"Removed section remains: "..title)
    end
    for _,id in ipairs(g.pack) do
        check(text:find(D.tools[id].name,1,true),"Packing item missing")
        check(text:find(D.uses[g.id][id],1,true),"Mob-specific use is not visible")
    end
    check(A.window.scroll:GetHeight()>250,"Chrome crowds packing list")
    check(A.window.content:GetHeight()>=A.window.cards[1]:GetHeight(),"Content cannot scroll")
    for _,b in ipairs(A.window.filters) do if b:IsShown() then
        check(b.label:GetStringHeight()<=b.label:GetHeight()+1,"Sidebar label clipped")
        check(b.filter~="Overview" and b.filter~="Bosses" and b.filter~="Dangerous mobs" and b.filter~="First run" and b.filter~="First raid","Detailed sidebar remains")
    end end
    click(A.window.cards[1].content.blocks[1].columns[1].blocks[1])
    check(A.state.view=="supplies" and A.state.filter=="Potions","Essentials link failed")
    A:Back(); check(A.state.instance==g.id,"Supply Back lost instance")
    nav(g.kind=="raids" and "All raids" or "All dungeons")
    check(not A.state.instance and A.document.total==(g.kind=="raids" and 7 or 28),"Back to directory")
end
A:Navigate("dungeons"); A:Activate({kind="instance",id="rfc"}); nav("High levels")
check(not A.state.instance and A.document.total>0,"Level filter did not exit packing list")

local ctx=A:GetContext()
local function count(view,filter,query)
    return I.Build(ctx,{view=view,filter=filter,query=query}).total
end
check(count("dungeons","All dungeons","Gnomeregan")==1,"Instance search")
check(count("dungeons","All dungeons","Feralas")==3,"Zone search")
check(count("dungeons","All dungeons","zzzzno")==0,"Search empty state")
check(count("raids","20 players")==2 and count("raids","40 players")==5,"Raid size filters")
check(count("dungeons","Early levels")+count("dungeons","Mid levels")+count("dungeons","High levels")==28,"Level filters cover all dungeons")

-- Exact map identity, not localized name; multiple wings never guessed.
for map,expected in pairs(expectedMaps) do
    local g=I.byMap[map][1]
    instance(map,g.kind=="raids" and "raid" or "party","Localized instance "..map)
    check(I.Current().map==map,"Instance ID read from wrong API return slot")
    A:Navigate("supplies")
    check(A.window.currentInstance:IsShown(),"Current section missing outside guides")
    click(A.window.currentInstance)
    check(A.state.view==g.kind,"Wrong current tab")
    if expected==1 then check(A.state.instance==g.id,"Current guide did not open")
    else check(not A.state.instance and A.document.total==expected,"Ambiguous wing was guessed") end
    A:Back(); check(A.state.view=="supplies","Current button broke Back")
end
instance(99999,"raid","Unknown raid")
click(A.window.currentInstance)
check(A.state.unknownInstance and A.document.total==0,"Unknown instance incorrectly mapped")
nav("All raids"); check(A.document.total==7,"Cannot leave unsupported instance page")
instance(1234,"pvp","Battleground")
check(not A.window.currentInstance:IsShown(),"PvP incorrectly shown as raid")
instance(nil,"none","World")
check(not A.window.currentInstance:IsShown(),"Current section remains after exit")

-- The global strip also fits the non-guide pages, including alert controls.
instance(36,"party","The Deadmines")
for _,view in ipairs({"supplies","training","petguide","deaths","alerts"}) do
    A:Navigate(view)
    local x,y,w,h=A.window.currentInstance:GetRect()
    local sx,sy,sw,sh=A.window.sidebar:GetRect()
    check(y+h<=sy,"Current strip overlaps sidebar")
    if view=="alerts" then
        local px,py,pw,ph=A.LowHealth.page.volume:GetRect()
        check(py+ph<sy+sh,"Current strip pushes volume beyond page")
    elseif view=="deaths" then
        local dx,dy=A.Deaths.host:GetRect()
        check(dy>=y+h,"Current strip overlaps death journal")
    end
end
instance(nil,"none","World")

-- Preview must never change actual location detection; zone event updates it.
A:SetProfile("mode","preview")
instance(189,"party","Scarlet Monastery")
click(A.window.currentInstance)
check(A.document.total==4,"Preview overrides actual location")
A:Activate({kind="instance",id="sm-library"})
A:SetProfile("characterClass","Mage")
check(A.state.instance=="sm-library","Planning class change loses selected guide")
IsInInstance=function() return false,"none" end
MOCK.Fire("ZONE_CHANGED_NEW_AREA")
check(not A.window.currentInstance:IsShown(),"Zone event did not clear current section in preview")
check(A.state.instance=="sm-library","Zone change stole selected guide")

-- Bag data is live; unavailable is never shown as zero. Equipped cloak is explicit.
ctx.mode="live"; ctx.level=60; ctx.inventory={available=true,counts={[19183]=7}}
local pack=I.Build(ctx,{view="raids",instance="bwl",filter="Items"})
check(allText(pack.cards):find("In bags: 7",1,true),"Real bag count missing")
GetInventoryItemID=function(unit,slot) check(unit=="player" and slot==15,"Wrong cloak slot"); return 15138 end
pack=I.Build(ctx,{view="raids",instance="bwl",filter="Items"})
check(allText(pack.cards):find("Equipped",1,true),"Equipped cloak shown as missing")
ctx.inventory.available=false
pack=I.Build(ctx,{view="raids",instance="bwl",filter="Items"})
check(allText(pack.cards):find("Bag count unavailable",1,true),"Unknown inventory published as empty")
ctx.level=20; ctx.mode="preview"
pack=I.Build(ctx,{view="raids",instance="bwl",filter="Items"})
check(allText(pack.cards):find("Requires level 55",1,true),"Level requirement not shown")
check(not allText(pack.cards):find("Equipped",1,true),"Preview implies actual gear is equipped on planned character")

-- Pools reset their paint, fonts and borders when returning to supplies.
A:SetProfile("mode","live"); A:Navigate("supplies")
local supply=A.window.cards[1].content.blocks[1]
check(not supply.block.guideTone and supply.body.fontSize==11,"Guide style leaked into supply row")
check(supply:GetHeight()==46,"Supply row geometry changed")
GetInstanceInfo=nil
check(I.Current()==nil,"Missing instance API fallback")
print("PASS: "..checks.." instance assertions; 35 compact packing lists, current routing, search, navigation, inventory and pooled layout.")
""")
