"""Lua 5.1 parity and integration checks. Requires Python + lupa (lua51)."""
import hashlib
import json
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def load(lua, addon, path):
    lua.execute((ROOT / path).read_text(encoding='utf-8'), 'HardcoreBuddy', addon)

def equal(expected, actual, path='root'):
    if isinstance(expected, dict):
        assert actual is not None, path
        for k, v in expected.items(): equal(v, actual[k], f'{path}.{k}')
        assert set(actual.keys()) <= set(expected.keys()), (path, 'extra keys', set(actual.keys())-set(expected.keys()))
    elif isinstance(expected, list):
        assert actual is not None and len(actual) == len(expected), (path, 'length', len(actual) if actual is not None else None, len(expected))
        for i, v in enumerate(expected, 1): equal(v, actual[i], f'{path}[{i}]')
    else:
        assert expected == actual, (path, expected, actual)

def ids(table): return [v['id'] for _, v in table.items()]

lua = LuaRuntime(unpack_returned_tuples=True)
addon = lua.table()
for path in ['Data/Items.lua','Data/Scrolls.lua','Data/Crafting.lua','Data/Companions.lua','Data/Quivers.lua','Data/Presentation.lua','Data/PetGuide.lua','Data/FactionRules.lua','Data/ProfessionProgression.lua','Planner.lua','Inventory.lua','Professions.lua','Crafting.lua','Supplies.lua','Guide.lua','Data/Instances.lua','Data/InstancesRaids.lua','Instances.lua','Companion.lua']:
    load(lua, addon, path)
P, G = addon['Planner'], addon['Guide']
fixtures = json.loads((ROOT / 'tests/website-fixtures.json').read_text(encoding='utf-8'))
# The archived website fixtures preserve provenance, while shipping data now
# deliberately omits it. Compare every gameplay field after removing only the
# two external-link metadata keys from an in-memory copy of those fixtures.
def without_external_metadata(value):
    if isinstance(value,dict):
        return {key:without_external_metadata(child) for key,child in value.items()
                if key not in ('reference','classificationSource')}
    if isinstance(value,list): return [without_external_metadata(child) for child in value]
    return value
fixtures=without_external_metadata(fixtures)
for fixture in fixtures['carry']:
    result=P['BuildList'](fixture['characterClass'],fixture['level'])
    assert len(result['rows']) == len(fixture['rows'])
    for expected, (_, actual) in zip(fixture['rows'],result['rows'].items()):
        for key in ['id','displayName','short']: assert expected[key] == actual[key], (fixture['characterClass'],fixture['level'],key)
        for key in ['options','progression']: assert expected[key] == ids(actual[key]), (fixture['characterClass'],fixture['level'],key,expected[key],ids(actual[key]))
        assert expected['next'] == (actual['next']['id'] if actual['next'] else None)
    for key in ['specialist','backups','advanced']: assert fixture[key] == ids(result[key]), (fixture['characterClass'],fixture['level'],key)
print('PASS: 540 carry profiles match website rows, ordering, options, progression, next unlocks and extra groups.')
for level in range(1,61):
    equal(fixtures['hunter'][level-1],P['HunterPlan'](level,level),f'hunter{level}')
    equal(fixtures['warlock'][level-1],P['WarlockPlan'](level),f'warlock{level}')
    equal(fixtures['quivers'][level-1],P['QuiverPlan'](level),f'quivers{level}')
print('PASS: All 60 Hunter, Warlock and quiver plans match full website fixtures.')
for hunter_level in range(1,61):
    for pet_level in range(1,hunter_level+1):
        plan=P['HunterPlan'](hunter_level,pet_level)
        for _, a in plan['abilities'].items():
            if a['current']:
                assert a['current']['petLevel'] <= pet_level
                assert P['TrainingLevel'](a['current']) <= hunter_level
                for _, s in a['sources'].items():
                    assert s['routine'] and s['classification']=='Normal' and s['minLevel']<=hunter_level
    unknown=P['HunterPlan'](hunter_level,None)
    assert all(a['current'] is None for _,a in unknown['abilities'].items())
print('PASS: 1,830 independent Hunter/pet level pairs and 60 unknown-pet cases respect both gates.')
for _, a in addon['Data']['Companions']['abilities'].items():
    for _, rank in a['ranks'].items():
        for _, source in rank['sources'].items(): assert 'rare' not in source['classification'].lower()
for _, source in addon['Data']['Companions']['starters'].items(): assert source['classification']=='Normal'
for class_name in ['Druid','Hunter','Mage','Paladin','Priest','Rogue','Shaman','Warlock','Warrior']:
    for level in range(1,61):
        for detailed in [False,True]:
            context=lua.table_from(dict(characterClass=class_name,level=level,petLevel=level,detailed=detailed,mode='preview'))
            doc=G['Build'](context)
            assert [doc['cards'][i]['title'] for i in range(1,4)]==['Food & drink','Potions & elixirs','Emergency supplies']
            if class_name=='Hunter':
                family_ids=[b['familyId'] for _,b in doc['cards'][4]['blocks'].items() if b['familyId']]
                assert len(family_ids)==(17 if detailed else 0) and len(set(family_ids))==len(family_ids)
                if not detailed:
                    blocks=doc['cards'][3]['blocks']
                    for name in ['Target Dummy','Advanced Target Dummy','Masterwork Target Dummy']:
                        assert any(b['title']==name for _,b in blocks.items()), name
            assert G['References'] is None, 'Removed Sources formatter remains callable'
print('PASS: 1,080 compact/detailed guide models preserve section order, all dummy ranks and family coverage without a Sources formatter.')
equal(dict(characterClass='Hunter',level=1,detailed=False,mode='live'),P['NormalizeProfile'](None))
equal(dict(characterClass='Hunter',level=1,detailed=False,mode='live'),P['NormalizeProfile'](lua.table_from(dict(characterClass='Death Knight',level=900,detailed='yes',mode='other'))))
equal(dict(characterClass='Warrior',level=60,detailed=True,mode='live'),P['NormalizeProfile'](lua.table_from(dict(characterClass='Warrior',level=60,detailed=True,mode='live',quantities=lua.table()))))
for rel, expected in json.loads((ROOT/'reference/manifest.json').read_text()).items():
    assert hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()==expected,rel
# Runtime data deliberately contains no external source URLs. Archived reference
# fixtures remain checksummed above; pet creature-source tables are still tested.
def assert_no_runtime_urls(value, path='Data'):
    if hasattr(value,'items'):
        for key, child in value.items(): assert_no_runtime_urls(child, f'{path}.{key}')
    elif isinstance(value,str):
        assert 'https://' not in value and 'http://' not in value, path
assert_no_runtime_urls(addon['Data'])
toc=(ROOT/'HardcoreBuddy.toc').read_text()
assert 'Dependencies:' not in toc and 'OptionalDeps:' not in toc
for line in toc.splitlines():
    if line and not line.startswith('#'): assert (ROOT/line.replace('\\','/')).is_file(),line
print('PASS: Profile normalization, source checksums and standalone TOC.')
lua.globals().TestAddon=addon
load(lua,addon,'tests/supplies.lua')
load(lua,addon,'tests/professions.lua')
load(lua,addon,'tests/professionprogression.lua')
load(lua,addon,'tests/crafting.lua')
load(lua,addon,'tests/factions.lua')
load(lua,addon,'tests/companion.lua')
load(lua,addon,'tests/wow_mock.lua')
load(lua,addon,'Skin.lua')
load(lua,addon,'Core.lua')
load(lua,addon,'UI.lua')
load(lua,addon,'Minimap.lua')
lua.globals().TestAddon=addon
load(lua,addon,'tests/integration.lua')
load(lua,addon,'tests/profession_integration.lua')
load(lua,addon,'tests/menu_navigation.lua')
load(lua,addon,'tests/redesign.lua')

# Simulate a new login using only serialized SavedVariables, not old runtime objects.
def plain(table):
    return {k:plain(v) if hasattr(v,'items') else v for k,v in table.items()}
saved=plain(addon['db'])
saved_character=plain(addon['characterDB'])
fresh=LuaRuntime(unpack_returned_tuples=True)
fresh_addon=fresh.table()
for path in ['Data/Items.lua','Data/Scrolls.lua','Data/Crafting.lua','Data/Companions.lua','Data/Quivers.lua','Data/Presentation.lua','Data/PetGuide.lua','Data/FactionRules.lua','Data/ProfessionProgression.lua','Planner.lua','Inventory.lua','Professions.lua','Crafting.lua','Supplies.lua','Guide.lua','Data/Instances.lua','Data/InstancesRaids.lua','Instances.lua','Companion.lua','tests/wow_mock.lua','Skin.lua','Core.lua','UI.lua','Minimap.lua']:
    load(fresh,fresh_addon,path)
fresh.globals().TestAddon=fresh_addon
fresh.globals().HardcoreBuddyDB=fresh.table_from(saved,recursive=True)
fresh.globals().HardcoreBuddyCharacterDB=fresh.table_from(saved_character,recursive=True)
fresh.globals().MOCK.Fire('ADDON_LOADED','HardcoreBuddy')
equal(saved['profile'],fresh_addon['db']['profile'],'relog profile')
equal(saved_character,fresh_addon['characterDB'],'relog carry targets')
assert saved['minimapAngle']==fresh_addon['db']['minimapAngle']
assert fresh_addon['window']['IsShown'](fresh_addon['window']) == saved['window']['visible']
fresh.globals().MOCK['class']='DEATHKNIGHT'
fresh_addon['SetProfile'](fresh_addon,'mode','live')
assert fresh_addon['GetContext'](fresh_addon)['liveUnavailable']
print('PASS: SavedVariables restore into a fresh Lua runtime; unsupported live class has explicit fallback.')

# Existing schema-1 preview profiles migrate once without losing preview choices.
fresh.globals().HardcoreBuddyDB=fresh.table_from(dict(schema=1,profile=dict(characterClass='Mage',level=45,detailed=True,mode='preview'),window={}),recursive=True)
fresh.globals().MOCK['class']='PRIEST'
fresh.globals().MOCK['level']=27
fresh_addon['Initialize'](fresh_addon)
assert fresh_addon['db']['schema']==2 and fresh_addon['db']['profile']['mode']=='live'
assert fresh_addon['db']['profile']['characterClass']=='Mage' and fresh_addon['db']['profile']['level']==45
context=fresh_addon['GetContext'](fresh_addon)
assert context['characterClass']=='Priest' and context['level']==27 and context['detailed']
fresh.globals().MOCK.Click(fresh_addon['window']['mode'])
assert fresh_addon['GetContext'](fresh_addon)['characterClass']=='Mage', 'Preview button must restore saved class'
assert fresh_addon['GetContext'](fresh_addon)['level']==45, 'Preview button must restore saved level'
fresh_addon['Initialize'](fresh_addon)
assert fresh_addon['GetContext'](fresh_addon)['characterClass']=='Mage'
assert fresh_addon['db']['profile']['mode']=='preview'
print('PASS: Existing profiles migrate to automatic class/level detection; subsequent explicit Preview choices persist.')
fresh.globals().HardcoreBuddyCharacterDB=fresh.table()
fresh_addon['Initialize'](fresh_addon)
assert len(fresh_addon['characterDB']['targets'])==0 and len(fresh_addon['characterDB']['ranks'])==0
print('PASS: A new character has independent carry targets and profession-rank selections.')
