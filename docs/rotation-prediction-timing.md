# Predict before the current cast finishes

October 2, 2026. Follow-up to cast-handoff stability: a stable choice can still
be late if its conditions use the state before the current cast.

## Reproduced failures

The new timing suite passed **11/22** against `7ba8c28` and **22/22** with this
change. These are offline sequences through the real adapter and selector.

- With 220/1,000 mana and a 100-mana Frostbolt starting, the old Main remained
  Frostbolt. It now advertises wanding immediately for the projected 120 mana.
- With 480/1,000 mana and the same cast, a ready mana gem now appears at START,
  before the player falls below its 45% threshold.
- Scorch refreshes and Frostbolt slow refreshes use the aura duration remaining
  after the current cast/GCD. The old rules could lock another filler while
  the aura was approaching its refresh window.
- When START precedes UnitCastingInfo, the next Main is sent to Glow:Apply in
  that same event using the reported cast time. Previously the old action
  stayed visible until the API appeared on a later polling tick.

## Boundaries retained

The forecast feeds Main's conditions. Defensives still check live health and
resources. Current target health, range, crowd control, immunity and group-pull
safety remain authoritative. Damage, crits, enemy movement and future procs are
not guessed. This does not claim to predict every combat outcome.

The forecast reserves unpaid cast mana once and includes reported casting
regeneration. Channels already paid for are not charged again. Missing channel
duration is not estimated. The START fallback uses
[the client's spell-info cast time](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua).

The early recommendation retains its identity through API arrival, the queue
window and cast completion. Actual interruption still releases it. No movement
gate, automatic casting, action-bar mutation, saved logging or UI geometry was
added.

## Validation

- 22/22 new prediction cases, including values passed to Glow:Apply during START.
- 41/41 cast-handoff cases.
- 200/200 scenario cases and 64/64 choice cases.
- 75/75 audit cases; 3,888 combinations with zero invariant violations.
- 115/115 regression checks; class isolation and assistant-only checks pass.

```text
python tests/run_rotation_scenarios.py --suite prediction --strict --output docs/rotation-prediction-scenarios.json
python tests/run_rotation_scenarios.py --suite handoff --strict
python tests/run_rotation_scenarios.py --suite two_hundred --strict
python tests/run_rotation_scenarios.py --suite clarity --strict
python tests/run_rotation_scenarios.py --strict
python tests/run_rotation_helper.py
```

The live client's event ordering and rendered animation still require in-game
verification; the cases above establish the reproduced timing defects offline.
