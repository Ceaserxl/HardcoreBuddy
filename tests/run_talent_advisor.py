"""Validate Classic paths, live point spending, preview isolation and navigation."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT, composite

lua, addon = boot()
lua.execute((ROOT / 'tests/talent_advisor.lua').read_text(encoding='utf-8'))
fresh, _ = boot()
fresh.execute('''
    HardcoreBuddyDB.gearAdvisorActive=false
    HardcoreBuddyDB.talentAdvisorEnabled=false
    TestAddon:Initialize()
    assert(not TestAddon.GearAdvisor:IsEnabled())
    assert(not TestAddon.TalentAdvisor:IsEnabled())
    assert(TestAddon.db.gearAdvisorEnabled~=false)
''')
print('PASS: Saved advisor disable flags survive initialization independently of tooltip preference.')
if '--render' in sys.argv:
    target = ROOT / '.release/talent-advisor-preview.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    composite(lua.globals().MOCK.frames, addon.window).save(target)
    print('PASS: Offline advisor layout preview:', target)
    panel_target = ROOT / '.release/talent-panel-preview.png'
    composite(lua.globals().MOCK.frames, addon.TalentPanel.frame).save(panel_target)
    print('PASS: Offline attached talent panel preview:', panel_target)
