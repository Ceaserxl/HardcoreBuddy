local _,A=...
local E=A.AuctionEssentials
E.selected={}
function E:Toggle(record)
    if not record or self.scan or self.batch or self.confirmation or self.awaitingBuy then return end
    local id=record.itemId
    self.selected[id]=not self.selected[id] or nil
    self:Refresh()
end
function E:Estimate()
    local cost,units,need,unknown,queue=0,0,0,false,{}
    for _,record in ipairs(self.items or {}) do
        if self.selected[record.itemId] and (record.missing or 0)>0 then
            local result=self.results[record.itemId]
            need=need+record.missing
            if result==nil then unknown=true
            elseif result then
                local plan=result.plan
                if not plan or plan.need~=record.missing then unknown=true
                else
                    cost=cost+plan.cost; units=units+plan.units
                    if plan.units>0 then queue[#queue+1]={record=record,remaining=math.min(record.missing,plan.units),ceiling=plan.ceiling} end
                end
            end
        end
    end
    return cost,units,need,unknown,queue
end
function E:BuySelected()
    if self.scan or self.batch or self.awaitingBuy or self.confirmation or not self.open then return end
    local _,_,_,unknown,queue=self:Estimate()
    if unknown or #queue==0 then return end
    self.batch=queue
    self:Start(queue[1].record,true)
end
function E:PurchaseSucceeded()
    local waiting=self.awaitingBuy; if not waiting then return end
    self.awaitingBuy=nil
    if not self.batch then self.message="Buyout confirmed. Your items will arrive by mail."; self:Refresh(); return end
    local current=self.batch[1]
    current.remaining=current.remaining-waiting.listing.count
    if current.remaining<=0 then
        self.selected[current.record.itemId]=nil
        table.remove(self.batch,1)
    end
    if #self.batch>0 then self:Start(self.batch[1].record,true)
    else self:Stop("Selected refill purchases complete. Collect your items from the mailbox.") end
end
