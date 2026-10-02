# Rotation Advisor

Companion > Rotation Advisor provides Classic Era Mage 1-60 combat advice and
shared consumable preparation for all nine classes. Assistant Mode is per
character and disabled by default. It highlights actions; the player performs
every cast and chooses targets and ground locations.

## Stable combat advice

A character profile chooses a main attack from learned Fireball, Frostbolt and
Arcane Missiles ranks using actual talents, cast times and school spell power,
critical chance and hit. The live profile rebuilds when spells, talents, level or
equipment refresh. Temporary target conditions and available mana do not rerank
that main attack. No target death-time estimate drives priorities.

The combat list is ordered and short:

1. Immediate survival emergencies: critical-health protection/escape or a dangerous fall.
2. An appropriate distant Pyroblast opener or an active Presence of Mind Pyroblast.
3. Safe observed AoE: Flamestrike then Blizzard on a verified cluster, or Blast Wave
   then Arcane Explosion for nearby engaged enemies.
4. A conservative short wand finish or a noncritical Fire Blast finisher.
5. Improved Scorch upkeep for a Fire profile on a substantial grouped/boss target.
6. The main attack, followed by a fixed fallback order when range, immunity, a
   school lockout, mana or cooldown readiness makes it unavailable.
7. Instant damage or the wand when the normal attacks are unavailable.

Critical-health checks are heuristics, not guarantees of survival. Other health,
range, mana and AoE thresholds also remain conservative rules. Spell damage is
estimated; Fire Blast finishing uses a reduced noncritical estimate. Unknown
wand damage never invents a finishing opportunity. Active Shoot is not toggled off.

## Independent situational highlights

Counterspell, Nova, wards, Blink, Remove Lesser Curse, Polymorph, mana gems,
safe Evocation and damage cooldowns can light alongside the primary attack.
A changed utility condition clears that utility highlight without changing the
committed damage spell. For solo Shatter Mages, Rank 1 Nova is suggested against
a nearby attacker when another root is useful. An incidental Frostbite clears
Nova without blanking the Frostbolt highlight.

Crowd-control, range, mana, cooldown, immunity and target eligibility checks apply
to utility too. Counterspell and emergency actions require current readiness,
not forecast mana. Mana gems require carried inventory and enough missing mana.
Grouped recovery requires the enemy to be occupied and the player not under attack.
Burst cooldowns use grouped/boss context and remaining health rather than death-time
predictions. Only immediate survival emergencies displace the damage primary.

## Preparation and colors

Gold: one combat primary, or multiple missing buffs/preparation actions out of combat.
Red: independent situational actions. Blue: an existing buff with five minutes or
less remaining. Missing buffs return to gold. Unknown active buff expiration is
not invented. Intellect, armor, Barrier, elixirs, scrolls and lasting food buffs use
these shared refresh semantics; an equal/stronger Intellect elixir suppresses a
weaker Arcane Intellect recommendation.

`ConsumableBuffs.lua` owns class-filtered carried-supply preparation. Food and
water require recovery need; Well Fed food, elixirs and scrolls can be suggested
at full health/mana for their lasting buffs. Eating/drinking suppress repeated
recovery prompts. Bank-only stock and items with tracking disabled are excluded.
Only one buff food is suggested, preferring the Essentials choice. Mana-free
classes are not advised to drink or use intellect-only scrolls.

Preparation is separate from damage priorities. Known gem conjuring is shown
before pulling; using a carried gem remains independent during combat. Movement
and mounting do not suppress advice or substitute instant spells. Players still
need to stop or dismount when a spell requires it.

## Timing and rendering

A normal damage cast commits its next action at cast start. That action remains
through the cast and a short completion handoff. Current cast mana is reserved
before forecasting the next action. Cooldowns and mana can be previewed through
the remaining cast/GCD with at least a one-second reaction lead. Enemy approach
previews require actual position/range evidence.

Invalid range, immunity, insufficient mana, crowd control or unsafe AoE can
suppress a committed action without substituting a late damage spell. A new
cast, target change or immediate survival emergency can replace the plan.
An interrupted cast token cannot create a new plan while the client briefly
continues reporting that cancelled cast.

Damage channels preview their next action in the final second. Utility can
remain available; Evocation is allowed to finish except for an immediate survival
emergency. A primary may be absent while the wand is already firing or no eligible
attack is available.

The addon uses separate cosmetic Blizzard spell-alert overlays and leaves native
proc alerts intact. Blizzard-resolved spell macros, modifiers, ranks and item
macros are supported. Disabling stops polling and clears HCB glows. Death, flight
paths and unsuitable targets remain suppression conditions. No protected casts,
targeting, action-bar changes or secure attribute changes are performed.

## Modules and diagnostics

`Rotation/Global.lua` handles shared eligibility, spell discovery, prediction,
cast stability, highlights and diagnostics. Nine class files provide module
boundaries. `Rotation/Mage.lua` implements the combat priority list; the other
eight class files currently enable shared consumables only.

Logging starts automatically and records every update using recursive deltas.
The current session and two previous sessions are retained. Reload/logout writes
WoW's per-character SavedVariables; world transitions do not start a new session.
`/hcb rotation log mark` marks an issue and `/hcb rotation log status` prints the path:

`_classic_era_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/HardcoreBuddy.lua`

Version 2 entries store `time` and recursive `delta` fields. Logs include character
stats/talents, raw decisions, selected action, actual primary, profile main attack,
cast locks/events, resources, spells, auras and highlighted slots/colors. Wanding
is recorded explicitly so an already-active wand is distinguishable from a missing
recommendation. Target health trends remain diagnostic observations only.

## Data and validation

Numerical rank data comes from the pinned [WoWSims Classic Mage implementation](https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/sim/mage)
through `scripts/build_mage_rotation_data.py`. All runtime data ships with HCB.
See [Mage research](mage-rotation-research.md) for sources and historical reviews.
The priority rules are practical heuristics, not a guarantee of optimal DPS.
Unknown positions, unseen enemies, partial resists, projectile travel and other
players' future actions cannot be predicted reliably.

`tests/run_rotation_advisor.py` covers levels 1-60, class boundaries, stable profiles,
fixed fallbacks, independent utility, emergency overrides, forecast/cast timing,
CC/range/immunity, movement and mounting, macro/native glow behavior, preparation
and automatic logging. Offline checks do not verify live visual timing or DPS.
After reload, exercise actual combat, utility alongside casts, training/equipment
changes, cooldowns, low mana, and AoE with nearby crowd control.
