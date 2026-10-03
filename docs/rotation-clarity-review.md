# Rotation Helper choice review

October 2, 2026. Reviewed the choices and transitions after the user reported
incorrect recommendations despite passing the earlier rule-consistency tests.

## Changes

| Confusing behavior | Revised behavior |
| --- | --- |
| An idle player sees a finisher with up to two seconds of cooldown left. | Use a ready attack. During a cast or GCD, plan an ability that will be ready when that action ends. |
| A future mana forecast displaces an attack affordable now. | Prefer an affordable attack; forecast up to two seconds only when no attack is affordable at the next action. |
| A full-mana Mage switches to a wand below 12% enemy health. | Enemy health alone never selects the wand. A ready, affordable Fire Blast can remain the finisher. |
| Mana ticks make wand and spell suggestions alternate. | Enter conservation below 15% mana and continue until 25%; a new target resets it, and Clearcasting permits a spell. |
| Utility talent points change Fire/Frost filler choice. | Compare damage-focused school talents. Frost is the default when neither school has greater damage investment. |
| Fire filler continues with a slow about to expire. | Plan Frostbolt when the slow will expire by the next action, using at least a two-second window. |
| Scorch stacking starts on a nearly dead elite. | Stop selecting the Scorch ramp below 20% target health. |
| Damage cooldowns appear before a pull, without a usable attack, or alongside a wand. | Require an engaged durable target and a compatible Main spell. Combustion only supports Fire attacks. |
| Joining/leaving a group changes the armor suggested for refresh. | Preserve the active armor type; use solo/group defaults only when armor is absent. |
| Buffs invite interrupting an opener or Evocation. | Suppress preparation through attacks, Evocation, and unmodeled casts. |
| Water and Evocation compete. | Prefer carried, usable water; retain Evocation as the fallback. Food and water may still coexist. |
| Hypothermia is searched only among helpful auras. | Include harmful player auras. Do not suggest resetting Ice Block while Hypothermia blocks it, or Barrier while its shield remains active. |
| Editing a macro or updating a bar changes Main mid-cast. | Preserve the cast plan across those rebuilds. |
| An instant just used remains highlighted while cooldown data lags. | Briefly suppress repeat Fire Blast, Nova, and Counterspell advice after success. Consuming a held instant clears the previous cast handoff. |
| A held recommendation outlives group pull safety or newly started drinking. | Recheck those conditions before displaying the held Main. |

The four glow categories remain. Ordinary defensive actions can coexist with
Main; recovery items and buffs may coexist when they do not interrupt recovery.
The native glow appearance is unchanged. No movement/mount checks or saved
combat logging were introduced.

The school comparison and numerical thresholds are explicit conservative
policies, not a full damage optimizer. The helper still does not predict exact
damage, guaranteed kills, missile travel, or random procs.

## Validation

- 64/64 new choice and transition cases.
- 200/200 existing scenario cases with revised expectations for intentional
  policy changes.
- 115/115 existing regression checks, including macros and glow ownership.
- 75/75 audit expectations and 3,888 combinations with zero invariant violations.

The old expectations for idle cooldown previews, full-tree filler classification,
and routine Combustion use were changed explicitly. The new cases independently
cover the desired outcomes. Other original expectations remain in place.

```text
python tests/run_rotation_scenarios.py --suite clarity --strict --output docs/rotation-clarity-scenarios.json
python tests/run_rotation_scenarios.py --suite two_hundred --strict
python tests/run_rotation_scenarios.py --strict
python tests/run_rotation_helper.py
```

[Individual choice results](rotation-clarity-scenarios.json) record expected and
actual selections. Simulations use real selection/snapshot code with mocked
inputs and synthetic costs. These results do not establish live animation
quality, client event latency, optimal damage, or that every gameplay ambiguity
has been eliminated. In-game acceptance should cover a near-death target,
back-to-back Frostbolts, instant finishers, wand mana recovery, and drinking
between pulls.

## Source checks

The adapter continues to use the client's spell cooldown and power-cost data;
see [Blizzard's Classic Era spell API definitions](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).
The policy retains the partial-rank distinction documented by
[Improved Scorch](https://www.wowhead.com/classic/spell=11095/improved-scorch).
Classic spell IDs were cross-checked against
[Ice Block](https://www.wowhead.com/classic/spell=11958/ice-block) and
[Cold Snap](https://www.wowhead.com/classic/spell=12472/cold-snap).
