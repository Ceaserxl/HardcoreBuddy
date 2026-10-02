"""Extract factual supply/vendor relationships; no dependency on Questie in-game."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_map_data import ROOT, CACHE, MAPS, lua
from lupa.lua51 import LuaRuntime

runtime=LuaRuntime(unpack_returned_tuples=True)
addon=runtime.table(Data=runtime.table())
for filename in ('Data/Items.lua','Data/Scrolls.lua','Data/ProfessionProgression.lua','Ammunition.lua'):
    runtime.execute((ROOT/filename).read_text(encoding='utf-8'),'HardcoreBuddy',addon)
ids=set()
def collect(table):
    for key,value in table.items():
        if key=='itemId' and isinstance(value,(int,float)): ids.add(int(value))
        elif hasattr(value,'items'): collect(value)
collect(addon)
items=runtime.execute((CACHE/'source-questie-items.lua').read_text(encoding='utf-8').split('QuestieDB.itemData = [[',1)[1].rsplit(']]',1)[0])
npcs=runtime.execute((CACHE/'source-questie.html').read_text(encoding='utf-8').split('QuestieDB.npcData = [[',1)[1].rsplit(']]',1)[0])
vendors={}; sold_by={}
for item_id in sorted(ids):
    row=items[item_id]
    for _,npc_id in (row[14].items() if row and row[14] else []):
        npc=npcs[npc_id]
        if not npc or not npc[7]: continue
        locations={}
        for map_id,area in MAPS.items():
            if npc[7][area]:
                locations[map_id]=[[xy[1],xy[2]] for _,xy in npc[7][area].items() if 0<=xy[1]<=100 and 0<=xy[2]<=100]
        if not locations: continue
        has_path=bool(npc[8] and any(True for _ in npc[8].items()))
        points=sum(len(points) for points in locations.values())
        movement='roaming' if has_path else 'stationary' if points==1 else 'unknown'
        vendors[npc_id]={'name':npc[1],'faction':npc[13] or 'AH','locations':locations,'movement':movement}
        sold_by.setdefault(item_id,[]).append(npc_id)
out=['-- Factual Classic vendors from Questie v10.0.0. See docs/vendor-services.md.','local _,A=...','A.Data.SupplyVendors={']
for ident,data in sorted(vendors.items()): out.append(f'[{ident}]={lua(data)},')
out+=['}','A.Data.SupplySoldBy={']
for ident,data in sorted(sold_by.items()): out.append(f'[{ident}]={lua(sorted(set(data)))},')
out+=['}','']
(ROOT/'Data/SupplyVendors.lua').write_text('\n'.join(out),encoding='utf-8')
print(len(ids),'supply IDs;',len(sold_by),'with known outdoor/city vendors;',len(vendors),'vendors')
