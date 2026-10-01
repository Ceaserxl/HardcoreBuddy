local _,A=...
local U={results={},offset=0}; A.AuctionUpgrades=U
local G,Skin=A.GearAdvisor,A.Skin
local visibleRows=5
local checkedBySearch={{1},{2},{3},{5},{6},{7},{8},{9},{10},{15},{11,12},{13,14},{16},{17},{16},{18}}
local slots={1,2,3,5,6,7,8,9,10,15,11,12,13,14,16,17,18}
local names={[1]="Head",[2]="Neck",[3]="Shoulders",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",
    [9]="Wrists",[10]="Hands",[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",
    [15]="Back",[16]="Main hand",[17]="Off hand",[18]="Ranged",twoHand="Two-handed",paired="1H + off hand"}
-- Auction inventory types differ from equipment-slot IDs. Shared ring/trinket
-- slots and generic one-handed weapons are queried once, then compared in both
-- eligible slots; duplicate queries would inflate available weapon copies.
local searches={
    {"Head",true,{4,1}}, {"Neck",false,{4,2}}, {"Shoulders",true,{4,3}},
    {"Chest",true,{4,5},{4,20}}, {"Waist",true,{4,6}}, {"Legs",true,{4,7}},
    {"Feet",true,{4,8}}, {"Wrists",true,{4,9}}, {"Hands",true,{4,10}},
    {"Back",false,{4,16}}, {"Rings",false,{4,11}}, {"Trinkets",false,{4,12}},
    {"Main hand",false,{2,13},{2,21}}, {"Off hand",false,{2,22},{4,14},{4,23}},
    {"Two-handed",false,{2,17}}, {"Ranged",false,{2,15},{2,25},{2,26}},
}
local armorSlots={INVTYPE_HEAD=true,INVTYPE_SHOULDER=true,INVTYPE_CHEST=true,INVTYPE_ROBE=true,
    INVTYPE_WAIST=true,INVTYPE_LEGS=true,INVTYPE_FEET=true,INVTYPE_WRIST=true,INVTYPE_HAND=true}
local armorNames={"Cloth","Leather","Mail","Plate"}
-- Supply the full class/subclass/slot hierarchy, as Blizzard's auction
-- categories do. Omitting subClassID can discard the inventory-type filter
-- and repeatedly retrieve the entire armor/weapon category for each slot.
local armorSubclasses={[2]={0},[11]={0},[12]={0},[16]={1},[14]={6},[23]={0}}
local bodySubclasses={0,1,2,3,4}
local oneHandSubclasses={0,4,7,13,15}
local rangedSubclasses={2,3,18,19}
local weaponSubclasses={
    [13]=oneHandSubclasses,[21]=oneHandSubclasses,[22]=oneHandSubclasses,
    [17]={1,5,6,8,10,20},[15]=rangedSubclasses,[25]={16},[26]=rangedSubclasses,
}

function U:SearchQueue(highestArmor)
    local queue={}
    for _,search in ipairs(searches) do
        local entry={name=search[1],filters={}}
        for i=3,#search do
            local class,inventory=search[i][1],search[i][2]
            local subclasses=class==2 and weaponSubclasses[inventory] or armorSubclasses[inventory] or bodySubclasses
            if search[2] and highestArmor then subclasses={highestArmor} end
            for _,subclass in ipairs(subclasses) do
                entry.filters[#entry.filters+1]={classID=class,subClassID=subclass,inventoryType=inventory}
            end
        end
        queue[#queue+1]=entry
    end
    return queue
end
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
    if (not not a.owned)~=(not not b.owned) then return a.owned end
    if (a.buyout>0)~=(b.buyout>0) then return a.buyout>0 end
    local ap,bp=price(a),price(b)
    if ap~=bp then return ap<bp end
    return (a.key or a.link)<(b.key or b.link)
end
local function change(row)
    if row.part then return row.owned and "Equipped" or "Included" end
    if row.percent then return string.format(row.percent>0 and "+%.2f%%" or "%.2f%%",row.percent) end
    if row.weaponSet and not row.emptyBaseline then return "No baseline" end
    return "Empty slot"
end
local function changeColor(row)
    return row.part and Skin.colors.muted or row.percent and row.percent<0 and Skin.colors.red
        or row.percent==0 and Skin.colors.muted or Skin.colors.green
end

local function hideComparisons()
    if GameTooltip_HideShoppingTooltips then GameTooltip_HideShoppingTooltips(GameTooltip)
    else for _,tip in ipairs(GameTooltip.shoppingTooltips or {}) do tip:Hide() end end
end

function U:HideTooltip(row)
    local owner=GameTooltip:GetOwner()
    if owner and owner.hardcoreBuddyAuctionRow and (not row or owner==row) then
        owner.comparisonState=nil
        hideComparisons(); GameTooltip:Hide()
    end
end

function U:UpdateTooltipComparison(row)
    if GameTooltip:GetOwner()~=row or not GameTooltip:IsShown() then return end
    local _,link=GameTooltip:GetItem()
    if not link or not GameTooltip_ShowCompareItem then return end
    -- The native comparison call clears/reanchors the shopping tooltips.
    -- Reuse them across owner OnUpdate calls instead of rebuilding every tick.
    local state=row.comparisonState
    if state and state.link==link then
        local intact=true
        for _,tip in ipairs(state.visible) do if not tip:IsShown() then intact=false; break end end
        if intact then return end
    end
    GameTooltip_ShowCompareItem(GameTooltip)
    state={link=link,visible={}}; row.comparisonState=state
    for _,tip in ipairs(GameTooltip.shoppingTooltips or {}) do
        if tip:IsShown() then state.visible[#state.visible+1]=tip end
    end
end

function U:Stop(message)
    A.AuctionDiagnostics:Finish(self.scan,message)
    self.scan=nil
    if message then self.message=message end
    self:Refresh()
end

function U:Start()
    if self.scan then self:Stop("Scan stopped. Results are partial."); return end
    if not self.open or not self.panel or not self.panel:IsShown() then return end
    local p=G:CurrentProfile()
    if not p then self:Stop("Talent data is loading. Try again in a moment."); return end
    local equipped={}
    for _,slot in ipairs(slots) do
        local item,reason=G:Equipped(slot)
        if reason and reason~="unsupported" then self:Stop("Equipped gear is loading. Try again in a moment."); return end
        if slot==16 or slot==17 then equipped[slot]=item end
    end
    local weapons,reason=A.WeaponSetAdvisor.New(p,equipped)
    if not weapons then self:Stop(reason); return end
    self.results={}; self.slot=nil; self.setup=nil; self.offset=0; self.complete=false; self.stale=false
    self.checkedSlots={}; self.progress=0
    self.weaponBaseline=weapons.baseline
    self.profile=p; self.profileKey=profileKey(p)
    local highest=A.characterDB and A.characterDB.auctionHighestArmorOnly and G.HighestArmorSubclass(p) or nil
    self.scan={search=1,queue=self:SearchQueue(highest),highestArmor=highest,page=0,phase="query",since=now(),
        seen=0,skipped=0,cache={},weapons=weapons}
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
    local function unavailable(stage,reason,item,slot)
        return false,{stage=stage,reason=reason,name=name,link=link,item=item,comparisonSlot=slot,
            auction={name=name,count=count,usable=usable,minimum=minimum,increment=increment,buyout=buyout,bid=bid}}
    end
    if not name or not link or not count or not buyout or not minimum then
        local missing={}
        for _,field in ipairs({{"name",name},{"item link",link},{"stack count",count},{"buyout price",buyout},{"minimum bid",minimum}}) do
            if field[2]==nil then missing[#missing+1]=field[1] end
        end
        return unavailable("auction data","Missing "..table.concat(missing,", "))
    end
    local cached=scan.cache[link]
    if cached==false then return true end
    if not cached then
        local item,reason=G:Read(link)
        if reason=="unsupported" then scan.cache[link]=false; return true end
        if not item then return unavailable("item data",reason or "Item reader returned no data") end
        if not G.Allowed(item,self.profile) then scan.cache[link]=false; return true end
        if scan.highestArmor and armorSlots[item.equip] and item.subclassID~=scan.highestArmor then
            scan.cache[link]=false; return true
        end
        local rows=G:Comparisons(item,self.profile)
        for _,row in ipairs(rows) do
            -- Structural exclusions (unique items / two-handed constraints)
            -- are final; incomplete native data is retried before skipping.
            if row.status=="unknown" and (row.text:find("loading") or row.text:find("incomplete") or row.text:find("unavailable")) then
                return unavailable("gear comparison",row.text,item,row.slot)
            end
        end
        cached={item=item,rows=rows}; scan.cache[link]=cached
    end
    local nextBid=(bid or 0)>0 and bid+(increment or 0) or minimum
    if not scan.weapons:Add(cached.item,icon,buyout,nextBid,count) then
        return unavailable("weapon score","Main-hand or off-hand stat score is incomplete",cached.item)
    end
    self:Add(cached.item,cached.rows,link,icon,buyout,nextBid,count)
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
        local search=scan.queue[scan.search]
        self.message=string.format("Scanning %s (%d/%d) | page %d | %d auctions checked",search.name,scan.search,#scan.queue,scan.page+1,scan.seen)
        self:Refresh()
        self.sending=true
        QueryAuctionItems("",nil,self.profile.level,scan.page,true,nil,false,false,search.filters)
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
                else
                    for _,slot in ipairs(checkedBySearch[scan.search]) do self.checkedSlots[slot]=true end
                    self.progress=scan.search/#scan.queue
                    scan.search=scan.search+1; scan.page=0
                end
                if scan.search>#scan.queue then
                    scan.phase="weapons"; scan.worker=coroutine.create(function() return scan.weapons:Build() end)
                    self.message="Comparing two-handed and main-hand/off-hand setups..."; self:Refresh()
                else scan.phase="query"; scan.since=now(); self:Refresh() end
                return
            end
            local read,detail=self:ReadAuction(scan.index)
            if read then
                scan.index=scan.index+1; scan.itemSince=nil; scan.itemAttempts=nil; scan.firstReason=nil
            else
                scan.itemSince=scan.itemSince or now()
                scan.itemAttempts=(scan.itemAttempts or 0)+1
                scan.firstReason=scan.firstReason or (detail and detail.reason)
                if now()-scan.itemSince<10 then return end
                scan.skipped=scan.skipped+1
                A.AuctionDiagnostics:Record(scan,detail)
                scan.index=scan.index+1; scan.itemSince=nil; scan.itemAttempts=nil; scan.firstReason=nil
            end
        end
    elseif scan.phase=="weapons" then
        local ok,result=coroutine.resume(scan.worker)
        if not ok then
            self:Stop("Weapon comparison unavailable. Results are partial; scan again.")
            if geterrorhandler then geterrorhandler()(result) end
        elseif coroutine.status(scan.worker)=="dead" then
            self.results.twoHand=result.twoHand; self.results.paired=result.paired
            self.checkedSlots.twoHand=true; self.checkedSlots.paired=true
            self.complete=scan.skipped==0
            self:Stop(string.format("%s | %d auctions checked%s",self.complete and "Scan complete" or "Partial results",scan.seen,
                scan.skipped>0 and (" | "..scan.skipped..(scan.skipped==1 and " listing" or " listings").." could not be read. Rescan to retry.") or ""))
        end
    end
end

function U:Invalidate()
    if not self.profile then return end
    self.stale=true; self.complete=false
    local owner=GameTooltip:GetOwner()
    if owner and owner.hardcoreBuddyAuctionRow then owner.tooltipItem=nil end
    self:Stop("Gear or talents changed. Scan again to refresh upgrades.")
end

function U:Find(row)
    if row and row.owned then return end
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
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetSize(width,24)
    Skin.Paint(b,"card")
    b.caption=label(b,"",6,-2,width-12,Skin.colors.white,11)
    b.caption:SetJustifyH("CENTER")
    function b:SetText(value) self.caption:SetText(value) end
    function b:GetText() return self.caption:GetText() end
    function b:PaintState(active)
        self.active=active
        self:SetBackdropColor(active and 0.20 or 0.065,active and 0.16 or 0.08,active and 0.09 or 0.095,1)
        self:SetBackdropBorderColor(active and 0.75 or 0.20,active and 0.57 or 0.25,active and 0.28 or 0.29,1)
        self.caption:SetTextColor(unpack(active and Skin.colors.gold or Skin.colors.white))
    end
    b:SetScript("OnEnter",function(self) self:SetBackdropBorderColor(0.8,0.65,0.37,1) end)
    b:SetScript("OnLeave",function(self) self:PaintState(self.active) end)
    b:PaintState(false)
    b:SetText(text); b:SetScript("OnClick",callback); return b
end

function U:SelectSlot(slot)
    self:HideTooltip()
    self.slot=slot; self.setup=nil; self.weaponsOnly=false; self.offset=0
    self:Refresh()
end

function U:Refresh()
    if not self.panel then return end
    local list={}
    if self.setup then
        list=self.setup.components
    elseif self.slot then
        for _,row in ipairs(self.results[self.slot] or {}) do list[#list+1]=row end
        table.sort(list,better)
    elseif self.profile then
        for _,slot in ipairs(self.weaponsOnly and {16,17} or slots) do
            slot=slot==16 and "twoHand" or slot==17 and "paired" or slot
            local candidates=self.results[slot] or {}; table.sort(candidates,better)
            local best=candidates[1]
            if self.weaponsOnly or (best and not best.owned and (not best.percent or best.percent>0)) then
                list[#list+1]={slot=slot,best=best,total=#candidates}
            end
        end
    end
    self.display=list
    self.offset=math.max(0,math.min(self.offset,#list-visibleRows))
    self.scroll:SetMinMaxValues(0,math.max(0,#list-visibleRows)); self.scroll:SetValue(self.offset)
    self.scroll:SetShown(#list>visibleRows)
    self.start:SetText(self.scan and "Stop scan" or self.profile and "Rescan upgrades" or "Scan upgrades")
    self.start:PaintState(true)
    self.back:SetShown(self.slot~=nil or self.weaponsOnly)
    self.back:SetText(self.setup and "< Setups" or self.slot and self.weaponsOnly and "< Weapons" or "< Overview")
    self.overview:PaintState(not self.slot and not self.weaponsOnly)
    self.weaponButton:PaintState(self.weaponsOnly or self.slot=="paired" or self.slot=="twoHand")
    for slot,tab in pairs(self.slotButtons) do tab:PaintState(self.slot==slot) end
    local p=self.profile or G:CurrentProfile()
    local armorProfile=G:CurrentProfile()
    self.armorOnly:SetChecked(A.characterDB and A.characterDB.auctionHighestArmorOnly==true)
    self.armorOnly.label:SetText("Best Armor: "..(armorProfile and armorNames[G.HighestArmorSubclass(armorProfile)] or "..."))
    self.subtitle:SetText(p and (p.name.."  |  Level "..p.level.."  |  Compared with equipped gear") or "Waiting for character data")
    local weaponView=self.slot=="paired" or self.slot=="twoHand"
    self.heading:SetText(self.setup and "Items in this setup" or self.slot and names[self.slot]
        or self.weaponsOnly and "Compare weapon setups" or "Best upgrades by slot")
    local bestTwo=self.results.twoHand and self.results.twoHand[1]
    local bestPair=self.results.paired and self.results.paired[1]
    local advice=bestTwo and bestPair and (bestTwo.score==bestPair.score and "Equal scores"
        or "Higher score: "..(bestTwo.score>bestPair.score and "Two-handed" or "1H + off hand")) or "Both hands compared together"
    self.hint:SetText(self.setup and (change(self.setup).." for both hands"..(self.setup.emptyOff and " | Off hand stays empty" or ""))
        or weaponView and (#list.." setups | Score change includes both hands")
        or self.slot and (#list.." upgrades | Best score first | Hover to compare equipped gear")
        or self.weaponsOnly and advice or "Choose a slot for all upgrades. Hover to compare equipped gear.")
    self.status:SetText(self.message or "Start a scan to find upgrades. You can browse results as they arrive.")
    local diagnostics=A.characterDB and A.characterDB.auctionDiagnostics
    self.diagnosticsButton:SetShown(diagnostics~=nil)
    self.status:SetWidth(diagnostics and 620 or 762)
    self.status:SetTextColor(unpack(self.stale and Skin.colors.red or self.scan and Skin.colors.gold
        or self.complete and Skin.colors.green or Skin.colors.muted))
    self.progressFill:SetWidth(math.max(1,762*(self.progress or 0)))
    self.progressFill:SetVertexColor(unpack(self.complete and Skin.colors.green or Skin.colors.gold))
    self.progressFill:SetShown((self.progress or 0)>0 or self.scan~=nil)
    self.empty:SetShown(#list==0)
    local waiting=self.slot and not (self.checkedSlots and self.checkedSlots[self.slot])
    self.emptyTitle:SetText(not self.profile and "Find your next upgrade" or self.scan and waiting and "Waiting for this slot"
        or self.scan and not self.slot and "Searching the auction house"
        or waiting and "This slot has not been scanned" or "No upgrades found here")
    self.emptyText:SetText(not self.profile and "1. Scan upgrades   2. Choose a slot   3. Find auctions"
        or self.scan and self.slot and not waiting and "This slot is complete. Other slots are still being scanned."
        or self.scan and "Results will appear here as each slot is checked."
        or self.stale and "Your equipment changed. Rescan to update comparisons."
        or waiting and "Start a new scan to check this slot."
        or "Try another slot or rescan for new listings.")
    for index,frame in ipairs(self.rows) do
        local entry=list[self.offset+index]; frame.entry=entry; frame:SetShown(entry~=nil)
        if entry then
            local row=self.slot and entry or entry.best
            local checked=self.checkedSlots and self.checkedSlots[entry.slot]
            frame.icon:SetTexture(row and row.icon or nil); frame.icon:SetShown(row~=nil)
            local pair=row and row.weaponSet and #row.components==2
            frame.item:SetText(row and (pair and row.components[1].name or row.name) or names[entry.slot])
            frame.item:SetTextColor(unpack(row and Skin.colors.white or Skin.colors.muted))
            local detail=self.setup and entry.label or self.slot and (row and row.owned and "Currently equipped" or "Option "..(self.offset+index))
                or names[entry.slot]
            if pair then detail="Off hand: "..row.components[2].name
            elseif not row then detail=checked and "No upgrade found" or self.scan and "Waiting for this slot" or "Slot not scanned"
            elseif not self.slot then
                local noun=row.weaponSet and "setup" or "upgrade"
                detail=detail.." | "..entry.total.." "..noun..(entry.total==1 and "" or "s")
            end
            frame.slot:SetText(detail)
            frame.percent:SetText(row and (row.percent==nil and not row.part and not row.weaponSet and "Empty slot" or change(row)) or "--")
            frame.percent:SetTextColor(unpack(row and changeColor(row) or Skin.colors.muted))
            local value,kind
            if row then value,kind=price(row) end
            frame.cost:SetText(row and (row.owned and "No purchase" or money(value)) or "")
            frame.priceKind:SetText(row and not row.owned and (row.weaponSet and (row.priceLabel.." total") or kind) or "")
            frame.action:SetText(row and (self.slot and (row.weaponSet and "View items >" or row.owned and "Equipped"
                or self.scan and "Stop scan to browse" or "Find auctions >") or "See options >") or "")
            frame.accent:SetShown(row~=nil)
            frame.accent:SetVertexColor(unpack(row and changeColor(row) or Skin.colors.muted))
        end
    end
    -- Preserve stationary hover through scan updates, including comparisons.
    local owner=GameTooltip:IsShown() and GameTooltip:GetOwner()
    if owner and owner.hardcoreBuddyAuctionRow then
        local entry=owner.entry
        local item=entry and (self.slot and entry or entry.best)
        if not self.panel:IsShown() or not owner:IsShown() or not item then self:HideTooltip(owner)
        elseif item~=owner.tooltipItem or item.auctions~=owner.tooltipAuctions then
            local old=owner.tooltipItem
            if old and not item.weaponSet and old.link==item.link and old.owned==item.owned
                and old.label==item.label and old.count==item.count then
                -- A new price/listing record for the same item does not change
                -- its equipped comparison. Keep the tooltip in place.
                owner.tooltipItem=item; owner.tooltipAuctions=item.auctions
            else owner:GetScript("OnEnter")(owner) end
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
    label(panel,"HardcoreBuddy  /  Gear upgrades",16,-12,560,Skin.colors.white,18)
    self.subtitle=label(panel,"",16,-38,580,Skin.colors.muted,11)
    self.start=button(panel,"Scan upgrades",156,function() U:Start() end); self.start:SetPoint("TOPRIGHT",-14,-12)
    self.armorOnly=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
    self.armorOnly:SetSize(18,18); self.armorOnly:SetPoint("TOPLEFT",self.start,"BOTTOMLEFT",0,0)
    self.armorOnly.label=label(self.armorOnly,"Best Armor: ...",20,0,136,Skin.colors.muted,11)
    self.armorOnly.label:SetHeight(18)
    self.armorOnly:SetScript("OnClick",function(self)
        if not A.characterDB then return end
        A.characterDB.auctionHighestArmorOnly=not not self:GetChecked()
        U.results={}; U.slot=nil; U.setup=nil; U.offset=0; U.profile=nil; U.weaponBaseline=nil
        U.complete=false; U.stale=false; U.progress=0; U.checkedSlots={}
        U:Stop("Armor filter changed. Scan upgrades to refresh results.")
    end)
    local divider=Skin.Divider(panel); divider:SetPoint("TOPLEFT",14,-68); divider:SetWidth(762)
    divider:SetVertexColor(0.20,0.25,0.29,1)
    self.overview=button(panel,"Best by slot",174,function() U:SelectSlot(nil) end)
    self.overview:SetPoint("TOPLEFT",14,-78)
    self.weaponButton=button(panel,"Compare weapons",174,function()
        U:HideTooltip(); U.weaponsOnly=true; U.slot=nil; U.setup=nil; U.offset=0; U:Refresh()
    end)
    self.weaponButton:SetPoint("TOPLEFT",14,-106)
    label(panel,"JUMP TO SLOT",16,-133,172,Skin.colors.muted,9)
    self.slotButtons={}
    for i,slot in ipairs(slots) do
        slot=slot==16 and "twoHand" or slot==17 and "paired" or slot
        local key=slot
        local caption=key=="twoHand" and "2H weapon" or key=="paired" and "1H + off hand" or names[key]
        local tab=button(panel,caption,85,function() U:SelectSlot(key) end)
        tab:SetSize(85,18); tab.caption:SetFont(STANDARD_TEXT_FONT,11,"")
        tab.caption:SetHeight(18); tab.caption:SetPoint("TOPLEFT",4,0); tab.caption:SetWidth(77)
        tab:SetPoint("TOPLEFT",14+((i-1)%2)*89,-155-math.floor((i-1)/2)*19)
        self.slotButtons[key]=tab
    end
    self.heading=label(panel,"",204,-78,430,Skin.colors.white,14)
    self.hint=label(panel,"",204,-99,558,Skin.colors.muted,10)
    self.back=button(panel,"< Overview",100,function()
        U:HideTooltip()
        if U.setup then U.setup=nil elseif U.slot then U.slot=nil else U.weaponsOnly=false end
        U.offset=0; U:Refresh()
    end)
    self.back:SetPoint("TOPRIGHT",-14,-76)
    label(panel,"ITEM / SLOT",252,-117,260,Skin.colors.muted,9)
    label(panel,"SCORE CHANGE",526,-117,95,Skin.colors.muted,9)
    local priceHeader=label(panel,"LISTING PRICE",640,-117,120,Skin.colors.muted,9); priceHeader:SetJustifyH("RIGHT")
    self.empty=CreateFrame("Frame",nil,panel); self.empty:SetPoint("TOPLEFT",204,-155); self.empty:SetSize(558,150)
    self.emptyTitle=label(self.empty,"",12,-24,534,Skin.colors.white,18); self.emptyTitle:SetJustifyH("CENTER")
    self.emptyText=label(self.empty,"",12,-60,534,Skin.colors.muted,11); self.emptyText:SetJustifyH("CENTER")
    label(self.empty,"Percentages compare item scores, not total character damage.",20,-99,518,Skin.colors.muted,10):SetJustifyH("CENTER")
    self.rows={}
    for i=1,visibleRows do
        local row=CreateFrame("Button",nil,panel,"BackdropTemplate"); self.rows[i]=row
        row.hardcoreBuddyAuctionRow=true
        -- The native GameTooltip OnUpdate calls its owner's UpdateTooltip.
        -- Keep equipped comparisons visible while the mouse remains here.
        row.UpdateTooltip=function(self) U:UpdateTooltipComparison(self) end
        row:SetPoint("TOPLEFT",204,-138-(i-1)*38); row:SetSize(558,36); Skin.Paint(row,"row")
        row:SetBackdropColor(i%2==0 and 0.055 or 0.04,i%2==0 and 0.075 or 0.055,i%2==0 and 0.09 or 0.07,1)
        row.accent=row:CreateTexture(nil,"ARTWORK"); row.accent:SetTexture("Interface\\Buttons\\WHITE8x8")
        row.accent:SetPoint("TOPLEFT",0,-4); row.accent:SetSize(2,28)
        row.slot=label(row,"",48,-17,268,Skin.colors.muted,10)
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(28,28); row.icon:SetPoint("LEFT",9,0)
        row.icon:SetTexCoord(0.07,0.93,0.07,0.93)
        row.item=label(row,"",48,0,268,Skin.colors.white,12)
        row.percent=label(row,"",322,0,94,Skin.colors.green,12)
        row.cost=label(row,"",426,0,122,Skin.colors.white,11); row.cost:SetJustifyH("RIGHT")
        row.action=label(row,"",322,-17,130,Skin.colors.gold,9)
        row.priceKind=label(row,"",456,-17,92,Skin.colors.muted,9); row.priceKind:SetJustifyH("RIGHT")
        row:SetHighlightTexture("Interface\\Buttons\\WHITE8x8","ADD")
        row:GetHighlightTexture():SetVertexColor(0.08,0.10,0.12,0.5)
        row:SetScript("OnEnter",function(self)
            U:HideTooltip()
            local entry=self.entry; local item=entry and (U.slot and entry or entry.best)
            if item then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(item.link)
                if item.weaponSet then
                    GameTooltip:AddLine(" ")
                    GameTooltip:AddLine("Complete setup vs equipped: "..change(item),unpack(changeColor(item)))
                    for _,part in ipairs(item.components) do
                        GameTooltip:AddLine(part.label..": "..part.name..(part.owned and " (equipped)" or ""),0.9,0.75,0.45,true)
                    end
                    if item.emptyOff then GameTooltip:AddLine("Off hand: empty",0.9,0.75,0.45) end
                    GameTooltip:AddLine("Total: "..(item.owned and "No purchase" or money(price(item)).." ("..item.priceLabel..")"),0.9,0.75,0.45)
                else
                    if item.count>1 then GameTooltip:AddLine("Listed stack: "..item.count,1,0.8,0.4) end
                end
                self.tooltipItem=item; self.tooltipAuctions=item.auctions
                GameTooltip:Show()
                self:UpdateTooltip()
            end
        end)
        row:SetScript("OnLeave",function(self) U:HideTooltip(self) end)
        row:SetScript("OnHide",function(self) U:HideTooltip(self) end)
        row:SetScript("OnClick",function(self)
            if not self.entry then return end
            U:HideTooltip(self)
            if self.entry.weaponSet then U.setup=self.entry; U.offset=0; U:Refresh()
            elseif U.slot then U:Find(self.entry)
            else U.slot=self.entry.slot; U.offset=0; U:Refresh() end
        end)
    end
    self.scroll=CreateFrame("Slider",nil,panel,"BackdropTemplate"); Skin.Paint(self.scroll,"edit")
    self.scroll:SetOrientation("VERTICAL"); self.scroll:SetSize(8,188); self.scroll:SetPoint("TOPRIGHT",-14,-138)
    self.scroll:SetThumbTexture("Interface\\Buttons\\WHITE8x8"); self.scroll:GetThumbTexture():SetSize(6,28)
    self.scroll:GetThumbTexture():SetVertexColor(0.42,0.48,0.53,1)
    self.scroll:SetValueStep(1); self.scroll:SetObeyStepOnDrag(true)
    self.scroll:SetScript("OnValueChanged",function(_,value)
        value=math.floor(value+0.5); if U.offset~=value then U.offset=value; U:Refresh() end
    end)
    panel:EnableMouseWheel(true); panel:SetScript("OnMouseWheel",function(_,delta)
        self.scroll:SetValue(math.max(0,math.min(self.offset-delta*3,#(self.display or {})-visibleRows)))
    end)
    local progressTrack=panel:CreateTexture(nil,"BACKGROUND"); progressTrack:SetTexture("Interface\\Buttons\\WHITE8x8")
    progressTrack:SetPoint("TOPLEFT",14,-336); progressTrack:SetSize(762,3); progressTrack:SetVertexColor(0.12,0.16,0.19,1)
    self.progressFill=panel:CreateTexture(nil,"ARTWORK"); self.progressFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    self.progressFill:SetPoint("TOPLEFT",14,-336); self.progressFill:SetSize(1,3)
    self.status=label(panel,"",14,-345,762,Skin.colors.muted,10)
    self.diagnosticsButton=button(panel,"Scan details",128,function() A.AuctionDiagnostics:Show() end)
    self.diagnosticsButton:SetPoint("TOPRIGHT",-14,-345)
    panel:Hide()
    panel:SetScript("OnHide",function()
        self:HideTooltip()
        if self.scan then self:Stop("Scan stopped. Results are partial.") end
    end)
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
