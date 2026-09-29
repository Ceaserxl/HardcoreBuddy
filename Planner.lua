local _, addon = ...
local P = {}
addon.Planner = P
local D = addon.Data
local F = D.FactionRules or {exclusiveItems={},acquisition={},routineZones={}}
P.classes, P.ease, P.classNotes = D.Presentation.classes, D.Presentation.ease, D.Presentation.classNotes
P.groups = {"Food & drink", "Potions & elixirs", "Emergency supplies"}
local nameOrder = {}
for index, name in ipairs(D.Presentation.nameOrder) do nameOrder[name] = index end
local grouped = {bandage = true, dummy = true, antivenom = true}
P.grouped = grouped

local function copy(t)
    local result = {}
    for k, v in pairs(t) do result[k] = v end
    return result
end
local function filter(t, predicate)
    local result = {}
    for _, value in ipairs(t) do if predicate(value) then result[#result + 1] = value end end
    return result
end
local function contains(t, value)
    for _, other in ipairs(t) do if other == value then return true end end
    return false
end
-- JavaScript sorts are stable. Preserve data order for exact equal-key parity.
local function sorted(t, less)
    local result = {}
    for _, value in ipairs(t) do
        local index = #result + 1
        while index > 1 and less(value, result[index - 1]) do
            result[index] = result[index - 1]
            index = index - 1
        end
        result[index] = value
    end
    return result
end
function P.AvailableAt(item) return item.recommendLevel or item.level end
function P.MatchesClass(item, class) return contains(item.classes, "All") or contains(item.classes, class) end
-- nil keeps the original unrestricted reference model. Runtime contexts always
-- supply a known faction or false, which explicitly means detection unavailable.
function P.ContextFaction(context)
    if context.faction=="Alliance" or context.faction=="Horde" then return context.faction end
    if context.factionUnknown or context.faction~=nil then return false end
end
function P.MatchesFaction(item,faction)
    if faction==nil then return true end
    local required=item.faction or F.exclusiveItems[item.itemId or item.id]
    return not required or required=="Neutral" or required==faction
end
function P.SourceMatchesFaction(source,faction)
    if faction==nil then return true end
    local affinity=source.routeFaction or F.routineZones[source.zone]
    return not affinity or affinity==faction
end
function P.ItemForFaction(item,faction)
    if not item or not P.MatchesFaction(item,faction) then return nil end
    if faction==nil then return item end
    local result=copy(item)
    local routes=F.acquisition[item.itemId]
    if routes then result.route=routes[faction] or routes.neutral or routes.other end
    for _,key in ipairs({"options","progression"}) do
        if item[key] then
            result[key]={}
            for _,other in ipairs(item[key]) do
                local allowed=P.ItemForFaction(other,faction)
                if allowed then result[key][#result[key]+1]=allowed end
            end
        end
    end
    if item.next then result.next=P.ItemForFaction(item.next,faction) end
    return result
end
function P.ByEase(a, b)
    if a.ease ~= b.ease then return a.ease < b.ease end
    return (nameOrder[a.name] or 9999) < (nameOrder[b.name] or 9999)
end
local function strength(a, b)
    local ap, bp = a.power or a.level, b.power or b.level
    if ap ~= bp then return ap > bp end
    if a.ease ~= b.ease then return a.ease < b.ease end
    if (a.preference or 0) ~= (b.preference or 0) then return (a.preference or 0) < (b.preference or 0) end
    return P.ByEase(a, b)
end
function P.BuildList(class, level, faction)
    local items = D.Items.items
    if faction~=nil then
        items={}
        for _,item in ipairs(D.Items.items) do
            local allowed=P.ItemForFaction(item,faction)
            if allowed then items[#items+1]=allowed end
        end
    end
    local eligible = filter(items, function(item) return P.MatchesClass(item, class) and P.AvailableAt(item) <= level end)
    local families, seen, rows = {}, {}, {}
    for _, item in ipairs(eligible) do
        if not item.alternative and not seen[item.family] then
            families[#families + 1], seen[item.family] = item.family, true
        end
    end
    for _, family in ipairs(families) do
        local options = sorted(filter(eligible, function(item) return item.family == family end), P.ByEase)
        local candidates = filter(options, function(item)
            return not item.alternative and ((family ~= "wellfed" and family ~= "manafood") or item.ease <= 2)
        end)
        candidates = sorted(candidates, grouped[family] and function(a, b) return a.power < b.power end or strength)
        local item = candidates[1]
        if item then
            local row = copy(item)
            row.displayName = family == "bandage" and "Bandages" or family == "dummy" and "Target dummies"
                or family == "antivenom" and "Anti-venom" or item.name
            row.short = family == "bandage" and "Strongest rank your First Aid allows"
                or family == "dummy" and "Choose one rank for your Engineering"
                or family == "antivenom" and "Match the poison level, not your level" or item.short
            row.options = filter(options, function(other)
                return other.id ~= item.id and ((family ~= "recovery" and family ~= "drink" and family ~= "wellfed")
                    or other.level >= item.level or (other.power ~= nil and item.power ~= nil and other.power >= item.power))
            end)
            row.progression = sorted(filter(items, function(other)
                return other.family == family and P.MatchesClass(other, class)
            end), function(a, b)
                if P.AvailableAt(a) ~= P.AvailableAt(b) then return P.AvailableAt(a) < P.AvailableAt(b) end
                return (a.power or 0) < (b.power or 0)
            end)
            for _, other in ipairs(row.progression) do
                if P.AvailableAt(other) > level then row.next = other; break end
            end
            rows[#rows + 1] = row
        end
    end
    return {
        rows = sorted(rows, P.ByEase),
        specialist = sorted(filter(eligible, function(i) return i.alternative and i.family:sub(1, 12) == "specialfood-" end), P.ByEase),
        backups = sorted(filter(eligible, function(i) return i.group == "Route-specific backups" end), P.ByEase),
        advanced = sorted(filter(eligible, function(i) return i.alternative and i.group == "Emergency supplies" end), P.ByEase),
    }
end

function P.TrainingLevel(rank, routineOnly, faction)
    if rank.trainer then return math.max(10, rank.petLevel) end
    local minimum
    for _, source in ipairs(rank.sources) do
        if (routineOnly == false or source.routine) and P.SourceMatchesFaction(source,faction) then
            minimum = math.min(minimum or 999, source.minLevel)
        end
    end
    return minimum and math.max(10, rank.petLevel, minimum) or nil
end

-- Character tame-source level and recipient pet level are independent gates.
-- nil petLevel means unknown, never silently substitute the character's level.
function P.HunterAbility(ability, level, petLevel, faction)
    local result = copy(ability)
    if faction~=nil then
        result.ranks={}
        for _,rank in ipairs(ability.ranks) do
            local r=copy(rank)
            r.sources=filter(rank.sources,function(s) return P.SourceMatchesFaction(s,faction) end)
            result.ranks[#result.ranks+1]=r
        end
    end
    result.restricted, result.sources = {}, {}
    for _, rank in ipairs(result.ranks) do
        local unlock = P.TrainingLevel(rank,nil,faction)
        if petLevel and level >= 10 and unlock and unlock <= level and rank.petLevel <= petLevel then result.current = rank end
        if not rank.trainer and not unlock then result.restricted[#result.restricted + 1] = rank end
    end
    for _, rank in ipairs(result.ranks) do
        local unlock = P.TrainingLevel(rank,nil,faction)
        if unlock and (not result.current or rank.rank > result.current.rank)
            and (not petLevel or unlock > level or rank.petLevel > petLevel) then result.next = rank; break end
    end
    if result.current then
        result.sources = filter(result.current.sources, function(s) return s.routine and s.minLevel <= level end)
    end
    return result
end

function P.HunterPlan(level, petLevel, faction)
    local data, sources = D.Companions, {}
    for _, s in ipairs(data.starters) do sources[#sources + 1] = s end
    local abilities = {}
    for _, ability in ipairs(data.abilities) do
        abilities[ability.id] = P.HunterAbility(ability, level, petLevel, faction)
        for _, rank in ipairs(ability.ranks) do for _, s in ipairs(rank.sources) do sources[#sources + 1] = s end end
    end
    local categories = {
        {name="Offensive", role="Offense", pick="Cat / Owl", text="Cat for single-target damage; owl for Screech utility. Keep Growl supplied with focus.",
            names={level >= 32 and "Stranglethorn Tiger" or "Durotar Tiger", level >= 48 and "Ironbeak Owl" or "Strigid Hunter"}},
        {name="General", role="General", pick=level >= 16 and "Carrion bird / Wolf" or "Wolf",
            text=level >= 16 and "Carrion bird for balanced stats and Screech; wolf is another balanced option."
                or "A wolf is a common early balanced choice. Carrion birds become a practical Screech option at 16.",
            names={level >= 32 and "Salt Flats Vulture" or level >= 16 and "Greater Fleshripper" or "Prairie Wolf"}},
        {name="Defensive", role="Defense", pick="Boar / Bear", text="Boar for Charge and flexible feeding; bear for extra health and a broad diet. Lower damage can mean slower kills.",
            names={"Elder Mottled Boar", "Scarred Crag Boar"}},
    }
    if faction~=nil then
        categories[1].names={level>=32 and "Stranglethorn Tiger" or faction=="Alliance" and "Moonstalker Runt" or "Durotar Tiger",
            level>=48 and "Ironbeak Owl" or "Strigid Hunter"}
        if faction=="Horde" or faction==false then
            categories[2].pick=level>=32 and "Carrion bird / Wolf" or "Wolf"
            categories[2].text=level>=32 and categories[2].text
                or "A local wolf is a balanced early choice. The shared Salt Flats route becomes available at level 32."
        end
        categories[2].names={level>=32 and "Salt Flats Vulture"
            or faction=="Alliance" and (level>=16 and "Greater Fleshripper" or "Prowler") or "Prairie Wolf"}
    end
    for _, category in ipairs(categories) do
        category.families = filter(data.families, function(f) return f.role == category.role end)
        category.pets = {}
        if level >= 10 then
            for _, name in ipairs(category.names) do
                for _, s in ipairs(sources) do
                    if s.name == name and s.routine and s.minLevel <= level and P.SourceMatchesFaction(s,faction) then
                        category.pets[#category.pets + 1] = s; break
                    end
                end
            end
        end
    end
    local names = level < 16 and {"Strigid Hunter", "Durotar Tiger", "Flatland Cougar", "Moonstalker Runt"}
        or level < 32 and {"Greater Fleshripper"} or level < 48 and {"Salt Flats Vulture"} or {"Ironbeak Owl"}
    if faction=="Horde" and level>=16 and level<32 then names={"Durotar Tiger","Flatland Cougar"} end
    return {unlocked=level >= 10, abilities=abilities, categories=categories,
        pets=filter(data.starters, function(pet)
            return contains(names, pet.name) and pet.minLevel <= level and P.SourceMatchesFaction(pet,faction)
        end)}
end
function P.WarlockPlan(level) return D.Presentation.warlockPlans[level] end
function P.QuiverPlan(level)
    local result = {}
    for _, tier in ipairs(D.Presentation.quiverTiers) do
        if tier.level <= level then result.current = tier elseif not result.next then result.next = tier end
    end
    return result
end
function P.NormalizeProfile(profile)
    profile = type(profile) == "table" and profile or {}
    local level = profile.level
    return {characterClass=contains(P.classes, profile.characterClass) and profile.characterClass or "Hunter",
        level=type(level) == "number" and level == math.floor(level) and level >= 1 and level <= 60 and level or 1,
        detailed=profile.detailed == true, mode=profile.mode == "preview" and "preview" or "live"}
end
