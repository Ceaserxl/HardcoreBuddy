-- Scan prices once; buying loads only the saved offer's page and verifies its price.
local _,A=...
local E=A.AuctionEssentials
local popup="HARDCOREBUDDY_ESSENTIAL_BUYOUT"
function E:Stop(message)
    self.scan=nil; self.confirmation=nil
    self.batch=nil; self.awaitingBuy=nil
    if StaticPopup_Hide then StaticPopup_Hide(popup) end
    if message then self.message=message end
    self:Refresh()
end
function E:Start()
    if self:Busy() or not self.open or not self.panel:IsShown() then return end
    self:Stop()
    self.complete=false
    local queue,message=self:ScanItems()
    if not queue then self.message=message; self:Refresh(); return end
    self.results={}
    if #queue==0 then self.message="No Essentials to scan."; self:Refresh(); return end
    self.scan={queue=queue,item=1,page=0,phase="query",since=GetTime()}
    self.message="Scanning Essentials..."
    self:Refresh()
end
local function cheaper(a,b)
    if not b then return true end
    local av,bv=a.buyout*b.count,b.buyout*a.count
    if av~=bv then return av<bv end
    return a.buyout<b.buyout -- Equal unit price: prefer the smaller total purchase.
end
function E:Listing(index,id)
    local name,_,count,_,_,_,_,_,_,buyout,_,_,_,owner=GetAuctionItemInfo("list",index)
    local link=GetAuctionItemLink("list",index)
    if not name or not link or not count or count<=0 or not owner or owner=="" then return nil,false end
    if tonumber(link:match("item:(%d+)"))~=id or not buyout or buyout<=0
        or owner==UnitName("player") or self.ownSellers and self.ownSellers[owner] then return nil,true end
    return {name=name,link=link,count=count,buyout=buyout,owner=owner,index=index,itemId=id},true
end
function E:AcceptPurchase(data)
    if self.confirmation~=data or not self.open or not self.panel:IsShown() or self.scan or self.purchaseReceipt then return end
    local current,loaded=self:Listing(data.index,data.itemId)
    if not loaded or not current or current.link~=data.link or current.count~=data.count
        or current.buyout~=data.buyout or current.owner~=data.owner then
        self:Stop("Listing changed. Scan again for current offers."); return
    end
    if GetMoney()<data.buyout then self:Stop("Not enough money for this stack."); return end
    self.confirmation=nil
    self.awaitingBuy={listing=data,since=GetTime()}
    self.purchaseReceipt=self.awaitingBuy
    self.loadedPage=nil
    PlaceAuctionBid("list",data.index,data.buyout)
    self.message="Waiting for the auction house to confirm the purchase."; self:Refresh()
end
function E:Confirm(listing)
    if not StaticPopupDialogs or not StaticPopupDialogs.BUYOUT_AUCTION then self:Stop("Buyout confirmation unavailable."); return end
    if not StaticPopupDialogs[popup] then
        local dialog={}; for k,v in pairs(StaticPopupDialogs.BUYOUT_AUCTION) do dialog[k]=v end
        dialog.text="Buy %s?"; dialog.OnShow=function(frame,data) MoneyFrame_Update(frame.MoneyFrame,data.buyout) end
        dialog.OnCancel=function() E:Stop("Purchase cancelled.") end
        dialog.OnAccept=function(_,data) E:AcceptPurchase(data) end
        StaticPopupDialogs[popup]=dialog
    end
    self.scan=nil; self.confirmation=listing
    self.message="Confirm the stack quantity and total buyout."
    StaticPopup_Show(popup,listing.count.." x "..listing.name,nil,listing)
    self:Refresh()
end
function E:Tick()
    if self.awaitingBuy then
        if GetTime()-self.awaitingBuy.since>20 then self:Stop("Purchase confirmation timed out. Check your mail before retrying.") end
        return
    end
    local s=self.scan; if not s then return end
    if not self.open or not self.panel:IsShown() then self:Stop(); return end
    -- Query throttling is separate from waiting for an actual server reply.
    -- Refill batches can legitimately spend longer than 20 seconds throttled.
    if GetTime()-s.since>(s.phase=="query" and 60 or 20) then
        self:Stop(s.phase=="query" and "Auction house is still busy. Try the remaining refills again." or "Scan timed out. Rescan before buying."); return
    end
    local record=s.queue and s.queue[s.item]
    if s.phase=="settling" then
        -- The bid acknowledgement can precede the old result-page update.
        -- Drain that update before requesting the next stack's page; otherwise it
        -- can be mistaken for the response to the new search.
        local updated=s.settle.listUpdated
        if updated and GetTime()-updated>=.5 or not updated and GetTime()-s.since>=2 then
            s.phase="query"; s.since=GetTime(); s.settle=nil
        end
    elseif s.phase=="craftPlanning" then
        local ok=coroutine.resume(s.planner)
        if not ok then self:Stop("Unable to compare crafting costs. Scan again."); return end
        if coroutine.status(s.planner)~="dead" then s.since=GetTime(); return end
        self.scan=nil; self.complete=true
        self.message=s.message or ("Scan complete. Refills use the lowest total cost."..self:CraftNotice())
        self:Refresh()
    elseif s.phase=="planning" then
        local ok,calculated=coroutine.resume(s.planner)
        if not ok then self:Stop("Unable to calculate refill. Scan again."); return end
        if coroutine.status(s.planner)~="dead" then s.since=GetTime(); return end
        local plan=calculated.plan
        local result=self.results[record.itemId]
        result.plan=plan; result.plans=calculated.plans
        result.ceiling=plan.ceiling
        if plan.offers[1] then
            result.count=plan.offers[1].count; result.buyout=plan.offers[1].buyout
        else result.count=nil; result.buyout=nil end
        s.item=s.item+1; s.page=0; s.best=nil; s.offers=nil; s.phase="query"; s.since=GetTime()
        if s.item>#s.queue then
            s.phase="craftPlanning"; s.planner=coroutine.create(function() self:PreparePlans() end)
            self.message="Preparing refill costs..."
        else self.message="Scanning "..s.item.." / "..#s.queue..": "..s.queue[s.item].name end
        self:Refresh()
    elseif s.phase=="query" then
        if not CanSendAuctionQuery() then
            if not s.throttled then
                s.throttled=true; self.message="Waiting for the auction house: "..record.name; self:Refresh()
            end
            return
        end
        s.throttled=nil
        self.loadedPage=nil
        s.phase="waiting"; s.since=GetTime(); self.sending=true
        QueryAuctionItems(record.name,nil,nil,s.page,false,nil,false,true,nil)
        self.sending=false
    elseif s.phase=="reading" then
        local count,total=GetNumAuctionItems("list")
        if count==0 and total>0 then return end
        local pageBest,verified,pageOffers=nil,nil,{}
        for i=1,count do
            -- A delayed update for a different search is not this query's
            -- result. Different IDs with the same exact name still get filtered
            -- normally; they are legitimate results, not stale pages.
            local link=GetAuctionItemLink("list",i)
            if link and tonumber(link:match("item:(%d+)"))~=record.itemId
                and GetAuctionItemInfo("list",i)~=record.name then return end
            local listing,loaded=self:Listing(i,record.itemId)
            if not loaded then return end
            if listing then
                listing.page=s.page
                pageOffers[#pageOffers+1]=listing
                if s.verify and listing.link==s.best.link and listing.buyout==s.best.buyout and listing.count==s.best.count and listing.owner==s.best.owner then
                    verified=listing
                end
                if cheaper(listing,pageBest) then pageBest=listing end
            end
        end
        self.loadedPage={itemId=record.itemId,page=s.page}
        if s.verify then
            if verified then verified.savedOffer=s.best; self:Confirm(verified)
            else self:Stop("Saved listing is no longer available. Scan again for current offers.") end
            return
        end
        s.offers=s.offers or {}
        for _,listing in ipairs(pageOffers) do s.offers[#s.offers+1]=listing end
        if pageBest and cheaper(pageBest,s.best) then s.best=pageBest end
        if (s.page+1)*50<total then s.page=s.page+1; s.phase="query"; s.since=GetTime(); return end
        local result=false
        if s.best then
            table.sort(s.offers,cheaper)
            result={}; for k,v in pairs(s.best) do result[k]=v end
            result.offers=s.offers
        end
        self.results=self.results or {}; self.results[record.itemId]=result
        if not result then result={offers={}}; self.results[record.itemId]=result end
        local need=record.missing or 0
        local needs=self:PlanNeeds(record.itemId)
        s.planner=coroutine.create(function()
            local plans={}
            for _,quantity in ipairs(needs) do plans[quantity]=self:RefillPlan(result.offers,quantity,nil,true) end
            local plan=plans[need] or self:RefillPlan(result.offers,need,nil,true)
            plans[need]=plan
            return {plan=plan,plans=plans}
        end)
        s.phase="planning"; s.since=GetTime()
    end
end
