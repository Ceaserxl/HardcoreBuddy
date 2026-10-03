-- Reviewed Classic Era additions. Sources and scope: docs/supply-catalog.md.
-- Each row supplies the item, recipe and effect model together.
local _,A=...
local D=A.Data
local physical={"Warrior","Rogue","Hunter","Druid","Paladin","Shaman"}
local casters={"Mage","Warlock","Priest","Druid","Shaman","Paladin"}
local function add(id,name,level,family,classes,effect,skill,spell,recipe,reagents,buff)
    local row={id="supply-"..id,itemId=id,name=name,displayName=name,level=level,
        family=family,classes=classes or {"All"},group="Potions & elixirs",ease=2,
        short=effect,detail=effect,icon="Interface\\Icons\\INV_Potion_43",
        craftSkill={name="Alchemy",value=skill},maxStack=5,
        route="Alchemy; craft with a learned recipe or buy from another player.",
        caution="Optional preparation; choose effects for your build and encounter."}
    D.Items.items[#D.Items.items+1]=row
    D.Crafting.items[id]={craftable=true,profession="Alchemy",skill=skill,spellId=spell,
        recipeItemId=recipe,recipeName=recipe and ("Recipe: "..name),
        recipeKind=recipe and "recipe" or "trainer",
        recipeSource=recipe and ("Learn Recipe: "..name..".") or "Learn from an Alchemy trainer.",ahEligible=true}
    D.AuctionRecipes[id]={spellId=spell,output=1,reagents=reagents}
    if buff then
        D.ConsumableBuffs.items[id]=buff
        D.ConsumableBuffs.auras[buff.aura]=buff
    end
end
add(13452,"Elixir of the Mongoose",46,"agility",physical,"+25 Agility, +2% critical strike / 1 hr",
    280,17571,13491,{{13465,2},{13466,2},{8925,1}},
    {aura=17538,group="agility",power=25,effects={agility=25,crit=2}})
add(9155,"Arcane Elixir",37,"spellpower",casters,"+20 spell damage / 30 min",
    235,11461,nil,{{8839,1},{3821,1},{8925,1}},{aura=11390,group="spellPower",power=20})
add(13454,"Greater Arcane Elixir",47,"spellpower",casters,"+35 spell damage / 1 hr",
    285,17573,13493,{{13463,3},{13465,1},{8925,1}},{aura=17539,group="spellPower",power=35})
add(6373,"Elixir of Firepower",18,"firepower",{"Mage","Warlock"},"+10 Fire damage / 30 min",
    140,7845,nil,{{6371,2},{3356,1},{3372,1}},{aura=7844,group="fire",power=10})
add(21546,"Elixir of Greater Firepower",40,"firepower",{"Mage","Warlock"},"+40 Fire damage / 30 min",
    250,26277,21547,{{6371,3},{4625,3},{8925,1}},{aura=26276,group="fire",power=40})
add(3386,"Elixir of Poison Resistance",14,"poison-resistance",nil,"Cures up to 4 poisons (Lvl 60 or lower)",
    120,3174,3394,{{1288,1},{2453,1},{3372,1}})

-- Absorption potions are encounter preparation, not automatic persistent-buff
-- reminders. Their shared potion cooldown must not encourage routine use.
local function protection(id,name,level,school,low,high,skill,spell,recipe,reagents)
    add(id,name,level,"protection-"..school,nil,
        "Absorbs "..low.."-"..high.." "..school.." damage / 1 hr",skill,spell,recipe,reagents)
    D.Items.items[#D.Items.items].power=(low+high)/2
end
protection(6051,"Holy Protection Potion",10,"holy",300,500,100,7255,6053,{{2453,1},{2452,1},{3371,1}})
protection(6048,"Shadow Protection Potion",17,"shadow",675,1125,135,7256,6054,{{3369,1},{3356,1},{3372,1}})
protection(6049,"Fire Protection Potion",23,"fire",975,1625,165,7257,6055,{{4402,1},{6371,1},{3372,1}})
protection(6050,"Frost Protection Potion",28,"frost",1350,2250,190,7258,6056,{{3819,1},{3821,1},{3372,1}})
protection(6052,"Nature Protection Potion",28,"nature",1350,2250,190,7259,6057,{{3357,1},{3820,1},{3372,1}})
protection(13457,"Greater Fire Protection Potion",48,"fire",1950,3250,290,17574,13494,{{7068,1},{13463,1},{8925,1}})
protection(13456,"Greater Frost Protection Potion",48,"frost",1950,3250,290,17575,13495,{{7070,1},{13463,1},{8925,1}})
protection(13458,"Greater Nature Protection Potion",48,"nature",1950,3250,290,17576,13496,{{7067,1},{13463,1},{8925,1}})
protection(13461,"Greater Arcane Protection Potion",48,"arcane",1950,3250,290,17577,13497,{{11176,1},{13463,1},{8925,1}})
protection(13459,"Greater Shadow Protection Potion",48,"shadow",1950,3250,290,17578,13499,{{3824,1},{13463,1},{8925,1}})

D.AuctionRecipes[5530]={spellId=6510,output=1,reagents={{3818,1,"Fadeleaf"}}}
D.Crafting.items[5530].skill=150
