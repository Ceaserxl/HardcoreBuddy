# Classic Era Mage rotation research audit

Reviewed 2026-10-02 against the current helper. Scope: original Classic Era
1–60 PvE and Hardcore; expansion, Retail and Season of Discovery rotations are
excluded. Guide strategies inform priorities but do not prove numerical optimality.

## Findings and implementation

| Topic | Research finding | Current helper / action |
| --- | --- | --- |
| Leveling fillers | Newly learned Fireball/Frostbolt ranks matter early; later Frost talents change the balance. | Keep learned-rank and actual-talent comparisons instead of a fixed spell for every level. |
| Fire Blast | Movement and finishing are useful contexts; single-target sustained casting is built around the main filler. | Removed the raw damage-per-GCD rule that could repeatedly displace the filler. Retain movement, finishing, expiring-freeze and unavailable-filler uses. |
| Defensive Nova | Rank 1 preserves the root while saving mana. | Select learned Rank 1 for the existing defensive Nova priority. Higher ranks are not needed for that control action. |
| Scorch | Its vulnerability benefits longer Fire fights more than short leveling kills. | Existing longer-fight stack/refresh gating is appropriate; the exact ten-second cutoff is an addon heuristic. |
| Arcane leveling | Arcane investment does not require exclusive Arcane Missiles use. Fireball and Frostbolt remain relevant. | Keep cross-school comparisons; evaluate actual talents rather than assuming every Arcane build has the guide's level-47 allocation. |
| Mana and safety | Wand finishing, preparation and restrained Mana Shield use reduce downtime and risk. | Shields/buffs and emergency Mana Shield are present. Wand use is currently only a fallback: wand-damage/regen-aware finishing and mana-gem planning remain gaps. |
| AoE | Kiting builds and grouped damage require different positioning and talent assumptions. Channels should not be clipped casually. | Keep observed-cluster, control and channel safeguards. The helper cannot verify unseen enemies or manually placed ground spells. |

The current Pyroblast opener is still chosen by the general scoring model; it is
not a dedicated Fire pull sequence. Numeric health/mana thresholds, cooldown
timing and the cast-handoff lock are implementation choices, not quotations from
guides. The research does not establish that the entire helper is optimal.

## Sources checked

- [Wowhead: Frost leveling](https://www.wowhead.com/classic/guide/classes/mage/frost/leveling-tips): rank progression, main fillers and Frost talent interaction.
- [Wowhead: Hardcore Mage](https://www.wowhead.com/classic/guide/classes/mage/hardcore-leveling-tips): control ranks, Fire/Frost play patterns, wand finishing, mana preparation and emergency protection.
- [Icy Veins: Classic Mage PvE rotation](https://www.icy-veins.com/wow-classic/mage-dps-pve-rotation-cooldowns-abilities): finishers, filler priorities, vulnerability upkeep and grouped AoE. Its max-level assumptions must not be applied wholesale to leveling.
- [Wowhead: Arcane leveling](https://www.wowhead.com/classic/guide/classes/mage/arcane/leveling-tips): alternative damage schools, pushback protection and talent-dependent transitions. Its wording about uninterrupted Missiles refers to pushback protection, not immunity to school interrupts or crowd control.
- [Wowhead: AoE leveling](https://www.wowhead.com/classic/guide/mage-aoe-farming-leveling-classic-wow): Improved Blizzard and kiting context.
- [Frost Nova Rank 1](https://www.wowhead.com/classic/spell=122/frost-nova) and [Rank 4](https://www.wowhead.com/classic/spell=10230/frost-nova): Classic tooltip checks show 55 versus 145 base mana, both with up to eight seconds of rooting. Damage can break either root.

Regression coverage checks that a higher instantaneous score alone no longer
promotes Fire Blast, that movement/finisher/fallback uses remain, and that the
Nova rank choice follows actual learned spells. In-game validation remains
separate from these offline checks.
