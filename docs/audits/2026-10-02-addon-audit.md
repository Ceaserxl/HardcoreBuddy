# HardcoreBuddy: cross-class, level and interface audit

Audit date: 2026-10-02. Runtime examined: `5d1a47d` (v0.7.0 working tree). This audit adds evidence and tooling only; it does not change runtime behavior, saved character data, research caches, or a published release.

## Assessment

**The addon has substantial working functionality, but it is not yet consistent enough to call every recommendation and page correct.** The largest problem is that different screens make the same decision independently. Supply ordering, default selection, Essential classification, preparation highlights, gear eligibility, and explanatory text do not all consume the same resolved result.

There is one release-blocking validation mismatch, several reproduced user-visible defects, and important coverage gaps. The main gear/enchant arithmetic and auction stack optimizer performed well in the tested cases. A wholesale rewrite would discard working behavior; consolidate the decision and presentation boundaries in small, tested changes instead.

Priorities used below:

- **P1:** fix before the next release.
- **P2:** incorrect, missing, or misleading user-facing behavior; fix in the cleanup pass.
- **P3:** wording, presentation, or maintenance debt with lower immediate impact.

“Confirmed” means reproduced with the actual Lua modules in the offline harness, or directly established by the referenced source. “Coverage/policy” identifies a real limitation whose intended replacement needs to be made explicit. Neither label implies live WoW verification.

## Coverage and evidence

| Area | Executed coverage | Result and qualification |
| --- | --- | --- |
| Existing suites and local release package | 87 commands in an isolated copy of tracked working files | 77 passed, 10 failed initially; failure triage below |
| Supplies | 9 classes × levels 1–60 × 2 factions × profession skill 0/300 | 2,160 contexts, 86,224 records, 84,064 detail models; independent consistency observations |
| Enchants | 30 profiles; all nine classes, levels 1–60, both recommendation modes, roles, custom weights and builds | 1,072,626 existing assertions passed |
| Gear | Class/material/level restrictions, paired slots and weapon comparisons, score references and tooltip lifecycle | 41,112 existing assertions and 257 cross-material comparisons passed; uncovered eligibility/explanation cases below |
| Armor kits | Character/item levels, slots, existing augments, crafting, unknown data and refresh | 27,358 existing checks passed |
| Professions | Every learned/unlearned subset of the current bandage, anti-venom and dummy recipes, at every skill 0–300 | 313,040 independent strongest-learned-recipe comparisons; zero disagreements |
| AH refill arithmetic | 1,200 additional seeded markets with 1–9 whole-stack offers; exhaustive subset oracle | Zero disagreements on cost, overbuy tie-breaking and partial supply, within the current relative price ceiling |
| AH workflows | Per-row purchases, cached listing identity, multi-stack event ordering, own auctions, crafting, bank and mail accounting | Existing tests passed; these simulate server events, not live transactions |
| Class training | 1,324 catalog spell entries; all classes and levels, race/faction/talent labels, future/untrained views | Existing tests passed |
| Custom builds and talents | Bundle validation/sharing/editor, 9-class layout, legal paths and spending | 770 custom-build assertions, 3,515 layout checks and 4,228 talent assertions passed |
| Rotation/helper | Mage cast commitment, macros, cooldowns, handoff, predictions and shared consumable preparation | Existing named suites and matrices passed; does not establish combat optimality or timing in the live client |
| UI | 978 fixed-height supply rows; 750 settings geometry checks; 19 additional preview pages; pooled-frame lifecycle | Geometry tests passed; independent review found semantic styling differences and a clipped bandage warning |
| NPC/maps | Filters, exclusions, alerts, markers, zone tables, model loading, research pacing | Existing tests passed; cached coordinate validation also passed on rerun for 3,267 published pins |
| Packaging | Build local ZIP and boot its TOC/assets under Lua 5.1 | Passed, 231 packaged files; nothing published |

The supply matrix includes synthetic impossible class/faction pairs to stress filters. Health was modeled as `level × 55`, and the profession matrix deliberately includes recipe combinations a normal training path may not produce. These strengthen boundary testing but are not a census of real characters. “All classes/levels” describes these axes, not every possible combination of talents, items, buffs, inventory, server state, and screen configuration.

Evidence files:

- [Complete suite results and output](2026-10-02-suite-results.json)
- [Independent supply, food-weight and refill matrix](2026-10-02-matrix.json)
- [Focused reproductions and catalog inventory](2026-10-02-edges.json)
- [Cached coordinate validation](2026-10-02-coordinate-check.txt)
- [Settings overview](images/2026-10-02-settings.jpg), [scroll detail](images/2026-10-02-scroll.png), [bandage requirement clipping](images/2026-10-02-bandage.png)

Previews render the real addon frame tree with approximate fonts. Unresolved native Blizzard textures are placeholders, not evidence of broken in-game item icons. The settings overview covers the initially visible portion of each settings page; scrolling and dependency behavior are covered separately by the existing tests.

## Confirmed defects and inconsistent behavior

### F01 — P1: the release workflow runs a retired test that fails against the current helper

**Evidence:** [release.yml:50](../../.github/workflows/release.yml#L50) invokes `tests/run_rotation_removed.py`. That test still requires `A.ConsumableBuffs` to be absent. The current shared preparation implementation intentionally exposes it. The isolated release audit reproduced the failure.

**Impact:** a release run stops at this step even though the new helper's own tests and local package boot pass. `tests/release_workflow.py` validates tags/naming, so its success does not prove the entire workflow succeeds.

**Fix:** change the retired-feature test to check only artifacts that must remain removed, such as the old logger/UI. Keep the shared buff module, and make current helper validation part of the release checks.

**Acceptance:** execute the workflow's actual validation sequence from a clean checkout. Both legacy-removal boundaries and the current helper must pass before packaging.

### F02 — P2: a User item can silently lose its Essential classification

**Reproduction:** add item 5997, Elixir of Minor Defense, to User items. Mark the User entry Essentials. The User tab contains it, but All resolves the built-in `armor` family as Optional, and Essentials omits it.

**Cause:** [Core.lua:124](../../Core.lua#L124) permits a User entry duplicating a built-in item ID. [Supplies.lua:215](../../Supplies.lua#L215) deduplicates by item ID before applying the final Essentials filter. The built-in record wins over the User record and its priority.

**Fix:** define one effective record per exact item ID before category/priority filtering. Either attach the User preference to that record or make duplicate addition open the existing record with a clear explanation. Do not silently discard a saved priority.

**Acceptance:** add a built-in Optional item as User, mark it Essentials, and verify the same effective priority in User, All, Essentials, Missing Essentials, vendor refill and AH Essentials. Include conflicting targets and removal of the User override.

### F03 — P2: adding/removing User items does not invalidate Missing Essentials

**Evidence:** the focused reproduction successfully calls `EditUserItem` for add and remove; neither `Readiness:SuppliesChanged()` nor `Readiness:Refresh()` is called. Other preference edits already invalidate this panel. [Core.lua:124](../../Core.lua#L124) refreshes the main window only; [Readiness.lua:39](../../Readiness.lua#L39) owns the separate deferred panel refresh.

**Impact:** deleting an Essential User item can leave an obsolete row in an already visible Missing Essentials panel until another relevant event refreshes it. The source and invalidation probe establish the missing update; the visible live-client event timing remains to be checked.

**Fix:** route successful add/remove through the same coalesced supply-change notification used by quantity and priority edits.

**Acceptance:** with the panel open and no bag/zone event, remove a listed User item. It should disappear on the next refresh frame. Addition and duplicate-override changes must also invalidate the view.

### F04 — P2: build-weight ordering is not the common recommendation policy

**Reproduction:** a level-40 Mage with Stamina/Spirit weights 100 and MP5 weight 0 sorts Spider Sausage ahead of Sagefish Delight, yet Spider Sausage remains Optional and Sagefish Delight remains Essentials. Reversing the weights changes sort order but not classification.

**Cause:** [Guide.lua:23](../../Guide.lua#L23) scores supply alternatives using weights. [Supplies.lua:14](../../Supplies.lua#L14) chooses buff-food priority from a fixed class list. [RotationHelper/Buffs.lua:8](../../RotationHelper/Buffs.lua#L8) has another class-based preference. [Planner.lua:88](../../Planner.lua#L88) and `Guide.NextSupply` choose defaults/progression by different static rules. Some buff group names, such as `trollsblood`, are also not weight keys.

**Impact:** a custom build, healer/melee hybrid, or deliberately unusual profile can receive conflicting ordering, Essential status and preparation suggestions. This contradicts the requested “sorted by its score based on the build” behavior across supplies.

**Fix:** compute an effective profile and structured effect score once. Reuse the result for comparable defaults, alternatives and preparation preferences. Keep explicit player overrides authoritative. Do not compare unrelated jobs such as healing recovery versus escape utility as though they have interchangeable scores.

**Acceptance:** test all profiles plus extreme custom weights. Within each comparable/conflicting family, every consumer must agree on the winner, while user-selected defaults and manually chosen priority remain respected. Include hybrid caster/healer/melee profiles and zero-weight ties.

### F05 — P2: scored changes can be missing from the upgrade explanation

**Reproduction:** a profile with Fire Resistance weight 100 scores 10 Fire Resistance as 1,000 in both gear and enchants. Comparing 10 and 20 Fire Resistance returns no gain/loss explanation, even with the “all stats” path.

**Cause:** [GearAdvisor.lua:461](../../GearAdvisor.lua#L461) uses a separate fixed `lossStats` list. Resistance keys and other supported scoring keys are absent from it.

**Impact:** the displayed percentage can change without telling the player which important stat they gain or lose. In Hardcore, omitting a resistance loss is particularly misleading.

**Fix:** share normalized stat metadata between scoring, the weight editor and explanations. Audit every supported key; distinguish an unsupported effect from a true zero. Keep compact truncation only after building the complete change list.

**Acceptance:** for every editable scoring stat, construct a positive and negative delta and verify the full explanation reports it, including combined weapon setups. The existing score itself should remain unchanged.

### F06 — P2: cached-alt weapon eligibility lacks a talent/proficiency condition

**Reproduction:** `GearAdvisor.Allowed` accepts a synthetic low-required-level two-handed axe for a Shaman at levels 1, 10, 19, 20 and 60 without a learned-talent check. [AltAdvisor.lua:37](../../AltAdvisor.lua#L37) caches a profile/dual-wield information but not this enabling talent; [AltAdvisor.lua:146](../../AltAdvisor.lua#L146) uses the coarse eligibility function.

**Game-data check:** Classic's [Two-Handed Axes and Maces talent](https://www.wowhead.com/classic/spell=16269/two-handed-axes-and-maces) grants the relevant weapon access. Class membership alone is insufficient.

**Impact:** an offline alt comparison can recommend a weapon the cached character cannot equip. A native restriction on an item tooltip may still protect the live character; this audit does not establish an unsafe automatic equip.

**Fix:** cache the actual enabling abilities/proficiencies needed for eligibility and their freshness. Separate “class can train this” from “this character can equip this now.” Preserve the requested train-to-use notice for ordinary trainable ranged skills.

**Acceptance:** Shaman with/without the enabling talent, talent reset, stale/unknown cache, and refreshed cache. Repeat the same eligibility contract for other gated weapon capabilities.

### F07 — P2: lower scroll alternatives cannot be made the default

**Reproduction:** open Scroll of Intellect on a level-60 Mage. The page says Selected Alternative but has no default control. Setting the corresponding saved family default still leaves Scroll of Intellect IV on the root page.

**Cause:** [Supplies.lua:205](../../Supplies.lua#L205) resolves default groups through the main Planner item catalog. Scrolls are selected through their separate catalog path.

**Fix:** include scroll families in the same eligible-default resolution as other comparable supplies. Keep the strongest eligible rank as the automatic default when there is no explicit choice.

**Acceptance:** choose a lower scroll, set default, navigate away, reload a fresh runtime, and verify all consumers use it. Clearing the choice restores the automatic rank. A future unusable scroll must not become an active default.

### F08 — P2: Next items are duplicated in Alternatives

**Evidence:** 10,484 duplicate occurrences across the sampled detail models, not 10,484 distinct items. Examples include Strong Anti-Venom and Advanced Target Dummy. The scroll preview also shows the same progression item under Next and Alternatives.

**Cause:** [Companion.lua:352](../../Companion.lua#L352) builds Next and Alternatives independently; special bandage handling is more selective than several other families.

**Fix:** resolve selected/recommended/next/alternative identities first, then render. Exclude the selected and Next item from ordinary Alternatives. Preserve a recommended alternative marker when it adds information, without creating a duplicate row in two sections.

**Acceptance:** no duplicate exact item/augment identity across the right column for any supply family, including scrolls, dummy, anti-venom, food, ammo, enchants and armor kits. Keep Next above Alternatives and keep the standardized empty row when a section has no entries.

### F09 — P2: Blinding Powder has crafting metadata but no material rows

**Evidence:** item 5530 is marked craftable in [Data/Crafting.lua:67](../../Data/Crafting.lua#L67), but `Crafting.MaterialBlocks` returns no materials. There is no matching static auction recipe. Classic's [Blinding Powder spell](https://www.wowhead.com/classic/spell=6510/blinding-powder) lists one Fadeleaf reagent.

**Fix:** add structured reagent/output metadata to the common recipe model so the supply page can display it. Preserve Rogue/ability/recipe gates and the item's actual trade eligibility; do not blindly make every conjured/class reagent an AH purchase.

**Acceptance:** a learned Rogue recipe displays the correct reagent quantity; an unlearned recipe remains inspectable with its requirement. Reagent-free Mage gems must still have zero materials—those four empty-material observations are intentional, not missing data.

### F10 — P2: bandage alternatives have different styling depending on entry path

**Evidence:** opening the same bandage as a direct item versus the `supplyFamily` page produces different right-column flags. One path uses ordinary alternative rows; the family path marks them as tracked `supply` cards with stock states/borders.

**Cause:** separate builders in [Companion.lua](../../Companion.lua) reconstruct bandage rows instead of consuming one presentation model.

**Fix:** reuse the selected/next/alternative row contract. Keep the selected item and Materials tracked; use the same alternative styling as the other supply detail pages. Preserve bandage-specific health and learned-recipe information as concise data, not a separate layout implementation.

**Acceptance:** navigate from All, Essentials, the bandage family, a lower-rank alternative and a Next row. Equivalent states must produce identical row height, border/status policy, padding and toolbar controls.

### F11 — P2: the unavailable-bandage explanation overflows a compact row

**Reproduction:** Hunter level 32, maximum health 700, First Aid 80, with unavailable learned-recipe data. The recommended Mageweave Bandage row combines its effect/skill line with a long missing-profession/recipe sentence. It exceeds the two-line, 28px body region inside the fixed 56px card.

**Evidence:** [bandage preview](images/2026-10-02-bandage.png). [UI.lua:61](../../UI.lua#L61) enforces compact row geometry; the special bandage builder adds more text than fits. The 978 row-height checks pass because they check outer height, not visible text completeness.

**Fix:** retain the standard row size. Use a short requirement/status phrase and put the full explanation in the tooltip. Check the actual title and subtitle regions, not only the outer rectangle.

**Acceptance:** long item names, unknown recipe data, unavailable profession, smaller effective scale and normal game fonts. No text clipping or collision with stock/status, without expanding just one family's row height.

### F12 — P2: Back loses the dungeon source when a packing link opens Supplies

**Evidence:** `tests/run_instances.py` fails with `Supply Back lost instance`. A packing link opens a Supplies category root. The visible Back button clears history and remains in Supplies rather than returning to the instance.

**Cause:** [UI.lua:1134](../../UI.lua#L1134) applies the Supplies detail-to-tab-root rule to every Supplies state, even a root page reached from another area.

**Fix:** keep the requested behavior for Supplies item details: Back returns to that tab's main page. Limit that special case to detail navigation; preserve genuine cross-page history from a root page.

**Acceptance:** detail→Supplies root still works for every category; dungeon packing link→Supplies root→Back returns to the same dungeon, without resurrecting unnecessary submenu Back buttons.

### F13 — P3: automatic-bandage tooltip and User success copy describe old controls

**Evidence:** [UI.lua:125](../../UI.lua#L125) says the automatic choice is the best learned profession recipe, while current bandage selection deliberately defaults to the health recommendation. [Core.lua:140](../../Core.lua#L140) tells a user to set a Carry quantity “below” after adding an item, using old terminology/layout.

**Fix:** derive explanation text from the resolved selection reason: health recommendation, learned recipe, or explicit default. Use current Auto-buy amount / Refill amount labels and the actual editing location.

**Acceptance:** each selection reason has truthful tooltip text, and no current success message points to a removed or renamed control.

### F14 — P3: shipped documentation describes removed pages and controls

**Examples:** [README.md:171](../../README.md#L171) and [docs/advisors.md:70](../advisors.md#L70) describe the removed dump textbox; README's supply/bandage section still describes old Item Details/Show all behavior; [docs/enchants.md:52](../enchants.md#L52) describes the removed Show Lesser Ranks control. The advisor document also retains the old Advisors navigation.

**Fix:** rewrite those sections from current user flows after the behavior fixes settle. Keep archival notes explicitly labeled as historical rather than mixed into current instructions.

**Acceptance:** walk every documented button/page name against the current UI and packaged documentation. Remove obsolete controls from current help; retain the current Light of Elune exception.

## Coverage gaps and policies that need to be made explicit

### F15 — P2: a future health-based bandage becomes an active restock target

**Evidence:** 1,080 sampled skill-0 contexts select a bandage the character cannot yet use. This is expected for the explicitly requested health-based planning recommendation. However, [Supplies.lua:47](../../Supplies.lua#L47), [Readiness.lua:31](../../Readiness.lua#L31) and the AH Essentials item path carry the same selection into active shortage/refill evaluation without distinguishing use eligibility.

**Fix:** preserve the health recommendation and “set highest available as default” behavior. Add an explicit distinction between planning a future item and restocking an item usable now. At minimum, make the restriction unambiguous before buying; preferably exclude unusable automatic purchases until the user explicitly chooses to stock the future rank.

**Acceptance:** no First Aid, insufficient use skill, sufficient use skill but unknown recipe, learned lower rank, and explicit usable override. Do not confuse being unable to craft with being unable to use—a purchased bandage can be usable without its recipe.

### F16 — P2: the curated consumable catalog is too small to imply complete high-level recommendations

**Inventory:** 156 main supply records, 24 scrolls, 138 enchant recipes (including scopes), and 6 armor kits. Elixirs contains 19 records across seven families. Those counts establish internal coverage, not completeness against every Classic item.

**Verified omissions from the supply/recipe/buff identity paths:**

| Item | Why it belongs in the coverage review |
| --- | --- |
| [Elixir of the Mongoose, 13452](https://www.wowhead.com/classic/item=13452/elixir-of-the-mongoose) | Level 46 physical-stat/critical-strike consumable missing from the available comparison set |
| [Greater Arcane Elixir, 13454](https://www.wowhead.com/classic/item=13454/greater-arcane-elixir) | Level 47 spell-damage consumable missing from caster comparisons |
| [Elixir of Greater Firepower, 21546](https://www.wowhead.com/classic/item=21546/elixir-of-greater-firepower) | Level 40 school-specific consumable missing from fire-build comparisons |

The inventory probe also found several protection potions and Poison Cure absent. Their precise use, acquisition, rank and class/encounter relevance need a source-backed catalog pass before inclusion. Head/shoulder special augments likewise need an explicit scope decision; current enchant coverage is not every possible augmentation source.

**Fix:** maintain a reviewed inclusion/exclusion manifest. For each included item record use level, effects, stacking/conflict group, recipe/output, materials, acquisition and class/build applicability together. Add important missing comparison families first. Keep rare/expensive/situational items optional where appropriate; adding an item must not automatically make it Essential.

**Acceptance:** every eligible rank in an included family is either represented or has an explicit exclusion reason. A compound effect such as Agility plus crit is scored as both effects. Verify the upper-level Next chain does not terminate just because the catalog stopped early.

**Scope limit:** this was an internal full-catalog audit plus targeted external verification, not an exhaustive scrape of all Classic item/quest/vendor databases. It cannot certify that no other item is missing.

### F17 — P2: the AH price guard cannot detect an entirely overpriced market

**Reproduction:** a market containing only one unit priced at 100,000,000 copper (10,000 gold) is accepted by `RefillPlan`, with zero exclusions.

**Cause:** [AuctionRefillPlan.lua:5](../../AuctionRefillPlan.lua#L5) caps unit price at five times the cheapest current offer. If the cheapest is itself unreasonable, every relative calculation can still be correct while the recommendation violates the desire to avoid insane prices.

**Fix:** supplement the relative outlier rule with an explicit user budget/unit-price limit or a clearly sourced historical reference. When no trustworthy reference exists, show that uncertainty rather than calling the offer reasonable. Keep native purchase confirmation.

**Acceptance:** sole expensive listing, all-expensive market, legitimate price spike, mixed normal/outlier market and disappearing cheap stacks. The optimizer must still find the cheapest whole-stack plan inside the accepted policy. This is not evidence of an unconfirmed purchase or an arithmetic error.

### F18 — P2: unscored utility is treated as zero in some progression comparisons

**Evidence:** [Enchants.lua:85](../../Enchants.lua#L85) intentionally returns no numeric score for effects without a defensible model, including some proc/movement/threat effects. The detail progression path uses `E.Score(selected, profile) or 0` before finding a higher-scored Next augment.

**Impact:** a numerical stat upgrade is not automatically a better Hardcore choice than an unscored survival/utility effect. Conversely, inventing an arbitrary score would conceal the uncertainty.

**Fix:** represent `scored`, `utility preference`, and `unknown` separately. Use an explicit class/build utility policy and explain it. Do not describe an incomparable effect as strictly better solely because nil became zero. Keep armor kits and enchants in the same compatibility comparison.

**Acceptance:** selected Minor Speed, appropriate threat roles, proc enchants, explicit custom zero weights, and ordinary stat upgrades. Recommended/Next labels must reflect the chosen policy, not an accidental nil fallback.

### F19 — P3: empty Materials sections and unlabeled batch quantities add ambiguity

**Evidence:** scroll/vendor-only detail pages can retain a Materials section with no actual recipe; some say “No recipe materials listed.” For craftable items, [Crafting.lua:7](../../Crafting.lua#L7) shows recipe material quantities, not necessarily the amount needed to reach the character's refill target. The AH crafting planner separately handles yields and required quantities.

**Fix:** distinguish `not crafted`, `reagent-free ability`, `recipe data unknown`, and `known recipe`. Use the same intentional empty-row style if the standardized page keeps the section; otherwise omit a truly inapplicable section. Clearly identify a recipe batch versus target/refill quantities, or provide a concise quantity selector. Do not silently multiply enchant requirements that are meant to describe one application.

**Acceptance:** vendor water, a scroll, a Mage mana gem, a crafted consumable with output greater than one, Blinding Powder, an enchant and an armor kit. “Unknown” must never be presented as “no reagents needed.”

### F20 — P2: validation must test current contracts rather than historical page snapshots

**Evidence:** multiple failing suites encode superseded layout or catalog rules. The broad runner needed a separate research-cache rerun. Some fixed-height tests pass despite overflowing text. The release workflow does not invoke the complete modern suite.

**Fix:** separate authoritative current behavior tests, historical/reference comparisons, data-provenance checks requiring caches, and live-client checks. Publish one command that runs the required offline checks and returns a failure status. Preserve independent arithmetic oracles instead of testing a function against its own output. Put new ranking/default/duplication/text-fit contracts into that command.

**Acceptance:** a fresh checkout can run required checks with documented dependencies and fixtures. Known optional cache checks report an explicit skip instead of an unexplained file error. CI runs the same required set locally reported as passing.

## Additional data validation

### F21 — P2: NPC sentinel levels leak into the interface

**Evidence:** four catalog records contain a `9999` minimum/maximum level: Azuregos (6109), Anachronos (15192), Spirit of Azuregos (15481), and Qiraji Lieutenant General (15757). [MapAdvisor.lua:213](../../MapAdvisor.lua#L213) turns that value directly into level text for pin tooltips and table rows. [MapNPCViewer.lua:227](../../MapNPCViewer.lua#L227) also formats it directly. The zone-notice table has a separate sanity check, so different views can disagree for the same NPC. The focused evidence captures the actual tooltip and available table labels.

**Fix:** normalize sentinel/unknown/boss levels once at the data-to-view boundary. Display an appropriate boss/unknown indicator instead of a fictitious Level 9999. Preserve raw source values only in provenance where useful, and preserve legitimate level-61–63 creatures.

**Acceptance:** all four records, unknown levels, ordinary level ranges and legitimate above-60 bosses. Map tooltip, zone notice, Zone Advisor table and NPC model viewer must agree; filtering/sorting must not treat the sentinel as a real character level.

## Triage of the ten initial failures

| Suite | Classification | Correct response |
| --- | --- | --- |
| `run.py` | Archived website/catalog expectation predates expanded vendor foods; partial legacy load path | Separate historical parity from current catalog requirements; do not remove valid vendor alternatives to satisfy it |
| `run_button_hover` | Mock lacks native `UICheckButtonTemplate` hover behavior on four map checkboxes | Model native template behavior or constrain the assertion; verify native hover in WoW before changing skin code |
| `run_crafted_ammo` | Expects Alternatives before Next | Update to the requested Next-then-Alternatives order |
| `run_instances` | Reproduced runtime navigation defect | Fix F12, then rerun the complete suite past its first failure |
| `run_item_details` | Expects removed Item Details layout | Replace with current Recommended/Materials/Next/Alternatives contract |
| `run_global_layout` | Expects old side-by-side details block | Same: test current semantic sections instead of stale block indices |
| `run_page_alignment` | Expects old item-details column | Update semantic alignment expectations |
| `run_scrolls` | Fixed sidebar index predates reordered categories | Find the Scrolls control by identity; rerun all assertions after the failing one |
| `run_rotation_removed` | Obsolete assertion conflicts with intentional shared buff helper | Fix F01; retain tests that old logging/artifacts remain removed |
| `run_map_coordinates` | Isolated tracked-file copy lacks ignored research HTML cache | Cached rerun passed for 3,267 pins; make cache requirements/fixtures explicit |

After the cache rerun, nine failures remain in their original suites: eight stale/mock expectations and one reproduced navigation problem. One stale expectation also blocks the real release pipeline. Tests that stop at their first failing assertion do **not** establish that the unexecuted assertions would pass after correction.

## What passed, and what should be preserved

- No wrong-class root supply item, above-use-level root item, duplicate root item ID, Rogue/Warrior water recommendation, or selected-item identity mismatch was found in the sampled supply matrix. Future detail browsing was not incorrectly counted as a root recommendation.
- Gear and enchant resistance scores agreed in the focused test; F05 is an explanation omission, not a finding that those scores are wrong.
- The strongest learned profession recipe matched the independent oracle in all 313,040 cases.
- The independent 1,200-market auction oracle agreed with the optimizer. Existing tests also covered exact/overbuy, insufficient supply, recipe outputs, shared materials and queue event ordering.
- Enchant class/build filtering, armor-kit comparisons, ranged scopes and eligible off-hand rows passed existing tests. This does not make an unmodeled utility effect quantitatively optimal.
- Settings headers, paired sections, dependency disabling, scroll endpoints and ordinary row geometry passed the current offline checks. The settings preview review found no additional confirmed overlap in the visible default sections.
- The reported numeric model-bounds failure has a passing 730-frame regression, invalid-data checks and bounded retry coverage.
- Alt snapshot age boundaries, fresh empty slots and persistence tests passed. Keep legitimate empty-slot upgrades; extend capability metadata rather than suppressing all empty slots.
- The current helper suites passed their encoded expectations. This audit did not find grounds to claim live cast/glow timing is perfect or to redesign Mage combat based only on mock results.

## Information to remove, retain, or label differently

| Information/data | Action |
| --- | --- |
| Duplicate item in both Next and Alternatives | Remove the duplicate presentation, retain the item in the catalog |
| Old Show Lesser Ranks, dump textbox, Item Details and Advisors-tab instructions | Remove from current help; retain only explicitly historical material |
| “Best learned recipe” on a health-selected bandage | Replace with the actual reason |
| “No recipe materials listed” for a known noncraftable item | Replace with an intentional noncraftable state or omit the inapplicable section |
| Future/unusable recommendation appearing as ready-to-buy | Separate planning from usable restock eligibility |
| Light of Elune's special quest/macro view | Preserve; it deliberately has no generic Next/Alternatives or refill controls |
| User custom item detail with no Next/Alternatives | Preserve the requested exception |
| Duplicate Light Feather catalog entries for different class contexts | Retain their class metadata unless consolidated safely; current root deduplication works for them |
| Reagent-free Mage gems | Retain; an empty material list is correct |
| Previously excluded seasonal/reputation foods | Keep out of routine Supplies. Recognition/crafting/aura metadata may still be needed for owned items; its presence alone is not a recommendation leak |
| Non-Mage combat rotations | Do not treat absence as missing rows; current combat scope is Mage, with shared preparation support |
| Questie fallback/provenance records and research caches | Preserve. The 34 outstanding research entries need better sources; this audit does not prove their markers invalid |

## Recommended cleanup order

1. **Restore trustworthy validation:** F01 and F20; repair stale assertions against the accepted UI before using “all tests pass” as a release condition.
2. **Unify effective supply identity and state:** F02, F03, F04, F07 and F15. Resolve item identity, selected/default reason, eligibility, priority, target/refill, effect score and source once, then let the views consume it.
3. **Complete and normalize comparison metadata:** F05, F06, F09, F16, F18 and F21. Use structured effects and explicit capability/utility states; add reviewed missing items with complete materials and buff-conflict data, and normalize NPC sentinel levels.
4. **Consolidate detail presentation:** F08, F10, F11, F12 and F19. One row/section contract with explicit exceptions for Light of Elune and custom items; keep compact sizes and consistent Back behavior.
5. **Finish purchase policy and copy:** F17, F13 and F14. Explain cost limits and unknowns, then update the packaged help from the resulting UI.

Suggested resolved supply model: `identity`, `family`, `category`, `recommended`, `selected`, `selectionReason`, `usableNow`, `craftableNow`, `eligibilityReason`, `effects`, `scoreState`, `score`, `priority`, `target`, `refillAt`, `stockByLocation`, `materials`, `next`, `alternatives`. This is a proposed cleanup boundary, not an instruction to replace every module in one change.

## Required live-client verification after fixes

The offline suite cannot certify protected actions, actual fonts, third-party tooltip ownership, server latency or visual glow timing. The focused live pass should include:

1. Same item through All/category/Essentials/alternative/Next entry paths; smallest supported effective scale; long names and unknown item-cache state; hover and scrollbar endpoints.
2. User add/remove/default/priority changes with Missing Essentials visible and no intervening bag event.
3. A cached Shaman alt before/after the weapon talent and after a talent reset; fresh empty slots, old snapshots, logout and relog.
4. Vendor bundle/refill and AH purchases with changing listings, own auctions, insufficient money/bag space, material-only plans and mailbox collection. Confirm ordinary native confirmation remains intact.
5. Native/replacement bag tooltips with other installed tooltip addons; verify no blank tail, drawing outside bounds, flicker or omitted weighted-stat explanations.
6. Mage combat with real latency and macros; cast-start recommendation commitment, protected-action errors and missing action-bar spells. Passing scenario counts alone do not certify damage or survival optimality.
7. Map/model/zone notices in the actual client; source-valid coordinates are not a promise of a current live spawn.

No live game interaction, destructive reset, auction purchase, external message or release publication was performed for this audit.

## Reproduction commands

Use Python with the repository's existing Lupa/Pillow dependencies. On Windows, set `PYTHONUTF8=1` and `PYTHONDONTWRITEBYTECODE=1` to avoid locale failures and changes to tracked bytecode.

```text
python scripts/audit_addon.py --output .release/full-audit-NEW
python tests/audit_addon_matrix.py --output .release/audit-matrix-NEW
python tests/audit_addon_edges.py --output .release/audit-edges-NEW
python tests/run_map_coordinates.py
```

The broad runner snapshots tracked working files, preserves existing output directories, captures each result, builds a local ZIP and never publishes it. The two new audit probes are separate commands; they record observations without treating every deliberate exception as a defect, and fail if their independent arithmetic/profession oracles disagree. The coordinate check requires the preserved research cache; it was rerun read-only from the original workspace after the isolated cache error.
