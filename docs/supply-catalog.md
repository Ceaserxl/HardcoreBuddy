# Supply catalog scope and reviewed additions

Reviewed 2026-10-02 for Classic Era / official Hardcore, levels 1–60.
This is a curated preparation guide, not a complete database of every Classic item.
`Data/SupplyExtensions.lua` keeps each added item, use level, effect, recipe,
crafting skill, output and consumed reagents together. Existing vendor-food,
profession, scroll, ammo and enchant catalogs remain authoritative for their entries.

## Inclusion manifest

All ranks listed below are available through the shared supply detail, comparison
and material paths. New families default to Optional. Ordinary food remains
available across classes; mana-only food/drink still requires a mana class.

| Family | Included item IDs | Policy |
| --- | --- | --- |
| Agility | 2457, 3390, 8949, 9187, **13452** | Mongoose extends the existing family; score both 25 Agility and 2% crit |
| General spell damage | **9155, 13454** | Caster-capable classes; damage weight, without adding a healing bonus |
| Fire damage | **6373, 21546** | Mage/Warlock; selected build's Fire damage weight |
| Poison removal | **3386** | Optional encounter preparation; level 14, Alchemy 120, up to four poisons |
| Holy absorption | **6051** | Optional; the available Classic rank |
| Shadow absorption | **6048, 13459** | Optional; compare within the same damage school |
| Fire absorption | **6049, 13457** | Optional; compare within the same damage school |
| Frost absorption | **6050, 13456** | Optional; compare within the same damage school |
| Nature absorption | **6052, 13458** | Optional; compare within the same damage school |
| Arcane absorption | **13461** | Optional; the available Classic rank |
| Blinding Powder | 5530 | Added Fadeleaf reagent and one-item output; Rogue Poisons 150 / character level 34 |

Each added Alchemy recipe produces one item; materials on supply details are for
one craft. Protection potions have a shared potion cooldown and absorb a finite
amount, so they do not generate routine persistent-buff refresh highlights.
Their duration is a maximum, not a guarantee that the shield survives that long.

The default food policy chooses comparable ordinary candidates by the active
build's stat weights. Explicit defaults and priorities take precedence. Preparation
highlights compare the sources actually carried or learned; they can therefore
use a carried optional food even when the planning page prefers a routine source.
Food compares Stamina + Spirit against MP5 using those weights. Troll's Blood
uses health regeneration. Mongoose includes its crit effect when comparing an
active or carried source; it must not be replaced by a plain Agility elixir.

## Deliberate exclusions and non-recommendation data

| Scope | Decision |
| --- | --- |
| Seasonal/event and reputation-only food/drink | Excluded from routine Supplies, as requested. Recognition data can remain for owned buffs. |
| Quest/reputation head, leg and shoulder augments | Outside the current profession/armor-kit/scope recommendation catalog. No fabricated gear or acquisition eligibility. |
| Encounter-specific raid/world buffs, flasks and compound effects beyond the listed families | Not represented as a complete preparation optimizer. Existing supported emergency items remain. Sages/Brute Force auras are recognized to avoid replacing active effects; they are not new routine supply recommendations. |
| Procs, movement, threat and profession utility enchants | Class/role/profession filtered alternatives, with no invented numeric score. Next cannot call an incomparable effect a strict upgrade. |
| Light of Elune | Unique quest/macro workflow, bags-only quantity; no refill, generic Next or Alternatives. |
| Custom User items | Explicit personal tracking; no generated progression. A duplicate built-in item shares stock, quantities and its User priority override. |
| NPC research fallbacks | Preserved separately. This catalog pass does not replace unresolved research evidence. |

## Sources

Classic spell pages provide use effects, reagent identities and quantities;
recipe items provide profession requirements. These are developer references,
never fetched by the addon at runtime.

- [Mongoose recipe](https://www.wowhead.com/classic/item=13491/recipe-elixir-of-the-mongoose) and [craft](https://www.wowhead.com/classic/spell=17571/elixir-of-the-mongoose).
- [Arcane Elixir](https://www.wowhead.com/classic/spell=11461/arcane-elixir), [Greater Arcane Elixir](https://www.wowhead.com/classic/spell=17573/greater-arcane-elixir) and [recipe](https://www.wowhead.com/classic/item=13493/recipe-greater-arcane-elixir).
- [Firepower](https://www.wowhead.com/classic/spell=7845/elixir-of-firepower), [Greater Firepower](https://www.wowhead.com/classic/spell=26277/elixir-of-greater-firepower) and [recipe](https://www.wowhead.com/classic/item=21547/recipe-elixir-of-greater-firepower).
- [Poison Resistance](https://www.wowhead.com/classic/spell=3174/elixir-of-poison-resistance) and [recipe](https://www.wowhead.com/classic/item=3394/recipe-elixir-of-poison-resistance).
- Protection crafts: [Holy](https://www.wowhead.com/classic/spell=7255/holy-protection-potion), [Shadow](https://www.wowhead.com/classic/spell=7256/shadow-protection-potion), [Fire](https://www.wowhead.com/classic/spell=7257/fire-protection-potion), [Frost](https://www.wowhead.com/classic/spell=7258/frost-protection-potion), [Nature](https://www.wowhead.com/classic/spell=7259/nature-protection-potion).
- Greater protection crafts: [Fire](https://www.wowhead.com/classic/spell=17574/greater-fire-protection-potion), [Frost](https://www.wowhead.com/classic/spell=17575/greater-frost-protection-potion), [Nature](https://www.wowhead.com/classic/spell=17576/greater-nature-protection-potion), [Arcane](https://www.wowhead.com/classic/spell=17577/greater-arcane-protection-potion), [Shadow](https://www.wowhead.com/classic/spell=17578/greater-shadow-protection-potion).
- [Blinding Powder](https://www.wowhead.com/classic/spell=6510/blinding-powder).
