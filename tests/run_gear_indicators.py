"""Upgrade decisions and native bag/quest button lifecycle with real scoring fixtures."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/gear_indicators.lua').read_text(encoding='utf-8'))
