# Mage rotation scenario audit

Original audited implementation: `a1eff0d` (cooldown eligibility gate removed).
Follow-ups: missing action-bar chat notices, brighter four-category glows, and
the seven remaining selection and cast-tracking fixes. The shared cooldown gate
has now been restored at the user's request.
Date: 2026-10-02.

**Result: all eight original findings are resolved in the offline tests.**
The subsequent [100-scenario run](rotation-100-scenarios.md) found an additional
cast-timing issue, now resolved: timing revisions preserve the cast identity and
committed recommendation. The [200-scenario follow-up](rotation-200-scenarios.md)
passes all cases, including 100 timing and lifecycle combinations.
All 50 focused cooldown scenarios, 115 regression checks, and 75 named audit
expectations pass, with zero
structural violations across 3,888 combinations. The expanded audit includes
late and unrelated cast events, numeric casting IDs paired with START events,
channel endings, cast stability through cooldown changes and all three Improved
Scorch ranks.

## Coverage and limits

The new fixture exercises the actual spell rebuild, API snapshot, selector, and
selected event handlers with simulated WoW API inputs. It covers levels 1, 4,
10, 20, 40, and 60; legal sample Frost, Fire, and Arcane talent paths; three
health and mana bands; normal and elite targets; melee, ranged, and out-of-range
distances; solo and grouped combat; and ready versus cooling-down abilities.
Named cases also cover interrupts, crowd control, recovery supplies, buff
refreshing, stronger Intellect buffs, and cast/event transitions.

Across the matrix, no result contains multiple Main actions, duplicate actions,
unknown spells, out-of-range enemy recommendations, or a cooldown-gate violation. Existing regression tests
also cover macro matching, cast commitment, lifecycle handling, and native glow
ownership.

These are offline simulations, not live-client or damage simulations. Mana costs
are synthetic; the matrix checks consistent selection rather than optimal DPS.
Event-order cases demonstrate what happens if those inputs arrive in that order;
they do not establish how often that order occurs in WoW. Actual glow appearance,
server latency, encounter results, and action-bar addon integration still need
live testing.

## Findings

| Status | Scenario | Verified result |
| --- | --- | --- |
| Resolved | Low health, Ice Block unavailable, Cold Snap ready | Cold Snap is visible; unavailable Ice Block is hidden. |
| Resolved | Low health, Ice Barrier unavailable, Mana Shield ready | The emergency Mana Shield replaces unavailable Barrier. |
| Resolved | Target below 15% health, Fire Blast cooling down | A usable filler is Main; unavailable Fire Blast is hidden. |
| Resolved | Successful cast charges mana before the casting API clears | The matched cast is marked paid, so its cost is not reserved twice. The next cast reserves its own cost normally. |
| Resolved | Interruption event arrives before the casting API clears | A matching cast identity releases the plan and ignores the stale API value. Extra keypresses and late events for other casts leave the current plan intact. |
| Resolved | Four Fire Vulnerability stacks with partial Improved Scorch while casting Scorch | The planner keeps Scorch rather than assuming another stack. Partial ranks also do not assume a pending refresh succeeds. |
| Resolved | A cast begins with insufficient mana for a next action, then mana recovers | The empty plan fills once and becomes committed. Further threshold changes cannot replace it mid-cast. |
| Resolved | Frostbolt is preferred but only Fireball is on the action bar | Local chat identifies the missing Frostbolt rank once per session; hidden/paged slots and resolved macros are checked. |

Cooldowns are checked in generic eligibility. Main readiness uses the two-second
planning window or the current cast's remaining time, whichever is longer.
Defensive, offensive and preparation actions must be ready now. The spell GCD is
ignored. An existing Main stays committed through the cast even when a different
ability becomes ready. If the committed action becomes unavailable, it is hidden
without substituting a late recommendation.

The partial Scorch case matters because rank 1 has a 33% chance to apply Fire
Vulnerability; the pending cast cannot guarantee another stack.
[Improved Scorch spell data](https://www.wowhead.com/classic/spell=11095/improved-scorch).

## Live verification still needed

1. Trigger emergency advice with Ice Block or Barrier already on cooldown.
2. Cast near the mana threshold, interrupt a cast, and use consecutive casts of
   the same spell to verify stable highlights under actual client latency.
3. Check Scorch stacking with partial talent ranks, plus missing-action-bar
   feedback and the brighter four-category glows.

## Reproduce

Use Python with the existing test dependencies, including Lupa:

```text
python tests/run_rotation_helper.py
python tests/run_rotation_scenarios.py --output docs/rotation-scenario-audit.json
python tests/run_rotation_scenarios.py --strict
python tests/run_rotation_scenarios.py --suite cooldown --strict --output docs/rotation-cooldown-scenarios.json
```

The exploratory command exits successfully when it finishes with no structural
violations; it still prints every policy gap. `--strict` also requires every named
expectation to pass and now exits with status 0. The full case list and actual selections
are in [the JSON report](rotation-scenario-audit.json).

The requested 50 focused scenarios and their individual outcomes are in
[the cooldown report](rotation-cooldown-scenarios.json).
