"""Validate edited stat weights and persistence in a fresh addon runtime."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT/'tests/gear_advisor.lua').read_text(encoding='utf-8'))
lua.execute((ROOT/'tests/gear_weights.lua').read_text(encoding='utf-8'))
fresh, _ = boot()
fresh.execute('TestAddon.characterDB.advisors={statWeights='+lua.globals().WEIGHT_SAVED_FIXTURE+'}')
fresh.execute('''
    MOCK.class="HUNTER"; MOCK.level=40
    assert(TestAddon.GearAdvisor:CurrentProfile().weights.agility==1.375)
    local profile=TestAddon.GearAdvisor.Profile("WARLOCK",40,nil,1)
    assert(TestAddon.GearAdvisor:ApplyWeights(profile).weights.shadow==0.123)
''')
print('PASS: Custom weights survive a fresh-runtime SavedVariables reload.')
