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
        if record.tracking and record.refillNeeded and record.item.binding~=true and not self:VendorItem(record.item) then
            local r={}; for k,v in pairs(record) do r[k]=v end
            local bank=A.characterDB and A.characterDB.auctionBank
            r.bagCount=record.count; r.bankCount=bank and bank.counts[record.itemId] or 0
            r.mailCount=self:MailCount(record.itemId)
            r.count=r.bagCount and (r.bagCount+r.bankCount+r.mailCount)
            r.missing=r.count and math.max(0,r.target-r.count)
            if r.missing and r.missing>0 then out[#out+1]=r end
        end
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
function E:Refresh()
    if not self.panel then return end
    -- Share the exact Upgrades content bounds, including native AH resizing.
    local width,height=AuctionFrame:GetWidth()-18,AuctionFrame:GetHeight()-47
    self.panel:SetSize(width,height)
    self.title:SetWidth(math.max(160,width-320))
    self.items=self:Items(A:GetContext())
    local shown=math.max(1,math.min(#self.rows,math.floor((height-108)/38)))
    self.offset=math.max(0,math.min(self.offset,math.max(0,#self.items-shown)))
    self.scroll:SetMinMaxValues(0,math.max(0,#self.items-shown)); self.scroll:SetValue(self.offset)
    self.scroll:SetHeight(shown*38); self.scroll:SetShown(#self.items>shown)
    local positions={40,width-448,width-390,width-332,width-280,width-218,width-94}
    local widths={width-500,54,54,48,58,116,64}
    for i,header in ipairs(self.headers) do
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",14+positions[i],-50); header:SetWidth(widths[i])
    end
    self.start.caption:SetText(self.batch and "Buying..." or self.scan and "Stop scan" or self.complete and "Scan Complete" or "Scan Essentials")
    self.start.caption:SetTextColor(unpack(self.scan and Skin.colors.gold or Skin.colors.white))
    self.start:SetEnabled(not self.batch and not self.confirmation and not self.awaitingBuy and not self.purchaseReceipt)
    self.preferCraft:SetChecked(self:PreferCraft())
    self.preferCraft:SetEnabled(not self:Busy())
    self.preferCraft.label:SetTextColor(unpack(self:Busy() and Skin.colors.muted or Skin.colors.white))
    for i,row in ipairs(self.rows) do
        local record=i<=shown and self.items[i+self.offset]
        row:SetShown(record~=nil); row.record=record
        if record then
            row:SetWidth(width-28)
            local plan=self:RowPlan(record)
            row.buy:SetShown(not record.crafting)
            row.buy:SetEnabled(not self:Busy() and plan~=nil and plan.units>0)
            row.buy:ClearAllPoints(); row.buy:SetPoint("LEFT",row,"LEFT",positions[7],0)
            local result=self.results[record.itemId]
            local function cash(n) return n and (GetCoinTextureString and GetCoinTextureString(n) or n.."c") or "?" end
            local price=plan and (plan.units>0 and cash(plan.cost) or "None listed") or result and "Update needed" or "Not scanned"
            if record.craftParent and record.missing==0 then
                price=record.bagUsed>0 and ("In Bags ("..record.bagUsed..")") or ""
                if record.bankUsed>0 then price=price..(price~="" and " / " or "").."In Bank ("..record.bankUsed..")" end
                if record.mailUsed>0 then price=price..(price~="" and " / " or "").."In Mail" end
            elseif record.crafting then
                local craft=self:CraftCost(record)
                price="Craft: "..cash(craft)
            end
            local values={record.name..(record.craftable and " |cff62d79b(Craftable)|r" or ""),record.count==nil and "?" or tostring(record.count),tostring(record.target),
                record.missing==nil and "?" or tostring(record.missing),not record.crafting and plan and plan.units>0 and tostring(plan.units) or "—",price}
            for column,cell in ipairs(row.cells) do
                local indent=column==1 and record.craftParent and 14 or 0
                cell:ClearAllPoints(); cell:SetPoint("LEFT",row,"LEFT",positions[column]+indent,0)
                cell:SetWidth(widths[column]-indent); cell:SetHeight(30); cell:SetText(values[column])
            end
            row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT",record.craftParent and 20 or 6,0)
            local icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(record.itemId)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    local _,inMail=self:MailStock()
    self.mailStatus:SetShown(inMail>0); self.mailStatus.label:SetText("Items in Mail")
    self.notice:SetWidth(width-28-(inMail>0 and 166 or 0))
    self.notice:SetText(self.message or (#self.items==0 and "No Essentials have reached their refill amount." or "Scan prices, then Buy beside an item to refill it."))
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
    self.title=label(panel,"HardcoreBuddy  /  Essentials",16,-4,450)
    Skin.TextStyle(self.title,"page"); self.title:SetHeight(26); self.title:SetWordWrap(false)
    self.start=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.start:SetSize(156,24)
    self.start:SetPoint("TOPRIGHT",-14,-8); self.start.caption=label(self.start,"Scan Essentials",4,0,148)
    self.start.label=self.start.caption; self.start.caption:SetJustifyH("CENTER")
    Skin.Button(self.start,"category")
    self.start:SetScript("OnClick",function() if E.scan then E:Stop("Scan stopped. Results may be incomplete.") else E:Start() end end)
    self.preferCraft=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate"); self.preferCraft:SetSize(24,24)
    self.preferCraft:SetPoint("RIGHT",self.start,"LEFT",-100,0)
    self.preferCraft.label=label(self.preferCraft,"Craft > Buy",0,0,94)
    self.preferCraft.label:ClearAllPoints(); self.preferCraft.label:SetPoint("LEFT",self.preferCraft,"RIGHT",0,0)
    self.preferCraft:SetScript("OnClick",function(button) E:SetPreferCraft(button:GetChecked()) end)
    self.notice=label(panel,"",16,-31,560); Skin.TextStyle(self.notice,"subtitle")
    self.notice:SetHeight(18); self.notice:SetWordWrap(false)
    self.mailStatus=CreateFrame("Frame",nil,panel); self.mailStatus:SetSize(156,22)
    self.mailStatus:SetPoint("TOPRIGHT",-14,-31); self.mailStatus:EnableMouse(true)
    self.mailStatus.label=label(self.mailStatus,"",0,0,156); self.mailStatus.label:SetJustifyH("RIGHT")
    self.mailStatus:SetScript("OnEnter",function(frame)
        GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText("Essentials in Mail")
        for _,r in ipairs(E:MailStock()) do GameTooltip:AddLine(r.name,1,1,1) end
        GameTooltip:AddLine("Collect these items from your mailbox. They already count toward AH refill targets.",1,0.8,0.4,true); GameTooltip:Show()
    end)
    self.mailStatus:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.headers={}
    for i,title in ipairs({"ITEM","OWNED","TARGET","NEED","QTY","COST","BUY"}) do self.headers[i]=label(panel,title,0,-50,80) end
    self.rows={}
    for i=1,20 do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.rows[i]=row
        row:SetPoint("TOPLEFT",14,-72-(i-1)*38); row:SetHeight(36)
        Skin.Paint(row,"row"); Skin.Hover(row,true)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",6,0)
        row.cells={}
        for column=1,6 do
            row.cells[column]=label(row,"",0,0,80); row.cells[column]:SetJustifyV("MIDDLE")
        end
        row.cells[6]:SetFont(STANDARD_TEXT_FONT,10,"")
        row.buy=CreateFrame("Button",nil,row,"BackdropTemplate"); row.buy:SetSize(64,24)
        row.buy.label=label(row.buy,"Buy",0,0,64); row.buy.label:SetJustifyH("CENTER")
        Skin.Button(row.buy,"category")
        row.buy:SetScript("OnClick",function() E:BuyRow(row.record) end)
        row:SetScript("OnEnter",function(self)
                if self.record then
                    local r=self.record
                    GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("item:"..r.itemId)
                    if (r.bankCount or 0)>0 then GameTooltip:AddLine("In Bank ("..r.bankCount..")",1,0.8,0.4) end
                    if (r.mailCount or 0)>0 then GameTooltip:AddLine("In Mail",1,0.8,0.4) end
                    for _,child in ipairs(r.children or {}) do
                        if child.missing==0 then
                            local locations={}
                            if child.bagUsed>0 then locations[#locations+1]="Bags "..child.bagUsed end
                            if child.bankUsed>0 then locations[#locations+1]="Bank "..child.bankUsed end
                            if child.mailUsed>0 then locations[#locations+1]="Mail" end
                            GameTooltip:AddLine(child.name..": "..table.concat(locations,", "),0.4,0.85,0.6,true)
                        end
                    end
                    local plan=E:RowPlan(r)
                    if plan and not r.crafting and plan.units>0 then
                        GameTooltip:AddLine("Refill: "..plan.units.." items in "..#plan.offers.." auction stacks.",1,0.8,0.4,true)
                        if plan.units<r.missing then GameTooltip:AddLine("Only a partial refill is available at reasonable prices.",1,0.8,0.4,true) end
                    end
                    GameTooltip:Show()
                end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    self.scroll=CreateFrame("Slider",nil,panel,"BackdropTemplate")
    self.scroll:SetOrientation("VERTICAL"); self.scroll:SetSize(8,200); self.scroll:SetPoint("TOPRIGHT",0,-72)
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
        E.loadedPage=nil
        if not E.sending and (E.scan or E.confirmation or E.awaitingBuy) then E:Stop("Another search started. Essentials action cancelled.") end
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
for _,event in ipairs({"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","BAG_UPDATE_DELAYED","PLAYER_MONEY","AUCTION_ITEM_LIST_UPDATE","CHAT_MSG_SYSTEM","UI_ERROR_MESSAGE","GET_ITEM_INFO_RECEIVED","SPELLS_CHANGED"}) do E.events:RegisterEvent(event) end
E.events:SetScript("OnEvent",function(_,event,...)
    if event=="AUCTION_HOUSE_SHOW" then E.open=true; E.pending=true
    elseif event=="AUCTION_HOUSE_CLOSED" then E.open=false; E.pending=nil; if E.panel then E.panel:Hide() end
    elseif event=="CHAT_MSG_SYSTEM" then
        local message=...
        if ERR_AUCTION_BID_PLACED and message==ERR_AUCTION_BID_PLACED then E:PurchaseSucceeded() end
    elseif event=="UI_ERROR_MESSAGE" then
        local code,message=...
        if E.awaitingBuy or E.purchaseReceipt then
            E.purchaseReceipt=nil
            if ERR_AUCTION_BID_OWN and (message==ERR_AUCTION_BID_OWN or code==ERR_AUCTION_BID_OWN) then E:OwnAuctionRejected()
            else E:Stop("Purchase failed. Check the auction error before retrying.") end
        end
    elseif event=="AUCTION_ITEM_LIST_UPDATE" then
        E.loadedPage=nil
        if E.awaitingBuy then E.awaitingBuy.listUpdated=GetTime()
        elseif E.scan and E.scan.phase=="settling" then E.scan.settle.listUpdated=GetTime()
        elseif E.confirmation then E:Stop("Listings changed. Click the item to check again.")
        elseif E.scan and E.scan.phase=="waiting" then E.scan.phase="reading" end
    elseif E.panel and E.panel:IsShown() then E:Refresh() end
end)
E.events:SetScript("OnUpdate",function()
    if E.purchaseReceipt and GetTime()-E.purchaseReceipt.since>20 then E.purchaseReceipt=nil end
    if E.pending then E:Attach(); if E.panel then E.pending=nil end end
    if E.scan or E.awaitingBuy then E:Tick() end
end)
