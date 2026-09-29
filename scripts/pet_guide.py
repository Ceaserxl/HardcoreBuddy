"""Build an offline factual pet guide index. Development only; requires BeautifulSoup.

Uses cached source pages unless --refresh is passed. No images or guide articles
are redistributed in runtime data. Family pages include unavailable appearances.
"""
import concurrent.futures
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / 'reference/pet-guide'
BASE = 'https://www.wow-petopia.com/classic/'
CACHE.mkdir(exist_ok=True)
audit = json.loads((ROOT/'reference/research/companion-source-records.json').read_text())
sources = []

def page(name, url):
    path = CACHE / (name+'.html')
    if not path.exists() or '--refresh' in sys.argv:
        path.write_bytes(urllib.request.urlopen(BASE+url, timeout=30).read())
    raw = path.read_bytes()
    return raw.decode('utf-8'), dict(url=BASE+url, sha256=hashlib.sha256(raw).hexdigest())

jobs = [('family-'+f['id'], 'family.php?id='+f['id']) for f in audit['families']]
jobs += [(n,n+'.php') for n in ['abilities','attackspeed','training','differences','casterpets']]
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    pages = list(pool.map(lambda args: page(*args), jobs))
raws = {job[0]:result[0] for job,result in zip(jobs,pages)}
sources = [result[1] for result in pages]
pets, looks = {}, []
for family in audit['families']:
    raw = raws['family-'+family['id']]
    soup = BeautifulSoup(raw,'html.parser')
    tips = dict(re.findall(r'tooltips\.(\w+)\s*=\s*"(.*?)";', raw))
    for link in soup.select('a[href^="look.php?id="]'):
        lookid = link['href'].split('=')[1]
        if any(x['id']==lookid and x['family']==family['id'] for x in looks): continue
        table = BeautifulSoup(tips.get(link.get('id'),''),'html.parser')
        title = table.find('th')
        appearance = title.get_text(' ',strip=True) if title else (link.img.get('alt','') if link.img else lookid)
        entries = []
        for row in table.select('tr'):
            name, lv, zone = row.select_one('.pettablename'),row.select_one('.level'),row.select_one('.zone')
            if not name or not lv: continue
            name = name.get_text(' ',strip=True); level=lv.get_text(' ',strip=True)
            levels = re.match(r'(\d+)(?:-(\d+))?',level)
            tame = row.find('img',alt='Can Be Tamed') is not None
            key = (name.lower(),family['id'])
            pet = pets.setdefault(key,dict(name=name,family=family['id'],zone=zone.get_text(' ',strip=True) if zone else '',
                level=level,minLevel=int(levels[1]) if levels else 0,maxLevel=int(levels[2] or levels[1]) if levels else 0,
                classification=re.sub(r'^\d+(?:-\d+)?\s*','',level) or 'Normal',tameable=tame,looks=[],abilities=[]))
            pet['tameable'] = pet['tameable'] or tame
            if appearance not in pet['looks']: pet['looks'].append(appearance)
            entries.append(name)
        looks.append(dict(id=lookid,name=appearance,family=family['id'],pets=entries,url=BASE+link['href']))

speed = BeautifulSoup(raws['attackspeed'],'html.parser')
for h in speed.select('[id^="attackspeed_"]'):
    for li in h.find_next('ul').select('li'):
        a=li.find('a'); name=a.get_text(' ',strip=True)
        for (key,_),pet in pets.items():
            if key == name.lower():
                pet['attackSpeed']=float(h['id'].split('_')[1]); pet['npcId']=int(a['href'].split('npc=')[1])

ability_page=BeautifulSoup(raws['abilities'],'html.parser')
for ability in audit['abilities']:
    for rank in ability['ranks']:
        el=ability_page.find(id=ability['id']+str(rank['rank']))
        desc=el.select_one('.abilityrankdesc') if el else None
        rank['effect']=desc.get_text(' ',strip=True) if desc else ''
        for source in rank['sources']:
            for (name,_),pet in pets.items():
                if name==source['name'].lower():
                    pet['npcId']=source['npcId']
                    learned=ability['name']+' '+str(rank['rank'])
                    if learned not in pet['abilities']: pet['abilities'].append(learned)
                    source['classification']=pet['classification']
    ability['url']=BASE+'abilities.php#'+ability['id']

historical=BeautifulSoup(raws['casterpets'],'html.parser')
caster_ids={int(a['href'].split('npc=')[1]) for a in historical.select('a[href*="npc="]')}
for pet in pets.values():
    pet['historicalCaster']=pet.get('npcId') in caster_ids
    pet['url']=BASE+'family.php?id='+pet['family']
for look in looks:
    look['tameable']=any(p['tameable'] and p['family']==look['family'] and p['name'] in look['pets'] for p in pets.values())

data=dict(checkedOn='2026-09-27',families=audit['families'],abilities=audit['abilities'],
          pets=sorted(pets.values(),key=lambda p:(p['name'].lower(),p['family'])),looks=looks,sources=sources)
assert len(data['families'])==17 and len(data['abilities'])==21
assert sum(len(a['ranks']) for a in data['abilities'])==111
assert len(data['pets'])>400 and len(looks)>100
assert all(r['effect'] for a in data['abilities'] for r in a['ranks'])
(ROOT/'reference/pet-guide.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Pet Guide:',len(data['pets']),'creatures,',len(looks),'appearances, 17 families, 21 abilities / 111 ranks.')
