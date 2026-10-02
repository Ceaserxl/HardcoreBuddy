# Rotation log review - October 2, 2026

Read-only source: Gnomerotwo SavedVariables, written October 2 at 2:20:04 PM, 14,108,949 bytes. Reviewed sessions started at Unix timestamps 1790974963 and 1790974614. Preserved decoded copies in the Codex task workspace as rotationDiagnostics-seventh-review.json and rotationDiagnosticsPrevious-seventh-review.json. The source game cache was not modified.

## Coverage

Newest session: 7,906 samples over 1,040.695 seconds (17:20), including 2,301 in-combat samples. Previous session: 2,113 samples over 347.556 seconds (5:47), with no in-combat samples. Talents are recorded and marked ready in every sample of both sessions. The character is a level-41 Mage with Improved Frostbolt 5, Ice Shards 5, Shatter 5, Frost Channeling 3, Piercing Ice 3, Elemental Precision 2, Arctic Reach 1, Frostbite 3, Improved Frost Nova 2, Ice Barrier and Cold Snap.

## Findings

Frostbolt remains the main damage decision (2,227 samples in the newest session). It uses learned Rank 7, a 2.5-second cast, 136 mana and a nonfrozen damage estimate of 402.906. These are observed recommendation estimates, not measured actual DPS. Fireball decisions occur when the live Frostbolt range check fails while Fireball remains in range; at 505.346 seconds, both spells are usable and Frostbolt has the higher estimate, but only Fireball reports range=true. This is a range fallback, not an ignored Frost specialization or movement rule.

The cast lock was held in 1,860 samples. Ten selected-action changes occurred with the same cast token and target. These include target death, lost range, Nova becoming redundant after a freeze, out-of-combat preparation changes during Conjure Mana Jade, an urgent Counterspell override and the interruption race described below. Selected-action fields can show an optional buff after the primary disappears; this does not mean the buff replaced the combat primary highlight. No active Intellect, Ice Armor or Barrier above 300 seconds was redundantly included in optional actions.

The previous session is useful for preparation and talent availability, but cannot validate combat behavior. The newest session contains out-of-range and cooldown error events; these alone do not prove advisor errors because the player can press any action and recommendations deliberately lead cooldown completion.

## Applied fix

At 219.226 seconds UNIT_SPELLCAST_INTERRUPTED cleared a committed Frost Nova plan while UnitCastingInfo still exposed the same Frostbolt cast token with 0.73 seconds remaining. The immediate update created a fresh Frostbolt plan before UNIT_SPELLCAST_STOP cleared the cast. This violates the intended cast-start stability during the event transition.

The shared coordinator now remembers the interrupted cast token, cancels only the matching plan and prevents a new nonurgent plan while that interrupted token remains exposed. Urgent advice is still allowed. An unrelated interruption cannot cancel the active plan. Normal advice resumes when the token clears or changes.

Lost range, dead targets, redundant freezes and Evocation still suppress invalid actions. No movement or mount gates were added. No speculative damage-priority changes were made from these captures.

## Validation

1,004 rotation, live adapter, native highlight, macro, UI and logging regression checks passed. New checks cover matching and unrelated interruption tokens, stale UnitCastingInfo, urgent advice and recovery on cleared/new casts. Offline validation does not establish live-client performance; another reload and capture are needed to verify the event-order fix in game.
