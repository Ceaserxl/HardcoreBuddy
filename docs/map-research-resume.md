# NPC research checkpoint

This pass added 482 usable Wowhead Classic NPC pages, bringing the verified
individual-page count from 560 to 1,042. Four Dragons of Nightmare use the
separate portal guide. Requests now use a two-second delay by default, also
recorded in the saved resume command. The first three pages of this pass were
saved before the delay was changed from five seconds to two.

The retrieval queue completed without access errors; no retry was needed.
**34 NPC records remain** without usable individual Wowhead page coordinates.
All 34 pages loaded but had no usable Classic zone coordinates; zero records
are awaiting their first successful retrieval attempt. Their IDs remain in
`pagesWithoutCoordinates` and are skipped by the normal resume script.

All 639 pre-existing cache files were preserved byte-for-byte. The offline
rebuild covers 46 zones and 1,080 NPCs. Records without any mapped coordinates
decreased from 102 to zero. Questie fallback remains where needed: a cached
Wowhead page does not mean every spawn location is Wowhead-sourced.

Progress is in `docs/map-research-progress.json`; HTML caches are under
`.release/map-research`. The normal resume command is:

`python scripts/resume_map_research.py --delay 2`

It currently has no unprocessed requests. The remaining 34 records need
separate review of the pages without coordinates, rather than repeated runs
of the unchanged queue. Rebuild with `python scripts/build_map_data.py` after
adding any verified coordinates.

Validation passed: request pacing/cache/error-stop tests, map advisor tests,
zone table tests, leveling-zone tests, cache hashes, catalogue identity and
progress-count checks. These are offline checks, not in-game visual testing.

Paste back:

> Resume HardcoreBuddy NPC research from docs/map-research-progress.json.
> The normal retrieval queue is complete: 1,042 usable individual Wowhead pages,
> 34 pages without usable coordinates remain for separate review. Preserve
> caches and Questie fallback. Use a two-second delay between requests; on
> access errors wait 30 seconds and retry once, then stop if it fails again.
> Rebuild, validate, commit, and report remaining counts.
