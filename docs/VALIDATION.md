# HardcoreBuddy validation

September 27, 2026. Target: installed Classic Era 1.15.9.69722, interface 11509.

## Version 3.2.0 embedded death journal (September 28)

### Supply description column and user-item removal

Supply rows now put their muted description beside the name under a Description
heading, including item-detail supply rows. Long descriptions wrap within their
own column. User input instructions stay consistent after adding or dropping an
item; errors remain actionable. Remove item appears only in a custom item's
detail page and returns to User after removal. Saved Carry targets remain intact.
User-item regression checks cover stable instructions and detail-only removal.
The inspected layout is `docs/layout-previews/hardcorebuddy-supply-columns.png`.

### Personal supply items and Emergency icon

Emergency now uses an engineering gadget icon distinct from Potions. User
follows Optional in the sidebar and accepts item IDs or pasted item links.
Entries persist per character, use exact-item bag counts and existing Carry
targets, and resolve uncached names on GET_ITEM_INFO_RECEIVED. Add/remove controls
remain on the User list; standard details/back navigation works. Sidebar row
spacing adapts to the number of categories and available height.

`tests/run_user_items.py` passes input validation, duplicates, uncached name
resolution, quantities, removal, saved data reuse, details/back and icon
separation. Death integration and 39 Lua 5.1 syntax checks pass. Inspected
simulation: `docs/layout-previews/hardcorebuddy-user-items.png`.

### Scrolls supply category

Added a Scrolls sidebar tab under Supplies and a corresponding section in All.
The reviewed `reference/scrolls.json` generates `Data/Scrolls.lua`; all 24
Classic ranks were checked against Wowhead's Classic item tooltip endpoint,
with responses saved in `reference/research/scroll-tooltips.json`.
Supplies recommends the highest usable rank per type with exact item counts.
Scroll upgrades participate in existing level-up field kit notifications.

`tests/run_scrolls.py` passes every level boundary, six-type selection, exact
rank stock, carry targets and details/back navigation. Kit alert and death
regressions pass, including 39 Lua 5.1 syntax checks. Inspected layout:
`docs/layout-previews/hardcorebuddy-scrolls.png` (native item icons are placeholders
in the simulation).

### Integrated low health warning

The installed Low Health aura was inspected read-only. Its strict below-40%
trigger, red 72px PT Sans Narrow text, half-second pulse and play-on-start air
horn now run in `LowHealth.lua` without a WeakAuras runtime dependency. Bundled
sound/font assets retain attribution and font licensing in `Media/Health`.
Alerts is a page in the main window, with enable/sound toggles, a 1-100% threshold
and three-second preview. Settings persist in HardcoreBuddyDB.lowHealth.

`tests/run_low_health.py` passes threshold boundaries, unrelated unit filtering,
single sound per episode, pulse, recovery, death, invalid health, disable/mute,
preview expiry, input bounds and navigation. The main regression suite passes,
including 26,716 layout assertions; death tests and all 38 Lua 5.1 syntax checks
pass. Inspected simulations are `hardcorebuddy-health-options.png` and
`hardcorebuddy-low-health.png`. Audio playback and live health events still need
in-game verification using `/reload`, `/hcb health`, and Preview warning.

### Level-up field kit notification

Compares the actual character's supply rows before and after PLAYER_LEVEL_UP,
independent of preview mode and window visibility. Newly listed supplies trigger
an eight-second clickable notification plus a full chat summary; repeated level
events and XP updates stay quiet. Clicking opens Supplies in live mode.
`tests/run_kit_alerts.py` verifies all 59 Hunter level transitions, no-change
levels, duplicate suppression, fading and navigation. The full `tests/run.py`
suite and death integration/syntax checks pass. In-game appearance remains to
be checked at a level that unlocks supplies.

### Alternative symmetrical iron banner

Replaced the skull artwork with silver-edged iron, mirrored end pieces and red
corner gems. The compact geometry and centered text remain. Imported artwork
excludes black exterior padding. Inspected simulation:
`docs/layout-previews/hardcorebuddy-death-banner-iron.png`.
`tests/run_deaths.py` passes all death checks and 37 Lua 5.1 syntax checks.

### Symmetrical alert artwork and centered text

New artwork places matching small skull ornaments at both ends, leaving the
middle open for centered text. The alert remains 896 x 112 with equal 57px end
caps. The title, character/level, cause/location and divider share the full
banner's centerline. The imported texture excludes exterior black padding.

`tests/run_deaths.py` passes: 89 embedded-module assertions, integration checks,
93 standalone regression assertions and 37 Lua 5.1 syntax checks. Added checks
cover the new asset, equal caps and centered text bounds. The inspected mock
render is `docs/layout-previews/hardcorebuddy-death-banner-centered.png`;
in-game appearance still requires `/reload` and Preview alert.

### Separate compact-feed columns

The live feed is now 400 x 218 with labeled LVL, NAME, LOCATION and WHEN columns.
Four 30px rows place names and locations side by side on one baseline. The extra
width preserves readable text and the existing header/footer controls. Death
integration tests verify horizontal separation and bounds; the inspected
simulation is `hardcorebuddy-live-feed-columns.png`. All death regressions and
37 Lua 5.1 syntax checks pass.

### Compact live-feed redesign

The compact feed now uses a 300 x 218 themed panel, small skull/brand header,
four framed 34px rows, prominent level numbers, names and ages on the first
line, and locations beneath. The footer has a status indicator and Open journal
button. The existing drag/lock, scale, saved position, hide and row-detail
behavior remains. Empty and unavailable-feed states have separate wording.

Inspected populated/empty simulations are `hardcorebuddy-live-feed.png` and
`hardcorebuddy-live-feed-empty.png`. Death integration checks cover latest
current-realm reports, label bounds/non-overlap, journal/details navigation,
hide-without-stopping-tracking and empty/unavailable states. The 89 death-module
assertions and all 37 Lua 5.1 syntax checks pass. In-game check: `/reload`, enable
the compact feed in Death Journal > Options, drag the header and click a row.

### Shorter alert with left-aligned text

The alert is now 896 x 112 (previously 896 x 146). Three texture slices preserve
the skull and end-cap proportions while stretching only the middle section.
Text is left-aligned at x=126, beside the skull, with tighter vertical spacing.
The exterior-black-strip crop, configurable timing and long-text fitting remain.
Death regressions and all 37 Lua 5.1 syntax checks pass. The compact layout is
shown in `docs/layout-previews/hardcorebuddy-death-banner-compact.png`.

### Banner edge crop and centered typography

The banner texture coordinates exclude the opaque exterior above and below
the frame. Runtime height is 146 at width 896, preserving the sampled strip's
proportions. The original texture remains unchanged; a generated transparency
edit was rejected because it contained an opaque checkerboard.

The alert title, 30px character/level line and 18px cause/location line are
centered in the text area beside the skull. A subtle gold divider separates
the two larger lines. Long text reduces to bounded smaller sizes, and subsequent
short alerts restore the larger fonts. `hardcorebuddy-death-banner-fitted.png`
is the inspected layout simulation. Death integration checks cover texture
coordinates, frame size, text alignment, fitting/reset and existing timing.

### Separate columns and dedicated alert banner

Journal reports now have six separate columns on one baseline: Level,
Adventurer, Location, Cause, Source and When. Displayed causes omit a leading
"a" or "an" without changing saved cause/message data. The alert's lower line
contains only cause and location; the repeated Blizzard character announcement
is retained in report details. Sound defaults to enabled while saved choices
remain respected.

The new `AlertBanner.tga` is generated specifically for the wide alert and shown
at 896 x 164 with a skull at the left, quiet text area and ornamental border.
Small-screen fitting also refreshes after display/UI-scale changes. Inspected
simulations are `hardcorebuddy-deaths-columns.png` and
`hardcorebuddy-death-banner.png`. Source and conversion details are recorded in
`Media/Deaths/ARTWORK.md`.

`tests/run_deaths.py` passes 89 module assertions and integration checks for
column separation/baselines, article cleanup, original-record preservation,
concise alert text, sound defaults and saved preferences, banner asset binding,
small-screen width, timing, migration and persistence. All 37 Lua files compile
under Lua 5.1. In-game follow-up: `/reload`, inspect report columns, open Options
and preview a saved report; confirm artwork, audio preference and duration.

### Journal redesign and configurable duration

The main Level label uses measured text width with padding, no wrapping, and
adjacent controls positioned from that measurement. The fixed 1040x660 outer
window and uniform screen fitting remain unchanged. Layout tests explicitly
check label width, height and button separation with normal and wider fonts.

Death Journal now has only Reports and Options. Reports use framed two-line
rows, three summary boxes, themed search/level fields and themed pagination.
Row count adjusts to the available content height, including planning mode.
Community reports remain labeled unverified. Options use two columns with
visible checkbox states and a saved alert-duration field, bounded to 1-30
seconds. The existing three-second hold remains the default, followed by a
half-second fade; an alert snapshots its duration when it starts.

Death tests cover default/malformed/bounded duration, Enter/focus-loss commit,
Escape cancellation, empty input, exact hold/fade timing, persistence, removal
of Verified navigation, and report/options bounds in live and planning modes.
The 88 death-module assertions and all 37 Lua 5.1 syntax checks pass. The main
field-kit suite also passes. Inspected layout simulations:
`hardcorebuddy-deaths-redesign.png`, `hardcorebuddy-deaths-options-redesign.png`
and `hardcorebuddy-level-label.png` in `docs/layout-previews`.
In-game follow-up: `/reload`, inspect the planning Level label, open Death
Journal > Options, set a duration, preview an actual report and check its timing.

### Removed watching and previews from saved history

Player watching is removed from the sidebar, report details, row right-clicks,
slash commands, filtering and minimum-level alert exceptions. Existing saved
watch preferences are cleared at initialization and are not imported from the
standalone addon. Reports and ordinary alert-level settings are preserved.

Preview alert and `/hcb deaths test` use the newest saved report for the current
realm, then the newest report from any realm. Only empty history uses the sample
adventurer. Previews retain the preview heading and original report text and do
not modify or insert history. `tests/run_deaths.py` passes 88 module assertions
plus integration checks for the removed controls/preferences, preview button,
realm selection, empty-history fallback and unchanged records. All 37 Lua files
compile under Lua 5.1.

### Main-window page integration

Death Journal is now the fourth main navigation tab. Reports, details and
options are child pages of the right-hand content area; All reports, Verified,
Watchlist and Options use the existing left sidebar. The footer launcher and
independent journal/settings/details windows are removed. Slash aliases,
minimap right-click and the compact feed's Journal button open the same page.
Page dimensions and scale follow the main window; overlay settings affect only
the compact feed and alert. Existing journal positions remain saved but are not
used by the embedded page.

The existing suite passes, including 23,956 layout assertions across 144
configurations. Death tests cover page switching, parent visibility, sidebar
filters, shared options/details, back navigation, search, pagination, level
filters and bounds at 1920x1080, 1024x768 and 640x480. Lua 5.1 compilation and
the death-event/migration regressions also pass. The journal and options layout
simulations are saved in `docs/layout-previews/hardcorebuddy-deaths-page.png`
and `hardcorebuddy-deaths-options.png`; native template controls are not fully
represented by the simulator. In-game follow-up: `/reload`, choose Death Journal,
open a report, return to the list, and switch between Options and Supplies.

### Initial integration history

HardcoreDeaths now runs as four internal `Deaths/` modules with copied runtime
artwork. The field kit has a Death Journal footer button; right-clicking its
single minimap button or using `/hcb deaths` opens the journal. Existing `/hd`
aliases remain available. History lives in `HardcoreBuddyDB.deaths`.

The local standalone HardcoreDeaths TOC optionally loads HardcoreBuddy first,
and its Events.lua yields when the embedded module exists. One login with both
enabled imports the old data without modifying the legacy tables. This avoids
duplicate listeners, windows and minimap buttons while preserving standalone
behavior when HardcoreBuddy is disabled. The embedded addon has no dependency
on the old directory. Distribution with an unmodified standalone addon requires
disabling that addon.

`tests/run.py` passed the existing data, profession, menu and layout suite,
including 21,772 layout assertions across 144 configurations. Its minimap
tooltip expectation now includes the right-click death-journal hint.
`tests/run_deaths.py` passed 86 embedded-module regression assertions, full TOC
startup, shared controls, case-preserving watch commands, one-time migration,
original-data isolation, preference precedence, relog persistence and unsupported
event fallback. The standalone fallback still passes its 93 assertions. All
37 Lua files compile under Lua 5.1. No Git checkout is present for diff checks.

The native event isolation was also checked against Blizzard's
[Classic RaidWarning implementation](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_FrameXMLUtil/Classic/RaidWarning.lua): only
`HARDCORE_DEATHS` is replaced; `CHAT_MSG_RAID_WARNING` remains registered.

In-game follow-up: restart the client to refresh the changed TOCs, leave both
addons enabled for the first login, verify the import chat message and journal
history, then disable standalone HardcoreDeaths. Check the shared minimap
right-click, Death Journal footer button, `/hcb deaths test`, options and live
death messages. Native rendering and live realm traffic still need client checks.

## Version 3.1.0 field kit refinement (September 28)

The window uses a fixed 1040 x 660 layout, uniformly scaled to fit small screens.
The category sidebar remains visible in lists and details, with direct routes
back to categories and Companion profession pages. Supplies / All is a single
scrolling list grouped by Food & drink, Buffs, Emergency and Optional. Supplies
search, Missing-only controls and the stock-summary strip are removed; stale
query/stock state is cleared before building the visible list. Pet Guide retains
its catalog search. Back is placed above the right content area without moving
the sidebar. Item details render labeled fields for
crafting, rank gates, recipe acquisition and trade eligibility.

Faction-exclusive rewards and routes use the actual character's faction, even
while planning. Unknown faction suppresses exclusive routes. Shared tradeable
items and the complete wild-pet catalog remain available. Sources controls and
research URLs are removed from runtime files; developer provenance remains.

Bandage, anti-venom and target-dummy guidance distinguishes learned recipes,
currently craftable upgrades, future tiers, recipe/manual AH eligibility and
skill-cap training. First Aid and Cooking include book/quest requirements.
The native item tooltip is available over rows and icons, including recipe
items, with an embedded fallback when game item data is unavailable.

The custom canvas/map background and metal-framed rows match the fixed layout.
The banner fills the full header using centered proportional cropping, and the
92-pixel emblem is vertically centered beside the title.
Four shipped TGA assets are active; source PNGs and prompts are in ARTWORK.md.
Tests use a strict Lua 5.1 mock and separate layout simulations. Exact final
results are recorded in test-results.txt. These do not substitute for a live
client check of native fonts, rendering, focus, bags and character skills.

Final checks passed: 452 crafting assertions covering all 120 distinct items;
6,456 row/icon openings; 3,348 native item-tooltip checks; 111,730 pooled-row
checks; 28,253 structured-field checks; and 21,772 layout assertions across
144 screen, mode, view and font-metric combinations. All 30 Lua files compile
under Lua 5.1. Seventeen final layout simulations render all four active custom
textures with no missing native texture placeholders. Grouped All, cleared
stale Supplies filters, Pet Guide search, faction routes and sidebar exits from
details are covered directly. Internal model filtering has separate coverage.

In-game follow-up: `/reload`, open `/hcb`, scroll All through each category,
open both Elixir of Greater Defense and Restorative Potion, return using the
sidebar, and hover item/recipe rows. Check live bags/skills, then planning mode
and the faction-specific First Aid route on the appropriate character.

## Version 3.0.2 planning controls and fitted artwork (September 28)

The former Preview button is now `Plan another character`, positioned with the
navigation controls below the artwork. While planning, it becomes `Return to my
character`. The class/level controls and Back button flow onto utility rows when
needed. The subtitle labels planning and the assumed pet level; the short notice
explains that inventory and professions still belong to the actual character.
Saved planning choices and the internal preview-mode representation are preserved.

Search uses the font's measured string width plus padding, disables wrapping and
centers the text in a row sized for its measured height. It no longer depends on
a fixed label width. Nearby controls can wrap when the search field would become
too narrow.

The header and minimap now use a steel shield and ivory-skull emblem. A newly
composed shallow campsite panorama replaces the oversized original landscape.
The import extracts the complete generated strip from intentional letterbox
padding. Runtime fits its entire 9.05:1 composition inside the header without
cropping, stretching or changing the height available for the guide. Unused
space matches the dark edge of the artwork. Assets and prompts are in ARTWORK.md.

The focused UI checks now cover 144 combinations from 480 to 1400 pixels wide,
including 400-pixel-high windows, live/planning modes, three sections and two
font metrics. The second set uses 20% wider and 10% taller text to catch the
reported clipping. Checks cover actual planning-button clicks, readable Search
and button labels, full-banner UVs and aspect ratio, header bounds, and the
complete first supply row at minimum height. Short supply tables omit their
repeated card heading while retaining every quantity column.

The main suite passed after the planning/search change. Final focused checks,
Lua compilation and artwork validation follow the later decorative and compact
heading changes; exact output and ordering are in `test-results.txt`. Twelve
`redesign-*.png` simulations document the current artwork and layouts. Native
fonts, rendering and focus still require an in-game `/reload` check.

Final results: 22,233 focused assertions pass across those 144 layouts; all 23
Lua files compile under Lua 5.1. All three active TGA files and source PNGs
validate, including shield transparency. The twelve regenerated previews have
zero missing texture placeholders. The full menu run recorded 7,311 row/icon
openings and 242 automatic profession UI/event assertions before the final
decorative/compact-heading changes.

## Version 3.0.1 full-width banner (September 28)

The in-game screenshot exposed the banner's hard vertical edge: its right-aligned
texture was capped at 510 pixels (340 in compact mode). The artwork now fills
the header between the existing frame insets. A lighter tint and adjusted crop
keep the lantern glow visible while preserving the source image's proportions.
Header height, title, controls and content geometry are unchanged.

The existing focused redesign suite passes 5,441 assertions across 42 layouts;
all 15 runtime Lua files compile under Lua 5.1. Actual-frame-tree previews at
480x560, 840x650 and 1040x730 were inspected with zero texture placeholders
(`layout-previews/banner-fixed-*.png`). These are layout simulations; the native
client still needs `/reload` to display and verify the revised banner.

## Version 3.0 illustrated field journal

The current interface opens directly to the supply table inside an illustrated
field journal. Embedded artwork supplies the forest header, lantern crest and
embossed leather. Native dialog borders, beveled controls and framed item icons
provide the remaining decoration. Categories become a sidebar when there is
enough room and return to tabs in compact windows. Bag counts, Carry targets,
per-item meters and a category summary expose restocking needs without opening
reference details. The minimap launcher uses the same lantern crest.

The redesign preserves automatic class/level and pet detection, known-recipe
selection, per-character Carry targets, live bag refresh, Preview, all reference
routes and the standalone TOC. Dimensions migrate once to 840x650; subsequent
resizing persists. Decorative regions do not receive mouse input.

The focused redesign suite exercises 42 layouts, including narrow and short
windows, sidebar/tab transitions, Preview and every class. It checks geometric
bounds, click targets, category selection, resizing, stock indicators, artwork
visibility and native BackdropTemplate resize callbacks. The complete suite also
traverses item details, profession ranks, Pet Guide, search, pagination, Sources,
tooltips, quantity edits, minimap behavior and SavedVariables restoration. Final
counts and results are recorded in `test-results.txt`: 5,441 redesign assertions
across 42 layouts, 7,311 row/icon openings and 242 profession UI/event assertions
pass. All 23 Lua files compile under Lua 5.1. All three embedded TGA headers,
dimensions, pixel payloads and source PNGs validate, including crest transparency.

Native texture coordinates and frame API contracts were reviewed against the
Classic Era Blizzard UI source. Two resize defects were corrected: button texture
slices now follow size changes, and the main window preserves the inherited
BackdropTemplate size handler. The Preview class menu has distinct hit areas for
all nine options.

`layout-previews/redesign-*.png` are renders of the actual Lua frame tree. They
include the embedded artwork and cached native textures, with substitute fonts;
they are layout simulations, not game screenshots. The supply, Emergency,
narrow, Preview, profession-rank, item-detail, Companion, Pet Guide and Sources
views were reviewed. Artwork prompts, source files and import steps are in
`ARTWORK.md`.

Remaining client verification: `/reload`, open `/hcb`, inspect the art and native
fonts, resize/scroll, edit a Carry target, switch Preview and return to the
character, then open item details and the class companion. Check the minimap
launcher and live bag updates after using or moving an item. No game-client
execution was available; mock coverage cannot certify native rendering or focus.

Earlier version sections below are retained as historical implementation notes.

## Version 2.1.1 automatic anti-venom

Anti-venom now uses the same automatic selection, exact bag counts and Carry
targets as bandages and dummies. Selection uses actual First Aid skill and learned
recipes, including in Preview; old manual anti-venom choices are ignored. All
ranks remain available as references, with only the current choice editable.

Regression coverage includes First Aid 80/130/300 boundaries, missing stronger
recipes, shared First Aid detection, recipe-learning events, old saved selections,
exact-item quantities, Carry edits, Missing filtering and readonly rank details.
The menu sweep requires every former Use button to remain hidden. Final results
are recorded in `test-results.txt`: 74 profession checks, 242 profession UI/event
assertions and 7,311 row/icon openings pass. All 21 Lua files compile under Lua
5.1. Checks use a simulated WoW UI.

## Version 2.1 automatic crafting ranks

Bandages and target dummies select the strongest learned recipe whose crafting
requirement is met by the current character's profession skill. Anti-venom keeps
its manual selector. Old bandage/dummy choices are ignored; each automatic item
retains its exact bag count and editable Carry target. Other ranks remain readable
references. Preview uses the current character's skills and recipes.

- 58 profession-model/API assertions cover all 13 recipe thresholds and the point
  below each, missing recipes, use-versus-craft requirements, localization,
  temporary/racial bonuses, collapsed header restoration, synchronous event
  reentry, legacy recipe-query fallback and unavailable/failed API results.
- 158 actual UI/event assertions cover newly learned recipes, skill upgrades,
  world entry in Preview, hidden-window updates, old manual selections, exact
  item counts and unavailable professions. Pending Carry edits stay with the old
  item when an upgrade changes the automatic choice or makes its detail readonly.
- The full menu sweep passes 7,414 row/icon openings, 4,569 passive clicks,
  1,544 page visits, 50 anti-venom selections, 14,308 tooltip hovers, 1,076 Sources
  checks and 115,006 pooled-row checks. All 100 reachable supply recommendation
  variants and the complete Pet Guide remain covered.
- Existing inventory, preview, saved-profile and recommendation parity checks
  pass. All 21 Lua files compile under Lua 5.1.

The source checks and crafting thresholds are recorded in `PROVENANCE.md`.
The test output is in `test-results.txt`. Native game-client execution has not
been automated. In-game, reload and check Emergency before/after gaining skill
or learning a bandage/dummy recipe. Materials and crafting tools are not checked.

## Version 2.0.1 menu regression audit

The reported line-item crash was reproduced before the fix by rejecting nil
assets in the button mock. The existing integration test then failed at the same
`UI.lua` highlight call as the client. Inert detail rows now use
`ClearHighlightTexture`; actionable rows restore their highlight when reused.
The exact Elixir of Agility (8949) row, icon, detail and Back sequence is covered.

`tests/menu_navigation.lua` drives the real UI handlers in Lua 5.1:

- 7,620 row/icon openings, 4,569 passive-row clicks and 1,544 page visits.
- All nine classes and all 100 supply recommendation variants reachable across
  the 540 class/level profiles, including profession rank selection (271 Uses).
- The complete Pet Guide: 17 families, 21 abilities, 111 ranks, 559 creatures,
  145 appearances and five care guides, including nested Companion routes.
- 15,171 tooltip hovers, 1,076 Sources open/close checks and 120,246 checks of
  reused rows for correct highlights, input targets and control visibility.
- Back restores the prior state; search, empty results, filters, pagination,
  selected coordinate clicks and scroll clipping pass. Preview coordinate checks
  at three widths and all previous inventory/persistence regressions also pass.

The audit also fixed the Preview class dropdown overlapping Sources and ensured
Sources commits pending Carry edits. A saved-profile migration regression now
clicks the actual Preview button; initialization preserves the saved class and
level before that button can seed a new preview from the character.

The full suite passes; output is in `test-results.txt`. These are automated frame
mock checks, not a game-client run. Real native rendering, item assets and mouse
focus still need the installed client. Reload the addon to use version 2.0.1.

## Version 2.0 supplies makeover

The previous landing-menu layouts below are historical. The current opening view
is a supply table with carried counts, editable targets and stock status.

- 28 supply/inventory regression checks verify split stacks, keyring inclusion,
  bank exclusion, unknown/incomplete API results, target normalization, disabled
  targets, exact profession ranks and healing/mana potion category routing.
- 540 class/level supply presentations execute in Lua 5.1. Existing recommendation
  fixtures still verify item selection; the new Supplies model changes visible
  categories and adds quantities without rewriting the preserved baseline.
- Native mock clicks now hit actual coordinates using visibility, frame levels,
  strata and scroll clipping. Preview is tested at 480, 680 and 1040 widths; the
  header drag rectangle never intersects Preview or Close.
- Typed level values commit before plus/minus. First preview starts at live level.
  Enter, blur, arrow keys, invalid drafts and return to live mode are covered.
- Live bag events refresh both live and preview views. Carry edits, blank reset,
  Escape cancellation, string-key cleanup, zero targets and the Missing filter
  are checked. A low selected bandage rank remains missing; an untracked one does not.
- Separate character SavedVariables are serialized and restored into a fresh Lua
  runtime. Pet Guide navigation, minimap behavior and 95 class/view/width layouts
  also pass. Existing 1,830 Hunter/pet pairs retain independent level gates.

`layout-previews/makeover-*.png` shows the current supply, Emergency, narrow,
preview, rank-picker and Pet Guide layouts. These were inspected using substitute
fonts and icon boxes. They are simulations, not screenshots from the game client.

Remaining client check: `/reload`, click Preview and change the level, return to
your character, buy/use/split an item stack and watch its quantity update. Change
a Carry target, choose a profession rank, switch Missing only, then reload/relog
to confirm persistence. Verify real fonts, item textures, scrolling and focus on
the installed client; these cannot be certified by a frame mock.

## Version 1.2 simplified home (historical)

Home now contains only action buttons, with no supply recommendations or advice
text displayed until a section is opened. The default window is 520x400. The
Hunter lookup is labeled Pet Guide; its embedded file is Data/PetGuide.lua.
Existing navigation, data and source-copying checks pass after the rename.

## Version 1.1 companion redesign (historical)

The original recommendation checks below still pass. The website-style main view
has been replaced, so its older layout notes below are historical evidence.
Additional Lua 5.1 checks now cover:

- 540 bounded dashboards, each with three supplies and at most two next steps.
- Every Petopia family, all 111 rank details, 559 creatures, 145 appearances and
  five care guides. Pagination traverses the complete catalog without duplicates.
- Multiword and literal-punctuation search, with Owl searches excluding Howl.
  Level filtering excludes untameable and over-level creatures and gives no tame
  suggestions below Hunter level 10.
- Drill-down/back navigation, restored searches, item/source copying, rare labels,
  class changes, level events, saved preferences and the existing minimap behavior.
- 140 class/view/width layout combinations across all nine classes and widths of
  480, 650, 720, 1040 and 1280 UI units.

`layout-previews/companion-*.png` documents the new dashboard at 480 and 680 widths,
Warlock context, Supplies, Petopia search/family details and narrow Preview. These
were inspected as simulations with substitute fonts/icons, not game screenshots.

The remaining real-client check is to `/reload`, open `/hcb` or the minimap book,
and verify Now, Supplies, Companion, Hunter Petopia, source copying and Back.
Check actual fonts/highlights, scroll clipping, preview controls, changing pet
levels, combat navigation, window resizing and reload persistence. `/hcb reset`
now restores 680x540. Actual in-game rendering has not been tested here.

## Automated checks completed

- Actual Lua 5.1 execution using `lupa.lua51`, not a JavaScript rewrite of the port.
- 540 class/level carry lists compared with independent fixtures generated by
  preserved website JavaScript. Exact selected IDs, order, display names, short
  descriptions, options, complete progression, next unlock and additional groups.
- All 60 Hunter plans, Warlock plans and quiver plans match full website results.
- 1,830 distinct Hunter/pet level pairs and 60 unknown-pet cases. No ability is
  promoted solely because the character has outleveled the active pet.
- 1,080 compact/detailed guide models. Correct carry-card order, compact dummy
  ranks, all 17 families exactly once in detailed categories, no rare tame sources,
  and source URL export.
- Lua integration with a strict native-frame mock: startup, quiet first load,
  slash commands, visibility, saved profiles, actual-level and pet refresh,
  level input and normalization, view toggle, references, item-cache fallback,
  numeric tooltip alpha, scrolling, resize and UI scale, unsupported live class.
- SavedVariables copied into a fresh Lua runtime to verify reload/relog restore.
- 30 layout combinations across 480, 650, 900, 1040 and 1280 UI-unit widths,
  three classes and compact/detailed modes. Wide Hunter cards share a 2:1 row.
- Standalone TOC paths, source checksums and deterministic data/fixture regeneration.

The 60-level comparison includes the handoff's Troll's Blood, Agility, class
reagent, pet-source gaps, Warlock utility and bag boundaries. Grouped professions
retain all ranks and use skills; no profession is inferred from player level.

## Visual evidence

`layout-previews/*.png` are generated from the actual UI.lua frame tree under the
mock, with Pillow text measurement/rendering. Compact 480/1040, Hunter pet/quiver
1040, detailed Hunter 57 and Warlock 30 at 650 were inspected. Title width was
made explicit to avoid overlap; content wraps and scrolls inside the viewport.
Segoe UI substitutes for WoW fonts; boxes substitute for native icons. These
are clearly labeled layout simulations, not real-client screenshots.

## Remaining real-client checks

No in-game rendering, gameplay or protected-action behavior was tested here.
Website tests and mock tests do not certify addon behavior. With only Hardcore
Buddy enabled, turn on `/console scriptErrors 1` and check:

1. `/hcb` opens in My character/Compact on first install, detecting the actual
   class and level. Existing schema-1 profiles switch to automatic detection
   once while preserving preview choices. `/hcb help` and
   `/hardcorebuddy` work. Close, reopen, reload and relog; saved profile, position,
   size and visibility restore correctly.
2. Select all classes; edit level with digits, plus/minus, arrow keys, Enter and
   blur. Invalid/out-of-range drafts normalize to 1-60. Toggle both views.
3. Switch My character / Preview. Level up with live view open. Summon/dismiss a
   lower-level Hunter pet; actual recipient level gates apply and missing pet
   data reads unknown. Learned skills and profession ranks are never claimed.
4. Hover names and icons, including an uncached item. Check tooltip alpha/wrapping,
   copy source URLs through References, and close windows with Escape.
5. Drag/resize at common UI scales, change display scale, scroll long detailed
   guides to the end, and inspect clipping, scrollbar behavior, font/icon rendering
   and side-by-side versus stacked Hunter cards. `/hcb reset` recovers the window.
6. At relevant boundaries, inspect dummy 85/185/275, bandage use versus craft
   skill, Charge's missing rank, optional dungeon Bite 8, all family categories,
   Felhunter 30 without Spell Lock until 36, and the level-40 routine bags through 60.
7. Confirm Self Found/faction/quest/recipe/travel cautions and optional routes remain
   visible in details. This is a reference guide, not a live availability or
   cooldown simulator. Check opening/closing during combat does not produce errors.

## Website cleanup

Before cleanup, the retained reviewed JSON, original model JavaScript, six
research files and workbook were checked byte-for-byte against the supplied
website copy. Regeneration is byte-identical without reading the website folder.
The deletion target was resolved to exactly
`C:\World of Warcraft\_classic_era_\Interface\AddOns\HardcoreBuddy\CXL-Website`,
inside the intended addon folder, with no reparse points in the tree.

Automatic approval review rejected both the validated deletion command and a
retry with the literal absolute path, reporting only `blocked by policy`.
No alternative mechanism was used to bypass that restriction. A later filesystem
check confirmed the website copy had been removed externally. Data generation,
fixture generation and the complete automated suite were rerun successfully with
that folder absent. Cleanup is complete; the real-client checks above remain
explicitly untested.
