"""Current full-TOC core contracts and unchanged historical profession references."""
import hashlib
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

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


lua, addon = boot()
P, G = addon['Planner'], addon['Guide']
equal(dict(characterClass='Hunter', level=1, detailed=False, mode='live'), P.NormalizeProfile(None))
equal(dict(characterClass='Hunter', level=1, detailed=False, mode='live'),
      P.NormalizeProfile(lua.table_from(dict(characterClass='Death Knight', level=900, detailed='yes', mode='other'))))
equal(dict(characterClass='Warrior', level=60, detailed=True, mode='live'),
      P.NormalizeProfile(lua.table_from(dict(characterClass='Warrior', level=60, detailed=True, mode='live'))))
fixtures = json.loads((ROOT / 'tests/website-fixtures.json').read_text(encoding='utf-8'))
# Old carry rows are archived provenance, not an authority for today's catalog.
# Keep unaffected hunter/warlock/quiver reference parity checks.
def without_external_metadata(value):
    if isinstance(value, dict):
        return {k: without_external_metadata(v) for k, v in value.items()
                if k not in ('reference', 'classificationSource')}
    if isinstance(value, list): return [without_external_metadata(v) for v in value]
    return value
fixtures = without_external_metadata(fixtures)
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

lua.execute("""
local A=TestAddon
local checks=0
for _,class in ipairs(A.Planner.classes) do for level=1,60 do
 local c={characterClass=class,level=level,mode="preview",faction="Alliance"}
 local rows=A.Supplies.Build(c,{filter="All"}); local seen={}
 for _,r in ipairs(rows) do
  assert(not seen[r.itemId],"One effective row per exact item")
  seen[r.itemId]=true
  assert(A.Planner.MatchesClass(r.item,class),"Class filtering")
  assert(r.item.level<=level,"Use level")
  assert(r.target>=0 and r.refillThreshold>=0,"Valid quantities")
  if class=="Rogue" or class=="Warrior" then assert(r.family~="drink","No non-mana water") end
  checks=checks+1
 end
end end
print("PASS: "..checks.." current full-TOC supply records across 540 class/level contexts.")
""")
for rel, expected in json.loads((ROOT/'reference/manifest.json').read_text()).items():
    data=(ROOT/rel).read_bytes()
    # The archived hashes used Windows CRLF. Git checks these text fixtures out
    # as LF on Linux; only normalize line endings, never JSON content or spacing.
    canonical=data.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')
    assert expected in (hashlib.sha256(data).hexdigest(),hashlib.sha256(canonical).hexdigest()),rel
toc=(ROOT/'HardcoreBuddy.toc').read_text()
assert 'Dependencies:' not in toc and 'OptionalDeps:' not in toc
for line in toc.splitlines():
    if line and not line.startswith('#'): assert (ROOT/line.replace(chr(92),'/')).is_file(),line
print('PASS: Archived reference checksums and standalone full TOC.')

def plain(table):
    return {k:plain(v) if hasattr(v,'items') else v for k,v in table.items()}
lua.execute('TestAddon.characterDB.targets[117]=23; TestAddon.characterDB.refillThresholds[117]=6')
saved=plain(addon.db); saved_character=plain(addon.characterDB)
fresh,fresh_addon=boot()
fresh.globals().HardcoreBuddyDB=fresh.table_from(saved,recursive=True)
fresh.globals().HardcoreBuddyCharacterDB=fresh.table_from(saved_character,recursive=True)
fresh_addon.Initialize(fresh_addon)
assert fresh_addon.characterDB.targets[117]==23
assert fresh_addon.characterDB.refillThresholds[117]==6
print('PASS: Character quantities persist into a fresh full-TOC runtime.')

# Retain the API and persistence contracts from the original core suite. The
# renderer replaces Professions.Read with a layout fixture, so reload that module
# in a separate runtime before exercising the real localized skill reader.
for name in ('supplies', 'professions', 'professionprogression'):
    reader_lua, reader_addon = boot()
    if name != 'supplies':
        reader_lua.execute((ROOT / 'Professions.lua').read_text(encoding='utf-8'), 'HardcoreBuddy', reader_addon)
    reader_lua.execute((ROOT / 'tests' / (name + '.lua')).read_text(encoding='utf-8'))

fresh.globals().MOCK['class'] = 'DEATHKNIGHT'
fresh_addon.SetProfile(fresh_addon, 'mode', 'live')
assert fresh_addon.GetContext(fresh_addon)['liveUnavailable']
fresh.globals().HardcoreBuddyDB = fresh.table_from(dict(schema=1,
    profile=dict(characterClass='Mage', level=45, detailed=True, mode='preview'), window={}), recursive=True)
fresh.globals().MOCK['class'], fresh.globals().MOCK['level'] = 'PRIEST', 27
fresh_addon.Initialize(fresh_addon)
assert fresh_addon.db.schema == 2 and fresh_addon.db.profile.mode == 'live'
assert fresh_addon.db.profile.characterClass == 'Mage' and fresh_addon.db.profile.level == 45
context = fresh_addon.GetContext(fresh_addon)
assert context.characterClass == 'Priest' and context.level == 27 and context.detailed
fresh_addon.SetProfile(fresh_addon, 'mode', 'preview')
assert fresh_addon.GetContext(fresh_addon).characterClass == 'Mage'
assert fresh_addon.GetContext(fresh_addon).level == 45
fresh_addon.Initialize(fresh_addon)
assert fresh_addon.db.profile.mode == 'preview'
fresh.globals().HardcoreBuddyCharacterDB = fresh.table()
fresh_addon.Initialize(fresh_addon)
assert len(fresh_addon.characterDB.targets) == 0 and len(fresh_addon.characterDB.ranks) == 0
print('PASS: Profile normalization, unsupported live classes, migration and independent new-character targets.')
