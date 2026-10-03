# Installed MaxDPS versus HardcoreBuddy

Source audit: October 2, 2026. HardcoreBuddy baseline: `2237ca4`.

MaxDPS has substantially broader class and action-bar support. Its installed
Classic Mage rotation is much smaller than HardcoreBuddy's policy, especially
for Frost. It does not solve the cast-end switching problem: its core can change
the recommended spell on every polling tick, including during an existing cast.
HardcoreBuddy has more explicit Hardcore safety, resource planning and Classic
consumable preparation, but neither implementation is a damage simulator or a
proof of an optimal rotation.

This report concerns the files actually installed in the Classic Era AddOns
directory. Retail, TBC, Cataclysm and Mists specialization files also exist on
disk, but the installed TOCs do not load those rotations. A feature present in
one of those files is not automatically a Classic feature.

## Scope and evidence

Reviewed the core lifecycle, selection loop, auras, cooldowns, resources,
range/target counting, action-button and macro resolution, highlights, options,
custom rotations, standalone spell frame, diagnostics, time-to-die and swing
tracking, and the rotation policies loaded by all nine installed class modules.
The relevant spec-selection library was also inspected. Bundled libraries and
large static data tables were not subjected to an exhaustive security audit.

All 46 TOC-loaded non-library Lua files across the ten addons passed Lua 5.1
syntax checks. Fifteen targeted source-behavior checks executed the installed
Mage files and selected actual core/helper methods with synthetic WoW APIs.
All fifteen reproduced the behavior described below. These are characterization
checks, not fifteen claims that the behavior is desirable.

HardcoreBuddy's prediction suite passed 22/22; shared buff checks passed 58/58
plus 540 class/level combinations. This establishes offline logic behavior,
not live animation quality, API compatibility, measured CPU cost or DPS.

- [Read-only comparison harness](../tests/compare_installed_maxdps.py)
- [Results, versions and source hashes](maxdps-source-checks.json)
- [HardcoreBuddy helper specification](rotation-helper.md)
- [HardcoreBuddy consumable coverage](consumable-buffs.md)

No MaxDPS files, addon settings or HardcoreBuddy runtime files were changed.

## Installed versions and entry points

| Addon | Version | Policies loaded by its installed TOC |
| --- | --- | --- |
| MaxDps | v11.3.49 | Shared framework |
| MaxDps_Mage | v11.2.9 | Classic Arcane, Fire, Frost |
| MaxDps_Druid | v11.2.11 | Classic Balance, Feral, Guardian |
| MaxDps_Hunter | v11.2.15 | Classic Beast Mastery, Marksmanship, Survival |
| MaxDps_Paladin | v11.2.12 | Generic Holy file and Classic Retribution |
| MaxDps_Priest | v11.2.9 | Classic Discipline, Holy, Shadow |
| MaxDps_Rogue | v11.2.11 | Classic Assassination, Combat, Subtlety |
| MaxDps_Shaman | v11.2.10 | Classic Elemental, Enhancement |
| MaxDps_Warlock | v11.2.10 | Shared Classic DPS policy |
| MaxDps_Warrior | v11.2.11 | Classic DPS and Protection |

The core loads the player's class addon on demand, not all nine class policies
for every character. An enabled custom Lua rotation can replace that class/spec
entry point.

The most recently modified MaxDPS SavedVariables file on disk is dated
September 27, 2026. It contains `forceSingle=true`, `customGlow=true`,
`sizeMult=1.6`, custom highlight/cooldown colors, and an empty custom-rotation
list. Unset fields inherit defaults, including the 0.15-second polling interval
and pixel custom-glow style. Another, older saved account file has no comparable
overrides. Saved disk settings are not proof of what the currently running WoW
session has loaded or changed since its last save.

## Feature comparison

| Area | Installed MaxDPS Classic | Current HardcoreBuddy helper |
| --- | --- | --- |
| Purpose | Class/spec damage priorities, with module-dependent utility | Solo Hardcore Mage leveling and conservative group support |
| Combat classes | Policies across all nine, with coverage/dispatch gaps below | Mage only |
| Other classes | Their installed class module | Shared food, drink and cataloged consumable preparation only |
| Selection | First usable matching condition in an ordered list | Ordered Main rules plus separate utility/preparation groups |
| Normal update rate | 0.15 seconds; configurable | 0.10 seconds plus event-triggered updates |
| Cast stability | Recomputes and replaces the choice mid-cast | Commits Main at cast start and retains it through completion |
| Resource prediction | Helpers exist, but Classic Mage reads current mana | Reserves current cast cost and forecasts casting regeneration |
| Spec selection | Mostly the talent tree with most points | Uses specific learned damage talents to choose Fire/Frost behavior |
| AoE | Nameplate/threat/range estimate and explicit AoE lists | No general Mage AoE rotation; defensive Nova only |
| Survival | Depends on the class policy; no Classic Mage defensive list | Counterspell, Nova, Barrier, Mana Shield, Ice Block, Cold Snap, decurse |
| Buff consumables | Shared list contains later-expansion combat potions | 64 cataloged Classic food/elixir/scroll items and buff conflicts |
| Rank matching | Known-by-name and name-based glow fallback can light multiple ranks | Selects a learned rank and matches exact spell/item IDs |
| Action bars | Many dedicated integrations plus LibActionButton enumeration | Blizzard, Bartender, Dominos and selected ElvUI button discovery |
| Appearance | Configurable textures, sizes, colors, pixel/autocast effects | Four colored copies of Blizzard's proc animation with brightness boost |
| Additional display | Optional movable next-spell icon with keybind text | Action-bar glows and explanatory helper page |
| Custom rotation | In-game Lua editor, save/delete/enable by class/spec | No rotation-code editor; custom talent builds are a separate system |
| External display API | WeakAuras events for spell, cooldown, target count and TTD | No equivalent published event interface |
| Logging | Transient spell history, optional spell/aura profiler and debug output | No persistent rotation trace logging |
| Automatic casting | No automatic execution in the audited built-in paths | No automatic execution |

Relevant implementation: [MaxDPS Core](../../MaxDps/Core.lua),
[Helper](../../MaxDps/Helper.lua), [Buttons](../../MaxDps/Buttons.lua),
[Options](../../MaxDps/Options.lua), and HardcoreBuddy's
[Engine](../RotationHelper/Engine.lua), [Runtime](../RotationHelper/Runtime.lua),
[Mage](../RotationHelper/Mage.lua), [Glow](../RotationHelper/Glow.lua).

## What the installed Mage module actually recommends

Each list below is priority order. Later entries win only when earlier entries
do not qualify. These describe source behavior, not recommended play advice.
`CheckSpellUsable` has the Classic-specific limitations discussed below.

### Frost

With zero or one counted target: **Frostbolt**. That is the entire single-target
list. There is no finisher, mana-conservation wand, interruption, shield, root,
mana gem, armor or Intellect rule in the Classic Frost file.

With more than one counted target:

1. Flamestrike when its queried effect is active **or** refreshable.
2. Cone of Cold when the target's estimated minimum range is under ten yards.
3. Arcane Explosion under the same range condition.

There is no Blizzard rule and no single-target fallback from that AoE branch.
An ordinary Frostbolt-only encounter can therefore feel stable simply because
there is only one spell to choose from.

### Fire

With zero or one counted target:

1. Combustion if ready.
2. Scorch if the queried Improved Scorch effect has fewer than five stacks or
   its direct debuff entry is refreshable.
3. Pyroblast when the queried Ignite effect is absent.
4. Fire Blast if ready.
5. Fireball.

With more than one counted target: Flamestrike, then close-range Arcane
Explosion. Blast Wave is commented out. There is no single-target fallback.

The Scorch check does not require the Improved Scorch talent. It uses spell
12873, the talent, instead of 22959, the applied Fire Vulnerability debuff.
The aura-name lookup consequently looks for "Improved Scorch" rather than
"Fire Vulnerability"; the separate direct debuff lookup has the wrong key too.
The isolated tests reproduce continued Scorch advice with five healthy actual
Fire Vulnerability stacks, and also with no Improved Scorch talent at all.

Spell identities were cross-checked against the Classic tooltip data for
[Improved Scorch](https://nether.wowhead.com/classic/tooltip/spell/12873) and
[Fire Vulnerability](https://nether.wowhead.com/classic/tooltip/spell/22959).

### Arcane

With zero or one counted target:

1. Evocation at 35% mana or less.
2. Arcane Power if ready.
3. Presence of Mind if ready.
4. Fire Blast if its specific Improved Arcane Missiles talent key is present.
5. Arcane Missiles under that same talent condition.
6. Frostbolt when that talent key is absent.

With more than one counted target: Evocation, Arcane Power, Presence of Mind,
Flamestrike, Cone of Cold if the talent key is absent and the target is close,
then close-range Arcane Explosion.

The talent key is 16770, the highest Improved Arcane Missiles rank. The Classic
talent collector records tooltip spell IDs rather than normalizing a talent
family, so partial-rank behavior depends on which ID the client returns. There
is no general "any points invested" check here. Health is read into a local
variable, but it does not gate Evocation. Arcane Power/Presence of Mind are the
main recommended action rather than separate optional highlights.

Sources: [Frost](../../MaxDps_Mage/Specialization/Classic/Frost.lua),
[Fire](../../MaxDps_Mage/Specialization/Classic/Fire.lua),
[Arcane](../../MaxDps_Mage/Specialization/Classic/Arcane.lua).

## Prediction, cooldowns, and late changes

`Core.lua:InvokeNextSpell` prepares state, refreshes ancillary data, calls the
class function, compares the result with the old choice, and replaces the glow
if it differs. Its timer normally runs every 0.15 seconds. Target changes can
also invoke it. There is no Main commitment tied to a cast identity, and its
cast-success history is not a cast-start decision lock.

`Helper.lua:EndCast` calculates the larger of remaining cast/channel time and
remaining global cooldown. The result is exposed as `FrameData.timeShift`.
However, `CooldownConsolidated(spellId, timeShift)` does not use that argument
in its calculation. It instead marks a spell ready when either:

- Its remaining cooldown is no greater than the reported **full GCD duration**
  while a GCD duration is reported, or
- Its cooldown has at most half a second remaining.

Consequences reproduced in the source checks:

- A spell with two seconds left is not ready at the start of a three-second
  cast, even though it will be ready before that cast ends.
- With 0.1 seconds left on a 1.5-second GCD, a spell with 1.3 seconds left can
  already be marked ready.
- A Fire recommendation changed from Scorch to Combustion during the same cast
  when Combustion crossed the half-second boundary.

The three Classic Mage files assign `timeShift`, time-to-die, haste, crit and
several health/resource variables, but most are not used in their actual
priority conditions. Reading a statistic does not mean it influences the choice.

HardcoreBuddy evaluates Main using post-current-cast mana and aura expiration
time, chooses the next action when the cast starts, and keeps it until a new
cast/action, matching cancellation, or target change allows a new plan.
Defensive advice remains live. Its two-second resource look-ahead is limited
forecasting, not a simulation of damage, incoming mobs or the next several casts.

The tradeoff: MaxDPS is more reactive to a changing snapshot but can surprise
the player late. HardcoreBuddy is more predictable but can retain a decision
after circumstances improve. Neither policy is universally best for every proc
or emergency; HardcoreBuddy separates immediate defensive choices for that reason.

## Readiness, range, talents, and rank differences

**Classic readiness is notably weak in this MaxDPS build.** The shared
`CheckSpellUsable` rejects passive spells and scans the spellbook for a matching
name. Unlike its Retail/Cata/Mists paths, its Classic path does not consult the
usable/mana result or check the spell's actual power cost. The Classic Mage
single-target lists also lack per-spell range checks. The tests still returned
Frostbolt with zero mana, an unusable API result, an 80-yard synthetic target,
and critical player health. These are four separate controlled checks.

`CooldownConsolidated` reads `isEnabled` but does not use it to block readiness
when zero timings are returned. This is a source finding; no claim is made
about how often that particular API combination occurs in live Classic.

MaxDPS chooses the Mage tree using the greatest number of spent talent points.
Ties retain the first tree found; with no points, its library returns zero and
Mage has no zero-spec fallback. Some other classes have a fallback. This matters
for levels before the first talent point and mixed builds. HardcoreBuddy works
from learned spells at level one and compares selected damage talents; it is
still a heuristic rather than mathematical spell scoring.

MaxDPS's hardcoded high-rank spell IDs do not, by themselves, mean low levels
are unsupported. Its Classic known-spell check and highlight fallback compare
names. The test with only rank-one Frostbolt still selected the Frostbolt
family, and its glow routine lit both ranks when two rank buttons were present.
That flexibility also means it does not select a single intentional rank.
HardcoreBuddy resolves learned damage ranks explicitly and intentionally allows
the lowest learned Nova rank present on a bar for control.

Neither inspected Classic Mage implementation has a movement gate.
HardcoreBuddy also has no mounted gate. MaxDPS's mounted check in `GlowSpell`
suppresses the missing-action chat warning, not the rotation itself.

## AoE, auras and shared data

MaxDPS tracks nameplate unit tokens, filters them through threat participation,
uses LibRangeCheck, and counts estimated ranges up to 30 yards for ranged
characters or 15 for melee. If none qualify but a living hostile target exists,
it falls back to one. Force-single and forced-target-count settings override
this. This is an estimate from exposed units, not knowledge of every rendered
enemy or exact geometry around a ground-target spell.

Its aura collector supports full and incremental `UNIT_AURA` updates. It keeps
player helpful auras, the player's target debuffs, player-applied dots on
observed units, and dispellable target buffs. Remaining duration is calculated
on access; ordinary refreshability is below 30% of duration.

`FindADAuraData` searches all tracked dot GUIDs by spell name, rather than
restricting itself to the current target. Thus some class rules using it can
be satisfied by a dot on a different observed enemy. If multiple matches exist,
the final matching table iteration supplies the returned data; it is not a
deliberate current-target or minimum-duration selection.

The Mage Flamestrike condition is `up or refreshable`: a present aura qualifies
because it is up, and an absent aura normally qualifies because it is
refreshable. It therefore keeps Flamestrike ahead of the later AoE entries
whenever Flamestrike passes the other gates. A separate test showed that the
two-target branch can return nothing with only ranged Frostbolt and an
out-of-range Arcane Explosion available.

MaxDPS also supplies a time-to-die estimate from up to 50 target-health samples
taken every 0.25 seconds, using a linear fit capped at five minutes. The Classic
Mage rules do not use that estimate, while several other class rules do.
Swing tracking is present for other modules. Neither constitutes DPS simulation.

HardcoreBuddy scans player/target auras and observed nameplates for pressure
and breakable crowd control. It does not yet have a Mage AoE damage policy or
a time-to-die fit. Its Nova safety check suppresses advice when observed nearby
crowd control is present; neither addon can certify a safe AoE pull from unseen
units or terrain.

## Consumables and utility

MaxDPS maps action-bar item IDs to their use-spell IDs so items can be highlighted.
Its shared `Consumables` list in this build contains BFA and later-expansion
potions. `GlowConsumables` asks for their cooldown glow when ready. There is no
Classic Mage comparison of Elixir of Wisdom/Greater Intellect versus Arcane
Intellect, no five-minute Classic food/elixir refresh policy, and no ordinary
food/water recovery advice in its Classic Mage files.

HardcoreBuddy's shared catalog handles 64 routine Classic items, class and
use-level filtering, stronger active buffs, free-spell ties, five-minute refresh,
and food/drink recovery. Buff meals work at full health as well. Direct items
and item macros can glow. Mana gems are separately handled by Mage policy.

Coverage must be stated accurately: consumable preparation runs on all nine
classes, but competing castable class buffs in the shared catalog currently
cover Mage Intellect and Priest Fortitude/Divine Spirit. It is not yet a complete
set of every class's self buffs, blessings, totems, world buffs or special items.
Compound consumables such as Sages/Mongoose/Brute Force are recognized as active
effects, but that does not mean all are offered as carried-item candidates.
Food preference is a class policy, not an optimization across all possible
stat combinations.

HardcoreBuddy's Mage utility uses health, mana, attackers, enemy casts, curses,
cooldowns, target engagement and observed control. Burst advice requires an
engaged durable target and a compatible Main spell. It does not automate Blink
landing locations or Polymorph target choice. The MaxDPS Classic Mage module
has no equivalent survival policy, even though general defensive controls are
visible in its settings. Its large shared `Cooldowns.lua` table returns early
outside Retail, and these Mage files never call the defensive glow helpers.

## Other eight installed class modules

This is the implemented policy coverage, not a promise that each class is
correct or optimized. No complete combat scenario suite was run for these classes.

| Class | What its loaded Classic rules do | Important limits found in the source |
| --- | --- | --- |
| Druid | Balance maintains form/buffs/dots and Starfire; multi-target Moonfire/Hurricane. Feral contains cat builders/finishers and bear attacks, with SoD checks mixed in. | Classic dispatch sends both Feral and Guardian to Feral. Restoration is selected by Main but no Restoration file is loaded. |
| Hunter | Aspect, Hunter's Mark, Rapid Fire/Bestial Wrath, Multi-Shot, Serpent Sting, Aimed Shot; Volley/trap AoE entries. | Reads Focus-style values despite Classic Hunter mana, and has no low-mana policy. Pet health is read but does not trigger Mend Pet in these lists. Several SoD identifiers are present. |
| Paladin | Retribution maintains seals, uses Hammer of Wrath, Judgement and conditional other attacks. | Protection is selected by Main but absent from the TOC. Holy points at a generic modern helper file rather than the Classic Holy file on disk; it is not a complete Classic Holy priority list. Retribution mixes SoD/modern identifiers and conditions. |
| Priest | Discipline/Holy: Shadow Word: Pain, Inner Focus, Smite. Shadow adds Shadowform, Mind Blast, Mind Flay. | These are damage lists, not group-healing engines. Some dot tests use the all-target aura helper. |
| Rogue | Sinister Strike/Backstab or Hemorrhage/Ghostly Strike; Slice and Dice and Eviscerate; Subtlety Ambush. | Assassination's Sinister Strike expression can pass at five combo points when Dagger Specialization is absent. Slice and Dice refresh expressions can pass without their five-point clause. Shared Classic usability does not supply an energy/positional safeguard. |
| Shaman | Elemental: totems, Chain Lightning, Lightning Bolt and conditional Earth Shock. Enhancement: totems, Stormstrike, Earth Shock. | Main selects Restoration, but no Restoration file is loaded. No full healing/survival engine. |
| Warlock | One DPS policy across specs: armor/pre-pull talents, DoTs, Shadow Bolt, short-TTD finishers and Life Tap. | Life Tap checks mana below 10% without checking player health. No comprehensive pet/survival plan. |
| Warrior | DPS and Protection priorities, shouts, Execute, builders/spenders, independent cooldown suggestions. | Protection routing checks existing FrameData talents rather than simply the current spec; startup state matters. DPS includes Cleave with `targets <= 2`, so it can qualify on one target. Swing data exists, but that alone does not validate Slam timing. |

Files under each addon's `Main.lua` and the TOC-listed specialization paths are
the evidence. Merely having a Restoration/Protection file elsewhere on disk
does not load it or repair the dispatch gaps.

## Highlights, macros, settings and coexistence

MaxDPS discovers many bar implementations explicitly and also enumerates
LibActionButton variants. It supports stance/pet bars and item-to-use-spell
mapping. The standard macro path uses `GetMacroSpell` and action-slot fallback.
It has no core modifier-key event registration; the cached mapping is rebuilt
on bar/macro/form events. Some bar libraries may supply additional refreshes,
so this is a compatibility risk for changing macro branches, not a universal
claim that modifier macros fail. A macro-body parsing experiment exists in the
file but is not called by the live button-discovery path.

HardcoreBuddy resolves each visible button's current action while applying
glows, handles spell/item macro results, and listens to modifier changes.
Its exact-ID matching avoids illuminating every rank, at the cost of requiring
the recommended rank or a macro resolving to it. It warns once per missing
recommended spell per session; MaxDPS also reports missing bar spells, but does
not have the same once-per-spell warning map.

MaxDPS defaults to a white next-action overlay and green independent cooldown
overlays; configurable custom effects include pixel and autocast glows. It can
optionally suppress native Blizzard/LibActionButton activation-glow events.
HardcoreBuddy uses owned copies of Blizzard's looping proc animation, with gold
Main, red Defensive, violet Offensive and blue Preparation. Multiple compatible
utility groups can remain lit, with one Main. It does not clear another addon's
owned glows.

Both addons can draw on the same button. They do not negotiate which recommendation
wins. That can produce overlapping colors or simultaneously contradictory spell
advice; an unexplained glow while both are enabled cannot be attributed to HCB
without isolating the source. For comparison runs, enable one rotation display
at a time. No settings were changed during this audit.

MaxDPS also offers a movable spell icon with keybind text, configurable update
rate, forced target count, cooldown-only mode, message verbosity, debug tooltip
IDs, and a Lua rotation editor. Extra standalone consumable/defensive/trinket
frame creation is Retail-gated in this build. Its optional profiler records
unique spell/aura identities to generate Lua lists; it is not a full decision
trace explaining why every recommendation changed. Its ordinary transient
spell history retains five spells plus last-use timestamps.

Settings and custom rotation text are saved in `MaxDpsOptions`. I found no
network/telemetry sender in the inspected recommendation path. The URLs in its
window are displayable support/donation links. Built-in Classic behavior
highlights actions; it does not choose and execute a protected cast for a user.

## What to take from this comparison

Useful MaxDPS ideas for HCB are broader action-bar adapters, a cached button
index with reliable invalidation, an optional standalone next-spell display,
well-defined public recommendation events, and a deliberately tested target/TTD
model if group/AoE support becomes a goal. These are proposals, not changes made
by this audit.

HCB should retain its clear category meaning, early cast commitment, learned
rank selection, explicit safety rules and consumable conflict handling. Copying
this installed MaxDPS Mage priority list would remove much of that behavior and
would import the reproduced Scorch/cooldown/AoE problems.

HCB's remaining limits also deserve attention before calling its rotation
"best": it does not calculate expected damage per spell from gear/talents,
simulate projectile damage or target death, model a full Arcane specialization,
optimize AoE, or cover all class self buffs. Its strict range gate can suppress
advice when the API returns unknown, and Nova uses an interaction-distance
proxy rather than a precise area-target geometry test. Its repeated snapshot
reads and button resolution have not been CPU-benchmarked in a busy live raid.

Both addons use hand-authored priorities. MaxDPS's name and larger framework
do not establish superior recommendations for this particular Classic Hardcore
Mage use case; HCB's extra conditions do not establish optimal DPS either.
Actual client testing remains necessary for queued casts, latency, bar addons,
proc visibility and overlapping highlight ownership.
