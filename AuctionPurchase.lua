-- Resolve a saved recommendation against fresh listings before native-style confirmation.
local _,A=...
local P={}; A.AuctionPurchase=P
local popup="HARDCOREBUDDY_BUYOUT"
local function identity(link)
    return type(link)=="string" and link:match("item:([%d:%-]+)")
end
function P:Cancel()
    self.request=nil; self.confirmation=nil
    if StaticPopup_Hide then StaticPopup_Hide(popup) end
end
function P:Message(text)
    A.AuctionUpgrades.message=text; A.AuctionUpgrades:Refresh()
end
function P:Find(row)
    local U=A.AuctionUpgrades
    if not row or row.owned then return end
    if not A.GearAdvisor:IsEnabled() or not U.open or U.scan or U.stale then self:Message("Stop scanning or refresh stale results before buying."); return end
    if not row.buyout or row.buyout<=0 then self:Message("This listing has no buyout."); return end
    self:Cancel()
    self.request={row=row,page=0,phase="query",since=GetTime()}
    self:Message("Checking live auctions for "..row.name.."...")
end
function P:Matches(index,row)
    local name,_,count,_,_,_,_,_,_,buyout,_,_,_,owner=GetAuctionItemInfo("list",index)
    return name and identity(GetAuctionItemLink("list",index))==identity(row.link)
        and count==row.count and buyout==row.buyout and buyout>0
        and (not UnitName or owner~=UnitName("player"))
end
function P:Confirm(index,row)
    if not StaticPopupDialogs or not StaticPopupDialogs.BUYOUT_AUCTION or not StaticPopup_Show then
        self:Message("Auction confirmation is unavailable. Try reopening the auction house."); return
    end
    if not StaticPopupDialogs[popup] then
        local dialog={}; for k,v in pairs(StaticPopupDialogs.BUYOUT_AUCTION) do dialog[k]=v end
        dialog.OnShow=function(frame,data) MoneyFrame_Update(frame.MoneyFrame,data.row.buyout) end
        dialog.OnCancel=function() P.confirmation=nil end
        dialog.OnAccept=function(_,data)
            local U=A.AuctionUpgrades
            if P.confirmation~=data or not A.GearAdvisor:IsEnabled() or not U.open or not U.panel:IsShown() or U.scan or U.stale
                or not P:Matches(data.index,data.row) then
                P:Cancel(); P:Message("Listing changed. Click the item to check again."); return
            end
            if GetMoney()<data.row.buyout then P:Cancel(); P:Message("Not enough money for this buyout."); return end
            P.confirmation=nil
            PlaceAuctionBid("list",data.index,data.row.buyout)
            P:Message("Buyout submitted. Rescan to refresh available listings.")
        end
        StaticPopupDialogs[popup]=dialog
    end
    if GetMoney()<row.buyout then self:Message("Not enough money for this buyout."); return end
    self.confirmation={index=index,row=row}
    StaticPopup_Show(popup,nil,nil,self.confirmation)
    self:Message("Confirm or cancel the buyout.")
end
function P:ListUpdated()
    if self.confirmation then self:Cancel(); self:Message("Auction listings changed. Click the item to check again.") end
    if self.request and self.request.phase=="waiting" then self.request.phase="reading" end
end
function P:Tick()
    local r=self.request; if not r then return end
    local U=A.AuctionUpgrades
    if not U.open or not U.panel:IsShown() or U.scan or U.stale then self:Cancel(); return end
    if GetTime()-r.since>20 then self:Cancel(); self:Message("Auction lookup timed out. Click the item to retry."); return end
    if r.phase=="query" then
        if not CanSendAuctionQuery("list") then return end
        r.phase="waiting"; r.since=GetTime(); self.sending=true
        QueryAuctionItems(r.row.name,nil,nil,r.page,false,nil,false,true)
        self.sending=false
    elseif r.phase=="reading" then
        local batch,total=GetNumAuctionItems("list")
        for index=1,batch do
            if not GetAuctionItemLink("list",index) then return end
            if self:Matches(index,r.row) then self.request=nil; self:Confirm(index,r.row); return end
        end
        if batch>0 and (r.page+1)*50<total then r.page=r.page+1; r.phase="query"; r.since=GetTime()
        else self:Cancel(); self:Message("That item/price is no longer available. Rescan for current listings.") end
    end
end
