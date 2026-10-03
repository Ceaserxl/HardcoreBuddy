-- Mock the legacy auction API, including separately delivered result pages.
local A,E=TestAddon,TestAddon.AuctionEssentials
local F={clock=100,stock={},auctions={},queries={},purchases={},ready=true}
ESSENTIAL_FIXTURE=F
GetTime=function() return F.clock end
A.GetContext=function() return {inventory={available=true,counts=F.bags or {}}} end
A.Supplies.Build=function(_,state)
    assert(state.filter=='Essentials')
    local records={}
    for id,s in pairs(F.stock) do
        records[#records+1]={itemId=id,name=s.name,item=s.item or {itemId=id},count=s.count or 0,
            target=s.target,missing=s.target-(s.count or 0),tracking=true,refillNeeded=s.refillNeeded~=false}
    end
    return records
end
UnitName=function() return 'Player' end
CanSendAuctionQuery=function() return F.ready end
QueryAuctionItems=function(name,minimum,maximum,page,usable,quality,all,exact,filters)
    assert(F.ready and not minimum and not maximum and not usable and exact and not filters)
    F.queries[#F.queries+1]={name=name,page=page}
    local id
    for key,s in pairs(F.stock) do if s.name==name then id=key end end
    for key,pages in pairs(F.auctions) do if pages.name==name then id=key end end
    assert(id,'Unexpected query: '..name)
    F.wanted={id=id,page=page}
end
GetNumAuctionItems=function()
    if not F.displayed then return 0,0 end
    local pages=F.auctions[F.displayed.id] or {}
    local rows=pages[F.displayed.page] or {}
    return #rows,pages.total or #rows
end
GetAuctionItemLink=function(_,index)
    local pages=F.displayed and F.auctions[F.displayed.id]
    local row=pages and pages[F.displayed.page] and pages[F.displayed.page][index]
    return row and 'item:'..F.displayed.id..':0'
end
GetAuctionItemInfo=function(_,index)
    local id=F.displayed and F.displayed.id
    local pages=id and F.auctions[id]
    local r=pages and pages[F.displayed.page] and pages[F.displayed.page][index]
    if r then return pages.name or F.stock[id].name,nil,r.count,nil,nil,nil,nil,nil,nil,r.price,nil,nil,nil,r.owner or 'Seller' end
end
GetMoney=function() return F.money or 10000000 end
PlaceAuctionBid=function(_,index,price)
    local rows=F.auctions[F.displayed.id][F.displayed.page]
    assert(rows[index].price==price,'Never bid on a stale index or changed price')
    F.purchases[#F.purchases+1]={id=F.displayed.id,page=F.displayed.page,index=index,count=rows[index].count,price=price}
end
StaticPopupDialogs=StaticPopupDialogs or {}; StaticPopupDialogs.BUYOUT_AUCTION={}
StaticPopup_Show=function(_,text,_,data) F.popup=data; F.popupText=text end
StaticPopup_Hide=function() F.popup=nil end
ERR_AUCTION_BID_PLACED='Bid accepted'; ERR_AUCTION_BID_OWN='Cannot buy own auction'
function F.event(name,...) E.events.scripts.OnEvent(E.events,name,...) end
function F.tick(seconds) F.clock=F.clock+(seconds or .25); E.events.scripts.OnUpdate(E.events) end
function F.deliver() F.displayed=F.wanted; F.event('AUCTION_ITEM_LIST_UPDATE') end
function F.finish()
    for i=1,1000 do
        if not E.scan then return end
        F.tick()
        if E.scan and E.scan.phase=='waiting' then F.deliver() end
    end
    error('Action did not finish')
end
function F.accept()
    assert(E.confirmation,'Expected regular buy confirmation')
    StaticPopupDialogs.HARDCOREBUDDY_ESSENTIAL_BUYOUT.OnAccept(nil,E.confirmation)
    assert(E.awaitingBuy)
end
function F.ack(updateFirst)
    local p=F.purchases[#F.purchases]
    table.remove(F.auctions[p.id][p.page],p.index)
    if updateFirst then F.event('AUCTION_ITEM_LIST_UPDATE') end
    F.event('CHAT_MSG_SYSTEM',ERR_AUCTION_BID_PLACED)
end
function F.reset()
    E:Stop(); E.purchaseReceipt=nil; E.loadedPage=nil; E.results={}; E.ownSellers=nil; E.complete=false
    A.characterDB.auctionMail=nil; A.characterDB.auctionBank=nil; A.characterDB.auctionEssentialsPreferCraft=false
    A.characterDB.auctionEssentialsShowAll=false
    F.stock={}; F.auctions={}; F.queries={}; F.purchases={}; F.ready=true; F.money=nil
    F.displayed=nil; F.wanted=nil; F.bags={}; E.message=nil
end
E:Attach(); E.open=true; AuctionFrameTab_OnClick(E.tab)
F.reset()
