# Restocking and vendor services

Missing Essentials shows a nearby friendly vendor when one is known. Click the
item to target that exact vendor name within WoW's targeting range. The Review
supplies button still opens Essentials. Target buttons hide during combat.

The local catalogue contains 314 vendors for 59 of the 157 supply item IDs
examined. Relationships, names, factions and coordinates were extracted from
[Questie v10.0.0 Classic item data](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicItemDB.lua)
and [NPC data](https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicNpcDB.lua).
There is no in-game Questie dependency. Opening a merchant also remembers its
observed items and location for that character. The nearest friendly vendor on
the current map is used: any distance within a capital, or within ten map
percentage points elsewhere. This is a proximity estimate, not pathfinding or
an assertion that an inn vendor sells everything. Unknown sources are labeled
honestly; crafted items and limited stock may require another source.

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

## Debug exports

Settings > Debug > Capture data retains the full incremental dump and progress
animation without creating an output EditBox. Reload after dump completes is
off by default. When enabled, a successful capture waits until out of combat
before reloading. Failed captures preserve the last good dump and do not reload.

Reload or log out to write the cached dump to disk. Open:

`_classic_era_/WTF/Account/<ACCOUNT>/<Realm>/<Character>/SavedVariables/HardcoreBuddy.lua`

Search for `debugDump` inside `HardcoreBuddyCharacterDB`; its `text` field holds
the full serialized export. The Debug page displays the current realm/character
path. Copy from an external text editor, not from an in-game textbox.
