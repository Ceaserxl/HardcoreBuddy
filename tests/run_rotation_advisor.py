"""Mage 1-60 priorities, live reads, native glow/macro regressions and UI checks."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite
lua, addon = boot()
root = Path(__file__).resolve().parent
lua.execute("\n".join((root / name).read_text(encoding="utf-8") for name in
    ("mage_rotation_regression.lua", "rotation_highlight_regression.lua", "mage_rotation_live_regression.lua")))
if "--render" in sys.argv:
    out = root.parent / ".release"
    out.mkdir(exist_ok=True)
    composite(lua.globals().MOCK.frames, addon.window).save(out / "rotation-advisor.png")
