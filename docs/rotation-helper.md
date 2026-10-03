# Rotation Helper: shared rules, Mage policy

Enable it in **Companion > Rotation Helper** on a Mage. It starts disabled per
character. This is a new assistant, independent of the retired prototype. It
highlights actions; it never casts, edits a macro, or changes an action slot.
There is no combat-history recorder or saved diagnostic log.

## What each glow means

| Tint | Meaning | Selection |
| --- | --- | --- |
| Gold | Main: the next attack | One at a time |
| Red | Defensive: interrupts, roots, shields, dispels, emergency immunity | Separate from Main |
| Violet | Offensive: ready optional damage abilities or a carried mana gem | Separate from Main |
| Blue | Preparation: buffs, food, water, conjuring a mana gem | Several may appear together out of combat |

All use a private copy of Blizzard's native spell-alert animation. The loop
starts directly, so there is no oversized birth animation or repeating restart.
An additive second pass makes all four colors brighter at the same size and
animation speed. Both passes stop together when the recommendation clears.
Native procs and other addons keep ownership of their own glows. Standard action
bars and discovered Bartender, Dominos and ElvUI action-slot buttons are supported;
other action-bar addons can register buttons with `RotationHelper.Glow:Register`.
Macro matching uses the client's currently resolved spell or item, including
conditional spell macros. A macro that only runs arbitrary Lua has no resolved
spell to highlight. The ability must be on a visible action bar.

If a recommended spell is absent from the action bars, a local chat notice names
it and asks you to add the recommended rank or a matching spell macro. Each
missing spell rank is reported once per session (until reload/login), across all
four categories. Hidden and paged action slots count as present; they do not
trigger a missing-spell notice. Items do not trigger these spell notices.

## Shared rules

- Only learned spells and carried recovery items are eligible. Rank changes and
  talent changes refresh the available actions. Actual player data is used even
  if the field kit is previewing another character.
- The shared cooldown gate applies to spells and items in all four categories.
  Main attacks may be highlighted up to two seconds before becoming ready, or
  when they will be ready at the current cast's completion, whichever is later.
  Other categories require a ready cooldown now. The GCD is ignored for spells.
  Unavailable choices are hidden, allowing the next eligible action in their
  group to appear, such as Cold Snap instead of Ice Block or Mana Shield instead
  of Barrier. No extra violet hint is shown for a cooling-down Main attack.
  Main plans mana up to two seconds ahead.
  At cast start it plans for that cast's completion, reserving its mana
  cost and crediting only reported casting regeneration. It does not predict
  random procs, damage, or uncertain future resource gains.
- The next Main action is committed at cast start and survives a short completion
  handoff. An empty plan may fill when mana recovers; once filled, it stays
  committed. Success events prevent reserving an already-paid cast cost again.
  Matching interruptions, failures and channel endings release the old plan even
  if the casting API has not cleared it yet. Cast identities keep failed extra
  keypresses and late events from cancelling a different cast. Target changes
  also permit a new plan. Range loss or breakable crowd control hides a committed
  action without substituting another spell near the end of the cast.
- Defensive and preparation advice updates independently. There is no movement
  sampling, movement gate, or mounted gate. Death, flight and an active
  incapacitating class immunity clear recommendations.
- Enemy actions require a live, attackable PvE target, confirmed spell range and
  no breakable crowd control. Unknown range is not treated as in range.
- The general group policy uses engaged targets. It does not select a target,
  initiate an AoE rotation, or assume that visible units represent every enemy.
  Observed crowd control on nameplates suppresses Nova advice. A player still
  judges whether an area spell can safely be used.
- Short-lived immunity evidence is limited to the spell that failed. A creature
  immune to Nova is not assumed immune to Frostbolt damage.
- Supported self buffs refresh at five minutes remaining. A stronger intellect
  elixir suppresses a weaker Arcane Intellect recommendation. Preparation pauses
  while eating or drinking.

## Mage policy

Frostbolt is the safe single-target baseline as soon as learned; Fireball covers
the opening levels and unavailable Frost damage. Fire investments favor
Fireball after establishing a solo slow, and directly on engaged group targets.
Pyroblast is a Fire opener. Improved Scorch is reserved for durable targets and
only anticipates a pending stack or refresh at 3/3 talent rank. Lower ranks keep
planning from confirmed stacks and expiration times. Wanding conserves low mana; Fire Blast is a
low-health finishing option. Neither finisher claims a guaranteed killing blow.

Counterspell, Nova, shields, Remove Lesser Curse, Ice Block and Cold Snap are
independent defensive suggestions. Nova prefers the lowest learned rank actually
on a bar, otherwise the highest learned rank. Mana Shield is for emergencies,
not routine maintenance. Cold Snap is suggested only under pressure with a
survival cooldown unavailable. Damage cooldowns and mana gems remain optional.
Solo preparation favors Ice/Frost Armor; groups favor Mage Armor. An existing
armor buff is respected until its refresh threshold.

This first version deliberately concentrates on solo Hardcore leveling and
conservative group support, not a dungeon AoE or raid damage optimizer. It does
not infer safe Blink landing positions, choose Polymorph targets, or count mobs
outside observable unit tokens. These remain player decisions.

## Architecture

| File | Responsibility |
| --- | --- |
| `RotationHelper/Engine.lua` | Pure selection, readiness and cast commitment |
| `RotationHelper/Runtime.lua` | Live API snapshot, learned ranks, events, lifecycle |
| `RotationHelper/Glow.lua` | Action/macro matching and cosmetic native animation |
| `RotationHelper/Supplies.lua` | Shared carried food and drink selection |
| `RotationHelper/Mage.lua` | Spell definitions, aura definitions and ordered conditions only |
| `RotationHelper/UI.lua` | Compact enable control and explanation |

Future class modules supply the same spell definitions and predicates over the
snapshot. They must not call game APIs, register events, create frames, or save
combat state. A rule returns a reason when applicable. Its category and optional
group determine whether it competes for Main or a utility slot.

## Fresh research

Reviewed October 2, 2026:

- [Wowhead: Hardcore Mage leveling](https://www.wowhead.com/classic/guide/classes/mage/hardcore-leveling-tips):
  basis for Frost control, wand conservation, Fire alternatives, preparation and
  emergency-only Mana Shield. The Hardcore emphasis takes precedence over
  advice to maintain Mana Shield for general leveling.
- [Icy Veins: single-target Frost leveling](https://www.icy-veins.com/wow-classic/single-target-frost-mage-leveling-talent-build-from-1-to-60):
  cross-check for learned-rank progression, self buffs and single-target attacks.
- [Blizzard Classic Era spell-alert source](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.lua)
  and [native template](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.xml):
  animation ownership, sizing and loop behavior.
- [Blizzard cast API and events](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua):
  cast identifiers, success/interruption payloads, and channel events.
- [Improved Scorch](https://www.wowhead.com/classic/spell=11095/improved-scorch):
  partial talent ranks do not guarantee a vulnerability stack.

The rules and thresholds above are implementation decisions, not copied optimal
damage formulas. No retired rotation implementation was restored.

## Verification

`tests/run_rotation_helper.py` checks scenario sequences rather than isolated
spell priorities: late target-health changes, committed mana, cooldown-filtered
highlights, range changes, macros, roots versus immunity, stronger buffs, recovery,
disabled state, unsupported classes and native-glow ownership. The legacy
cleanup test still verifies that old saved traces are discarded.

Offline mocks establish logic and layout behavior. Live WoW must still verify
the animation, action-bar addon compatibility, actual client aura/range returns,
and queued casts under latency. Useful first checks: level 1, a Frost Mage with
Nova, a Fire Mage with Improved Scorch, and a level-40+ Mage with Ice Barrier.

`tests/run_rotation_scenarios.py --strict` adds legal talent/level combinations
and event-order cases, including unavailable emergency choices, mana charging,
matching versus unrelated cast endings, channels and partial Scorch ranks. The
latest results are recorded in `docs/rotation-scenario-audit.md` and its JSON file.

`tests/run_rotation_scenarios.py --suite cooldown --strict` runs exactly 50
cooldown scenarios: GCD normalization, readiness boundaries, emergency fallbacks,
damage abilities, mana gems, food/water, cast transitions, previous audit fixes,
and missing-action chat. Results are in `docs/rotation-cooldown-scenarios.json`.

`tests/run_rotation_scenarios.py --suite hundred --strict` combines those 50
cases with 50 additional safety, resource, timing and action-bar scenarios. See
`docs/rotation-100-scenarios.md` for the current result and outstanding finding.
