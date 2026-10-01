local A,F=TestAddon,GEAR_FIXTURES
local U,G=A.AuctionUpgrades,A.GearAdvisor
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
check(not U.panel,"Native Auction UI is optional at addon load")
local create=CreateFrame
CreateFrame=function(...)
    local f=create(...)
    function f:SetID(id) self.id=id end
    function f:GetID() return self.id end
    return f
end
AuctionFrame=CreateFrame("Frame","AuctionFrame",UIParent)
AuctionFrame:SetSize(832,447); AuctionFrame:SetPoint("TOPLEFT",40,-80); AuctionFrame.numTabs=7
AuctionFrameBrowse=CreateFrame("Frame","AuctionFrameBrowse",AuctionFrame)
for i=1,7 do
    local t=CreateFrame("Button","AuctionFrameTab"..i,AuctionFrame)
    t:SetID(i); t:SetSize(90,32); t:SetPoint("BOTTOMLEFT",(i-1)*75,25)
end
local clicks=0
function AuctionFrameTab_OnClick(tab) clicks=clicks+1; AuctionFrame.selectedTab=tab:GetID(); AuctionFrameBrowse:SetShown(tab==AuctionFrameTab1) end
function PanelTemplates_SetNumTabs(frame,num) frame.numTabs=num end
function PanelTemplates_EnableTab() end
function PanelTemplates_TabResize(tab) tab:SetSize(100,32) end
function PanelTemplates_SetTab(frame,index) frame.selectedTab=index end
function hooksecurefunc(name,callback)
    local previous=_G[name]; _G[name]=function(...) previous(...); callback(...) end
end
local queries,ready,pending={},true,false
local auctions,total={},0
local pages={}
function CanSendAuctionQuery() return ready end
function QueryAuctionItems(name,min,max,page,usable,quality,all,exact,filters)
    queries[#queries+1]={name=name,min=min,max=max,page=page,usable=usable,all=all,exact=exact,filters=filters}
    if filters then
        local data=pages[filters[1].classID] or {}
        auctions={}; total=#data
        for i=page*50+1,math.min(#data,(page+1)*50) do auctions[#auctions+1]=data[i] end
    end
    pending=true
end
function GetNumAuctionItems() return #auctions,total end
function GetAuctionItemInfo(_,index)
    local v=auctions[index]
    return v.item.name,123,v.count or 1,2,v.usable~=false,1,nil,v.minimum or 100,10,v.buyout or 0,v.bid or 0
end
function GetAuctionItemLink(_,index) local v=auctions[index]; return not v.noLink and v.item.link or nil end
local function tick(delta)
    MOCK.time=(MOCK.time or 0)+(delta or 0.1)
    U.events.scripts.OnUpdate(U.events,delta or 0.1)
end
local function finish()
    for i=1,1000 do
        tick()
        if pending then pending=false; MOCK.FireAll("AUCTION_ITEM_LIST_UPDATE") end
        if not U.scan then return end
    end
    error("Scan did not finish")
end
MOCK.FireAll("AUCTION_HOUSE_SHOW"); tick()
check(U.tab and U.tab.template=="AuctionTabTemplate","Uses the same native tab template as auction tools")
check(U.tab:GetID()==8 and AuctionFrame.numTabs==8,"Appends without replacing other addons' tabs")
local first=U.tab
MOCK.FireAll("AUCTION_HOUSE_SHOW"); tick(); check(U.tab==first,"No duplicate tab on reopen")
AuctionFrameTab_OnClick(U.tab)
check(U.panel:IsShown() and not AuctionFrameBrowse:IsShown(),"Native click handler selects upgrades")
check(clicks==1,"Existing native click handler remains intact")

F.reset("HUNTER",40,{31,0,0})
local old=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=10},4,3)
F.equip(1,old)
local good=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=15},4,1)
local best=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=20},4,2)
local down=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=5},4,3)
local future=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=100},4,1); future.required=50
local plate=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=100},4,4)
local ring=F.item("INVTYPE_FINGER",{ITEM_MOD_AGILITY_SHORT=10},4,0)
local suffix=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=16},4,1)
suffix.id=good.id; suffix.link=good.link:gsub(":%-15:",":-16:"); F.alias(suffix.link,suffix)
local sword=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=10},2,7,{{"(20.0 damage per second)"}})
pages[4]={{item=best,buyout=10000},{item=best,buyout=5000},{item=good,buyout=1000},{item=down},
    {item=future},{item=plate},{item=ring},{item=best,usable=false},{item=suffix}}
for i=1,51 do pages[4][#pages[4]+1]={item=down} end
pages[2]={{item=sword,buyout=12345}}
ready=false; U:Start(); tick()
check(#queries==0 and U.scan.phase=="query","Respects server query throttle")
ready=true; finish()
check(U.complete and #queries==3,"Scans both categories and every server page")
check(queries[1].filters[1].classID==4 and queries[2].page==1 and queries[3].filters[1].classID==2,"Armor and weapon query filters correct")
for _,q in ipairs(queries) do check(q.max==40 and q.usable and not q.all,"Only level-appropriate usable listings, no full-dump query") end
check(#U.results[1]==3,"Only upgrades, with duplicates and unusable items removed")
check(U.results[1][1].link==best.link and U.results[1][1].buyout==5000,"Best percentage first; duplicate keeps cheapest buyout")
check(U.results[1][1].auctions==2,"Duplicate listings counted once per item")
check(U.results[1][1].percent==G:Comparisons(G:Read(best.link),G:CurrentProfile())[1].percent,"Exact advisor percentage reused")
check(U.results[1][3].link==good.link,"Cloth upgrade compared against equipped mail")
check(U.results[1][2].link==suffix.link,"Different random suffixes of the same item remain separate")
check(U.results[11][1].percent==nil and U.results[12][1].percent==nil,"Empty ring slots get no fabricated percentage")
check(U.results[16] and U.results[17],"Dual-wield weapon compared in both hand slots")
check(#U.rows==7 and #U.display==17,"Reuses seven rows for the continuous slot list")
MOCK.Click(U.rows[1])
check(U.slot==1 and #U.display==3 and U.display[1].link==best.link,"Slot opens every upgrade sorted descending")
MOCK.Click(U.back); U.panel.scripts.OnMouseWheel(U.panel,-1)
check(U.offset==3 and U.rows[1].entry.slot==5,"Mouse wheel browses continuous slot list")
U.scroll:SetValue(10); check(U.rows[7].entry.slot==18,"Scroll bar reaches final slot")

U:Start(); tick(); QueryAuctionItems("Other search")
check(not U.scan and U.message:find("Another auction search"),"External queries cancel scanner without overwriting other results")
pending=false
U:Start(); tick(); AuctionFrameTab_OnClick(AuctionFrameTab2)
check(not U.scan and not U.panel:IsShown(),"Changing native tabs cancels scan")
AuctionFrameTab_OnClick(U.tab)
U:Start(); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",1)
check(not U.scan and U.stale,"Gear changes invalidate comparisons")
U:Start(); A.characterDB.advisors={gearProfile="survival"}; tick()
-- Explicit event also handles same-profile talent updates.
MOCK.FireAll("CHARACTER_POINTS_CHANGED")
check(not U.scan and U.stale,"Talent changes invalidate comparisons")
A.characterDB.advisors=nil

pages[4]={{item=good,noLink=true}}; pages[2]={}; pending=false
U:Start(); tick(); MOCK.FireAll("AUCTION_ITEM_LIST_UPDATE"); tick()
check(U.scan and U.scan.index==1,"Missing link is retried")
pages[4][1].noLink=nil; finish()
check(U.complete and U.results[1],"Delayed item data eventually included")
pages[4]={{item=good,noLink=true}}; U:Start(); finish()
check(not U.complete and U.message:find("1 unavailable"),"Unavailable data produces honest partial results")
pages[4]={}; U:Start(); tick(); pending=false; tick(21)
check(not U.scan and U.message:find("timed out"),"Missing server response times out safely")
ready=false; U:Start(); tick(31)
check(not U.scan and U.message:find("busy"),"Throttle cannot hang scan indefinitely")
ready=true

local main=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=5},2,7,{{"(10.0 damage per second)"}})
local off=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=5},2,7,{{"(10.0 damage per second)"}})
local two=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_AGILITY_SHORT=40},2,8,{{"(40.0 damage per second)"}})
F.equip(16,main); F.equip(17,off)
pages[4]={}; pages[2]={{item=two,minimum=500,bid=800}}
U:Start(); finish()
local comparison=G:Comparisons(G:Read(two.link),G:CurrentProfile())[1]
check(U.results[16][1].percent==comparison.percent and U.results[16][1].label=="Both hands","Two-handed candidates replace the combined hand baseline")
check(U.results[16][1].buyout==0 and U.results[16][1].bid==810,"Bid-only upgrades retain the next valid bid")

-- More than one screen of upgrades, no paging buttons or growing frame pool.
pages[4]={}; pages[2]={}
for i=1,25 do pages[4][i]={item=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=20+i},4,1),buyout=i*100} end
U:Start(); finish(); MOCK.Click(U.rows[1]); U.scroll:SetValue(18)
check(#U.display==25 and U.rows[7].entry==U.display[25] and #U.rows==7,"All slot alternatives are continuously scrollable")

BrowseName=CreateFrame("EditBox"); BrowseMinLevel=CreateFrame("EditBox"); BrowseMaxLevel=CreateFrame("EditBox")
IsUsableCheckButton=CreateFrame("CheckButton")
local searches=0
function AuctionFrameBrowse_Search() searches=searches+1 end
local chosen=U.rows[1].entry
MOCK.Click(U.rows[1])
check(searches==1 and BrowseName:GetText()=='"'..chosen.name..'"',"Clicking alternative opens native exact-name search")
check(not U.panel:IsShown() and AuctionFrameBrowse:IsShown() and AuctionFrameBrowse.page==0,"Browse takes over with clean paging")
AuctionFrameTab_OnClick(U.tab); U:Start(); MOCK.FireAll("AUCTION_HOUSE_CLOSED")
check(not U.scan and not U.open,"Auction close cancels pending work")
local px,py,pw,ph=U.panel:GetRect(); local ax,ay,aw,ah=AuctionFrame:GetRect()
check(px>=ax and px+pw<=ax+aw and py>=ay and py+ph<ay+ah-12,"Panel fits native auction frame above the tab row")
F.reset("DRUID",40,{0,31,0})
F.equip(18,F.item("INVTYPE_RELIC",{},4,8))
MOCK.FireAll("AUCTION_HOUSE_SHOW"); tick(); AuctionFrameTab_OnClick(U.tab); U:Start()
check(U.scan~=nil,"An unscored equipped relic does not block armor scanning")
U:Stop()
print("PASS: "..checks.." auction upgrade assertions")
