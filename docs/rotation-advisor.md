# Mage Rotation Advisor

The accepted highlight/macro infrastructure is retained. Rogue support and the
old Mage prototype priorities have been replaced by a Mage-only Classic Era
level 1â€“60 decision engine. Enable Assistant Mode under Rotation Advisor Settings;
the per-character default is Disabled. No action is executed by the advisor.

## Character and combat inputs

- Highest **learned** ranks, including the level-60 spell books. Level alone does
  not grant a spell. Rank-one Frostbolt is additionally kept for quick slows,
  and defensive Frost Nova uses learned Rank 1 to conserve mana.
- Actual allocated talents from the live Classic talent tree, not the selected
  Talent Advisor build. Missing talent data is retried every two seconds.
- School spell power and critical chance from the equipped character, live cast
  times and mana costs, cooldowns, current mana and regeneration.
- Health, movement, buffs, Clearcasting, Presence of Mind, frozen/slowed targets,
  vulnerability stacks, curses, interruptible enemy casts, recent incoming damage
  school, threat and observed target health loss.
- Target distance, facing and observed nameplates where the client supplies them.
  Target health trends estimate fight duration; healing invalidates that estimate.

## Priorities

Emergency Ice Block, interrupts, root/stun escape, sustained-fall Slow Fall,
self decurse, shields, wards, close-range control and defensive Cold Snap can
override damage. Polymorph is limited to eligible targeted enemies in dangerous
multi-enemy fights without an observed Mage damage-over-time effect. The player
still chooses targets and escape directions.

In combat, optional red highlights are evaluated separately from the single gold
primary action. Multiple missing buffs (Intellect, one appropriate armor buff and Ice
Barrier) can remain highlighted together through movement, casts and combat,
provided mana and readiness permit them. Intellect (including Arcane Brilliance)
and armor become optional at 60 seconds remaining; Ice Barrier at five seconds.
Refreshing clears that optional highlight. Unknown-duration buffs are not treated
as expiring. An urgent shield recommendation becomes the primary gold action;
it is not also drawn red. Safe out-of-combat Evocation is optional. During combat,
Evocation requires a healthy, undamaged Mage whose
target is occupied in a group and has a sufficiently long estimated life.

Damage choices compare Fireball, Frostbolt, Scorch, Arcane Missiles and appropriate
Pyroblast opportunities. Estimates include rank damage, coefficients, actual cast
times, school bonuses, relevant talents, crit, Shatter, vulnerability and mana
pressure. Solo approaching attackers can take precedence with a Frostbolt slow.
Fire Blast finishes enemies or supplies damage when other casts are unavailable; it does not
displace a normal filler just because its damage per GCD is higher. Presence of
Mind, Arcane Power and Combustion are used when their observed context supports
them. Scorch upkeep is reserved for longer Fire fights.

Pyroblast has a dedicated pre-combat opener: a learned usable rank, confirmed
distance of at least 25 yards, an unengaged target, at least 80% health, and enough
mana for both the opener and a filler. It must hit harder than that filler. Moving,
already casting, or an existing target DoT suppresses the long opener. In combat,
Pyroblast remains limited to Presence of Mind opportunities.

Wand finishing reads the equipped wand's damage and speed, estimates whole shots,
and considers the five-second mana-regeneration rule. It permits a quick finish
or a short low-mana regeneration window when healthy and safe; unknown wand data,
nearby attackers, recent damage and Clearcasting suppress this choice.
An approaching attacker additionally needs confirmed distance and a lasting slow.
Neither finishing nor fallback tells the player to toggle an active Shoot off.

Mana-gem preparation optionally highlights the highest learned gem when missing
from bags, outside combat and with sufficient mana. In combat, a carried usable
gem is highlighted when its maximum restoration fits the missing mana. Shared
item cooldowns are respected. Gem use waits for a current cast/channel to finish;
emergency defenses and interrupts retain priority. Direct item buttons and
Blizzard-resolved item macros are supported. Nothing is conjured or used automatically.

Area comparisons include Arcane Explosion, Blast Wave, Cone of Cold, Flamestrike
and Blizzard. Nearby unengaged or crowd-controlled enemies and unknown positions
suppress affected area advice. Ground spells require an observed cluster around
the target; solo Blizzard also requires a distant slowed/frozen target and
Improved Blizzard. Only the target is counted as confirmed inside Cone of Cold;
facing one enemy does not prove that all others are in the cone. Recently cast
Flamestrike is not immediately overwritten. Ground placement remains manual.

## Highlight timing

Gold uses Blizzard's spell-alert animation; red indicates optional upkeep.
In combat, highlighting permits one primary action plus eligible optional actions.
Out of combat, multiple preparation actions use gold together: Intellect, armor,
Barrier, gem preparation, safe recovery and eligible carried supplies. Preparation
takes precedence over pulling; urgent defenses still take priority.
Mana-gem preparation remains visible while moving as a preview for when the player stops.
Place the conjure spell on the bar to see its highlight.
The companion page displays the primary first, or an optional action when there
is no primary. Disabling the assistant clears both groups.
The addon owns separate cosmetic overlays and leaves native proc alerts intact.
Macros are matched by Blizzard's resolved spell ID, including modifier changes
and explicit ranks. The addon does not parse, create or rewrite casting macros.

Normal casts and the GCD do not clear the next recommendation.
Once a next damage spell is selected during a cast, it stays selected through
completion and a one-second handoff, or until the next cast starts. Ordinary
damage reranking cannot switch it just as the player presses the prepared spell.
Urgent survival/interrupt advice and changed targets can replace that choice.
Crowd control, lost range, insufficient mana, immunity and unsafe AoE suppress
an invalid choice without substituting a different damage spell during that
cast. The original choice returns if valid again. Even an empty cast-start plan
stays empty until the next cast or the end of the idle handoff.

Mana and cooldown forecasts cover the remaining cast/GCD, with at least a
one-second reaction lead.
Current cast mana is reserved before forecasting another spell. Damage channels
show their next action in the final second; emergency priorities remain available
during channels. Evocation is allowed to finish. Enemy approach prediction can
preview a spell just before the enemy crosses that spell's actual range boundary.

Mounting is not a suppression gate. Advice can show what to use after dismounting;
the addon does not dismount the player. Death, flight paths, friendly/invalid
damage targets, observed breakable crowd control and genuinely unavailable spells
remain appropriate gates. Disabled mode stops polling and clears only HCB glows.

## Data and boundaries

See the [Classic Mage rotation research audit](mage-rotation-research.md) for
guide comparisons, corrections and remaining modeling gaps.

`scripts/build_mage_rotation_data.py` produces `Data/MageRotationSpells.lua` from
numerical rank facts in [WoWSims Classic Mage implementations](https://github.com/wowsims/classic/tree/7779ebbf79dc7f1341e6ab939b28a3402c9a730a/sim/mage).
The generator pins that revision. Cone of Cold's rank values were checked against
the [Classic spell](https://www.wowhead.com/classic/spell=120/cone-of-cold) and its
rank tooltips (120, 8492, 10159, 10160, 10161). All runtime data ships locally;
there is no simulator, website or other-addon dependency.

Client contracts: [Classic spell APIs](https://github.com/Gethe/wow-ui-source/blob/1.15.9/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua),
[action buttons](https://github.com/Gethe/wow-ui-source/blob/1.15.9/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua),
[loss of control](https://github.com/Gethe/wow-ui-source/blob/1.15.9/Interface/AddOns/Blizzard_APIDocumentationGenerated/LossOfControlDocumentation.lua).

This is a practical priority helper, not a full encounter simulator or guarantee
of maximum DPS. Unknown enemies, line of sight, positions, resistances, future
procs and damage from other players cannot be predicted perfectly. Partial
resistance, travel time, consumable/trinket optimization and encounter scripts are
not simulated. Utility such as portals, food/water conjuring, Amplify/Dampen Magic and group
buff assignment remains manual. PvP, other class rotations and third-party bar
integrations are outside this Mage helper.

Out-of-combat supply preparation uses the current character's tracked Supplies
recommendations. Food/drink highlight below 90% health/mana unless their recovery
aura is already active. Carried elixirs with duration of at least five minutes and
scrolls highlight when their use-spell aura is missing or has 60 seconds remaining.
Unknown use spells are skipped. Ownership, usability and cooldown are read live;
the supply list refreshes every five seconds. Bank-only items and tracking targets
of zero are excluded. Item buttons and resolved item macros use the same gold glow.
The assistant neither uses items nor auto-dismounts or stops movement.

Tracked Well Fed and mana-regeneration food also highlight at full health/mana
when the lasting food buff is missing or has at most 60 seconds remaining.
Eating suppresses repeat prompts before the lasting buff applies. Only one buff
food is highlighted, preferring the Supplies Essentials choice, then higher level.
Buff names are localized through Classic spell data:
[Well Fed](https://www.wowhead.com/classic/spell=19705/well-fed) and
[Mana Regeneration](https://www.wowhead.com/classic/spell=18194/mana-regeneration).

## Validation

`tests/run_rotation_advisor.py` exercises every level with Fire/Frost/Arcane talent
emphases, combat priorities, mana/cooldown/range previews, mounted and channel
behavior, auras, immunity resets, target life estimates, legacy APIs, and native
glow/macro/UI lifecycle regressions. Protected-action sentinels reject casts,
macro changes, bindings and secure-attribute writes; repeated updates allocate
no frames. Settings geometry, navigation and lifecycle suites are also run.

Live checks still required: enable on a Mage, exercise mounted/dismounted combat,
modifier macros, actual talents and rank training, low mana, interrupts, roots,
AoE and nearby CC. Check the first and last seconds of normal casts/channels,
reload persistence, disabling and loading screens. Offline mocks cannot verify
actual client API timing, visual quality or unseen enemy geometry.

Movement alone does not promote Fire Blast or Cone of Cold over a valid filler.
Mounted characters retain preparation and recovery previews, including mana gems
and Evocation; the player must dismount to perform actions that require it.

Buff refresh colors now use actual aura duration: blue at or below five minutes remaining,
gold when missing. This applies to Intellect, armor, Barrier, tracked elixirs,
scrolls and food buffs, replacing fixed 60-second/five-second refresh windows.
Unknown-duration active buffs do not get an estimated early warning.

## Rotation diagnostics

Logging starts automatically when the character data is ready. Every rotation
update is recorded, with unchanged fields omitted through recursive deltas.
There is no sample-count cap. Logging runs in the background without diagnostics
controls in Rotation Advisor. `/hcb rotation log mark` records a searchable `USER_MARK` and
`/hcb rotation log status` prints the saved location.

On UI startup, the prior `rotationDiagnosticsPrevious` moves to
`rotationDiagnosticsPrevious2`, and the last nonempty capture moves to `rotationDiagnosticsPrevious`
and a fresh `rotationDiagnostics` begins. World transitions do not start a new
session. Logout records a final sample. WoW flushes these per-character
SavedVariables on `/reload` or logout; the addon does not create arbitrary files.
At most three sessions are retained: the current log and two previous logs.
The oldest is discarded on the next reload; empty sessions do not evict useful logs.

Open `_classic_era_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/HardcoreBuddy.lua`
and send the whole file after reloading. WoW writes the ending session under
`rotationDiagnostics` before the UI restarts; the new in-memory session and
`rotationDiagnosticsPrevious` and `rotationDiagnosticsPrevious2` are written on the next save. No manual capture,
large in-game textbox, or automatic reload is needed.

Version 2 entries contain a monotonic `time` and recursive `delta`: `fields`
updates table keys, `value` replaces a scalar, and `remove=true` deletes a key.
Replaying from the first entry reconstructs each full sample. Logs include raw
and selected advice, lock state, spell estimates/readiness, cast timing, mana and
range forecasts, buff durations, highlighted action slots and colors, UI errors,
and a stronger Intellect elixir when it blocks the learned spell.

Classic Intellect strengths are +2/+7/+15/+22/+31 for learned ranks 1–5.
[Lesser Intellect](https://www.wowhead.com/classic/spell=3166/lesser-intellect)
gives +6 and [Greater Intellect](https://www.wowhead.com/classic/spell=11396/greater-intellect)
gives +25. While an equal or stronger elixir is active, the weaker class buff is
not highlighted, including during the elixir's final five minutes.

Opening offensive casts retain damage advice before combat starts, including
the cast handoff. Ready mana gems remain auxiliary through movement and casts.
Non-rotation interactions do not create damage plans or erase forecast mana
when their power cost is unavailable. Unchanged false diagnostic values are
not written again; every update is still recorded.

Target death-time forecasts require at least four seconds and two observed
health losses. An eight-second rolling trend includes downtime between hits;
healing, target changes, and observation gaps reset confidence. Diagnostic
snapshots record the trend duration, loss count, and damage rate. This avoids
treating a single spell burst as sustained damage and preserves cast-start locks.

The next live capture exposed Fire immunity and a finishing-score edge case.
An immune pure-damage Fire Blast now temporarily blocks Fire damage spells on
that target (15 seconds); successful Fire damage clears the school evidence.
Control immunity and ordinary resists do not supply school immunity. Casts
whose estimated direct damage can finish the target are exempt from the short
death-time score penalty. Spell sent/success/failure events now record spell ID,
cast token, and the sent target name to help identify instant-cast errors.

Solo Shatter leveling now considers proactive Rank 1 Frost Nova on a nearby
attacker even at healthy HP, rather than waiting for the emergency threshold.
It requires learned Shatter, usable Frostbolt, safe nearby enemies, and enough
remaining target HP to justify the root. Grouped fights, bosses, existing
freezes, immunity, low mana, and active channels retain their safeguards.
This non-emergency choice follows the cast-start lock. Logs now include actual
talent ranks and readiness, school damage/crit, target level, grouping, hit,
haste, vulnerability stacks, and target combat context.

Buff warning glows now begin at five minutes (300 seconds) remaining for self buffs and
tracked consumable buffs, including elixirs, scrolls, and food. This replaces
the previous percentage threshold. Expiring buffs stay blue; missing buffs
stay gold. Presence-only buffs with unknown expiry do not warn prematurely.

Consumable preparation is now provided by ConsumableBuffs.lua, a shared
module independent of Mage rotation rules. It uses each class's supply plan
and item restrictions, carried stock, live aura expiry and cooldowns. All
Classic classes can enable Assistant Mode for preparation highlights; Mage
is still the only supported combat rotation. Mana-free classes do not get
water or mana-food advice. Shifted Druids check mana rather than energy/rage.
The shared refresh threshold remains five minutes, with blue warning glows
and gold missing-buff glows. Disabled still clears all HCB highlights.

## Class module layout and movement policy

Rotation/Global.lua owns the class registry, common readiness and validity
gates, learned-rank discovery, cooldown/power/range forecasts, cast-start
locking, diagnostics, and native action-bar highlights. The nine class files
are Warrior.lua, Paladin.lua, Hunter.lua, Rogue.lua, Priest.lua, Shaman.lua,
Mage.lua, Warlock.lua, and Druid.lua in Rotation/. Mage.lua owns Mage priorities,
state interpretation, talents, special ranks, resources and immunity rules.
The other eight registered modules retain shared consumable preparation only;
their combat profiles are disabled. ConsumableBuffs.lua remains independent.

Movement is telemetry only. No class recommendation or plan-retention rule
checks movement. Evocation, Pyroblast opening, ground AoE, wand finishing,
Presence of Mind, and instant fallback advice use the same non-movement
conditions while walking or standing. This does not change the client's
casting requirements. Dead/taxi, range, resources, cooldowns, immunity, active
channels, crowd control, and observed-enemy safety gates remain in effect.
