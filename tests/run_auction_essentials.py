"""Essentials filtering, matching AH bounds, native searches and tab isolation."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text())
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text())
lua.execute('''
local A=TestAddon; local E=A.AuctionEssentials; local U=A.AuctionUpgrades
local original=A.Supplies.Build
local function record(id,name,missing,extra)
    local item={itemId=id,name=name}; for k,v in pairs(extra or {}) do item[k]=v end
    return {itemId=id,name=name,item=item,count=20-missing,target=20,missing=missing,tracking=true}
end
A.Supplies.Build=function(_,state)
    assert(state.filter=="Essentials")
    return {record(117,"Vendor food",20),record(2512,"Vendor arrows",20),
        record(10513,"Crafted ammo",200),record(999901,"User item",0),
        record(999902,"Limited stock potion",4),record(999903,"Bound item",4,{binding=true})}
end
local rows=E:Items({})
assert(#rows==3 and rows[1].name=="Crafted ammo" and rows[3].name=="User item")
E:Attach(); E.open=true
AuctionFrameTab_OnClick(E.tab)
assert(E.panel:IsShown() and not U.panel:IsShown(),"Tabs are exclusive")
assert(E.panel:GetWidth()==U.panel:GetWidth() and E.panel:GetHeight()==U.panel:GetHeight(),"Same dimensions")
assert(E.rows[1].record.itemId==10513)
local calls=0; local page=0; local ready=false; local empty=false; local bought
local originalQuery=QueryAuctionItems
QueryAuctionItems=function(name,minimum,maximum,p,usable,quality,all,exact,filters)
    calls=calls+1; page=p
    assert(not minimum and not maximum and not usable and exact and not filters)
end
CanSendAuctionQuery=function() return ready end
GetNumAuctionItems=function() return empty and 0 or 2,empty and 0 or 51 end
GetAuctionItemLink=function(_,index) return "item:10513:0:0:0" end
UnitName=function() return "Player" end
GetAuctionItemInfo=function(_,index)
    -- Page 0: lower stack total but worse per item. Page 1: cheapest unit price.
    local count=page==0 and 1 or 10
    local price=page==0 and 100 or 500
    return "Crafted ammo",nil,count,nil,nil,nil,nil,nil,nil,index==2 and 1 or price,nil,nil,nil,index==2 and "Player" or "Seller"
end
GetMoney=function() return 100000 end
StaticPopupDialogs=StaticPopupDialogs or {}; StaticPopupDialogs.BUYOUT_AUCTION={}
StaticPopup_Show=function(_,text,_,data) E.testPopup=data; E.popupText=text end
StaticPopup_Hide=function() E.testPopup=nil end
PlaceAuctionBid=function(_,index,price) bought={index,price} end
local function step()
    E:Tick()
    if E.scan and E.scan.phase=="waiting" then E.scan.phase="reading" end
end
local function finish()
    for i=1,100 do if not E.scan then return end; step() end
    error("scan did not finish")
end
E:Search(rows[1]); step(); assert(calls==0 and E.panel:IsShown(),"Throttle respected")
ready=true; finish()
assert(E.confirmation.count==10 and E.confirmation.buyout==500 and page==1,"Cheapest unit price across all pages, excluding own auctions")
assert(E.popupText=="10 x Crafted ammo" and E.panel:IsShown(),"Confirm whole stack in Essentials tab")
assert(E.rows[1].cells[6]:GetText()=="10","Separate stack column")
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnAccept(nil,E.confirmation)
assert(bought[2]==500 and not E.results[10513],"Confirmed stack buyout invalidates cached result")
E:Start(); finish(); assert(E.complete and E.results[10513].buyout==500,"Scan all finishes")
assert(E.results[999901].plan.units==0 and E.results[999902].plan.units==0,"Only exact item IDs accepted")
MOCK.Click(E.rows[1])
assert(E.selected[10513] and E.rows[1].buy:GetChecked(),"Row toggles its checkbox without purchasing")
local cost,units,need,unknown=E:Estimate()
assert(cost==600 and units==11 and need==200 and not unknown,"Whole-stack refill estimate reports limited stock")
MOCK.Click(E.rows[1].buy)
assert(not E.selected[10513],"Checkbox toggles same selection")
E:Toggle(rows[1]); E:BuySelected(); finish()
assert(E.batch and E.confirmation and E.confirmation.count==10,"Buy starts selected refill")
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnAccept(nil,E.confirmation)
assert(E.awaitingBuy and not E.scan,"Waits for success before another purchase")
E:PurchaseSucceeded(); finish()
assert(E.batch[1].remaining==1 and E.confirmation and E.confirmation.count==1 and E.confirmation.buyout==100,
    "Replans the remainder: a single costs less than another cheaper-per-item stack")
StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnCancel()
assert(not E.batch and not E.confirmation,"Cancel halts the refill queue")
E:Search(rows[1]); finish(); assert(E.confirmation)
E.events.scripts.OnEvent(nil,"AUCTION_ITEM_LIST_UPDATE")
assert(not E.confirmation,"Changed listings cancel popup")
empty=true; E:Search(rows[1]); finish(); assert(not E.confirmation and E.results[10513].plan.units==0,"No buyouts never prompts")
assert(not E.skipConfirmation:GetChecked(),"Skip confirmation defaults unchecked")
E.skipConfirmation:SetChecked(true); E.skipConfirmation.scripts.OnClick(E.skipConfirmation)
assert(A.characterDB.essentialSkipConfirmation==true,"Checkbox saves preference")
empty=false; bought=nil; E:Search(rows[1]); finish()
assert(bought and bought[2]==500 and E.awaitingBuy and not E.confirmation and not E.testPopup,"Enabled skip buys verified stack without popup")
E:Stop(); bought=nil
local listing=E:Listing(1,10513); listing.buyout=1
E:Confirm(listing)
assert(not bought and not E.awaitingBuy,"Skip still rejects changed listings")
E.skipConfirmation:SetChecked(false); E.skipConfirmation.scripts.OnClick(E.skipConfirmation)
E:Search(rows[1]); finish()
assert(E.confirmation and not bought,"Disabling skip restores confirmation")
E:Stop()
AuctionFrame:SetSize(900,500); U:Layout(); E:Refresh()
assert(E.panel:GetWidth()==U.panel:GetWidth() and E.panel:GetHeight()==U.panel:GetHeight())
E:Start(); AuctionFrameTab_OnClick(U.tab)
assert(not E.panel:IsShown() and U.panel:IsShown() and not E.scan,"Switching tabs stops scan")
E.open=false; local before=calls; E:Search(rows[1]); assert(calls==before,"Closed AH cannot query")
QueryAuctionItems=originalQuery
A.Supplies.Build=original
print("PASS: Essentials vendor filtering, tradeable items, sorting, tab isolation, geometry, throttling and exact native searches")
''')
