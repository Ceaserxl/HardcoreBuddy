"""Offline provenance audit of every published NPC pin."""
import sys
from pathlib import Path
from unittest.mock import patch
from lupa.lua51 import LuaRuntime
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'scripts'))
import build_map_data as build
runtime=LuaRuntime()
if not (build.CACHE/'source-questie.html').is_file():
    print('SKIP: coordinate provenance needs the optional ignored research HTML cache; shipping data is checked by run_map_advisor.')
    raise SystemExit(0)
source=(build.CACHE/'source-questie.html').read_text(encoding='utf-8')
def cached(kind,ident,url):
    return (build.CACHE/f'{kind}-{ident}.html').read_text(encoding='utf-8')
with patch.object(build,'fetch',cached):
    classic=build.corrected_classic(runtime,source)
addon=runtime.table(); addon.Data=runtime.table()
runtime.execute((build.ROOT/'Data/MapNPCs.lua').read_text(encoding='utf-8'),'HardcoreBuddy',addon)
count=0
for ident,npc in addon.Data.MapNPCs.items():
    expected=build.DRAGON_PORTALS if ident in (14887,14888,14889,14890) else build.spawn_coordinates(classic[ident])
    assert set(npc.locations.keys())==set(expected),(ident,'Missing or foreign spawn zone')
    for map_id,points in npc.locations.items():
        assert len(points)<=12
        for _,point in points.items():
            assert (point[1],point[2]) in {tuple(p) for p in expected[map_id]},(ident,map_id,'Unsupported coordinate')
            count+=1
    if expected:
        membership={map_id for map_id,zone in addon.Data.MapZones.items() if ident in list(zone.npcs.values())}
        assert membership==set(expected),(ident,'Zone lists include unsupported sightings')
assert build.coordinate_pairs(runtime.eval('{{{10,20},{30,40}},{{50,60},{-1,-1}}}'))==[[10,20],[30,40],[50,60]]
# Wowhead sightings remain evidence for the audit, never authoritative pin input.
assert build.observed_coordinates('var g_mapperData = {"12":[{"coords":[[50,60],[150,60]]}]}')[1429]==[[50,60]]
assert classic[412][7][10] is not None,'Stitches correction must survive'
print(f'PASS: all {count} published pins use documented spawns/patrols or reviewed dragon portals; nested routes, unknown coordinates and zone memberships validated.')
