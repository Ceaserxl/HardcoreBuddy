# Mage rotation scenario audit

Original audited implementation: `a1eff0d` (cooldown eligibility gate removed).
Follow-up: missing action-bar chat notices and brighter four-category glows.
Date: 2026-10-02.

**Result: more work is needed before calling the recommendations reliable.**
All 115 regression checks pass. The expanded audit now meets 40 of 47 named
expectations and passes structural checks across 3,888 combinations. Seven
targeted cases still expose policy or event-handling gaps. The original audit
reported eight; the missing-action-bar case now passes with a local chat notice.

## Coverage and limits

The new fixture exercises the actual spell rebuild, API snapshot, selector, and
selected event handlers with simulated WoW API inputs. It covers levels 1, 4,
10, 20, 40, and 60; legal sample Frost, Fire, and Arcane talent paths; three
health and mana bands; normal and elite targets; melee, ranged, and out-of-range
distances; solo and grouped combat; and ready versus cooling-down abilities.
Named cases also cover interrupts, crowd control, recovery supplies, buff
refreshing, stronger Intellect buffs, and cast/event transitions.

Across the matrix, no result contains multiple Main actions, duplicate actions,
unknown spells, or out-of-range enemy recommendations. Existing regression tests
also cover macro matching, cast commitment, lifecycle handling, and native glow
ownership.

These are offline simulations, not live-client or damage simulations. Mana costs
are synthetic; the matrix checks consistent selection rather than optimal DPS.
Event-order cases demonstrate what happens if those inputs arrive in that order;
they do not establish how often that order occurs in WoW. Actual glow appearance,
server latency, encounter results, and action-bar addon integration still need
live testing.

## Findings

| Priority | Scenario | Current result | Needed improvement |
| --- | --- | --- | --- |
| High | Low health, Ice Block unavailable, Cold Snap ready | Ice Block claims the survival group and hides Cold Snap. | Keep the ready emergency reset visible. |
| High | Low health, Ice Barrier unavailable, Mana Shield ready | Barrier claims the shield group and hides Mana Shield. | Keep a usable emergency shield visible. |
| High | Target below 15% health, Fire Blast cooling down | Fire Blast becomes the only Main recommendation despite a usable filler. | Provide an actionable Main or a clearly separate usable fallback. |
| High | Successful cast charges mana before the casting API clears | Snapshot reserves the same cast cost again and temporarily hides the committed Main. | Reconcile success events and pending mana cost. |
| Medium | Interruption event arrives before the casting API clears | The interrupted cast's old Main remains locked until its original finish time plus 0.25 seconds. | Invalidate the matching interrupted cast immediately. |
| Medium | Four Fire Vulnerability stacks with 1/3 Improved Scorch while casting Scorch | The planner assumes the fifth stack and switches to Fireball. | Account for a failed stack application when talent rank is below 3/3. |
| Medium | A cast begins with insufficient mana for a next action, then mana recovers | The empty plan stays locked for the rest of the cast. | Allow an empty plan to gain an action without replacing an existing committed Main. |
| Resolved | Frostbolt is preferred but only Fireball is on the action bar | Local chat identifies the missing Frostbolt rank once per session. | Add the spell or a matching macro; hidden/paged slots are also checked. |

The first three cases are consequences of deliberately removing the cooldown
gate, rather than failures to implement that request. Cooldown suggestions can
remain visible, but they should not hide the only usable action in their group.
The audit does not restore a cooldown gate.

The partial Scorch case matters because rank 1 has a 33% chance to apply Fire
Vulnerability; the pending cast cannot guarantee another stack.
[Improved Scorch spell data](https://www.wowhead.com/classic/spell=11095/improved-scorch).

## Recommended order

1. Resolve the three unavailable-action conflicts while retaining the desired
   cooldown hints.
2. Fix cast-success mana accounting and interrupted-cast invalidation.
3. Correct partial Improved Scorch prediction and allow empty plans to fill.
4. Exercise the missing-action-bar feedback and brighter glows in live solo and
   group encounters.

## Reproduce

Use Python with the existing test dependencies, including Lupa:

```text
python tests/run_rotation_helper.py
python tests/run_rotation_scenarios.py --output docs/rotation-scenario-audit.json
python tests/run_rotation_scenarios.py --strict
```

The exploratory command exits successfully when it finishes with no structural
violations; it still prints every policy gap. `--strict` exits with status 1 while
any named expectation remains unmet. The full case list and actual selections
are in [the JSON report](rotation-scenario-audit.json).
