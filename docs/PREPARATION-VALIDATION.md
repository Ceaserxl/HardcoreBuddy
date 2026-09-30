# Preparation and alert changes

Implemented and checked on 2026-09-29 for the v0.3.0 release.

- `tests/run.py`: full planner, profession, inventory, saved-data, navigation
  and layout suite passed. Includes all 540 class/level supply profiles and
  144 window/screen/view combinations.
- `tests/run_preparation.py`: priorities, carry overrides, ammunition selection,
  thrown-stack counting, unknown inventory/item data, rest-area transitions,
  reminder throttling, combat suppression, death styles/opacity, persistent drag
  preview and fresh-runtime SavedVariables restoration passed.
- Death journal, channel membership, kit alerts, low health, creature routing,
  noise/exclusions, hunter training/tooltips, scrolls, user items, instance guides
  and release-name checks passed. Ordinary elite warnings are suppressed both
  on detection and when an active warning crosses an instance boundary; rares
  remain enabled in dungeons and raids.
- `tests/render_preparation.py`: generated and visually reviewed real-frame-tree
  previews in `docs/layout-previews/`. Fonts and native icons are approximated;
  these are not client screenshots.
- Local package validation: all 156 shipping files resolve, ZIP CRC and
  byte-for-byte checks pass, and the packaged addon boots under Lua 5.1 with
  bundled textures and alert sounds. New modules are in the TOC and manifest.

Version 0.3.0 packages these changes with the existing settings and history
preserved. Publication uses the normal GitHub/CurseForge release workflow.

Remaining client checks: live equipment/ammo API behavior, movement across
rest-area boundaries, alert dragging/click-through and actual font rendering.

Ammo vendor tiers and icons are recorded in
`reference/research/ammunition-tooltips.json`, retrieved from the Classic
tooltip endpoint `https://nether.wowhead.com/classic/tooltip/item/{itemId}`.
No network requests or additional addon dependencies are used at runtime.
