# Classic Hardcore carry-list research

Reviewed September 26, 2026. Scope: Classic Era levels 1–60, not Retail, TBC,
Season of Discovery, or private-server variants. This is an editorial leveling
carry list, not a complete item database or a live character/market feed.

## Evidence and provenance

`hcclassic-source-records.json` preserves 159 researched records: the original
94 workbook rows plus 65 additional supplies. Of those, 158 have exact matching
Classic item tooltips; the workbook's unavailable Elixir of Water Walking is
retained only as provenance. `recommendations.json` contains 121 curated records
(120 distinct items; Light Feather has separate Mage/Priest spell gates).

Each available record retains its item ID, exact item reference, verification
date, local icon and Classic tooltip effect. Recipe and crafting records retain
materials and separate crafting requirements when available. Acquisition
relations are preserved as text; downloaded JavaScript is never evaluated.
Large drop tables are deliberately capped at 12,000 characters: they are source
samples, not exhaustive drop-rate authorities. Missing relationships do not
establish that an item is unobtainable. A missing spell tooltip is explicitly
recorded and does not replace the verified item tooltip.

The collector's `trainer` field means a trainer relation was observed, not that
its absence proves a world-drop recipe. Starting recipes and incomplete vendor
relations required manual review. The curation script explicitly corrects the
starting Alchemy recipes and Major Healing, Superior Mana, and Major Mana routes.
Cross-expansion comments were excluded when they disagreed with Era records.

## Ranking policy

The five bands are qualitative editorial acquisition effort:

| Band | Meaning |
| --- | --- |
| Vendor | Ordinary finished-item supplies; check the vendor stocks the tier |
| Simple craft | A routine trained recipe or class-created item, with materials/skill still required |
| Recipe / travel | Purchase a recipe, fish/gather ingredients, or travel to its supplier |
| Farm / limited | Random recipes/drops, constrained quest supplies, or less convenient farming |
| Special access | Seasonal, dungeon, reputation or late-game prerequisites |

The planner chooses the strongest usable recovery/elixir rank, then orders the
result by ease within each section. Well Fed and mana food favor repeatable
recipes through the first three bands; harder, stronger alternatives remain
visible in details. Equal-power food ties follow reviewed recipe preference
(e.g. Roast Raptor before recipes with less convenient suppliers). This is not
a claim that every listed item should be stacked, nor that recipes/herbs have a
fixed auction price. Existing skills, faction and ingredients can change effort.

The UI has only global class/level controls and a compact/detailed toggle. It
has no inventory quantities, checkboxes, item selectors, inclusion overrides,
packing progress or downloads. Profession tools show requirements rather than
assuming the character has a skill based on their level.

## Food findings

- Vendor recovery food and drink advance through use-level tiers 1, 5, 15, 25,
  35 and 45. Ordinary recovery food has no Well Fed stat bonus. Cooked fish are
  useful alternatives when already fishing; they are not automatically buff food.
- Easy stamina/spirit progression uses early eggs/wolf meat, clam/crab/meat
  recipes, Goblin Deviled Clams, Roast Raptor, and Spider Sausage. Equal-buff
  alternatives are retained rather than treating every food as another buff.
- Redridge Goulash has an Alliance recipe route; Heavy Crocolisk Stew's recipe
  vendor is Horde-only. Their use levels do not guarantee safe recipe/material
  access. Tender Wolf Steak and Monster Omelet provide later recovery upgrades
  while retaining the same stamina/spirit bonus as Spider Sausage.
- Mana food is an alternative for mana users. Smoked Sagefish uses item 21072,
  not raw fish 21071. Nightfin Soup's exact tooltip specifies **10 minutes**,
  overriding generic guide prose that says 15.
- Grilled Squid is seasonal, Runn Tum Tuber Surprise needs Dire Maul access,
  and Smoked Desert Dumplings require late-game Silithus recipe/material access.
  Dirge's Chimaerok Chops are a rare quest-chain luxury, not a routine supply.
- Class notes distinguish melee, caster/healer, and tank priorities for hybrids.
  Hunter pet feeding depends on diet/level and is separate from player food buffs.
  Mage-conjured recovery supplies can replace the listed vendor baseline.

Sources: [food effects and tiers](https://www.wowhead.com/classic/guide/wow-classic-best-food),
[class/build food guidance](https://www.icy-veins.com/wow-classic/classic-cooking-profession-guide),
[cooking access](https://www.wowhead.com/classic/guide/cooking-leveling-1-300-wow-classic),
[cooking vendor routes](https://www.wowhead.com/classic/guide/cooking-vendor-recipes-wow-classic),
[Nightfin Soup](https://www.wowhead.com/classic/item=13931),
[Grilled Squid recipe](https://www.wowhead.com/classic/item=13942),
[Runn Tum recipe](https://www.wowhead.com/classic/item=18267),
[Desert Recipe](https://www.wowhead.com/classic/quest=8307).
Individual acquisition records support vendor names, ingredients and recipe skills.

## Emergency findings

- Healing, mana and escape potions compete for the potion cooldown. Free Action
  prevents effects; it does not remove existing stuns/slows. Limited
  Invulnerability protects against physical attacks, not all spell damage.
- Bandages use First Aid skill, not character level. Heavy Runecloth requires
  First Aid 225 to **use**; its crafting requirement is higher. The list shows
  all ten use thresholds and healing effects without inventing a character's
  profession skill. Damage interrupts bandaging.
- Anti-venom poison caps are poison levels, not character minimums. Powerful
  Anti-Venom additionally needs First Aid 300 to use and a reputation recipe.
- Target dummies require Engineering 85 / 185 / 275. Their duration ends early
  if killed. Healthstones, mana gems, target dummies and Felwood plants share
  cooldown interactions; they are not independent consecutive saves. This
  caution is community-corroborated, not an exhaustive server-tested simulator.
- Warlock Healthstone creation levels are 10 / 22 / 34 / 46 / 58, different
  from their item use levels. Base untalented healing is shown.
- Mage gem creation levels are 28 / 38 / 48 / 58. Light Feather is relevant
  after Slow Fall at 12 or Priest Levitate at 34. Rogue Flash Powder enters
  after Vanish at 22; Blinding Powder after Blind at 34. Thistle Tea is a
  rogue-only energy supply with recipe access separate from item use level.
- Sticky Glue, Slumber Sand and Light of Elune have finite quest supply and
  bind on pickup. Slumber Sand is a Horde reward, Light of Elune Alliance.
  Magic Dust drops randomly from Westfall Dust Devils. Jungle Remedy's
  Stranglethorn farm is higher level than its item requirement. Felwood plant
  access needs its cleansing quest and salves, not merely level 45 to use food.
- Self Found prohibits trading, auction-house use and mail. Do not interpret
  vendor/crafting alternatives as permission to bypass those rules. Healthstones
  received from another class require trading to be enabled. Normal battleground
  food vendors are not used as Hardcore leveling defaults.

Sources: [First Aid](https://www.wowhead.com/classic/guide/first-aid-leveling-1-300-wow-classic),
[Alchemy training](https://www.wowhead.com/classic/guide/alchemy-leveling-1-300-wow-classic),
[Alchemy vendor routes](https://www.wowhead.com/classic/guide/alchemy-vendor-recipes-wow-classic),
[cooldown discussion](https://eu.forums.blizzard.com/en/wow/t/potion-cooldown-not-authentic-with-classic-wow/94963/7),
[Hardcore player corroboration](https://www.reddit.com/r/classicwow/comments/16aliq1),
[Create Minor Healthstone](https://classicdb.ch/?spell=6201),
[Lesser](https://classicdb.ch/?spell=6202), [normal](https://classicdb.ch/?spell=5699),
[Greater](https://classicdb.ch/?spell=11729), [Major](https://classicdb.ch/?spell=11730),
[Conjure Mana Agate](https://classicdb.ch/?spell=759), [Jade](https://classicdb.ch/?spell=3552),
[Citrine](https://classicdb.ch/?spell=10053), [Ruby](https://classicdb.ch/?spell=10054),
[Slow Fall](https://www.wowhead.com/classic/spell=130),
[Levitate](https://www.wowhead.com/classic/spell=1706),
[Blind](https://www.wowhead.com/classic/spell=2094),
[Thistle Tea vendor recipe](https://www.wowhead.com/classic/item=18160),
[Blizzard Self Found rules](https://worldofwarcraft.blizzard.com/en-us/news/24056987/wow-hardcore-self-found-mode-begins-february-29),
[Blizzard Hardcore rules](https://worldofwarcraft.blizzard.com/en-us/news/23973734).

## Deliberate boundaries

There is no live game session to prove actual vendor stock, recipe ownership,
auction prices, player inventory or server cooldown behavior. Those are not
represented as live facts. Faction/profession/quest gates remain explicit notes,
not hidden inferred profile settings. The original workbook is retained but
its inclusion flags and build suggestions no longer control the carry list.
Raid-specific protection stockpiles, weapon oils, scroll stacking and a full
Engineering explosive catalogue are outside this focused leveling guide.

## Troll's Blood carry-list inclusion

All four researched Classic ranks are normal Potions & elixirs for every class:
Weak (level 1), Strong (15), Mighty (26), Major (53). Compact mode selects the
strongest usable rank; detailed mode retains lower-rank alternatives and the next
unlock. These sustained regeneration buffs are not classified as emergency supplies.
Mighty uses its world-drop recipe acquisition route rather than assuming a
routine trainer; Major requires Honored Zandalar Tribe reputation for its recipe.
Sources: [Mighty recipe](https://www.wowhead.com/classic/item=3831),
[Major recipe](https://www.wowhead.com/classic/item=20014),
[reputation rewards](https://www.wowhead.com/classic/guide/zandalar-tribe-reputation-wow-classic).

## Agility and visible target dummy ranks

Agility elixirs now cover Warrior, Paladin and Shaman as well as Hunter, Rogue
and Druid. This is a weapon-build recommendation: Agility supplies weapon crit,
dodge and armor; it is not a spell-damage buff. The three pure caster classes
remain outside the normal Agility recommendation.
Reference: [Blizzard's Classic manual, Attributes](https://us.media.blizzard.com/manuals/wow/wow-classic-manual-enUS.pdf).

The already-researched Target Dummy, Advanced Target Dummy and Masterwork Target
Dummy are now visible together in compact mode, explicitly requiring Engineering
85, 185 and 275 respectively. Character level does not select a profession rank;
carry one your actual skill allows. Detailed mode retains all rank tooltips and
item links. See the preserved item records for
[Advanced](https://www.wowhead.com/classic/item=4392) and
[Masterwork](https://www.wowhead.com/classic/item=16023).
