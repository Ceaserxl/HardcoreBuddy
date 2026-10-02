-- Exact-item supply quantities; targets are editable planning suggestions.
local _, addon = ...
local P = addon.Planner
local S = {}
addon.Supplies = S
S.categories = {"All", "Food & Drink", "Elixirs", "Scrolls", "Potions", "Emergency", "Class", "Enchants", "Optional", "User"}
S.filters={"All","Essentials"}
for i=2,#S.categories do S.filters[#S.filters+1]=S.categories[i] end
S.priorities={"Essentials","Advanced","Optional"}
local essentials={recovery=true,drink=true,wellfed=true,manafood=true,bandage=true,healing=true,
    ammunition=true,["Swiftness Potion"]=true,["Swim Speed Potion"]=true}
local advanced={["Flask of Petrification"]=true,["Limited Invulnerability Potion"]=true,
    ["Free Action Potion"]=true,["Restorative Potion"]=true,["Living Action Potion"]=true,["Light of Elune"]=true}
local casterFood={Mage=true,Priest=true,Warlock=true}
local function primaryBuffFood(context)
    if casterFood[context.characterClass] then
        for _,food in ipairs(addon.Data.Items.items) do
            if food.family=="manafood" and P.AvailableAt(food)<=context.level
                and P.MatchesClass(food,context.characterClass) and P.MatchesFaction(food,P.ContextFaction(context)) then
                return "manafood"
            end
        end
    end
    return "wellfed"
end
function S.Priority(context,item)
    local saved=context.priorities or {}
    local choice=saved[item.family] or saved[item.itemId] or saved[tostring(item.itemId)]
    for _,value in ipairs(S.priorities) do if choice==value then return value end end
    if item.family=="wellfed" or item.family=="manafood" then
        return item.family==primaryBuffFood(context) and "Essentials" or "Optional"
    end
    return essentials[item.family] and "Essentials" or advanced[item.family] and "Advanced" or "Optional"
end

function S.CanDefaultBandage(context,item)
    if not item or item.family~="bandage" then return false end
    local skill=context.professions and context.professions.skills and context.professions.skills.bandage
    for _,recipe in ipairs(addon.Professions.recipes.bandage) do
        if recipe.itemId==item.itemId then return type(skill)=="number" and skill>=recipe.useSkill end
    end
    return false
end

-- Explicit bandage defaults use the live character's use-skill requirement.
-- Other profession families continue to select the best learned recipe.
function S.Selection(context, family)
    if family=="bandage" then
        local id=(context.supplyDefaults or {}).bandage
        if id and S.CanDefaultBandage(context,{family="bandage",itemId=id}) then
            return id,{status="selected",itemId=id,note="Your default bandage",manual=true}
        end
    end
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
    if item.group == "Food & drink" then return "Food & Drink" end
    if item.group == "Potions & elixirs" then return "Elixirs" end
    return "Emergency"
end

function S.Category(item)
    if item.supplyCategory then return item.supplyCategory=="Buffs" and "Elixirs" or item.supplyCategory end
    if item.armorKit then return "Enchants" end
    if item.ammoKind then return "Class" end
    if item.userItem then return "User" end
    if item.family=="trollsblood" then return "Elixirs" end
    if item.name and item.name:find("Potion",1,true) then return "Potions" end
    if item.family=="healthstone" or item.family=="managem" or item.family=="feather"
        or item.family=="tea" or item.family=="vanish" or item.family=="blind" then return "Class" end
    return defaultCategory(item)
end

function S.NormalizeTarget(value,limit)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
    return math.min(limit or 200, math.max(0, math.floor(value)))
end

function S.DefaultTarget(item)
    if item.itemId==5816 then return 1 end
    if item.armorKit or item.enchantMaterial then return item.recommendedTarget or 1 end
    if item.ammoKind then return item.ammoKind=="thrown" and 100 or 1000 end
    if item.userItem then return 1 end
    local family = item.family
    if family == "recovery" or family == "drink" or family == "bandage" then return 20 end
    if family == "healthstone" or family == "managem" or defaultCategory(item) == "Optional" then return 1 end
    if family == "vanish" or family == "blind" or family == "feather" then return 10 end
    if family == "healing" or family == "mana" or defaultCategory(item) == "Elixirs"
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
    local suggested=item.ammoKind and addon.Ammunition.DefaultTarget(context,item) or S.DefaultTarget(item)
    groupFamily = groupFamily or (P.grouped[item.family] and item.family or nil)
    local target = S.NormalizeTarget(targets[id] ~= nil and targets[id] or targets[tostring(id)],item.ammoKind and 10000 or 200)
    if target == nil then target = suggested end
    local count = available and (inventory.counts[id] or 0) or nil
    if item.ammoKind and addon.Ammunition then count=addon.Ammunition.Count(context,item) end
    if item.ammoKind and context.characterClass~="Hunter" and targets[id]==nil and targets[tostring(id)]==nil then target=100 end
    -- A consumed, unique quest reward cannot be restocked by another purchase.
    local oneTime=id==5816
    if oneTime then target=1 end
    local completed=C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
    local obtainable=oneTime and count==0 and P.ContextFaction(context)=="Alliance" and completed and completed(1017)==false
    if count ~= nil and (type(count) ~= "number" or count ~= count or count < 0
        or count == math.huge or count ~= math.floor(count)) then count = nil end
    local missing = count ~= nil and math.max(0, target - count) or nil
    local thresholds=context.refillThresholds or {}
    local threshold=S.NormalizeTarget(thresholds[id] or thresholds[tostring(id)],item.ammoKind and 10000 or 200)
    if threshold==nil then threshold=item.ammoKind and (item.ammoKind=="thrown" and 20 or 200) or 5 end
    threshold=math.min(target,threshold)
    local status = count == nil and "unknown" or missing == 0 and "ready" or count == 0 and "missing" or "low"
    local note = item.useSkill and ("Requires " .. item.useSkill.name .. " " .. item.useSkill.value)
        or groupFamily == "antivenom" and ("Poisons up to level "..item.power) or nil
    return {
        item=item, itemId=id, name=item.name..(obtainable and " |cff66ee99(Obtainable)|r" or ""), displayName=item.name, icon=item.icon,
        oneTime=oneTime,
        family=item.family, groupFamily=groupFamily, category=S.Category(item),priority=S.Priority(context,item),
        count=count, target=target, targetKey=id, status=status, missing=missing,
        owned=count ~= nil and count > 0 or false, available=count ~= nil,
        quantityNote=note, defaultTarget=suggested,
        refillThreshold=oneTime and 0 or threshold,refillNeeded=not oneTime and threshold>0 and count~=nil and count<target and count<=threshold,
        optional=S.Category(item) == "Optional", tracking=target > 0,
    }
end

local function matches(item, category, query)
    if category ~= "All" and category~="Essentials" and S.Category(item) ~= category then return false end
    local text = table.concat({item.name or "", item.short or "", item.family or "",
        item.useSkill and item.useSkill.name or "", S.Category(item)}, " "):lower()
    for word in tostring(query or ""):lower():gmatch("%S+") do
        if not text:find(word, 1, true) then return false end
    end
    return true
end

-- Preferences only apply to currently eligible alternatives, so old food and
-- potion choices cannot suppress a stronger tier when the character levels.
function S.PreferredItem(context, row)
    local selected=row
    local wanted=(context.supplyDefaults or {})[row.family]
    for _,item in ipairs(row.options or {}) do if item.itemId==wanted then selected=item; break end end
    local inventory=context.inventory or {}
    local count=inventory.available and inventory.counts and (inventory.counts[selected.itemId] or 0)
    if not wanted and type(count)=="number" and count>=0 and count<5
        and row.family=="recovery" and addon.VendorServices then
        local bestVendor
        local function localFood(item)
            if not item.vendorFood or item.level~=row.level then return end
            local vendor=addon.VendorServices:FindVendor(item.itemId)
            if vendor and (not bestVendor or vendor.movementRank<bestVendor.movementRank
                or vendor.movementRank==bestVendor.movementRank and vendor.distance<bestVendor.distance) then
                selected,bestVendor=item,vendor
            end
        end
        localFood(row)
        for _,item in ipairs(row.options or {}) do localFood(item) end
    end
    local out={}; for k,v in pairs(selected) do out[k]=v end
    out.options={}
    if selected~=row then out.options[1]=row end
    for _,item in ipairs(row.options or {}) do
        if item.itemId~=selected.itemId then out.options[#out.options+1]=item end
    end
    out.next=row.next; out.progression=row.progression
    out.supplyCategory=S.Category(row)
    return out
end

local genericTitles={recovery="Food",drink="Drink",wellfed="Food",manafood="Food",
    bandage="Bandage",dummy="Dummy",antivenom="Antivenom",healing="Healing",mana="Mana",
    healthstone="Healthstone",managem="Gem",feather="Reagent",vanish="Reagent",blind="Reagent",tea="Tea"}
function S.GenericTitle(item)
    if item.armorKit then return "Armor" end
    if item.ammoKind then return ({arrows="Arrows",bullets="Bullets",thrown="Thrown"})[item.ammoKind] or "Ammo" end
    if genericTitles[item.family] then return genericTitles[item.family] end
    if item.group=="Scrolls" then return "Scroll" end
    if (item.name or ""):find("Potion",1,true) then return "Potion" end
    if (item.name or ""):find("Elixir",1,true) then return "Elixir" end
    if (item.name or ""):find("Flask",1,true) then return "Flask" end
    return item.userItem and "Item" or "Utility"
end

function S.DefaultGroup(context, item)
    if not item or item.userItem or P.grouped[item.family] then return end
    for _,row in ipairs(P.BuildList(context.characterClass,context.level,P.ContextFaction(context)).rows) do
        if row.family==item.family and #(row.options or {})>0 then
            if row.itemId==item.itemId then return row end
            for _,other in ipairs(row.options) do if other.itemId==item.itemId then return row end end
        end
    end
end

function S.Build(context, state)
    state = state or {}
    local category = state.category or state.filter or "All"
    if category=="Buffs" then category="Elixirs" end
    if category == "Recovery" or category == "Food & drink" then category = "Food & Drink" end
    local stock = state.stock or "All"
    local plan = P.BuildList(context.characterClass, context.level, P.ContextFaction(context))
    local rows, seen = {}, {}

    local function add(item, groupFamily)
        local id = item.itemId
        if seen[id] or not matches(item, category, state.query) then return end
        seen[id] = true
        local record = S.Record(context, item, groupFamily)
        if category=="Essentials" and (record.priority~="Essentials"
            or groupFamily and S.Selection(context,groupFamily)~=id) then return end
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
        else add(S.PreferredItem(context,item)) end
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
    if addon.Ammunition then local ammo=addon.Ammunition.Recommend(context); if ammo then add(ammo) end end
    if addon.ArmorKits then for _,item in ipairs(addon.ArmorKits.Recommendations(context)) do add(item) end end
    if addon.Enchants then for _,item in ipairs(addon.Enchants.MaterialItems(context)) do add(item) end end
    for _,item in ipairs(context.userItems or {}) do add(item) end
    return rows
end
