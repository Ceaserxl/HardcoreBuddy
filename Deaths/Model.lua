-- Pure data logic; no game frames or network calls.
local _, addon = ...
addon.Deaths = { VERSION = addon.version, MAX_RECORDS = 5000 }
local H = addon.Deaths
-- Lets the installed standalone addon yield to the integrated implementation.
HardcoreBuddyDeaths = H

function H.Clean(value, limit)
    if type(value) ~= "string" then return "" end
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return value:gsub("|", ""):gsub("[%c]", " "):sub(1, limit or 180)
end
function H.ShortName(name)
    return H.Clean(name, 80):match("^([^%-]+)") or ""
end
function H.ParseOfficial(message, realm, timestamp)
    local text = H.Clean(message, 600)
    -- Keep the original localized announcement even when structured parsing fails.
    local name = text:match("%[([^%]]+)%]")
    local level = text:match("[Tt]hey were level (%d+)") or text:match("[Ll]evel (%d+)")
    local cause, zone = text:match("has been slain by (.-) in (.-)!")
    if not cause then
        cause, zone = text:match("%] (.-) in (.-)!")
    end
    return {
        name = name and H.Clean(name, 80) or "Unknown adventurer",
        level = tonumber(level), cause = cause, zone = zone,
        realm = realm, date = timestamp, source = "Blizzard", message = text,
    }
end
function H.ParseCommunity(message, sender, realm, timestamp)
    if type(message) ~= "string" or #message > 2048 then return end
    local payload = message:match("^1%$(.+)")
    if not payload then return end
    local fields = {}
    for field in payload:gmatch("(.-)~") do fields[#fields + 1] = field end
    local name, level = fields[1], tonumber(fields[6])
    if not name or H.ShortName(sender):lower() ~= H.ShortName(name):lower()
        or not level or level % 1 ~= 0 or level < 1 or level > 60 then return end
    return {
        name = H.Clean(name, 80), realm = realm, level = level,
        guild = H.Clean(fields[2], 80), npcID = tonumber(fields[3]),
        classID = tonumber(fields[5]), date = timestamp, source = "Community",
        message = "Community report (unverified).",
    }
end
function H.Key(record)
    return (record.realm or ""):lower() .. ":" .. (record.name or ""):lower()
end
function H.Same(a, b)
    if a.name == "Unknown adventurer" or b.name == "Unknown adventurer" then
        return a.message == b.message and a.realm == b.realm and math.abs(a.date - b.date) <= 180
    end
    return H.Key(a) == H.Key(b)
        and (not a.level or not b.level or a.level == b.level)
        and math.abs(a.date - b.date) <= 180
end
local rank = { Community = 1, Imported = 2, Blizzard = 3, Self = 4 }
function H.Insert(records, record, limit)
    if type(record) ~= "table" or type(record.name) ~= "string" or record.name == "" then return false end
    -- Merge duplicate reports before inserting in chronological order.
    for i = #records, 1, -1 do
        local old = records[i]
        if H.Same(old, record) then
            local upgrade = (rank[record.source] or 0) >= (rank[old.source] or 0)
            for key, value in pairs(record) do
                if key ~= "date" and value ~= nil and value ~= "" and (upgrade
                    or old[key] == nil or old[key] == "") then old[key] = value end
            end
            return false, old
        end
    end
    local low, high = 1, #records + 1
    while low < high do
        local mid = math.floor((low + high) / 2)
        if records[mid].date <= record.date then low = mid + 1 else high = mid end
    end
    table.insert(records, low, record)
    if #records > limit then table.remove(records, 1) end
    return true, record
end
function H.Filter(records, query, mode, minLevel, realm)
    query = H.Clean(query):lower()
    local output = {}
    for i = #records, 1, -1 do
        local r = records[i]
        local haystack = table.concat({r.name or "", r.zone or "", r.cause or "", r.guild or "", r.message or ""}, " "):lower()
        if (not realm or r.realm == realm) and (not minLevel or minLevel == 0 or (r.level or 0) >= minLevel)
            and (mode ~= "verified" or r.source == "Blizzard" or r.source == "Self")
            and (query == "" or haystack:find(query, 1, true)) then output[#output + 1] = r end
    end
    return output
end
function H.Stats(records)
    local sum, known, highest, zones = 0, 0, 0, {}
    for _, r in ipairs(records) do
        if r.level then sum, known, highest = sum + r.level, known + 1, math.max(highest, r.level) end
        if r.zone and r.zone ~= "" then zones[r.zone] = (zones[r.zone] or 0) + 1 end
    end
    local deadliest, count = "--", 0
    for zone, deaths in pairs(zones) do
        if deaths > count or (deaths == count and zone < deadliest) then deadliest, count = zone, deaths end
    end
    return { count = #records, average = known > 0 and sum / known or nil,
        highest = highest, zone = deadliest, zoneCount = count }
end
