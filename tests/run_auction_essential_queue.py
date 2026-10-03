"""Saved multi-stack refills: event ordering, own auctions, throttles and timeouts."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua, addon = boot()
for name in ('gear_advisor.lua', 'auction_upgrades.lua', 'auction_essentials_fixture.lua'):
    lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
lua.execute(r'''
local A,E,F=TestAddon,TestAddon.AuctionEssentials,ESSENTIAL_FIXTURE
local function setup()
 F.reset()
 F.stock={[900001]={name='A Potion',target=10},[900002]={name='B Potion',target=8}}
 F.auctions={[900001]={[0]={{count=5,price=50,owner='AltSeller'},{count=5,price=60,owner='Seller'}}},
             [900002]={[0]={{count=8,price=80}}}}
 E:Start(); F.finish(); E:BuyRow(E.items[1]); F.finish(); F.accept()
end
setup(); local sent=#F.queries
F.ack()
assert(E.scan.phase=='settling' and E.batch.remaining==5)
F.tick(.1); assert(#F.queries==sent)
F.event('AUCTION_ITEM_LIST_UPDATE'); F.tick(.6)
F.ready=false; F.tick(); F.tick(25)
assert(E.scan and E.scan.phase=='query' and #F.queries==sent,'Long throttle does not trigger response timeout')
F.ready=true; F.tick()
assert(E.scan.phase=='waiting' and #F.queries==sent+1)
F.displayed={id=900002,page=0}; F.event('AUCTION_ITEM_LIST_UPDATE'); F.tick()
assert(E.scan.phase=='reading' and not E.confirmation,'Ignore stale different item page')
F.deliver(); F.finish(); assert(E.confirmation.itemId==900001 and E.confirmation.buyout==60)
F.accept(); F.ack(true); F.finish()
assert(#F.purchases==2 and not E.batch and not E.scan and #E.items==1 and E.items[1].itemId==900002,'One row never purchases another row')
assert(E:MailCount(900001)==10 and E:MailCount(900002)==0)
F.event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED); assert(E:MailCount(900001)==10)
E:BuyRow(E.items[1]); F.finish(); F.accept(); F.ack(); F.finish()
assert(E:MailCount(900002)==8 and #E.items==0,'Another row can buy its own cached plan')

setup(); F.ack(true); sent=#F.queries; F.tick(.25); assert(#F.queries==sent)
F.finish(); assert(E.confirmation.buyout==60)
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnCancel()
assert(not E.batch and not E.scan and not E.confirmation,'Cancel stops remaining saved stacks')

setup(); sent=#F.queries
F.event('UI_ERROR_MESSAGE',1,ERR_AUCTION_BID_OWN)
assert(E.batch.remaining==10 and not E.awaitingBuy and E:MailCount(900001)==0,'Rejected own auction fills nothing')
F.finish(); assert(E.confirmation.owner=='Seller' and #F.queries==sent+1,'Continue remaining saved offers, without rescanning')
F.accept(); F.ack(); F.finish()
assert(E:MailCount(900001)==5 and not E.batch and E.message:find('incomplete',1,true))

setup(); F.event('UI_ERROR_MESSAGE',2,'Not enough money')
F.event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
assert(not E.awaitingBuy and not E.scan and E:MailCount(900001)==0,'Unrelated error stops and clears receipt')
setup(); F.tick(21)
assert(not E.awaitingBuy and not E.batch and E.message:find('timed out',1,true),'Unacknowledged bid has bounded timeout')
F.reset(); F.stock={[900001]={name='Potion',target=1}}; F.auctions={[900001]={[0]={{count=1,price=10}}}}
E:Start(); F.tick(); assert(E.scan.phase=='waiting'); F.tick(21)
assert(not E.scan and E.message:find('Scan timed out',1,true))
F.ready=false; E:Start(); F.tick(61)
assert(not E.scan and E.message:find('still busy',1,true))
print('PASS: saved multi-stack queue, both event orders, stale pages, long throttles, own-auction skip, mail accounting and timeouts')
''')
