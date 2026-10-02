# Rotation log review - October 2, third capture

Source: Gnomerotwo SavedVariables written at 3:24:42 PM, 3,856,454 bytes;
read without modification. SHA-256:
`b21dc4e278a7c9f009f5871154c172cdcc68e7ff78c451c00e847163d9fd0d66`.
An exact source copy, metadata and decoded samples were preserved in the local
`rotation-log-ninth-review` analysis folder.

| Session start | Samples | Duration | Combat samples |
| --- | ---: | ---: | ---: |
| 1790979656 | 1,636 | 225.880 seconds | 280 |
| 1790979590 | 491 | 64.129 seconds | 0 |
| 1790979574 | 244 | 15.030 seconds | 0 |

All 2,371 samples report level 42, ready talent data and a Frostbolt damage
profile. The newest session includes two fights; the earlier two are preparation.

## Stable combat advice

Frostbolt remains the main combat recommendation. Its macro (macro ID 13,
action slot 69, resolved spell 8408) receives the gold highlight. Nova and the
carried mana gem appear independently without replacing the damage plan.

No different primary replaces a plan during an unchanged cast token and target.
The two removals are an interrupted cast at 110.197 seconds and a dead target at
138.165 seconds. Barrier selections after target death are preparation, not a
damage-priority substitution. Player health remains full throughout both fights;
this capture does not exercise emergency health, low-mana combat or AoE behavior.

Forecast mana reserves the current spell cost, including Frostbolt and gem
conjuring. Near-zero regeneration during the five-second rule is distinct from
the normal regeneration rate and is not evidence of a forecasting error.

## Cooldown feedback

Two "Spell is not ready yet" messages occur at 134.366 and 134.803 seconds.
Nova succeeds at approximately 133.893 seconds and Frostbolt starts at 135.393.
That timing is consistent with pressing Frostbolt during Nova's 1.5-second global
cooldown. The old trace does not record the remaining GCD directly, so this is an
inference. These are recorded game feedback messages, not Lua exception reports.

Early highlights remain enabled as requested. New traces record `gcdRemaining`
separately from a spell's intrinsic cooldown/readiness to make this distinction
visible in future captures.

## Recovery and buffs

At 161.363 seconds, drinking begins with 566/3,285 mana (17.23%). Evocation
continues glowing until mana passes 25% at 164.587 seconds, despite water already
restoring mana. The recommendation now suppresses Evocation during an active
localized Drink aura and returns when drinking ends if recovery is still needed.
Other preparation advice stays available. Traces also record `drinking`.

Water already stops highlighting during drinking. Expiring elixirs use the
requested five-minute blue warning; missing buffs use gold. Greater Intellect
blocks weaker Arcane Intellect until its aura expires. Preparation remains
available while mounted or moving. These behaviors were retained.

## Validation

1,046 offline Mage rotation, live adapter, UI, highlight and logging regression
checks passed. New cases reproduce low-mana drinking, retain independent buffs,
restore Evocation after drinking, cover localized modern/legacy spell lookup,
ignore expired auras and verify GCD/drinking diagnostic fields survive replay.
Offline validation does not establish live visual timing or optimal DPS. Reload
the addon to exercise the recovery correction and collect the additional fields.

## Follow-up: Nova flashing between Frostbolts

The player's report identifies a separate utility transition in this same log.
At 108.866 seconds (`UNIT_SPELLCAST_STOP`), Nova appears with 793 target health
and 401.933 estimated Frostbolt damage. At 108.966 (`UNIT_SPELLCAST_START`),
Nova disappears with identical health and damage. The offensive root threshold
changed from one estimated hit between casts to two during a cast. Frostbolt's
gold primary correctly remained steady, but the brief Nova invitation was confusing.

Offensive Nova now uses two estimated hits at both times. This preserves the
existing mid-cast rule against a wasteful finishing root while removing the
between-cast flash. Low-health defensive rooting remains available. Real changes
in range, root status, health, cooldown or safety can still clear utility advice.

1,053 offline regression checks passed after this correction. New checks match
the captured damage estimate, compare idle/casting advice on the recorded target,
retain Nova on durable targets and preserve low-health defensive rooting.
