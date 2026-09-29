-- Reviewed acquisition restrictions. Tradable food is not faction-locked.
-- Home-zone affinity is only for routine Hunter routes, never creature taming.
local _, addon = ...
addon.Data = addon.Data or {}
addon.Data.FactionRules = {
    exclusiveItems = {[4941]="Horde", [3434]="Horde", [5816]="Alliance", [3604]="Alliance", [3605]="Alliance"},
    acquisition = {
        [1082]={
            Alliance="Learn the recipe from Kendor Kabonka in Stormwind or the Redridge Goulash quest. Gather the two required meats.",
            other="Obtain the finished food through trading where allowed. No local recipe vendor is listed for your faction.",
        },
        [2682]={
            Alliance="Buy the recipe from Kendor Kabonka in Stormwind, then gather Crawler Claws.",
            other="Obtain the finished food through trading where allowed. No local recipe vendor is listed for your faction.",
        },
        [20074]={
            Horde="Buy the recipe from Ogg'marr at Brackenwall Village in Dustwallow Marsh. Gather Tender Crocolisk Meat.",
            other="Obtain the finished food through trading where allowed. No local recipe vendor is listed for your faction.",
        },
        [3726]={
            Alliance="Buy the recipe from Super-Seller 680 in Desolace or Ulthaan in Ashenvale. Gather Big Bear Meat.",
            Horde="Buy the recipe from Super-Seller 680 in Desolace. Gather Big Bear Meat.",
            neutral="Buy the recipe from Super-Seller 680 in Desolace. Gather Big Bear Meat.",
        },
        [3665]={
            Alliance="Buy the recipe from Kendor Kabonka in Stormwind. Gather Raptor Eggs.",
            Horde="Buy the recipe from Keena or Nerrist. Gather Raptor Eggs.",
            other="Obtain the recipe or finished food through trading where allowed. Faction vendors appear when your faction is known.",
        },
        [12210]={
            Alliance="Buy the recipe from Corporal Bluth in Stranglethorn Vale. Gather Raptor Flesh.",
            Horde="Buy the recipe from Nerrist in Stranglethorn Vale. Gather Raptor Flesh.",
            other="Obtain the recipe or finished food through trading where allowed. Faction vendors appear when your faction is known.",
        },
        [12212]={
            Alliance="Buy the recipe from Corporal Bluth in Stranglethorn Vale. Gather Tiger Meat and the vendor ingredients.",
            Horde="Buy the recipe from Nerrist in Stranglethorn Vale. Gather Tiger Meat and the vendor ingredients.",
            other="Obtain the recipe or finished food through trading where allowed. Faction vendors appear when your faction is known.",
        },
        [12218]={
            Alliance="Buy the recipe from Himmik in Everlook or Malygen in Felwood. Gather Giant Eggs.",
            Horde="Buy the recipe from Himmik in Everlook or Bale in Felwood. Gather Giant Eggs.",
            neutral="Buy the recipe from Himmik in Everlook. Gather Giant Eggs.",
        },
        [13443]={
            Alliance="Buy the limited-stock recipe from Ulthir in Darnassus, then craft the potion.",
            Horde="Buy the limited-stock recipe from Algernon in Undercity, then craft the potion.",
            other="Obtain the finished potion through trading where allowed. Faction vendors appear when your faction is known.",
        },
        [5634]={
            Alliance="Buy the recipe from Soolie Berryfizz in Ironforge, then craft the potion.",
            Horde="Buy the recipe from Kor'geld in Orgrimmar, then craft the potion.",
            other="Obtain the finished potion through trading where allowed. Faction vendors appear when your faction is known.",
        },
    },
    routineZones = {
        ["Dun Morogh"]="Alliance", ["Elwynn Forest"]="Alliance", ["Teldrassil"]="Alliance",
        ["Darkshore"]="Alliance", ["Westfall"]="Alliance", ["Loch Modan"]="Alliance",
        ["Redridge Mountains"]="Alliance", ["Duskwood"]="Alliance",
        ["Durotar"]="Horde", ["Mulgore"]="Horde", ["Tirisfal Glades"]="Horde",
        ["The Barrens"]="Horde", ["Silverpine Forest"]="Horde",
    },
}
