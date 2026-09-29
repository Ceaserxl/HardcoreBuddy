# Classic Era instance guide research

Reviewed 2026-09-28. The current UI shows only level ranges and packing lists. Runtime content is in `Data/Instances.lua` and
`Data/InstancesRaids.lua`; these are original factual summaries, not copies of
Zygor's guide scripts or DBM's encounter implementation.

## Sources inspected

- Installed `ZygorGuidesViewerClassic/Data-Classic/Dungeons.lua`, plus the full
  Alliance and Horde `Guides-Classic/Dungeons/ZygorDungeon*CLASSIC.lua` files:
  instance catalog, named bosses, route prerequisites, optional events and
  dungeon hazards. The opening Classic dungeon sections were used, not the
  later Season of Discovery raid guides. Zygor's Scarlet Monastery and
  Scholomance map IDs include later-version values: the runtime catalog uses
  Classic IDs 189 and 289 instead.
- Installed anniversary client's `DBM-Party-Vanilla` Classic and Shared modules
  and Vanilla TOC: boss identities, original spell warnings and map IDs.
  Retail and seasonal-only dungeons were excluded.
- [DBM Vanilla raid modules](https://github.com/DeadlyBossMods/DBM-Vanilla/tree/25d051c8474355ebe59af0975d79a0cdac3c77b1/DBM-Raids-Vanilla),
  commit `25d051c8474355ebe59af0975d79a0cdac3c77b1`: MC, BWL, VanillaOnyxia,
  VanillaZG, AQ20, AQ40 and VanillaNaxx. Raid modules were not installed in the
  Classic Era or anniversary addon folders. The official source was inspected
  separately. Ignore SoD / SoM branches and the retail Blackrock Depths raid.
- Classic client item tooltips through
  `https://nether.wowhead.com/classic/tooltip/item/ITEM_ID`: exact item IDs,
  icons, level/profession requirements and consumable limits. Cached tooltip
  responses are in `items/`; unused researched items are retained as evidence,
  not silently added to player recommendations.
- [Blizzard's Hardcore rules](https://worldofwarcraft.blizzard.com/en-us/news/23973734/rules-of-engagement-classic-hardcore-is-coming-to-world-of-warcraft):
  leveling-dungeon lockouts and the need to check group eligibility.

The source inventory in `sources.json` records hashes and locations of inspected
local addon files and the pinned official raid revision. Original third-party
addon source is kept in the development tools cache, outside the distributable
HardcoreBuddy folder. Neither source addon is a runtime dependency.

## Editorial decisions

- 28 dungeon routes/wings and all seven instanced Classic Era raids.
  Maraudon's two inner sections are one Inner guide; North tribute is covered
  inside Dire Maul North. UBRS remains a 10-player dungeon.
- Suggested full-run levels are editorial planning bands, not entry limits,
  automatic readiness assessments, or source-certified safe levels.
- Boss, hazard, route and first-run briefings were removed from runtime data
  and navigation to keep each entry focused on levels and items to bring.
- The two Stratholme routes, four Scarlet Monastery wings, three Maraudon
  routes, three Dire Maul wings and two Spire routes share map IDs. Detection
  opens a route chooser rather than inferring a wing from a localized name.
- Item descriptions are short; native item tooltips retain full item details.
  Packing rows now show named mobs, abilities and usage timing instead of
  generic item effects. Broad retreat items explicitly say they have no
  particular mob counter. Three generic recommendations without a confirmed
  target were removed (Restorative in inner Maraudon, Anti-Venom in Sunken
  Temple and Molten Core).
  Free Action is prevention, Anti-Venom ranks retain poison-level caps, and
  protection potions show finite absorbs. Shared potion cooldowns remain visible.
- Onyxia Scale Cloak must be equipped; Hourglass Sand specifically removes Bronze.
  Zul'Gurub and Naxxramas cleansing items defer to the raid's cleanse calls.
- The source records above document the earlier full guide research; encounter
  tactics are no longer shipped as player-facing content.

## Item-use follow-up, 2026-09-28

Free Action notes match the item's cached Classic tooltip: use before ordinary
stuns/roots, not after application and not for Sleep or Fear. Mob abilities
were checked against the existing DBM/source inventory and these records:

- [BradyGames: Wailing Caverns](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/wailing/Wailing%20HR.pdf):
  Deviate Viper's Localized Toxin; poison cleansing is not assigned to
  Venomwing's direct-damage Toxic Spit.
- [BradyGames: The Stockade](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/stockade/the_stockade_lrgs.pdf):
  Defias Convict's Backhand and Hamhock's Chain Lightning.
- [BradyGames: Blackfathom Deeps](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/blackfathomdeeps/blackfathom_deeps_lr.pdf):
  Lady Sarevess' Frost Nova and Aku'mai's poison.
- [BradyGames: Gnomeregan](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/gn/gnlr.pdf):
  Mechanized Guardian's Electrified Net.
- [BradyGames: Razorfen Kraul](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/razorfens/kraul_gshr.pdf):
  Razorfen Totemic's Earthgrab Totem.
- [BradyGames: Maraudon](https://ptgmedia.pearsoncmg.com/imprint_downloads/brady/wow/maraudon/maraudon_lr.pdf):
  Theradrim Guardian / Cavern Shambler Knockdown and purple-wing debuffs.
- Installed DBM `Shared/ZulFarrak/Antusul.lua`: Earthgrab Totem (8376).
  `Shared/SunkenTemple/ShadeofEranikus.lua`: Acid Breath (12533), with
  Classic spell tooltip checked separately from the seasonal raid mechanics.
  Pinned BWL `Chromaggus.lua`: Green affliction is poison (23169).
- [Classic Scarlet Monastery Cathedral mobs](https://warcraft.wiki.gg/wiki/Scarlet_Monastery_Cathedral):
  Scarlet Sorcerer's Slow; not a nonexistent Scarlet Wizard Polymorph.
- [Lord Incendius](https://www.wowhead.com/classic/npc=9017/lord-incendius):
  curse removal; Argelmach's instant Shock is not a removable damage-over-time spell.
- [Alzzin the Wildshaper](https://warcraft.wiki.gg/wiki/Alzzin_the_Wildshaper):
  Enervate is poison and Wither is disease.
- [Arcane Torrent](https://warcraft.wiki.gg/wiki/Arcane_Torrent_%28mob%29):
  its lightning is nature damage, so the arcane potion note names Arcane
  Aberration instead.

The item-to-ability pairing is our inference from the recorded ability and the
item's effect. It is not an in-game test of every immunity. No entry promises
immunity to scripted boss control, raid wipe mechanics, or encounter execution.

## Verification

`tests/run_instances.py` boots the real TOC and checks catalog coverage, map
routing, unknown instances, wing ambiguity, search, packing lists, sidebar
dispatch, preview/live location behavior, carried quantities, equipment and
pooled UI reset. `tests/render_layout.py` produces frame-tree previews with
approximate game fonts; they are not game screenshots.
