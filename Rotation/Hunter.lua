-- Class boundary: shared consumable preparation; combat advice is not enabled.
local _,A=...
local C={name="Hunter",combat=false,definitions={},selfSpells={}}
A.RotationAdvisor:RegisterClass("HUNTER",C)
