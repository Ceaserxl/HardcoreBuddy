# Rotation Helper: 200-scenario follow-up

Date: 2026-10-02. **200/200 scenario expectations pass.** The cast identity fix
resolves the timing finding from the previous 100-scenario run.

## Fix

Changing a cast's start or finish time no longer changes its identity when an
API cast ID or matching START-event GUID is available. Main remains committed;
the completion window follows the revised finish time. Matching success and
interruption events still handle mana charging and release correctly. A real
new START gets a new plan, including overlapping replacement casts and channels.

For channels and clients without an API cast ID, the adapter preserves the
START-event identity across overlapping intervals of the same spell. If neither
identifier is available, it falls back to spell and start time rather than
assuming two observations must be the same cast.

## Coverage

| Coverage | Cases | Passed |
| --- | ---: | ---: |
| Cooldown readiness, GCD, emergency choices, supplies and prior fixes | 50 | 50 |
| Safety, buffs, resources, cast transitions and action-bar notices | 50 | 50 |
| Cast identity, timing revisions and lifecycle combinations | 100 | 100 |
| Total | 200 | 200 |

The 100 new combinations cross:

- Four API forms: string GUID, numeric API ID plus START GUID, channel plus
  START GUID, and missing API ID plus START GUID.
- Five timing revisions: finish delay, half-second shift, one-second shift,
  shortened timing, and repeated shifts.
- Five outcomes: continued commitment, success with paid mana, matching
  interruption, unrelated failed keypress, and a genuine new START. New START
  cases include both sequential and overlapping cast intervals.

Each combination starts with a Frostbolt recommendation, lowers the target into
Fire Blast finisher range, and checks that timing changes cannot trigger a late
switch. It also checks that the hold window follows the updated finish time.

Additional validation: **115 existing regression checks**, **75 named audit
expectations**, and **3,888 matrix combinations with zero invariant violations**.
The runner checks unique names and requires exactly 200 cases in this suite.

## Reproduce

```text
python tests/run_rotation_scenarios.py --suite two_hundred --strict --output docs/rotation-200-scenarios.json
python tests/run_rotation_helper.py
python tests/run_rotation_scenarios.py --strict
```

[Individual results](rotation-200-scenarios.json) record expected and actual
outcomes. All commands exit with status 0.

These are offline Lua simulations using the real adapter and selector with
mocked game inputs and synthetic mana costs. They verify selection and event
handling under those inputs, not optimal DPS, live event frequency, server
latency, or rendered glow appearance. Those still require in-game testing.
