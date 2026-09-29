"""Preserve the attributed AirHorn recording at ten volume levels. Requires ffmpeg."""
import subprocess
import sys
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'Media/Health'
for volume in range(10,101,10):
    subprocess.run([sys.argv[1] if len(sys.argv)>1 else 'ffmpeg','-y','-loglevel','error',
                    '-i',str(root/'AirHorn.ogg'),'-af',f'volume={volume/100}',
                    '-c:a','pcm_s16le',str(root/f'AirHorn{volume}.wav')],check=True)
