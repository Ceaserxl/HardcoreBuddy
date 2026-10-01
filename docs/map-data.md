# Map Advisor data and behavior

Advisors > Map covers 46 Classic Era outdoor zones and cities. It ships its data
locally and does not load or communicate with another addon. Indoor instances,
live spawn detection and discovery credit are outside this feature.

## Controls

Reveal, marker filters and zone-entry notices are in **Settings > Map**. The
**Map settings** row in **Advisors > Map** opens that page. Zone browsing and
the Open zone map / Follow current zone buttons remain in the advisor.

- **Unchanged** leaves unexplored terrain hidden; **Reveal all** draws the map
  terrain; **Tint unexplored** draws it with a translucent blue tint (default).
- Separate Dangerous, Rare, Elite and World boss filters control pins and lists.
  Their custom map icons are crimson claw marks, a silver dragon, a gold dragon
  and a horned skull, respectively. The transparent artwork draws at 22 pixels
  and keeps its apparent size as the map zooms.
  Matching icons appear beside each filter and in marker tooltips.

- **Silent zone-entry notice** is off by default. When enabled it prints a short
  chat message, with no sound or banner, upon entering a catalogued zone.
  Notices defer during combat, suppress dungeon/raid zones and throttle repeat
  visits for five minutes. They describe known dangers, not detected creatures.
- Browse zones uses one scrollable list; Follow current zone resumes tracking
  your location. Hover map pins for names, levels, classifications and notes.

Markers use native Classic assets: `nameplates-icon-elite-silver`,
`nameplates-icon-elite-gold`, `services-icon-warning`, and
`Interface/TargetingFrame/UI-TargetingFrame-Skull`. Atlas availability is checked
before use; native texture fallbacks handle missing atlases. Classic atlas names
are recorded in the [client atlas catalogue](https://github.com/Hoizame/WoW_ClassicUIResources/blob/master/RawData/UiTextureAtlasElement.lua).
Icons remain 18 pixels at different map zoom levels. Clusters use a 12-pixel
maximum distance between all members, preventing transitive chains.

Reveal uses independent textures behind native explored overlays. Discovering an
area naturally removes its extra tint. It never changes exploration flags,
achievements, XP or the native texture pool. Texture manifests are checked
against the client's map-art ID and tile dimensions before drawing.

## Sources and scope (reviewed October 1, 2026)

The build reviewed NPC lists for every zone in Wowhead's
[Classic Eastern Kingdoms](https://www.wowhead.com/classic/zones/eastern-kingdoms)
and [Classic Kalimdor](https://www.wowhead.com/classic/zones/kalimdor) catalogues,
including the six capital cities. There are 1,080 selected NPC entries.

Wowhead rejected further NPC-page requests after a subset of pages had been
cached. Missing coordinates and Classic identity/rank checks therefore use
[Questie's Classic NPC database, v10.0.0](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicNpcDB.lua).
Classic records supplement omissions caused by Season of Discovery replacements
on Wowhead's lists (including Son of Arugal). No Questie addon code is embedded.
The four possible Nightmare Dragon portals are documented in Wowhead's
[Dragons of Nightmare guide](https://www.wowhead.com/classic/guide/dragons-of-nightmare-emeriss-lethono-taerar-ysondre-classic-wow).
All four dragons are listed at all four portals because the assignments vary.

The dataset includes database-ranked rares, rare elites, elites and bosses,
plus a curated selection of dangerous normal enemies such as Defias Pillagers.
Normal-enemy warnings are editorial guidance, not an exhaustive danger rating.
Friendly NPCs for your faction are hidden; trainer, vendor and flight-master
records are excluded. Neutral enemies can appear. Some ranked bosses are city
leaders or event creatures rather than ordinary roaming world bosses.

There are **121 records without mapped outdoor coordinates**. They appear in
their zone lists with an explicit unavailable message, never an invented pin.
Coordinates are representative spawn areas, not complete paths or live sightings.
Dense spawns are sampled into at most 12 actual recorded points per NPC/zone;
nearby points are grouped into hoverable pins to reduce clutter. Records may
include conditional quest/event spawns. The catalogue is not a guarantee of
complete coverage or a safe route. See [the build audit](map-data-audit.json) for
all reviewed zone URLs, NPC reference URLs, cached-page flags and coordinate
sources. A reference URL alone does not mean the individual NPC page was read.

The 40 outdoor map tile manifests contain factual client map-art IDs, rectangle
geometry and texture file IDs, normalized from
[Leatrix Maps' archived reveal data](https://github.com/WowInterfaces/leatrix-maps-wrath/blob/1c8a143e2fbc29afbcee39e607d0376ab53ba4c1/Leatrix_Maps_Reveal.lua).
No Leatrix functions or runtime dependency are included. Capital maps need no
fog overlay. Drawing follows the native Classic map API contract documented by
[Blizzard's exploration provider](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_SharedMapDataProviders/MapExplorationDataProvider.lua).

## Rebuilding and verification

Run `scripts/build_map_data.py` with Python and Lupa (Lua 5.1), and
`scripts/build_map_tiles.py`. Downloads/cache are under `.release/map-research`.
The NPC builder requests zone pages and uses already cached individual NPC
pages; it does not retry blocked NPC pages. These scripts never run in WoW.

`tests/run_map_advisor.py` verifies data relationships, core danger records,
portal rotation, tile geometry, independent texture ownership, exploration/map
changes, faction/category filters, silent notices and navigation with API mocks.
`tests/run_preparation.py` verifies essentials dragging and saved position in a
fresh Lua runtime. These checks do not replace live WoW visual validation.
