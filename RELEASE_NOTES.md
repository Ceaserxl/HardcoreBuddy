# HardcoreBuddy 0.1.0-beta.1

First public beta for WoW Classic Era / Hardcore (interface 11509).

- Field kit recommendations, editable carry targets and custom items.
- Character planning, companion guidance and Hunter beast tooltips.
- Death Journal, compact live feed and configurable death alerts.
- Low-health warnings and separate rare/elite detection alerts.
- Dungeon and raid level ranges and packing lists with mob-specific item tips.

## Installation

Extract the ZIP into `World of Warcraft/_classic_era_/Interface/AddOns`.
The resulting path should be `AddOns/HardcoreBuddy/HardcoreBuddy.toc`.
Restart WoW after installing, then use `/hcb` or the minimap button.
No other addons are required. Existing HardcoreBuddy settings are retained.

## Beta validation

Automated checks cover Lua 5.1 loading, saved settings, recommendation logic,
menus and alerts. In-game rendering, combat targeting and audible playback
still require live-client verification. Report issues with the steps to reproduce,
your class/level, client version and any Lua error text.
