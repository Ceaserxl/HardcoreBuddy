local _, addon = ...
local C = {}
addon.Crafting = C

local ranks = {
    Leatherworking={{"Apprentice",75,0,5},{"Journeyman",150,50,10},{"Expert",225,125,20},{"Artisan",300,200,35}},
    Alchemy={{"Apprentice",75,0,5},{"Journeyman",150,50,10},{"Expert",225,125,20},{"Artisan",300,200,35}},
    Engineering={{"Apprentice",75,0,5},{"Journeyman",150,50,10},{"Expert",225,125,20},{"Artisan",300,200,35}},
    Cooking={{"Apprentice",75,0,5},{"Journeyman",150,50,10},{"Expert",225,125,0},{"Artisan",300,225,35}},
    ["First Aid"]={{"Apprentice",75,0,0},{"Journeyman",150,50,0},{"Expert",225,125,0},{"Artisan",300,225,35}},
}

local function routeFor(routes,faction)
    if faction=="Alliance" or faction=="Horde" then return routes[faction] or routes.neutral or routes.other end
    return routes.neutral or routes.unknown or routes.other
end

local function acquisition(row,item,context)
    local faction=context.faction
    if row.recipeRoutes then return routeFor(row.recipeRoutes,faction) end
    local rules=addon.Data.FactionRules
    local routes=rules and rules.acquisition and rules.acquisition[item.itemId]
    if routes then return routeFor(routes,faction) or "Faction unavailable; the faction-specific recipe route is hidden." end
    if row.recipeKind=="doctor" then
        local progression=addon.Data.ProfessionProgression
        local doctor=progression and progression.doctors and routeFor(progression.doctors,faction)
        return doctor and ("Learn from "..doctor.name.." in "..doctor.place.." after completing Triage.")
            or "Faction unavailable; the faction-specific First Aid doctor is hidden. Complete Triage before learning this recipe."
    end
    if row.vendors then
        local vendors={}
        for _,vendor in ipairs(row.vendors) do
            if not vendor.faction or vendor.faction==faction then
                vendors[#vendors+1]=vendor.name..(vendor.zone and (" in "..vendor.zone) or "")
                if #vendors==2 then break end
            end
        end
        if #vendors>0 then return "Buy "..(row.recipeName or "the recipe").." from "..table.concat(vendors," or ").."." end
        return (faction=="Alliance" or faction=="Horde") and "No recipe vendor for your faction is listed. Obtain a tradable recipe through trade where allowed."
            or "Faction unavailable; the faction-specific recipe vendors are hidden."
    end
    return row.recipeSource
end

-- Descriptive facts only: crafting requirements are distinct from item use
-- requirements, and AH eligibility never reports a live Auction House listing.
function C.GetInfo(item,context)
    item=item or {};context=context or {}
    local catalog=addon.Data.Crafting
    local row=(catalog and catalog.items and catalog.items[item.itemId]) or item.crafting
    if not row then return {craftable=nil,craftingText="Crafting information unavailable."} end
    local result={}
    for key,value in pairs(row) do result[key]=value end
    result.tradeNote="AH listings are not checked. Self Found cannot use the Auction House or player trading."
    if row.craftKind=="classSpell" then
        result.craftingText=row.className.." conjuration"
        result.rankText=row.className.." character level "..row.learnLevel.." to learn this spell rank."
        result.recipeAHText="No recipe item; learned as a class spell."
        result.finishedAHText="Unavailable: conjured item."
    elseif row.craftable then
        result.craftingText=row.craftKind=="poison" and "Rogue Poisons ability (recipe must be learned)"
            or (row.profession.." "..row.skill.." (recipe must be learned)")
        if row.craftKind=="poison" then
            result.rankText="Rogue character level "..row.rankLevel.." to train this recipe; requires the Poisons ability."
        else
            for _,rank in ipairs(ranks[row.profession] or {}) do
                if row.skill<=rank[2] then
                    result.professionRank=rank[1];result.rankSkill=rank[3];result.rankLevel=rank[4]
                    result.rankText=rank[1].." "..row.profession
                        ..(rank[3]>0 and (" - train at skill "..rank[3]) or " - initial training")
                        ..(rank[4]>0 and (", character level "..rank[4]) or "; no additional character-level requirement")
                    if rank[1]=="Expert" and (row.profession=="Cooking" or row.profession=="First Aid") then
                        result.rankText=result.rankText..". Learn the Expert skill book."
                    elseif rank[1]=="Artisan" and row.profession=="Cooking" then
                        result.rankText=result.rankText..". Complete Clamlette Surprise."
                    elseif rank[1]=="Artisan" and row.profession=="First Aid" then
                        result.rankText=result.rankText..". Complete Triage."
                    end
                    break
                end
            end
        end
        if row.recipeItemId then
            if row.ahEligible==true then result.recipeAHText="Tradable recipe; may be sold at the AH."
            elseif row.ahEligible==false then result.recipeAHText="Unavailable: recipe binds when picked up."
            else result.recipeAHText="Recipe tradability has not been verified." end
        elseif row.recipeKind=="quest" then result.recipeAHText="Unavailable: the quest teaches the recipe directly."
        elseif row.recipeKind=="unknown" then result.recipeAHText="Recipe tradability has not been verified."
        else result.recipeAHText="No recipe item; learned from a trainer." end
        result.finishedAHText=item.binding==false and "Tradable finished item; may be sold at the AH."
            or item.binding==true and "Unavailable: finished item is bound." or "Finished-item tradability has not been verified."
    else
        result.craftingText="Not profession-crafted."
        result.finishedAHText=item.binding==false and "Tradable item; may be sold at the AH."
            or item.binding==true and "Unavailable: item is bound." or "Item tradability has not been verified."
    end
    result.recipeSource=acquisition(row,item,context)
    if row.restriction then result.recipeSource=(result.recipeSource or "").." "..row.restriction end
    result.materials=item.ingredients
    if row.craftable and not result.materials then
        result.materials=row.craftKind=="classSpell" and row.className=="Mage" and "No reagent required."
            or "Check the learned recipe for required materials."
    end
    result.ahText=(result.recipeAHText and ("Recipe: "..result.recipeAHText.." ") or "")..(result.finishedAHText or "")
    return result
end
