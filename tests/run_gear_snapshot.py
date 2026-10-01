"""Verify manual gear capture, native Character navigation and offline persistence."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lupa.lua51 import LuaRuntime
from render_layout import boot, ROOT, composite

lua, addon = boot()
lua.globals().GEAR_SNAPSHOT_TEST = True
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/gear_snapshot.lua').read_text(encoding='utf-8'))

# Deserialize only the trusted fixture produced by this test into a runtime
# without native item/talent APIs. No current item cache is needed to inspect it.
offline = LuaRuntime(unpack_returned_tuples=True)
offline.execute(lua.globals().SNAPSHOT_SAVED_FIXTURE)
offline.execute('''
    local s=HardcoreBuddyCharacterDB.gearSnapshot
    assert(s.schema==2 and s.complete)
    assert(s.character.class=="HUNTER" and s.profile.weights.crit==0.8)
    assert(s.slots[10].enchantID==1843 and s.scoring.enchantsIncluded==false)
    assert(s.slots[10].apiStats.RESISTANCE0_NAME==211)
    assert(s.slots[10].advisor.stats.RESISTANCE0_NAME==171)
    assert(math.abs(s.slots[10].score-11.155)<0.00001)
    assert(s.talents[1].talents[1].rank==5)
    assert(s.slots[10].tooltipLines[6].left=="Reinforced Armor +40")
    assert(s.slots[3].advisor.stats.ITEM_MOD_AGILITY_SHORT==8)
    assert(s.slots[19].state=="empty")
''')
print('PASS: SavedVariables fixture reloaded and inspected offline with no WoW APIs.')

if '--render' in sys.argv:
    addon.window.Hide(addon.window)
    target = ROOT / '.release/gear-snapshot-preview.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    composite(lua.globals().MOCK.frames, lua.globals().CharacterFrame).save(target)
    print(f'PASS: Character snapshot layout simulation: {target}')
