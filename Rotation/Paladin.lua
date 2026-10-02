-- Class boundary: shared consumable preparation; combat advice is not enabled.
local _,A=...
local C={name="Paladin",combat=false,definitions={},selfSpells={}}
A.RotationAdvisor:RegisterClass("PALADIN",C)
