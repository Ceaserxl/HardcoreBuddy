-- Buy a saved offer with native confirmation, loading only its original page if needed.
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
function P:VendorBlocked(row)
    local source=A.VendorServices and A.VendorServices:UnlimitedSource(row and row.link)
    if not source then return false end
    self:Cancel()
    local message=(row.name or "This item").." is sold by a vendor with unlimited stock: "..source..". AH purchase blocked."
    self:Message(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcd52HardcoreBuddy:|r "..message) end
    return true
end
function P:Find(row)
    local U=A.AuctionUpgrades
    if not row or row.owned then return end
    if self:VendorBlocked(row) then return end
    if not A.GearAdvisor:IsEnabled() or not U.open or not U.panel:IsShown() or U.scan or U.stale then self:Message("Stop scanning or refresh stale results before buying."); return end
    if not row.buyout or row.buyout<=0 then self:Message("This listing has no buyout."); return end
    self:Cancel()
    local index=self:LoadedListing(row)
    if index then self:Confirm(index,row); return end
    local query=row.listing and row.listing.query
    if not query then self:Message("This saved result has no listing location. Scan upgrades once to refresh it."); return end
    self.request={row=row,query=query,phase="query",since=GetTime()}
    self:Message("Loading the saved listing for "..row.name.."...")
end
function P:Matches(index,row)
    local name,_,count,_,_,_,_,_,_,buyout,_,_,_,owner=GetAuctionItemInfo("list",index)
    return name and owner and owner~="" and identity(GetAuctionItemLink("list",index))==identity(row.link)
        and count==row.count and buyout==row.buyout and buyout>0
        and (not row.listing or not row.listing.owner or owner==row.listing.owner)
        and (not UnitName or owner~=UnitName("player"))
end
function P:LoadedListing(row)
    local count,total=GetNumAuctionItems("list")
    if count==0 and total>0 then return nil,false end
    local loaded=true
    for index=1,count do
        local name,_,_,_,_,_,_,_,_,_,_,_,_,owner=GetAuctionItemInfo("list",index)
        if not name or not GetAuctionItemLink("list",index) or not owner or owner=="" then loaded=false
        elseif self:Matches(index,row) then return index,true end
    end
    return nil,loaded
end
function P:Confirm(index,row)
    if self:VendorBlocked(row) then return end
    if not StaticPopupDialogs or not StaticPopupDialogs.BUYOUT_AUCTION or not StaticPopup_Show then
        self:Message("Auction confirmation is unavailable. Try reopening the auction house."); return
    end
    if not StaticPopupDialogs[popup] then
        local dialog={}; for k,v in pairs(StaticPopupDialogs.BUYOUT_AUCTION) do dialog[k]=v end
        dialog.OnShow=function(frame,data) MoneyFrame_Update(frame.MoneyFrame,data.row.buyout) end
        dialog.OnCancel=function() P:Cancel(); P:Message("Purchase cancelled.") end
        dialog.OnAccept=function(_,data)
            if P:VendorBlocked(data.row) then return end
            local U=A.AuctionUpgrades
            if P.confirmation~=data or not A.GearAdvisor:IsEnabled() or not U.open or not U.panel:IsShown() or U.scan or U.stale
                or not P:Matches(data.index,data.row) then
                P:Cancel(); P:Message("Listing changed. Scan again for current offers."); return
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
    if self.confirmation then self:Cancel(); self:Message("Auction listings changed. Click Buy to check again.") end
    if self.request and self.request.phase=="waiting" then self.request.phase="reading" end
end
function P:Tick()
    local r=self.request; if not r then return end
    local U=A.AuctionUpgrades
    if not U.open or not U.panel:IsShown() or U.scan or U.stale then self:Cancel(); return end
    if GetTime()-r.since>(r.phase=="query" and 60 or 20) then self:Cancel(); self:Message("Auction lookup timed out. Click Buy to retry."); return end
    if r.phase=="query" then
        if not CanSendAuctionQuery("list") then return end
        r.phase="waiting"; r.since=GetTime(); self.sending=true
        local q=r.query
        QueryAuctionItems(q.name,q.minimum,q.maximum,q.page,q.usable,nil,false,q.exact,q.filters)
        self.sending=false
    elseif r.phase=="reading" then
        local index,loaded=self:LoadedListing(r.row)
        if index then self.request=nil; self:Confirm(index,r.row); return end
        if not loaded then return end
        self:Cancel(); self:Message("Saved listing is no longer available. Scan again for current offers.")
    end
end
