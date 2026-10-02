-- Page every exact-item query before selecting a buyout. Never buy from cached indices.
local _,A=...
local E=A.AuctionEssentials
local popup="HARDCOREBUDDY_ESSENTIAL_BUYOUT"
function E:Stop(message,keepBatch)
    self.scan=nil; self.confirmation=nil
    if not keepBatch then self.batch=nil; self.awaitingBuy=nil end
    if StaticPopup_Hide then StaticPopup_Hide(popup) end
    if message then self.message=message end
    self:Refresh()
end
function E:Start(record,keepBatch)
    if not self.open or not self.panel:IsShown() then return end
    self:Stop(nil,keepBatch)
    self.complete=false
    local queue,message
    if record then queue={record} else queue,message=self:ScanItems() end
    if not queue then self.message=message; self:Refresh(); return end
    if not record then self.results={} end
    if #queue==0 then self.message="No Essentials to scan."; self:Refresh(); return end
    self.scan={queue=queue,item=1,page=0,phase="query",since=GetTime(),purchase=record~=nil}
    self.message=record and "Checking the cheapest current buyout..." or "Scanning Essentials..."
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
        or owner==UnitName("player") then return nil,true end
    return {name=name,link=link,count=count,buyout=buyout,owner=owner,index=index,itemId=id},true
end
function E:AcceptPurchase(data)
    if self.confirmation~=data or not self.open or not self.panel:IsShown() or self.scan then return end
    local current,loaded=self:Listing(data.index,data.itemId)
    if not loaded or not current or current.link~=data.link or current.count~=data.count
        or current.buyout~=data.buyout or current.owner~=data.owner then
        self:Stop("Listing changed. Click the item to check again."); return
    end
    if GetMoney()<data.buyout then self:Stop("Not enough money for this stack."); return end
    self.confirmation=nil
    self.awaitingBuy={listing=data,since=GetTime()}
    PlaceAuctionBid("list",data.index,data.buyout)
    self.results[data.itemId]=nil; self.complete=false
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
    if GetTime()-s.since>20 then self:Stop("Scan timed out. Rescan before buying."); return end
    local record=s.queue[s.item]
    if s.phase=="craftPlanning" then
        local ok=coroutine.resume(s.planner)
        if not ok then self:Stop("Unable to compare crafting costs. Scan again."); return end
        if coroutine.status(s.planner)~="dead" then s.since=GetTime(); return end
        self.scan=nil; self.complete=true
        self.message="Scan complete. Refills use the lowest total cost."..self:CraftNotice()
        self:Refresh()
    elseif s.phase=="planning" then
        local ok,calculated=coroutine.resume(s.planner)
        if not ok then self:Stop("Unable to calculate refill. Scan again."); return end
        if coroutine.status(s.planner)~="dead" then return end
        local plan=calculated.plan
        local result=self.results[record.itemId]
        result.plan=plan; result.plans=calculated.plans
        if plan.offers[1] then
            result.count=plan.offers[1].count; result.buyout=plan.offers[1].buyout
        else result.count=nil; result.buyout=nil end
        if s.purchase then
            s.best=plan.offers[1]
            if not s.best then self:Stop("No reasonably priced refill is available."); return end
            s.page=s.best.page; s.verify=true; s.phase="query"; s.since=GetTime(); self:Refresh(); return
        end
        s.item=s.item+1; s.page=0; s.best=nil; s.offers=nil; s.phase="query"; s.since=GetTime()
        if s.item>#s.queue then
            s.phase="craftPlanning"; s.planner=coroutine.create(function() self:SelectCheaperCrafts() end)
            self.message="Comparing crafting costs..."
        else self.message="Scanning "..s.item.." / "..#s.queue..": "..s.queue[s.item].name end
        self:Refresh()
    elseif s.phase=="query" then
        if not CanSendAuctionQuery() then return end
        s.phase="waiting"; s.since=GetTime(); self.sending=true
        QueryAuctionItems(record.name,nil,nil,s.page,false,nil,false,true,nil)
        self.sending=false
    elseif s.phase=="reading" then
        local count,total=GetNumAuctionItems("list")
        if count==0 and total>0 then return end
        local pageBest,verified,pageOffers=nil,nil,{}
        for i=1,count do
            local listing,loaded=self:Listing(i,record.itemId)
            if not loaded then return end
            if listing then
                listing.page=s.page
                pageOffers[#pageOffers+1]=listing
                if s.verify and listing.link==s.best.link and listing.buyout==s.best.buyout and listing.count==s.best.count then
                    verified=listing
                end
                if cheaper(listing,pageBest) then pageBest=listing end
            end
        end
        if s.verify then
            if verified then self:Confirm(verified)
            else self:Stop("Cheapest listing changed. Click the item to check again.") end
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
        local batch=s.purchase and self.batch and self.batch[1]
        local need=batch and batch.remaining or record.missing or 0
        local needs=s.purchase and {need} or self:PlanNeeds(record.itemId)
        s.planner=coroutine.create(function()
            local plans={}
            for _,quantity in ipairs(needs) do plans[quantity]=self:RefillPlan(result.offers,quantity,batch and batch.ceiling,true) end
            local plan=plans[need] or self:RefillPlan(result.offers,need,batch and batch.ceiling,true)
            plans[need]=plan
            return {plan=plan,plans=plans}
        end)
        s.phase="planning"; s.since=GetTime()
    end
end
