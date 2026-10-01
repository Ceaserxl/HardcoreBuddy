"""Bag notifications and opt-in equipment changes, with real comparison logic."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua,addon=boot()
lua.execute((ROOT/'tests/gear_bags.lua').read_text(encoding='utf-8'))

# A new login preserves both explicit enabled preferences rather than defaults.
from lupa.lua51 import LuaRuntime
fresh=LuaRuntime(unpack_returned_tuples=True)
for file in ('wow_mock.lua','deaths_mock.lua'):
    fresh.execute((ROOT/'tests'/file).read_text(encoding='utf-8'))
fresh.execute('HardcoreBuddyDB={gearBagNotify=true,gearAutoEquip=true}')
restored=fresh.table()
for entry in (ROOT/'HardcoreBuddy.toc').read_text().splitlines():
    if entry.strip() and not entry.startswith('#'):
        fresh.execute((ROOT/entry.replace('\\','/')).read_text(encoding='utf-8'),'HardcoreBuddy',restored)
fresh.globals().MOCK.FireAll('ADDON_LOADED','HardcoreBuddy')
assert restored.db.gearBagNotify and restored.db.gearAutoEquip
print('PASS: both bag preferences survive fresh-runtime initialization.')
