-- Class boundary: shared consumable preparation; combat advice is not enabled.
local _,A=...
local C={name="Priest",combat=false,definitions={},selfSpells={}}
A.RotationAdvisor:RegisterClass("PRIEST",C)
