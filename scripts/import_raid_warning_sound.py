"""Generate per-alert volume copies of the original Classic raid-warning clip.

Usage: python scripts/import_raid_warning_sound.py PATH_TO_FFMPEG
Source and attribution are included in Media/Deaths/Original.
"""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1] / 'Media/Deaths/Original'
source = root / 'RaidWarning.ogg'
for volume in range(10, 101, 10):
    output = root / f'RaidWarning{volume}.ogg'
    if volume == 100:
        output.write_bytes(source.read_bytes())
    else:
        subprocess.run([sys.argv[1], '-hide_banner', '-loglevel', 'error', '-y',
                        '-i', str(source), '-af', f'volume={volume/100}',
                        '-c:a', 'libvorbis', '-q:a', '5', str(output)], check=True)
print('Generated 10 original raid-warning clips at 10-100% volume.')
