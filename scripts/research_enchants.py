"""Cache Classic Era enchant spell facts from Wowhead; stop on access errors."""
import json,re,time,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
CACHE=ROOT/'.release/enchant-research';CACHE.mkdir(parents=True,exist_ok=True)
def fetch(url,path):
 if path.exists(): return path.read_text(encoding='utf8')
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'Mozilla/5.0'}),timeout=25) as r: text=r.read().decode('utf8')
 if 'WH.Gatherer' not in text: raise RuntimeError('Unexpected page, research stopped')
 path.write_text(text,encoding='utf8');time.sleep(.5);return text
if __name__=='__main__':
 source=ROOT/'.release/enchanting.html'
 text=source.read_text(encoding='utf8') if source.exists() else fetch('https://www.wowhead.com/classic/spells/professions/enchanting?filter=16;1;0',CACHE/'list.html')
 raw=text.split('var listviewspells = ',1)[1].split(';',1)[0]
 rows=json.loads(re.sub(r'([,{])(\w+):',r'\1"\2":',raw))
 rows=[r for r in rows if r['name'].startswith('Enchant ') and r['id']<30000]
 (CACHE/'list.json').write_text(json.dumps(rows,indent=2),encoding='utf8')
 for i,row in enumerate(rows):
  print(f'{i+1}/{len(rows)} {row["id"]} {row["name"]}',flush=True)
  try: fetch(f'https://www.wowhead.com/classic/spell={row["id"]}?classic',CACHE/f'{row["id"]}.html')
  except Exception as e: print('STOP:',e,flush=True);break
