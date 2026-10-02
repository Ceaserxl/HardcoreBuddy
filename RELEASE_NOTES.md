# Unreleased

- Removed the Rotation Advisor prototype, its highlights and automatic diagnostic
  logging. Old per-character rotation traces are cleared when that character loads.
- Alt Advisor keeps genuine empty-slot upgrades and excludes gear snapshots older
  than 7 days by default. The cutoff is configurable in Gear Advisor settings.
- Essentials auction purchases are cached as In Mail after server confirmation.
  Mailbox collection updates stock; fulfilled refill rows are hidden, including
  crafting materials already covered by bags, the saved bank or pending mail.
- Added account-wide custom talent builds bundled with stat weights, including
  talent-tree editing, current-talent capture, selection, deletion, reviewed
  export/import codes and in-game whisper links.
- Custom weights feed gear, enchant and auction advice. Selecting or editing a
  custom path pauses automatic talent spending until explicitly enabled again.

# HardcoreBuddy v0.6.5

- Compact, consistent layouts across Supplies, Companion, settings and Death Journal.
- Gear Advisor, Talent Advisor and Zone Advisor now live under Companion. Spells
  includes class training, Hunter pet abilities and Warlock grimoires.
- Supplies includes class- and specialization-aware enchants, armor kits and scopes,
  with alternatives, material tracking and level-appropriate or maximum recommendations.
- Per-item refill thresholds and targets, improved ammunition selection, vendor
  guidance and map markers, optional vendor purchasing and repair settings.
- AH Upgrades compares equipment and weapon setups. AH Essentials compares finished
  items against learned crafting recipes, accounts for bags and saved bank stock,
  and finds economical whole-stack purchases for refills.
- Craft and Buy start unchecked. Craft is selected after scanning only when cheaper;
  manual choices are respected. Click Buy once, then confirm each queued stack.
  Own-auction errors try another seller or continue to the next queued item.
- Bank snapshots save on close and persist between sessions. Ordinary vendor drink
  alternatives are available across classes; Buffs is now Elixirs, followed by Scrolls.
- Light of Elune uses quest completion status and bag-only quantities, provides quest
  links, and creates a draggable Elune/Hearthstone macro with validation and repair.
- Zone Advisor includes map exploration tint, NPC filters, configurable markers,
  clustering and paged model previews. Updated NPC and vendor data are bundled.
- Improved tooltip formatting, alternate-character upgrade advice, talent application,
  death report controls, sound settings and diagnostic capture.

Existing settings are retained. No other addons are required. Reload after updating.
Automated checks cover Lua loading, recommendation logic, UI models, purchasing
flows and package integrity; final visual and protected-action checks require WoW.

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
