# Classic Era / Hardcore beast audit

Audited 2026-09-28. Runtime facts are in `Data/Beasts.lua`; rebuild with
`scripts/build_beast_catalog.py`. This is an NPC-template catalog, not a claim
that every template currently spawns on official servers.

## Sources and precedence

- [Petopia Classic](https://www.wow-petopia.com/classic/): refreshed all 17 family
  pages and five ability/training reference pages. Provides explicit tameability
  exceptions, skill ranks, and icon names for the existing pet guide.
- [Wowhead tameable beasts](https://www.wowhead.com/classic/npcs/beasts?filter=52;-2323;0)
  and [untameable beasts](https://www.wowhead.com/classic/npcs/beasts?filter=52;-2324;0):
  downloaded both untruncated partitions (630 and 764 records). These total the
  1,394 records in the unfiltered list. Entries introduced in patch 1.15 or later
  are excluded because this database mixes in Season of Discovery.
- [CMaNGOS Classic database](https://github.com/cmangos/classic-db/blob/master/Full_DB/ClassicDB_1_12_1_z2815.sql.gz):
  historical 1.12 creature-template type, family and tameable flag facts, used to
  separate vanilla rules from SoD changes to existing NPCs. This is community
  reconstructed data, not an official current Blizzard server export.

Petopia's explicit Classic classifications take precedence. Otherwise vanilla
flags take precedence over Wowhead's mixed-season flags. Two pre-1.15 Wowhead
IDs absent from the vanilla snapshot extend the catalog. Unknown IDs remain
unclassified; missing records are never inferred to be untamable.

## Results

- 1,222 NPC records: 587 tamable, 635 untamable.
- Test, unused, and seasonal-only records excluded.
- Young Pridewing and three Core Hound entries retain vanilla untamable status.
- Spot and Stormpike Owl retain Petopia's explicit untamable status.
- Six previously unindexed Petopia entries resolved by exact unique NPC name.
- 37 tamable records have no verified skill list. They explicitly display
  `Pet skills not verified`; an empty, verified list displays `No innate pet skills`.
- Skill icons use the native icon names shown on Petopia's Classic ability page.

`beast-audit.json` records individual provenance, conflicts, seasonal exclusions
and unresolved skill sets. This audit covers the researched source catalogs;
it does not guarantee every template's behavior on every live-server variant.
