"""Multiple-item refills with delayed native bid/query events and throttling."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text())
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text())
lua.execute(r'''
local A,E=TestAddon,TestAddon.AuctionEssentials
local clock=100
GetTime=function() return clock end
local stock={
 [900001]={name='A Potion',count=5,price=50},
 [900002]={name='B Potion',count=8,price=80},
}
local function records()
 local rows={}
 for id,s in pairs(stock) do
  rows[#rows+1]={itemId=id,name=s.name,item={itemId=id},count=0,target=s.count,missing=s.count,tracking=true}
 end
 return rows
end
A.Supplies.Build=records
A.GetContext=function() return {inventory={available=true,counts={}}} end
A.characterDB.auctionMail=nil; A.characterDB.auctionBank=nil
local ready,wanted,displayed=true,nil,nil
local queries,purchases={},{}
CanSendAuctionQuery=function() return ready end
QueryAuctionItems=function(name,_,_,page)
 assert(ready and page==0)
 queries[#queries+1]=name
 for id,s in pairs(stock) do if s.name==name then wanted=id; return end end
 error('Unexpected query')
end
GetNumAuctionItems=function() return displayed and 1 or 0,displayed and 1 or 0 end
GetAuctionItemLink=function() return displayed and 'item:'..displayed..':0' end
GetAuctionItemInfo=function()
 local s=displayed and stock[displayed]
 if s then return s.name,nil,s.count,nil,nil,nil,nil,nil,nil,s.price,nil,nil,nil,'Seller' end
end
GetMoney=function() return 100000 end
PlaceAuctionBid=function(_,index,price)
 assert(index==1 and stock[displayed].price==price)
 purchases[#purchases+1]=displayed
end
StaticPopupDialogs=StaticPopupDialogs or {}; StaticPopupDialogs.BUYOUT_AUCTION={}
StaticPopup_Show=function() end; StaticPopup_Hide=function() end
ERR_AUCTION_BID_PLACED='Bid accepted'
local function event(name,...) E.events.scripts.OnEvent(E.events,name,...) end
local function tick(seconds) clock=clock+(seconds or .25); E.events.scripts.OnUpdate(E.events) end
local function deliver()
 displayed=wanted; event('AUCTION_ITEM_LIST_UPDATE')
end
local function finish()
 for i=1,100 do
  if not E.scan then return end
  tick()
  if E.scan and E.scan.phase=='waiting' then deliver() end
 end
 error('Queue did not reach confirmation')
end
local function accept()
 StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnAccept(nil,E.confirmation)
 assert(E.awaitingBuy)
end
E:Attach(); E.open=true; AuctionFrameTab_OnClick(E.tab)
E:Start(); finish()
E.selected[900001]=true; E.selected[900002]=true
E:BuySelected(); finish()
assert(E.confirmation.itemId==900001)
accept(); local sent=#queries
event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
assert(E.scan.phase=='settling' and E.batch[1].record.itemId==900002)
assert(#E.items==1 and E.items[1].itemId==900002,'Completed first row disappears without invalidating queued second row')
tick(.1); assert(#queries==sent,'Acknowledgement alone does not immediately send the next query')
event('AUCTION_ITEM_LIST_UPDATE'); tick(.6)
ready=false; tick(); tick(25)
assert(E.scan and E.scan.phase=='query' and #queries==sent,'Normal query throttling does not trigger a 20-second response timeout')
ready=true; tick()
assert(E.scan.phase=='waiting' and wanted==900002 and #queries==sent+1)
-- A late page from the previous item cannot become the new item's empty result.
displayed=900001; event('AUCTION_ITEM_LIST_UPDATE'); tick()
assert(E.scan.phase=='reading' and not E.confirmation,'Stale preceding result page is ignored')
deliver(); finish(); assert(E.confirmation.itemId==900002)
accept()
-- The server can send the list update before, or after, the bid acknowledgement.
event('AUCTION_ITEM_LIST_UPDATE'); event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
assert(#purchases==2 and purchases[1]==900001 and purchases[2]==900002)
assert(not E.batch and not E.scan and not E.awaitingBuy and #E.items==0,'One Buy click completes different rows through native confirmations')
assert(E:MailCount(900001)==5 and E:MailCount(900002)==8,'Each receipt counts exactly once')
event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
assert(E:MailCount(900002)==8,'Repeated acknowledgement cannot double-count')

-- Reversed event ordering with another queued row and no duplicate purchases.
A.characterDB.auctionMail=nil; E.selected={}; E:Start(); finish()
E.selected[900001]=true; E.selected[900002]=true; E:BuySelected(); finish(); accept()
event('AUCTION_ITEM_LIST_UPDATE'); event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
sent=#queries; tick(.25); assert(#queries==sent)
finish(); assert(E.confirmation.itemId==900002)
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnCancel()
assert(not E.batch and not E.scan and not E.confirmation,'Cancel still stops the remaining purchases')

-- A genuinely missing reply still times out after a query was actually sent.
E:Start(records()[1]); tick(); assert(E.scan.phase=='waiting')
tick(21); assert(not E.scan and E.message:find('Scan timed out',1,true))
ready=false; E:Start(records()[1]); tick(61)
assert(not E.scan and E.message:find('still busy',1,true),'A permanently blocked throttle has a bounded, separate timeout')
print('PASS: multi-row purchase queue, both server event orders, stale pages, long throttles, mail receipts, cancellation and bounded timeouts')
''')
