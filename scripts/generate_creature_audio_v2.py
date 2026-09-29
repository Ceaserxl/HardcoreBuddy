"""Volume variants for spoken rares and a two-tone elite siren.
Run generate_creature_voices.ps1 first to recreate the speech sources.
"""
import math
import struct
import wave
from pathlib import Path

root=Path(__file__).resolve().parents[1]/'Media/CreatureSounds'

def variants(kind,samples,rate):
    for volume in range(10,101,10):
        data=b''.join(struct.pack('<h',round(max(-1,min(1,v))*volume/100*32767)) for v in samples)
        with wave.open(str(root/(kind+str(volume)+'.wav')),'wb') as out:
            out.setparams((1,2,rate,0,'NONE','not compressed'))
            out.writeframes(data)

for kind in ('NeutralRareVoiceV1','HostileRareVoiceV1'):
    with wave.open(str(root/(kind+'-source.wav'))) as source:
        assert source.getsampwidth()==2 and source.getnchannels()==1
        rate=source.getframerate()
        raw=source.readframes(source.getnframes())
    samples=[v[0]/32768 for v in struct.iter_unpack('<h',raw)]
    gain=0.85/max(abs(v) for v in samples)
    variants(kind,[v*gain for v in samples],rate)

rate=22050
duration=2.4
samples=[]
phase=0.0
for i in range(round(rate*duration)):
    t=i/rate
    # Alternating high/low siren with smooth transitions and no sharp clicks.
    frequency=780+220*math.tanh(5*math.sin(2*math.pi*t/0.6))
    phase+=2*math.pi*frequency/rate
    envelope=min(1,t/0.025,(duration-t)/0.10)
    tone=math.sin(phase)+0.3*math.sin(3*phase)+0.12*math.sin(5*phase)
    samples.append(envelope*tone*0.55)
variants('EliteSirenV2',samples,rate)
