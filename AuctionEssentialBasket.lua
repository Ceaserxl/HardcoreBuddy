-- A row buys only its saved refill plan, one native confirmation per stack.
local _,A=...
local E=A.AuctionEssentials
function E:Busy()
    return self.scan or self.batch or self.confirmation or self.awaitingBuy or self.purchaseReceipt
end
function E:RowPlan(record)
    local result=record and self.results[record.itemId]
    return result and result.plans and result.plans[record.missing]
end
function E:BuyRow(record)
    if not record or self:Busy() or not self.open or not self.panel:IsShown() then return end
    -- Recheck stock and craft preference before using a potentially stale row.
    local current
    for _,r in ipairs(self:Items(A:GetContext())) do
        if r.itemId==record.itemId and r.craftParent==record.craftParent then current=r; break end
    end
    if not current or current.crafting then self:Refresh(); return end
    if current.missing~=record.missing then self:Replan("Stock changed. Review the updated refill before buying."); return end
    local plan=self:RowPlan(current)
    if not plan or plan.units<=0 then self.message="Scan Essentials to find a refill for this item."; self:Refresh(); return end
    local offers={}; for _,offer in ipairs(plan.offers) do offers[#offers+1]=offer end
    self.batch={record=current,offers=offers,remaining=current.missing}
    self:NextPurchase()
end
function E:NextPurchase(settle)
    local batch=self.batch; if not batch then return end
    local best=batch.offers[1]
    if not best or batch.remaining<=0 then
        local missing=batch.remaining>0
        self.batch=nil
        self:Replan(missing and "Available stacks finished. Refill is incomplete; scan again for more listings."
            or "Refill purchased. Collect your items from the mailbox.")
        return
    end
    self.message="Loading the saved listing: "..batch.record.name
    self.scan={queue={batch.record},item=1,best=best,page=best.page,verify=true,
        phase=settle and "settling" or "query",since=GetTime(),settle=settle}
    -- If the exact query page is already loaded, no query is needed at all.
    if not settle and self.loadedPage and self.loadedPage.itemId==best.itemId and self.loadedPage.page==best.page then
        self.scan.phase="reading"
        self:Tick()
    end
    self:Refresh()
end
function E:RemovePurchasedOffer(listing,ownSeller)
    local result=self.results[listing.itemId]
    if not result then return end
    for i=#result.offers,1,-1 do
        local offer=result.offers[i]
        if ownSeller and offer.owner==listing.owner or not ownSeller and offer==listing.savedOffer then
            table.remove(result.offers,i)
        end
    end
    result.plans={}; result.plan=nil
end
function E:PurchaseSucceeded()
    local waiting=self.awaitingBuy or self.purchaseReceipt; if not waiting then return end
    self.awaitingBuy=nil; self.purchaseReceipt=nil; self.loadedPage=nil
    self:RecordMailPurchase(waiting.listing)
    self:RemovePurchasedOffer(waiting.listing)
    if not self.batch then self.message="Buyout confirmed. Your items will arrive by mail."; self:Refresh(); return end
    self.batch.remaining=self.batch.remaining-waiting.listing.count
    table.remove(self.batch.offers,1)
    self:NextPurchase(waiting)
end
function E:OwnAuctionRejected()
    local waiting=self.awaitingBuy; if not waiting then return end
    self.awaitingBuy=nil; self.purchaseReceipt=nil; self.loadedPage=nil
    self.ownSellers=self.ownSellers or {}
    self.ownSellers[waiting.listing.owner]=true
    self:RemovePurchasedOffer(waiting.listing,true)
    if not self.batch then self:Stop("Your own auction was skipped. Scan again to find another seller."); return end
    -- Skip this seller's planned stacks without substituting an unreviewed listing.
    for i=#self.batch.offers,1,-1 do
        if self.batch.offers[i].owner==waiting.listing.owner then table.remove(self.batch.offers,i) end
    end
    self:NextPurchase(waiting)
end
