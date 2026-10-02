# Supplies: Enchants

Enchants follows Scrolls. It contains equipped-slot recommendations, armor kits,
and an exact-item material shopping list. Open a slot to browse alternatives,
then open an alternative to inspect its effect, requirements and bag counts.
Browsing alternatives is temporary; old saved enchant choices are ignored.
Missing slots always display the automatic recommendation. Applied alternatives
display their actual enhancement rather than replacing the recommendation.

Rows display `Slot - Enchant`, the effect as the subtitle, and status at the
upper right. Missing enchants show Not Enchanted with red borders; the recommended
enchant applied shows Enchanted and another applied enhancement shows Alternative,
both green on the overview.
Hover shows the enchant effect rather than its crafting recipe. Details place
the recommendation and alternatives on the left and tracked reagents on the right.
Armor kits participate in these same comparisons for chest, gloves, legs and boots,
respecting the kit's required use level and the target item's level.
They can be the recommendation (including legs and caster gloves) or an alternative.
Kit details show Leatherworking requirements and their crafting materials.

The bundled catalog contains 132 Classic Era Enchanting profession recipes and
58 consumed material types, plus the existing six armor kits. It excludes Season
of Discovery recipes. Quest/reputation head, leg and shoulder augments and
Engineering scopes are not part of the Enchanting profession catalog.

Source: [Wowhead Classic Enchanting spells](https://www.wowhead.com/classic/spells/professions/enchanting?filter=16;1;0).
Each spell's tooltip, enchant effect ID, required skill, reusable rod and consumed
materials were checked against its individual Classic spell page. The normalized
facts are checked in at `reference/research/enchants.json`. `research_enchants.py`
preserves downloaded pages and stops on access errors; `build_enchants.py` builds
the runtime catalog from that cache. Neither script runs inside the addon.

## Leveling policy

Gear Advisor settings > Enchants offers two per-character recommendation modes:

- **Show Level Appropriate Enchants** (default): use leveling budget tiers.
  Enchanting skill caps are 50 for levels 1-9, 100 for 10-19, 150 for 20-29,
  200 for 30-39, 250 for 40-49, 290 for 50-59, and 300 at level 60.
- **Show Max Enchants**: consider all applicable ranks regardless of those
  budget tiers, including high-skill enchants on low-level equipment.

The mode updates slot recommendations, alternatives and required materials.
These are recommendation tiers, not wearer restrictions. Enchanting skill is
required of the enchanter; actual gear restrictions still apply in both modes.
Armor kits retain their required use level and minimum item level. Applied
higher-rank enchants remain recognized when using level-appropriate mode.

The slot menu initially shows the highest applicable rank of each effect.
Show Lesser Ranks, opposite Back, expands the list to include lower compatible
enchants and armor kits. The applied enchant remains available for comparison.
Recommendations are class-based preparation suggestions, not simulated damage
gains or live auction price estimates.

Defaults favor stamina/health, useful primary stats, and movement speed on boots.
Mana enchants are excluded for classes without mana. Spell/healing enchants are
restricted to relevant classes; melee damage enchants are not Hunter defaults.
Threat-increasing enchants are limited to tank-capable classes (Warrior,
Paladin, Druid and Shaman). Melee-hit proc/damage enchants are limited to
Warrior, Rogue, Paladin and Shaman; Hunters and pure casters do not receive
strength enchants. Stealth enchants are shown for Rogues and Druids.
Mining, Herbalism, Skinning and Fishing bonuses require that profession to be
learned. Unknown profession data and character previews hide these bonuses.
This does not require Enchanting to receive ordinary enchants from an enchanter.
Both recommendation modes and the lesser-ranks list use these filters.
There is no dependency on another addon's scoring or data at runtime.

## Gear and material checks

Checks use the actual equipped item link, equipment location, item level and
permanent enchant ID. Item data that has not loaded remains unknown. Shield
enchants require a shield; two-handed recipes require a two-handed melee weapon.
Held-in-offhand items and wands are excluded. Cloth/leather/mail/plate weight
does not change an otherwise valid armor enchant. Preview mode never reads or
plans materials for the live character's equipment.

An existing identical enchant needs no materials. Lower ranks of the same
recommended stat can trigger an upgrade; unrelated enchants/armor kits are kept.
Browsing a replacement displays its reagents without changing the automatic
shopping list. The addon never casts an enchant or confirms an overwrite.
Recommended armor kits track the finished kit; crafting materials are shown
in the detail's material column.

Materials are summed across all verified slots needing enchants so shared bag
stock is not counted twice. Armor kits are excluded for those same pieces to
avoid planning two permanent enhancements on one item. Tools are listed separately
and are not consumed. Recipe possession and the player's Enchanting skill are
not assumed; Self Found players must learn and apply their own recipes.

Offline checks: `tests/run_enchants.py` and `tests/run_armor_kits.py`. Live WoW
tooltips, inventory events and rendering still require an in-game check.
