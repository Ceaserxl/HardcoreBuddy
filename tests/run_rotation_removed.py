"""All rotation helpers stay unloaded and hidden, including previously enabled saves."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
assert(not A.RotationAdvisor and not A.MageRotation)
assert(not A.RotationHelper and not A.ConsumableBuffs,"No live helper or preparation runtime")
assert(A.Data.ConsumableBuffs,"Shared supply scoring metadata remains available")
local targets=A.characterDB.targets
A.characterDB.rotationHelperEnabled=true
A.characterDB.rotationMode="assistant"
A.characterDB.rotationDiagnostics={count=1,entries={{old=true}}}
A.characterDB.rotationDiagnosticsPrevious={count=1}
A.characterDB.rotationDiagnosticsPrevious2={count=1}
A:Initialize()
assert(A.characterDB.targets==targets,"Retirement preserves supply settings")
assert(A.characterDB.rotationHelperEnabled==false,"Previously enabled characters are disabled")
local function cleared()
    for _,key in ipairs({"rotationMode","rotationDiagnostics","rotationDiagnosticsPrevious","rotationDiagnosticsPrevious2"}) do
        assert(A.characterDB[key]==nil,"Old rotation state survived: "..key)
    end
end
cleared()
for _,class in ipairs({"MAGE","ROGUE","HUNTER","WARRIOR","PALADIN","PRIEST","SHAMAN","WARLOCK","DRUID"}) do
    MOCK.class=class
    for _,tab in ipairs(A.Companion.Tabs(A:GetContext())) do assert(tab~="Rotation Advisor" and tab~="Rotation Helper") end
    A:Navigate("training")
    for _,card in ipairs(A.document.cards) do for _,block in ipairs(card.blocks or {}) do
        assert(block.title~="Rotation Helper" and block.title~="Rotation Advisor","No overview entry")
    end end
end
A:OpenSettings()
assert(not A.Settings.pages["Rotation Advisor"])
assert(not A.Settings.pages["Rotation Helper"])
A:Navigate("training"); A.state.filter="Rotation Helper"; A:Refresh(true)
assert(A.state.filter=="Overview","Stale helper routes fall back to Overview")
A:Activate({kind="rotationHelperToggle"})
assert(A.characterDB.rotationHelperEnabled==false and not A.RotationHelper)
local messages=#MOCK.messages
A:HandleSlashCommand("rotation")
A:HandleSlashCommand("rotation log status")
MOCK.FireAll("UNIT_SPELLCAST_START","player")
IsInInstance=function() return false,"none" end
UnitExists=function(unit) return unit=="player" end
MOCK.FireAll("PLAYER_ENTERING_WORLD")
MOCK.FireAll("BAG_UPDATE_DELAYED")
MOCK.FireAll("PLAYER_LOGOUT")
cleared()
assert(not A.RotationHelper and not A.ConsumableBuffs,"Events cannot start helper runtime")
for i=messages+1,#MOCK.messages do assert(not MOCK.messages[i]:find("Rotation Helper:",1,true)) end
''')
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from package_release import manifest

_, files = manifest()
assert not any(name.startswith("RotationHelper/") for name in files)
assert "docs/rotation-helper.md" not in files
assert not any(name.startswith("Rotation/") or name in ("RotationAdvisorUI.lua", "ConsumableBuffs.lua") for name in files)
print("PASS: all rotation behavior unloaded, saved enable disabled, all-class menus hidden and package excluded")
