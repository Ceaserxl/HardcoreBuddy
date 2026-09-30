"""Layout previews from real frames; not live-client screenshots."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, render, composite, ROOT

lua, addon = boot()
render(lua, addon, 'preparation-essentials', filter='Essentials')
render(lua, addon, 'preparation-options', view='alerts', filter='Preparation')
render(lua, addon, 'death-appearance', view='deaths', filter='Appearance')
render(lua, addon, 'preparation-ammo', filter='Class', preview=True, level=40)
out = ROOT / 'docs/layout-previews'
for style in ('Compact', 'Banner', 'Text-only'):
    lua.globals().TEST_STYLE = style
    lua.execute('''
        local H=TestAddon.Deaths
        H.db.settings.alertStyle=TEST_STYLE
        H:ShowAlert({name="Lilyrae",level=36,cause="Kolkar Windchaser",zone="Kolkar Village"},true)
    ''')
    composite(lua.globals().MOCK.frames, addon.Deaths.alert).save(out / ('death-style-' + style.lower() + '.png'))
lua.execute('''
    TestAddon:ShowKitUpdate(40,{"Jagged Arrow"})
    IsResting=function() return true end
    IsInInstance=function() return false,"none" end
    InCombatLockdown=function() return false end
    TestAddon.Readiness.settings.panel=true
    TestAddon.Readiness:Refresh()
''')
for name, frame in [('quiet-upgrade', addon.kitAlert), ('restock-panel', addon.Readiness.panel)]:
    composite(lua.globals().MOCK.frames, frame).save(out / (name + '.png'))
print('Rendered preparation and alert previews.')
