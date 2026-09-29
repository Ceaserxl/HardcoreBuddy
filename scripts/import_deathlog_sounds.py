"""Rebuild per-alert volume copies of the bundled Deathlog source clips.

Usage: python scripts/import_deathlog_sounds.py PATH_TO_FFMPEG
Unmodified source clips and their license live beside the generated files.
"""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1] / 'Media/Deaths/Deathlog'
revision = '1092449ed714e70ddfdc6111e575e15a27589933'
sources = []
for name in ('HeroFallen', 'Arugal', 'Dread_Hunger', 'hunger_games', 'golfclap'):
    source = root / (name + '.ogg')
    sources.append(dict(name=name, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                        url=f'https://github.com/aaronma37/Deathlog/blob/{revision}/Libs/DeathNotificationLib/Sounds/{name}.ogg'))
    for volume in range(10, 101, 10):
        subprocess.run([sys.argv[1], '-hide_banner', '-loglevel', 'error', '-y',
                        '-i', str(source), '-af', f'volume={volume/100}',
                        '-c:a', 'libvorbis', '-q:a', '5',
                        str(root / f'{name}{volume}.ogg')], check=True)
(root / 'sources.json').write_text(json.dumps(dict(revision=revision, sources=sources), indent=2) + '\n')
print('Generated 50 Deathlog clips at 10-100% volume.')
