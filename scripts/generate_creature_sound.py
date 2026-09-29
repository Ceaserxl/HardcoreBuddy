"""Original warning sirens with independent volume variants; no external samples."""
import math, struct, wave
from pathlib import Path
rate=22050
duration=2.4
root=Path(__file__).resolve().parents[1]/'Media/CreatureSounds'
root.mkdir(exist_ok=True)
for kind in ('Rare','Elite','HostileRare'):
    samples=[]
    phase=0.0
    for i in range(int(rate*duration)):
        t=i/rate
        if kind=='Rare':
            frequency=780+260*(0.5-0.5*math.cos(2*math.pi*t/1.2))
        elif kind=='Elite':
            frequency=500+380*(0.5-0.5*math.cos(2*math.pi*t/0.8))
        else:
            frequency=700+550*(0.5-0.5*math.cos(2*math.pi*t/0.4))
        phase+=2*math.pi*frequency/rate
        envelope=min(1,t/0.035,(duration-t)/0.12)
        samples.append(envelope*(math.sin(phase)+0.25*math.sin(3*phase)+0.1*math.sin(5*phase))*0.48)
    for volume in range(10,101,10):
        data=b''.join(struct.pack('<h',int(v*volume/100*32767)) for v in samples)
        with wave.open(str(root/(kind+str(volume)+'.wav')),'wb') as out:
            out.setparams((1,2,rate,0,'NONE','not compressed'))
            out.writeframes(data)
