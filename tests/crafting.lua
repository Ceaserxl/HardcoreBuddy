local A=TestAddon
local C=A.Crafting
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function contains(value,needle) return type(value)=="string" and value:find(needle,1,true)~=nil end
local byId={}
for _,item in ipairs(A.Data.Items.items) do byId[item.itemId]=item end
local function info(id,faction) return C.GetInfo(byId[id],{faction=faction or "Alliance",characterLevel=20,level=60}) end

local coverage,crafts,classes,poisons,plain=0,0,0,0,0
for id,item in pairs(byId) do
    local result=C.GetInfo(item,{faction="Horde"})
    coverage=coverage+1
    check(type(result.craftable)=="boolean","Every catalog item has an explicit reviewed crafting classification: "..id)
    check(type(result.finishedAHText)=="string","Every catalog item distinguishes finished-item AH eligibility: "..id)
    if result.craftKind=="classSpell" then classes=classes+1
    elseif result.craftKind=="poison" then poisons=poisons+1
    elseif result.craftable then
        crafts=crafts+1
        check(result.skill>0 and result.profession and result.professionRank,"Every profession recipe has skill and rank: "..id)
        check(type(result.ahEligible)=="boolean" and result.recipeSource and result.recipeKind~="unknown","Every current profession recipe has reviewed acquisition and recipe AH status: "..id)
    else plain=plain+1 end
end
check(coverage==120 and crafts==89 and classes==9 and poisons==1 and plain==21,"Coverage includes all 120 unique catalog items and distinguishes profession/class/poison creation")
local greater=info(8951)
check(greater.skill==195 and greater.profession=="Alchemy","Greater Defense shows exact Alchemy195 crafting requirement")
check(greater.professionRank=="Expert" and greater.rankSkill==125 and greater.rankLevel==20,"Greater Defense separates Expert training125/character20 from recipe195")
check(greater.recipeKind=="trainer" and contains(greater.recipeSource,"an Alchemy trainer"),"Greater Defense shows its trainer acquisition")
check(not greater.recipeItemId and greater.ahEligible==false and contains(greater.recipeAHText,"No recipe item"),"Trainer recipe never becomes an AH recipe")
check(contains(greater.finishedAHText,"Tradable finished item"),"Trainer-only acquisition does not prohibit trading the finished elixir")
local restorative=info(9030)
check(restorative.skill==215 and restorative.professionRank=="Expert" and restorative.rankLevel==20,"Restorative correctly requires215, not225 or its item use level32")
check(restorative.questLevel==40 and contains(restorative.recipeSource,"Ghak Healtouch") and contains(restorative.recipeSource,"level 40"),"Restorative separates actual quest access40 from profession rank20")
check(contains(info(9030,"Horde").recipeSource,"Jarkal Mossmeld") and not contains(info(9030,"Horde").recipeSource,"Ghak"),"Restorative quest route follows actual faction")
local unknown=C.GetInfo(byId[9030],{level=60})
check(contains(unknown.recipeSource,"Faction unavailable") and not contains(unknown.recipeSource,"Ghak") and not contains(unknown.recipeSource,"Jarkal"),"Unknown faction suppresses Restorative quest givers")
check(not restorative.recipeItemId and restorative.ahEligible==false and contains(restorative.recipeAHText,"quest teaches"),"Restorative is learned directly; no fictitious tradable recipe")
check(contains(restorative.finishedAHText,"Tradable"),"Restorative finished potion remains tradable")
check(info(13444).ahEligible==false and contains(info(13444).recipeAHText,"binds when picked up"),"Major Mana recipe is bound despite its tradable finished potion")
check(info(18254).ahEligible==false and contains(info(18254).recipeSource,"Pusillin"),"Runn Tum recipe is a bound dungeon drop")
check(info(20008).ahEligible==false and contains(info(20008).recipeSource,"Exalted"),"Living Action uses the bound Zandalar Exalted recipe")
check(info(20004).ahEligible==false and contains(info(20004).recipeSource,"Honored"),"Major Troll's Blood uses the bound Zandalar Honored recipe")
check(info(19440).ahEligible==false and contains(info(19440).recipeSource,"Argent Dawn - Honored"),"Powerful Anti-Venom retains reputation and recipe binding")
check(info(2459).recipeItemId==2555 and info(2459).ahEligible and contains(info(2459).recipeSource,"Recipe: Swiftness Potion"),"Tradable world-drop recipes are named explicitly")
check(info(21023).ahEligible and contains(info(21023).recipeSource,"Scepter"),"Quest reward recipes can be tradable even when direct quest teaching is not")
check(contains(info(13446).recipeSource,"Evie Whirlbrew") and info(13446).recipeKind=="vendor","Major Healing has a verified neutral limited-stock vendor")
check(contains(info(13443,"Alliance").recipeSource,"Ulthir") and not contains(info(13443,"Alliance").recipeSource,"Algernon"),"Existing faction acquisition rules override mixed vendor text")
check(contains(info(13935,"Horde").recipeSource,"Sheendra") and not contains(info(13935,"Horde").recipeSource,"Vivianna"),"Baked Salmon filters structured vendors by actual faction")
check(not contains(C.GetInfo(byId[13935],{}).recipeSource,"Sheendra"),"Unknown faction does not assume a vendor is neutral")
check(contains(info(14530,"Horde").recipeSource,"Gregory Victor") and contains(info(14530).rankText,"Triage"),"Artisan bandage shows its actual doctor and training quest")
check(info(6451).professionRank=="Expert" and info(6451).rankLevel==0 and contains(info(6451).rankText,"Expert skill book"),"Expert First Aid book does not inherit primary profession character20")
check(info(13931).rankLevel==35 and contains(info(13931).rankText,"Clamlette Surprise"),"High Cooking recipes show Artisan quest and character35")
check(info(20452).questLevel==54 and contains(info(20452).recipeSource,"Sharing the Knowledge"),"Desert Dumplings recipe quest is distinguished from Artisan training")
check(info(16023).rankSkill==200 and info(16023).rankLevel==35,"Artisan Engineering training requires200 and character35")
check(info(5512).craftKind=="classSpell" and not info(5512).professionRank and contains(info(5512).finishedAHText,"conjured"),"Warlock conjurations are not presented as profession recipes or AH stock")
check(info(5514).learnLevel==28 and info(5514).materials=="No reagent required.","Mana Agate uses spell learning level and no fictional crafting material")
check(info(5530).skill==nil and info(5530).rankLevel==34 and contains(info(5530).craftingText,"Rogue Poisons"),"Blinding Powder uses the character34 class ability; difficulty170 is not a crafting prerequisite")
check(not info(117).craftable and not info(5140).craftable,"Vendor food and Flash Powder are not incorrectly marked craftable")
check(contains(restorative.tradeNote,"not checked") and contains(restorative.tradeNote,"Self Found"),"AH facts never claim a live listing or Self Found access")
check(C.GetInfo({itemId=999999},{}).craftable==nil,"An unreviewed future item is unknown rather than falsely noncraftable")
print("PASS: "..checks.." crafting catalog checks cover all items, exact skill/rank requirements, recipe binding, faction sources and separate finished-item AH eligibility.")
