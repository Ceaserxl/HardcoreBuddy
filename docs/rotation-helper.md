# Rotation Helper: shared rules, Mage policy

Enable it in **Companion > Rotation Helper**. It starts disabled per character.
Shared buff and consumable preparation supports all nine Classic classes;
combat rotation advice currently supports Mage. This assistant is independent of the retired prototype. It
highlights actions; it never casts, edits a macro, or changes an action slot.
There is no combat-history recorder or saved diagnostic log.

## What each glow means

| Tint | Meaning | Selection |
| --- | --- | --- |
| Gold | Main: the next attack | One at a time |
| Red | Defensive: interrupts, roots, shields, dispels, emergency immunity | Separate from Main |
| Violet | Offensive: ready optional damage abilities or a carried mana gem | Separate from Main |
| Blue | Preparation: class buffs, elixirs, scrolls, buff food, water, conjuring a mana gem | Several non-conflicting buffs may appear together out of combat |

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
  Main attacks must be ready now, or by the end of the current cast or GCD.
  A cooldown inside two seconds does not displace a ready attack while idle.
  Other categories require a ready cooldown now. The GCD is ignored for spells
  and preparation consumables; actual item cooldowns and disabled items still wait.
  Unavailable choices are hidden, allowing the next eligible action in their
  group to appear, such as Cold Snap instead of Ice Block or Mana Shield instead
  of Barrier. No extra violet hint is shown for a cooling-down Main attack.
  Main prefers an attack affordable at the next action. Only if none is
  affordable does it anticipate mana recovery up to two seconds ahead.
  At cast start it plans for completion, reserving that cast's mana cost and
  crediting only reported casting regeneration. It does not predict random
  procs, damage, or uncertain future resource gains.
- Main rule conditions use that same projected mana and aura time, rather than
  choosing from pre-cast thresholds and then locking a stale decision. Wand
  conservation and debuff refreshes can therefore be advertised at START.
  A carried, ready mana gem is also suggested before the cast crosses its mana
  threshold. Immediate defensive checks continue using live health/resources.
- If a confirmed START arrives before the casting API, the adapter uses the
  spell's reported cast time to publish the next glow in that event. When the
  casting API arrives, it updates timing under the same identity without
  changing the advertised action. Channels with no reported duration wait for
  their actual channel data; no duration is invented.
- The next Main action is committed at cast start and remains held after
  completion until a new cast starts or the held instant is used. There is no
  timed handoff expiry. An empty plan may fill when mana recovers; once filled, it stays
  committed. Success events prevent reserving an already-paid cast cost again.
  Matching interruptions and failures release the old plan even if the casting
  API has not cleared it yet. A channel ending normally preserves the plan;
  CHANNEL_STOP requires explicit interruption evidence to release it. Cast identities keep failed extra
  keypresses and late events from cancelling a different cast. Target changes
  also permit a new plan. Range loss or breakable crowd control hides a committed
  action without substituting another spell near the end of the cast.
  Action-bar, macro, spellbook and talent refreshes preserve the plan. Using a held instant
  attack clears that handoff; a brief success guard prevents repeat advice
  before cooldown data catches up. Group pull safety and recovery still apply
  to an existing plan.
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
  elixir suppresses a weaker Arcane Intellect recommendation. The shared catalog
  compares actual stat amounts across learned spells, carried consumables and
  active buffs received from any player. Only the strongest carried/learned
  source in each conflict group is highlighted; free class spells win ties.
  Stronger active buffs are never downgraded, even inside the refresh window.
  Items on cooldown wait without prompting a weaker consumable.
  Spell preparation pauses while eating or drinking. Needed food, water,
  scrolls and elixirs remain highlighted during eating, drinking and the GCD.
  Preparation still pauses while channeling Evocation, casting an attack, or
  casting a spell the helper does not model. Carried, usable water takes precedence over
  Evocation; food and water can still appear together.
- Buff food has its own missing/expiring buff check and can be suggested at full
  health. Mage/Priest/Warlock prefer carried mana food; other classes use the
  supplies catalog's stat-food preference. All consumables respect catalog class
  and use-level filters. Buff meals take precedence over another recovery meal.
  Starting a meal keeps its food-buff marker until the buff is satisfied.
  See [shared buff coverage and verified identities](consumable-buffs.md).

## Mage policy

Frostbolt is the safe single-target baseline as soon as learned; Fireball covers
the opening levels and unavailable Frost damage. Fire investments favor
Fireball after establishing a solo slow, and directly on engaged group targets.
This compares learned damage-focused talents in each school; utility/range/AoE
points alone do not change the filler. It is a policy heuristic, not a DPS score.
Solo Fire renews a slow that would have at most two seconds left at the next
action. Scorch's refresh threshold likewise uses its remaining duration after
the current cast/GCD.
Pyroblast is a Fire opener. Improved Scorch is reserved for durable targets and
only anticipates a pending stack or refresh at 3/3 talent rank. Lower ranks keep
planning from confirmed stacks and expiration times. Scorch does not start or
refresh its ramp below 20% target health. Wanding conserves mana below 15%,
continuing until 25% to avoid oscillation on each mana tick. It requires an
engaged target and stops for Clearcasting. Low enemy health alone never causes
a switch to wanding. Fire Blast remains a low-health finishing option when
affordable and ready for the next action; it does not claim a guaranteed kill.

Counterspell, Nova, shields, Remove Lesser Curse, Ice Block and Cold Snap are
independent defensive suggestions. Nova prefers the lowest learned rank actually
on a bar, otherwise the highest learned rank. Mana Shield is for emergencies,
not routine maintenance. Cold Snap is suggested only under pressure with a
survival cooldown unavailable. Hypothermia is read from harmful auras; Cold Snap
does not treat it as a cooldown it can reset. An active Barrier does not need a
reset. Damage cooldowns and mana gems remain optional. Damage boosts require a
compatible Main attack on an engaged, durable target; Combustion does not
accompany Frost or wand attacks.
With no armor, solo preparation favors Ice/Frost Armor and groups favor Mage
Armor. Refreshes preserve the existing armor type, including after joining or
leaving a group; physical armor can upgrade to the highest learned rank.

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
| `RotationHelper/Buffs.lua` | Shared strongest-buff selection and consumable preparation |
| `Data/ConsumableBuffs.lua` | Verified Classic item/aura identities and conflict strengths |
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
`docs/rotation-100-scenarios.md` for the results and resolved timing finding.

`tests/run_rotation_scenarios.py --suite two_hundred --strict` adds 100 cast
identity combinations: four API forms, five timing changes, and five lifecycle
outcomes. The runtime uses a stable API cast ID or START-event GUID; timing
revisions update the observed cast timing without selecting a new Main action.
Channels and casts without an API ID retain their START-event identity while
their observed intervals overlap. A new START replaces that identity, including
when a channel is clipped. Without either identifier, the fallback uses spell
and start time. Results and limitations are in `docs/rotation-200-scenarios.md`.

`tests/run_rotation_scenarios.py --suite clarity --strict` exercises 64 additional
choice and transition cases, including readiness, mana ticks, instant spell
handoffs, recovery, buff choices, and action-bar changes during a cast. See
`docs/rotation-clarity-review.md` for the revised priorities and validation.

`tests/run_rotation_scenarios.py --suite handoff --strict` checks 41 cast-boundary
cases. It reproduces late spellbook/talent refreshes, completion gaps up to three
seconds, natural versus interrupted channel endings, and a START event arriving
before the casting API. See `docs/rotation-handoff-fix.md` for the reproduced
failures and the revised completion contract.

`tests/run_rotation_scenarios.py --suite prediction --strict` checks 22 early
prediction cases, including the value sent to the glow during START before the
casting API appears. See `docs/rotation-prediction-timing.md`.

`tests/run_rotation_scenarios.py --suite buffs --strict` checks conflict
selection, active stronger buffs, item/macro glows, aura propagation and all nine
classes from level 1 to 60. Its data checks use the actual Classic aura IDs;
the older tests that incorrectly labeled 11390 as Intellect were corrected.
