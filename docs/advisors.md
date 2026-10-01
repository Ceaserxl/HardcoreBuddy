# Gear and talent advisors

Open **Advisors** in the main window. The sidebar offers **Gear**, **Talents**
and **Builds**. `/hcb gear` and `/hcb talents` open the relevant page.

## Gear scoring

The score is the sum of each intrinsic stat multiplied by the chosen profile's
weight. The displayed change is `(new score / replaced score - 1) * 100`, rounded
to two decimals. This measures the relative item score, not simulated DPS or
survival. Zero-score and empty baselines have descriptive labels.

Thirty Classic profiles cover every talent tree in all nine classes, plus Feral
tanking, melee Hunter and Fury/Protection. Automatic selection uses the live
character's most-invested tree, with tree order breaking ties. Until talent data
is available, or before spending any points, it clearly labels a leveling
default. Manual profile choices are saved per character. Edit Character never
changes the live gear-scoring character.

All usable armor materials compete by slot. There is no lighter-armor penalty
and no requirement to match the equipped material. Class, level and native red
equipment restrictions still apply. Rings and trinkets show both slots; a
two-handed weapon replaces both hands. A replacement off-hand cannot be scored
as equippable while a two-handed main hand remains equipped.

Permanent enchants and armor kits are cleared from both item links before
scanning; random suffixes remain intact. Native primary-stat text takes priority
over incomplete Classic item-stat API results. Static supported Equip stats are
included; procs, use effects and set bonuses are excluded. Lost stats appear in
red even when the total item score improves. Hunter melee stat sticks and feral
weapons do not receive irrelevant weapon-DPS value.

## Talent advice

Sixteen Hardcore paths cover levels 10-60 across all nine Classic classes.
Levels 1-9 show that talents are locked. The list has continuous scrolling,
current ranks and a next-point highlight. Edit Character can preview any class.
Default paths change phases for Druid, Rogue, Shaman and Warrior; incompatible
existing points produce explicit respec guidance. Selecting another path never
spends points or resets talents.

**Learn** spends exactly one point on click, after re-reading the live class,
level, build, talent ranks and free points. A changed recommendation, combat,
missing data or incompatible build prevents spending. Native talent coordinates
identify localized talents; ranks, tier gates and prerequisites are checked.
There is no automatic allocation or background combat calculation.

## Reference and differences

Reference inspected: the installed Zygor Classic `Item-ItemScore.lua`,
`Code-Classic/Item-ItemScore.lua`, `Data-Classic/Item-Statweights.lua`,
`Code-Classic/TalentAdvisor*.lua` and the Hardcore branch of
`Guides-Classic/TalentAdvisor-Builds.lua`. Numerical stat tables and ordered
talent selections were imported into compact data files. The advisor runtime
and UI are independent; Zygor is not required or loaded by HardcoreBuddy.
Input hashes and the import correction are in `reference/advisor/source.json`.

Deliberate differences from that reference:

- No material-based score penalties at levels 40 or 50.
- No asymmetric candidate-only hit-cap discount: the same weight evaluates both
  sides, so comparing an identical item always returns zero.
- No invented 100% score against an empty or zero-score slot.
- Relevant weapon DPS only, as described above; enchants are consistently excluded.
- The Frost single-target path moves its third Frost Channeling point ahead of
  Ice Barrier, making Ice Barrier legal at level 40 instead of the source's 39.
- No automatic equipping or multi-point talent spending.

Classic talent coordinates, rank limits, spell IDs and prerequisites come from
the pinned [WoWSims Classic talent trees](https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/ui/core/talents/trees).
The compact factual reference, individual source URLs/hashes and MIT license
are retained in `reference/advisor`. No simulation code is loaded or shipped.

## Validation

`tests/run_gear_advisor.py` covers reference scores, all-class armor eligibility,
slot handling, item-loading failures, enhancement stripping and tooltip reuse.
`tests/run_talent_advisor.py` validates every path point against Classic tier,
rank and prerequisite rules and tests live allocation safeguards and navigation.
`tests/run_gear_snapshot.py` verifies manual capture, saved-data independence,
native Character-window integration and offline reload of the saved fixture.

These are automated API/layout fixtures. Actual client appearance and live point
spending must still be checked in WoW; the tests do not constitute a live session.

The current talent API shape was also checked against the
[Classic Era Blizzard UI API definitions](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpecializationInfoDocumentation.lua).
