# HardcoreBuddy v0.2.5 Beta

Release update for WoW Classic Era / Hardcore (interface 11509).

Published as a normal Release. Beta is the pre-1.0 display label only.

- Scroll recommendations now follow the selected class and level.
- Hunter Supplies > Class shows active pet spell ranks, available upgrades,
  and beasts to tame with level ranges and zones. Trainer skills point to the
  pet trainer; preview mode does not assume learned ranks.
- Automatically join the localized HardcoreDeaths channel after login/reload
  and rejoin if membership is lost, independently of death-banner settings.
- Add 226 faction-aware elite/NPC exclusions, including flight masters, based
  on Unitscan Hardcore defaults. Excluded NPCs receive no alert or automatic
  marker; rare and rare-elite warnings remain enabled.

## Installation

Extract the ZIP into `World of Warcraft/_classic_era_/Interface/AddOns`.
The resulting path should be `AddOns/HardcoreBuddy/HardcoreBuddy.toc`.
Restart WoW after installing, then use `/hcb` or the minimap button.
No other addons are required. Existing settings and death history are retained.

## Validation

Automated tests cover Lua 5.1 loading, saved settings, recommendations, pet
rank tracking, channel membership, exclusions, alerts and packaged assets.
Live in-game rendering and playback still require beta testing. Report issues
with reproduction steps, class/level, client version and any Lua error text.
