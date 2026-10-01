local addonName,A=...
local S={schema=2}; A.GearSnapshot=S
local G=A.GearAdvisor
local slotNames={[0]="Ammo","Head","Neck","Shoulders","Shirt","Chest","Waist","Legs","Feet",
    "Wrists","Hands","Ring 1","Ring 2","Trinket 1","Trinket 2","Back","Main hand","Off hand","Ranged","Tabard"}

-- SavedVariables must contain independent, serializable values, never native
-- frames or shared API tables that later item/talent updates can mutate.
local function copy(value)
    if type(value)=="table" then
        local result={}
        for k,v in pairs(value) do
            if type(k)=="number" or type(k)=="string" then result[k]=copy(v) end
        end
        return result
    elseif type(value)=="string" or type(value)=="boolean" then return value
    elseif type(value)=="number" and value==value and math.abs(value)<math.huge then return value end
end
local function api(name) return C_Item and C_Item[name] or _G[name] end

function S:ReadTalents()
    local trees={}
    for tab=1,3 do
        local tree={index=tab,talents={}}
        local modern=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
        if modern then
            local id,name,_,_,_,_,points=modern(tab,false,false)
            tree.id,tree.name,tree.points=id,name,points
        elseif GetTalentTabInfo then
            local first,second,third,_,fifth=GetTalentTabInfo(tab,false,false)
            if type(first)=="string" then tree.name,tree.points=first,third
            else tree.id,tree.name,tree.points=first,second,fifth end
        end
        local count=GetNumTalents and GetNumTalents(tab,false,false)
        if type(count)=="number" then
            for index=1,math.min(count,50) do
                local info
                if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
                    info=C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=index,isInspect=false,isPet=false})
                elseif GetTalentInfo then
                    local name,icon,tier,column,rank,maxRank=GetTalentInfo(tab,index,false,false)
                    if name then info={name=name,icon=icon,tier=tier,column=column,rank=rank,maxRank=maxRank} end
                end
                tree.talents[index]=copy(info) or {unavailable=true}
            end
        else tree.detailsUnavailable=true end
        trees[tab]=tree
    end
    return trees
end

function S:ReadSlot(slot,profile)
    local row={slot=slot,slotName=slotNames[slot]}
    row.itemID=GetInventoryItemID("player",slot)
    row.link=GetInventoryItemLink("player",slot)
    if not row.itemID or row.itemID==0 then
        row.state=row.link and "unavailable" or "empty"
        return row
    end
    -- Classic can expose selected ammunition through slot 0's item ID while
    -- GetInventoryItemLink returns nil. Ammo has no suffix/enchant variant;
    -- scan its item ID link rather than waiting for a nonexistent slot link.
    -- Keep every other slot strict so missing random-suffix links stay unknown.
    if slot==0 and not row.link then
        row.link="item:"..row.itemID; row.linkSource="itemID"
    end
    if not row.link or tonumber(row.link:match("item:(%d+)"))~=row.itemID then
        row.state,row.reason="unavailable","Item link loading"; return row
    end
    row.enchantID=tonumber(row.link:match("item:%d+:(%d+)")) or 0
    if slot==0 then
        local countAPI=api("GetItemCount")
        if countAPI then
            local ok,count=pcall(countAPI,row.itemID,false,false,false)
            if ok and type(count)=="number" and count==count and count>=0 and count<math.huge then
                row.availableCount=count
            else row.countUnavailable=true end
        else row.countUnavailable=true end
    end
    local info,statsAPI=api("GetItemInfo"),api("GetItemStats")
    if info then
        local name,_,quality,level,required,_,_,_,equip,icon,_,classID,subclassID=info(row.link)
        row.name,row.quality,row.itemLevel,row.requiredLevel=name,quality,level,required
        row.equipLoc,row.icon,row.classID,row.subclassID=equip,icon,classID,subclassID
    end
    row.apiStats=statsAPI and copy(statsAPI(row.link))
    local scanSlot=slot
    if row.linkSource=="itemID" then scanSlot=nil end
    local scan=G:Scan(row.link,scanSlot,true)
    row.tooltipLines=scan and copy(scan.tooltipLines)
    local item,reason
    if slot==0 then reason="unsupported" -- saved for review; ammo has no gear score
    else item,reason=G:Equipped(slot) end
    row.advisor=copy(item)
    row.advisorReason=reason
    row.score=item and profile and G.Score(item,profile,slot) or nil
    row.scoreModel=row.score~=nil and "classic-weighted-v3" or nil
    if item and profile and row.score==nil then
        reason="Item stats incomplete"; row.advisorReason=reason
    end
    if not row.name then row.state,row.reason="unavailable","Item data loading"
    elseif not scan then row.state,row.reason="unavailable","Item tooltip loading"
    elseif reason and reason~="unsupported" then
        row.state,row.reason="unavailable",reason
    else row.state="saved" end
    return row
end

function S:Capture(quiet)
    if not A.characterDB or not GetInventoryItemID or not GetInventoryItemLink then
        self.message="Equipment data is not ready. Try again after loading."
        return nil,self.message
    end
    local profile,profileReason=G:CurrentProfile()
    local _,class=UnitClass("player")
    local stamp=GetServerTime and GetServerTime() or time()
    local snapshot={schema=self.schema,capturedAt=stamp,addonVersion=A.version,
        character={name=UnitName("player"),realm=GetRealmName(),guid=UnitGUID("player"),
            class=class,level=UnitLevel("player"),faction=UnitFactionGroup("player")},
        locale=GetLocale and GetLocale(),projectID=WOW_PROJECT_ID,
        profile=copy(profile),profileReason=profileReason,talents=self:ReadTalents(),
        scoring={enchantsIncluded=false,method="Classic weighted item stats"},slots={}}
    if GetBuildInfo then
        local version,build,buildDate,interface=GetBuildInfo()
        snapshot.client={version=version,build=build,date=buildDate,interface=interface}
    end
    for slot=0,19 do snapshot.slots[slot]=self:ReadSlot(slot,profile) end
    snapshot.savedCount,snapshot.unavailableCount,snapshot.emptyCount=0,0,0
    for slot=0,19 do
        local row=snapshot.slots[slot]
        local currentLink=GetInventoryItemLink("player",slot)
        local linkChanged=currentLink~=row.link
        if row.linkSource=="itemID" then
            linkChanged=currentLink~=nil and tonumber(currentLink:match("item:(%d+)"))~=row.itemID
        end
        if linkChanged or GetInventoryItemID("player",slot)~=row.itemID then
            row.state,row.reason="unavailable","Equipment changed during capture; snapshot again"
            row.advisor,row.score,row.scoreModel=nil,nil,nil
        end
        local key=row.state=="saved" and "savedCount" or row.state=="empty" and "emptyCount" or "unavailableCount"
        snapshot[key]=snapshot[key]+1
    end
    snapshot.complete=snapshot.unavailableCount==0 and profile~=nil
    -- Keep only the most recent manual snapshot for this character.
    A.characterDB.gearSnapshot=snapshot
    self.message=nil
    if not quiet then A:Print("Gear snapshot captured. Use /reload or log out to save it for offline review."
        ..(snapshot.complete and "" or " Some data is unavailable; wait for it to load and snapshot again."))
    end
    return snapshot
end
