-- Classic Era buff identities and actual stat amounts, verified 2026-10-02.
-- Sources and stacking boundaries: docs/consumable-buffs.md.
local _,A=...
local D={items={},auras={},eating={}}
A.Data.ConsumableBuffs=D

-- item ID, effect/aura ID, conflict group, amount, optional eating spell ID
local function item(id,aura,group,power,eating,foodType)
    D.items[id]={aura=aura,group=group,power=power,eating=eating,foodType=foodType}
    D.auras[aura]={group=group,power=power,foodType=foodType}
    if eating then D.eating[eating]=true end
end
item(6888,19705,"food",2,5004,"wellfed") -- Herb Baked Egg
item(2680,19705,"food",2,5004,"wellfed") -- Spiced Wolf Meat
item(5525,19706,"food",4,5005,"wellfed") -- Boiled Clams
item(2684,19706,"food",4,5005,"wellfed") -- Coyote Steak
item(2683,19706,"food",4,5005,"wellfed") -- Crab Cake
item(2687,19706,"food",4,5005,"wellfed") -- Dry Pork Ribs
item(1082,19708,"food",6,5006,"wellfed") -- Redridge Goulash
item(5527,19708,"food",6,5006,"wellfed") -- Goblin Deviled Clams
item(3726,19708,"food",6,5006,"wellfed") -- Big Bear Steak
item(3665,19708,"food",6,5006,"wellfed") -- Curiously Tasty Omelet
item(20074,19709,"food",8,5007,"wellfed") -- Heavy Crocolisk Stew
item(12210,19709,"food",8,5007,"wellfed") -- Roast Raptor
item(13851,19709,"food",8,5007,"wellfed") -- Hot Wolf Ribs
item(12212,19709,"food",8,5007,"wellfed") -- Jungle Stew
item(17222,19710,"food",12,10256,"wellfed") -- Spider Sausage
item(18045,19710,"food",12,10256,"wellfed") -- Tender Wolf Steak
item(12218,19710,"food",12,10256,"wellfed") -- Monster Omelet
item(21023,25661,"food",25,25660,"wellfed") -- Dirge's Kickin' Chimaerok Chops
item(21072,25694,"food",3,25690,"manafood") -- Smoked Sagefish
item(21217,25941,"food",6,25691,"manafood") -- Sagefish Delight
item(13931,18194,"food",8,18233,"manafood") -- Nightfin Soup
item(3382,3219,"trollsblood",2) -- Weak Troll's Blood Potion
item(3388,3222,"trollsblood",6) -- Strong Troll's Blood Potion
item(3826,3223,"trollsblood",12) -- Mighty Troll's Blood Potion
item(20004,24361,"trollsblood",20) -- Major Troll's Blood Potion
item(5997,673,"armor",50) -- Elixir of Minor Defense
item(3389,3220,"armor",150) -- Elixir of Defense
item(8951,11349,"armor",250) -- Elixir of Greater Defense
item(13445,11348,"armor",450) -- Elixir of Superior Defense
item(2458,2378,"health",27) -- Elixir of Minor Fortitude
item(3825,3593,"health",120) -- Elixir of Fortitude
item(2457,2374,"agility",4) -- Elixir of Minor Agility
item(3390,3160,"agility",8) -- Elixir of Lesser Agility
item(8949,11328,"agility",15) -- Elixir of Agility
item(9187,11334,"agility",25) -- Elixir of Greater Agility
item(2454,2367,"strength",4) -- Elixir of Lion's Strength
item(3391,3164,"strength",8) -- Elixir of Ogre's Strength
item(9206,11405,"strength",25) -- Elixir of Giants
item(3383,3166,"intellect",6) -- Elixir of Wisdom
item(9179,11396,"intellect",25) -- Elixir of Greater Intellect
item(3012,8115,"agility",5) -- Scroll of Agility
item(1477,8116,"agility",9) -- Scroll of Agility II
item(4425,8117,"agility",13) -- Scroll of Agility III
item(10309,12174,"agility",17) -- Scroll of Agility IV
item(954,8118,"strength",5) -- Scroll of Strength
item(2289,8119,"strength",9) -- Scroll of Strength II
item(4426,8120,"strength",13) -- Scroll of Strength III
item(10310,12179,"strength",17) -- Scroll of Strength IV
item(1180,8099,"stamina",4) -- Scroll of Stamina
item(1711,8100,"stamina",8) -- Scroll of Stamina II
item(4422,8101,"stamina",12) -- Scroll of Stamina III
item(10307,12178,"stamina",16) -- Scroll of Stamina IV
item(955,8096,"intellect",4) -- Scroll of Intellect
item(2290,8097,"intellect",8) -- Scroll of Intellect II
item(4419,8098,"intellect",12) -- Scroll of Intellect III
item(10308,12176,"intellect",16) -- Scroll of Intellect IV
item(1181,8112,"spirit",3) -- Scroll of Spirit
item(1712,8113,"spirit",7) -- Scroll of Spirit II
item(4424,8114,"spirit",11) -- Scroll of Spirit III
item(10306,12177,"spirit",15) -- Scroll of Spirit IV
item(3013,8091,"armor",60) -- Scroll of Protection
item(1478,8094,"armor",120) -- Scroll of Protection II
item(4421,8095,"armor",180) -- Scroll of Protection III
item(10305,12175,"armor",240) -- Scroll of Protection IV

-- Class buffs received from any player count, including their group versions.
local function aura(group,values)
    for id,power in pairs(values) do D.auras[id]={group=group,power=power} end
end
aura("intellect",{[1459]=2,[1460]=7,[1461]=15,[10156]=22,[10157]=31,[23028]=31})
aura("stamina",{[1243]=3,[1244]=8,[1245]=20,[2791]=32,[10937]=43,[10938]=54,[21562]=43,[21564]=54})
aura("spirit",{[14752]=17,[14818]=23,[14819]=33,[27841]=40,[27681]=40})
-- Compound consumables are recognized as active sources, not confused with Intellect.
D.auras[17535]={effects={intellect=18,spirit=18}} -- Elixir of the Sages
D.auras[17538]={group="agility",power=25,keep=true} -- Mongoose also grants critical strike
D.auras[17537]={effects={strength=18,stamina=18}} -- Brute Force
-- Other Classic food buffs must not be replaced by a weaker or unrelated food.
for _,id in ipairs({19711,18125,18191,18192,18193,22730,24799}) do
    D.auras[id]={group="food",power=0,keep=true}
end

D.classSpells={
    MAGE={intellect={ranks={1459,1460,1461,10156,10157}}},
    PRIEST={fortitude={ranks={1243,1244,1245,2791,10937,10938}},
        divineSpirit={ranks={14752,14818,14819,27841}}},
}
