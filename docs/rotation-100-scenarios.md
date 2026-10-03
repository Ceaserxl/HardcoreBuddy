# Rotation Helper: 100-scenario run

Date: 2026-10-02. Runtime tested: `2ea21af`.

**99 passed; 1 failed.** This run combines the 50 cooldown scenarios with 50
additional scenarios. All case names are unique, and the runner asserts that
exactly 100 cases execute. Production rotation code was not changed by this run.

| Coverage | Cases | Passed |
| --- | ---: | ---: |
| Cooldown readiness, GCD, emergency choices, items and prior fixes | 50 | 50 |
| Target safety, range, control and immunity | 20 | 20 |
| Buffs, resource thresholds and defensive conditions | 20 | 20 |
| Cast transitions, action-bar notices and unsupported classes | 10 | 9 |

## Finding: revised timing can break the cast commitment

1. Start a Frostbolt cast with GUID `same-cast`, start time 100 and finish time
   103. The next Main recommendation is Frostbolt.
2. At time 101, keep the same GUID and target, revise the start/finish times to
   100.5/103.5, and lower the target to 14% health within Fire Blast range.
3. Expected: the existing Frostbolt recommendation remains committed.
4. Actual: Main changes to Fire Blast before the current cast finishes.

`RotationHelper/Runtime.lua` builds its cast token from both the API cast ID and
start time. The same GUID therefore produces a new token when the start time
changes. `RotationHelper/Engine.lua` interprets that token as a new cast and
replans. An isolated control with only the finish time changed preserves
Frostbolt, confirming that the start-time component causes this result.

The next fix should use a stable cast identifier when available, while retaining
a suitable fallback for channels/clients without one. Timing updates should
adjust the prediction window without replacing the committed action.

This is reproduced with simulated API values. It does not establish how often
the live client revises those values, nor whether this event order has occurred
in the user's game. These tests do not certify optimal DPS or live glow rendering.

## Validation and reproduction

```text
python tests/run_rotation_scenarios.py --suite hundred --strict --output docs/rotation-100-scenarios.json
```

The strict command exits with status 1 for the documented unmet expectation.
[Individual results](rotation-100-scenarios.json) include expected and actual
outcomes for all 100 cases.

The existing broader audit also ran successfully: 75/75 named expectations and
3,888 combinations with zero structural violations. Its cases do not include
this same-GUID start-time revision, so those passes do not resolve the new finding.
