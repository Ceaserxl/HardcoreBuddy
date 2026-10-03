# Audit fixes: 2026-10-02

Follow-up to [the original audit](2026-10-02-addon-audit.md). Changes apply to
v0.7.0 source; this task does not publish a release or modify live SavedVariables.

## Resolution register

| Findings | Resolution |
| --- | --- |
| F01, F20 | Release CI uses `python tests/run_all.py`. Legacy rotation-removal checks permit the intentional shared buff module. Current layout, ordering and navigation contracts replace obsolete assertions. Native XML hover is distinguished from mocked custom hover. Optional coordinate provenance explicitly skips without its cache. Unchanged historical profession/reference checks and independent arithmetic oracles remain. |
| F02, F03 | A duplicate User item's priority applies to its exact built-in item across views; cycling either representation edits the same preference. Exact-item quantities remain shared. Removing the User record restores built-in classification. Successful add/remove invalidates Missing Essentials. Known built-in use restrictions still apply to User copies. |
| F04 | Supplies, defaults, alternatives, progression and preparation share structured effect scores from the active build. Food uses Stamina/Spirit versus MP5, and Troll's Blood uses health regeneration. Comparable ordinary candidates drive automatic defaults; carried/learned sources drive preparation. Explicit priorities/defaults remain authoritative in supply planning. |
| F05 | Upgrade explanations derive from editable stat metadata and include resistances, regeneration, penetration, Feral attack power and weapon DPS, including combined replacements. Scoring arithmetic is preserved. |
| F06 | Alt snapshots cache the Shaman two-handed talent and capability provenance. Unknown old capabilities cannot borrow the logged-in character's abilities. Current class/talent restrictions apply before comparisons; ordinary trainable ranged notices remain. |
| F07 | Scroll families support eligible lower-rank defaults and persistent exact-item selection. |
| F08 | Selected, Next and Alternatives identities are distinct. Recommended markers survive when the recommended option is Next. Applies to ordinary supplies, profession items, scrolls, enchants and kits. |
| F09 | Blinding Powder has its Fadeleaf reagent, one-item output and Poisons 150 requirement in the common recipe system. |
| F10, F11 | Bandages use the ordinary supply detail builder from every entry path. The compact unavailable subtitle fits its fixed row; the full health/crafting explanation is on hover. Highest learned rank information remains available without duplicate items. |
| F12 | Supplies detail Back returns to its category root. A category root reached from a dungeon retains its real navigation history. |
| F13, F14 | Selection reasons and current control names replace obsolete Carry/learned-bandage text. README, advisor, enchant and preparation documents describe current pages and controls. |
| F15 | Planning recommendations remain visible; unusable items are excluded from Missing Essentials, vendor refill and AH Essentials. Use skill is independent of knowing the crafting recipe. |
| F16 | Added 16 reviewed supply items, including Mongoose, both Arcane/Firepower ranks, poison removal and protection potions, with recipe/material/effect metadata. [Catalog manifest](../supply-catalog.md) records included families and deliberate exclusions. This is not a claim of exhaustive Classic database coverage. |
| F17 | AH Essentials has a configurable per-unit gold budget, default 10g; 0 removes that budget. The existing 5x cheapest-offer ceiling also applies. Fully blocked plans show Price limit; partial plans retain their cost and explain exclusions on hover. Native confirmation remains. |
| F18 | Unknown/utility enchant scores stay incomparable; they no longer become zero when choosing Next. The slot shows No Directly Comparable Upgrade for such selections. No fabricated utility weights. |
| F19 | Materials distinguishes Not Crafted, No Materials Required and Recipe Materials Unknown. Known recipes identify per-craft quantities and multi-item output. Enchants retain per-application materials. |
| F21 | Shared NPC level formatting handles unknown/sentinel levels consistently in map tooltips, zone tables/notices and model viewers. Real level 61–63 ranges remain valid; unknown levels sort last. |

## Validation

The isolated tracked-file snapshot completed **88 commands with zero failures**:
85 executed validation suites, one explicitly skipped optional coordinate-cache
check, plus package construction and package boot. The ZIP contains 233 files.
The exact CI command, `python tests/run_all.py`, also completed successfully in
that snapshot (86 successful exits, including the same documented optional skip).
The cache-dependent coordinate check passed separately in the working checkout.
No publish step was run. Documentation edits afterward do not alter runtime behavior.

Evidence:

- [Full suite and package output](2026-10-02-fixed-suite-results.json)
- [Exact CI command output](2026-10-02-fixed-ci-validation.txt)
- [Cached coordinate check](2026-10-02-fixed-coordinate-check.txt)
- [Supply, text-fit and auction oracle matrix](2026-10-02-fixed-matrix.json)
- [Focused reproductions and profession oracle](2026-10-02-fixed-edges.json)
- [Compact bandage preview](images/2026-10-02-fixed-bandage.png)
- [AH purchase-limit settings preview](images/2026-10-02-fixed-ah-settings.png)

Additional independent coverage:

- 2,160 supply contexts, 96,468 records and 94,308 detail models.
- No duplicate right-column item observations, wrong-class records, selected-item
  identity mismatches or decreasing buff-power progression observations.
- Zero approximate text-fit candidates across the sampled detail layouts.
- 1,200 exhaustive auction-market subset comparisons: zero disagreements.
- 313,040 strongest-learned-recipe oracle cases: zero disagreements.
- Focused regression coverage includes duplicate User priorities, invalidation,
  weight extremes, scroll defaults, usable/unlearned bandages, all editable stats,
  cached Shaman capabilities, complete added recipes, budget limits and NPC levels.

Expected observations remain: four reagent-free Mage gems; the two class-specific
Light Feather records; and future health-recommended bandages that are inspectable
but excluded from automatic restock. The historical baseline evidence is retained.

## Verification boundary

Tests execute the real Lua 5.1 modules with mocked WoW APIs. Offline frame renders
use approximate fonts and placeholders for uncached native textures. They establish
logic and modeled geometry, not live auction-server behavior, protected actions,
actual client fonts or third-party tooltip ownership. The original audit's focused
live-client checklist remains applicable. Existing NPC research caches and the 34
fallback research entries are preserved.
