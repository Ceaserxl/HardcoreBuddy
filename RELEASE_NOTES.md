# Unreleased

- Added a central Settings tab for general preferences, gear scoring, auction
  filters, death alerts and appearance, low health, rares, elites, and preparation.
  Existing preferences and command shortcuts are preserved. Long settings pages
  scroll, and General includes minimap and field kit notification toggles.
- Saved the last auction upgrade scan per character, including weapon setups
  and partial scans across reloads. Cached results show their capture time and
  require a rescan when gear, level, talent profile, weights, or armor filter changes.
- Fixed legitimate negative item stats being rejected as unreadable auction
  listings (including Cloak of Rot, Black Widow Band, and Ogremage Staff).
- Simplified gear tooltips: green stat gains / red losses beneath the original
  slot and percentage row, without specialization, scoring explanations, or listing counts.
- Fixed equipped comparison flicker during auction scans by reusing visible
  tooltips and updating listing counts without rebuilding item comparisons.
- Auction upgrade hovers now show equipped-item comparisons automatically,
  without requiring Shift.
- Added saved diagnostics for skipped auction listings, including the precise
  failure stage, item and equipped comparison data, and retry timing. Open the
  copyable report with Scan details or `/hcb auction debug`.
- Redesigned auction upgrades with persistent slot navigation, a focused best
  upgrades overview, modern item cards, explicit bid/buyout labels, a scan
  progress bar and clearer weapon comparisons and empty states.
- Hovered auction upgrade tooltips and Shift comparisons now stay visible during
  scan updates and refresh when the item under the pointer changes.
- Gear scoring now prefers displayed intrinsic attack-power and ranged
  attack-power bonuses over conflicting API values, correcting Assault Band's
  upgrade percentages while continuing to exclude applied enchants.
- Fixed auction slot filters missing their parent item subclass, which could
  cause every slot to repeat a broad armor or weapon scan.
- Auction upgrades now scan individual equipment slots in sequence. Added a
  saved per-character checkbox under Scan upgrades to restrict body armor to the
  class-and-level armor type, while retaining jewelry, cloaks and weapon setups.
- Fixed Shift-hover equipped-item comparisons on auction upgrades and weapon
  setup components, including modifier changes while already hovering.
- Fixed weapon percentage mismatches by preserving each profile's DPS weight and
  reading native displayed DPS precision. Two-handed tooltips show the reference
  main-hand comparison plus a separate Both hands comparison when an off-hand
  would be lost. Full auction setups continue to compare the complete equipment.
- Added auction-house Weapon setups: compare two-handed weapons against complete
  main-hand/off-hand pairs using the same equipped baseline. Includes upgrades
  for either or both hands, equipped-item reuse, shields, caster off-hands,
  legal dual wield, separate purchase links and combined listing prices.
- Added a native-style Upgrades tab at the auction house: scan for the best
  percentage upgrade per slot, browse all alternatives with continuous scrolling,
  and open matching auctions in Browse. Uses the standalone gear advisor and
  respects auction throttling, other searches, and equipment/talent changes.
- Matched the reference percentage display's downward rounding to two decimals.
  Gear scoring remains standalone, with no in-game interaction with Zygor.
- Fixed short spell-damage suffixes such as `+15 Frost Spell Damage` being
  omitted from gear scores, causing false upgrades against Frozen Wrath items.
- Added an Advisors page with gear and talent advice for all nine Classic classes.
- Rebuilt gear percentages around Classic specialization stat weights; all usable
  armor materials compete without lighter-armor penalties. Enchants and armor
  kits are excluded, and lost stats are shown in red.
- Added automatic talent-based scoring and selectable role profiles.
- Added 16 Hardcore talent paths, next-point advice, explicit respec guidance,
  one-click single-point learning and complete scrollable build lists.
- Preserved manual Character-window gear snapshots for offline review.
- Removed the combat simulator, recovery sampling and unused research data.
- Replaced paging throughout HardcoreBuddy with continuous scrolling,
  including the complete Pet Guide, supply and training lists, and Death Journal.
  The journal reuses visible rows to keep large histories responsive.
- Supplies > Buffs now checks equipped chest armor, leggings, gloves and boots
  for missing or outdated armor kits. Recommendations respect character and
  armor item levels, preserve other enchants and Core Armor Kits, and update
  when equipment or enhancements change.

## HardcoreBuddy v0.3.0

More flexible alerts and clearer supply planning for WoW Classic Era / Hardcore.

- Quieter, borderless supply-upgrade notifications away from danger alerts.
- Compact, Banner and Text-only death alerts with background opacity and a
  persistent drag preview under Death Journal > Appearance.
- Essentials filter and editable Essentials / Advanced / Optional priorities.
- Class and weapon-aware arrow, bullet and thrown-weapon supply tracking.
- Optional resting-area restock panel and throttled departure reminders under
  Alerts > Preparation. Both are off by default.
- Clear an active ordinary elite warning when entering a dungeon or raid;
  rare and rare-elite warnings remain active.
- Release names now use the numeric version without a suffix.

## Installation

Extract the ZIP into `World of Warcraft/_classic_era_/Interface/AddOns`.
The resulting path should be `AddOns/HardcoreBuddy/HardcoreBuddy.toc`.
Restart WoW after installing, then use `/hcb` or the minimap button.
No other addons are required. Existing settings and death history are retained.

## Validation

Automated tests cover Lua 5.1 loading, saved settings, recommendations, pet
rank tracking, channel membership, exclusions, alerts and packaged assets.
Live in-game rendering and playback still require client testing. Report issues
with reproduction steps, class/level, client version and any Lua error text.
