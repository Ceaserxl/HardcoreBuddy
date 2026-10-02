-- Confirmed Essentials buyouts count as owned while their items are in mail.
-- This cache belongs to the character; supplies/readiness still count bags only.
local _,A=...
local E=A.AuctionEssentials
local function now() return time and time() or 0 end
local function saved()
    if not A.characterDB then return end
    A.characterDB.auctionMail=A.characterDB.auctionMail or {items={}}
    return A.characterDB.auctionMail.items
end
local function quantity(entry) return (entry.inbox or 0)+(entry.pending or 0) end
function E:MailCount(itemID)
    local items=saved(); local entry=items and items[itemID]
    if entry and entry.expires and entry.expires<=now() then items[itemID]=nil; return 0 end
    return entry and quantity(entry) or 0
end
function E:MailStock()
    local rows,total={},0
    for id,entry in pairs(saved() or {}) do
        local count=self:MailCount(id)
        if count>0 then rows[#rows+1]={itemId=id,name=entry.name or ("Item "..id),count=count}; total=total+count end
    end
    table.sort(rows,function(a,b) return a.name<b.name end)
    return rows,total
end
function E:RecordMailPurchase(listing)
    local items=saved()
    if not items or not listing.itemId or not listing.count or listing.count<=0 then return end
    self:MailCount(listing.itemId) -- Discard an expired record before adding stock.
    local entry=items[listing.itemId] or {inbox=0,pending=0}; items[listing.itemId]=entry
    entry.pending=(entry.pending or 0)+listing.count
    entry.name=listing.name; entry.at=now(); entry.expires=now()+30*24*60*60
end
function E:CaptureMail()
    if not self.mailOpen or not GetInboxNumItems or not GetInboxHeaderInfo or not GetInboxItem then return end
    local loaded,total=GetInboxNumItems()
    if type(loaded)~="number" or type(total)~="number" then return end
    local counts={}; local complete=loaded==total
    for mail=1,loaded do
        local _,_,sender,_,_,cod,_,attachments=GetInboxHeaderInfo(mail)
        if not sender or cod==nil then return end -- Headers are still loading.
        if cod==0 and attachments and attachments>0 then
            local found=0
            for slot=1,(ATTACHMENTS_MAX_RECEIVE or ATTACHMENTS_MAX or 16) do
                local _,id,_,count=GetInboxItem(mail,slot)
                if id then
                    if type(count)~="number" or count<1 then return end
                    counts[id]=(counts[id] or 0)+count; found=found+1
                end
            end
            if found<attachments then return end -- Never replace stock with a partial attachment read.
        end
    end
    for id,entry in pairs(saved() or {}) do
        local visible=counts[id] or 0
        local previous=entry.inbox or 0
        -- Previously seen mail and fresh buyouts must not be counted twice.
        local arrived=math.max(0,visible-previous)
        entry.pending=math.max(0,(entry.pending or 0)-arrived)
        entry.inbox=complete and visible or math.max(previous,visible)
        -- A complete mailbox reconciles old receipts, including collection while
        -- the addon was disabled. Allow a fresh purchase time to reach the inbox.
        if complete and now()-(entry.at or 0)>120 then entry.pending=0 end
        if quantity(entry)==0 then saved()[id]=nil end
    end
end
function E:TrackMailTake(mail,attachment)
    if not self.mailOpen or not GetInboxItem then return end
    self:CaptureMail()
    local inventory=A.Inventory.Read(); if not inventory.available then return end
    local first,last=attachment or 1,attachment or (ATTACHMENTS_MAX_RECEIVE or ATTACHMENTS_MAX or 16)
    self.mailTakes=self.mailTakes or {}
    for slot=first,last do
        local _,id,_,count=GetInboxItem(mail,slot)
        local entry=id and saved() and saved()[id]
        if entry and count and count>0 then
            local take=self.mailTakes[id]
            if not take then
                take={bags=inventory.counts[id] or 0,inbox=entry.inbox or 0,pending=entry.pending or 0,
                    amount=0,at=GetTime()}; self.mailTakes[id]=take
            end
            take.amount=take.amount+count
        end
    end
end
function E:UpdateMailTakes()
    if not self.mailTakes or not next(self.mailTakes) then return end
    local inventory=A.Inventory.Read(); if not inventory.available then return end
    for id,take in pairs(self.mailTakes) do
        if GetTime()-take.at>10 then self.mailTakes[id]=nil
        else
            local gained=math.min(take.amount,math.max(0,(inventory.counts[id] or 0)-take.bags))
            local entry=saved() and saved()[id]
            if entry and gained>0 then
                -- Bounds avoid deducting twice if MAIL_INBOX_UPDATE preceded bags.
                entry.inbox=math.min(entry.inbox or 0,math.max(0,take.inbox-gained))
                entry.pending=math.min(entry.pending or 0,math.max(0,take.pending-math.max(0,gained-take.inbox)))
                if quantity(entry)==0 then saved()[id]=nil end
            end
            if gained>=take.amount then self.mailTakes[id]=nil end
        end
    end
end
local events=CreateFrame("Frame"); E.mailEvents=events
for _,event in ipairs({"MAIL_SHOW","MAIL_CLOSED","MAIL_INBOX_UPDATE","BAG_UPDATE_DELAYED","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="MAIL_SHOW" then E.mailOpen=true; E.mailTakes={}
    elseif event=="MAIL_CLOSED" then E:UpdateMailTakes(); E.mailOpen=false
    elseif event=="BAG_UPDATE_DELAYED" then E:UpdateMailTakes()
    elseif E.mailOpen then E:CaptureMail() end
    if E.panel and E.panel:IsShown() then E:Refresh() end
end)
if hooksecurefunc then
    if TakeInboxItem then hooksecurefunc("TakeInboxItem",function(mail,slot) E:TrackMailTake(mail,slot or 1) end) end
    if AutoLootMailItem then hooksecurefunc("AutoLootMailItem",function(mail) E:TrackMailTake(mail) end) end
end
