# Shared consumable and class-buff preparation

Verified October 2, 2026. Blue action-bar markers now include the 64 routine
elixirs, scrolls and buff foods in the existing supplies catalogs. Preparation
works on all nine Classic classes; combat rotation advice remains Mage-only.
Each character enables the assistant in Companion > Rotation Helper.

## Choosing a buff

- Compare the actual stat amount, not item level or the catalog's ranking score.
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
consumable armor, flat health and Troll's Blood regeneration. Food chooses one
meal using the existing class preference: mana food for Mage/Priest/Warlock,
stat food for other classes. It compares ranks within that preference. Unknown
special food effects and the extra crit on active Mongoose are preserved.
Sages and Brute Force are recognized as active compound stat buffs.

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
read is retried. Successful use briefly suppresses repeat prompts while aura and
bag events catch up. UNIT_AURA clears satisfied markers immediately.

Direct item buttons and item macros use the existing native proc-style glow.
No new frame or bar geometry is added. Food buff checks also run at full health
and mana, but preparation never interrupts eating, drinking or combat casts.

## Offline verification

58 focused cases pass, plus 540 class/level combinations without duplicate
conflicting groups. Tests cover stronger items versus spells in both directions,
five-minute refreshes, received class buffs, class/use-level filtering, compound
buff recognition, inventory changes and actual direct-item/macro glow application.

The existing 200-case, 64-choice, 41-handoff, 22-prediction, 75-audit and 115-check
suites also pass; the audit matrix retains zero violations across 3,888 inputs.
Fixtures using the wrong Intellect IDs were corrected, and non-Mage lifecycle
expectations now explicitly require preparation without a combat rotation.

Live WoW verification is still needed for client aura values and rendered glows.
