# Mage Rotation Advisor

The accepted highlight/macro infrastructure is retained. Rogue support and the
old Mage prototype priorities have been replaced by a Mage-only Classic Era
level 1–60 decision engine. Enable Assistant Mode under Rotation Advisor Settings;
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

Between fights, optional red highlights suggest Intellect, an armor buff, Ice
Barrier and safe Evocation. Existing armor buffs and Arcane Brilliance are
respected. During combat, Evocation requires a healthy, undamaged Mage whose
target is occupied in a group and has a sufficiently long estimated life.

Damage choices compare Fireball, Frostbolt, Scorch, Arcane Missiles and appropriate
Pyroblast opportunities. Estimates include rank damage, coefficients, actual cast
times, school bonuses, relevant talents, crit, Shatter, vulnerability and mana
pressure. Solo approaching attackers can take precedence with a Frostbolt slow.
Fire Blast finishes enemies or supplies instant damage while moving; it does not
displace a normal filler just because its damage per GCD is higher. Presence of
Mind, Arcane Power and Combustion are used when their observed context supports
them. Scorch upkeep is reserved for longer Fire fights. Wand fallback does not
tell the player to toggle an already active Shoot off.

Area comparisons include Arcane Explosion, Blast Wave, Cone of Cold, Flamestrike
and Blizzard. Nearby unengaged or crowd-controlled enemies and unknown positions
suppress affected area advice. Ground spells require an observed cluster around
the target; solo Blizzard also requires a distant slowed/frozen target and
Improved Blizzard. Only the target is counted as confirmed inside Cone of Cold;
facing one enemy does not prove that all others are in the cone. Recently cast
Flamestrike is not immediately overwritten. Ground placement remains manual.

## Highlight timing

Gold uses Blizzard's spell-alert animation; red indicates optional preparation.
The addon owns separate cosmetic overlays and leaves native proc alerts intact.
Macros are matched by Blizzard's resolved spell ID, including modifier changes
and explicit ranks. The addon does not parse, create or rewrite casting macros.

Normal casts and the GCD do not clear the next recommendation.
Once a next damage spell is selected during a cast, it stays selected through
completion and a one-second handoff, or until the next cast starts. Ordinary
damage reranking cannot switch it just as the player presses the prepared spell.
Urgent survival/interrupt advice, changed targets, crowd control, lost range,
insufficient mana, immunity and unsafe AoE still invalidate that choice.

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
not simulated. Utility such as portals, conjuring, Amplify/Dampen Magic and group
buff assignment remains manual. PvP, other class rotations and third-party bar
integrations are outside this Mage helper.

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
