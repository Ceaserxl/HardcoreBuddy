# Rotation Helper: 100-scenario run

Date: 2026-10-02. **100/100 pass after the cast identity fix.** The original run
against `2ea21af` passed 99 and found the timing issue described below. The
[200-scenario follow-up](rotation-200-scenarios.md) includes this suite and 100
additional timing and lifecycle combinations.
Policy expectations now include the subsequent [choice review](rotation-clarity-review.md).

This suite combines the 50 cooldown scenarios with 50
additional scenarios. All case names are unique, and the runner asserts that
exactly 100 cases execute.

| Coverage | Cases | Passed |
| --- | ---: | ---: |
| Cooldown readiness, GCD, emergency choices, items and prior fixes | 50 | 50 |
| Target safety, range, control and immunity | 20 | 20 |
| Buffs, resource thresholds and defensive conditions | 20 | 20 |
| Cast transitions, action-bar notices and unsupported classes | 10 | 10 |

## Resolved: revised timing could break the cast commitment

1. Start a Frostbolt cast with GUID `same-cast`, start time 100 and finish time
   103. The next Main recommendation is Frostbolt.
2. At time 101, keep the same GUID and target, revise the start/finish times to
   100.5/103.5, and lower the target to 14% health within Fire Blast range.
3. Expected: the existing Frostbolt recommendation remains committed.
4. Before the fix: Main changed to Fire Blast before the current cast finished.
5. After the fix: Main remains Frostbolt and observed cast timing follows the
   revised finish time. The later [handoff fix](rotation-handoff-fix.md) also
   prevents completion from expiring that next-action choice.

The old token included the mutable start time. The runtime now uses the API cast
ID independently of timing, preserving START-event GUIDs for channels and
numeric or absent API IDs. A genuine new START still allows a fresh decision.

This is reproduced with simulated API values. It does not establish how often
the live client revises those values, nor whether this event order has occurred
in the user's game. These tests do not certify optimal DPS or live glow rendering.

## Validation and reproduction

```text
python tests/run_rotation_scenarios.py --suite hundred --strict --output docs/rotation-100-scenarios.json
```

The strict command now exits with status 0.
[Individual results](rotation-100-scenarios.json) include expected and actual
outcomes for all 100 cases.

The existing broader audit also ran successfully: 75/75 named expectations and
3,888 combinations with zero structural violations.
