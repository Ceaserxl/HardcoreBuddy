local _,A=...
local C={schema=2}; A.AuctionCache=C
local slots={1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}

local function copy(value)
    if type(value)~="table" then return value end
    local result={}
    for key,entry in pairs(value) do result[key]=copy(entry) end
    return result
end

function C:Signature(profile)
    if not profile or not GetInventoryItemID or not GetInventoryItemLink then return end
    local parts={profile.class,profile.level,profile.id or profile.name,tostring(profile.manual),
        tostring(A.characterDB and A.characterDB.auctionHighestArmorOnly==true),tostring(A.GearAdvisor.CanDualWield(profile))}
    parts[#parts+1]=tostring(A.AuctionUpgrades:LevelRange())
    local keys={}; for key in pairs(profile.weights) do keys[#keys+1]=key end; table.sort(keys)
    for _,key in ipairs(keys) do parts[#parts+1]=key.."="..profile.weights[key] end
    for _,slot in ipairs(slots) do
        local id=GetInventoryItemID("player",slot)
        local link=GetInventoryItemLink("player",slot)
        if id and id~=0 and not link then return end
        parts[#parts+1]=link or "empty"
    end
    return table.concat(parts,";")
end

function C:Save(upgrades,message)
    if not A.characterDB or not upgrades.scan or not upgrades.profile then return end
    local stamp=date and date("%Y-%m-%d %H:%M") or "Unknown time"
    A.characterDB.auctionLastScan={schema=self.schema,results=copy(upgrades.results),profile=copy(upgrades.profile),
        signature=upgrades.scanSignature,checkedSlots=copy(upgrades.checkedSlots),progress=upgrades.progress,
        complete=upgrades.complete,weaponBaseline=upgrades.weaponBaseline,recordedAt=stamp,
        location=GetRealZoneText and GetRealZoneText() or "",message=message or "Scan interrupted. Results are partial."}
    upgrades.savedScanAt=stamp
end

function C:Restore(upgrades)
    if upgrades.profile then return end
    local saved=A.characterDB and A.characterDB.auctionLastScan
    if type(saved)~="table" or saved.schema~=self.schema or type(saved.results)~="table"
        or type(saved.profile)~="table" or type(saved.profile.weights)~="table" then return end
    upgrades.results=copy(saved.results); upgrades.profile=copy(saved.profile)
    upgrades.checkedSlots=copy(saved.checkedSlots or {}); upgrades.progress=saved.progress or 0
    upgrades.complete=saved.complete; upgrades.weaponBaseline=saved.weaponBaseline
    upgrades.savedScanAt=saved.recordedAt; upgrades.cached=true; upgrades.scanSignature=saved.signature
    upgrades.stale=not saved.signature or saved.signature~=self:Signature(A.GearAdvisor:CurrentProfile())
    upgrades.message=upgrades.stale and "Gear, talents or armor filter changed. Rescan to update comparisons."
        or ((saved.message or "Saved scan").." Prices may have changed.")
    if upgrades.stale then upgrades.complete=false end
    return true
end
