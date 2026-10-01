local _,A=...
local G=A.GearAdvisor
local W={}; A.WeaponSetAdvisor=W
W.__index=W

local function variant(item)
    local fields={}
    for field in ((item.link:match("item:([%d:%-]+)") or "")..":"):gmatch("(.-):") do fields[#fields+1]=field end
    return item.id..":"..(fields[7] or "0")
end
local function roles(item,p)
    local e=item.equip
    if e=="INVTYPE_2HWEAPON" then return "twoHand" end
    if e=="INVTYPE_WEAPON" then return "main",G.CanDualWield(p) and "off" or nil end
    if e=="INVTYPE_WEAPONMAINHAND" then return "main" end
    if e=="INVTYPE_HOLDABLE" or e=="INVTYPE_SHIELD" or (e=="INVTYPE_WEAPONOFFHAND" and G.CanDualWield(p)) then return "off" end
end
local function cost(offer) return offer.buyout>0 and offer.buyout or offer.bid end
local function cheaper(a,b)
    if (a.buyout>0)~=(b.buyout>0) then return a.buyout>0 end
    return cost(a)<cost(b)
end

function W.New(profile,equipped)
    local base=0
    for slot=16,17 do
        local score=G.Score(equipped[slot],profile,slot)
        if not score then return nil,"Equipped weapon stats are loading. Try again in a moment." end
        base=base+score
    end
    return setmetatable({profile=profile,equipped=equipped,baseline=base,catalog={},results={twoHand={},paired={}}},W)
end

function W:Add(item,icon,buyout,bid,count)
    if not roles(item,self.profile) or not G.Allowed(item,self.profile) then return true end
    local key=variant(item)
    local record=self.catalog[key]
    if not record then
        local mainScore,offScore=G.Score(item,self.profile,16),G.Score(item,self.profile,17)
        if not mainScore or not offScore then return false end
        record={key="auction:"..key,item=item,icon=icon,offers={},auctions=0,mainScore=mainScore,offScore=offScore}
        self.catalog[key]=record
    end
    record.auctions=record.auctions+1
    record.offers[#record.offers+1]={buyout=buyout,bid=bid,count=count,link=item.link}
    table.sort(record.offers,cheaper)
    -- Two physical listings are enough for a legal duplicate-weapon pair.
    -- Retain the second actual price instead of charging the cheapest twice.
    if #record.offers>2 then table.remove(record.offers) end
    return true
end

local function component(record,slot,offerIndex)
    if not record then return end
    local offer=not record.owned and record.offers[offerIndex or 1]
    return {key=record.key,link=offer and offer.link or record.item.link,name=record.item.name,item=record.item,
        icon=record.icon,label=slot==16 and "Main hand" or "Off hand",owned=record.owned,
        buyout=offer and offer.buyout or 0,bid=offer and offer.bid or 0,count=offer and offer.count or 1,
        auctions=record.auctions or 0,part=true}
end

function W:Pair(main,off)
    if not main then return end
    local first=roles(main.item,self.profile)
    if first~="main" and first~="twoHand" then return end
    if off then
        if first=="twoHand" then return end
        local offFirst,offSecond=roles(off.item,self.profile)
        if offFirst~="off" and offSecond~="off" then return end
        if main.item.id==off.item.id and (main.item.unique or off.item.unique) then return end
        if main==off and (main.owned or #main.offers<2) then return end
    end
    local m=component(main,16); local o=component(off,17,main==off and 2 or 1)
    local score=main.mainScore+(off and off.offScore or 0)
    local total,hasBid,hasBuyout=0,false,false
    local parts={m}; if o then parts[2]=o end
    for _,part in ipairs(parts) do
        if not part.owned then
            total=total+cost(part); hasBid=hasBid or part.buyout==0; hasBuyout=hasBuyout or part.buyout>0
        end
    end
    local current=m.owned and (not o or o.owned)
    local delta=self.baseline>0 and (score*100/self.baseline-100)
        or self.baseline<0 and ((score-self.baseline)*100/math.abs(self.baseline))
    local percent=delta and math.floor(delta*100)/100 or nil
    return {key=main.key.."/"..(off and off.key or "empty"),components=parts,weaponSet=true,owned=current,
        link=m.link,icon=m.icon,name=m.name..(o and (" + "..o.name) or first=="main" and " (empty off hand)" or ""),
        label="Both hands",score=score,percent=percent,
        baseline=self.baseline,emptyBaseline=not self.equipped[16] and not self.equipped[17],
        buyout=not hasBid and total or 0,bid=hasBid and total or 0,
        priceLabel=current and "Owned" or hasBid and (hasBuyout and "Bid + buyout" or "Bid") or "Buyout",
        emptyOff=first=="main" and not off}
end

function W:Build()
    self.results={twoHand={},paired={}}
    local groups={main={},off={},twoHand={}}
    local owned={}
    local function add(record)
        local first,second=roles(record.item,self.profile)
        if first then groups[first][#groups[first]+1]=record end
        if second then groups[second][#groups[second]+1]=record end
    end
    for slot=16,17 do
        local item=self.equipped[slot]
        if item then
            local info=C_Item and C_Item.GetItemInfo or GetItemInfo
            owned[slot]={key="equipped:"..slot,item=item,owned=true,icon=info and select(10,info(item.link)),
                mainScore=G.Score(item,self.profile,16),offScore=G.Score(item,self.profile,17)}
            add(owned[slot])
        end
    end
    for _,record in pairs(self.catalog) do add(record) end
    for kind,group in pairs(groups) do
        local scoreKey=kind=="off" and "offScore" or "mainScore"
        table.sort(group,function(a,b)
            local as,bs=a[scoreKey],b[scoreKey]
            if as~=bs then return as>bs end
            if not not a.owned~=not not b.owned then return a.owned end
            if not a.owned and not b.owned then
                if cheaper(a.offers[1],b.offers[1]) then return true end
                if cheaper(b.offers[1],a.offers[1]) then return false end
            end
            return a.key<b.key
        end)
    end
    local seen={}
    local function save(row,kind)
        if row and not seen[row.key] then seen[row.key]=true; self.results[kind][#self.results[kind]+1]=row end
    end
    -- Include the current configuration even when its individual pieces have
    -- better partners on the market, giving both views a clear keep/swap baseline.
    if owned[16] then
        save(self:Pair(owned[16],owned[17]),owned[16].item.equip=="INVTYPE_2HWEAPON" and "twoHand" or "paired")
    end
    local work=0
    local function yieldWork()
        work=work+1; if work%64==0 then coroutine.yield() end
    end
    for _,record in ipairs(groups.twoHand) do save(self:Pair(record),"twoHand"); yieldWork() end
    -- Each main hand and off hand gets its highest-scoring legal partner.
    -- This covers upgrades for either slot without storing a quadratic list of
    -- every possible pairing. Yield even in long runs of incompatible uniques.
    for _,main in ipairs(groups.main) do
        local best
        for _,off in ipairs(groups.off) do
            best=self:Pair(main,off); yieldWork(); if best then break end
        end
        save(best or self:Pair(main),"paired"); yieldWork()
    end
    for _,off in ipairs(groups.off) do
        for _,main in ipairs(groups.main) do
            local best=self:Pair(main,off); yieldWork()
            if best then save(best,"paired"); break end
        end
    end
    return self.results
end
