# Companion leveling zones

Companion > Zone Advisor lists suggested Classic Era questing bands for the character's
faction. These are recommended visit ranges, not the minimum and maximum level
of every mob in the zone. They follow the faction questing progression in
[Wowhead's Classic leveling guide](https://www.wowhead.com/classic/guide/classic-wow-leveling),
with context from its [Alliance guide](https://www.wowhead.com/classic/guide/alliance-leveling-classic-wow)
and [Horde guide](https://www.wowhead.com/classic/guide/horde-leveling-classic-wow).
Reviewed October 1, 2026. No addon or website runtime dependency is required.

The list contains 36 route entries, with northern and southern Stranglethorn
listed separately. It excludes capitals and zones outside this selected leveling
route; it is not intended as an exhaustive list of every possible grinding area.
Names and map destinations reuse the Classic map catalogue. Race starting zones
are limited by faction; reaching another race's zone may require travel.

The default filter includes an entry when `level >= low - 3` and
`level <= high + 3`, matching the Dungeons & Raids filter. Show all removes the
level restriction but preserves faction filtering. Search matches zone names.
Edit Character uses the planned level and the current character's faction.
Rows identify Upcoming, In range or Finishing up; inclusion below the band is a
planning aid, not a recommendation to fight higher-level enemies in Hardcore.
The list scrolls continuously. Clicking a row opens the existing world-map view.

`tests/run_leveling_zones.py` checks both factions at every level from 1 through
60, inclusive +/-3 boundaries, map destinations, faction exclusions, search,
Companion navigation, Show all and planned levels.
