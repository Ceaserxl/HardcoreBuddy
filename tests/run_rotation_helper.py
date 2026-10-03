"""Fresh assistant: scenario/replay checks, native-glow ownership and API boundaries."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from rotation_archive_fixture import boot

lua, addon = boot()
lua.execute((ROOT / "tests/rotation_helper_cases.lua").read_text(encoding="utf-8"))

# Class policies must remain portable and testable without any game API.
mage = (ROOT / "RotationHelper/Mage.lua").read_text(encoding="utf-8")
for forbidden in ("CreateFrame", "UnitHealth", "GetTime", "GetSpell", "RegisterEvent", "SetScript", "characterDB"):
    assert forbidden not in mage, forbidden
runtime = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "RotationHelper").glob("*.lua"))
for forbidden in ("CastSpell", "UseAction", "UseItemByName", "RunMacro", "EditMacro", "SetAttribute", "GetUnitSpeed", "IsMounted", "rotationDiagnostics", "Zygor"):
    assert forbidden not in runtime, forbidden
for forbidden in ("MAGE", '"Mage"', "frostbolt", "scorch", "intellect"):
    assert forbidden not in (ROOT / "RotationHelper/Runtime.lua").read_text(encoding="utf-8"), forbidden
print("PASS: class isolation; no casting, bar mutation, movement filters or combat logging")
