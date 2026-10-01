"""Central settings navigation, controls, and optional offline layout previews."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT, composite
lua, addon=boot()
lua.execute((ROOT/'tests/settings.lua').read_text(encoding='utf-8'))
if '--render' in sys.argv:
    target=ROOT/'.release/settings-previews'
    target.mkdir(parents=True,exist_ok=True)
    for section in ['General','Gear Advisor','Talent Advisor','Auction House','Death Alerts','Low Health','NPC Alerts','Map']:
        addon.OpenSettings(addon,section)
        composite(lua.globals().MOCK.frames,addon.window).save(target/(section.lower().replace(' ','-')+'.png'))
    for page in ['Stat Weights','Gear Snapshot']:
        addon.OpenSettings(addon,'Gear Advisor')
        addon.Settings.OpenGearPage(addon.Settings,page)
        composite(lua.globals().MOCK.frames,addon.window).convert('RGB').save(target/(page.lower().replace(' ','-')+'.png'))
    print('Offline settings previews:',target)
