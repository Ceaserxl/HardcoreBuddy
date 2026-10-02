-- Essential supply prices and confirmed cheapest-stack buyouts inside the AH.
local _,A=...
local E={offset=0,results={}}; A.AuctionEssentials=E
local Skin=A.Skin
local ordinaryVendors={}
for _,item in ipairs(A.Data.Items.items) do
    if item.vendorFood or item.family=="drink" then ordinaryVendors[item.itemId]=true end
end
function E:VendorItem(item)
    if ordinaryVendors[item.itemId] or item.vendorFood or item.family=="drink" then return true end
    local ammo=A.Ammunition.items[item.itemId]
    if ammo and not ammo.ingredients then return true end
    return A.VendorServices:UnlimitedSource("item:"..item.itemId)~=nil
end
function E:Items(context)
    local out={}
    for _,record in ipairs(A.Supplies.Build(context,{filter="Essentials"})) do
        if record.tracking and record.item.binding~=true and not self:VendorItem(record.item) then out[#out+1]=record end
    end
    table.sort(out,function(a,b)
        local am,bm=a.missing or 0,b.missing or 0
        if (am>0)~=(bm>0) then return am>0 end
        return a.name<b.name
    end)
    return out
end
local function label(parent,text,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    f:SetPoint("TOPLEFT",x,y); f:SetSize(width,22); f:SetJustifyH("LEFT"); f:SetText(text)
    return f
end
function E:Search(record)
    if record and not self.scan then self:Start(record) end
end
function E:Refresh()
    if not self.panel then return end
    -- Share the exact Upgrades content bounds, including native AH resizing.
    local width,height=AuctionFrame:GetWidth()-18,AuctionFrame:GetHeight()-47
    self.panel:SetSize(width,height)
    self.items=self:Items(A:GetContext())
    local shown=math.max(1,math.min(#self.rows,math.floor((height-110)/38)))
    self.offset=math.max(0,math.min(self.offset,math.max(0,#self.items-shown)))
    self.scroll:SetMinMaxValues(0,math.max(0,#self.items-shown)); self.scroll:SetValue(self.offset)
    self.scroll:SetHeight(shown*38); self.scroll:SetShown(#self.items>shown)
    local positions={40,width-430,width-360,width-300,width-240,width-170}
    local widths={width-478,64,54,54,64,140}
    for i,header in ipairs(self.headers) do
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",14+positions[i],-60); header:SetWidth(widths[i])
    end
    self.start.caption:SetText(self.scan and "Stop scan" or self.complete and "Scan Complete" or "Scan Essentials")
    self.start.caption:SetTextColor(unpack(self.scan and Skin.colors.gold or Skin.colors.white))
    for i,row in ipairs(self.rows) do
        local record=i<=shown and self.items[i+self.offset]
        row:SetShown(record~=nil); row.record=record
        if record then
            row:SetWidth(width-28)
            local result=self.results[record.itemId]
            local price=result and (GetCoinTextureString and GetCoinTextureString(result.buyout) or tostring(result.buyout).."c")
                or result==false and "None listed" or "Not scanned"
            local values={record.name,record.count==nil and "?" or tostring(record.count),tostring(record.target),
                record.missing==nil and "?" or tostring(record.missing),result and tostring(result.count) or "?",price}
            for column,cell in ipairs(row.cells) do
                cell:ClearAllPoints(); cell:SetPoint("LEFT",row,"LEFT",positions[column],0)
                cell:SetWidth(widths[column]); cell:SetText(values[column])
            end
            local icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(record.itemId)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    self.notice:SetWidth(width-28)
    self.notice:SetText(self.message or (#self.items==0 and "No non-vendor Essentials configured. Set item priority in Supplies." or "Scan prices, then click an item to buy the cheapest stack per item."))
    if MoneyFrame_Update then MoneyFrame_Update("HardcoreBuddyEssentialsMoneyFrame",GetMoney()) end
end
function E:Attach()
    if self.panel or not A.AuctionUpgrades.panel or not AuctionFrameTab_OnClick then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local index=(AuctionFrame.numTabs or 3)+1
    while _G["AuctionFrameTab"..index] do index=index+1 end
    local tab=CreateFrame("Button","AuctionFrameTab"..index,AuctionFrame,"AuctionTabTemplate")
    self.tab=tab; tab:SetID(index); tab:SetText("Essentials")
    tab:SetPoint("LEFT",_G["AuctionFrameTab"..(index-1)],"RIGHT",-15,0)
    PanelTemplates_SetNumTabs(AuctionFrame,index); PanelTemplates_EnableTab(AuctionFrame,index)
    PanelTemplates_TabResize(tab,0,nil,36)
    tab:SetScript("OnClick",function(self) AuctionFrameTab_OnClick(self) end)
    local panel=CreateFrame("Frame",nil,AuctionFrame,"BackdropTemplate"); self.panel=panel
    panel:SetPoint("TOPLEFT",AuctionFrame,"TOPLEFT",14,-34)
    panel:SetFrameLevel(AuctionFrame:GetFrameLevel()+10); panel:EnableMouse(true)
    Skin.Paint(panel,"card"); panel:SetBackdropColor(0.025,0.031,0.037,1)
    Skin.TextStyle(label(panel,"HardcoreBuddy  /  Essentials",16,-4,450),"page")
    self.start=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.start:SetSize(156,24)
    self.start:SetPoint("TOPRIGHT",-14,-8); self.start.caption=label(self.start,"Scan Essentials",4,0,148)
    self.start.label=self.start.caption; self.start.caption:SetJustifyH("CENTER")
    Skin.Button(self.start,"category")
    self.start:SetScript("OnClick",function() if E.scan then E:Stop("Scan stopped. Results may be incomplete.") else E:Start() end end)
    self.notice=label(panel,"",16,-31,560); Skin.TextStyle(self.notice,"subtitle")
    self.headers={}
    for i,title in ipairs({"ITEM","OWNED","TARGET","NEED","STACK","BUYOUT"}) do self.headers[i]=label(panel,title,0,-60,80) end
    self.rows={}
    for i=1,20 do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.rows[i]=row
        row:SetPoint("TOPLEFT",14,-82-(i-1)*38); row:SetHeight(36)
        Skin.Paint(row,"row"); Skin.Hover(row,true)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",6,0)
        row.cells={}; for column=1,6 do row.cells[column]=label(row,"",0,0,80) end
        row:SetScript("OnClick",function(self) E:Search(self.record) end)
        row:SetScript("OnEnter",function(self)
            if self.record then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..self.record.itemId); GameTooltip:AddLine("Click to check and buy the cheapest stack per item",1,0.8,0.4); GameTooltip:Show() end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    self.scroll=CreateFrame("Slider",nil,panel,"BackdropTemplate")
    self.scroll:SetOrientation("VERTICAL"); self.scroll:SetSize(8,200); self.scroll:SetPoint("TOPRIGHT",0,-82)
    self.scroll:SetThumbTexture("Interface\\Buttons\\WHITE8x8"); self.scroll:GetThumbTexture():SetSize(6,28)
    self.scroll:SetValueStep(1)
    self.scroll:SetScript("OnValueChanged",function(_,value)
        local offset=math.floor(value+0.5); if offset~=E.offset then E.offset=offset; E:Refresh() end
    end)
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel",function(_,delta) E.offset=E.offset-delta; E:Refresh() end)
    self.money=CreateFrame("Frame","HardcoreBuddyEssentialsMoneyFrame",panel,"SmallMoneyFrameTemplate")
    self.money:SetPoint("BOTTOMLEFT",14,8)
    panel:Hide()
    panel:SetScript("OnHide",function() E:Stop(); GameTooltip:Hide() end)
    hooksecurefunc("QueryAuctionItems",function()
        if not E.sending and (E.scan or E.confirmation) then E:Stop("Another search started. Scan cancelled.") end
    end)
    hooksecurefunc("AuctionFrameTab_OnClick",function(selected)
        panel:SetShown(selected==tab)
        if selected==tab then
            AuctionFrame.type="list"
            if SetAuctionsTabShowing then SetAuctionsTabShowing(false) end
            PanelTemplates_SetTab(AuctionFrame,index); E:Refresh()
        end
    end)
end
E.events=CreateFrame("Frame")
for _,event in ipairs({"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","BAG_UPDATE_DELAYED","PLAYER_MONEY","AUCTION_ITEM_LIST_UPDATE"}) do E.events:RegisterEvent(event) end
E.events:SetScript("OnEvent",function(_,event)
    if event=="AUCTION_HOUSE_SHOW" then E.open=true; E.pending=true
    elseif event=="AUCTION_HOUSE_CLOSED" then E.open=false; E.pending=nil; if E.panel then E.panel:Hide() end
    elseif event=="AUCTION_ITEM_LIST_UPDATE" then
        if E.confirmation then E:Stop("Listings changed. Click the item to check again.")
        elseif E.scan and E.scan.phase=="waiting" then E.scan.phase="reading" end
    elseif E.panel and E.panel:IsShown() then E:Refresh() end
end)
E.events:SetScript("OnUpdate",function()
    if E.pending then E:Attach(); if E.panel then E.pending=nil end end
    if E.scan then E:Tick() end
end)
