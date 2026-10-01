# HardcoreBuddy

A standalone companion for **WoW Classic Era / official Hardcore, levels 1–60**.
No libraries, other addons, website or network connection are required.

## Open your field kit

Use `/hcb` or `/hardcorebuddy`, or click the skull-and-shield minimap emblem.
Drag the minimap button to reposition it. Escape closes the window. `/hcb reset`
centers it; `/hcb help` lists commands.

All lists use continuous scrolling, including the Pet Guide and Death Journal.
Use the mouse wheel or scrollbar to browse the full list.

## Settings

Open the **Settings** tab or use `/hcb settings`. The sidebar groups General,
Gear Advisor, Auction House, Death Alerts, Death Banner, Low Health, Rares,
Elites, and Preparation. Long pages scroll. Existing saved preferences are kept.
General includes the minimap button, field kit upgrade notices, and recentering.
Carry quantities and item priorities remain in Supplies; talent paths remain in
Advisors. `/hcb health` and `/hcb deaths settings` open their Settings sections.

## Supply priorities and preparation

**Supplies > Essentials** collects core food, drink, buff food, bandages, healing,
movement potions and relevant ammunition. Items still live in their usual tabs.
Each row shows Essentials, Advanced or Optional; open its details to cycle the
priority. Priority choices follow the item family as ranks improve. Carry targets
are per item and character; set 0 to skip restocking.

**Supplies > Class** tracks arrows for bows/crossbows, bullets for guns, or your
equipped thrown weapon stack. It uses selected ammunition when available and
otherwise suggests a level-appropriate vendor tier. Planning mode has its own
ammo selector. Wands do not produce ammo recommendations.

**Settings > Preparation** has two controls, both on by default: a compact
missing-essentials panel while resting in a city/inn, and a silent reminder when
leaving. Reminders use the real character, respect Carry 0, suppress unknown stock,
stay out of combat, and have a five-minute cooldown. Dismiss the panel for the
current visit with its close button. An unowned Light of Elune has no default
restock requirement.

Drag the **Missing essentials** panel to move it. Its position is saved between
sessions; clicking it still opens your Essentials supplies.

**Supplies > Buffs** checks your equipped chest armor, leggings, gloves and boots
for armor-kit upgrades. It respects both your character level and each piece's
item level, recommends kits for unenhanced pieces or older armor kits, and keeps
other enchants and Core Armor Kits. Suggested Carry quantities cover the pieces
that need each kit. Open a kit to see which pieces to enhance. Recommendations
refresh when equipment or enhancements change; unavailable item data stays
unknown. Planning mode shows a level-based reference without checking live gear.

## Gear and talent advisors

Open **Advisors** in HardcoreBuddy, `/hcb gear`, or `/hcb talents`.

- Color-coded gear upgrade/downgrade percentages using Classic specialization stat weights.
- Follows the build selected in **Settings → Talent Advisor**, including automatic Hardcore leveling paths.
- Open **Stat Weights** in **Settings → Gear Advisor**, with **Restore Defaults** for the active profile.
- Green arrows and borders mark upgrades in native bags, Baganator bags and quest reward choices.
- Compares every usable armor material by slot, without penalizing lighter armor.
- Shows both ring/trinket slots, handles two-handed replacements and lists stat losses.
- Excludes applied enchants and armor kits from both scores.
- Hardcore talent paths for all nine classes, with current ranks, next-point advice,
  explicit respec guidance and one continuous point-by-point list.
- WoW's existing talent rank numbers show current/recommended ranks for your
  selected build, such as **2/5**.
- Separate **Disable Gear Advisor** and **Disable Talent Advisor** buttons in their
  Settings pages.
- Click **Learn** to spend a single recommended point, or browse other classes
  using **Edit Character**. Points are never spent automatically.

The gear percentage measures weighted item stats, not simulated damage or survival.
Procs, active item effects and set bonuses are excluded. See [advisor details](docs/advisors.md).
Use **Settings → Gear Advisor → Gear Snapshot → Snapshot Current Gear** to save gear and talent
information for offline review. The saved item list is on the snapshot page;
`/reload` or log out to write it to disk.

## Map advisor

Open **Advisors > Map** to reveal unexplored outdoor terrain or tint unexplored
areas translucent blue. Category filters show known dangerous NPCs, rares,
elites and bosses. Browse any Classic zone, or follow your current zone.
An optional **Silent zone-entry notice** lists known dangers in chat without
playing a sound. Pins mark recorded spawn areas, not live sightings; missing
coordinates stay clearly labelled in the zone list. See [sources and coverage](docs/map-data.md).

## Auction house upgrades

Open **Upgrades** at the auction house and click **Scan upgrades**. The tab uses
the native auction-tab style and works without any other auction addon.

- **Best by slot** shows the strongest available recommendation for each slot,
  without filling the overview with slots that have no upgrades.
- A persistent slot picker opens all alternatives directly, including empty
  slots. Results scroll continuously, with no paging controls.
- Clear item cards separate score changes, listing prices, buyouts and bids.
  **Find auctions** opens the normal Browse search; it does not buy the item.
- Hover an upgrade to see currently equipped items automatically, without
  holding Shift or changing your global tooltip settings.
- **Compare weapons** compares both complete weapon setups, with their combined
  price and individual components available under **View items**.
- Scan progress stays visible while browsing. Empty states distinguish slots
  that have not been scanned from those with no upgrades found.
- Includes every usable armor material, jewelry and weapons, using the same
  scoring profile and percentages as HardcoreBuddy's gear tooltips.
- Searches one equipment slot at a time, finishing its pages before moving on.
- **Settings > Auction House > Best Armor** restricts body armor to your class's
  highest armor type for its level (for example, **Best Armor: Mail** for hunters
  at level 40+). Off by default and saved per character. Jewelry, cloaks, shields,
  held off-hands and weapons remain eligible. Changing it requires a fresh scan.
  The same checkbox is also available beneath **Scan upgrades** in the AH window.
- Shows listing prices, merges duplicate item variants using their cheapest
  buyout (or next bid), and keeps different random suffixes separate.
- Click an alternative to search for its auctions in the normal Browse tab.
  Confirm the exact item variant and current price there before purchasing.

Use **Compare weapons** to compare **Two-handed** against **1H + off hand**. Both
percentages use the total score of your currently equipped hands. The paired
view considers replacing either item, replacing both, or reusing equipped gear;
it includes shields, caster off-hands and dual-wield weapons where usable.
Each candidate is shown with its best legal partner. Open a setup to see both
items and search for either purchase. The total price includes every required
listing. Your equipped setup remains available as a zero-change option, and
lower-scoring alternatives appear in red. These are weighted gear scores, not
simulated damage or survival estimates.

Scanning takes time because the auction house returns one page at a time. Keep
the Upgrades tab open; another auction search or changing tabs stops the scan.
Stopped scans and missing data are labeled as partial results. Gear or talent
changes require a new scan. Prices are for the full listing, not per item.
Empty slots show **Empty slot** instead of an invented percentage. Weapon setups
compare both hands together; other slots are compared independently.

If listings cannot be read, click **Scan details** or use **`/hcb auction debug`**.
The copyable report includes the item link, failure reason, search slot/page,
retry timing, item stats and native tooltip text. The latest failed scan is saved
per character across reloads, limited to 25 skipped listings. A successful scan
does not erase that report. Click **Select report**, then **Ctrl+C** to copy it.

## Dungeons and raids

The **Dungeons** and **Raids** tabs contain 28 dungeon routes/wings and all seven
Classic Era raids. Search by instance or zone, or filter by level band or raid
size. Each entry shows its suggested level range and a compact list of items
to bring, with icons, requirements, tooltips and live bag counts. Item rows name
the relevant mobs and abilities, including whether to use a potion before an
effect or to cleanse afterward. Everyday
supplies link directly to the relevant field-kit category.
Suggested levels are planning guidance, not entrance requirements.

While inside an instance, **Current Dungeon** or **Current Raid** appears above
the content on every tab. Click it to open the packing list. Shared instances such as
Scarlet Monastery open a wing chooser. Detection follows your actual location
even while editing a planned character. Zygor and DBM are not required.

## Death journal and alerts

**Settings > Death Alerts** defaults to **Original (Deathlog default)**, the
native WoW raid-warning sound used before the custom bell. It uses WoW's Master
volume; the Play alert sound checkbox mutes it. The custom bell and five Deathlog
clips (Hero Fallen, Arugal, Dread Hunger, Hunger Games and Golf Clap) retain the
independent alert volume slider. Use the arrows to choose; click the name to listen.
Deathlog does not need to be installed. Credits and original sources are in
`Media/Deaths/Deathlog/README.md`.

HardcoreDeaths is built into HardcoreBuddy. Select the **Death Journal** tab in the main
window, right-click the shared minimap button, or use `/hcb deaths`. The `/hd` and
`/hardcoredeaths` aliases also open this page.

Reports and player details appear in the right-hand content area. Death options
and appearance are in **Settings > Death Alerts** and **Settings > Death Banner**.
The main window controls positioning and scale; compact feed and alert overlays
keep their separate position/scale settings.

The journal uses separate Level, Adventurer, Location, Cause, Source and When
columns, plus summary statistics and search/minimum-level controls. Leading
"a"/"an" is omitted from displayed causes; original reports remain in details.
Under **Settings > Death Alerts**, set **Alert display duration** from 1 to 30
seconds (default 3). Press Enter or leave the field to save; Escape cancels an
edit. The alert remains visible for that duration, then fades for half a second.
The setting applies to new alerts and previews and survives login.
Sound is enabled by default; an existing saved sound choice is preserved.
**Supplies > User**, after Optional, lets you add personal items by dragging them
from your bags anywhere onto the content page. Drops add immediately. Set their
Carry quantities and track bag counts. Click a user item to open its details,
then choose Remove item to remove it from your list. The list
is saved per character. Uncached items display their ID until their name loads.

**Supplies > Scrolls** lists the highest usable rank of Agility, Strength,
Stamina, Intellect, Spirit and Protection scrolls. Recommendations follow your class and
live or planned level, with exact-item bag counts, editable carry quantities
and item details. The catalog covers all 24 Classic Era ranks.

**Settings > Low Health** (`/hcb health`) controls a flashing red **LOW HEALTH!** warning
with an air horn. It defaults to below 40% health, matching the existing aura;
the threshold, warning and sound are configurable. The alarm plays once on entry
and the warning clears on recovery or death. Preview runs for three seconds.
It works independently of death alerts, planning mode and menu visibility.
Disable the old Low Health WeakAura to avoid duplicate warnings. WeakAuras is
not required; distribute `Media/Health/` with its attribution and font license.

Level-ups that change the field kit show a small, silent, borderless
**HardcoreBuddy: supply upgrades available** notice toward the right of the screen.
It lasts four seconds, then fades. Click it to open the live kit; the complete
list is also printed in chat. Unchanged levels stay quiet, and preview settings
do not affect detection.

**Settings > Death Banner** offers Compact (default), Banner, and Text-only
death alerts. Background opacity is independent of text. **Unlock and move**
keeps a silent preview visible while you drag; **Save position** locks it and
restores click-through behavior. All styles share a saved position and scale
down on smaller screens. Banner retains the symmetrical iron-and-silver artwork.

The journal includes searchable history for your realm, level filters, player details, statistics, and Deathlog history import. The compact
live feed uses a 360 x 218 panel with six compact, unframed reports, prominent levels,
separate name, location and age columns, plus a feed-status indicator and Open journal button.
Drag its header to move it; the minus button hides the feed without stopping
death tracking. Only Blizzard's
Hardcore death announcement is replaced; ordinary raid warnings remain enabled.
The journal records reports received while you play, not a complete realm history.
Optional community reports are off by default and labeled unverified.

- `/hcb deaths settings`: feed, alert, sound, position lock, scale and level options.
- `/hcb deaths mini`: show or hide the compact feed.
- `/hcb deaths test`: preview the newest saved report for your realm (or the newest saved report
  from another realm). An example is used only when history is empty; previews
  never add history.
- `/hcb deaths import`: import history from a loaded Deathlog addon.
- `/hcb deaths resetposition`: reset death-window positions.

For this installation, HardcoreDeaths now loads after HardcoreBuddy and yields
its event handling and UI. Leave both enabled for one login to automatically
copy the old history, settings and positions into
`HardcoreBuddyDB.deaths`. The original saved data is left intact. After that
login, the separate HardcoreDeaths addon can be disabled; HardcoreBuddy runs
independently. Existing HardcoreBuddy death settings take precedence on later
imports. If distributing HardcoreBuddy alongside an unmodified HardcoreDeaths,
disable the standalone addon to avoid two active receivers.

The window has a fixed **1040 × 660** wide layout. Drag its header to move it.
On smaller screens it scales down uniformly while retaining that layout.
Use the mouse wheel or scrollbar for longer lists. There is no resize grip.

## Supplies and item details

Supplies opens to Food & drink. Recommendations show exact **In bags** quantities,
editable **Carry** targets and per-item stock status.
Healing/mana potions are under Emergency; elixirs are under Buffs.
All combines Food & drink, Buffs, Emergency and Optional into one scrolling list
with category headings and no pages. Supplies has no search, Missing-only button
or stock-summary strip, so the item list starts directly below navigation.
The category sidebar stays visible on item, profession and pet detail pages;
choose a category there to return directly to its list.

Click a Carry number, type an amount and press Enter. Zero disables that target;
clearing it restores the suggestion. Bag counts exclude bank stock and update
when items are looted, bought, used or moved. Unavailable counts stay Unknown.

Hover an item row or icon for its native tooltip, with an embedded-description
fallback for uncached items. Click for acquisition, requirements and alternatives;
Back sits above the right content area and restores the previous category.
The Carry field has its own editing
help. Sources buttons, URL export and runtime research metadata are removed.
Item details use labeled fields for effects, crafting profession and skill,
profession rank and its character-level gate, recipe acquisition, Auction House
eligibility, materials and use requirements. Recipe and finished-item trading
are distinguished. Recipe eligibility does not mean the character knows it.

## Your character and planning

Class, level, faction and active pet level are detected automatically. Exclusive
quest rewards and routes appear only for the correct faction. Shared/tradable
items stay available with appropriate local/trading guidance. Unknown faction
suppresses exclusive recommendations and shows a notice.

**Plan another character** opens class/level controls below the artwork;
**Return to my character** restores live guidance. Planning still uses the actual
character's faction, bags, professions and training level gates. A planned Hunter
pet is explicitly assumed to match the planned level; live pet level is detected.

## Profession upgrades

Bandages, anti-venom and target dummies automatically track the strongest recipe
you know and can craft at your First Aid or Engineering skill. Recipe/skill changes
update that choice. Old manual pins are ignored; exact-item Carry targets persist.

Click a profession row for its next upgrade, required skill, acquisition and
recipe-item AH eligibility. Guidance prefers the strongest missing recipe you
can currently craft; otherwise it shows the next future tier. It distinguishes
trainer recipes, tradable manuals and bind-on-pickup recipes. AH eligibility does
not imply current listings, and Self Found characters cannot use the AH.

Companion includes First Aid, Engineering and Cooking progression. These cover
skill-cap trainers, Expert books, faction-specific Triage routes and Clamlette
Surprise requirements/ingredients. Optional introductory quests are distinguished
from required training. Recipe/manual rows have their own native item tooltips.
Crafting materials/tools, auction listings and quest objectives are not tracked.
Unknown skill/recipe information is labeled. Crafting and use requirements remain
separate; training always uses the actual character, including while planning.

## Companion and Pet Guide

Companion offers class advice, pet training, demon utility and professions.
Hunters open **Companion > Pet Guide** for an offline searchable index of
**17 families, 21 abilities / 111 ranks, and 559 creatures**, plus five care guides.
Its sections are Families, Abilities, Pets, and Care. Appearance descriptions
remain on individual creature pages.
Routine Hunter routes favor accessible early zones for the current faction.
The complete wild-creature catalog stays available: beasts are not faction-locked
by their home zone. Rare, elite, group and unavailable entries are labeled.
Learned pet/demon abilities are not assumed.

The factual pet index was researched from Petopia Classic. Attribution and
research records remain in `docs/PROVENANCE.md` and `reference/`; website images,
logos and full articles are never loaded by the game.

## Saved preferences and artwork

`HardcoreBuddyDB` saves planning choices, mode, position, visibility and minimap
angle, plus death history and preferences under `deaths`.
`HardcoreBuddyCharacterDB` saves each character's Carry targets. Actual
character data is read fresh. The field kit and death journal stay closed until
opened; the compact death feed is visible by default.

The field kit uses a campsite banner filling the header, a larger vertically
centered skull shield, flat dark
background and status-colored item rows. Embedded TGAs need no external downloads.
Original generated PNGs, prompts and import steps are in `docs/ARTWORK.md`.
This is an independent addon, not an official Blizzard product.

## Development and distribution

GitHub Actions now builds each push and publishes numeric version tags to
GitHub and CurseForge as normal releases with numeric version names.
See [release instructions](docs/RELEASING.md).

The Death Journal also records the official Hardcore death-chat channel,
independently of Blizzard's raid-warning selection. With chat set to everyone
and warnings set to guild, received chat deaths enter the journal and compact
feed silently; native warnings still produce alerts once. Both event orders
are deduplicated. This does not change your chat or warning settings and cannot
recover earlier messages that were never recorded.

`python scripts/generate.py` rebuilds five Lua datasets from reviewed JSON,
stripping research URLs while preserving gameplay creature sources.
`Data/FactionRules.lua`, `Data/Crafting.lua` and `Data/ProfessionProgression.lua` contain reviewed
route and training rules. Research/provenance remains outside runtime data.

`python tests/run.py` uses Python, `lupa.lua51` and Node.js for development checks.
`python tests/run_deaths.py` checks death behavior, migration, shared controls,
full TOC loading and saved-data persistence with Lua 5.1.
`python tests/render_layout.py` also uses Pillow and Windows fonts for labeled
layout simulations, not game screenshots. None are runtime dependencies.

Build a release ZIP with `python scripts/package_release.py`. The builder uses
an explicit runtime manifest, verifies TOC entries and version consistency, and
includes required audio credits, licenses and source clips. It excludes tests,
research, preview images, source artwork, caches and retired media. The ZIP has
one top-level `HardcoreBuddy` folder, ready to extract into `Interface/AddOns`.

Use `/reload` to load changes. The TOC targets interface 11509. Automated checks
do not certify native rendering/focus; see `docs/VALIDATION.md` for results and
remaining in-game checks.

## Hunter pet spell upgrades

**Supplies > Class** shows the active Hunter pet's learned spell ranks and the
highest obtainable upgrade that meets both Hunter and pet level requirements.
Each upgrade lists a beast, level range and zone, or directs you to a pet trainer.
Click a skill to inspect its rank and sources. Normal outdoor beasts and nearby
faction routes are preferred over elite/group sources. Check Beast Training
before taming if your Hunter already knows the upgrade. Preview mode and missing
pet data never imply a learned rank.

Scroll recommendations use class roles: Agility for physical/hybrid classes,
Strength for melee/hybrid classes, Intellect and Spirit for mana users, and
Stamina and Protection for everyone. These are suggestions, not use restrictions.
Custom items can still include any scroll.

HardcoreBuddy automatically checks membership in the official HardcoreDeaths
channel (localized for your client) after login/reload and rejoins if membership
is lost. This is independent of optional community reports and death banners.
Failed join requests are retried at most once per minute.

Creature alerts include 226 NPC-ID exclusions based on the installed Unitscan
Hardcore default elite/faction lists, including flight masters. Defaults respect
the actual player faction, including while planning another character. These
exclusions suppress both alerts and automatic raid markers. Rare and rare-elite
warnings remain independent; Unitscan's unchecked rare category is not imported.
The addon embeds its own table and does not require Unitscan to be installed.
