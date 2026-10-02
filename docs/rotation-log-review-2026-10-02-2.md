# Rotation log review - October 2, second capture

Source: Gnomerotwo SavedVariables written at 2:33:22 PM, 14,706,380 bytes; read without modification. Preserved decoded snapshots in the Codex task workspace with the suffix -eighth-review.json.

Newest session started at 1790976225: 4,871 samples over 576.930 seconds (9:37), including 2,037 combat samples. Previous session started at 1790976006: 1,389 samples over 217.276 seconds (3:37), with no combat. Talent reads are ready throughout. The newest capture includes leveling from 41 to 42 and subsequently reports Fireball Rank 8 (10148) and Arcane Intellect Rank 4 (10156).

## Cast stability and highlights

The latest interruption correction is loaded: at 530.545 seconds an interrupted-cast lock suppresses the stale snapshot rather than creating a new damage plan. There are four selected-action changes with an unchanged cast token and target, all to an empty selection: two lost Frostbolt range checks, a freeze making the committed Nova redundant and a dead target. There are no different selected spells replacing an active same-target cast plan in this capture.

1,827 samples hold the cast-start recommendation. Logged highlights include 605 moving samples with a primary-style highlight, demonstrating that movement does not globally clear them. Styles include 945 expiring-buff refresh highlights. Sample counts are not counts of unique glows or casts.

Fireball remains a range fallback. At 180.739 seconds Scorch is a mana forecast fallback: current mana is 85, forecast mana 101.550, enough for its 100 mana but below Frostbolt's 136. Low-mana gaps can also occur while the wand is already firing; the trace does not explicitly store wanding, so that explanation should not be inferred solely from an empty recommendation.

## Confirmed channel-scoring correction

At 343.051 seconds the target has 438 HP and a 2.478-second death forecast. The scorer credits Arcane Missiles with 650.922 damage over its full five-second channel, assigning score 130.184. It penalizes Frostbolt to 24.174, and Scorch scores 119.684. Missiles incorrectly escapes the short-lifetime penalty because its full-channel total is lethal, although killing this target requires four one-second ticks.

The lethal exemption now checks whether enough channel ticks fit before the predicted death time. It covers Missiles and Blizzard and preserves the exemption when an early tick really can finish the target. The recorded state now favors Scorch over the undeliverable channel damage. This was one raw scoring decision, suppressed by an existing cast plan; it is not evidence that the player actually cast a bad Missiles channel.

## Validation

1,009 rotation, live adapter, native highlight, macro, UI and logging checks passed. Added regression checks reproduce the recorded short-life target, verify a short cast wins and preserve lethal first-tick channels. Existing cast locks, movement independence and spellbook behavior remain covered. Another reload is needed to exercise the new channel-scoring adjustment in the live client. No claim of optimal or measured DPS is made.
