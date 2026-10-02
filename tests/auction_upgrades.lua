-- Cross-armor fixtures explicitly opt out of the new default.
TestAddon.characterDB.auctionHighestArmorOnly=false
local A,F=TestAddon,GEAR_FIXTURES
local U,G=A.AuctionUpgrades,A.GearAdvisor
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
function GameTooltip:GetOwner() return self.owner end
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
local inventoryTypes={INVTYPE_HEAD=1,INVTYPE_NECK=2,INVTYPE_SHOULDER=3,INVTYPE_CHEST=5,INVTYPE_ROBE=20,
    INVTYPE_WAIST=6,INVTYPE_LEGS=7,INVTYPE_FEET=8,INVTYPE_WRIST=9,INVTYPE_HAND=10,INVTYPE_FINGER=11,
    INVTYPE_TRINKET=12,INVTYPE_CLOAK=16,INVTYPE_WEAPON=13,INVTYPE_WEAPONMAINHAND=21,INVTYPE_WEAPONOFFHAND=22,
    INVTYPE_SHIELD=14,INVTYPE_HOLDABLE=23,INVTYPE_2HWEAPON=17,INVTYPE_RANGED=15,INVTYPE_THROWN=25,INVTYPE_RANGEDRIGHT=26}
function CanSendAuctionQuery() return ready end
function QueryAuctionItems(name,min,max,page,usable,quality,all,exact,filters)
    queries[#queries+1]={name=name,min=min,max=max,page=page,usable=usable,all=all,exact=exact,filters=filters}
    if filters then
        local data={}
        for _,class in ipairs({4,2}) do
            for _,listing in ipairs(pages[class] or {}) do
                for _,filter in ipairs(filters) do
                    -- A slot restriction without its parent subclass can become
                    -- a class-wide query. Do not let the mock hide that failure.
                    if class==filter.classID and (filter.subClassID==nil or
                        (listing.item.subclassID==filter.subClassID and inventoryTypes[listing.item.equip]==filter.inventoryType)) then
                        data[#data+1]=listing; break
                    end
                end
            end
        end
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
check(U.empty:IsShown() and U.emptyTitle:GetText()=="Find your next upgrade" and #U.display==0,
    "First visit explains the workflow instead of showing seventeen empty result rows")
local navigationCount=0
for slot,tab in pairs(U.slotButtons) do
    navigationCount=navigationCount+1
    local tx,ty,tw,th=tab:GetRect(); local px,py=U.panel:GetRect()
    check(tx>=px+14 and tx+tw<=px+188 and ty+th<=py+326,"Slot navigation fits in its own column")
end
check(navigationCount==17 and U.weaponButton:IsShown(),"All slots and weapon navigation remain available")

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
check(U.complete and #queries==17,"Scans sixteen slot groups and every server page")
check(queries[1].filters[1].inventoryType==1 and queries[2].page==1 and queries[3].filters[1].inventoryType==2,
    "Finishes every head page before starting neck, with no broad armor query")
for _,q in ipairs(queries) do check(q.min==30 and q.max==40 and q.usable and not q.all,"Usable listings within ten levels below the player, no full-dump query") end
for _,q in ipairs(queries) do
    for _,filter in ipairs(q.filters) do
        check(type(filter.classID)=="number" and type(filter.subClassID)=="number" and type(filter.inventoryType)=="number",
            "Every slot query includes the full native class/subclass/inventory hierarchy")
    end
end
check(U.message:find("61 auctions checked",1,true),"Each auction is checked once across the complete scan")
check(#U.results[1]==3,"Only upgrades, with duplicates and unusable items removed")
check(U.results[1][1].link==best.link and U.results[1][1].buyout==5000,"Best percentage first; duplicate keeps cheapest buyout")
check(U.results[1][1].auctions==2,"Duplicate listings counted once per item")
check(U.results[1][1].percent==G:Comparisons(G:Read(best.link),G:CurrentProfile())[1].percent,"Exact advisor percentage reused")
check(U.rows[1].priceKind:GetText()=="" and U.rows[1].action:GetText()==""
    and U.rows[1].options:GetText()=="3 options >",
    "Overview separates the price type from the navigation action")
check(U.results[1][3].link==good.link,"Cloth upgrade compared against equipped mail")
check(U.results[1][2].link==suffix.link,"Different random suffixes of the same item remain separate")
check(U.results[11][1].percent==nil and U.results[12][1].percent==nil,"Empty ring slots get no fabricated percentage")
check(U.results[16] and U.results[17],"Dual-wield weapon compared in both hand slots")
check(U.results.paired[1].emptyOff,"A shared one-handed listing is scanned only once, not counted as two purchasable copies")
check(#U.rows==16 and #U.display==4,"Overview shows only slots with recommendations, using reusable rows")
MOCK.Click(U.rows[1])
check(U.slot==1 and #U.display==3 and U.display[1].link==best.link,"Slot opens every upgrade sorted descending")
local _,backParent,backAnchor,backX,backY=U.back:GetPoint()
check(backParent==U.panel and backAnchor=="TOPLEFT" and backX==204 and backY==-60,"Auction Back is above the left edge of results")
local bx,by,bw,bh=U.back:GetRect(); local hx=U.heading:GetRect()
check(hx>=bx+bw,"Auction heading stays clear of Back")
check(U.rows[1].action:GetText()=="Buyout >","Candidate offers a confirmed buyout")
MOCK.Click(U.back); MOCK.Click(U.slotButtons[12])
check(U.slot==12 and U.slotButtons[12].active,"Persistent slot picker opens Ring 2 with a selected highlight")
MOCK.Click(U.slotButtons[18])
check(U.slot==18 and U.empty:IsShown(),"Every slot remains accessible even without an upgrade")
check(U.emptyTitle:GetText()=="No upgrades found here","A searched empty slot is not labeled as unsearched")
MOCK.Click(U.overview)
check(not U.slot and U.overview.active,"Overview navigation resets selection directly")

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
check(not U.complete and U.message:find("1 listing could not be read",1,true),"Unavailable data explains skipped listings")
local diagnostics=A.characterDB.auctionDiagnostics
local failure=diagnostics.entries[1]
check(diagnostics.skipped==1 and failure.stage=="auction data" and failure.reason=="Missing item link",
    "Skipped listing records its exact failure stage and missing field")
check(failure.name==good.name and failure.search=="Head" and failure.page==1 and failure.index==1
    and failure.attempts>1 and failure.waitSeconds>=10,"Diagnostic includes listing identity, query position and retry timing")
check(diagnostics.checked==1 and diagnostics.outcome==U.message,"Completed report retains scan totals and outcome")
MOCK.Click(U.diagnosticsButton)
local debugWindow=A.AuctionDiagnostics.window
check(debugWindow:IsShown() and debugWindow.edit:GetText():find("Missing item link",1,true),"Scan details opens a copyable failure report")
MOCK.Click(debugWindow.selectAll)
check(debugWindow.edit:HasFocus() and debugWindow.edit.selection[2]==#debugWindow.edit:GetText(),"Select report selects all diagnostic text for copying")
debugWindow.edit.scripts.OnEscapePressed(debugWindow.edit)
check(not debugWindow:IsShown() and not debugWindow.edit:HasFocus(),"Closing report releases keyboard focus")
A:HandleSlashCommand("auction debug")
check(debugWindow:IsShown(),"Diagnostics can also be opened through the slash command")
debugWindow:Hide()
pages[4]={{item=good}}; U:Start(); finish()
check(A.characterDB.auctionDiagnostics==diagnostics,"A successful rescan preserves the latest failed scan for investigation")
local noStats=F.item("INVTYPE_HEAD",{},4,1,{{"+10 Agility"}}); noStats.stats=nil
pages[4]={{item=noStats}}; U:Start(); finish()
failure=A.characterDB.auctionDiagnostics.entries[1]
check(failure.stage=="item data" and failure.reason=="Item stats loading" and failure.candidate.tooltip[2]=="+10 Agility",
    "Item API failure is distinguished from auction data and retains the native tooltip")
local invalid=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=0/0},4,1)
pages[4]={{item=invalid}}; U:Start(); finish()
failure=A.characterDB.auctionDiagnostics.entries[1]
check(failure.stage=="gear comparison" and failure.reason=="Item stats incomplete" and failure.comparisonSlot==1,
    "Incomplete scoring records the affected comparison slot")
check(type(failure.candidate.stats.ITEM_MOD_AGILITY_SHORT)=="string" and failure.equipped[1].slot==1,
    "Invalid numbers are saved safely with equipped-item context")
pages[4]={{item=good}}; U:Start(); U.scan.weapons.Add=function() return false end; finish()
failure=A.characterDB.auctionDiagnostics.entries[1]
check(failure.stage=="weapon score" and #failure.equipped==2,"Weapon scoring failure includes both equipped hand slots")
check(failure.candidate.link==good.link and failure.candidate.stats.ITEM_MOD_AGILITY_SHORT==15,"Diagnostic stores independent scoring evidence")
local original=good.stats.ITEM_MOD_AGILITY_SHORT; good.stats.ITEM_MOD_AGILITY_SHORT=999
check(failure.candidate.stats.ITEM_MOD_AGILITY_SHORT==15,"Saved diagnostic data is not a shared mutable item API table")
good.stats.ITEM_MOD_AGILITY_SHORT=original
local retained=A.characterDB.auctionDiagnostics; local reportText=A.AuctionDiagnostics:Text()
U.scan=nil; U.results={}; A.characterDB={auctionDiagnostics=retained}
check(A.AuctionDiagnostics:Text()==reportText,"Diagnostics can be reconstructed from per-character saved data without scan state")
local limit=A.AuctionDiagnostics.limit; A.AuctionDiagnostics.limit=1
pages[4]={{item=good,noLink=true},{item=good,noLink=true}}; U:Start(); finish()
check(A.characterDB.auctionDiagnostics.skipped==2 and #A.characterDB.auctionDiagnostics.entries==1,
    "Diagnostic storage is bounded while preserving the full skipped count")
A.AuctionDiagnostics.limit=limit
check(A.AuctionDiagnostics:Text():find("first 1 skipped listings",1,true),"Report discloses truncated diagnostic storage")
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
U:Start(); finish(); MOCK.Click(U.rows[1]); U.scroll:SetValue(100)
check(#U.display==25 and U.rows[math.floor((U.panel:GetHeight()-118-16)/38)].entry==U.display[25] and #U.rows==16,"All slot alternatives are continuously scrollable")

BrowseName=CreateFrame("EditBox"); BrowseMinLevel=CreateFrame("EditBox"); BrowseMaxLevel=CreateFrame("EditBox")
IsUsableCheckButton=CreateFrame("CheckButton")
local searches=0
function AuctionFrameBrowse_Search() searches=searches+1 end
local chosen=U.rows[1].entry
MOCK.Click(U.rows[1])
check(A.AuctionPurchase.request.row==chosen,"Clicking alternative starts live buyout verification")
check(U.panel:IsShown() and not AuctionFrameBrowse:IsShown(),"Buyout remains in Upgrades")
AuctionFrameTab_OnClick(U.tab); U:Start(); MOCK.FireAll("AUCTION_HOUSE_CLOSED")
check(not U.scan and not U.open,"Auction close cancels pending work")
local px,py,pw,ph=U.panel:GetRect(); local ax,ay,aw,ah=AuctionFrame:GetRect()
check(px>=ax and px+pw<=ax+aw and py>=ay and py+ph<=ay+ah-10,"Panel fits native auction frame with 10px bottom inset")
F.reset("DRUID",40,{0,31,0})
F.equip(18,F.item("INVTYPE_RELIC",{},4,8))
MOCK.FireAll("AUCTION_HOUSE_SHOW"); tick(); AuctionFrameTab_OnClick(U.tab); U:Start()
check(U.scan~=nil,"An unscored equipped relic does not block armor scanning")
U:Stop()
-- Auction candidates must survive per-item downgrades and a currently equipped
-- two-hander so that a better complete caster pair can be discovered.
F.reset("MAGE",40,{0,0,31})
local staff=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_INTELLECT_SHORT=20},2,10,{{"(10.0 damage per second)"}})
local casterSword=F.item("INVTYPE_WEAPON",{ITEM_MOD_INTELLECT_SHORT=14},2,7,{{"(10.0 damage per second)"}})
local held=F.item("INVTYPE_HOLDABLE",{ITEM_MOD_INTELLECT_SHORT=10},4,0)
local biggerStaff=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_INTELLECT_SHORT=22},2,10,{{"(10.0 damage per second)"}})
F.equip(16,staff)
pages[4]={{item=held,buyout=800}}; pages[2]={{item=casterSword,buyout=200},{item=biggerStaff,buyout=500}}
U:Start(); finish()
check(U.results.paired[1].percent>U.results.twoHand[1].percent,"Auction scan discovers a winning pair despite both items failing independent upgrades")
MOCK.Click(U.weaponButton)
check(#U.display==2 and U.rows[1].entry.slot=="twoHand" and U.rows[2].entry.slot=="paired","Weapon comparison shows both styles side by side in the list")
check(U.hint:GetText():find("Higher score: 1H + off hand",1,true),"Comparison identifies the higher-scoring style")
MOCK.Click(U.rows[2]); MOCK.Click(U.rows[1])
check(U.setup and #U.display==2 and U.rows[1].entry.label=="Main hand" and U.rows[2].entry.label=="Off hand","Setup opens both components")
check(U.rows[2].percent:GetText()=="Included","A component does not get a fabricated independent percentage")
U.rows[1].scripts.OnEnter(U.rows[1]); U.rows[1].scripts.OnLeave(U.rows[1])
MOCK.Click(U.rows[2])
check(A.AuctionPurchase.request.row.link==held.link,"Each component can request its own buyout")
AuctionFrameTab_OnClick(U.tab); MOCK.Click(U.back); MOCK.Click(U.back)
check(U.weaponsOnly and not U.slot and not U.setup,"Back returns from setup to alternatives to style comparison")
MOCK.Click(U.rows[1])
local ownedIndex
for i,entry in ipairs(U.display) do if entry.owned then ownedIndex=i end end
check(ownedIndex and U.display[ownedIndex].percent==0,"Current staff stays visible as the keep-equipped option")
MOCK.Click(U.rows[ownedIndex]); local oldSearches=searches; MOCK.Click(U.rows[1])
check(searches==oldSearches,"Equipped components never trigger an auction purchase search")
MOCK.Click(U.back); MOCK.Click(U.back); MOCK.Click(U.back)
check(not U.weaponsOnly and #U.display==2,"Back returns to the overview's available recommendations")
pages[4]={}; pages[2]={{item=staff,buyout=1}}
U:Start(); finish()
check(U.results.twoHand[1].owned,"An equal-scoring listing never outranks keeping the equipped weapon")
MOCK.Click(U.weaponButton); U.rows[1].scripts.OnEnter(U.rows[1]); U.rows[1].scripts.OnLeave(U.rows[1])
check(U.results.paired==nil or #U.results.paired==0,"No one-handed setup fabricated from a staff alone")

-- Classic's GameTooltip_OnUpdate delegates to owner:UpdateTooltip(). Model
-- that native boundary, including modifier changes without moving the mouse.
local shift,always,equipped=false,false,false
local compareCalls=0
function IsModifiedClick(kind) check(kind=="COMPAREITEMS","Respects native comparison binding"); return shift end
local oldCVar=GetCVarBool
function GetCVarBool(name) if name=="alwaysCompareItems" then return always end; return oldCVar and oldCVar(name) end
function GameTooltip:IsEquippedItem() return equipped end
ShoppingTooltip1=CreateFrame("GameTooltip"); ShoppingTooltip2=CreateFrame("GameTooltip")
GameTooltip.shoppingTooltips={ShoppingTooltip1,ShoppingTooltip2}
function GameTooltip_HideShoppingTooltips(tip)
    check(tip==GameTooltip,"Hides comparisons belonging to the item tooltip")
    for _,shopping in ipairs(tip.shoppingTooltips) do shopping:Hide() end
end
function GameTooltip_ShowCompareItem(tip)
    check(tip==GameTooltip and tip:IsShown(),"Uses the native comparison API after showing the item")
    compareCalls=compareCalls+1
    for _,shopping in ipairs(tip.shoppingTooltips) do shopping.comparedLink=tip.link; shopping:Show() end
end
local function nativeTooltipTick()
    local owner=GameTooltip:GetOwner()
    if owner and owner.UpdateTooltip then owner:UpdateTooltip() end
end
local hovered=U.rows[1]
hovered.scripts.OnEnter(hovered)
check(ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown(),"Unmodified hover shows equipped comparisons even with always-compare disabled")
local stableCalls=compareCalls
for i=1,20 do nativeTooltipTick() end
check(compareCalls==stableCalls and ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown(),
    "Repeated native tooltip updates do not clear and rebuild equipped comparisons")
ShoppingTooltip2:Hide(); nativeTooltipTick()
check(compareCalls==stableCalls+1 and ShoppingTooltip2:IsShown(),"A lost comparison is restored once")
nativeTooltipTick(); check(compareCalls==stableCalls+1,"Restored comparisons remain stable on later updates")
shift=true; nativeTooltipTick()
check(ShoppingTooltip1:IsShown() and ShoppingTooltip2:IsShown(),"Pressing Shift while hovered opens equipped comparisons")
check(ShoppingTooltip1.comparedLink==GameTooltip.link,"Compares the hovered upgrade's exact item link")
shift=false; nativeTooltipTick()
check(ShoppingTooltip1:IsShown() and GameTooltip:IsShown(),"Releasing Shift keeps automatic comparisons visible")
shift=true; hovered.scripts.OnLeave(hovered); hovered.scripts.OnEnter(hovered)
check(ShoppingTooltip1:IsShown(),"Holding Shift before hovering also works")
hovered.scripts.OnLeave(hovered)
check(not GameTooltip:IsShown() and not ShoppingTooltip2:IsShown(),"Leaving a row clears all owned tooltips")
shift=false; always=true; hovered.scripts.OnEnter(hovered)
check(ShoppingTooltip1:IsShown(),"Respects the native always-compare preference")
equipped=true; nativeTooltipTick()
check(ShoppingTooltip1:IsShown(),"Equipped entries also request native comparisons without Shift")
shift=true; nativeTooltipTick(); check(ShoppingTooltip1:IsShown(),"Explicit Shift still compares an equipped item")
equipped=false; always=false
local previousLink=GameTooltip.link
local tooltipSets=0
local setHyperlink=GameTooltip.SetHyperlink
GameTooltip.SetHyperlink=function(self,link) tooltipSets=tooltipSets+1; return setHyperlink(self,link) end
U:Refresh()
check(GameTooltip:IsShown() and ShoppingTooltip1:IsShown() and GameTooltip.link==previousLink,
    "Progress refresh keeps the hovered item and equipped comparisons visible")
check(tooltipSets==0,"Unchanged progress refresh does not rebuild or flicker the tooltip")
hovered.scripts.OnEnter(hovered); MOCK.Click(hovered); MOCK.Click(U.rows[1])
local part=U.rows[1]; part.scripts.OnEnter(part)
check(ShoppingTooltip1:IsShown() and ShoppingTooltip1.comparedLink==part.entry.link,"Weapon setup components support comparison too")
local other=CreateFrame("Frame"); GameTooltip:SetOwner(other,"ANCHOR_RIGHT"); GameTooltip:Show()
local previous=compareCalls; part:UpdateTooltip(); part.scripts.OnLeave(part)
U:Refresh()
check(GameTooltip:IsShown() and compareCalls==previous,"Does not update or hide another frame's tooltip")
part.scripts.OnEnter(part); AuctionFrameTab_OnClick(AuctionFrameTab1)
check(not GameTooltip:IsShown() and not ShoppingTooltip1:IsShown(),"Leaving the auction upgrades tab clears comparisons")

shift=false; always=false
AuctionFrameTab_OnClick(U.tab); F.reset("HUNTER",40,{31,0,0}); F.equip(1,old)
check(not A.characterDB.auctionHighestArmorOnly,"Explicit cross-armor preference remains off")
local mail=F.item("INVTYPE_HEAD",{ITEM_MOD_AGILITY_SHORT=25},4,3)
local robe=F.item("INVTYPE_ROBE",{ITEM_MOD_AGILITY_SHORT=5},4,1)
local chest=F.item("INVTYPE_CHEST",{ITEM_MOD_AGILITY_SHORT=5},4,3)
local cloak=F.item("INVTYPE_CLOAK",{ITEM_MOD_AGILITY_SHORT=5},4,1)
local neck=F.item("INVTYPE_NECK",{ITEM_MOD_AGILITY_SHORT=5},4,0)
local trinket=F.item("INVTYPE_TRINKET",{ITEM_MOD_AGILITY_SHORT=5},4,0)
pages[4]={{item=good},{item=best},{item=mail},{item=robe},{item=chest},{item=cloak},{item=neck},{item=ring},{item=trinket},{item=held}}
pages[2]={{item=sword,buyout=300}}
A:OpenSettings("Auction House")
local armorToggle=A.Settings.pages["Auction House"].armor
U.armorOnly:SetChecked(true); MOCK.Click(U.armorOnly)
check(armorToggle:GetChecked() and U.armorOnly.mark:GetText()=="X","AH checkbox updates centralized settings")
check(A.characterDB.auctionHighestArmorOnly and armorToggle.label:GetText()=="Best Armor: Mail","Checkbox saves per-character preference and labels hunter armor correctly")
local queryStart=#queries
U:Start(); finish()
check(#queries-queryStart==16,"Each slot group scans separately, including shared rings/trinkets only once")
check(#U.results[1]==1 and U.results[1][1].link==mail.link,"Highest-only hunter search excludes cloth and leather armor")
check(#U.results[5]==1 and U.results[5][1].link==chest.link,"Highest-only chest search excludes cloth robes")
check(U.results[15] and U.results[2] and U.results[11] and U.results[12] and U.results[13] and U.results[14],
    "Cloth cloaks, necks, both rings and both trinkets remain available")
check(#U.results.paired>0 and #U.results.paired[1].components==2,"Weapons and held off-hands survive the material filter")
check(queries[queryStart+1].filters[1].subClassID==3 and queries[queryStart+2].filters[1].subClassID==0,
    "Body armor uses the selected material; jewelry uses the native miscellaneous subclass")
armorToggle:SetChecked(false); A:Refresh()
check(armorToggle:GetChecked(),"Refreshing settings restores the saved checkbox preference")
armorToggle:SetChecked(false); MOCK.Click(armorToggle); U:Start(); finish()
check(not U.armorOnly:GetChecked(),"Centralized checkbox updates AH filter")
check(#U.results[1]==3 and #U.results[5]==2,"Unchecking restores cross-material armor and chest/robe variants")
U:Start(); tick(); armorToggle:SetChecked(true); MOCK.Click(armorToggle)
check(not U.scan and U.stale,"Changing filters mid-scan cancels and marks old results stale")
for class,expected in pairs({HUNTER={2,3},SHAMAN={2,3},WARRIOR={3,4},PALADIN={3,4},
    ROGUE={2,2},DRUID={2,2},MAGE={1,1},PRIEST={1,1},WARLOCK={1,1}}) do
    check(G.HighestArmorSubclass({class=class,level=39})==expected[1]
        and G.HighestArmorSubclass({class=class,level=40})==expected[2],"Highest armor follows Classic class and level: "..class)
end
F.reset("HUNTER",39,{30,0,0}); A:Refresh()
check(armorToggle.label:GetText()=="Best Armor: Leather","Hunter below 40 uses leather")
MOCK.level=40; A:Refresh()
check(armorToggle.label:GetText()=="Best Armor: Mail","Armor label updates when mail unlocks")
local _,sy,_,sh=U.start:GetRect(); local _,cy,_,ch=U.armorOnly:GetRect(); local _,wy=U.weaponButton:GetRect()
local cx=U.armorOnly:GetRect(); local sx=U.start:GetRect()
check(cx+156<=sx and cy>=sy and cy+ch<=sy+sh,"Best Armor fits to the left of Scan")
armorToggle:SetChecked(false); MOCK.Click(armorToggle)

-- Hover after head results arrive, then continue querying the remaining slots.
F.reset("HUNTER",40,{31,0,0}); F.equip(1,old)
U.weaponsOnly=false; pages[4]={{item=best},{item=good}}; pages[2]={}
U:Start(); tick(); pending=false; MOCK.FireAll("AUCTION_ITEM_LIST_UPDATE"); tick()
check(U.scan and U.scan.search==2,"Head results arrive before later slot queries")
local activeScan=U.scan
MOCK.Click(U.slotButtons[18])
check(U.scan==activeScan and U.emptyTitle:GetText()=="Waiting for this slot","Direct slot navigation preserves the active scan and explains pending results")
MOCK.Click(U.slotButtons[1])
check(U.rows[1].action:GetText()=="Stop scan to buy","Purchase search action explains why it is unavailable while scanning")
MOCK.Click(U.overview)
hovered=U.rows[1]; shift=true; hovered.scripts.OnEnter(hovered)
local setsBefore=tooltipSets
tick()
check(GameTooltip:IsShown() and GameTooltip.link==best.link and ShoppingTooltip1:IsShown(),
    "Starting the next slot query preserves the hovered upgrade and Shift comparisons")
finish()
check(GameTooltip:IsShown() and tooltipSets==setsBefore,"Tooltip stays open without rebuilding throughout the remaining scan and completion")
local current=U.results[1][1]; current.auctions=current.auctions+1; U:Refresh()
check(GameTooltip:IsShown() and tooltipSets==setsBefore and hovered.tooltipAuctions==current.auctions,
    "Updated listing count preserves both tooltips without a listing footer")
local comparisonBefore=compareCalls
local replacement={}; for key,value in pairs(current) do replacement[key]=value end
replacement.buyout=1; U.results[1][1]=replacement; U:Refresh(); nativeTooltipTick()
check(tooltipSets==setsBefore and compareCalls==comparisonBefore and hovered.tooltipItem==replacement,
    "A cheaper auction for the same item preserves visible equipped comparisons")
table.remove(U.results[1],1); U:Refresh()
check(GameTooltip:IsShown() and GameTooltip.link==good.link and ShoppingTooltip1.comparedLink==good.link,
    "Reused hovered row updates both item and equipped comparisons")
U.results[1]={}; U:Refresh()
check(not GameTooltip:IsShown() and not ShoppingTooltip1:IsShown(),"Removing the hovered item clears its tooltips")
local _,panelY=U.panel:GetRect()
for _,card in ipairs(U.rows) do
    local x,y,w,h=card:GetRect(); local sx=select(1,U.scroll:GetRect())
    if card:IsShown() then check(x+w<sx and y>=panelY+84 and y+h<=panelY+U.panel:GetHeight()-12,"Visible rows stay inside expanded table") end
    local fields={card.item,card.slotName,card.cost,card.percent,card.options}
    for i=1,#fields-1 do
        local left,_,width=fields[i]:GetRect(); local right=fields[i+1]:GetRect()
        check(left+width<=right,"Item, slot, price, score and options columns stay separate and ordered")
    end
end
GameTooltip.SetHyperlink=setHyperlink

-- Real Classic negative-stat items must finish scanning without timeouts.
F.reset("HUNTER",41,{31,1,0}); F.equip(1,old)
local rot=F.item("INVTYPE_CLOAK",{ITEM_MOD_STAMINA_SHORT=-5,ITEM_MOD_INTELLECT_SHORT=7,RESISTANCE0_NAME=22},4,1)
local widow=F.item("INVTYPE_FINGER",{ITEM_MOD_STAMINA_SHORT=-5,ITEM_MOD_INTELLECT_SHORT=7},4,0)
local ogremage=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_INTELLECT_SHORT=-5,ITEM_MOD_STRENGTH_SHORT=11},2,10,
    {{"(18.2 damage per second)"}})
pages[4]={{item=rot},{item=widow},{item=best}}; pages[2]={{item=ogremage},{item=ogremage}}
U:Start(); finish()
check(U.complete and U.message:find("5 auctions checked",1,true),"All negative-stat auctions are scored without unavailable listings")

local cache=A.characterDB.auctionLastScan
check(cache and cache.complete and cache.results[1][1].link==best.link and cache.results.twoHand[1].components,
    "Last scan saves armor and complete weapon setups")
U.results[1][1].buyout=1234567
check(cache.results[1][1].buyout~=1234567,"Saved scan does not share mutable result tables")
local queryCount=#queries
U.results={}; U.profile=nil; U.checkedSlots={}; U.scan=nil
MOCK.Click(U.tab)
check(U.cached and not U.stale and U.complete and U.results[1][1].link==best.link and #queries==queryCount,
    "Reopening restores saved results without querying the auction house")
check(U.subtitle:GetText():find("Saved scan:",1,true) and U.message:find("Prices may have changed",1,true),
    "Cached scan is dated and does not claim current prices")
MOCK.Click(U.slotButtons.twoHand); MOCK.Click(U.rows[1])
check(U.setup and #U.display==1 and U.display[1].link==ogremage.link,"Restored weapon components remain browsable")
U.setup=nil; U.slot=nil; U.profile=nil; F.equip(1,good)
MOCK.Click(U.tab)
check(U.stale and not U.complete,"Changed equipment invalidates cached percentages")
local beforeFind=#queries; U:Find(U.results[1][1])
check(#queries==beforeFind,"Stale cached comparisons cannot open a purchase search")
F.equip(1,old); F.reset("HUNTER",42,{31,1,0}); F.equip(1,old); U.profile=nil
MOCK.Click(U.tab); check(U.stale,"Changed level invalidates cached comparisons")
F.reset("HUNTER",41,{31,1,0}); F.equip(1,old); U.profile=nil
A.characterDB.auctionHighestArmorOnly=true
MOCK.Click(U.tab); check(U.stale,"Changed armor filter invalidates cached comparisons")
A.characterDB.auctionHighestArmorOnly=false
U:Start(); tick(); pending=false; MOCK.FireAll("AUCTION_ITEM_LIST_UPDATE"); tick()
MOCK.FireAll("PLAYER_LOGOUT")
check(not A.characterDB.auctionLastScan.complete and A.characterDB.auctionLastScan.results[1],
    "Reload during scanning saves partial results")
finish()
MOCK.FireAll("AUCTION_HOUSE_CLOSED")
check(A.characterDB.auctionLastScan.complete,"Closing the auction house preserves the completed scan")
U.profile=nil; U.results={}; local character=A.characterDB
A.characterDB={}; check(not A.AuctionCache:Restore(U),"Another character does not inherit a saved scan")
A.characterDB=character
check(A.AuctionCache:Restore(U),"Character cache remains available after closing the auction house")
local completedScan=A.characterDB.auctionLastScan
U.open=true; U.panel:Show(); U:Start()
check(U.scan~=nil,"Master toggle fixture starts an active scan")
G:SetEnabled(false)
check(U.scan==nil and not U.start:IsEnabled() and #U.display==0,"Gear master switch stops scanning and hides upgrade results")
check(U.emptyTitle:GetText()=="Gear Advisor disabled","Auction tab explains the disabled advisor")
local disabledQueries=#queries; U:Start(); tick()
check(U.scan==nil and #queries==disabledQueries,"Disabled advisor cannot start auction queries")
G:SetEnabled(true)
check(U.start:IsEnabled(),"Reenabling restores auction scan control")
local defaultSignature=A.AuctionCache:Signature(G:CurrentProfile())
U:SetLevelRange(5)
check(U:LevelRange()==5 and U.stale,"Level range persists and invalidates old results")
check(A.AuctionCache:Signature(G:CurrentProfile())~=defaultSignature,"Saved scan signature includes level range")
U:Start(); tick()
check(queries[#queries].min==U.profile.level-5 and queries[#queries].usable,"Custom range reaches the server query")
U:Stop()
U:SetLevelRange(60); U:Start(); tick()
check(queries[#queries].min==0,"Minimum required level clamps to zero")
U:Stop(); U:SetLevelRange(10)
U.open=false
-- Unique jewelry is assigned once, independent of comparison order and prices.
for _,pair in ipairs({{11,12,"INVTYPE_FINGER"},{13,14,"INVTYPE_TRINKET"}}) do
    local item=F.item(pair[3],{ITEM_MOD_AGILITY_SHORT=10},4,0)
    item.unique=true
    local rows={{slot=pair[1],status="up",percent=10},{slot=pair[2],status="up",percent=30}}
    U.results={}; U:Add(item,rows,item.link,123,200,100,1)
    check(not U.results[pair[1]] and #U.results[pair[2]]==1,"Unique jewelry uses highest percentage slot only")
    U:Add(item,rows,item.link,123,150,100,1)
    check(#U.results[pair[2]]==1 and U.results[pair[2]][1].buyout==150 and U.results[pair[2]][1].auctions==2,"Repeated unique listings retain cheapest price and count")
    rows[1].percent=nil
    U.results={}; U:Add(item,rows,item.link,123,200,100,1)
    check(U.results[pair[1]] and not U.results[pair[2]],"Empty baseline preferred for unique jewelry")
    rows[1].percent=30
    U.results={}; U:Add(item,{rows[2],rows[1]},item.link,123,200,100,1)
    check(U.results[pair[1]] and not U.results[pair[2]],"Equal unique upgrades choose first slot deterministically")
    rows[1].status="unknown"
    U.results={}; U:Add(item,rows,item.link,123,200,100,1)
    check(not U.results[pair[1]] and U.results[pair[2]],"Unique exclusions from equipped gear remain respected")
    item.unique=false; rows[1].status="up"
    U.results={}; U:Add(item,rows,item.link,123,200,100,1)
    check(U.results[pair[1]] and U.results[pair[2]],"Nonunique jewelry remains available for both slots")
end
-- Keep the completed item/weapon fixture for the fresh-runtime persistence test.
A.characterDB.auctionLastScan=completedScan
print("PASS: "..checks.." auction upgrade assertions")
