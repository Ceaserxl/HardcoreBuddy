# NPC research checkpoint

This pass cached 108 additional Wowhead Classic NPC pages with usable map
coordinates, bringing the verified individual-page count to 317. Four Dragons
of Nightmare use the separate portal guide. The generated catalogue still
supplements missing locations with Questie data; a cached page does not mean
every spawn location is Wowhead-sourced.

Stopped at NPC 4061 with HTTP 403. **759 NPC records remain** without usable
individual Wowhead page coordinates, including 16 pages that loaded but had no
usable Classic zone coordinates. No challenge bypass was attempted.

Progress is in `docs/map-research-progress.json`; HTML caches are under
`.release/map-research`. Run `python scripts/resume_map_research.py` to retry the
remaining queue (starting at 4061), then `python scripts/build_map_data.py` to
incorporate successful pages. Known pages without coordinates are skipped by
default; their IDs remain in `pagesWithoutCoordinates` for separate review.

Paste back:

> Resume HardcoreBuddy Wowhead NPC research using docs/map-research-progress.json
> and scripts/resume_map_research.py. Last pass stopped at NPC 4061 with HTTP 403;
> 759 records remain, including 16 pages without usable coordinates. Keep existing
> cached pages, stop on access errors, rebuild map data after successes, validate,
> commit, and report the remaining count and next continuation prompt.
