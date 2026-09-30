# Unreleased

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
