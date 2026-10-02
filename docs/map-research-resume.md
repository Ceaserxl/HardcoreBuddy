# NPC research checkpoint

Previous pass: 122 usable pages added, stopped at NPC 5915 with HTTP 403 and
637 remaining.

This pass cached 121 additional Wowhead Classic NPC pages with usable map
coordinates, bringing the verified individual-page count to 560. Four Dragons
of Nightmare use the separate portal guide. The generated catalogue still
supplements missing locations with Questie data; a cached page does not mean
every spawn location is Wowhead-sourced.

Stopped at NPC 8207 with HTTP 403, waited 30 seconds, and retried once. The retry
also returned HTTP 403, so requests stopped. **516 NPC records remain** without
usable individual Wowhead page coordinates: 485 awaiting retrieval and 31 pages
that loaded but had no usable Classic zone coordinates. No challenge bypass was
attempted. All 518 pre-existing cache files were preserved byte-for-byte.

The offline rebuild covers 46 zones and 1,080 NPCs. Records without any mapped
coordinates decreased from 108 to 102. Questie fallback remains where needed.

Progress is in `docs/map-research-progress.json`; HTML caches are under
`.release/map-research`. Run `python scripts/resume_map_research.py` to retry the
remaining queue (starting at 8207), then `python scripts/build_map_data.py` to
incorporate successful pages. Known pages without coordinates are skipped by
default; their IDs remain in `pagesWithoutCoordinates` for separate review.

Paste back:

> Resume HardcoreBuddy Wowhead NPC research using docs/map-research-progress.json
> and scripts/resume_map_research.py. Last blocked: NPC 8207, HTTP 403. 516 remain,
> including 31 pages without usable coordinates. Preserve caches, pause for 30
> seconds on access errors and retry once; if it fails again stop. Rebuild,
> validate, commit, and report remaining counts.
