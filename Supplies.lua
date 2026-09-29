-- Exact-item supply quantities; targets are editable planning suggestions.
local _, addon = ...
local P = addon.Planner
local S = {}
addon.Supplies = S
S.categories = {"All", "Food & drink", "Buffs", "Potions", "Emergency", "Class", "Scrolls", "Optional", "User"}

-- Automatic profession choices always come from the current character, even
-- while previewing a different class/level. Old manual choices cannot pin them.
function S.Selection(context, family)
    if addon.Professions.autoFamilies[family] then
        local result=addon.Professions.Best(context.professions,family)
        return result.itemId,result
    end
    return (context.ranks or {})[family]
end

local function defaultCategory(item)
    if item.group == "Scrolls" then return "Scrolls" end
    if item.family == "healing" or item.family == "mana" then return "Emergency" end
    if item.group == "Route-specific backups" or item.alternative then return "Optional" end
    if item.group == "Food & drink" then return "Food & drink" end
    if item.group == "Potions & elixirs" then return "Buffs" end
    return "Emergency"
end

function S.Category(item)
    if item.userItem then return "User" end
    if item.family=="trollsblood" then return "Buffs" end
    if item.name and item.name:find("Potion",1,true) then return "Potions" end
    if item.family=="healthstone" or item.family=="managem" or item.family=="feather"
        or item.family=="tea" or item.family=="vanish" or item.family=="blind" then return "Class" end
    return defaultCategory(item)
end

function S.NormalizeTarget(value)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return math.min(200, math.max(0, math.floor(value)))
end

function S.DefaultTarget(item)
    if item.userItem then return 1 end
    local family = item.family
    if family == "recovery" or family == "drink" or family == "bandage" then return 20 end
    if family == "healthstone" or family == "managem" or defaultCategory(item) == "Optional" then return 1 end
    if family == "vanish" or family == "blind" or family == "feather" then return 10 end
    if family == "healing" or family == "mana" or defaultCategory(item) == "Buffs"
        or family == "wellfed" or family == "manafood" then return 5 end
    return 3
end

-- Item details remain useful after a preview/level change replaces the current
-- recommendation. Read this exact item's stock without recommendation gates.
function S.Record(context, item, groupFamily)
    local id = item.itemId
    local inventory = context.inventory or {}
    local available = inventory.available == true and type(inventory.counts) == "table"
    local targets = type(context.targets) == "table" and context.targets or {}
    groupFamily = groupFamily or (P.grouped[item.family] and item.family or nil)
    local target = S.NormalizeTarget(targets[id] ~= nil and targets[id] or targets[tostring(id)])
    if target == nil then target = S.DefaultTarget(item) end
    local count = available and (inventory.counts[id] or 0) or nil
    if count ~= nil and (type(count) ~= "number" or count ~= count or count < 0
        or count == math.huge or count ~= math.floor(count)) then count = nil end
    local missing = count ~= nil and math.max(0, target - count) or nil
    local status = count == nil and "unknown" or missing == 0 and "ready" or count == 0 and "missing" or "low"
    local note = item.useSkill and ("Requires " .. item.useSkill.name .. " " .. item.useSkill.value)
        or groupFamily == "antivenom" and ("Poisons up to level "..item.power) or nil
    return {
        item=item, itemId=id, name=item.name, displayName=item.name, icon=item.icon,
        family=item.family, groupFamily=groupFamily, category=S.Category(item),
        count=count, target=target, targetKey=id, status=status, missing=missing,
        owned=count ~= nil and count > 0 or false, available=count ~= nil,
        quantityNote=note, defaultTarget=S.DefaultTarget(item),
        optional=S.Category(item) == "Optional", tracking=target > 0,
    }
end

local function matches(item, category, query)
    if category ~= "All" and S.Category(item) ~= category then return false end
    local text = table.concat({item.name or "", item.short or "", item.family or "",
        item.useSkill and item.useSkill.name or "", S.Category(item)}, " "):lower()
    for word in tostring(query or ""):lower():gmatch("%S+") do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

function S.Build(context, state)
    state = state or {}
    local category = state.category or state.filter or "All"
    if category == "Recovery" then category = "Food & drink" end
    local stock = state.stock or "All"
    local plan = P.BuildList(context.characterClass, context.level, P.ContextFaction(context))
    local rows, seen = {}, {}

    local function add(item, groupFamily)
        local id = item.itemId
        if seen[id] or not matches(item, category, state.query) then return end
        seen[id] = true
        local record = S.Record(context, item, groupFamily)
        if stock == "Missing" and (record.missing == nil or record.missing == 0) then return end
        if stock == "Ready" and record.status ~= "ready" then return end
        rows[#rows + 1] = record
    end

    for _, item in ipairs(plan.rows) do
        if P.grouped[item.family] then
            -- Each rank has a different itemID and use requirement. Never assign
            -- a family total to the lowest rank's name, icon or detail tooltip.
            for _, rank in ipairs(item.progression) do
                if P.AvailableAt(rank) <= context.level and P.MatchesClass(rank, context.characterClass) then
                    add(rank, item.family)
                end
            end
        else add(item) end
    end
    for _, section in ipairs({plan.specialist, plan.backups, plan.advanced}) do
        for _, item in ipairs(section) do add(item) end
    end
    -- Keep one current recommendation per scroll type, with exact-rank stock.
    local best,order={},{}
    for _,item in ipairs(addon.Data.Scrolls and addon.Data.Scrolls.items or {}) do
        if item.level<=context.level and P.MatchesClass(item,context.characterClass) then
            if not best[item.family] then order[#order+1]=item.family end
            if not best[item.family] or item.level>best[item.family].level then best[item.family]=item end
        end
    end
    for _,family in ipairs(order) do add(best[family]) end
    for _,item in ipairs(context.userItems or {}) do add(item) end
    return rows
end
