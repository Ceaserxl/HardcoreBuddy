"""Expand reviewed Classic vendor food from cached Questie facts/Wowhead tooltips."""
import html
import json
import re
import sys
import time
import urllib.request
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from build_map_data import ROOT, CACHE
from lupa.lua51 import LuaRuntime

ids=[4540,4541,4542,4544,4601,8950,2070,414,422,1707,3927,8932,
     787,4592,4593,4594,21552,8957,4536,4537,4538,4539,4602,8953,
     4604,4605,4606,4607,4608,8948,16166,16167,16168,16169,16170,
     16171,21030,21031,21033]
runtime=LuaRuntime(unpack_returned_tuples=True)
items=runtime.execute((CACHE/'source-questie-items.lua').read_text(encoding='utf-8').split('QuestieDB.itemData = [[',1)[1].rsplit(']]',1)[0])
path=ROOT/'reference/recommendations.json'
data=json.loads(path.read_text(encoding='utf-8'))
by_id={row['itemId']:row for row in data['items']}
for row in data['items']:
    if row['family']=='drink' or row['family']=='recovery' and not row.get('alternative'):
        row['vendorFood']=True
        row['classes']=['All']
for ident in ids:
    fact=items[ident]
    assert fact and fact[14], f'No vendor evidence for {ident}'
    cache=CACHE/f'vendor-food-{ident}.json'
    if not cache.exists():
        with urllib.request.urlopen(f'https://nether.wowhead.com/classic/tooltip/item/{ident}',timeout=30) as response:
            payload=response.read()
        json.loads(payload)
        cache.write_bytes(payload)
        time.sleep(2)
    tooltip=json.loads(cache.read_text(encoding='utf-8'))
    effect=re.search(r'<!--useEffect:0:1-->(.*?)<!--useEffect:1-->',tooltip['tooltip'])
    assert effect, ident
    description=html.unescape(re.sub('<[^>]+>','',effect[1])).replace('\xa0',' ')
    row=by_id.get(ident)
    if row is None:
        row={'id':'classic-'+re.sub(r'[^a-z0-9]+','-',fact[1].lower()).strip('-'),
             'itemId':ident,'name':fact[1],'level':fact[10],'family':'recovery',
             'group':'Food & drink','alternative':True,'binding':False}
        data['items'].append(row)
    row.update(classes=['All'],vendorFood=True,ease=0,
        detail='Use: '+description,icon='/images/hcclassic/'+tooltip['icon']+'.jpg',
        short='Health between fights',
        route='Buy from a food vendor that stocks this item.',
        caution='Recovery food has no Well Fed buff. Eat after reaching safety.',
        reference=f'https://www.wowhead.com/classic/item={ident}',verifiedOn='2026-10-02')
path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Reviewed',len(ids),'vendor food choices; all vendor food and drink available to every class.')
