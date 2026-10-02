# Rotation Advisor proof of concept

Updated 2026-10-02. The approved scope is **Assistant-only for Rogue and Mage**,
with Disabled as the per-character default. The user deferred adaptive One Button
casting and later authorized continued work on the Assistant. One Button and a
casting macro are outside this proof of concept.

## Behavior

Open Companion > Rotation Advisor or `/hcb rotation`, then Settings to enable
Assistant Mode. Recommendations and highlights continue with the HCB window
closed. The user presses the suggested spell on their own action bar.

- Rogue: builders, finishers, Slice and Dice, Kick, Evasion, and learned talent
  abilities such as Riposte, Hemorrhage and Blade Flurry.
- Mage: Frost leveling, Counterspell, defensive shields, Frost Nova, movement,
  mana conservation, wand use and Evocation between pulls.
- Uses learned ranks, cooldowns, usability, spell range, player/target health,
  resources, movement, combo points, buffs and interruptible target casts.
- Highlights only the recommended spell rank on Blizzard action bars. HCB owns
  its glow texture and leaves native proc effects alone. It creates these textures
  out of combat, then changes only its own highlight during combat.
- Suppresses repeated Shoot prompts while wand attacks are active. Interrupts
  and defensive priorities can still take precedence.
- Counts deduplicated observed targets and nameplates. Unknown proximity,
  nearby unengaged enemies or observed crowd control suppress area suggestions.
  Position checks include vertical distance. This cannot establish an exact count
  of all enemies in the world.
- Pet health and target mana are displayed as context; these two class priorities
  have no pet-management actions.
- Disabled stops combat polling and removes HCB highlights. World transitions
  suspend guidance until the character enters the world again.

This is a PvE prototype, not a damage simulator or a complete specialization
rotation. Spell macros and third-party action bars are not supported.

## Offline validation

`tests/run_rotation_advisor.py` covers pure priorities, modern and legacy client
adapters, learned ranks, unknown state, crowd control, observed enemy distance,
active wand attacks, bar paging, world transitions, mode settings, navigation and
UI geometry. Protected-operation sentinels reject casting, macro mutation,
bindings and secure-attribute writes along the tested paths. Repeated combat
updates are checked for frame allocation.

The layout renderer provides simulated previews; it cannot establish actual
in-game appearance, action-bar behavior or WoW security behavior. Settings layout
and dependency checks also cover the Rotation Advisor settings page.

Client adapter references:

- [Classic Era action buttons](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ActionBar/Shared/ActionButton.lua)
- [Classic Era spell API documentation](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua)

## Live verification still required

1. Enable Assistant Mode on a Rogue or Mage with learned spells placed directly
   on Blizzard action bars. Confirm the indicated rank glows.
2. Check movement, cooldowns, interrupts, low resources, target changes and nearby
   crowd-controlled enemies. Confirm low-mana wand attacks do not prompt toggling
   Shoot off.
3. Check bar paging, world transitions and guidance with the HCB window closed.
   Disable the mode and confirm only HCB highlights disappear.
4. Reload and confirm the character's mode persists. Another character should
   default to Disabled.
5. Confirm there are no addon errors during these interactions.

No live-client pass is claimed.
