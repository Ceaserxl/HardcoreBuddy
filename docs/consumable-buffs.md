# Shared consumable and class-buff preparation

Rotation Helper and all preparation highlights are disabled in v0.7.2. The shared
consumable metadata remains active for Supplies scoring. The description below
documents the archived highlighting implementation and its offline tests.

Verified October 2, 2026. Blue action-bar markers included routine
elixirs, scrolls and buff foods in the supplies catalogs. Preparation
works on all nine Classic classes; combat rotation advice remains Mage-only.
Each character enables the assistant in Companion > Rotation Helper.

## Choosing a buff

- Compare actual effects with the same active build weights as Supplies. Do not use item level as a proxy for buff strength.
- Choose one carried/learned source per conflicting buff group. Prefer the free
  class spell on an equal amount. Do not recommend an item above its use level
  or outside the supplies catalog's class filter.
- A stronger available source can upgrade a weaker active buff immediately.
  An equal active buff is refreshed at five minutes remaining. A stronger active
  buff blocks weaker replacements even when it is almost expired.
- A cooling-down best item waits; it does not make the helper spend a weaker
  consumable. Normal spell mana, item cooldown and preparation gates still apply.
- Recognize received Arcane Intellect/Brilliance, Power Word/Prayer of Fortitude,
  and Divine/Prayer of Spirit on every class. Mage Intellect and learned Priest
  Fortitude/Divine Spirit are available as free self-cast alternatives.
- Flat health elixirs and Stamina buffs remain separate. Class armor buffs remain
  separate from consumable armor. This is Classic Era; there is no blanket
  Battle/Guardian-elixir exclusivity rule.

The scalar conflict groups are Intellect, Stamina, Spirit, Strength, Agility,
consumable armor, flat health, spell damage, Fire damage and Troll's Blood regeneration.
Food compares Stamina + Spirit against MP5 using the active build weights. Compound
Mongoose compares both Agility and crit. Equal effects prefer a free learned spell.
Unknown special food effects are preserved. Sages and Brute Force are recognized
as active compound stat buffs. See [catalog scope](supply-catalog.md).

This is a preparation policy over the shipped supply catalog, not an exhaustive
model of every Classic temporary/world buff or a combined-stat DPS simulator.
It neither casts nor buys anything.

## Corrected identities

The previous Mage-only table mislabeled two spells and omitted the real elixir
auras. The regression fixtures had repeated those incorrect IDs.

| Effect | Correct aura | Amount |
| --- | --- | --- |
| Elixir of Wisdom | 3166 | 6 Intellect |
| Elixir of Greater Intellect | 11396 | 25 Intellect |
| Elixir of Lesser Agility | 3160 | 8 Agility |
| Arcane Elixir | 11390 | 20 spell damage, not Intellect |
| Elixir of the Sages | 17535 | 18 Intellect and Spirit |

The item-to-effect links and numerical amounts were checked against Wowhead's
Classic client-data tooltips, including
[Wisdom](https://nether.wowhead.com/classic/tooltip/item/3383),
[Greater Intellect](https://nether.wowhead.com/classic/tooltip/item/9179),
[Lesser Agility](https://nether.wowhead.com/classic/tooltip/spell/3160),
[Arcane Elixir](https://nether.wowhead.com/classic/tooltip/spell/11390), and
[Sages](https://nether.wowhead.com/classic/tooltip/spell/17535).
Every non-food item in Data/ConsumableBuffs.lua was checked through its Classic
item tooltip and linked spell tooltip. Food records distinguish the eating
spell from the resulting persistent buff, including
[Sagefish Well Fed](https://nether.wowhead.com/classic/tooltip/spell/25941),
[Nightfin regeneration](https://nether.wowhead.com/classic/tooltip/spell/18194),
and [12 Stamina/Spirit Well Fed](https://nether.wowhead.com/classic/tooltip/spell/19710).

## Lifecycle and markers

Only carried bag items qualify; bank stock is excluded. The bag cache refreshes
after bag changes and when class/use level changes. An unavailable inventory
read is retried. Successful buff application briefly suppresses repeat prompts
while aura and bag events catch up. Starting a meal does not suppress its still
needed food-buff marker. UNIT_AURA clears satisfied markers immediately.

Direct item buttons and item macros use the existing native proc-style glow.
No new frame or bar geometry is added. Food buff checks also run at full health
and mana. Needed food, water, scroll and elixir markers stay visible through
eating, drinking and matching global cooldowns. Real item cooldowns, disabled
items, combat and active-cast preparation gates still apply. Spell preparation
continues to wait while eating or drinking.

## Offline verification

88 focused cases pass, plus 540 class/level combinations without duplicate
conflicting groups. Tests cover stronger items versus spells in both directions,
five-minute refreshes, received class buffs, class/use-level filtering, compound
buff recognition, inventory changes and actual direct-item/macro glow application.
They also cover eating/drinking and GCD persistence on all nine classes, both
item-cooldown API paths, true cooldown rejection, and uninterrupted glow loops.

The existing 200-case, 64-choice, 41-handoff, 22-prediction, 75-audit and 115-check
suites also pass; the audit matrix retains zero violations across 3,888 inputs.
Fixtures using the wrong Intellect IDs were corrected, and non-Mage lifecycle
expectations now explicitly require preparation without a combat rotation.

Live WoW verification is still needed for client aura values and rendered glows.
