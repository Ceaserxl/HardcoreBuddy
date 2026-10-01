-- Suggested questing bands, not the level span of every creature in the zone.
-- Classic faction leveling routes; sources and scope: docs/leveling-zones.md.
local _,A=...
A.Data.LevelingZones={
    {map=1429,Alliance={1,10}}, -- Elwynn
    {map=1426,Alliance={1,10}}, -- Dun Morogh
    {map=1438,Alliance={1,10}}, -- Teldrassil
    {map=1411,Horde={1,10}}, -- Durotar
    {map=1412,Horde={1,10}}, -- Mulgore
    {map=1420,Horde={1,10}}, -- Tirisfal
    {map=1436,Alliance={10,20}}, -- Westfall
    {map=1432,Alliance={10,20}}, -- Loch Modan
    {map=1439,Alliance={10,20}}, -- Darkshore
    {map=1421,Horde={10,20}}, -- Silverpine
    {map=1413,Horde={10,30}}, -- Barrens
    {map=1433,Alliance={20,25}}, -- Redridge
    {map=1440,Alliance={20,25},Horde={25,30}}, -- Ashenvale
    {map=1442,Alliance={20,25},Horde={20,30}}, -- Stonetalon
    {map=1437,Alliance={25,30}}, -- Wetlands
    {map=1431,Alliance={25,30}}, -- Duskwood
    {map=1424,both={25,30}}, -- Hillsbrad
    {map=1434,both={30,35},part="North"}, -- Stranglethorn
    {map=1441,both={30,35}}, -- Thousand Needles
    {map=1443,both={35,40}}, -- Desolace
    {map=1417,both={35,40}}, -- Arathi
    {map=1434,both={40,45},part="South"},
    {map=1418,both={40,45}}, -- Badlands
    {map=1445,both={40,45}}, -- Dustwallow
    {map=1446,both={45,50}}, -- Tanaris
    {map=1425,both={45,50}}, -- Hinterlands
    {map=1444,both={45,50}}, -- Feralas
    {map=1427,both={45,50}}, -- Searing Gorge
    {map=1419,both={50,55}}, -- Blasted Lands
    {map=1449,both={50,55}}, -- Un'Goro
    {map=1447,both={50,55}}, -- Azshara
    {map=1448,both={50,55}}, -- Felwood
    {map=1452,both={55,60}}, -- Winterspring
    {map=1428,both={55,60}}, -- Burning Steppes
    {map=1422,both={55,60}}, -- Western Plaguelands
    {map=1423,both={55,60}}, -- Eastern Plaguelands
}
