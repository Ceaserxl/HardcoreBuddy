-- Class boundary: shared consumable preparation; combat advice is not enabled.
local _,A=...
local C={name="Warrior",combat=false,definitions={},selfSpells={}}
A.RotationAdvisor:RegisterClass("WARRIOR",C)
