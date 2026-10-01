"""Offline map geometry, independent overlays, filters, notices and navigation."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute((Path(__file__).with_name('map_advisor.lua')).read_text())
print('PASS: map data, exploration ownership, map transitions, filters, notices and controls.')
