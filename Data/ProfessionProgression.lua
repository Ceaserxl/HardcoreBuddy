-- Classic Era acquisition and training steps. Research links live in developer
-- provenance; AH eligibility describes tradability, never current listings.
local _, addon = ...
addon.Data = addon.Data or {}
local D = {}
addon.Data.ProfessionProgression = D

D.firstAidVendors = {
    Alliance={name="Deneb Walker",npcId=2805,place="Stromgarde Keep, Arathi Highlands"},
    Horde={name="Balai Lok'Wein",npcId=13476,place="Brackenwall Village, Dustwallow Marsh"},
}
D.cookingVendors = {
    Alliance={name="Shandrina",npcId=3955,place="Silverwind Refuge, Ashenvale"},
    Horde={name="Wulan",npcId=12033,place="Shadowprey Village, Desolace"},
}
D.doctors = {
    Alliance={name="Doctor Gustaf VanHowzen",npcId=12939,place="Theramore, Dustwallow Marsh",questId=6624,
        introduction="Alliance Trauma",introductionId=6625,guide="Nissa Firestone in Ironforge"},
    Horde={name="Doctor Gregory Victor",npcId=12920,place="Hammerfall, Arathi Highlands",questId=6622,
        introduction="Horde Trauma",introductionId=6623,guide="Arnok in Orgrimmar"},
}
D.cookingIntroductions = {
    Alliance={name="I Know A Guy...",questId=6612,guide="Daryl Riknussun in Ironforge"},
    Horde={name="To Gadgetzan You Go!",questId=6611,guide="Zamja in Orgrimmar"},
}

-- Indexed by learned crafting spell, not the consumable's use spell.
D.recipes = {
    [3275]={name="Linen Bandage",kind="trainer"},
    [3276]={name="Heavy Linen Bandage",kind="trainer"},
    [3277]={name="Wool Bandage",kind="trainer"},
    [3278]={name="Heavy Wool Bandage",kind="trainer"},
    [7928]={name="Silk Bandage",kind="trainer"},
    [7929]={name="Heavy Silk Bandage",kind="book",recipeItemId=16112,
        recipeName="Manual: Heavy Silk Bandage",ahEligible=true,vendors="firstAidVendors"},
    [10840]={name="Mageweave Bandage",kind="book",recipeItemId=16113,
        recipeName="Manual: Mageweave Bandage",ahEligible=true,vendors="firstAidVendors"},
    [10841]={name="Heavy Mageweave Bandage",kind="doctor"},
    [18629]={name="Runecloth Bandage",kind="doctor"},
    [18630]={name="Heavy Runecloth Bandage",kind="doctor"},
    [7934]={name="Anti-Venom",kind="trainer"},
    [7935]={name="Strong Anti-Venom",kind="book",recipeItemId=6454,
        recipeName="Manual: Strong Anti-Venom",ahEligible=true,acquisition="World-drop manual; check player trade or the Auction House."},
    [23787]={name="Powerful Anti-Venom",kind="book",recipeItemId=19442,
        recipeName="Formula: Powerful Anti-Venom",ahEligible=false,binding="pickup",
        acquisition="Buy from an Argent Dawn quartermaster. Requires Honored with the Argent Dawn."},
    [3932]={name="Target Dummy",kind="trainer"},
    [3965]={name="Advanced Target Dummy",kind="trainer"},
    [19814]={name="Masterwork Target Dummy",kind="book",recipeItemId=16046,
        recipeName="Schematic: Masterwork Target Dummy",ahEligible=true,
        acquisition="Buy from Xizzer Fizzbolt in Everlook, Winterspring (limited vendor stock), or check player trade / the Auction House."},
}
D.training = {
    bandage={
        {name="Journeyman First Aid",skill=50,cap=150,kind="trainer"},
        {name="Expert First Aid",skill=125,cap=225,kind="book",recipeItemId=16084,
            recipeName="Expert First Aid - Under Wraps",ahEligible=true,vendors="firstAidVendors"},
        {name="Artisan First Aid",skill=225,level=35,cap=300,kind="triage"},
    },
    dummy={
        {name="Journeyman Engineering",skill=50,level=10,cap=150,kind="trainer"},
        {name="Expert Engineering",skill=125,level=20,cap=225,kind="trainer"},
        {name="Artisan Engineering",skill=200,level=35,cap=300,kind="trainer",
            acquisition="Train with Buzzek Bracketswing in Gadgetzan, Tanaris. Target dummies do not require a Gnomish or Goblin specialization."},
    },
    cooking={
        {name="Journeyman Cooking",skill=50,level=10,cap=150,kind="trainer"},
        {name="Expert Cooking",skill=125,cap=225,kind="book",recipeItemId=16072,
            recipeName="Expert Cookbook",ahEligible=true,vendors="cookingVendors"},
        {name="Artisan Cooking",skill=225,level=35,cap=300,kind="clamlette",questId=6610},
    },
}
