"""Refill eligibility, per-row purchases, saved prices, and compact table layout."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua, addon = boot()
for name in ('gear_advisor.lua', 'auction_upgrades.lua', 'auction_essentials_fixture.lua'):
    lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
lua.execute(r'''
local A,E,F=TestAddon,TestAddon.AuctionEssentials,ESSENTIAL_FIXTURE
F.stock={
 [117]={name='Vendor food',target=20}, [2512]={name='Vendor arrows',target=1000},
 [10513]={name='Crafted ammo',target=200}, [999901]={name='User item',target=20,count=0},
 [999902]={name='Above refill amount',target=20,count=6,refillNeeded=false},
 [999903]={name='Bound item',target=1,item={itemId=999903,binding=true}},
 [999904]={name='Refill disabled',target=20,refillNeeded=false},
 [999905]={name='Fully covered',target=20,count=0},
}
A.characterDB.auctionBank={counts={[999905]=20}}
E:Refresh()
assert(#E.items==2 and E.items[1].itemId==10513 and E.items[2].itemId==999901,'Only low-stock, tradeable, non-vendor Essentials, including user items')
assert(E.panel:GetWidth()==A.AuctionUpgrades.panel:GetWidth() and E.panel:GetHeight()==A.AuctionUpgrades.panel:GetHeight())
assert(#E.headers==7 and E.headers[2]:GetText()=='OWNED' and E.headers[7]:GetText()=='BUY')
assert(not E.buy and not E.total and not E.rows[1].craft,'No basket footer or Craft column')
assert(E.rows[1].buy.label:GetText()=='Buy' and not E.rows[1].buy:IsEnabled(),'Unscanned Buy is disabled')
assert(select(5,E.rows[1]:GetPoint())==-72 and select(5,E.headers[1]:GetPoint())==-50,'Table moved up ten pixels')
F.auctions={
 [10513]={[0]={{count=1,price=100},{count=200,price=1,owner='Player'}},[1]={{count=10,price=500}},total=51},
 [999901]={[0]={}},
}
F.ready=false; E:Start(); F.tick(); assert(#F.queries==0,'Respect throttle')
F.ready=true; F.finish()
assert(E.complete and #F.queries==3,'Scan each needed item and every price page exactly once')
assert(E:RowPlan(E.items[1]).cost==600 and E:RowPlan(E.items[1]).units==11,'Cheapest available whole stacks, excluding player auctions')
assert(E.rows[1].cells[5]:GetText()=='11','Quantity covers the complete saved plan')
assert(E.rows[1].buy:IsEnabled() and not E.rows[2].buy:IsEnabled())
local calls=#F.queries
MOCK.Click(E.rows[1].buy); F.finish()
assert(#F.queries==calls+1 and F.queries[#F.queries].page==1,'Buy loads only the saved offer page, never rescans')
assert(E.confirmation.count==10 and E.confirmation.buyout==500 and F.popupText=='10 x Crafted ammo')
F.accept(); assert(E:MailCount(10513)==0,'Only confirmed purchases count as stock')
F.ack(); F.finish()
assert(E.confirmation.count==1 and E.confirmation.buyout==100 and #F.queries==calls+2,'Next saved stack prompts without a new search plan')
F.accept(); F.ack(true); F.finish()
assert(not E.batch and E:MailCount(10513)==11 and #F.purchases==2)
assert(not E.rows[1].buy:IsEnabled(),'Consumed cached offers cannot be purchased twice')

-- Buy the current page directly, rechecking the exact listing at both click and accept.
F.reset(); F.stock={[900001]={name='Potion',target=5}}
F.auctions={[900001]={[0]={{count=5,price=50}}}}
E:Start(); F.finish(); calls=#F.queries
E:BuyRow(E.items[1]); assert(E.confirmation and #F.queries==calls,'Already loaded listing needs no query')
F.auctions[900001][0][1].price=500
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnAccept(nil,E.confirmation)
assert(not E.confirmation and #F.purchases==0,'Price changed after prompt: never buy')
E:Start(); F.finish(); E:BuyRow(E.items[1]); F.finish()
F.event('AUCTION_ITEM_LIST_UPDATE'); assert(not E.confirmation,'New server listing update invalidates prompt')
E:BuyRow(E.items[1]); F.finish()
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnCancel(); assert(not E.batch and not E.confirmation)
-- Existing skip-confirmation preference cannot bypass standard confirmation.
A.characterDB.essentialSkipConfirmation=true
E:BuyRow(E.items[1]); F.finish(); assert(E.confirmation and #F.purchases==0)
E:Stop(); F.auctions[900001][0]={}
E:BuyRow(E.items[1]); F.finish()
assert(not E.confirmation and E.message:find('no longer available',1,true),'Sold listing never substitutes a more expensive one')
E:Start(); F.finish(); assert(not E.rows[1].buy:IsEnabled(),'No results never offers Buy')

-- Latest stock supersedes an old row and forces cost review before purchase.
F.auctions[900001][0]={{count=5,price=50},{count=1,price=10}}
E:Start(); F.finish(); local old=E.items[1]
F.stock[900001].count=4; E:BuyRow(old); F.finish()
assert(not E.confirmation and E.items[1].missing==1,'Changed stock updates cached price without buying old quantity')
F.stock[900001].refillNeeded=false; E:BuyRow(old); assert(#E.items==0)
F.stock[900001].refillNeeded=true
E:Start(); AuctionFrameTab_OnClick(A.AuctionUpgrades.tab)
assert(not E.panel:IsShown() and A.AuctionUpgrades.panel:IsShown() and not E.scan,'Tab switch stops pending action')
E.open=false; calls=#F.queries; E:BuyRow(old); E:Start(); assert(#F.queries==calls)
AuctionFrame:SetSize(900,500); A.AuctionUpgrades:Layout(); E:Refresh()
assert(E.panel:GetWidth()==A.AuctionUpgrades.panel:GetWidth() and E.panel:GetHeight()==A.AuctionUpgrades.panel:GetHeight(),'Resize remains aligned with Upgrades')
print('PASS: Essentials refill gate, user items, table layout, per-row Buy, cached plans, native confirmation and stale-listing protection')
''')
