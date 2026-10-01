"""Refresh factual Classic zone/NPC locations from Wowhead. Offline build tool only."""
import concurrent.futures
import json
from pathlib import Path
import re
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.release/map-research'
CACHE.mkdir(parents=True, exist_ok=True)
MAPS = {1411:14,1412:215,1413:17,1416:36,1417:45,1418:3,1419:4,1420:85,
    1421:130,1422:28,1423:139,1424:267,1425:47,1426:1,1427:51,1428:46,1429:12,
    1430:41,1431:10,1432:38,1433:44,1434:33,1435:8,1436:40,1437:11,1438:141,
    1439:148,1440:331,1441:400,1442:406,1443:405,1444:357,1445:15,1446:440,
    1447:16,1448:361,1449:490,1450:493,1451:1377,1452:618,
    1453:1519,1454:1637,1455:1537,1456:1638,1457:1657,1458:1497}
DRAGON_GUIDE='https://www.wowhead.com/classic/guide/dragons-of-nightmare-emeriss-lethono-taerar-ysondre-classic-wow'
# Documented portal areas; any of the four dragons can appear at each portal.
DRAGON_PORTALS={1431:[[46.5,36.5]],1425:[[63,22]],1444:[[51,10]],1440:[[93.5,37]]}
# Editorial warning reasons. NPC identity, rank, level, reaction and coordinates
# come from the Classic database; never use SoD replacements with different IDs.
DANGER_NAMES = {
    'Defias Pillager':'Fireball caster. Break line of sight and avoid fighting several at once.',
    'Defias Trapper':'Nets can stop your escape. Keep a clear route out.',
    'Defias Conjurer':'Caster with nearby enemies. Isolate the pull and keep a retreat open.',
    'Burning Blade Fanatic':'Cave pulls leave little room to escape. Clear the entrance first.',
    'Burning Blade Apprentice':'Caster in a crowded area. Avoid additional pulls.',
    'Burning Blade Warlock':'Caster in a crowded area. Watch for nearby demons.',
    'Voidwalker Minion':'Watch for a nearby caster before engaging.',
    'Dust Devil':'Higher-level roaming enemy among low-level quests. Check its level.',
    'Dalaran Summoner':'Caster. Check for additional summoned enemies before pulling.',
    'Dalaran Theurgist':'Caster in a crowded area. Avoid additional pulls.',
    'Murloc Oracle':'Caster in a dense camp. Keep an escape route open.',
    'Murloc Tidecaller':'Caster in a dense camp. Keep an escape route open.',
    'Nightbane Shadow Weaver':'Caster with nearby worgen. Avoid additional pulls.',
    'Dark Iron Rifleman':'Ranged enemy in a crowded area. Clear a retreat before pulling.',
    'Bloodsail Warlock':'Caster in a crowded camp. Avoid additional pulls.',
    'Bloodsail Mage':'Caster in a crowded camp. Break line of sight to isolate it.',
    'Deadwind Warlock':'High-level caster. Avoid this area while leveling through nearby zones.',
    'Deadwind Ogre Mage':'High-level caster. Avoid additional pulls.',
    'Scarlet Mage':'Caster in a dense camp. Avoid additional pulls.',
    'Scarlet Invoker':'Caster in a dense camp. Avoid additional pulls.',
    'Lost One Hunter':'Ranged enemy. Keep a clear escape route.',
    'Lost One Shadowhunter':'Ranged enemy in a dense camp. Avoid additional pulls.',
    'Dark Iron Shadowcaster':'Caster in a dense camp. Avoid additional pulls.',
    'Dustbelcher Shaman':'Caster in a crowded camp. Avoid additional pulls.',
}
DECODER = json.JSONDecoder()

def fetch(kind, ident, url):
    path = CACHE / f'{kind}-{ident}.html'
    if path.exists():
        return path.read_text(encoding='utf-8')
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=35) as response:
                value = response.read().decode('utf-8')
            path.write_text(value, encoding='utf-8')
            return value
        except Exception:
            if attempt == 2: raise
            time.sleep(2 + attempt)

def listview(page, template):
    embedded = re.search(r'<script[^>]+id="data.page.listPage.listviews"[^>]*>(.*?)</script>',page,re.S)
    if embedded:
        return next(x['data'] for x in json.loads(embedded[1]) if x['template']==template)
    for line in page.splitlines():
        if f"template: '{template}'" in line and 'data:' in line:
            return DECODER.raw_decode(line.split('data:',1)[1].lstrip())[0]
    raise ValueError(f'Missing {template} listview')

def lua(value):
    if value is None: return 'nil'
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,bool): return 'true' if value else 'false'
    if isinstance(value,(int,float)): return str(value)
    if isinstance(value,list): return '{'+','.join(lua(x) for x in value)+'}'
    if isinstance(value,dict): return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'
    raise TypeError(value)

def main():
    from lupa.lua51 import LuaRuntime
    source=fetch('source','questie','https://raw.githubusercontent.com/Questie/Questie/v10.0.0/Database/Classic/classicNpcDB.lua')
    classic=LuaRuntime().execute(source.split('QuestieDB.npcData = [[',1)[1].rsplit(']]',1)[0])
    dangers={ident:DANGER_NAMES[row[1]] for ident,row in classic.items() if row[1] in DANGER_NAMES}
    zones={}
    for continent in ('eastern-kingdoms','kalimdor'):
        page=fetch('zones',continent,'https://www.wowhead.com/classic/zones/'+continent+'?classic')
        zones.update({z['id']:z for z in listview(page,'zone')})
    candidates={}; selected={}; audit={'zones':{},'missingLocations':[], 'npcSources':{}}
    def zone_job(pair):
        map_id,area=pair
        page=fetch('zone',area,f'https://www.wowhead.com/classic/zone={area}?classic')
        return map_id,area,listview(page,'npc')
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for map_id,area,npcs in pool.map(zone_job,MAPS.items()):
            cities={1519:'Stormwind City',1637:'Orgrimmar',1537:'Ironforge',1638:'Thunder Bluff',1657:'Darnassus',1497:'Undercity'}
            z=zones.get(area,{'name':cities[area]} if area in cities else {})
            if not z: raise ValueError(f'Zone {area} absent from Classic lists')
            selected[map_id]={'name':z['name'],'area':area,'min':z.get('minlevel',0),'max':z.get('maxlevel',0),'npcs':[]}
            audit['zones'][str(map_id)]={'area':area,'url':f'https://www.wowhead.com/classic/zone={area}?classic','npcsReviewed':len(npcs)}
            for n in npcs:
                if not classic[n['id']] or all(r==1 for r in n.get('react',[1,1])): continue
                if int(classic[n['id']][15] or 0) & (16|128|8192): continue
                if n.get('classification',0) not in (1,2,3,4) and n['id'] not in dangers: continue
                candidates[n['id']]=n
                selected[map_id]['npcs'].append(n['id'])
            print('Zone',map_id,z['name'],len(selected[map_id]['npcs']),flush=True)
    # Zone lists can substitute Season of Discovery IDs for original Classic
    # creatures. Recover every qualifying outdoor Classic record independently.
    for ident,r in classic.items():
        if r[13]=='AH' or int(r[15] or 0)&(16|128|8192): continue
        if r[6] not in (1,2,3,4) and ident not in dangers: continue
        spawns=r[7]
        maps=[m for m,area in MAPS.items() if spawns and spawns[area]]
        if ident in (14887,14888,14889,14890): maps=list(DRAGON_PORTALS)
        if not maps and ident not in candidates: continue
        n=candidates.setdefault(ident,{'id':ident,'react':[1 if r[13]=='A' else -1,1 if r[13]=='H' else -1]})
        n.update(name=r[1],minlevel=r[4],maxlevel=r[5],classification=r[6])
        for m in maps: selected[m]['npcs'].append(ident)
    results={}
    def npc_job(pair):
        ident,n=pair
        # Wowhead zone lists were reviewed for every zone. Reuse the available
        # NPC-page cache; supplement missing map coordinates with Classic data.
        cached=CACHE/f'npc-{ident}.html'
        page=cached.read_text(encoding='utf-8') if cached.exists() else ''
        match=re.search(r'var g_mapperData\s*=\s*',page)
        locations=DECODER.raw_decode(page[match.end():])[0] if match else {}
        coords={}
        for map_id,area in MAPS.items():
            if isinstance(locations,dict):
                for group in locations.get(str(area),[]):
                    for xy in group.get('coords',[]):
                        if len(xy)>=2 and all(0<=v<=100 for v in xy[:2]): coords.setdefault(map_id,[]).append(xy[:2])
            if map_id not in coords:
                spawns=classic[ident][7]
                if spawns and spawns[area]:
                    coords[map_id]=[[point[1],point[2]] for _,point in spawns[area].items()
                        if 0<=point[1]<=100 and 0<=point[2]<=100]
        n['coordinateSource']='Wowhead + Questie Classic' if cached.exists() else 'Questie Classic'
        if ident in (14887,14888,14889,14890):
            coords=DRAGON_PORTALS
            n['coordinateSource']='Wowhead Dragons of Nightmare guide'
        return ident,n,coords
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for count,(ident,n,coords) in enumerate(pool.map(npc_job,sorted(candidates.items())),1):
            kind={1:'elite',2:'rare',3:'boss',4:'rare'}.get(n.get('classification'),'danger')
            entry={'name':n['name'],'kind':kind,'min':n.get('minlevel',0),'max':n.get('maxlevel',0),
                'react':n.get('react',[-1,-1]),'locations':{},'source':n['coordinateSource']}
            if ident in dangers: entry['note']=dangers[ident]
            if ident in (14887,14888,14889,14890): entry['note']='Possible portal location; the dragon at each portal varies.'
            for map_id,points in coords.items():
                # Retain representative observed locations, not an invented centroid.
                cells={}
                for x,y in points: cells.setdefault((int(x/5),int(y/5)),[x,y])
                values=list(cells.values())
                if len(values)>12: values=[values[round(i*(len(values)-1)/11)] for i in range(12)]
                entry['locations'][map_id]=values
                if ident not in selected[map_id]['npcs']: selected[map_id]['npcs'].append(ident)
            if not coords: audit['missingLocations'].append(ident)
            results[ident]=entry
            audit['npcSources'][str(ident)]={'reference':f'https://www.wowhead.com/classic/npc={ident}?classic',
                'pageCached':(CACHE/f'npc-{ident}.html').exists(),'coordinates':n['coordinateSource']}
            if count%40==0: print('NPCs',count,'/',len(candidates),flush=True)
    out=['-- Generated factual Classic Era zone and NPC data. See docs/map-data.md.','local _,A=...','A.Data.MapZones={']
    for map_id,z in sorted(selected.items()):
        z['npcs']=sorted(set(z['npcs']))
        out.append(f'[{map_id}]='+lua(z)+',')
    out+=['}','A.Data.MapNPCs={']
    for ident,n in sorted(results.items()): out.append(f'[{ident}]='+lua(n)+',')
    out+=['}','']
    (ROOT/'Data/MapNPCs.lua').write_text('\n'.join(out),encoding='utf-8')
    audit['supplementalDatabase']='https://github.com/Questie/Questie/blob/v10.0.0/Database/Classic/classicNpcDB.lua'
    audit['worldBossPortals']=DRAGON_GUIDE
    (ROOT/'docs/map-data-audit.json').write_text(json.dumps(audit,indent=2)+'\n',encoding='utf-8')
    print('DONE',len(selected),'zones',len(results),'NPCs;',len(audit['missingLocations']),'without mapped coordinates',flush=True)

if __name__=='__main__': main()
