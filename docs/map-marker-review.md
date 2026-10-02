# Map marker provenance review - October 2, 2026

Audited all 46 maps and 1,085 NPC records. Published coordinate points changed from 6,447 to 3,267.

The old builder treated Wowhead encounter sightings as spawn positions. The new builder uses the pinned Questie Classic spawn and patrol database, including its coordinate corrections. Existing Wowhead caches are preserved. All four Nightmare Dragons retain their reviewed portal rotation.

164 old NPC/zone pin sets were removed or withheld. Of these, 70 NPCs previously had pins but now have no supported coordinates; their zone-list records remain. Removed or withheld does not mean every sighting was fabricated: transported creatures, events, patrols and incomplete source data can all produce disagreements.

70 NPC records currently have no verified outdoor coordinates. They produce no pins. Omen is retained in Moonglade only, based on the Classic Lunar Festival guide; exact event coordinates are awaiting supported spawn data.

## Sources

- [Classic spawn and patrol data](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicNpcDB.lua)
- [Classic coordinate corrections](https://github.com/Questie/Questie/blob/v10.0.0/Database/Corrections/classicNPCFixes.lua)
- [Omen event location](https://www.wowhead.com/classic/guide/lunar-festival-wow-classic)

## Removed or withheld old NPC/zone pin sets

| NPC | Zone | Old points | Reason |
|---|---|---:|---|
| Dark Iron Saboteur (1052) | Arathi Highlands | 1 | Unsupported historical zone |
| Voidwalker Minion (8996) | Arathi Highlands | 2 | Unsupported historical zone |
| Blackfathom Oracle (4803) | Ashenvale | 3 | Unsupported historical zone |
| Fallenroot Rogue (4789) | Ashenvale | 3 | Unsupported historical zone |
| Shade of Taerar (15302) | Ashenvale | 3 | Outdoor coordinates unverified |
| Bone Witch (16380) | Azshara | 12 | Outdoor coordinates unverified |
| Lumbering Horror (14697) | Azshara | 12 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Azshara | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Azshara | 11 | Outdoor coordinates unverified |
| Obsidian Golem (4872) | Badlands | 2 | Unsupported historical zone |
| Bone Witch (16380) | Blasted Lands | 12 | Outdoor coordinates unverified |
| Lumbering Horror (14697) | Blasted Lands | 12 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Blasted Lands | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Blasted Lands | 12 | Outdoor coordinates unverified |
| Bone Witch (16380) | Burning Steppes | 12 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Burning Steppes | 1 | Outdoor coordinates unverified |
| Expeditionary Mountaineer (14390) | Burning Steppes | 1 | Unsupported historical zone |
| Expeditionary Priest (14393) | Burning Steppes | 1 | Unsupported historical zone |
| Lumbering Horror (14697) | Burning Steppes | 12 | Outdoor coordinates unverified |
| Scarshield Grunt (9043) | Burning Steppes | 1 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Burning Steppes | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Burning Steppes | 12 | Outdoor coordinates unverified |
| Blackfathom Tide Priestess (4802) | Darkshore | 1 | Unsupported historical zone |
| Eroded Anubisath Warbringer (15810) | Darkshore | 10 | Outdoor coordinates unverified |
| Faltering Silithid Flayer (15811) | Darkshore | 7 | Outdoor coordinates unverified |
| Qiraji Officer (15812) | Darkshore | 5 | Outdoor coordinates unverified |
| Qiraji Officer Zod (15813) | Darkshore | 7 | Outdoor coordinates unverified |
| Voidwalker Minion (8996) | Darkshore | 1 | Unsupported historical zone |
| Jademir Boughguard (5320) | Desolace | 8 | Unsupported historical zone |
| Misha (10204) | Desolace | 12 | Unsupported historical zone |
| Hogger (448) | Dun Morogh | 1 | Unsupported historical zone |
| Hogger (448) | Durotar | 2 | Unsupported historical zone |
| Mammoth Shark (12125) | Durotar | 1 | Unsupported historical zone |
| Voidwalker Minion (8996) | Durotar | 2 | Unsupported historical zone |
| Shade of Taerar (15302) | Duskwood | 11 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Dustwallow Marsh | 1 | Outdoor coordinates unverified |
| The Rot (14235) | Dustwallow Marsh | 7 | Outdoor coordinates unverified |
| Bloodletter (10954) | Eastern Plaguelands | 2 | Outdoor coordinates unverified |
| Bone Witch (16380) | Eastern Plaguelands | 12 | Outdoor coordinates unverified |
| Enraged Felbat (9521) | Eastern Plaguelands | 8 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Eastern Plaguelands | 1 | Outdoor coordinates unverified |
| Lumbering Horror (14697) | Eastern Plaguelands | 12 | Outdoor coordinates unverified |
| Marduk the Black (10939) | Eastern Plaguelands | 1 | Outdoor coordinates unverified |
| Redpath the Corrupted (10938) | Eastern Plaguelands | 3 | Outdoor coordinates unverified |
| Servant of Horgus (10953) | Eastern Plaguelands | 2 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Eastern Plaguelands | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Eastern Plaguelands | 11 | Outdoor coordinates unverified |
| The Cleaner (14503) | Eastern Plaguelands | 2 | Outdoor coordinates unverified |
| Reginald Windsor (12580) | Elwynn Forest | 1 | Unsupported historical zone |
| Teremus the Devourer (7846) | Elwynn Forest | 12 | Unsupported historical zone |
| Spirit of Trey Lightforge (11141) | Felwood | 1 | Outdoor coordinates unverified |
| Great Shark (12124) | Feralas | 9 | Unsupported historical zone |
| Greater Anubisath Warbringer (15754) | Feralas | 3 | Outdoor coordinates unverified |
| Greater Silithid Flayer (15756) | Feralas | 7 | Outdoor coordinates unverified |
| Mushgog (11447) | Feralas | 2 | Outdoor coordinates unverified |
| Qiraji Brigadier General (15753) | Feralas | 6 | Outdoor coordinates unverified |
| Shade of Taerar (15302) | Feralas | 3 | Outdoor coordinates unverified |
| The Razza (11497) | Feralas | 2 | Outdoor coordinates unverified |
| Enraged Felbat (9521) | Hillsbrad Foothills | 8 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Hillsbrad Foothills | 2 | Outdoor coordinates unverified |
| Milton Beats (13082) | Hillsbrad Foothills | 1 | Outdoor coordinates unverified |
| Verdantine Boughguard (12477) | Ironforge | 4 | Unsupported historical zone |
| Blacklash (2757) | Loch Modan | 1 | Unsupported historical zone |
| Hematus (2759) | Loch Modan | 12 | Unsupported historical zone |
| Shadowforge Digger (4846) | Loch Modan | 3 | Unsupported historical zone |
| Shadowforge Surveyor (4844) | Loch Modan | 4 | Unsupported historical zone |
| Eranikus, Tyrant of the Dream (15491) | Moonglade | 3 | Outdoor coordinates unverified |
| Nightmare Phantasm (15629) | Moonglade | 12 | Outdoor coordinates unverified |
| Omen (15467) | Moonglade | 12 | Outdoor coordinates unverified |
| Emeraldon Boughguard (12474) | Orgrimmar | 12 | Unsupported historical zone |
| Emeraldon Oracle (12476) | Orgrimmar | 1 | Unsupported historical zone |
| Emeraldon Tree Warder (12475) | Orgrimmar | 12 | Unsupported historical zone |
| Omen (15467) | Orgrimmar | 12 | Outdoor coordinates unverified |
| Volchan (10119) | Redridge Mountains | 12 | Unsupported historical zone |
| Enraged Gryphon (9526) | Searing Gorge | 2 | Outdoor coordinates unverified |
| Scarshield Grunt (9043) | Searing Gorge | 1 | Outdoor coordinates unverified |
| Aluntir (15288) | Silithus | 11 | Outdoor coordinates unverified |
| Anubisath Conqueror (15424) | Silithus | 3 | Outdoor coordinates unverified |
| Arakis (15290) | Silithus | 12 | Outdoor coordinates unverified |
| Colossal Anubisath Warbringer (15743) | Silithus | 12 | Outdoor coordinates unverified |
| Colossus of Ashi (15742) | Silithus | 12 | Outdoor coordinates unverified |
| Colossus of Regal (15741) | Silithus | 12 | Outdoor coordinates unverified |
| Colossus of Zora (15740) | Silithus | 10 | Outdoor coordinates unverified |
| Greater Anubisath Warbringer (15754) | Silithus | 4 | Outdoor coordinates unverified |
| Greater Silithid Flayer (15756) | Silithus | 12 | Outdoor coordinates unverified |
| High Overlord Saurfang (14720) | Silithus | 1 | Unsupported historical zone |
| Hive'Regal Hunter-Killer (15620) | Silithus | 2 | Outdoor coordinates unverified |
| Imperial Qiraji Destroyer (15744) | Silithus | 12 | Outdoor coordinates unverified |
| Lieutenant General Nokhor (15818) | Silithus | 12 | Outdoor coordinates unverified |
| Qiraji Brigadier General (15753) | Silithus | 12 | Outdoor coordinates unverified |
| Qiraji Brigadier General Pax-lish (15817) | Silithus | 12 | Outdoor coordinates unverified |
| Qiraji Drone (15421) | Silithus | 3 | Outdoor coordinates unverified |
| Qiraji Lieutenant General (15757) | Silithus | 12 | Outdoor coordinates unverified |
| Qiraji Tank (15422) | Silithus | 3 | Outdoor coordinates unverified |
| Qiraji Wasp (15414) | Silithus | 2 | Outdoor coordinates unverified |
| Supreme Anubisath Warbringer (15758) | Silithus | 12 | Outdoor coordinates unverified |
| Supreme Silithid Flayer (15759) | Silithus | 12 | Outdoor coordinates unverified |
| Xil'xix (15286) | Silithus | 2 | Outdoor coordinates unverified |
| Misha (10204) | Stonetalon Mountains | 2 | Unsupported historical zone |
| Enraged Gryphon (9526) | Stormwind City | 1 | Outdoor coordinates unverified |
| Flameshocker (16383) | Stormwind City | 12 | Outdoor coordinates unverified |
| Hogger (448) | Stormwind City | 1 | Unsupported historical zone |
| Lady Dena Kennedy (15991) | Stormwind City | 3 | Outdoor coordinates unverified |
| Pallid Horror (16394) | Stormwind City | 12 | Outdoor coordinates unverified |
| Stormwind Elite Guard (16396) | Stormwind City | 7 | Outdoor coordinates unverified |
| Teremus the Devourer (7846) | Stormwind City | 12 | Unsupported historical zone |
| Enraged Gryphon (9526) | Stranglethorn Vale | 1 | Outdoor coordinates unverified |
| Scarshield Quartermaster (9046) | Stranglethorn Vale | 1 | Outdoor coordinates unverified |
| Felcular (7735) | Swamp of Sorrows | 5 | Unsupported historical zone |
| Murk Slitherer (5224) | Swamp of Sorrows | 3 | Outdoor coordinates unverified |
| Teremus the Devourer (7846) | Swamp of Sorrows | 12 | Unsupported historical zone |
| Bone Witch (16380) | Tanaris | 12 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Tanaris | 1 | Outdoor coordinates unverified |
| Greater Anubisath Warbringer (15754) | Tanaris | 9 | Outdoor coordinates unverified |
| Greater Silithid Flayer (15756) | Tanaris | 12 | Outdoor coordinates unverified |
| Lieutenant General Nokhor (15818) | Tanaris | 7 | Outdoor coordinates unverified |
| Lumbering Horror (14697) | Tanaris | 12 | Outdoor coordinates unverified |
| Qiraji Brigadier General (15753) | Tanaris | 12 | Outdoor coordinates unverified |
| Qiraji Brigadier General Pax-lish (15817) | Tanaris | 12 | Outdoor coordinates unverified |
| Qiraji Lieutenant General (15757) | Tanaris | 12 | Outdoor coordinates unverified |
| Raging Dune Smasher (5470) | Tanaris | 4 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Tanaris | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Tanaris | 12 | Outdoor coordinates unverified |
| Supreme Anubisath Warbringer (15758) | Tanaris | 12 | Outdoor coordinates unverified |
| Supreme Silithid Flayer (15759) | Tanaris | 12 | Outdoor coordinates unverified |
| Cloned Ectoplasm (5780) | The Barrens | 1 | Outdoor coordinates unverified |
| Eroded Anubisath Warbringer (15810) | The Barrens | 12 | Outdoor coordinates unverified |
| Faltering Silithid Flayer (15811) | The Barrens | 9 | Outdoor coordinates unverified |
| Minor Anubisath Warbringer (15807) | The Barrens | 8 | Outdoor coordinates unverified |
| Minor Silithid Flayer (15808) | The Barrens | 10 | Outdoor coordinates unverified |
| Omen (15467) | The Barrens | 12 | Outdoor coordinates unverified |
| Qiraji Lieutenant (15806) | The Barrens | 10 | Outdoor coordinates unverified |
| Qiraji Lieutenant Jo-rel (15814) | The Barrens | 5 | Outdoor coordinates unverified |
| Qiraji Officer (15812) | The Barrens | 7 | Outdoor coordinates unverified |
| Qiraji Officer Zod (15813) | The Barrens | 10 | Outdoor coordinates unverified |
| Shade of Taerar (15302) | The Hinterlands | 4 | Outdoor coordinates unverified |
| Voidwalker Minion (8996) | The Hinterlands | 1 | Unsupported historical zone |
| Anubisath Warbringer (15751) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Lesser Anubisath Warbringer (15748) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Lesser Silithid Flayer (15749) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Qiraji Captain (15747) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Qiraji Captain Ka'ark (15815) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Qiraji Major (15750) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Qiraji Major He'al-ie (15816) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Razorfen Battleguard (7873) | Thousand Needles | 1 | Unsupported historical zone |
| Silithid Flayer (15752) | Thousand Needles | 12 | Outdoor coordinates unverified |
| Young Arikara (10581) | Thousand Needles | 2 | Outdoor coordinates unverified |
| Fallen Hero (10996) | Tirisfal Glades | 3 | Unsupported historical zone |
| Hogger (448) | Tirisfal Glades | 2 | Unsupported historical zone |
| The Banshee Queen (15193) | Tirisfal Glades | 1 | Outdoor coordinates unverified |
| Flameshocker (16383) | Undercity | 12 | Outdoor coordinates unverified |
| Pallid Horror (16394) | Undercity | 12 | Outdoor coordinates unverified |
| Undercity Elite Guardian (16432) | Undercity | 8 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Western Plaguelands | 2 | Outdoor coordinates unverified |
| Grand Inquisitor Isillien (1840) | Western Plaguelands | 2 | Outdoor coordinates unverified |
| Enraged Gryphon (9526) | Westfall | 1 | Outdoor coordinates unverified |
| Hogger (448) | Westfall | 1 | Unsupported historical zone |
| Enraged Gryphon (9526) | Wetlands | 1 | Outdoor coordinates unverified |
| Bone Witch (16380) | Winterspring | 12 | Outdoor coordinates unverified |
| Doctor Weavil (15552) | Winterspring | 1 | Unsupported historical zone |
| Lumbering Horror (14697) | Winterspring | 12 | Outdoor coordinates unverified |
| Shadow of Doom (16143) | Winterspring | 12 | Unsupported historical zone |
| Spirit of the Damned (16379) | Winterspring | 12 | Outdoor coordinates unverified |
| Xandivious (15623) | Winterspring | 7 | Outdoor coordinates unverified |

## Coordinates awaiting verification

| NPC | ID |
|---|---:|
| Grand Inquisitor Isillien | 1840 |
| Murk Slitherer | 5224 |
| Raging Dune Smasher | 5470 |
| Cloned Ectoplasm | 5780 |
| Scarshield Grunt | 9043 |
| Scarshield Quartermaster | 9046 |
| Enraged Felbat | 9521 |
| Enraged Gryphon | 9526 |
| Young Arikara | 10581 |
| Redpath the Corrupted | 10938 |
| Marduk the Black | 10939 |
| Servant of Horgus | 10953 |
| Bloodletter | 10954 |
| Spirit of Trey Lightforge | 11141 |
| Mushgog | 11447 |
| The Razza | 11497 |
| Milton Beats | 13082 |
| The Rot | 14235 |
| The Cleaner | 14503 |
| Lumbering Horror | 14697 |
| The Banshee Queen | 15193 |
| Xil'xix | 15286 |
| Aluntir | 15288 |
| Arakis | 15290 |
| Shade of Taerar | 15302 |
| Qiraji Wasp | 15414 |
| Qiraji Drone | 15421 |
| Qiraji Tank | 15422 |
| Anubisath Conqueror | 15424 |
| Omen | 15467 |
| Eranikus, Tyrant of the Dream | 15491 |
| Hive'Regal Hunter-Killer | 15620 |
| Xandivious | 15623 |
| Nightmare Phantasm | 15629 |
| Colossus of Zora | 15740 |
| Colossus of Regal | 15741 |
| Colossus of Ashi | 15742 |
| Colossal Anubisath Warbringer | 15743 |
| Imperial Qiraji Destroyer | 15744 |
| Qiraji Captain | 15747 |
| Lesser Anubisath Warbringer | 15748 |
| Lesser Silithid Flayer | 15749 |
| Qiraji Major | 15750 |
| Anubisath Warbringer | 15751 |
| Silithid Flayer | 15752 |
| Qiraji Brigadier General | 15753 |
| Greater Anubisath Warbringer | 15754 |
| Greater Silithid Flayer | 15756 |
| Qiraji Lieutenant General | 15757 |
| Supreme Anubisath Warbringer | 15758 |
| Supreme Silithid Flayer | 15759 |
| Qiraji Lieutenant | 15806 |
| Minor Anubisath Warbringer | 15807 |
| Minor Silithid Flayer | 15808 |
| Eroded Anubisath Warbringer | 15810 |
| Faltering Silithid Flayer | 15811 |
| Qiraji Officer | 15812 |
| Qiraji Officer Zod | 15813 |
| Qiraji Lieutenant Jo-rel | 15814 |
| Qiraji Captain Ka'ark | 15815 |
| Qiraji Major He'al-ie | 15816 |
| Qiraji Brigadier General Pax-lish | 15817 |
| Lieutenant General Nokhor | 15818 |
| Lady Dena Kennedy | 15991 |
| Spirit of the Damned | 16379 |
| Bone Witch | 16380 |
| Flameshocker | 16383 |
| Pallid Horror | 16394 |
| Stormwind Elite Guard | 16396 |
| Undercity Elite Guardian | 16432 |

Validation: every published point matches the corrected spawn/patrol dataset or reviewed dragon portal; zone membership, nested patrols, map behavior and paced research tests passed. These checks establish source consistency, not current live spawn presence.
