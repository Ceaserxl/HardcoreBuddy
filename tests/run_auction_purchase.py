"""Fresh auction identity verification and native-style buyout consent."""
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
local row={name="Chosen item",link="item:123:0:0:0:0:0:-15",count=1,buyout=500}
local link,price=row.link,500
local queries,bids=0,0
GetMoney=function() return 1000 end
GetAuctionItemLink=function() return link end
GetAuctionItemInfo=function() return 'Chosen item',1,1,2,true,1,nil,100,10,price,0,nil,nil,'Seller' end
GetNumAuctionItems=function() return 1,1 end
CanSendAuctionQuery=function() return true end
QueryAuctionItems=function(name,_,_,page,_,_,_,exact) assert(name==row.name and exact and page==0); queries=queries+1 end
StaticPopupDialogs={BUYOUT_AUCTION={text='Buy this auction?',button1='Accept',button2='Cancel',hasMoneyFrame=1}}
local dialog
StaticPopup_Show=function(which,_,_,data) dialog={which=which,data=data}; return dialog end
StaticPopup_Hide=function() dialog=nil end
PlaceAuctionBid=function(kind,index,amount) assert(kind=='list' and index==1 and amount==500); bids=bids+1 end
local function find()
 P:Find(row); P:Tick(); P:ListUpdated(); P:Tick()
end
find(); assert(dialog and bids==0 and U.panel:IsShown())
StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1)
find(); link='item:123:0:0:0:0:0:-16'
StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1,'Suffix change never buys wrong item')
link=row.link; price=600; find(); assert(not dialog and bids==1,'Never substitutes a higher price')
price=500; find(); P:ListUpdated(); assert(not dialog,'Fresh list invalidates open confirmation')
find(); U.open=false; StaticPopupDialogs[dialog.which].OnAccept(nil,dialog.data); assert(bids==1)
U.open=true; U.complete=true; U.cached=false; U:Refresh()
assert(U.start:GetText()=='Scan Complete' and not U.start.active)
U.scan={}; U:Refresh(); assert(not U.start.active and U.start:GetText():find('Scanning'))
U.scan=nil; U:SelectSlot(nil)
assert(U.heading:GetText()=='' and U.hint:GetText()=='')
assert(AuctionFrame:GetWidth()==832 and AuctionFrame:GetHeight()==447,'Native auction frame size is preserved')
assert(U.panel:GetWidth()==794 and U.panel:GetHeight()==377,'Panel fits inside auction border')
for _,slot in ipairs({1,11,17}) do
 U:SelectSlot(slot)
 assert(AuctionFrame:GetWidth()==832 and AuctionFrame:GetHeight()==447,'Slot view never expands auction frame')
 for _,r in ipairs(U.rows) do if r:IsShown() then
  local _,bottom,_,height=r:GetRect(); local _,panelBottom=U.panel:GetRect()
  assert(bottom>=panelBottom,'Visible rows stay within panel')
 end end
end
U:SelectSlot(nil)
local _,fillY=U.progressFill:GetRect(); local _,dividerY=U.divider:GetRect(); assert(fillY==dividerY)
print('PASS: live buyout confirmation, stale/mismatched/price checks, preserved tab, scan states and native-sized layout.')
''')
composite(lua.globals().MOCK.frames,a.AuctionUpgrades.panel).save(str(ROOT/'.release/auction-fitted.png'))
