"""Retired rotation code stays unloaded and its saved traces are discarded."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
assert(not A.RotationAdvisor and not A.MageRotation and not A.ConsumableBuffs)
local targets=A.characterDB.targets
A.characterDB.rotationMode="assistant"
A.characterDB.rotationDiagnostics={count=1,entries={{old=true}}}
A.characterDB.rotationDiagnosticsPrevious={count=1}
A.characterDB.rotationDiagnosticsPrevious2={count=1}
A:Initialize()
assert(A.characterDB.targets==targets,"Retirement preserves supply settings")
local function cleared()
    for _,key in ipairs({"rotationMode","rotationDiagnostics","rotationDiagnosticsPrevious","rotationDiagnosticsPrevious2"}) do
        assert(A.characterDB[key]==nil,"Old rotation state survived: "..key)
    end
end
cleared()
for _,class in ipairs({"MAGE","ROGUE","HUNTER"}) do
    MOCK.class=class
    for _,tab in ipairs(A.Companion.Tabs(A:GetContext())) do assert(tab~="Rotation Advisor") end
end
A:OpenSettings()
assert(not A.Settings.pages["Rotation Advisor"])
A:HandleSlashCommand("rotation")
A:HandleSlashCommand("rotation log status")
MOCK.FireAll("UNIT_SPELLCAST_START","player")
MOCK.FireAll("PLAYER_LOGOUT")
cleared()
''')
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from package_release import manifest

_, files = manifest()
assert not any("rotation" in name.lower() or name == "ConsumableBuffs.lua" for name in files)
print("PASS: rotation removal, saved-trace cleanup, navigation and shipping manifest")
