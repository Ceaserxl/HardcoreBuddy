"""Resume missing Wowhead Classic NPC pages, stopping on the first blocked request."""
import argparse
from datetime import datetime, timezone
import json
import math
import re
import time
import urllib.error
import urllib.request
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map_data import ROOT, CACHE, MAPS, DECODER

PROGRESS = ROOT / 'docs/map-research-progress.json'

def coordinates(page):
    match = re.search(r'var g_mapperData\s*=\s*', page)
    if not match:
        return False
    data = DECODER.raw_decode(page[match.end():])[0]
    return isinstance(data, dict) and any(
        len(xy) >= 2 and all(isinstance(v, (int, float)) and 0 <= v <= 100 for v in xy[:2])
        for area in MAPS.values() for group in data.get(str(area), []) for xy in group.get('coords', []))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--limit', type=int, default=10000)
    parser.add_argument('--delay', type=float, default=2, help='Seconds between requests (default: 2).')
    args = parser.parse_args()
    if not math.isfinite(args.delay) or args.delay < 0:
        parser.error('--delay must be a finite, non-negative number')
    audit = json.loads((ROOT/'docs/map-data-audit.json').read_text())
    state = json.loads(PROGRESS.read_text()) if PROGRESS.exists() else {}
    no_map = set(state.get('pagesWithoutCoordinates', []))
    candidates = sorted(int(i) for i, n in audit['npcSources'].items()
                        if n['coordinates'] != 'Wowhead Dragons of Nightmare guide')
    def pending():
        return [i for i in candidates if not (CACHE/f'npc-{i}.html').exists()
                or not coordinates((CACHE/f'npc-{i}.html').read_text(encoding='utf-8'))]
    state.update(updatedAt=datetime.now(timezone.utc).isoformat(), fetchedThisRun=[], stopReason='Completed queue', blockedNPC=None)
    state.pop('accessRetry', None)
    state['requestDelaySeconds'] = args.delay
    queue = [i for i in pending() if i not in no_map]
    def save():
        state['pagesWithoutCoordinates'] = sorted(no_map)
        state['pendingNPCs'] = pending()
        state['remaining'] = len(state['pendingNPCs'])
        state['verifiedNPCPages'] = len(candidates)-state['remaining']
        state['updatedAt'] = datetime.now(timezone.utc).isoformat()
        state['resumeCommand'] = f'python scripts/resume_map_research.py --delay {args.delay:g}'
        PROGRESS.write_text(json.dumps(state, indent=2)+'\n', encoding='utf-8')
    for i, ident in enumerate(queue):
        if i >= args.limit:
            state['stopReason'] = 'Batch limit reached'; break
        url = f'https://www.wowhead.com/classic/npc={ident}?classic'
        print(f'Requesting {ident}: {url}', flush=True)
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=20) as response:
                page = response.read().decode('utf-8')
            title = re.search(r'<title>(.*?)</title>', page, re.I|re.S)
            if title and re.search(r'just a moment|access denied|captcha|attention required', title[1], re.I):
                raise RuntimeError('Access challenge; stopped without bypassing it')
            if not coordinates(page):
                no_map.add(ident)
            else:
                (CACHE/f'npc-{ident}.html').write_text(page, encoding='utf-8')
                state['fetchedThisRun'].append(ident)
        except (urllib.error.URLError, TimeoutError, RuntimeError, ValueError) as exc:
            state['stopReason'] = str(exc); state['blockedNPC'] = ident; break
        save()
        time.sleep(args.delay)
    save()
    print(json.dumps({k:state[k] for k in ('stopReason','blockedNPC','remaining','verifiedNPCPages','fetchedThisRun')}, indent=2), flush=True)

if __name__ == '__main__':
    main()
