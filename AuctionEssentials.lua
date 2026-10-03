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
function E:ShowAllEssentials()
    return A.characterDB and A.characterDB.auctionEssentialsShowAll==true or false
end
function E:SetShowAllEssentials(enabled)
    if self:Busy() or not A.characterDB then self:Refresh(); return end
    A.characterDB.auctionEssentialsShowAll=enabled==true
    self.offset=0
    self:Replan(self:ShowAllEssentials() and "Showing all AH Essentials." or "Showing Essentials at their refill amount.")
end
function E:Items(context)
    local out={}
    local showAll=self:ShowAllEssentials()
    for _,record in ipairs(A.Supplies.Build(context,{filter="Essentials"})) do
        if record.usableNow~=false and record.tracking and (showAll or record.refillNeeded) and record.item.binding~=true and not self:VendorItem(record.item) then
            local r={}; for k,v in pairs(record) do r[k]=v end
            local bank=A.characterDB and A.characterDB.auctionBank
            r.bagCount=record.count; r.bankCount=bank and bank.counts[record.itemId] or 0
            r.mailCount=self:MailCount(record.itemId)
            r.count=r.bagCount and (r.bagCount+r.bankCount+r.mailCount)
            r.missing=r.count and math.max(0,r.target-r.count)
            if showAll or r.missing and r.missing>0 then out[#out+1]=r end
        end
    end
    table.sort(out,function(a,b)
        local am,bm=a.missing or 0,b.missing or 0
        if (am>0)~=(bm>0) then return am>0 end
        return a.name<b.name
    end)
    return out
end
local function label(parent,text,x,y,width,color,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size or 12,""); f:SetTextColor(unpack(color or Skin.colors.white))
    f:SetPoint("TOPLEFT",x,y); f:SetSize(width,20); f:SetJustifyH("LEFT"); f:SetJustifyV("MIDDLE")
    f:SetWordWrap(false); f:SetText(text); return f
end
local function button(parent,text,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetSize(width,24)
    b.caption=label(b,text,6,-2,width-12,Skin.colors.white,11)
    b.caption:SetJustifyH("CENTER"); b.label=b.caption
    Skin.Button(b,"utility"); b:SetScript("OnClick",callback); return b
end
local function checkbox(parent,text,callback)
    local b=CreateFrame("CheckButton",nil,parent,"BackdropTemplate"); b:SetSize(18,18)
    Skin.Paint(b,"edit")
    b.mark=label(b,"",0,0,18,Skin.colors.gold,11); b.mark:SetHeight(18); b.mark:SetJustifyH("CENTER")
    b.label=label(b,text,24,0,180,Skin.colors.muted,11); b.label:SetHeight(18)
    b.label:SetWidth(math.ceil(b.label:GetStringWidth())+2)
    b:SetScript("OnClick",function(self) callback(self:GetChecked()) end)
    return b
end
function E:Refresh()
    if not self.panel then return end
    -- Share the exact Upgrades content bounds, including native AH resizing.
    local width,height=AuctionFrame:GetWidth()-18,AuctionFrame:GetHeight()-47
    self.panel:SetSize(width,height)
    local controlsWidth=self.start:GetWidth()+self.showAll:GetWidth()+self.showAll.label:GetWidth()
        +self.preferCraft:GetWidth()+self.preferCraft.label:GetWidth()+36
    self.title:SetWidth(width-controlsWidth-42)
    self.items=self:Items(A:GetContext())
    local shown=math.max(1,math.min(#self.rows,math.floor((height-108)/38)))
    self.offset=math.max(0,math.min(self.offset,math.max(0,#self.items-shown)))
    self.scroll:SetMinMaxValues(0,math.max(0,#self.items-shown)); self.scroll:SetValue(self.offset)
    self.scroll:SetHeight(shown*38-2); self.scroll:SetShown(#self.items>shown)
    local rowWidth=width-28
    local positions={48,rowWidth-422,rowWidth-364,rowWidth-306,rowWidth-248,rowWidth-206,rowWidth-90}
    local widths={rowWidth-482,54,54,54,38,110,84}
    for i,header in ipairs(self.headers) do
        header:ClearAllPoints(); header:SetPoint("TOPLEFT",14+positions[i],-59); header:SetWidth(widths[i])
    end
    self.start.caption:SetText(self.batch and "Buying..." or self.scan and "Stop scan" or self.complete and "Scan Complete" or "Scan Essentials")
    self.start:SetEnabled(not self.batch and not self.confirmation and not self.awaitingBuy and not self.purchaseReceipt)
    Skin.ButtonState(self.start,false,nil,false)
    if self.scan then self.start:SetBackdropColor(0.22,0.17,0.035,1) end
    self.start.caption:SetTextColor(unpack(not self.start:IsEnabled() and Skin.colors.muted or self.scan and Skin.colors.gold or Skin.colors.white))
    self.preferCraft:SetChecked(self:PreferCraft())
    self.showAll:SetChecked(self:ShowAllEssentials())
    for _,control in ipairs({self.showAll,self.preferCraft}) do
        control.mark:SetText(control:GetChecked() and "X" or "")
        control:SetEnabled(not self:Busy()); control:SetAlpha(self:Busy() and 0.5 or 1)
    end
    local progress=self.scan and self.scan.queue and (self.scan.item-1)/math.max(1,#self.scan.queue) or self.complete and 1 or 0
    self.progressTrack:SetWidth(rowWidth)
    self.progressFill:SetWidth(math.max(1,rowWidth*progress))
    self.progressFill:SetVertexColor(unpack(self.scan and Skin.colors.gold or Skin.colors.green))
    self.progressFill:SetShown(progress>0 or self.scan~=nil)
    for i,row in ipairs(self.rows) do
        local record=i<=shown and self.items[i+self.offset]
        row:SetShown(record~=nil); row.record=record
        if record then
            row:SetWidth(rowWidth)
            local plan=self:RowPlan(record)
            row.buy:SetShown(not record.crafting)
            Skin.ControlEnabled(row.buy,not self:Busy() and (record.missing or 0)>0 and plan~=nil and plan.units>0)
            row.buy:ClearAllPoints(); row.buy:SetPoint("LEFT",row,"LEFT",positions[7],0)
            local result=self.results[record.itemId]
            local function cash(n) return n and (GetCoinTextureString and GetCoinTextureString(n) or n.."c") or "?" end
            local price=plan and (plan.units>0 and cash(plan.cost) or "None listed") or result and "Update needed" or "Not scanned"
            if not record.craftParent and record.missing==0 then
                price="Stocked"
            elseif record.readyToCraft then
                price="Ready to craft"
            elseif record.missing==nil then
                price="Stock unknown"
            elseif record.craftParent and record.missing==0 then
                price=record.bagUsed>0 and ("In Bags ("..record.bagUsed..")") or ""
                if record.bankUsed>0 then price=price..(price~="" and " / " or "").."In Bank ("..record.bankUsed..")" end
                if record.mailUsed>0 then price=price..(price~="" and " / " or "").."In Mail" end
            elseif record.crafting then
                local craft=self:CraftCost(record)
                price="Craft: "..cash(craft)
            end
            if not record.crafting and plan and plan.priceLimited and plan.units==0 then price="Price limit" end
            local values={record.name..(record.craftable and " |cff62d79b(Craftable)|r" or ""),record.count==nil and "?" or tostring(record.count),tostring(record.target),
                record.missing==nil and "?" or tostring(record.missing),not record.crafting and plan and plan.units>0 and tostring(plan.units) or "—",price}
            for column,cell in ipairs(row.cells) do
                local indent=column==1 and record.craftParent and 14 or 0
                cell:ClearAllPoints(); cell:SetPoint("LEFT",row,"LEFT",positions[column]+indent,0)
                cell:SetWidth(widths[column]-indent); cell:SetHeight(30); cell:SetText(values[column])
            end
            local stocked=record.missing==0 or record.readyToCraft
            row.accent:SetVertexColor(unpack(stocked and Skin.colors.green or record.missing and Skin.colors.gold or Skin.colors.muted))
            row.cells[6]:SetTextColor(unpack(stocked and Skin.colors.green or Skin.colors.white))
            row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT",record.craftParent and 23 or 9,0)
            local icon=C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(record.itemId)
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
    local _,inMail=self:MailStock()
    self.mailStatus:SetShown(inMail>0); self.mailStatus.label:SetText("Items in Mail")
    self.status:SetWidth(width-360)
    self.notice:SetWidth(width-360)
    self.status.message=self.message or (#self.items==0 and (self:ShowAllEssentials() and "No AH Essentials to show." or "No Essentials have reached their refill amount.") or "Scan prices, then Buy beside an item to refill it.")
    local short=self.status.message
    self.notice:SetText(short)
    while self.notice:GetStringWidth()>self.notice:GetWidth() do
        short=short:match("^(.*)%s+%S+$")
        if not short then self.notice:SetText("..."); break end
        self.notice:SetText(short.."...")
    end
    self.notice:SetTextColor(unpack(self.scan and Skin.colors.gold or self.complete and Skin.colors.green or Skin.colors.muted))
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
    self.start=button(panel,"Scan Essentials",156,function() if E.scan then E:Stop("Scan stopped. Results may be incomplete.") else E:Start() end end)
    self.start:SetPoint("TOPRIGHT",-14,-8)
    self.showAll=checkbox(panel,"Show All Essentials",function(value) E:SetShowAllEssentials(value) end)
    self.preferCraft=checkbox(panel,"Craft > Buy",function(value) E:SetPreferCraft(value) end)
    self.preferCraft:SetPoint("RIGHT",self.start,"LEFT",-self.preferCraft.label:GetWidth()-18,0)
    self.showAll:SetPoint("RIGHT",self.preferCraft,"LEFT",-self.showAll.label:GetWidth()-18,0)
    self.status=CreateFrame("Frame",nil,panel); self.status:SetPoint("TOPLEFT",346,-31); self.status:SetSize(400,18)
    self.status:EnableMouse(true)
    self.status:SetScript("OnEnter",function(frame)
        if not frame.message then return end
        GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText("AH Essentials")
        GameTooltip:AddLine(frame.message,1,1,1,true); GameTooltip:Show()
    end)
    self.status:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.notice=label(self.status,"",0,0,400,Skin.colors.muted,10)
    self.notice:SetJustifyH("RIGHT"); self.notice:SetHeight(18)
    self.progressTrack=panel:CreateTexture(nil,"ARTWORK"); self.progressTrack:SetColorTexture(0.20,0.25,0.29,1)
    self.progressTrack:SetPoint("TOPLEFT",14,-54); self.progressTrack:SetHeight(1)
    self.progressFill=panel:CreateTexture(nil,"OVERLAY"); self.progressFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.progressFill:SetPoint("TOPLEFT",14,-54); self.progressFill:SetHeight(3)
    self.mailStatus=CreateFrame("Frame",nil,panel); self.mailStatus:SetSize(156,22)
    self.mailStatus:SetPoint("BOTTOMRIGHT",-14,8); self.mailStatus:EnableMouse(true)
    self.mailStatus.label=label(self.mailStatus,"",0,0,156,Skin.colors.muted,11); self.mailStatus.label:SetJustifyH("RIGHT")
    self.mailStatus:SetScript("OnEnter",function(frame)
        GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText("Essentials in Mail")
        for _,r in ipairs(E:MailStock()) do GameTooltip:AddLine(r.name,1,1,1) end
        GameTooltip:AddLine("Collect these items from your mailbox. They already count toward AH refill targets.",1,0.8,0.4,true); GameTooltip:Show()
    end)
    self.mailStatus:SetScript("OnLeave",function() GameTooltip:Hide() end)
    self.headers={}
    for i,title in ipairs({"ITEM","OWNED","TARGET","NEED","QTY","COST","BUY"}) do self.headers[i]=label(panel,title,0,-59,80,Skin.colors.muted,9) end
    self.headers[6]:SetJustifyH("RIGHT")
    self.rows={}
    for i=1,20 do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.rows[i]=row
        row:SetPoint("TOPLEFT",14,-80-(i-1)*38); row:SetHeight(36)
        Skin.Paint(row,"row"); row:SetBackdropColor(i%2==0 and 0.055 or 0.04,i%2==0 and 0.075 or 0.055,i%2==0 and 0.09 or 0.07,1)
        row.accent=row:CreateTexture(nil,"ARTWORK"); row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.accent:SetPoint("TOPLEFT",0,-4); row.accent:SetSize(2,28)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",9,0)
        row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.cells={}
        for column=1,6 do
            row.cells[column]=label(row,"",0,0,80,Skin.colors.white,column==1 and 12 or 11)
        end
        row.cells[1]:SetWordWrap(true)
        row.cells[6]:SetJustifyH("RIGHT")
        row.buy=button(row,"Buy",76,function() E:BuyRow(row.record) end)
        Skin.Hover(row)
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
                        if plan.units<r.missing then GameTooltip:AddLine("Only a partial refill is available within your price limits.",1,0.8,0.4,true) end
                    end
                    if plan and (plan.excluded or 0)>0 then
                        GameTooltip:AddLine(plan.excluded.." listings excluded by the per-item budget or the 5x cheapest-price limit.",1,0.8,0.4,true)
                    end
                    GameTooltip:Show()
                end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    self.scroll=CreateFrame("Slider",nil,panel,"BackdropTemplate")
    self.scroll:SetOrientation("VERTICAL"); self.scroll:SetSize(8,200); self.scroll:SetPoint("TOPRIGHT",0,-80)
    Skin.Paint(self.scroll,"edit")
    self.scroll:SetThumbTexture("Interface\\Buttons\\WHITE8x8"); self.scroll:GetThumbTexture():SetSize(6,28)
    self.scroll:GetThumbTexture():SetVertexColor(0.42,0.48,0.53,1)
    self.scroll:SetValueStep(1); self.scroll:SetObeyStepOnDrag(true)
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
