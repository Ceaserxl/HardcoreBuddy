"""Normalize Classic map-art rectangle/file IDs into our factual tile manifest."""
import re
from pathlib import Path
import urllib.request
import io
import zipfile

ROOT=Path(__file__).resolve().parents[1]
SOURCE='https://edge.forgecdn.net/files/9020/349/Leatrix_Maps-1.15.157-classic.zip'
cache=ROOT/'.release/map-research/era-reveal-1.15.157.lua'
if not cache.exists():
    cache.parent.mkdir(parents=True,exist_ok=True)
    archive=zipfile.ZipFile(io.BytesIO(urllib.request.urlopen(SOURCE).read()))
    cache.write_bytes(archive.read('Leatrix_Maps/Leatrix_Maps_Reveal.lua'))
out=['-- Classic client map-art geometry and file IDs. See docs/map-data.md.','local _,A=...','A.Data.MapTiles={']
count=0
for line in cache.read_text(encoding='utf-8-sig').splitlines():
    match=re.search(r'--\[\[(\d+):.*?\]\]\s*\[(\d+)\]\s*=\s*\{(.*)\}',line)
    if not match or not 1411<=int(match[1])<=1458: continue
    tiles=[]
    for rect,files in re.findall(r'\["([0-9:]+)"\]\s*=\s*"([0-9, ]+)"',match[3]):
        w,h,x,y=map(int,rect.split(':')); ids=[int(f) for f in files.split(',')]
        assert len(ids)==((w+255)//256)*((h+255)//256)
        tiles.append('{'+','.join(map(str,[w,h,x,y]))+',{'+','.join(map(str,ids))+'}}')
    out.append('['+match[1]+']={art='+match[2]+',tiles={'+','.join(tiles)+'}},'); count+=1
out+=['}','']
(ROOT/'Data/MapTiles.lua').write_text('\n'.join(out),encoding='utf-8')
print('Classic reveal maps:',count)
