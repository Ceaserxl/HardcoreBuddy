"""Saved-page purchases, no rescan, exact offer validation and row Buy controls."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT, composite
lua,a=boot()
lua.execute((ROOT/'tests/gear_advisor.lua').read_text())
lua.execute((ROOT/'tests/auction_upgrades.lua').read_text())
lua.execute('''
local U,P=TestAddon.AuctionUpgrades,TestAddon.AuctionPurchase
U.open=true; U.scan=nil; U.stale=false; U.panel:Show()
local source={name="",minimum=30,maximum=40,page=3,usable=true,exact=false,
 filters={{classID=4,subClassID=1,inventoryType=1}}}
local row={name="Chosen item",link="item:123:0:0:0:0:0:-15",count=1,buyout=500,
 listing={query=source,index=7,owner="Seller"}}
local link,price,owner,available,total=row.link,500,"Seller",true,201
local queries,bids=0,0
GetMoney=function() return 1000 end
GetAuctionItemLink=function() return link end
GetAuctionItemInfo=function() return 'Chosen item',1,1,2,true,1,nil,100,10,price,0,nil,nil,owner end
GetNumAuctionItems=function() return available and 1 or 0,total end
CanSendAuctionQuery=function() return true end
QueryAuctionItems=function(name,minimum,maximum,page,usable,_,all,exact,filters)
 assert(name==source.name and minimum==30 and maximum==40 and page==3 and usable and not all and not exact and filters==source.filters)
 queries=queries+1
end
StaticPopupDialogs={BUYOUT_AUCTION={text='Buy this auction?',button1='Accept',button2='Cancel',hasMoneyFrame=1}}
local dialog
StaticPopup_Show=function(which,_,_,data) dialog={which=which,data=data}; return dialog end
StaticPopup_Hide=function() dialog=nil end
PlaceAuctionBid=function(kind,index,amount) assert(kind=='list' and index==1 and amount==500); bids=bids+1 end
local function find()
 P:Find(row)
 if P.request then P:Tick(); P:ListUpdated(); P:Tick() end
end
-- A matching currently loaded offer needs no network query at all.
find(); assert(dialog and bids==0 and queries==0 and U.panel:IsShown())
StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1)
-- A different loaded page uses exactly the stored query/page, never page zero or a name rescan.
available=false; P:Find(row); assert(P.request and P.request.query==source)
P:Tick(); assert(queries==1 and P.request.phase=='waiting')
available=true; P:ListUpdated(); P:Tick(); assert(dialog and not P.request)
StaticPopupDialogs[dialog.which].OnCancel(); assert(not P.request and not P.confirmation)
-- Even when there are more result pages, a vanished saved offer stops after one page.
price=600; local previous=queries; find()
assert(queries==previous+1 and not P.request and not dialog and bids==1,'No pagination or price substitution on Buy')
price=500
-- Old caches without a location may use an already loaded match, but cannot trigger a scan.
available=false; previous=queries
P:Find({name=row.name,link=row.link,count=1,buyout=500})
assert(not P.request and queries==previous and U.message:find('no listing location',1,true))
available=true
owner='OtherSeller'; previous=queries; find()
assert(not dialog and queries==previous+1,'Same item and price from a different seller cannot replace the saved offer')
owner='Seller'

local beforeQueries=queries
P:Find({name='Heavy Throwing Dagger',link='item:3108',count=200,buyout=500})
assert(not P.request and not dialog and queries==beforeQueries and U.message:find('unlimited stock',1,true),'Vendor item blocked before AH query')
local faction=UnitFactionGroup('player')=='Horde' and 'H' or 'A'
TestAddon.characterDB.vendorVisits={[1]={name='Known vendor',faction=faction,items={[123]=true}}}
assert(not TestAddon.VendorServices:UnlimitedSource(row.link),'Old vendor data without stock cannot block')
TestAddon.characterDB.vendorVisits[1].unlimited={[123]=true}
P:Confirm(1,row); assert(not dialog and bids==1,'Direct confirmation cannot bypass vendor guard')
TestAddon.characterDB.vendorVisits[1].unlimited[123]=nil
find(); assert(dialog,'Limited or unknown stock still permits confirmation')
TestAddon.characterDB.vendorVisits[1].unlimited[123]=true
StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data)
assert(bids==1 and not dialog,'Accept rechecks newly learned vendor stock')
TestAddon.characterDB.vendorVisits={}
find(); link='item:123:0:0:0:0:0:-16'
StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1,'Suffix change never buys wrong item')
link=row.link; price=600; find(); assert(not dialog and bids==1,'Never substitutes a higher price')
price=500; find(); P:ListUpdated(); assert(not dialog,'Fresh list invalidates open confirmation')
find(); U.open=false; StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1)
U.open=true; U.complete=true; U.cached=false; U:Refresh()
assert(U.start:GetText()=='Scan Complete' and not U.start.active)
U.scan={}; U:Refresh(); assert(not U.start.active and U.start:GetText():find('Scanning'))
U.scan=nil; U:SelectSlot(nil)
assert(U.heading:GetText()=='' and U.hint:GetText()=='' and U.optionsHeader:GetText()=='OPTIONS')
assert(AuctionFrame:GetWidth()==832 and AuctionFrame:GetHeight()==447,'Native auction frame size is preserved')
assert(U.panel:GetWidth()==814 and U.panel:GetHeight()==400,'Panel is 814px wide and 400px high')
for _,slot in ipairs({1,11,17}) do
 U:SelectSlot(slot)
 assert(U.optionsHeader:GetText()=='BUY')
 assert(AuctionFrame:GetWidth()==832 and AuctionFrame:GetHeight()==447,'Slot view never expands auction frame')
 for _,r in ipairs(U.rows) do if r:IsShown() then
  local _,bottom,_,height=r:GetRect(); local _,panelBottom=U.panel:GetRect()
  assert(bottom>=panelBottom,'Visible rows stay within panel')
 end end
end
U:SelectSlot(nil)
local _,fillY=U.progressFill:GetRect(); local _,dividerY=U.divider:GetRect(); assert(fillY==dividerY)
print('PASS: cached-page buyouts without rescanning, exact seller/price/variant checks, native confirmation, row buttons and table layout.')
''')
composite(lua.globals().MOCK.frames,a.AuctionUpgrades.panel).save(str(ROOT/'.release/auction-fitted.png'))
