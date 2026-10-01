# Provenance and scope

Port prepared September 27, 2026 from the user-provided CXL-Website copy and
the [original handoff](HANDOFF.md), website baseline `1595a17` following `7fc772d`.
Product name in-game: HardcoreBuddy; content: Hardcore Field Kit.
Version 1.1 replaces the website-style page with focused companion views at the
user's request. The recommendation model remains intact.
Version 2.0 adds the user-requested bag quantities and carry targets, opens directly
to Supplies, and routes healing/mana potions to Emergency. These supersede the
original handoff's no-inventory requirement. Quantity defaults are editable addon
planning suggestions, not facts imported from the reference website.

Reviewed item references were checked September 26, 2026; curated companions
September 27. The recommendation model preserves those snapshots. Numeric
item/NPC IDs, URLs, source dates, classifications, source
hashes, use/craft requirements and duplicate item IDs with distinct record IDs
are retained. Runtime data is generated from `reference/*.json`; SHA-256 checksums
are in `reference/manifest.json`.

`reference/baseline` contains only the three original recommendation model files,
with a small module-format package declaration for local fixture generation.
`reference/research` retains the four original research JSON datasets and two
research decision documents. `reference/Potion_Elixir_Sheet.xlsm` is retained
unchanged as historical provenance; no macros are executed or loaded by WoW.
Historical catalog inclusion flags and inventory state are not used.

No React app, web server, browser cookie/storage implementation, website icons,
website splash/navigation code or third-party web packages are shipped as addon
runtime. Icons and item tooltips use game-native resources. No external addon
libraries or external runtime services are required. Source references remain
credited to their original sites; this port does not assign new rights to their
content. No website artwork is copied into the addon.

## Client adaptation

The local `WowClassic.exe` file version was inspected: 1.15.9.69722. The TOC uses
11509. Native frame resizing, edit-box input and unit-event contracts were checked
against Blizzard's published UI source as mirrored on the Classic Era branch:

- [Frame API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFrameAPIDocumentation.lua)
- [EditBox API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua)
- [Unit events](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua)

The view reads `UnitClass`, `UnitLevel` and `UnitExists`, and refreshes on world
entry, player level/XP updates, active-pet changes and unit-level changes.
SavedVariables initialize on this addon's `ADDON_LOADED`. Scale/display changes
reapply window bounds. The UI is informational and creates no secure item/spell
action buttons. It avoids Ace library sharing and Settings category registration.
All `GameTooltip:SetText` color calls supply numeric alpha before the wrap flag.

Version 2.0.1 checks the [Button API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleButtonAPIDocumentation.lua):
`SetHighlightTexture` requires an asset; `ClearHighlightTexture` clears it.
The test mock now rejects nil highlight assets, reproducing the reported client
error before the fix. The [Backdrop implementation](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXML/Backdrop.lua)
separately supports `SetBackdrop(nil)` to clear a reused row's backdrop.

Version 2.0 reads `C_Container.GetContainerNumSlots` and `GetContainerItemInfo`
(`itemID`, `stackCount`) and refreshes on `BAG_UPDATE_DELAYED`. Carried bags 0-4 and
the declared Classic keyring are read; bank containers are excluded. Contracts were
checked against the Classic Era Blizzard source mirror:

- [Container API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua)
- [Classic bag constants](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_FrameXMLBase/Classic/Constants.lua)

Unknown or incomplete reads stay Unknown. Quantity targets and chosen profession
ranks use separate character SavedVariables. No container mutation API is called.

Version 2.1 automatically chooses bandages and target dummies from the current
character's effective First Aid/Engineering skill and learned recipe spells.
The supplemental recipe map in `Professions.lua` preserves the original item
snapshot and distinguishes crafting requirements from item-use requirements.
Spell IDs, crafted item IDs and crafting thresholds were checked against the
[First Aid recipe index](https://www.wowhead.com/classic/skill=129/first-aid) and
[Engineering recipe index](https://www.wowhead.com/classic/skill=202/engineering).
Bandage crafting thresholds are 1, 40, 80, 115, 150, 180, 210, 240, 260 and 290;
the three target dummies require Engineering 85, 185 and 275.

Version 2.1.1 adds anti-venom to automatic selection using the same detected First
Aid skill as bandages. The First Aid index's `learnedat` and `creates` fields were
checked for Anti-Venom (spell 7934, item 6452, skill 80), Strong Anti-Venom (7935,
6453, 130) and Powerful Anti-Venom (23787, 19440, 300). All three require confirmed
recipe knowledge. Rank strength follows the preserved poison-level caps of 25,
35 and 60; character level does not gate the automatic choice. The original item
details still explain poison caps and the Powerful rank's use requirement.

Native contracts were checked on the Classic Era Blizzard source branch:

- [SpellBook API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua): `C_SpellBook.IsSpellKnown` includes known spells outside the visible spellbook.
- [Legacy SpellBook aliases](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_DeprecatedSpellBook/Deprecated_SpellBook.lua): `IsPlayerSpell` is the compatible fallback; legacy `IsSpellKnown` has different semantics.
- [Classic SkillFrame](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_UIPanels_Game/Classic/SkillFrame.lua): native skill ranks, temporary points and modifiers.
- [TradeSkill API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua): localized profession names by skill-line ID.
- [Skill events](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SkillInfoDocumentation.lua): `SKILL_LINES_CHANGED` is synchronous, so reading collapsed skill headers is guarded against reentry and restores their state.

Profession and recipe information is read fresh at login/world entry and updated
on skill, spell and trade-skill events, including while Preview is active. Material
availability and crafting tools are not checked; no crafting action is performed.

No client interaction is automated. Real-client checks remain listed separately
in VALIDATION.md. Version 3 simulated layouts use substitute fonts and a separate
development cache of native textures; older renders used icon boxes.

## Version 3 artwork and native styling

Three original assets were generated with the built-in imagegen tool and embedded
as uncompressed 32-bit TGA textures. Source PNGs and exact prompts are preserved
in `Media/Source` and `docs/ARTWORK.md`. The artwork requires no other addon.
Native Blizzard textures are referenced by game paths and are not redistributed.

Version 3.0.2 replaces the banner and emblem with `JourneyBanner` and
`SurvivorShield`. The whole shallow scene is fitted at its source proportions.
A small native gradient blends its left edge into the header backing on wide
windows. [Texture API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua)
defines `SetGradient(orientation, minColor, maxColor)`;
[Color.lua](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXMLBase/Color.lua)
defines `CreateColor(r, g, b, a)`, including transparent endpoint colors.

Styling contracts were checked against the Classic Era game UI source:

- [Backdrop implementation](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXML/Backdrop.lua) and [template](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXML/Backdrop.xml): border sizing and inherited resize handling.
- [Panel templates](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedXML/SecureUIPanelTemplates.xml): native button assets and slice coordinates.
- [Action button template](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Classic/ActionButtonTemplate.xml): native item-icon framing.
- [Region API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleRegionAPIDocumentation.lua), [texture API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleTextureBaseAPIDocumentation.lua), [font API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleFontStringAPIDocumentation.lua) and [edit-box API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua): native decoration, shadows, layering and text insets.

## Version 3.1 profession, faction and item presentation

Runtime research URLs and the Sources export are removed. Original reviewed
records and this developer document preserve provenance separately from the
gameplay data. Faction overlays restrict exclusive quest rewards and give local
recipe routes for shared items; the complete wild-pet catalog is not filtered
as though creatures were faction-bound.

Progression references checked for the First Aid, Engineering and Cooking
guidance include [Classic First Aid](https://www.wowhead.com/classic/skill=129/first-aid),
[Engineering](https://www.wowhead.com/classic/skill=202/engineering),
[Expert Cookbook](https://www.wowhead.com/classic/item=16072/expert-cookbook),
[Clamlette Surprise](https://www.wowhead.com/classic/quest=6610/clamlette-surprise),
[Formula: Powerful Anti-Venom](https://www.wowhead.com/classic/item=19442/formula-powerful-anti-venom)
and [Schematic: Masterwork Target Dummy](https://www.wowhead.com/classic/item=16046/schematic-masterwork-target-dummy).
Recipe binding determines trade eligibility; no auction listing is assumed.
Profession rank training uses the actual character's level while planning.

Item icons use the native
[Classic Era item API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
when available, with a local game-icon path fallback. No Blizzard artwork is
downloaded by or embedded in the addon. New background and row artwork is
original generated art; exact prompts and source files are in ARTWORK.md.

## Petopia offline lookup (version 1.1)

[Petopia Classic](https://www.wow-petopia.com/classic/) is credited for the factual
family, creature, appearance and skill index, checked September 27, 2026. Fresh
copies of all 17 family pages and the abilities, attack-speed, training, differences
and caster-pet pages are retained under `reference/pet-guide` for research. Source
URLs and SHA-256 hashes are recorded in `reference/pet-guide.json`.

`scripts/pet_guide.py` combines family tooltip tables, attack-speed/NPC tables and
the previously reviewed full ability-rank audit. Game ability effects are retained
as skill facts; the care guides in `Companion.lua` are short original summaries.
The index covers 559 creatures, 145 appearances, 17 families and 21 abilities /
111 ranks. Missing attack speeds remain unknown. Classifications come from the
family listings. Historical caster flags describe obsolete Vanilla behavior.

The lookup includes clearly labeled rares, elites and group encounters. Routine
recommendations still use the separate common-tame dataset. Gallery images, full
articles, discussions and historical caster comparison tables remain on Petopia
with source links. Source HTML is development research, never loaded by WoW.
No Petopia logos or artwork are redistributed as runtime assets.

## Crafting catalog audit (September 28, 2026)

`Data/Crafting.lua` classifies all 121 catalog rows (120 distinct item IDs):
89 profession-crafted consumables, nine class conjurations, one Rogue poison
ability and 21 items with no player crafting recipe. `Crafting.lua` keeps recipe
requirements, profession-rank training, item-use level, recipe tradability and
finished-item tradability separate. No live Auction House availability is claimed;
Self Found restrictions are stated independently of an item's binding.

The 89 profession requirements use the `learnedat` field of the Classic game-data
recipe records on [Alchemy](https://www.wowhead.com/classic/skill=171),
[Cooking](https://www.wowhead.com/classic/skill=185),
[First Aid](https://www.wowhead.com/classic/skill=129) and
[Engineering](https://www.wowhead.com/classic/skill=202). Recipe difficulty/color
thresholds are not treated as crafting prerequisites. Per-item spell records,
recipe IDs, source URLs and reviewed recipe binding are retained in
`reference/research/crafting-audit.json`; earlier acquisition records remain in
`reference/research/hcclassic-source-records.json`.

In particular, [Elixir of Greater Defense](https://www.wowhead.com/classic/spell=11450)
requires Alchemy 195 and is trainer-taught; [Restorative Potion](https://www.wowhead.com/classic/spell=11452)
requires Alchemy 215. Both fit Expert Alchemy, whose training threshold is skill
125 and character level 20. Artisan primary-profession training starts at skill
200 and character level 35. Character-level gates are corroborated by the
[Classic Alchemy guide](https://www.wowhead.com/classic/guide/alchemy-leveling-1-300-wow-classic)
and [Classic Cooking guide](https://www.wowhead.com/classic/guide/cooking-leveling-1-300-wow-classic).
Secondary Expert skill books require skill 125 without an additional character
level gate; their Artisan quests require character 35 and skill 225.

Restorative is taught directly by [Badlands Reagent Run II (Alliance)](https://www.wowhead.com/classic/quest=2501)
or [Badlands Reagent Run II (Horde)](https://www.wowhead.com/classic/quest=2203),
whose final quest requires character level 40. The Alliance source lists
[Badlands Reagent Run](https://www.wowhead.com/classic/quest=2500) as its prerequisite;
the Horde source lists [Uldaman Reagent Run](https://www.wowhead.com/classic/quest=2202).
There is no tradable recipe item for this direct teaching. Smoked Desert Dumplings
similarly comes from [Desert Recipe](https://www.wowhead.com/classic/quest=8307)
and [Sharing the Knowledge](https://www.wowhead.com/classic/quest=8313), requiring
character level 54 and Cooking 285. These recipe quests are separate from
Artisan rank training.

All catalog recipe-item bindings were checked using their Classic item tooltips.
Bound exceptions include [Major Mana Potion](https://www.wowhead.com/classic/item=13501),
[Runn Tum Tuber Surprise](https://www.wowhead.com/classic/item=18267),
[Powerful Anti-Venom](https://www.wowhead.com/classic/item=19442),
[Living Action Potion](https://www.wowhead.com/classic/item=20013) and
[Major Troll's Blood Potion](https://www.wowhead.com/classic/item=20014).
Conversely, the [Dirge's Kickin' Chimaerok Chops quest recipe](https://www.wowhead.com/classic/item=21025)
is tradable; quest origin alone does not imply binding.

Current sold-by game data verifies [Major Healing Potion's Evie Whirlbrew vendor](https://www.wowhead.com/classic/item=13480),
[Superior Mana Potion's faction vendors](https://www.wowhead.com/classic/item=13477),
and all three [Powerful Anti-Venom vendors](https://www.wowhead.com/classic/item=19442).
Hasana, Lightspark and Miranda explicitly have friendly reactions to both factions.
Other vendor routes use explicit researched reaction pairs; missing reaction data
is omitted, never assumed neutral. Existing `FactionRules` take precedence.

[Blinding Powder](https://www.wowhead.com/classic/spell=6510) is trained as a Rogue
ability at character level 34. Its displayed skill-up difficulty of 170 is not
presented as a verified crafting prerequisite. Class conjurations also display
spell training levels instead of fictitious profession ranks. These metadata
changes do not alter automatic bandage, anti-venom or target-dummy selection.

## Gear and talent advisors

See [advisor data and scoring](advisors.md). The addon includes compact Classic
stat-weight tables and Hardcore talent paths, with an independent runtime.
The previous combat simulation and recovery experiments have been removed.
