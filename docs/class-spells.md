# Companion spell training

Companion > Spells shows untrained class spells available at the live character's
level. Learned spells are never listed in the current trainer section. When
none are untrained, Available at Trainer shows an empty state. Learned higher ranks suppress
obsolete untrained ranks. Race, faction and allocated talent restrictions apply.
Training and level/talent changes refresh the visible page.

Planning mode still displays the next training level after the selected level.
Future spells are shown by default. The toggle hides or appends future class and pet sections through level 60,
keeping the current section in place. Search applies to the displayed sections. Spell names, ranks,
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

Hunter pet abilities appear in separate level sections using the reviewed Pet
Guide ranks. Trainer abilities are removed from the ordinary class-spell rows to
avoid duplicates. Each pet rank shows its pet level, training points and either
the pet trainer or a taming source; clicking opens full rank/source details.
The planning level is the maximum of level 10, required pet level and earliest
verified taming-source level. Ranks without a verified trainer or taming source
are omitted (currently Charge 4 and Lightning Breath 1). Pet family restrictions
still apply; the list is a future reference, not an active-pet upgrade check.

Warlocks have separate demon-grimoire sections with 59 unique books from the
licensed Vanilla WarlockTomes dataset. Each includes the taught spell, demon
family and reference cost. Shared Succubus/Incubus books appear once. The matching
demon must be summoned to teach it. All pet entries participate in next-level,
all-future and search views. Companion > Pet Training continues to check the
active Hunter pet's learned ranks.

Current class training is checked against the live spellbook. Future pet training
remains a reference; it does not infer every pet's learned spells. Quest rewards
and dropped spell books are outside the trainer list. Costs remain reference
prices, and earlier ranks or class quests may still be prerequisites.
