-- Class boundary: shared consumable preparation; combat advice is not enabled.
local _,A=...
local C={name="Druid",combat=false,definitions={},selfSpells={}}
A.RotationAdvisor:RegisterClass("DRUID",C)
