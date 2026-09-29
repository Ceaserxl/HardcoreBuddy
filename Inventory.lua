-- Carried supplies only: backpack, equipped bags and the Classic keyring.
-- Blizzard's Classic Container documentation defines itemID and stackCount on
-- C_Container.GetContainerItemInfo; no item-name cache or other addon is needed.
local _, addon = ...
local Inventory = {}
addon.Inventory = Inventory

local function integer(value, minimum)
    return type(value) == "number" and value == value and value < math.huge
        and value >= minimum and value == math.floor(value)
end

function Inventory.Read()
    local container = C_Container
    if type(container) ~= "table" or type(container.GetContainerNumSlots) ~= "function"
        or type(container.GetContainerItemInfo) ~= "function" then
        return {available=false, counts={}}
    end

    local countBags = NUM_BAG_SLOTS
    if not integer(countBags, 1) or countBags > 4 then countBags = 4 end
    local bags = {0}
    for bag = 1, countBags do bags[#bags + 1] = bag end
    local keyring = KEYRING_CONTAINER or (Enum and Enum.BagIndex and Enum.BagIndex.Keyring)
    if keyring == -2 then bags[#bags + 1] = keyring end

    local counts = {}
    for _, bag in ipairs(bags) do
        local ok, slots = pcall(container.GetContainerNumSlots, bag)
        if not ok or not integer(slots, 0) or (bag == 0 and slots == 0) then
            return {available=false, counts={}}
        end
        for slot = 1, slots do
            local readOK, info = pcall(container.GetContainerItemInfo, bag, slot)
            if not readOK then return {available=false, counts={}} end
            if info ~= nil then
                if type(info) ~= "table" or not integer(info.itemID, 1) or not integer(info.stackCount, 1) then
                    -- Do not publish a partial scan as an empty/missing supply.
                    return {available=false, counts={}}
                end
                counts[info.itemID] = (counts[info.itemID] or 0) + info.stackCount
            end
        end
    end
    return {available=true, counts=counts}
end
