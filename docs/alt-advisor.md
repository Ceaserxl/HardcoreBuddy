# Alt Advisor

Equipment and the active Gear Advisor scoring profile are captured automatically
after login, equipment, level, talent and spell changes, and on logout. Independent
copies are stored account-wide in `HardcoreBuddyDB.altEquipment`, keyed by character
GUID. Item data loading does not overwrite a previous complete snapshot. Log into
each character once after installing this feature, then log out normally to persist
its equipment. Subsequent visits refresh it. Reset AddOn clears these snapshots too.

`HardcoreBuddy | Alt Advisor` appears below item advice only for BoE or nonbinding
equipment that improves another cached character on the same realm and faction.
The native tooltip's binding lines are checked after the item tooltip finishes
building, so an already-soulbound BoE is excluded. BoP, quest-bound and unknown
binding types are excluded. Special profession/reputation/race/class-list requirements
that cannot be verified for an offline character are conservatively excluded.

Each character appears once with their best eligible slot. Numeric percentage gains
sort highest first; upgrades without a numeric baseline follow as Empty slot or
Zero baseline. The existing scoring engine handles class armor/weapon eligibility,
unique jewelry and two-handed replacement of both hands, using saved stat weights
and dual-wield knowledge rather than the bank character's profile. Scores describe
last saved gear, not a live inspection of the alt.

Settings > Gear Advisor > Display & notifications > Show Alt Advisor upgrades is
enabled by default. Turning it off hides the section; the cache continues updating.
The Gear Advisor master switch also suppresses Alt Advisor advice.

Validation: `tests/run_alt_advisor.py`, the auction comparison regression suite,
and shared section-layout checks. Actual WoW hover rendering and character switching
still need live verification.
