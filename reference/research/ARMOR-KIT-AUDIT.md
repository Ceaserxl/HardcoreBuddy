# Classic Era armor kits

Item and crafting-spell tooltip responses are preserved in
`armor-kit-tooltips.json`. Retrieved from
`https://nether.wowhead.com/classic/tooltip/item/{id}` and
`https://nether.wowhead.com/classic/tooltip/spell/{id}`.
These are Classic Era records, not later expansion or seasonal kits.

| Kit | Item | Character level | Minimum armor item level | Bonus | Permanent enchant ID |
| --- | --- | --- | --- | --- | --- |
| Light | 2304 | 1 | None | 8 armor | 15 |
| Medium | 2313 | 5 | None | 16 armor | 16 |
| Heavy | 4265 | 20 | 15 | 24 armor | 17 |
| Thick | 8173 | 30 | 25 | 32 armor | 18 |
| Rugged | 15564 | 40 | 35 | 40 armor | 1843 |
| Core | 18251 | 50 | 45 | 3 defense | 2503 |

All six item tooltips name chest, legs, hands and feet. Recipe requirements
are Leatherworking 1/100/150/200/250/300; crafting-spell IDs are
2152/2165/3780/10487/19058/22727. Materials are in the captured crafting
tooltips. Pattern 18252 (Core) binds on pickup. Crafting thresholds were also
cross-checked against installed Zygor Classic recipe data, without a runtime
dependency or copying its implementation.

Permanent enchant mappings are corroborated by the original addon source
revisions [JewelTips r56712](https://groups.google.com/g/wowace/c/J4SeEmFinfU)
and [WoWEquip r52750](https://groups.google.com/g/wowace/c/2hEHvI4icpA), plus
[Classic spell 19057](https://classicdb.ch/?spell=19057).
The link format uses `item:itemId:permanentEnchantId:...`. Item level is the
fourth return of the client item-info API, not its character-use-level field.

Only ordinary armor kits are upgraded automatically. Any other permanent
enchant, including Core's defense bonus, is preserved. Unknown or mismatched
links and unloaded item levels do not generate recommendations. Suggested
quantities count the affected equipped pieces, not all four slots unconditionally.

Validation: `tests/run_armor_kits.py` covers all 60 character levels against
gear levels 1-65, all four supported slots, all six enchant mappings, unrelated
enchants, unknown/stale data, exact bag counts, quantity overrides, preview
isolation and live refresh after applying an enhancement. Its optional
`--render` flag produces a frame-tree preview, not a live-client screenshot.
