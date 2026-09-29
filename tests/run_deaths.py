"""Embedded deaths: original behavior, real TOC boot, handoff and saved-data migration."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
import os

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / 'tests/deaths_regression.lua').read_text())

def boot(saved=None, unsupported=False):
    lua = LuaRuntime(unpack_returned_tuples=True)
    addon = lua.table()
    for path in ['tests/wow_mock.lua', 'tests/deaths_mock.lua']:
        lua.execute((ROOT / path).read_text())
    if saved:
        lua.globals().HardcoreBuddyDB = lua.table_from(saved, recursive=True)
    if unsupported:
        lua.execute('''
            local register = UIParent.RegisterEvent
            local create = CreateFrame
            function CreateFrame(...)
                local frame = create(...)
                frame.RegisterEvent = function(self, event)
                    if event == "HARDCORE_DEATHS" then error("Unsupported event") end
                    return register(self, event)
                end
                return frame
            end
        ''')
    for path in (ROOT / 'HardcoreBuddy.toc').read_text().splitlines():
        if path and not path.startswith('#'):
            lua.execute((ROOT / path.replace('\\', '/')).read_text(), 'HardcoreBuddy', addon)
    lua.globals().TestAddon = addon
    lua.globals().MOCK.FireAll('ADDON_LOADED', 'HardcoreBuddy')
    return lua, addon

lua, addon = boot()
old_dir = ROOT.parent / 'HardcoreDeaths'
if old_dir.is_dir():
    lua.globals().TEST_LEGACY_PATH = old_dir.as_posix()
    assert 'HardcoreBuddy' in (old_dir / 'HardcoreDeaths.toc').read_text().split('## OptionalDeps:')[1].splitlines()[0]
lua.execute((ROOT / 'tests/deaths_integration.lua').read_text())

def plain(table):
    return {k: plain(v) if hasattr(v, 'items') else v for k, v in table.items()}

saved = plain(addon['db'])
fresh, restored = boot(saved)
assert plain(restored['Deaths']['db']) == saved['deaths'], 'Death history/settings must survive relog'
assert restored['Deaths']['db']['importedHardcoreDeaths'] is True
fresh.execute('''
    local H=TestAddon.Deaths
    assert(not H.mini:IsShown(), "migrated feed preference survives relog")
    assert(H.db.settings.scale==1.2)
    assert(H.db.settings.alertDuration==7 and H.options.duration:GetText()=="7", "duration survives relog")
    assert(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"))
    assert(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"))
''')
unsupported, _ = boot(unsupported=True)
for selection, version, expected in [('HeroFallen', None, 'RaidWarning'),
                                      ('DeathBell', 2, 'RaidWarning'),
                                      ('DeathBell', 3, 'DeathBell'),
                                      ('RaidWarning', 3, 'RaidWarning'),
                                      ('Arugal', None, 'Arugal'),
                                      ('HeroFallen', 2, 'HeroFallen')]:
    settings = dict(alertSound=selection)
    if version is not None:
        settings['soundVersion'] = version
    _, migrated = boot({'deaths': {'settings': settings}})
    assert migrated['Deaths']['db']['settings']['alertSound'] == expected
    assert migrated['Deaths']['db']['settings']['soundVersion'] == 3
print('PASS: Original native warning restored once; later explicit sound choices survive reload.')
unsupported.execute('''
    assert(TestAddon.Deaths.nativeSupported==false)
    assert(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"))
    assert(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"))
''')
existing, _ = boot({'deaths': {'watch': {'realm:older': True}, 'settings': {'scale': 0.9, 'mini': True, 'alerts': True}}})
existing.execute('''
    HardcoreDeathsDB={records={{name="Older", realm="Realm", date=1800, source="Imported"}},
        watch={["realm:older"]=true},settings={scale=1.4,mini=false,alerts=false}}
    MOCK.FireAll("ADDON_LOADED", "HardcoreDeaths")
    local H=TestAddon.Deaths
    assert(#H.db.records==1 and H.db.watch==nil, "old watching preferences are cleared and never imported")
    assert(H.db.settings.scale==0.9 and H.db.settings.mini and H.db.settings.alerts,
        "existing Buddy preferences take precedence over legacy preferences")
    assert(not RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"))
''')
# The legacy addon still functions when HardcoreBuddy is disabled.
fallback = LuaRuntime()
if old_dir.is_dir():
    os.chdir(old_dir)
    fallback.execute((old_dir / 'tests/regression.lua').read_text())
    os.chdir(ROOT)

compiler = LuaRuntime()
paths = list(ROOT.rglob('*.lua'))
for path in paths:
    compiler.execute('assert(loadstring(...))', path.read_text(encoding='utf-8'))
print(f'PASS: Full TOC boot, relog persistence, unsupported event fallback, standalone fallback; {len(paths)} Lua files compile under Lua 5.1.')
