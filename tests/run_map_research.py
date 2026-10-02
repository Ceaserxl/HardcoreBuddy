"""Offline checks for paced, cache-preserving research and access-error stops."""
import io
import json
import sys
import tempfile
import urllib.error
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
import resume_map_research as research

with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    cache = root / 'cache'
    cache.mkdir()
    (root / 'docs').mkdir()
    progress = root / 'docs/map-research-progress.json'
    (root / 'docs/map-data-audit.json').write_text(json.dumps({
        'npcSources': {str(i): {'coordinates': 'Questie Classic'} for i in (1, 2, 3, 4)}
    }))
    area = next(iter(research.MAPS.values()))
    page = 'var g_mapperData = ' + json.dumps({str(area): [{'coords': [[20, 30]]}]}) + ';'
    (cache / 'npc-1.html').write_text(page)
    calls, sleeps = [], []

    def fetch(request, **kwargs):
        calls.append(request.full_url)
        if 'npc=3?' in request.full_url:
            raise urllib.error.HTTPError(request.full_url, 403, 'Forbidden', {}, None)
        return io.BytesIO(page.encode())

    with patch.object(research, 'ROOT', root), patch.object(research, 'CACHE', cache), \
         patch.object(research, 'PROGRESS', progress), \
         patch.object(research.urllib.request, 'urlopen', fetch), \
         patch.object(research.time, 'sleep', sleeps.append), \
         patch.object(sys, 'argv', ['resume_map_research.py']), redirect_stdout(io.StringIO()):
        research.main()
        state = json.loads(progress.read_text())
        assert sleeps == [2, 30], 'Default delay is two seconds between requests'
        assert len(calls) == 3 and 'npc=2?' in calls[0] and 'npc=3?' in calls[1] and calls[1]==calls[2]
        assert state['blockedNPC'] == 3 and state['remaining'] == 2
        assert state['fetchedThisRun'] == [2] and state['requestDelaySeconds'] == 2
        assert state['resumeCommand'].endswith('--delay 2')
        assert (cache / 'npc-1.html').read_text() == page
        assert not (cache / 'npc-3.html').exists() and not (cache / 'npc-4.html').exists()
        (cache / 'npc-2.html').unlink()
        state['pagesWithoutCoordinates'] = [2]
        progress.write_text(json.dumps(state))
        calls.clear()
        with patch.object(sys, 'argv', ['resume_map_research.py', '--retry-no-coordinates', '--limit', '1']):
            research.main()
        retried = json.loads(progress.read_text())
        assert len(calls) == 1 and 'npc=2?' in calls[0]
        assert retried['fetchedThisRun'] == [2] and 2 not in retried['pagesWithoutCoordinates']
        assert '--retry-no-coordinates' in retried['resumeCommand']
        for invalid in ('-1', 'nan', 'inf'):
            with patch.object(sys, 'argv', ['resume_map_research.py', '--delay', invalid]), redirect_stderr(io.StringIO()):
                try:
                    research.main()
                except SystemExit as exc:
                    assert exc.code == 2
                else:
                    raise AssertionError('Invalid delay accepted')

print('PASS: two-second pacing, cache reuse, blocked-request stop, saved progress and delay validation.')
