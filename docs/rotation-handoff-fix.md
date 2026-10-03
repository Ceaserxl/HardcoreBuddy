# Hold the advertised spell through cast completion

October 2, 2026. The user reported Main switching at the end of a cast despite
the previous fixes. The old tests incorrectly allowed the handoff to expire.

## Reproduced failures

Against `92e9058`, a new 36-case boundary suite passed 19 and failed 17:

- Main changed from Frostbolt to Fire Blast when the completion gap reached
  250 ms, even though the player had not started another action.
- SPELLS_CHANGED and PLAYER_TALENT_UPDATE cleared the commitment during the
  final 100 ms of a cast.
- Other refresh events and extra failed keypresses exposed the expired handoff.
- A hard-cast success without a matched START GUID could be mistaken for
  consuming an instant when the casting API had already cleared.
- Normal channel completion was treated as an interruption.

These are reproduced simulated inputs, not a claim that every one occurred in
the user's client.

## Corrected contract

The next Main is chosen when a cast starts and remains the same through its
completion. **Elapsed time does not release the advertised action.** A new cast
start chooses the following action; successful use of the held instant consumes
it. Target changes, confirmed interruptions/failures, disabling the helper and
world lifecycle changes retain their existing behavior. Invalid targets, range,
resources or cooldowns can hide the held choice without substituting another.

Spellbook, talent, action-bar and macro refreshes preserve the commitment.
START-event GUIDs are retained if the casting API publishes the cast later.
The adapter checks that a consumed instant has zero cast time instead of
assuming every unmatched success is an instant.

CHANNEL_STOP marks a channel ended and removes its stale casting API entry;
it does not discard Main by itself. An explicit INTERRUPTED/FAILED event or
CHANNEL_STOP with an interrupting GUID permits a new decision. The event payload
is documented in [Blizzard's Classic Era unit API definitions](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua).

## Validation

- **41/41 handoff cases pass**, including the original 36 and five deferred-API
  or stale-channel cases. Gaps of 0, 100, 250, 300, 500, 1,000 and 3,000 ms retain
  the same recommendation; each following START permits a new choice.
- **200/200** existing scenarios pass. Their former timed-expiry expectation now
  requires preserving the advertised action; channel-cancellation fixtures
  provide explicit interruption evidence.
- **64/64** choice cases and **115/115** regression checks pass.
- **75/75** audit cases pass; **3,888** combinations have no invariant violations.

```text
python tests/run_rotation_scenarios.py --suite handoff --strict --output docs/rotation-handoff-scenarios.json
python tests/run_rotation_scenarios.py --suite two_hundred --strict
python tests/run_rotation_scenarios.py --suite clarity --strict
python tests/run_rotation_scenarios.py --strict
python tests/run_rotation_helper.py
```

[Individual results](rotation-handoff-scenarios.json) record the expected and
actual selections. These are offline checks of the real event handlers and
selector. The exact live-client event sequence and rendered glow still require
in-game verification.
