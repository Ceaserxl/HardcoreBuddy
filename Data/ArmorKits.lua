-- Classic Era item/use-spell tooltips: reference/research/armor-kit-tooltips.json.
local _, A = ...
local rows={
    {2304,"Light Armor Kit",1,1,8,15,1,2152,"17","1 Light Leather"},
    {2313,"Medium Armor Kit",5,1,16,16,100,2165,"15","4 Medium Leather, 1 Coarse Thread"},
    {4265,"Heavy Armor Kit",20,15,24,17,150,3780,"16","5 Heavy Leather, 1 Fine Thread"},
    {8173,"Thick Armor Kit",30,25,32,18,200,10487,"07","5 Thick Leather, 1 Silken Thread"},
    {15564,"Rugged Armor Kit",40,35,40,1843,250,19058,"09","5 Rugged Leather"},
    {18251,"Core Armor Kit",50,45,3,2503,300,22727,"05","3 Core Leather, 2 Rune Thread"},
}
A.Data.ArmorKits={items={}}
local reagents={
    [2304]={{2318,1,"Light Leather"}},
    [2313]={{2319,4,"Medium Leather"},{2320,1,"Coarse Thread"}},
    [4265]={{4234,5,"Heavy Leather"},{2321,1,"Fine Thread"}},
    [8173]={{4304,5,"Thick Leather"},{4291,1,"Silken Thread"}},
    [15564]={{8170,5,"Rugged Leather"}},
    [18251]={{17012,3,"Core Leather"},{14341,2,"Rune Thread"}},
}
for _,r in ipairs(rows) do
    local defense=r[1]==18251
    local stat=defense and "defense" or "armor"
    local crafting={craftable=true,profession="Leatherworking",skill=r[7],spellId=r[8],
        recipeKind=defense and "drop" or "trainer",
        recipeSource=defense and "Pattern: Core Armor Kit drops in Molten Core and binds on pickup."
            or "Learn this recipe from a Leatherworking trainer."}
    if defense then crafting.recipeItemId=18252; crafting.ahEligible=false end
    local item={itemId=r[1],id="armor-kit-"..r[1],name=r[2],level=r[3],gearLevel=r[4],
        power=r[5],enchantId=r[6],armorKit=true,defenseKit=defense,
        family=defense and "armor-kit-defense" or "armor-kit",group="Armor kits",classes={"All"},ease=defense and 4 or 2,
        binding=false,icon="inv_misc_armorkit_"..r[9]..".jpg",ingredients=r[10],crafting=crafting,reagents=reagents[r[1]],
        short="+"..r[5].." "..stat.." on one armor piece",
        detail="Permanently adds "..r[5].." "..stat.." to chest armor, gloves, leggings or boots.",
        route="Craft with Leatherworking or obtain the finished kit through trading where allowed. Leatherworking is not required to apply it.",
        caution="An armor kit replaces the item's existing permanent enchant or armor kit. Apply one kit per piece; bonuses do not stack."
            ..(defense and " Defense is a different bonus from armor; this kit is not an automatic upgrade over an armor kit." or "")}
    A.Data.ArmorKits.items[#A.Data.ArmorKits.items+1]=item
end
