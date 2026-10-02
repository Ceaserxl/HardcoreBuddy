# Rotation Advisor proof-of-concept audit

Audited 2026-10-02. Implementation commit: `39dce2a`.

The full requested goal is **incomplete**. The Rogue/Mage Assistant is implemented
and tested offline. Adaptive One Button casting and its draggable command macro
have no supported implementation under the inspected Classic Era API. A fixed
cast sequence was explicitly rejected by the user and is not a substitute.

## Requirements and evidence

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Companion > Rotation Advisor | `Companion.lua`, `UI.lua`, `RotationAdvisorUI.lua`; sidebar, Overview and `/hcb rotation` navigation tests | Implemented; in-game verification pending |
| Disabled mode | Per-character mode defaults to Disabled; tests cover no polling and highlight cleanup | Implemented; in-game reload verification pending |
| Assistant mode | Pure priorities plus live adapters in `RotationAdvisor.lua`; direct spell highlights on Blizzard bars | Implemented; in-game combat/bar verification pending |
| Rogue/Mage adaptive recommendations | Tests cover learned ranks, cooldowns, spell usability/range, player and target health, resources, movement, combo points, buffs, interrupts and observed enemies | Implemented as a PvE prototype, not a full specialization simulator |
| Target mana and pet health | Read into the snapshot and displayed; these Rogue/Mage priorities have no pet-management action | Context only |
| Enemy count and distance | Counts deduplicate observed target/nameplates; unknown proximity or observed unsafe neighbors suppress area-damage suggestions | Limited to observable units; not an exact world count |
| One Button Mode | Visible but disabled; `SetMode("onebutton")` does not enable casting | Blocked by the protected-action boundary |
| Draggable macro invoking HCB to choose and cast | No macro is created; no protected cast, macro mutation or binding is issued | Not implemented; same blocker |
| Review, validation and commit | Decision/lifecycle tests, UI previews, navigation/settings checks and packaged Lua 5.1 boot; commit `39dce2a` | Completed for the Assistant implementation |

`tests/run_rotation_advisor.py` exercises the priorities and client adapters,
including cooldowns, learned ranks, crowd control, bar paging, disabled mode and
per-character state. Its protected-API sentinels prove that the tested Assistant
paths do not invoke those mocked operations. They do not emulate WoW's security
engine or establish that a casting macro works. The test explicitly expects the
unsupported mode to stay disabled.

The existing `run_page_alignment.py` and `run_global_layout.py` failures were also
reproduced using commit `1e98810` versions of the files modified for this feature.
They concern supply-item layout and do not demonstrate a rotation regression.

## Casting boundary checked against client source

- [Classic Era command dispatch](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua): built-in secure commands are dispatched separately from addon slash commands. Invoking an addon command from a macro does not make its Lua handler secure.
- [Restricted environment](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/RestrictedEnvironment.lua): the secure environment exposes macro-style state, not arbitrary health/resource reads or the ordinary addon recommendation table.
- [Secure handlers](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_RestrictedAddOnEnvironment/SecureHandlers.lua): the external handler API rejects combat-time execution/updates. Predeclared secure spell actions do not provide an unrestricted callback for HCB to select the next spell.
- [Assisted-combat API](https://github.com/Gethe/wow-ui-source/blob/classic_era/Interface/AddOns/Blizzard_APIDocumentationGenerated/AssistedCombatDocumentation.lua): the shared generated documentation exposes availability and Blizzard-selected spell queries. It provides no method to register HCB priorities or supply HCB's chosen spell. Its presence in a source branch does not establish availability on the user's character/client.

These findings leave no supported route for the requested adaptive casting
behavior. The current implementation does not try protected calls and then
silence their errors. A change in scope from the user, or a supported API that
allows the requested behavior, is needed to resolve the remaining requirement.

## Live verification still required

1. On a Rogue or Mage, enable Assistant Mode in Settings > Rotation Advisor.
2. Put learned spells directly on Blizzard action bars. Confirm recommendations
   and highlights during movement, cooldowns, low resources and target changes.
3. Check bar paging and gameplay with the HCB window closed. Disable the mode
   and confirm HCB highlights disappear without removing Blizzard proc effects.
4. Reload and confirm the character's mode persists. Check another character
   still defaults to Disabled.
5. Confirm the client reports no addon errors during those interactions.

No live-client pass has been recorded by this audit.
