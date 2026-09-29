# Classic Hardcore companions and ammunition bags

Checked 2026-09-26. Scope: Classic Era / official Hardcore, levels 1–60. Recommendations are editorial leveling guidance, not a simulation of talents, faction access, trained skills, pet loyalty, inventory or current auction availability.

## Sources and reproducibility

- [Petopia Classic](https://www.wow-petopia.com/classic/), its [ability tables](https://www.wow-petopia.com/classic/abilities.php), [training instructions](https://www.wow-petopia.com/classic/training.php), and all 17 family pages establish family compatibility, diets, pet-level requirements, training points and tame sources. `scripts/research-companions.mjs` snapshots 21 abilities / 111 ranks and records URL/content hashes in `companion-source-records.json`.
- `scripts/curate-companions.py` selects useful training routes and checks every selected NPC's Normal/Elite classification against ClassicDB. `companion-npc-verification.json` records 59 verified non-rare creatures. The full source snapshot contains unfiltered reference information; user-facing recommendations contain no rare pets.
- [Bite](https://www.wowhead.com/classic/spell=17258), [Claw](https://www.wowhead.com/classic/spell=16827), and [Screech](https://www.wowhead.com/classic/spell=24423) establish focus/cooldown behavior. [Warcraft Tavern's comparison](https://www.warcrafttavern.com/wow-classic/guides/best-hunter-pets-for-dungeons-raiding-leveling-pvp/) and [Icy Veins' pet guide](https://www.icy-veins.com/wow-classic/hunter-dps-pets-guide) inform the playstyle recommendations.
- [Warlock demons and ability ranks](https://www.wowhead.com/classic/guide/wow-classic-warlock-demon-pets), [leveling](https://www.wowhead.com/classic/guide/classes/warlock/leveling-tips), and [Hardcore leveling](https://www.wowhead.com/classic/guide/classes/warlock/hardcore-leveling-tips) distinguish a damage-oriented Affliction approach from defensive Demonology play. [Sacrifice grimoire](https://www.wowhead.com/classic/item=16351) and [Spell Lock grimoire](https://www.wowhead.com/classic/item=16388) verify important delayed utility unlocks.
- `scripts/research-quivers.py` snapshots 13 Classic item tooltips, not modern retail bag versions, into `quiver-source-records.json`. Item names, equipment levels, capacities and speed bonuses are preserved. [Ammo bag acquisition guide](https://www.warcrafttavern.com/wow-classic/guides/ammo-bags-and-ammunition/), [Night Watch quest](https://classicdb.ch/?quest=58), and [Hunter epic quest](https://www.wowhead.com/classic/guide/classic-hunter-quest-ancient-petrified-leaf) supply route context.

Run research scripts inside the existing website development container. External source changes require review before replacing the checked-in curated records. No external HTML is rendered or executed in the application.

## Hunter conclusions

A happy, leveled common pet with current skills is the practical baseline. A nearby cat or owl works after the level-10 class quests; an owl or carrion bird with Screech is the cautious solo recommendation once a reasonable route is available. A cat remains a strong single-target choice. Travel risk can outweigh modest optimization, especially for Horde before a convenient Screech source. All 17 families and their diets/abilities are visible in Detailed view; the main panel focuses on the relevant leveling skills.

Bite costs 35 focus and has a 10-second cooldown. Claw costs 25 and can consume focus every global cooldown. At comparable ranks Bite generally provides efficient damage per focus, while Claw converts surplus focus into damage. These are not interchangeable DPS rankings: available ranks, focus regeneration and Growl usage change the result. Learn both on a cat and manage Claw if tanking skills starve. Screech costs 20, damages one target and reduces nearby enemies' melee attack power. Prioritize Growl/Screech on an owl; Claw is optional. An owl cannot learn Bite, and a bat cannot learn Claw. Avoid nearby crowd control when using area effects.

The character-level recommendation must satisfy both the recipient pet's requirement and an actual non-rare training creature's tame level. Selected routine sources are Normal and outside dungeons/raids. This means:

| Skill | Pet requirement | First selected routine Hunter level | Common source |
| --- | --- | --- | --- |
| Screech 1 | 8 | 16 | Greater Fleshripper, Westfall |
| Screech 2 | 24 | 32 | Salt Flats Vulture, Thousand Needles |
| Screech 3 | 48 | 48 | Ironbeak Owl, Felwood |
| Screech 4 | 56 | 56 | Monstrous Plaguebat, Eastern Plaguelands |
| Claw 4 | 24 | 25 | Elder Ashenvale Bear |
| Claw 5 | 32 | 34 | Scorpashi Lasher |
| Claw 8 | 56 | 57 | Winterspring Screecher |
| Bite 7 | 48 | 49 | Saltwater Snapjaw |
| Dive 1 | 30 | 31 | Young Mesa Buzzard |
| Dash 1 | 30 | 32 | Stranglethorn Tiger |
| Dash 3 | 50 | 54 | Blackrock Worg |

Bite 8's Bloodaxe Worg route is an optional dungeon tame; keep routine Bite 7 until actually learned. Charge 4 has no known source and is explicitly skipped. Elite Drywallow Daggermaw and Vilebranch Raiding Wolf do not lower the routine recommendation gates. Spawn ranges require checking the individual creature's level.

Stable the main pet, tame a temporary training creature, use its skill until the learned message appears, then teach the compatible main pet through Beast Training. Lower ranks can be skipped. Four active skills and loyalty-dependent training points constrain the build. Great Stamina/Natural Armor numbers are trainer ceilings, not a claim that every maximum is simultaneously affordable. Ranks assume the pet has caught up to the chosen character level.

## Warlock conclusions

The compact default is Imp before 10, then Voidwalker for cautious solo leveling; this is not a claim that Voidwalker maximizes leveling speed or always holds threat. Succubus/Incubus becomes the damage alternative at 20 for Affliction/drain-tanking play. Felhunter becomes a situational magic-dispel option at 30, with Spell Lock only at 36. Imp remains useful for group stamina and ranged damage.

Quest unlocks are not automatically completed by reaching a level. Sacrifice begins at 16, Seduction at 26, Spell Lock at 36. The guide displays current Firebolt, Blood Pact, Torment and Sacrifice ranks from grimoires. Soul Link and Dark Pact require the relevant talents. Infernal/Doomguard are not routine leveling companions. Soulstone does not restore a dead Hardcore character; see [Blizzard's Hardcore rules](https://worldofwarcraft.blizzard.com/en-us/news/23973734).

## Quiver conclusions

The default path shows both arrows and bullets without introducing another selector or inventory quantities:

| Level | Bow/crossbow | Gun | Slots | Total speed bonus | Route |
| --- | --- | --- | --- | --- | --- |
| 1 | Small Quiver | Small Shot Pouch | 8 | 10% | Vendors |
| 10 | Medium Quiver | Medium Shot Pouch | 10 | 10% | Vendors; capacity only |
| 30 | Heavy Quiver | Heavy Leather Ammo Pouch | 14 | 12% | Leatherworker / AH |
| 40 | Quickdraw Quiver | Thick Leather Ammo Pouch | 16 | 13% | Leatherworker / AH |

Self Found requires crafting rather than buying another player's work. Detailed view separates the Alliance Night Watch chain (12 slots / 11%, minimum quest level 18 but final quest level 30), Ribbly's BRD drops (equipment level 50 / 16 slots / 14%), and Ancient Sinew Wrapped Lamina (60 / 18 slots / 15%, raid-started Hunter epic quest). Equipment eligibility is not acquisition readiness. Do not replace a routine bag automatically with a dungeon/raid item, and do not recommend battleground reputation rewards as an official Hardcore route.

## Presentation contract

Food & drink, Potions & elixirs, and Emergency supplies remain the first three cards in DOM and visual order. Pet and quiver cards follow side by side on desktop (two-thirds / one-third width), stacking at 1000px and below. Warlocks receive a single demon card. Compact mode shows current priorities; Detailed view adds comparison, family coverage, source/rank roadmaps and optional bag routes. Class, numeric level, and detail preference continue to use existing cookies. No quantities or item selection controls are added.

### Pet-choice categories

The main Hunter card now presents Offensive, General and Defensive as three visible, compact categories. They follow Petopia's Offense/General/Defense family assignments (rechecked against the Classic homepage); they are not talent specializations. Offensive highlights cat/owl, General highlights wolf before level 16 and carrion bird thereafter, and Defensive highlights boar/bear. Common examples are drawn exclusively from the previously verified Normal NPC records and only appear once taming is unlocked and the creature's minimum level is reachable. Starter pets remain useful when kept leveled; examples do not require replacing a trained pet. Detailed view partitions all 17 families into the same three groups, including owls under Offensive.
