# Companion spell training

Companion > Spells displays the next training level after the selected character
level. Show all future spells expands it into a continuous list through level 60.
Search applies to the selected next-level or all-future view. Spell names, ranks,
icons and hover descriptions come from the WoW client, with lazy loading for
uncached spell data.

The bundled nine-class Vanilla trainer tables derive from What's Training? 10.0.0
by Sveng, installed in the adjacent WhatsTraining folder. Its MIT license is
included in WHATS_TRAINING_LICENSE.txt. Rebuild offline with:

    python scripts/import_class_spells.py ../WhatsTraining

HardcoreBuddy does not load, hook or read What's Training? in-game. Faction and
racial restrictions are retained; planning uses the current character's faction
and race. Talent-dependent ranks are labeled with their required talent, including
talents not currently learned, so future planning remains possible. The importer
adds the missing Hemorrhage talent requirement to its two trained upgrades.
Earlier ranks and class quests can still be required. Poison skill metadata is
retained in the source data but not presented as a verified training prerequisite.
Costs are reference prices from the source dataset, not a live trainer quote;
they are not adjusted for the character's reputation or other discounts.

This is a future class-trainer reference, not a list of unlearned past spells,
quest rewards, dropped spell books or demon grimoires. Hunter trainer entries
include trainer-taught pet abilities; Companion > Pet Training remains the guide
for abilities learned by taming beasts.
