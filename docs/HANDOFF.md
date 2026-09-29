# Hardcore Field Kit — website-to-addon handoff

Prepared September 27, 2026. Website implementation baseline: commit `1595a17` in CXL-Website, following `7fc772d`. Research snapshots were checked September 26, 2026. This is the requested development handoff for a future World of Warcraft addon, not a replacement for this repository's `Project Instructions.md`.

## Objective and current status

Build an addon carrying forward the **Hardcore Field Kit** at <https://thecxl.net/hcclassic>. The original request was to replace the clunky `Potion_Elixir_Sheet.xlsm` spreadsheet with a compact, much richer webpage showing what a character should carry at their class and level. Subsequent work added researched food, emergency supplies, Hunter pet training, Warlock demon guidance and quiver upgrades.

The website is implemented and tested. **No addon, Lua implementation, game-client integration, TOC/interface version, addon name, or in-game validation has been delivered.** Do not describe website tests as proof of addon behavior. Treat addon architecture suggestions below as recommendations, not previously approved product features.

Scope is **Classic Era / official Hardcore, levels 1–60**, across Druid, Hunter, Mage, Paladin, Priest, Rogue, Shaman, Warlock and Warrior. Do not silently mix in Retail, TBC, Wrath, Season of Discovery or private-server mechanics. Recheck client-specific APIs and current mechanics when implementing the addon.

## User decisions to preserve

1. Show a **plain list of recommended items to have on the character**. Do not restore inventory quantities, item checkboxes, include/exclude selectors, packing progress, shopping-cart behavior or item selection buttons. The permitted global class/level/view controls are different from item selectors.
2. Be compact by default. A **Detailed view / Compact view** toggle reveals extra research. Keep useful data dense and avoid empty card space.
3. Website defaults are **Hunter, level 1, compact**. Existing choices persist. Level is a numbers-only text box with adjacent minus/plus buttons, bounded to 1–60; arrow keys, Enter and blur normalization work.
4. On the website this lives under **Tools → HC Classic**, not Play.
5. First cards, in order: **Food & drink**, **Potions & elixirs**, **Emergency supplies**. Companion/equipment guidance follows them.
6. For Hunters, keep **pet and quiver cards side by side** when width permits; pet gets about two-thirds of the row. Stack them on narrow layouts.
7. Hunter pet choices have three visible categories: **Offensive**, **General**, **Defensive**. These are descriptive family roles, not interactive selectors or talent specializations.
8. **Do not recommend rare pets.** Show current useful skill ranks and actual common creatures to tame for them, with levels and locations.
9. Warlocks should see which demon to use and when, including utility unlocks.
10. Include quiver upgrades and the matching ammunition-pouch path for guns.
11. All Troll's Blood ranks belong with normal elixirs. Include Advanced Target Dummy and other dummy ranks. Agility is relevant to several weapon-using classes, including Warriors.
12. Rank acquisition from easy to hard, while explaining recipe, skill, faction, quest, seasonal and dungeon prerequisites. A usable item is not necessarily easy or safe to obtain.

## Files the addon developer should receive

**Send this document together with the data and logic below. This document summarizes behavior; it does not reproduce every item tooltip, NPC source or rank record.** Preserve numeric item/NPC IDs and provenance when converting data to Lua.

All following paths are relative to the repository root:

| File / directory | Purpose |
| --- | --- |
| `Potion_Elixir_Sheet.xlsm` | Original input workbook; preserve as provenance, do not run macros |
| `frontend/src/hcclassic/recommendations.json` | Active reviewed carry-list data: 121 recommendation records covering 120 distinct items |
| `frontend/src/hcclassic/planner.js` | Actual item filtering, ranking, grouping, class notes and website profile logic |
| `frontend/src/hcclassic/companions.json` | Reviewed family data, 9 selected ability progressions and common tame sources |
| `frontend/src/hcclassic/companions.js` | Hunter rank eligibility, category suggestions and Warlock recommendations |
| `frontend/src/hcclassic/quivers.json` | 13 verified Classic quiver/ammo-bag item records |
| `frontend/src/hcclassic/quivers.js` | Routine equipment progression and next upgrade |
| `frontend/src/hcclassic/HCClassic.jsx` | Main list, order, compact/detail content and controls |
| `frontend/src/hcclassic/CompanionGuide.jsx` | Pet categories, skill cards, full rank roadmaps, family groups and demon guidance |
| `frontend/src/hcclassic/QuiverGuide.jsx` | Routine bags and optional quest/dungeon/raid routes |
| `frontend/src/hcclassic/hcclassic.css` | Dense visual hierarchy and responsive layout |
| `frontend/src/hcclassic/catalog.json` | Original workbook import; historical, **not the active planner dataset** |
| `frontend/research/hcclassic-source-records.json` | Consumable research evidence; 159 records, 158 available items and one unavailable workbook entry |
| `frontend/research/companion-source-records.json` | Full Petopia audit: 17 families, 21 abilities, 111 ranks, source URLs/hashes |
| `frontend/research/companion-npc-verification.json` | Classification evidence for 59 selected non-rare NPCs |
| `frontend/research/quiver-source-records.json` | Original Classic item-tooltip evidence for ammunition bags |
| `frontend/research/hcclassic-research.md` | Food, potion, emergency, acquisition and cooldown research decisions |
| `frontend/research/hcclassic-companions.md` | Pet, demon, bag research and important rank gaps |
| `frontend/hcclassic-validation.md` | Historical tests, measurements, limitations and visual evidence |
| `frontend/public/images/hcclassic/` | Locally served website item icons |
| `artifacts/hcclassic/` | Rendered screenshots from the work |

**Important traps:** `catalog.json` retains the workbook's level-24 default and inclusion flags. Those are historical and must not override the active Hunter-level-1 default or reintroduce item selection. The full unfiltered Petopia source audit can contain rare names; use curated recommendations for user-facing tame suggestions. Some IDs appear in more than one recommendation record (for class-specific gates), so do not collapse records solely by item ID.

## Carry-list data contract and algorithm

`recommendations.json` contains `checkedOn`, `researched`, and `items`. Each record has a stable string `id`, numeric `itemId`, name, family, group, classes, use `level`, acquisition `ease`, route, short description, detail, icon and source references. Optional fields include:

- `recommendLevel`: a recommendation/acquisition/spell gate distinct from item use level. Eligibility uses `recommendLevel ?? level`.
- `useSkill` / `craftSkill`: `{name, value}` objects. Use and craft requirements must remain separate.
- `power`: explicit family strength; otherwise rank selection falls back to level.
- `preference`: reviewed tie-break for similarly strong alternatives.
- `alternative`: an optional/specialist record, not the routine default.
- `binding`, `ingredients`, `caution`, `verifiedOn`, `spellSource`, `recipeSource`, `guideSource`, `acquisitionSource`, `reference`.

Port `buildList` rather than inventing a new sort based only on item level:

1. Filter to matching class (`All` or explicit membership) and eligible recommendation level.
2. Group by item family, using families with a non-alternative record.
3. Choose the strongest usable routine recovery/elixir rank. Compare descending `power ?? level`, then ease, then reviewed preference, then alphabetical name.
4. Well Fed and mana-food defaults additionally restrict candidates to ease 0–2, favoring repeatable food over hard-to-obtain theoretical best food.
5. Bandages, target dummies and anti-venom are grouped profession/utility families. Do not infer a profession rank from character level. Preserve their explicit progression and use requirements.
6. Sort selected rows by acquisition ease, then name, within their display section. This is not the same as globally choosing the cheapest item regardless of strength.
7. Preserve eligible alternatives, progression and the next recommendation-level unlock. Match the exact `options` filtering in `planner.js` when reproducing parity.
8. Detailed-only additional groups are Specialist food alternatives, Route-specific backups and Advanced emergency options, followed by ranking explanations.

| Stored ease | Label | Interpretation |
| --- | --- | --- |
| 0 | Vendor | Ordinary finished-item stock, subject to actual vendor availability |
| 1 | Simple craft | Routine recipe/class creation; materials and skill still needed |
| 2 | Recipe / travel | Recipe supplier, gathering/fishing or travel |
| 3 | Farm / limited | Random recipe/drop, constrained quest supply or inconvenient farm |
| 4 | Special access | Seasonal, dungeon, reputation or late-game prerequisites |

These are editorial effort bands, not live auction prices, stock or guaranteed availability. Faction, known recipes, professions and nearby materials can change the practical order.

## Food, drink, potions and emergency behavior

### Food and class emphasis

Vendor recovery food and water progress at use levels 1, 5, 15, 25, 35 and 45. Recovery food is separate from Well Fed buffs. Stamina/spirit food is the general leveling baseline; mana-regeneration food is an alternative for mana users. Choose food buffs appropriate to the build, not every listed food as simultaneous buffs.

- Druid: stamina baseline; Feral can use Agility/Strength, caster/healer builds can favor mana regeneration; keep water.
- Hunter: stamina baseline, mana food for downtime, later damage food such as Grilled Squid. Pet food must match pet diet/level and does not give player-food stat buffs to pets.
- Mage: trained conjured food/water can replace vendor supplies; stamina remains useful.
- Paladin: stamina baseline/tanking; Strength for Retribution, mana support for healing.
- Priest and Warlock: stamina buffer and mana support; bandages can save mana. Warlock creates a Healthstone before leaving safety.
- Rogue: stamina baseline, later Agility food, Thistle Tea and trained escape reagents; no mana-water default.
- Shaman: stamina baseline, Strength for Enhancement or mana support for caster/healer play.
- Warrior: stamina or Strength; later Agility food, bandages and emergency tools matter particularly without self-healing.

Easy food progression includes eggs/wolf meat, clam/crab/meat dishes, Goblin Deviled Clams, Roast Raptor and Spider Sausage. Later Tender Wolf Steak/Monster Omelet improve recovery without increasing the same stamina/spirit buff. Recipe faction and access still matter. Smoked Sagefish is item **21072**, not raw fish 21071. Nightfin Soup's checked tooltip gives a **10-minute** buff. Grilled Squid is seasonal; Runn Tum Tuber Surprise is dungeon-related; Smoked Desert Dumplings has late-game Silithus access. Harder food remains optional/detailed.

### Explicit potion changes

- Troll's Blood is a normal `trollsblood` family under **Potions & elixirs**, for every class: Weak 1, Strong 15, Mighty 26, Major 53. Show the strongest eligible rank, retain lower ranks in details and the next unlock. Mighty has a world-drop recipe; Major's recipe has Zandalar Tribe reputation access.
- Agility elixirs apply to **Hunter, Rogue, Druid, Warrior, Paladin and Shaman**, not the three pure caster classes. Tiers: Minor 2, Lesser 18, normal 27, Greater 38. This is weapon-build guidance for crit/dodge/armor, not a spell-damage claim.
- Recovery potions remain important; sustained elixir buffs are optional preparation. Do not imply that all buffs/cooldowns can be stacked freely.

### Emergency tools and gates

- Compact Target dummies lists all three: Target Dummy — Engineering **85**; Advanced Target Dummy — **185**; Masterwork Target Dummy — **275**. Choose the rank actual Engineering allows. Do not hide Advanced behind detail mode or select it using character level.
- Bandages depend on **First Aid use skill**, not character level or crafting skill. Preserve all ten rank thresholds from the data. Heavy Runecloth uses First Aid 225; making it requires more. Incoming damage interrupts bandaging.
- Anti-venom limits refer to **poison level**, not minimum player level. Powerful Anti-Venom also has First Aid 300 use and reputation-recipe requirements.
- Healthstone creation gates: **10, 22, 34, 46, 58**. These differ from item use levels. Displayed healing is untalented baseline.
- Mage mana-gem creation gates: **28, 38, 48, 58**. Light Feather appears for Mage Slow Fall at **12** and Priest Levitate at **34**.
- Rogue Flash Powder follows Vanish **22**; Blinding Powder follows Blind **34**. Thistle Tea is Rogue-specific, with recipe access separately documented.
- Free Action Potion prevents control effects; it does not clear existing stuns/slows. Limited Invulnerability is physical protection, not universal spell immunity.
- Sticky Glue, Slumber Sand and Light of Elune are finite quest supplies; retain faction and bind-on-pickup cautions. Magic Dust is a random drop. Jungle Remedy's farm is above its nominal use requirement. Felwood plants need cleansing-quest/salve access.
- Healing, mana and escape potions compete for their potion cooldown. The guide also cautions about shared interactions between Healthstones, mana gems, target dummies and Felwood healing plants. These observations are **not an exhaustively game-client-validated cooldown simulator**; revalidate exact interactions before implementing real-time cooldown logic.
- Self Found excludes trading, auction house and mail. Other-class Healthstones require trading. Do not recommend normal battleground vendor/reputation routes as official Hardcore defaults. Soulstone resurrection and Divine Shield + Hearthstone escape are not Hardcore rescue plans.

## Hunter pets

### Category presentation

Compact mode shows three categories at once; it does not ask the player to select a category:

| Category | Full family membership | Highlighted leveling choices |
| --- | --- | --- |
| Offensive | Bats, Cats, Owls, Raptors, Spiders, Wind Serpents | Cat for single-target damage; owl for Screech utility |
| General | Carrion Birds, Hyenas, Wolves | Wolf early; carrion bird once a practical Screech source is available |
| Defensive | Bears, Boars, Crabs, Crocolisks, Gorillas, Scorpids, Tallstriders, Turtles | Boar for Charge/flexible feeding; bear for health/broad diet |

These assignments follow Petopia; an owl stays Offensive despite Screech's defensive value. Detailed view groups all 17 families under these headings with diets and compatible abilities.

Current example selection, implemented in `hunterPetCategories`:

- Offensive: Durotar Tiger before 32, Stranglethorn Tiger from 32; Strigid Hunter before 48, Ironbeak Owl from 48.
- General: Prairie Wolf before 16, Greater Fleshripper at 16–31, Salt Flats Vulture from 32.
- Defensive: Elder Mottled Boar and Scarred Crag Boar as common examples.
- Before level 10, show category guidance but no eligible tame examples. Complete the taming/feeding/training quest sequence first.

Examples are not mandatory replacements at each threshold. A happy, trained pet kept at your level remains useful. Starter examples do not imply a low-level fresh tame will instantly match the player. Westfall is an Alliance route; Horde can retain a local pet until the Thousand Needles option. Check the individual spawn level and travel risk.

### Ability selection and training

Primary compact skill rows: Growl, Screech, Claw, Bite; add Dive and Dash at character level 30. The detailed roadmap additionally includes Charge. Great Stamina and Natural Armor appear as trainer ceilings in training guidance. The complete 21-ability audit is broader than this curated set of nine abilities.

For each ability rank:

- Trainer availability begins at `max(10, petLevel)`.
- A routine tame-source rank begins at `max(10, petLevel, minimum eligible routine NPC level)`.
- Routine sources must be verified **Normal** creatures outside dungeon/raid zones. Rare creatures are excluded entirely from recommendations. Elite/dungeon sources are not routine defaults.
- Use the highest available routine rank, expose the next obtainable rank, and retain restricted/no-source ranks in the detailed roadmap.
- The website assumes pet level equals selected character level and explicitly warns when the pet is behind. An addon must not silently promote skills using character level when actual pet level is lower.

Critical regression boundaries:

| Ability | Pet requirement | First selected routine Hunter level / source |
| --- | --- | --- |
| Screech 1 | 8 | 16 — Greater Fleshripper |
| Screech 2 | 24 | 32 — Salt Flats Vulture |
| Screech 3 | 48 | 48 — Ironbeak Owl |
| Screech 4 | 56 | 56 — Monstrous Plaguebat |
| Claw 4 | 24 | 25 — Elder Ashenvale Bear |
| Claw 5 | 32 | 34 — Scorpashi Lasher |
| Claw 8 | 56 | 57 — Winterspring Screecher |
| Bite 7 | 48 | 49 — Saltwater Snapjaw |
| Dive 1 | 30 | 31 — Young Mesa Buzzard |
| Dash 1 | 30 | 32 — Stranglethorn Tiger |
| Dash 3 | 50 | 54 — Blackrock Worg |

Bite 8 has an optional Bloodaxe Worg dungeon route; keep routine Bite 7 until actually learned. Charge 4 has **no known training source**; skip it. Do not invent a source or use a rare to fill gaps. Exact full progressions, NPC IDs, spawn ranges, zones and training-point costs live in `companions.json`.

Bite costs 35 focus with a 10-second cooldown. Claw costs 25 and spends focus repeatedly subject to the global cooldown. Screech costs 20, deals single-target damage and reduces nearby melee attack power. Rank differences and focus budget matter; there is no universal Bite-versus-Claw winner. Cat: learn Bite/Claw and manage Claw so Growl is not starved. Owl: prioritize Growl/Screech, optional Claw. Owls cannot learn Bite; bats cannot learn Claw. Solo Growl on, Cower off; avoid interfering with nearby crowd control.

Training flow: stable main pet, tame a common source, feed it and let it use the skill until learned, retrieve the main pet, teach through Beast Training. Recipient family, level, loyalty/training points and four-active-skill limit apply. Lower ranks may be skipped. Trainer maximum stamina/armor ranks are not a promise that every maximum is affordable at once.

## Warlock demons

Recommendations assume the demon quest is completed and its abilities are trained; level alone does not prove ownership.

| Level | Guidance |
| --- | --- |
| 1–9 | Imp after starter quest; early damage, no Soul Shard for its summon |
| 10+ | Voidwalker as cautious solo default; let Torment establish threat; damage can still pull aggro |
| 16+ | Sacrifice grimoire enables emergency absorb; consumes the Voidwalker |
| 20+ | Succubus / Incubus alternative for faster single-target Affliction/drain-tanking play |
| 26+ | Seduction grimoire; humanoid control breaks on damage |
| 30+ | Felhunter for magic dispel; **not yet Spell Lock** |
| 36+ | Spell Lock grimoire enables the interrupt |

Imp remains a group stamina/ranged-damage option. Voidwalker is a defensive recommendation, not a universal fastest-leveling or guaranteed-threat claim. Soul Link/Dark Pact depend on talents. Manage pet position, passive/follow, Soul Shards, Health Funnel and replacement summons. Infernal/Doomguard are situational, not normal leveling companions.

Current rank tables in `warlockPlan`:

- Firebolt: 1, 8, 18, 28, 38, 48, 58.
- Blood Pact: 4, 14, 26, 38, 50.
- Torment: 10, 20, 30, 40, 50, 60.
- Sacrifice: 16, 24, 32, 40, 48, 56.

Compact shows skills for the recommended primary demon; Detailed view shows all applicable tracked skill ranks. This is not a complete catalog of every demon ability.

## Quivers and ammunition pouches

Show both weapon paths without adding another selector. Quivers serve bows/crossbows; pouches serve guns. Equip the appropriate bag. Percentages are total ranged attack-speed bonuses, not additive gains per tier or stackable bonuses from multiple bags.

| Level | Quiver (ID) | Ammo pouch (ID) | Slots | Speed | Routine route |
| --- | --- | --- | --- | --- | --- |
| 1 | Small Quiver (5439) | Small Shot Pouch (5441) | 8 | 10% | Vendors |
| 10 | Medium Quiver (11362) | Medium Shot Pouch (11363) | 10 | 10% | Vendors; storage-only upgrade |
| 30 | Heavy Quiver (7371) | Heavy Leather Ammo Pouch (7372) | 14 | 12% | Leatherworker / AH; self-craft for Self Found |
| 40 | Quickdraw Quiver (8217) | Thick Leather Ammo Pouch (8218) | 16 | 13% | Leatherworker / AH; self-craft for Self Found |

Detailed optional routes:

- Quiver/Bandolier of the Night Watch (3605/3604): 12 slots, 11%; Alliance Duskwood quest chain, minimum quest level 18 but final quest level 30. Do not portray this as a safe level-18 shopping trip.
- Ribbly's Quiver/Bandolier (2662/2663): requires 50, 16 slots, 14%; Blackrock Depths drop, optional group route.
- Ancient Sinew Wrapped Lamina (18714): requires 60, 18 slots, 15%; Hunter epic quest path beginning with Ancient Petrified Leaf in Molten Core; quiver turn-in needs Mature Blue Dragon Sinew.

Keep the level-40 routine recommendation through 60 until an optional upgrade is actually obtained. Acquisition readiness is separate from equipment eligibility. Do not substitute unavailable Hardcore battleground reputation bags.

## UI, persistence and refresh work already completed

The website uses a near-black/graphite, antique-gold and warm-white palette, local icons, compact bordered cards and readable text. Compact carry cards use three columns on wide desktops, two on tablets and one on phones. Ordinary compact rows were tightened to about 48px while preserving 12px mobile descriptions. Detailed mode has wider reading layouts and expanded sources, ingredients, cautions, alternatives and rank requirements.

Hunter pet/quiver cards share a 2:1 desktop row below the carry list and stack at 1000px and below. Pet categories use three columns where space permits and stack below 600px. Warlocks receive a single demon card. Other classes have no irrelevant pet/quiver guide.

Website profile cookie: `cxl-hcclassic-v3`, one-year lifetime, `Path=/hcclassic`, `SameSite=Lax`, Secure on HTTPS. Stores `characterClass`, `level`, `detailed`. It is authoritative over legacy local storage. When no cookie exists, only character/view preferences migrate from `cxl-hcclassic-v2` / `v1`; inventory fields are discarded. Invalid profile values return to Hunter/1/compact. Blocked cookies show a temporary-preference notice without breaking the page.

The reported hard-refresh animation defect was reproduced with cache disabled: the page appeared beneath the exiting splash, then a boot effect reset opacity and translated it again. The fix prepares the page during the splash hold and prevents splash unmount from restarting the entrance. Frame-by-frame tests confirm opacity 1/top 0 after handoff and restored scrolling. This was an animation ownership fix, not a request to clear browser cache. This web-only splash/navigation infrastructure does not need to be ported to an addon.

## Suggested addon adaptation — not implemented yet

- Use the checked-in data and selection logic as the behavioral baseline. Generate Lua data from reviewed JSON rather than manually retyping hundreds of fields. Keep generation deterministic and retain source dates, item IDs and NPC IDs.
- Preserve separation between data, pure recommendation selection, game-client state and UI rendering. Keep the offline/reference planner useful even when live information is unavailable.
- Replace browser cookies with appropriate addon persistence. Prefer actual character class/level for a live-character view; keep Hunter/1 as the existing reference-preview default if a preview is implemented. Automatic detection and preview controls are addon design choices, not completed website features.
- Verify the target Classic client build, interface version, Lua APIs, events, skill/pet data access and persistence semantics before naming or depending on them. This handoff deliberately does not guess a TOC version or API contract.
- If actual profession skills, pet level or learned abilities can be read reliably, distinguish known, available-to-learn and future ranks. Preserve the explicit unknown state when information is missing. Do not invent known recipes, completed quests, inventory or cooldown readiness.
- Actual inventory scanning, equipment detection, learned-skill detection, faction filtering, talent handling, reminders, minimap buttons, slash commands and automatic item-use buttons have **not** been requested/implemented here. Treat them as separate scope decisions. In particular, do not let inventory features reintroduce the rejected quantity/checklist workflow.
- Package required reference data with the addon; the website already renders from local data without runtime third-party requests. Research refresh is a development workflow. Check source/asset reuse permissions for distribution and verify client-native icon/item-link options.
- Build an informational guide first. Verify any future protected-action or combat interaction against the actual client instead of assuming web buttons translate to game actions.

## Validation and acceptance for the port

Historical website evidence is in `frontend/hcclassic-validation.md`; it is not a new rerun or game-client certification. Latest focused companion/category runs passed six model tests, two browser tests and a production build. Earlier combined planner/companion run had 15 model tests before the category test was added; planner tests separately cover all nine classes at every level (540 combinations). Screenshots cover 320, 390, 768 and 1440px, compact/detailed states, category layout and pet/quiver alignment.

Port the meaningful test cases from:

- `frontend/src/hcclassic/planner.test.js`
- `frontend/src/hcclassic/companions.test.js`
- `frontend/tests/hcclassic.spec.js`
- `frontend/tests/companions.spec.js`
- `frontend/tests/pet-categories.spec.js`

`frontend/tests/splash.spec.js` is website-only animation regression coverage.

Addon acceptance should include real-client checks for initial load, reload/relog persistence, class/level changes, view toggle, resizing/UI scale, category/order, unavailable data, skill gates and absence of errors. Compare outputs against website fixtures at level boundaries, not just one high-level character. Cover Troll's Blood 1/15/26/53; Agility 2/18/27/38; all dummy profession ranks; pet taming at 10 and the rank gaps above; Warlock 10/16/20/26/30/36; bags 1/10/30/40/50/60. No rare pet may enter a displayed recommendation. All 17 families must appear exactly once in detailed categories. Actual pet-level and profession gates must not be replaced by character-level assumptions.

Inspect real pixels and behavior at the intended game UI scales. Unit tests and a successful package build cannot substitute for an addon loaded in the correct game client. State clearly what remains untested if no client is available.

## Website maintenance and reproducibility

Current workspace: `/mnt/user/projects/CXL-Website` on `cxlserver` (Unraid). Existing development container: `TheCXL-Network-Website`, repository mounted at `/app`; Vite 9080 proxies FastAPI 9081. Use this container for website tooling; no disposable helper containers. The webpage changes used the existing mounted source and did not require a service restart.

Typical validation commands (from the host):

```bash
docker exec -w /app/frontend TheCXL-Network-Website node --test src/hcclassic/planner.test.js src/hcclassic/companions.test.js
docker exec -w /app/frontend TheCXL-Network-Website npx playwright test tests/hcclassic.spec.js tests/companions.spec.js tests/pet-categories.spec.js
docker exec -w /app/frontend TheCXL-Network-Website npm run build
```

Research/import tools under `frontend/scripts/`:

| Script | Purpose |
| --- | --- |
| `import-hcclassic.py` | Parse workbook zipped XML without executing macros |
| `research-hcclassic.py` | Collect Classic item/spell/acquisition references |
| `curate-hcclassic.py` | Apply reviewed class, effort and acquisition corrections |
| `research-companions.mjs` | Parse Petopia tables/families and record source hashes; does not execute downloaded site scripts |
| `curate-companions.py` | Select routes, verify exact rank source membership and reject rare NPCs |
| `research-quivers.py` | Collect Classic ammo-bag tooltip fields |

Run collectors deliberately, with network access, and review source changes before replacing curated data. Drop-table source samples are not exhaustive. A missing vendor/trainer relation is not proof of absence. Keep actual in-game validation separate from website snapshot evidence.

Two unrelated pre-existing worktree changes were deliberately left untouched throughout this work: the `start.sh` mode change and deletion of `artifacts/palworld-status-corner.png`. Do not include them in an addon/handoff commit. Preserve the working website while developing the addon in a deliberate separate destination. Addon destination and deployment have not been specified.

## Change history

| Commit | Work completed |
| --- | --- |
| `d20b6ac` | Initial workbook-based HC Classic page |
| `93d21ec` | Researched carry list, food and emergency supplies; removed inventory workflow |
| `3b33763` | Corrected measured mobile baseline in validation documentation |
| `0f40153` | Hunter/1 cookies, numeric level controls, Tools navigation, denser rows and splash handoff fix |
| `bcf725f` | All Troll's Blood ranks in normal elixirs |
| `9e2d684` | Visible dummy ranks and broader Agility class coverage |
| `7fc772d` | Pet ranks/common tames, demon guidance, quiver progression; carry cards first, pet/quiver side by side |
| `1595a17` | Offensive / General / Defensive choices and all-family grouping |

## Primary reference entry points

- [Petopia Classic](https://www.wow-petopia.com/classic/), [abilities](https://www.wow-petopia.com/classic/abilities.php), [training](https://www.wow-petopia.com/classic/training.php).
- [Classic food guide](https://www.wowhead.com/classic/guide/wow-classic-best-food), [First Aid](https://www.wowhead.com/classic/guide/first-aid-leveling-1-300-wow-classic).
- [Warlock demons](https://www.wowhead.com/classic/guide/wow-classic-warlock-demon-pets), [leveling](https://www.wowhead.com/classic/guide/classes/warlock/leveling-tips), [Hardcore guidance](https://www.wowhead.com/classic/guide/classes/warlock/hardcore-leveling-tips).
- [Ammo bags](https://www.warcrafttavern.com/wow-classic/guides/ammo-bags-and-ammunition/), [Night Watch quest](https://classicdb.ch/?quest=58), [Hunter epic quest](https://www.wowhead.com/classic/guide/classic-hunter-quest-ancient-petrified-leaf).
- [Blizzard Hardcore rules](https://worldofwarcraft.blizzard.com/en-us/news/23973734), [Self Found rules](https://worldofwarcraft.blizzard.com/en-us/news/24056987/wow-hardcore-self-found-mode-begins-february-29).

Exact item/spell/NPC references and additional research comparisons are in the checked-in datasets and focused research documents. Recheck disputed or client-sensitive facts; do not turn editorial defaults into claims that one pet, demon, food or route is universally optimal.
