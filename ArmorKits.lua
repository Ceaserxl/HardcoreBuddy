-- Read the permanent enchant field, not localized tooltip text. Never replace
-- an unrelated enchant or treat unavailable item data as unenhanced armor.
local _, A = ...
local K={}; A.ArmorKits=K
local slots={{5,"Chest"},{7,"Legs"},{10,"Gloves"},{8,"Boots"}}
local byEnchant={}
for _,kit in ipairs(A.Data.ArmorKits.items) do byEnchant[kit.enchantId]=kit end
local function copy(item)
    local result={}; for key,value in pairs(item) do result[key]=value end; return result
end
function K.Best(level,gearLevel)
    local best
    for _,kit in ipairs(A.Data.ArmorKits.items) do
        if not kit.defenseKit and level>=kit.level and gearLevel>=kit.gearLevel
            and (not best or kit.power>best.power) then best=kit end
    end
    return best
end
function K.Read(level)
    local result={slots={},unknown=0,upgrades=0,empty=0,enchanted=0,equipped=0}
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    for _,slot in ipairs(slots) do
        local row={slotId=slot[1],name=slot[2],status="unknown"}
        result.slots[#result.slots+1]=row
        if GetInventoryItemID and GetInventoryItemLink and info then
            local id=GetInventoryItemID("player",slot[1])
            if not id or id==0 then row.status="empty" else
                result.equipped=result.equipped+1
                row.itemId=id
                local link=GetInventoryItemLink("player",slot[1])
                local linkedId,enchant
                if type(link)=="string" then linkedId,enchant=link:match("item:(%d+):([^:]*):") end
                local enchantId=enchant=="" and 0 or tonumber(enchant)
                if tonumber(linkedId)==id and enchantId and enchantId>=0 and enchantId==math.floor(enchantId) then
                    local _,_,_,itemLevel=info(link)
                    if type(itemLevel)=="number" and itemLevel>0 and itemLevel<math.huge then
                        row.itemLevel,row.enchantId=itemLevel,enchantId
                        row.current=byEnchant[enchantId]
                        local best=K.Best(level,itemLevel)
                        if enchantId~=0 and (not row.current or row.current.defenseKit) then
                            row.status="enchanted"; result.enchanted=result.enchanted+1
                        elseif best and (not row.current or best.power>row.current.power) then
                            row.recommendation=best
                            row.status=row.current and "upgrade" or "unenhanced"
                            local key=row.current and "upgrades" or "empty"; result[key]=result[key]+1
                        else row.status="current" end
                    end
                end
            end
        end
        if row.status=="unknown" then result.unknown=result.unknown+1 end
    end
    return result
end
function K.Recommendations(context)
    if type(context.level)~="number" or context.level~=context.level or context.level<1 or context.level>60
        or context.level~=math.floor(context.level) then return {},nil end
    if context.mode=="preview" then
        local item=copy(K.Best(context.level,math.huge))
        item.kitTargets="Planning only: equipped armor is not checked. Match the kit to the piece's item level before applying it."
        item.recommendedTarget=1
        return {item},nil
    end
    local scan=K.Read(context.level)
    local planned=A.Enchants and A.Enchants.PlannedSlots(context) or {}
    local comparisons={}
    if A.Enchants then for _,g in ipairs(A.Enchants.Scan(context)) do comparisons[g.slotId]=g end end
    local items,groups={},{}
    for _,slot in ipairs(scan.slots) do
        local kit=slot.recommendation
        local compared=comparisons[slot.slotId]
        if compared and compared.status~="unknown" then
            kit=compared.needed and compared.recommendation and compared.recommendation.armorKit and compared.recommendation or nil
        end
        if kit and not planned[slot.slotId] then
            if not groups[kit.itemId] then
                local item=copy(kit); item.targetSlots={}; item.targetDetails={}; item.recommendedTarget=0
                items[#items+1]=item; groups[kit.itemId]=item
            end
            local item=groups[kit.itemId]
            item.recommendedTarget=item.recommendedTarget+1
            item.targetSlots[#item.targetSlots+1]=slot.name
            item.targetDetails[#item.targetDetails+1]=slot.name.." (item level "..slot.itemLevel.."): "
                ..(slot.current and (slot.current.name.." (+"..slot.current.power..(slot.current.defenseKit and " defense)" or " armor)")) or "No permanent enhancement")
                .." -> "..kit.name.." (+"..kit.power..(kit.defenseKit and " defense)." or " armor).")
        end
    end
    for _,item in ipairs(items) do
        item.short="+"..item.power..(item.defenseKit and " defense: " or " armor: ")..table.concat(item.targetSlots,", ")
        item.kitTargets=table.concat(item.targetDetails,"\n")
    end
    return items,scan
end
function K.DetailItem(context,item)
    for _,current in ipairs(K.Recommendations(context)) do
        if current.itemId==item.itemId then return current end
    end
    local detail=copy(item)
    detail.recommendedTarget=0
    detail.kitTargets="No currently verified equipped piece needs this kit. "..K.Summary(context)
    return detail
end
function K.Summary(context)
    if context.mode=="preview" then return "Armor kits: planning by character level; equipped armor is not checked." end
    local _,scan=K.Recommendations(context)
    if not scan then return "Armor kit check unavailable: character level unknown." end
    local parts={}
    if scan.upgrades>0 then parts[#parts+1]=scan.upgrades.." older kit"..(scan.upgrades==1 and "" or "s").." to upgrade" end
    if scan.empty>0 then parts[#parts+1]=scan.empty.." unenhanced piece"..(scan.empty==1 and "" or "s") end
    if scan.enchanted>0 then parts[#parts+1]=scan.enchanted.." existing enchant"..(scan.enchanted==1 and "" or "s").." kept" end
    if scan.unknown>0 then parts[#parts+1]="waiting for "..scan.unknown.." item check"..(scan.unknown==1 and "" or "s") end
    if #parts==0 then return scan.equipped==0 and "Armor kits: no armor equipped in the supported slots."
        or "Armor kits: equipped armor already has suitable kits." end
    return "Armor kits: "..table.concat(parts,"; ").."."
end
