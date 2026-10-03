"""Confirmed auction mail stock, collection, partial inboxes and refill filtering."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text())
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text())
lua.execute(r'''
local A,E=TestAddon,TestAddon.AuctionEssentials
HardcoreBuddyCharacterDB=A.characterDB -- The auction fixture uses an isolated character table.
local checks=0
local function check(ok,msg) checks=checks+1; assert(ok,msg) end
local timestamp,clock=100000,100
time=function() return timestamp end; GetTime=function() return clock end
local bags={}; A.Inventory.Read=function() return {available=true,counts=bags} end
local originalContext=A.GetContext
local function context() local c=originalContext(A); c.inventory={available=true,counts=bags}; return c end
A.GetContext=context
local target=20
A.Supplies.Build=function()
 return {{itemId=900001,name='Test Potion',item={itemId=900001},count=bags[900001] or 0,target=target,missing=target-(bags[900001] or 0),tracking=true,refillNeeded=true}}
end
A.characterDB.auctionMail=nil; A.characterDB.auctionBank=nil
E:Attach(); E.open=true; AuctionFrameTab_OnClick(E.tab)
local function receipt(id,count)
 E.awaitingBuy={listing={itemId=id,count=count,name='Test Potion'},since=clock}
 E.purchaseReceipt=E.awaitingBuy
 ERR_AUCTION_BID_PLACED='Bid accepted'
 E.events.scripts.OnEvent(nil,'CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
end
check(E:MailCount(900001)==0,'No speculative owned purchases')
receipt(900001,8)
check(E:MailCount(900001)==8,'Confirmed purchase recorded')
E:PurchaseSucceeded(); check(E:MailCount(900001)==8,'Duplicate success cannot count twice')
bags[900001]=3; A.characterDB.auctionBank={counts={[900001]=4}}
E:Refresh()
check(E.items[1].count==15 and E.items[1].missing==5,'Bags, bank and pending mail cover refill')
check(E.rows[1].cells[2]:GetText()=='15','Owned stock includes mail without an extra mail quantity')
check(E.mailStatus:IsShown() and E.mailStatus.label:GetText()=='Items in Mail','Mail reminder has no quantity')
receipt(900001,5)
check(#E.items==0 and not E.rows[1]:IsShown(),'Fulfilled purchase row disappears immediately')
check(E.mailStatus:IsShown(),'Mail notice remains when all refill rows are hidden')
local original=A.characterDB.auctionMail
A:Initialize(); check(A.characterDB.auctionMail==original and E:MailCount(900001)==13,'Mail cache survives initialization')
E.awaitingBuy={listing={itemId=900001,count=2,name='Test Potion'},since=clock}; E.purchaseReceipt=E.awaitingBuy
E:Stop(); E.open=false; E:PurchaseSucceeded()
check(E:MailCount(900001)==15,'Acknowledgement after closing AH is still recorded')

-- A new arrival is merged with the receipt, not added a second time.
A.characterDB.auctionMail=nil; A.characterDB.auctionBank=nil; bags={}
receipt(900001,10)
local mails={}; local total=0; local unavailable=false
GetInboxNumItems=function() return #mails,total end
GetInboxHeaderInfo=function(index)
 local m=mails[index]
 if unavailable then return end
 return nil,nil,'Auction House','Won item',0,0,29,m.count and 1 or nil
end
GetInboxItem=function(index,slot)
 local m=mails[index]
 if m and slot==1 and m.count and not m.unloaded then return 'Test Potion',m.id,134400,m.count end
end
E.mailEvents.scripts.OnEvent(nil,'MAIL_SHOW')
check(E:MailCount(900001)==10,'Opening a loading mailbox does not erase receipts')
E:CaptureMail(); check(E:MailCount(900001)==10,'Recent unarrived purchase survives empty inbox')
mails={{id=900001,count=10}}; total=1
E:CaptureMail(); check(E:MailCount(900001)==10 and A.characterDB.auctionMail.items[900001].pending==0,'Observed delivery replaces receipt')
receipt(900001,4); E:CaptureMail()
check(E:MailCount(900001)==14,'Existing inbox stock and a new unarrived purchase stay separate')
mails[2]={id=900001,count=4}; total=2; E:CaptureMail()
check(E:MailCount(900001)==14 and A.characterDB.auctionMail.items[900001].pending==0,'Second delivery not double counted')

-- Mail update before bag update; partial pickup and repeated events are stable.
E:TrackMailTake(2,1); mails[2]=nil; total=1; E:CaptureMail()
bags[900001]=4; E.mailEvents.scripts.OnEvent(nil,'BAG_UPDATE_DELAYED')
check(E:MailCount(900001)==10,'Mail-first collection decremented exactly once')
E:UpdateMailTakes(); E:CaptureMail(); check(E:MailCount(900001)==10,'Repeated refreshes do not consume stock')
E:TrackMailTake(1,1); E:UpdateMailTakes()
check(E:MailCount(900001)==10,'Failed pickup or full bags does not lose cached stock')
clock=clock+11; bags[900001]=6; E:UpdateMailTakes()
check(not next(E.mailTakes) and E:MailCount(900001)==10,'Expired failed retrieval cannot consume unrelated bag gains')
bags[900001]=4
-- Bag update before mail update, including an immediate mailbox close.
E:TrackMailTake(1,1); bags[900001]=14
E.mailEvents.scripts.OnEvent(nil,'BAG_UPDATE_DELAYED')
mails={}; total=0; E:CaptureMail(); E.mailEvents.scripts.OnEvent(nil,'MAIL_CLOSED')
check(E:MailCount(900001)==0,'Bag-first retrieval moves stock out of mail')
E:Refresh(); check(E.items[1].count==14 and E.items[1].missing==6,'Collected stock now counted in bags')
bags[900001]=20; E:Refresh(); check(#E.items==0,'Bag target fulfilled without mail is hidden')

-- A partial inbox cannot wipe unseen purchased stacks; successful pickups still count.
bags={}; receipt(900001,20); mails={{id=900001,count=20}}; total=1
E.mailEvents.scripts.OnEvent(nil,'MAIL_SHOW'); E:CaptureMail()
mails={{id=900001,count=4}}; total=5; E:CaptureMail()
check(E:MailCount(900001)==20,'Incomplete mailbox retains unseen stock')
E:TrackMailTake(1,1); bags[900001]=4; E:UpdateMailTakes()
check(E:MailCount(900001)==16,'Pickup reconciles even when only some mail is loaded')
unavailable=true; E:CaptureMail(); check(E:MailCount(900001)==16,'Loading headers preserve cache')
unavailable=false; mails[1].unloaded=true; E:CaptureMail()
check(E:MailCount(900001)==16,'Loading attachments preserve cache')
mails={{id=900001,count=16}}; total=1; E:CaptureMail()
check(E:MailCount(900001)==16,'Complete snapshot agrees after partial collection')
E.mailEvents.scripts.OnEvent(nil,'MAIL_CLOSED'); mails={}; total=0; E:CaptureMail()
check(E:MailCount(900001)==16,'Closed mailbox cannot clear cached stock')

-- Old unobserved receipts are corrected on a complete mailbox visit.
A.characterDB.auctionMail=nil; receipt(900001,5); timestamp=timestamp+121
E.mailEvents.scripts.OnEvent(nil,'MAIL_SHOW'); E:CaptureMail()
check(E:MailCount(900001)==0,'Old empty mailbox reconciles stale receipt')
receipt(900001,3); timestamp=timestamp+30*24*60*60+1
check(E:MailCount(900001)==0,'Expired auction mail no longer suppresses refills')

-- Pending crafting materials cover requirements and disappear from purchase rows.
bags={}; A.characterDB.auctionMail=nil
A.Data.AuctionRecipes[900001]={spellId=1001,output=1,reagents={{900010,1,'Material'}}}
C_SpellBook={IsSpellKnown=function(id) return id==1001 end}
C_Item.GetItemInfo=function(id) return 'Material' end
A.characterDB.auctionEssentialsPreferCraft=true; receipt(900010,20); E:Refresh()
check(#E.items==0 and #E.craftParents[1].children==1,'Fully covered material and finished craft are hidden together')
check(E.craftParents[1].children[1].mailUsed==20 and E:CraftCost(E.craftParents[1])==0,'Mail materials reduce crafting cost')
check(not E.rows[1]:IsShown(),'Materials in mail cannot be bought again')
local co=coroutine.create(function() E:PreparePlans() end)
repeat local ok,err=coroutine.resume(co); assert(ok,err) until coroutine.status(co)=='dead'
check(#E.items==0 and E:PreferCraft(),'A subsequent cost comparison does not resurrect a ready craft')
E:RecordMailPurchase({itemId=900010,count=5,name='Material'})
E.mailEvents.scripts.OnEvent(nil,'MAIL_CLOSED')
local character=A.characterDB
A.characterDB={}; check(E:MailCount(900010)==0,'Mail cache never leaks to another character'); A.characterDB=character
E.awaitingBuy={listing={itemId=900010,count=99,name='Material'},since=clock}; E.purchaseReceipt=E.awaitingBuy
E.events.scripts.OnEvent(nil,'UI_ERROR_MESSAGE',2,'Not enough money')
E.events.scripts.OnEvent(nil,'CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
check(E:MailCount(900010)==25,'Failed purchase cannot be cached by a later unrelated success')
-- Multiple materials must all be funded before the craft disappears.
A.Data.AuctionRecipes[900001].reagents={{900010,2,'Material A'},{900011,1,'Material B'}}
E:Refresh(); check(#E.items==3 and not E.craftParents[1].readyToCraft,'Partially funded craft stays visible')
receipt(900011,20); E:Refresh()
check(#E.items==2 and E.items[1].itemId==900001,'One completed material does not hide an incomplete craft')
receipt(900010,15); E:Refresh()
check(#E.items==0 and E.craftParents[1].readyToCraft,'Last successful material purchase removes parent and children')
print('PASS: '..checks..' auction mail assertions, receipts, persistence, collection order, incomplete inboxes and refill filtering')
''')

def plain(value):
    return {k: plain(v) for k, v in value.items()} if hasattr(value, 'items') else value

character = plain(lua.globals().HardcoreBuddyCharacterDB)
fresh, fresh_addon = boot()
fresh.globals().HardcoreBuddyCharacterDB = fresh.table_from(character, recursive=True)
fresh.execute("time=function() return " + str(lua.eval('time()')) + " end")
fresh.execute("TestAddon:Initialize(); assert(TestAddon.AuctionEssentials:MailCount(900010)==40)")
print('PASS: mail stock restored from character SavedVariables in fresh Lua runtime')
