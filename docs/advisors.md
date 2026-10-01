# Gear and talent advisors

Open **Advisors** in the main window. The sidebar offers **Gear** and **Talents**.
Choose builds in **Settings > Talent Advisor**. `/hcb gear` and `/hcb talents`
open the advice pages.

WoW's existing talent rank text shows **current rank / recommended rank** for the live
character's selected build, such as **2/5**. The target is blue when more points
are recommended, green when met, and red when the current rank exceeds the
build's target. Targets describe the complete selected path. Unused talents
without any points retain the normal display. The original rank border widens
to fit the numbers; no overlay badges, textures or additional labels are created.
Talent clicks are unchanged. Pet and inspection views do not
show player recommendations. There is no separate attached panel; the complete
scrollable path remains in **Advisors > Talents**.

Both Settings pages have independent enable/disable buttons. Disabling Gear
Advisor removes tooltip advice and upgrade markers and stops auction upgrade
scanning. Tooltip/marker preferences, weights and saved scans are retained.
Disabling Talent Advisor restores native rank numbers, visibility and border
sizes, hides recommendations and blocks
point spending through the advisor. Its chosen build remains available to gear
scoring. Reenable it from **Settings > Talent Advisor**. These switches persist
across reloads.

## Gear scoring

The score is the sum of each intrinsic stat multiplied by the chosen profile's
weight. The displayed change is `(new score * 100 / replaced score) - 100`, rounded
down to two decimals, matching the reference display, including negative changes.
This measures the relative item score, not simulated DPS or
survival. Zero-score and empty baselines have descriptive labels.

Thirty Classic profiles cover every talent tree in all nine classes, plus Feral
tanking, melee Hunter and Fury/Protection. The live character's Talent Advisor
build selects the scoring profile; there is no separate gear-profile setting.
Automatic Hardcore paths change phases with level. A manually selected path
persists per character and class. Existing standalone gear-profile overrides are
ignored. Edit Character never changes the live gear-scoring character.

Open **Stat Weights** in **Settings > Gear Advisor** to edit all scoring weights. Edit a nonnegative decimal
and press Enter or leave the field to save; Escape cancels the pending edit.
Zero ignores that stat. Overrides are saved per character and scoring profile;
builds using the same profile share its edits. **Restore Defaults** resets only
the active profile. Other profiles keep their edits. Changed weights immediately
refresh tooltips and upgrade markers and invalidate old auction results.

All usable armor materials compete by slot. There is no lighter-armor penalty
and no requirement to match the equipped material. Class, level and native red
equipment restrictions still apply. Rings and trinkets show both slots; a
two-handed item's **Main hand** line uses the main-hand baseline, matching the
reference item tooltip. When an off-hand is equipped, a separate **Both hands**
line includes its lost score. Auction weapon setups always compare the complete
configuration. A replacement off-hand cannot be scored
as equippable while a two-handed main hand remains equipped.

Permanent enchants and armor kits are cleared from both item links before
scanning; random suffixes remain intact. Native primary-stat text takes priority
over incomplete Classic item-stat API results. Static supported Equip stats are
included; procs, use effects and set bonuses are excluded. Lost stats appear in
red even when the total item score improves. The selected profile's DPS weight
applies to melee, ranged and wand weapons, without class-specific overrides.
Weapon DPS uses the native tooltip's displayed precision, matching the reference
scorer, ahead of the item API's higher-precision value. Enhancements are removed
before reading that tooltip. New snapshots identify this as `classic-weighted-v3`;
older saved snapshots retain their original scores and model identifier.
The **Gear Snapshot** button in **Settings > Gear Advisor** opens a page that
contains the capture button, saved character details, status and all 20 equipment
slots. Hover a row to see its captured tooltip. Both gear subpages have a **Back**
button that returns to Gear Advisor settings. Each uses the settings scroll and
does not open or modify the native Character window. Existing snapshots are retained.

## Upgrade markers

Bag items and quest reward choices show a dark green up arrow with a black outline
in the icon's bottom-right corner and a green icon border when they beat equipped
gear for at least one eligible slot. These
use the same build, restrictions and intrinsic-stat calculations as tooltips.
Two-handed markers compare both replaced hands. Zero-score baselines use the
score difference without inventing a percentage. Missing item data stays unmarked
until it loads. Markers refresh after gear, level, build or inventory changes;
recycled buttons clear old hints. They do not pick or equip items automatically.

Toggle these in **Settings > Gear Advisor** independently of tooltip advice.
Markers support Blizzard's native bags, replacement bags using Blizzard's live
container-button setup (including Baganator), and quest reward/quest-log choices.
Live bag buttons are discovered as they are populated, without relying on native
frame names or changing bag-addon settings. Pooled buttons resolve their current
bag and slot after sorting. Bank and cached/offline views are not marked.
Work runs in batches of at most four visible buttons per frame and caches
repeated comparisons.
Native hooks were checked against Blizzard's Classic Era
[container UI source](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_UIPanels_Game/Classic/ContainerFrame_Shared.lua)
and [quest UI source](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_UIPanels_Game/Vanilla/QuestInfo.lua).

## Auction weapon setups

The auction house's **Upgrades > Weapon setups** compares complete configurations.
The baseline is the sum of the equipped main-hand and off-hand scores. A candidate
two-hander supplies one score; a one-handed weapon and its off-hand supply two.
Both percentages use the same formula and rounding as the gear advisor. Ordinary
single-item tooltip percentages can differ from a setup's
percentage because their replaced baseline is different.

The scan retains usable weapon candidates even if they are not individual upgrades.
It combines them with scanned shields, held off-hands, legal off-hand weapons and
currently equipped pieces. This finds pairs that beat a staff even when neither
piece alone does, and allows upgrading one hand while retaining the other.
Unique-item rules, learned dual wield and main-hand-only restrictions apply.
Two copies of one auction variant require two actual listings; their two prices
are added rather than duplicating the cheapest price. An equipped copy may pair
with a purchased copy when permitted.

Each main-hand and off-hand candidate gets its highest-scoring compatible partner;
duplicate setups are collapsed. This exposes alternatives for either slot without
storing every possible combination. Work yields between frames, with a bounded
visible row pool. Equipped setups remain as zero-change options and negative
alternatives are retained for comparison. Items in bags are not searched.
Combined prices include all required purchases and identify bid-only or mixed
bid/buyout setups. Open a setup to inspect and search for each component.

This remains a weighted-stat comparison, not a combat simulation: attack speed,
dual-wield combat penalties, shield utility and effects are not independently
simulated. Choose the appropriate talent build and inspect the individual
items before changing weapon styles.

## Talent advice

Sixteen Hardcore paths cover levels 10-60 across all nine Classic classes.
Levels 1-9 show that talents are locked. The list has continuous scrolling,
current ranks and a next-point highlight. Edit Character can preview any class.
Default paths change phases for Druid, Rogue, Shaman and Warrior; incompatible
existing points produce explicit respec guidance. Selecting another path never
spends points or resets talents.

**Learn** spends exactly one point on click, after re-reading the live class,
level, build, talent ranks and free points. A changed recommendation, combat,
missing data or incompatible build prevents spending. Native talent coordinates
identify localized talents; ranks, tier gates and prerequisites are checked.
There is no automatic allocation or background combat calculation.

## Reference and differences

Reference inspected: the installed Zygor Classic `Item-ItemScore.lua`,
`Code-Classic/Item-ItemScore.lua`, `Data-Classic/Item-Statweights.lua`,
`Code-Classic/TalentAdvisor*.lua` and the Hardcore branch of
`Guides-Classic/TalentAdvisor-Builds.lua`. Numerical stat tables and ordered
talent selections were imported into compact data files. The advisor runtime
and UI are independent. HardcoreBuddy must not access Zygor globals, APIs,
settings or saved data, hook its functions, or load it in-game. Source inspection
and reference comparisons are performed only in offline developer tooling.
Input hashes and the import correction are in `reference/advisor/source.json`.

Deliberate differences from that reference:

- No material-based score penalties at levels 40 or 50.
- No asymmetric candidate-only hit-cap discount: the same weight evaluates both
  sides, so comparing an identical item always returns zero.
- No invented 100% score against an empty or zero-score slot.
- Enchants are consistently excluded.
- Two-handed tooltips also show the complete replacement under **Both hands**
  when an off-hand would be removed, rather than presenting only the main-hand gain.
- The Frost single-target path moves its third Frost Channeling point ahead of
  Ice Barrier, making Ice Barrier legal at level 40 instead of the source's 39.
- Automatic equipping is opt-in under Gear Advisor settings; talent points are
  still spent one at a time only when requested.

Classic talent coordinates, rank limits, spell IDs and prerequisites come from
the pinned [WoWSims Classic talent trees](https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/core/talents/trees).
The compact factual reference, individual source URLs/hashes and MIT license
are retained in `reference/advisor`. No simulation code is loaded or shipped.

## Validation

`tests/run_gear_bags.py` covers optional chat notices and automatic bag upgrades.
The bag advisor uses the same live scoring profile and comparisons as tooltips,
including usable lighter armor and complete two-handed replacements. It checks
four bag entries per update, chooses the strongest eligible improvement, equips
one item, then waits for an equipment update before scoring again.

Both bag options default off and respect the Gear Advisor master switch.
Notifications are deduplicated for the session, resetting when the options or
scoring settings change. Auto-equip preserves worn items identified by the
client as Quest class or Quest binding, and skips equipment whose quest status
has not loaded. A two-hander also checks the off-hand it would remove. Bag quest
flags and quest-starter IDs prevent equipping those candidates. Ordinary earned
quest rewards are eligible. Items with no quest designation cannot be inferred
to be needed for a quest simply from their stats.

Equipment changes wait for combat, death, taxi travel, cursor use and item locks
to clear. Failed attempts are not repeatedly issued against unchanged gear;
native binding confirmations are never accepted automatically. The module uses
the client [item API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua)
and [container API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/ContainerDocumentation.lua),
without other addon dependencies. Live equip/confirmation behavior still needs
verification in the game client.

`tests/run_gear_advisor.py` covers reference scores, all-class armor eligibility,
slot handling, item-loading failures, enhancement stripping and tooltip reuse.
`tests/run_talent_advisor.py` validates every path point against Classic tier,
rank and prerequisite rules and tests live allocation safeguards and navigation.
`tests/run_gear_snapshot.py` verifies manual capture, saved-data independence,
Gear Advisor settings integration and offline reload of the saved fixture.
`tests/run_auction_upgrades.py` verifies auction scanning, complete weapon setups,
both purchase links, legal pairings, duplicate availability/prices, equipped-item
reuse, score baselines, yielding and continuous result navigation.

These are automated API/layout fixtures. Actual client appearance and live point
spending must still be checked in WoW; the tests do not constitute a live session.

The current talent API shape was also checked against the
[Classic Era Blizzard UI API definitions](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua).
