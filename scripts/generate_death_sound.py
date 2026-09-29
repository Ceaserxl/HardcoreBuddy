"""Original death-alert bell at ten volume levels. No external samples."""
import math
import struct
import wave
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'Media/Deaths'
rate=22050
samples=[]
for i in range(rate*2):
    t=i/rate
    envelope=min(1,t/0.008)*math.exp(-2.5*t)*min(1,(2-t)/0.1)
    tone=sum(gain*math.sin(2*math.pi*frequency*t) for frequency,gain in ((440,1),(880,0.35),(1190,0.18)))
    samples.append(tone*envelope*0.4)
for volume in range(10,101,10):
    with wave.open(str(root/f'DeathBell{volume}.wav'),'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes(b''.join(struct.pack('<h',int(v*volume/100*32767)) for v in samples))
