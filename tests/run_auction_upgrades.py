"""Native auction boundaries, standalone scoring, and continuous results UI."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text(encoding='utf-8'))
