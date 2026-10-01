# Unreleased

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
