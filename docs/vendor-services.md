# Restocking and vendor services

Missing Essentials shows a nearby friendly vendor when one is known. Click the
item to mark its vendor on the world map and minimap, and target that exact
vendor name within WoW's targeting range. The panel stays open. Right-click
either marker to clear it; selecting another item replaces the marker. The Review
supplies button still opens Essentials. Target buttons hide during combat.
Both markers use Blizzard's red guard-destination flag. They clear automatically
within five yards of the marked coordinates. Arrival uses the recorded location;
roaming vendors are not tracked live.

The local catalogue contains 335 vendors for 96 of the 194 supply item IDs
examined. Relationships, names, factions and coordinates were extracted from
[Questie v10.0.0 Classic item data](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicItemDB.lua)
and [NPC data](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicNpcDB.lua).
There is no in-game Questie dependency. Opening a merchant also remembers its
observed items and location for that character. Friendly vendors on the current
map qualify at any distance, in cities and outdoor zones alike. Vendors with a
single recorded location and no patrol route
are preferred, followed by those with unknown movement, then known roaming
vendors. Distance breaks ties. Stationary status is inferred from source data;
it is not a live movement check. Markers for roaming vendors show a recorded
location, not live tracking. This is a proximity estimate, not pathfinding or
an assertion that an inn vendor sells everything. Unknown sources are labeled
honestly; crafted items and limited stock may require another source.

All classes can choose the ordinary vendor foods and drinks. Food alternatives
include bread, cheese, fish, fruit, fungus, meat and regional night elf foods at
the usable recommended tier. Without an explicit saved food default, the supply
recommendation prefers an equivalent sold by a local vendor using the same
stationary-first and nearest-distance rules, only when fewer than five of the
current item are owned. Saved defaults are preserved. Unknown stock does not
trigger substitution.

If fewer than five are owned and a selected plain food has no vendor in the zone, Missing Essentials can mark
a vendor selling an equivalent of the same tier. The row labels it as equivalent
food; the tooltip and marker name the actual item. Select that item as the default
in Supplies to track/restock it: vendor guidance never silently substitutes an
item during a purchase. Haunch of Meat has no Stormwind seller in the reviewed
Classic data; bread and cheese provide local equivalents.

Food effects and icons are cached from Wowhead Classic item tooltips by
`scripts/import_vendor_food.py`; names, use levels and seller relationships use
the Questie sources above. See [Classic vendor food families](https://www.wowhead.com/classic/guide/wow-classic-best-food)
and [Haunch of Meat vendor locations](https://www.wowhead.com/classic/item=2287/haunch-of-meat).
The six ordinary vendor drink tiers were already present; they now allow every
class. Reputation rewards and unavailable later-expansion drinks are not treated
as ordinary vendor water.

Opening a merchant offers only missing Essentials that its live stock can sell.
Buy confirms that visit. Auto Buy Next Time saves the opt-in; it can also be
changed under Settings > General > Vendor purchases. Automatic purchases print
chat receipts after bag contents confirm delivery. Purchases recheck stock,
money, capacity and Keep on hand targets after each transaction. Whole vendor
bundles only; no overshooting targets, special-currency purchases, or retries of
unconfirmed purchases. Closing the merchant or entering combat cancels buying.

Settings > General > Repairs enables personal-money auto repair, default off.
Repairs run once per merchant opening only when the full cost is affordable;
guild funds are never used. Vendor purchases also default off.

Best Armor in the auction window defaults on for characters without a saved
choice. Existing explicit choices remain unchanged.

## Auction vendor protection

HardcoreBuddy buyouts are blocked for standard unlimited-stock throwing knives
and axes, including Heavy Throwing Dagger, and other items observed as purchasable
with unlimited stock at a friendly merchant. The message names the vendor (or
vendor type for bundled throwing weapons), both in the AH status and chat.
Checks run before lookup, confirmation and acceptance. Blizzard's own Browse
purchase flow is unchanged.

The Classic throwing-weapon catalog uses the ordinary general-goods tiers; see
[Heavy Throwing Dagger](https://www.wowhead.com/classic/item=3108/heavy-throwing-dagger)
and [Mabel Solaj's Classic inventory](https://www.wowhead.com/classic/npc=227/mabel-solaj).
Live merchant evidence requires stock `-1` and an available ordinary-money purchase.
Finite stock, sold-out stock, extended-cost items and old visits with no stock
metadata never establish eligibility. Later finite-stock observations clear the
unlimited flag. Vendor sell price and the existing vendor-location catalog alone
are not evidence of unlimited supply. Coverage beyond the bundled throwing
weapons expands as the character visits merchants; it is not a complete catalog
of every vendor item.

## Debug exports

Settings > Debug > Capture data retains the full incremental dump and progress
animation without creating an output EditBox. Prompt to reload after dump is
off by default. When enabled, a successful capture offers Reload Now / Later.
Reload happens directly from the confirmation click; the asynchronous worker
never attempts the hardware-event-restricted reload. Failed captures preserve
the last good dump and do not prompt. Reset AddOn separately clears saved data
and reloads immediately from its Reset & Reload confirmation click.

Reload or log out to write the cached dump to disk. Open:

`_classic_era_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/HardcoreBuddy.lua`

Search for `debugDump` inside `HardcoreBuddyCharacterDB`; its `text` field holds
the full serialized export. The Debug page displays the current realm/character
path. Copy from an external text editor, not from an in-game textbox.
