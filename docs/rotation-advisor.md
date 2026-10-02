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
2. Required Nova setup for a solo Shatter opportunity.
3. An appropriate distant Pyroblast opener or an active Presence of Mind Pyroblast.
4. Safe observed AoE: Flamestrike then Blizzard on a verified cluster, or Blast Wave
   then Arcane Explosion for nearby engaged enemies.
5. A conservative short wand finish or a noncritical Fire Blast finisher.
6. Improved Scorch upkeep for a Fire profile on a substantial grouped/boss target.
7. The main attack, followed by a fixed fallback order when range, immunity, a
   school lockout, mana or cooldown readiness makes it unavailable.
8. Instant damage or the wand when the normal attacks are unavailable.

Critical-health checks are heuristics, not guarantees of survival. Other health,
range, mana and AoE thresholds also remain conservative rules. Spell damage is
estimated; Fire Blast finishing uses a reduced noncritical estimate. Unknown
wand damage never invents a finishing opportunity. Active Shoot is not toggled off.

## Four recommendation categories

| Category | Color | Meaning |
| --- | --- | --- |
| Main | Gold | One next combat action, including required setup or an urgent response. |
| Offensive Support | Purple | Optional damage cooldowns supporting Main. |
| Defensive | Red | Situational protection, escape, interrupts and control. |
| Preparation & Recovery | Blue | Buffs, food, drinks, gem creation/use and mana recovery; several can appear together. |

Each recommendation has one category. A Main action takes precedence over an
auxiliary recommendation for the same spell. Threat-specific Barrier advice is
Defensive; routine Barrier upkeep is Preparation. Immediate survival emergencies
become Main. The old generic optional color and missing-versus-expiring buff
color rules have been removed, along with multiple gold preparation actions.
Category descriptions appear in Settings and the recommendation tooltip, with a
color legend on the advisor page. Action bars display glows only.

For solo Shatter Mages, offensive Nova setup is Main: root first, then Frostbolt.
It is never an optional offensive glow beside a gold Frostbolt. The setup requires
a nearby attacker, safe AoE, no existing freeze and health above two estimated
Frostbolt hits. Defensive Nova may still appear red at low health. Required setup
uses the same cast-start commitment as damage; an already frozen target makes
planned Nova invalid, without inserting another spell late in the current cast.

Auxiliary conditions update independently. Counterspell, wards, Blink, curse
removal and defensive control are red. Arcane Power, Combustion and Presence of
Mind are purple. Mana gems and safe Evocation are blue. Readiness, range, immunity,
CC safety and inventory checks apply. Recovery does not interrupt active drinking.

Buffs are blue whether missing or within five minutes of expiration. Unknown
expiration is not invented. An equal/stronger Intellect elixir suppresses weaker
Arcane Intellect. Preparation never creates additional gold Main actions.

`ConsumableBuffs.lua` owns class-filtered carried-supply preparation. Food and
water require recovery need; Well Fed food, elixirs and scrolls can be suggested
at full health/mana for their lasting buffs. Eating/drinking suppress repeated
recovery prompts. Active drinking also suppresses redundant Evocation advice.
Bank-only stock and items with tracking disabled are excluded.
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
the remaining cast/GCD with at least a two-second reaction lead. Enemy approach
previews require actual position/range evidence.

Invalid range, immunity, insufficient mana, crowd control or unsafe AoE can
suppress a committed action without substituting a late damage spell. A new
cast, target change or immediate survival emergency can replace the plan.
An interrupted cast token cannot create a new plan while the client briefly
continues reporting that cancelled cast.

Damage channels preview their next action in the final two seconds. Utility can
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
cast locks/events, resources, spells, auras, recommendation categories and highlighted slots/colors. Wanding
is recorded explicitly so an already-active wand is distinguishable from a missing
recommendation. Drinking state and remaining global cooldown are recorded separately
from spell readiness, which permits early previews. Target health trends remain
diagnostic observations only.

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
