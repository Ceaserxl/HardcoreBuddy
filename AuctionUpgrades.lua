local _,A=...
local U={results={},offset=0}; A.AuctionUpgrades=U
local G,Skin=A.GearAdvisor,A.Skin
local slots={1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
local names={[1]="Head",[2]="Neck",[3]="Shoulders",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",
    [9]="Wrists",[10]="Hands",[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",
    [15]="Back",[16]="Main hand",[17]="Off hand",[18]="Ranged"}
local classes={4,2} -- Armor (including jewelry), then weapons; all usable materials.
local function now() return GetTime() end
local function profileKey(p)
    return p and table.concat({p.class,p.level,p.id or p.name,tostring(p.manual)},":")
end
local function price(row)
    if row.buyout>0 then return row.buyout,"Buyout" end
    return row.bid,"Bid"
end
local function money(value)
    local g=math.floor(value/10000); local s=math.floor(value/100)%100; local c=value%100
    return (g>0 and g.."g " or "")..(s>0 and s.."s " or "")..(c>0 and c.."c" or (g==0 and s==0 and "0c" or ""))
end
local function better(a,b)
    if a.percent~=b.percent then return (a.percent or -math.huge)>(b.percent or -math.huge) end
    if not a.percent and a.score~=b.score then return a.score>b.score end
    if (a.buyout>0)~=(b.buyout>0) then return a.buyout>0 end
    local ap,bp=price(a),price(b)
    if ap~=bp then return ap<bp end
    return a.link<b.link
end

function U:Stop(message)
    self.scan=nil
    if message then self.message=message end
    self:Refresh()
end

function U:Start()
    if self.scan then self:Stop("Scan stopped. Results are partial."); return end
    if not self.open or not self.panel or not self.panel:IsShown() then return end
    local p=G:CurrentProfile()
    if not p then self:Stop("Talent data is loading. Try again in a moment."); return end
    for _,slot in ipairs(slots) do
        local _,reason=G:Equipped(slot)
        if reason and reason~="unsupported" then self:Stop("Equipped gear is loading. Try again in a moment."); return end
    end
    self.results={}; self.slot=nil; self.offset=0; self.complete=false; self.stale=false
    self.profile=p; self.profileKey=profileKey(p)
    self.scan={class=1,page=0,phase="query",since=now(),seen=0,skipped=0,cache={}}
    self.message="Waiting for the auction house..."; self:Refresh()
end

function U:Add(item,rows,link,icon,buyout,bid,count)
    -- Keep random-suffix variants distinct, but collapse repeated auctions of
    -- the same variant. Enchants and instance IDs do not affect base scoring.
    local fields={}; for field in ((link:match("item:([%d:%-]+)") or "")..":"):gmatch("(.-):") do fields[#fields+1]=field end
    local key=tostring(item.id)..":"..(fields[7] or "0")
    for _,comparison in ipairs(rows) do
        if comparison.status=="up" then
            local list=self.results[comparison.slot] or {}; self.results[comparison.slot]=list
            local record={key=key,link=link,name=item.name,icon=icon,percent=comparison.percent,
                score=G.Score(item,self.profile,comparison.slot) or 0,label=comparison.label,
                buyout=buyout,bid=bid,count=count,auctions=1}
            local found
            for i,old in ipairs(list) do
                if old.key==key then
                    found=true; record.auctions=old.auctions+1
                    local cheaper=(buyout>0 and old.buyout==0) or ((buyout>0)==(old.buyout>0) and price(record)<price(old))
                    if cheaper then list[i]=record else old.auctions=record.auctions end
                    break
                end
            end
            if not found then list[#list+1]=record end
        end
    end
end

function U:ReadAuction(index)
    local scan=self.scan
    local name,icon,count,_,usable,_,_,minimum,increment,buyout,bid=GetAuctionItemInfo("list",index)
    if usable==false then return true end
    local link=GetAuctionItemLink("list",index)
    if not name or not link or not count or not buyout or not minimum then return false end
    local cached=scan.cache[link]
    if cached==false then return true end
    if not cached then
        local item,reason=G:Read(link)
        if reason=="unsupported" then scan.cache[link]=false; return true end
        if not item then return false end
        if not G.Allowed(item,self.profile) then scan.cache[link]=false; return true end
        local rows=G:Comparisons(item,self.profile)
        for _,row in ipairs(rows) do
            -- Structural exclusions (unique items / two-handed constraints)
            -- are final; incomplete native data is retried before skipping.
            if row.status=="unknown" and (row.text:find("loading") or row.text:find("incomplete") or row.text:find("unavailable")) then return false end
        end
        cached={item=item,rows=rows}; scan.cache[link]=cached
    end
    self:Add(cached.item,cached.rows,link,icon,buyout,(bid or 0)>0 and bid+(increment or 0) or minimum,count)
    return true
end

function U:Tick()
    if self.attachPending then self.attachPending=nil; self:Attach() end
    local scan=self.scan
    if not scan then return end
    if not self.open or not self.panel:IsShown() then self:Stop("Scan stopped. Results are partial."); return end
    if profileKey(G:CurrentProfile())~=self.profileKey then self:Invalidate(); return end
    if scan.phase=="query" then
        if now()-scan.since>30 then self:Stop("Auction house busy. Results are partial; scan again."); return end
        if not CanSendAuctionQuery("list") then return end
        scan.phase="waiting"; scan.since=now()
        self.message=string.format("Scanning %s | page %d | %d auctions checked",scan.class==1 and "armor" or "weapons",scan.page+1,scan.seen)
        self:Refresh()
        self.sending=true
        QueryAuctionItems("",nil,self.profile.level,scan.page,true,nil,false,false,{{classID=classes[scan.class]}})
        self.sending=false
    elseif scan.phase=="waiting" then
        if now()-scan.since>20 then self:Stop("Auction response timed out. Results are partial; scan again.") end
    elseif scan.phase=="reading" then
        local batch,total=GetNumAuctionItems("list")
        -- Copy/score a few auctions per frame, yielding while item data loads.
        for _=1,8 do
            if scan.index>batch then
                scan.seen=scan.seen+batch
                if batch>0 and (scan.page+1)*50<total then scan.page=scan.page+1
                else scan.class=scan.class+1; scan.page=0 end
                if scan.class>#classes then
                    self.complete=scan.skipped==0
                    local prefix=self.complete and "Scan complete" or "Partial results"
                    self:Stop(string.format("%s | %d auctions checked%s",prefix,scan.seen,
                        scan.skipped>0 and (" | "..scan.skipped.." unavailable; scan again") or ""))
                else scan.phase="query"; scan.since=now(); self:Refresh() end
                return
            end
            if self:ReadAuction(scan.index) then scan.index=scan.index+1; scan.itemSince=nil
            else
                scan.itemSince=scan.itemSince or now()
                if now()-scan.itemSince<10 then return end
                scan.skipped=scan.skipped+1; scan.index=scan.index+1; scan.itemSince=nil
            end
        end
    end
end

function U:Invalidate()
    if not self.profile then return end
    self.stale=true; self.complete=false
    self:Stop("Gear or talents changed. Scan again to refresh upgrades.")
end

function U:Find(row)
    if self.stale then self.message="Gear or talents changed. Scan again before opening an upgrade."; self:Refresh(); return end
    if self.scan or not row or not CanSendAuctionQuery("list") then
        self.message="Wait for the scan to finish, or stop it, before opening an auction."; self:Refresh(); return
    end
    if not AuctionFrameBrowse_Search then return end
    AuctionFrameTab_OnClick(AuctionFrameTab1)
    BrowseMinLevel:SetText(""); BrowseMaxLevel:SetText(""); IsUsableCheckButton:SetChecked(false)
    AuctionFrameBrowse.selectedCategoryIndex=nil; AuctionFrameBrowse.selectedSubCategoryIndex=nil
    AuctionFrameBrowse.selectedSubSubCategoryIndex=nil; AuctionFrameBrowse.qualityIndex=FILTER_ALL_INDEX or -1
    if BrowseDropdown and BrowseDropdown.GenerateMenu then BrowseDropdown:GenerateMenu() end
    if AuctionFrameFilters_Update then AuctionFrameFilters_Update() end
    BrowseName:SetText('"'..row.name..'"'); AuctionFrameBrowse.page=0
    AuctionFrameBrowse_Search()
end

local function label(parent,text,x,y,width,color,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size or 12,""); f:SetTextColor(unpack(color or Skin.colors.white))
    f:SetPoint("TOPLEFT",x,y); f:SetSize(width,20); f:SetJustifyH("LEFT"); f:SetJustifyV("MIDDLE")
    f:SetWordWrap(false); f:SetText(text); return f
end
local function button(parent,text,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetSize(width,24)
    b:SetText(text); b:SetScript("OnClick",callback); return b
end

function U:Refresh()
    if not self.panel then return end
    local list={}
    if self.slot then
        for _,row in ipairs(self.results[self.slot] or {}) do list[#list+1]=row end
        table.sort(list,better)
    else
        for _,slot in ipairs(slots) do
            local candidates=self.results[slot] or {}; table.sort(candidates,better)
            list[#list+1]={slot=slot,best=candidates[1],total=#candidates}
        end
    end
    self.display=list
    self.offset=math.max(0,math.min(self.offset,#list-7))
    self.scroll:SetMinMaxValues(0,math.max(0,#list-7)); self.scroll:SetValue(self.offset)
    self.scroll:SetShown(#list>7)
    self.start:SetText(self.scan and "Stop scan" or "Scan upgrades")
    self.back:SetShown(self.slot~=nil)
    local p=self.profile or G:CurrentProfile()
    self.subtitle:SetText((p and (p.name.." | Level "..p.level) or "Waiting for character data").." | Equipped gear comparisons")
    self.heading:SetText(self.slot and (names[self.slot].." - all upgrades") or "Best upgrade per slot")
    self.status:SetText(self.message or "Scan the auction house to find upgrades for your current gear.")
    self.hint:SetText(self.slot and "Click an item to find its auctions. Prices are per listing; check the exact variant before buying."
        or "Click a slot to see every upgrade. Empty slots use item score. Each slot is compared separately.")
    for index,frame in ipairs(self.rows) do
        local entry=list[self.offset+index]; frame.entry=entry; frame:SetShown(entry~=nil)
        if entry then
            local row=self.slot and entry or entry.best
            frame.slot:SetText(self.slot and tostring(self.offset+index) or names[entry.slot])
            frame.icon:SetTexture(row and row.icon or nil)
            frame.item:SetText(row and row.name or (self.profile and (self.complete and "No upgrades found" or "No upgrades found yet") or "Ready to scan"))
            frame.item:SetTextColor(unpack(row and Skin.colors.white or Skin.colors.muted))
            frame.percent:SetText(row and (row.percent and string.format("+%.2f%%",row.percent) or "Empty slot") or "")
            frame.cost:SetText(row and ((row.buyout==0 and "Bid " or "")..money(price(row))) or "")
            frame.action:SetText(row and (self.slot and select(2,price(row)) or ("View all ("..entry.total..")")) or "")
        end
    end
end

function U:Attach()
    if self.panel or not AuctionFrame or not AuctionFrameTab_OnClick or not QueryAuctionItems then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local index=(AuctionFrame.numTabs or 3)+1
    while _G["AuctionFrameTab"..index] do index=index+1 end
    local tab=CreateFrame("Button","AuctionFrameTab"..index,AuctionFrame,"AuctionTabTemplate")
    self.tab=tab; tab:SetID(index); tab:SetText("Upgrades")
    tab:SetPoint("LEFT",_G["AuctionFrameTab"..(index-1)],"RIGHT",-15,0)
    PanelTemplates_SetNumTabs(AuctionFrame,index); PanelTemplates_EnableTab(AuctionFrame,index)
    PanelTemplates_TabResize(tab,0,nil,36)
    tab:SetScript("OnClick",function(self) AuctionFrameTab_OnClick(self) end)
    local panel=CreateFrame("Frame",nil,AuctionFrame,"BackdropTemplate"); self.panel=panel
    panel:SetPoint("TOPLEFT",AuctionFrame,"TOPLEFT",19,-55); panel:SetSize(790,377)
    panel:SetFrameLevel(AuctionFrame:GetFrameLevel()+10); panel:EnableMouse(true)
    Skin.Paint(panel,"card"); panel:SetBackdropColor(0.025,0.031,0.037,1)
    label(panel,"HardcoreBuddy Upgrades",14,-8,440,Skin.colors.gold,16)
    self.subtitle=label(panel,"",14,-31,610,Skin.colors.muted,11)
    self.start=button(panel,"Scan upgrades",130,function() U:Start() end); self.start:SetPoint("TOPRIGHT",-14,-12)
    self.heading=label(panel,"",14,-59,570,Skin.colors.gold)
    self.back=button(panel,"All slots",95,function() U.slot=nil; U.offset=0; U:Refresh() end)
    self.back:SetPoint("TOPRIGHT",-14,-55)
    label(panel,"Slot",14,-83,90,Skin.colors.muted,10)
    label(panel,"Item",144,-83,280,Skin.colors.muted,10)
    label(panel,"Upgrade",453,-83,90,Skin.colors.muted,10)
    label(panel,"Price",555,-83,95,Skin.colors.muted,10)
    self.rows={}
    for i=1,7 do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.rows[i]=row
        row:SetPoint("TOPLEFT",12,-105-(i-1)*32); row:SetSize(744,30); Skin.Paint(row,"row")
        row:SetBackdropColor(i%2==0 and 0.065 or 0.04,0.06,0.07,1)
        row.slot=label(row,"",5,-5,95,Skin.colors.muted,11)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(26,26); row.icon:SetPoint("LEFT",101,0)
        row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.item=label(row,"",132,-5,300)
        row.percent=label(row,"",441,-5,98,Skin.colors.green)
        row.cost=label(row,"",543,-5,97,Skin.colors.gold,11)
        row.action=label(row,"",646,-5,96,Skin.colors.muted,11)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight","ADD")
        row:SetScript("OnEnter",function(self)
            local entry=self.entry; local item=entry and (U.slot and entry or entry.best)
            if item then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(item.link)
                GameTooltip:AddLine(item.label.." | "..item.auctions.." listing(s)",0.9,0.75,0.45)
                if item.count>1 then GameTooltip:AddLine("Listed stack: "..item.count,1,0.8,0.4) end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row:SetScript("OnClick",function(self)
            if not self.entry then return end
            GameTooltip:Hide()
            if U.slot then U:Find(self.entry)
            elseif self.entry.total>0 then U.slot=self.entry.slot; U.offset=0; U:Refresh() end
        end)
    end
    self.scroll=CreateFrame("Slider",nil,panel,"BackdropTemplate"); Skin.Paint(self.scroll,"edit")
    self.scroll:SetOrientation("VERTICAL"); self.scroll:SetSize(14,219); self.scroll:SetPoint("TOPRIGHT",-12,-105)
    self.scroll:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob"); self.scroll:GetThumbTexture():SetSize(16,32)
    self.scroll:SetValueStep(1); self.scroll:SetObeyStepOnDrag(true)
    self.scroll:SetScript("OnValueChanged",function(_,value)
        value=math.floor(value+0.5); if U.offset~=value then U.offset=value; GameTooltip:Hide(); U:Refresh() end
    end)
    panel:EnableMouseWheel(true); panel:SetScript("OnMouseWheel",function(_,delta)
        self.scroll:SetValue(math.max(0,math.min(self.offset-delta*3,#(self.display or {})-7)))
    end)
    self.status=label(panel,"",14,-330,760,Skin.colors.gold,11)
    self.hint=label(panel,"",14,-352,760,Skin.colors.muted,10)
    panel:Hide()
    panel:SetScript("OnHide",function() if self.scan then self:Stop("Scan stopped. Results are partial.") end end)
    hooksecurefunc("AuctionFrameTab_OnClick",function(selected)
        panel:SetShown(selected==tab)
        if selected==tab then
            AuctionFrame.type="list"
            if SetAuctionsTabShowing then SetAuctionsTabShowing(false) end
            PanelTemplates_SetTab(AuctionFrame,index)
            if self.profileKey and profileKey(G:CurrentProfile())~=self.profileKey then self:Invalidate() end
            self:Refresh()
        end
    end)
    hooksecurefunc("QueryAuctionItems",function()
        if self.scan and not self.sending then self:Stop("Another auction search started. Results are partial; scan again.") end
    end)
    self:Refresh()
end

U.events=CreateFrame("Frame")
for _,event in ipairs({"AUCTION_HOUSE_SHOW","AUCTION_HOUSE_CLOSED","AUCTION_ITEM_LIST_UPDATE","PLAYER_REGEN_ENABLED",
    "PLAYER_EQUIPMENT_CHANGED","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","PLAYER_LEVEL_UP"}) do U.events:RegisterEvent(event) end
U.events:SetScript("OnEvent",function(_,event)
    if event=="AUCTION_HOUSE_SHOW" then U.open=true; U.attachPending=true
    elseif event=="AUCTION_HOUSE_CLOSED" then U.open=false; U.complete=false; U:Stop("Auction house closed. Scan again for current listings.")
    elseif event=="AUCTION_ITEM_LIST_UPDATE" then
        if U.scan and U.scan.phase=="waiting" then U.scan.phase="reading"; U.scan.index=1 end
    elseif event=="PLAYER_REGEN_ENABLED" then if U.open then U.attachPending=true end
    else U:Invalidate() end
end)
U.events:SetScript("OnUpdate",function(_,elapsed)
    U.elapsed=(U.elapsed or 0)+elapsed
    if U.elapsed>=0.05 then U.elapsed=0; U:Tick() end
end)
