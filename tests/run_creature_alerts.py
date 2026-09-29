import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,addon=boot()
lua.execute('''
local A=TestAddon
local H=A.CreatureAlerts
local instanceType="none"
IsInInstance=function() return instanceType~="none",instanceType end
local now=0
GetTime=function() return now end
local u={classification="rare",reaction=2,guid="one",name="Rare creature",level=20}
UnitExists=function(unit) return unit=="target" or unit=="nameplate1" end
UnitIsPlayer=function() return u.player end
UnitPlayerControlled=function() return u.pet end
UnitIsDeadOrGhost=function() return u.dead end
UnitClassification=function() return u.classification end
UnitReaction=function() return u.reaction end
UnitCanAttack=function() return u.attackable~=false end
UnitGUID=function() return u.guid end
UnitName=function() return u.name end
UnitLevel=function() return u.level end
-- These routing tests isolate presentation arbitration; dedicated noise tests cover it.
local inspect=H.Inspect
H.Inspect=function(self,...)
    self.lastPresented=nil; self.warning:Hide()
    return inspect(self,...)
end
local shown=0
local show=H.Show
H.Show=function(self,...) shown=shown+1; show(self,...) end
H:Inspect("target"); assert(shown==1 and H.warning.category=="rares")
H:Inspect("nameplate1"); assert(shown==1)
now=121; H:Inspect("target"); assert(shown==2)
u.classification="rareelite"; u.guid="two"; H:Inspect("target"); assert(shown==3 and H.warning.category=="rares")
H.settings.rares.enabled=false; u.guid="three"; H:Inspect("target"); assert(shown==4 and H.warning.category=="elites")
u.classification="rare"; u.guid="four"; H:Inspect("target"); assert(shown==4)
H.settings.rares.enabled=true; H.settings.rares.nonHostile=false; u.reaction=4; H:Inspect("target"); assert(shown==4)
u.classification="elite"; H:Inspect("target"); assert(shown==5 and H.warning.title:GetText()=="Neutral Elite detected")
u.reaction=5; u.guid="five"; H:Inspect("target"); assert(shown==5)
u.reaction=4; u.attackable=false; H:Inspect("target"); assert(shown==5)
u.attackable=true; H:Inspect("target"); assert(shown==6)
H.settings.elites.nonHostile=false; u.guid="six"; H:Inspect("target"); assert(shown==6)
u.reaction=1; H:Inspect("target"); assert(shown==7)
u.guid="seven"; u.dead=true; H:Inspect("target"); assert(shown==7)
u.dead=false; u.player=true; H:Inspect("target"); assert(shown==7)
u.player=false; u.pet=true; H:Inspect("target"); assert(shown==7)
u.pet=false; u.classification="normal"; H:Inspect("target"); assert(shown==7)
u.classification="worldboss"; u.level=-1; H:Inspect("target"); assert(shown==8 and H.warning.name:GetText():find("??",1,true))
H.warning.scripts.OnUpdate(H.warning,10.5); assert(not H.warning:IsShown())
A:Navigate("alerts"); A.state.filter="Rares"; A:Refresh()
assert(H.page:IsShown() and H.page.category=="rares" and H.page.checks.nonHostile:IsShown())
H.page.duration:SetText("99"); H.page.duration.scripts.OnEnterPressed(); assert(H.settings.rares.duration==30)
A.state.filter="Elites"; A:Refresh(); assert(H.page.checks.nonHostile:IsShown())
H.page.checks.enabled:SetChecked(false); H.page.checks.enabled.scripts.OnClick(); assert(not H.settings.elites.enabled)
u.guid="eight"; H:Inspect("target"); assert(shown==8)
H.page.preview.scripts.OnClick(); assert(shown==9 and H.warning:IsShown())
A:Navigate("supplies"); assert(not H.page:IsShown())
local combat=false
InCombatLockdown=function() return combat end
local b={attributes={}}
function b:Hide() assert(not combat); self.hidden=true end
function b:SetAttribute(key,value) assert(not combat); self.attributes[key]=value end
RegisterStateDriver=function(button,state,condition) assert(not combat and condition=="[combat] hide; show"); button.driver=condition end
UnregisterStateDriver=function(button) assert(not combat); button.driver=nil end
H.targetButton=b
H:Show("Detected elite",40,"elite","Hostile","elites",true)
assert(b.attributes.macrotext=="/targetexact Detected elite" and b.driver)
combat=true
H:Show("Combat elite",42,"elite","Hostile","elites",true)
assert(b.attributes.macrotext=="/targetexact Detected elite")
combat=false; H:SyncTargetButton()
assert(b.attributes.macrotext=="/targetexact Combat elite")
H.warning:Hide(); H:SyncTargetButton(); assert(not b.driver and not b.attributes.type)
H:Show("Preview",30,"rare","Hostile","rares")
assert(not b.driver and not b.attributes.type)
local played={}
PlaySoundFile=function(path,channel) assert(channel=="Master"); played[#played+1]=path; return true,#played end
StopSound=function() end
H.settings.rares.sound=true; H.settings.elites.sound=true
H.settings.rares.volume=40; H.settings.elites.volume=80
H:Show("Rare",30,"rare","Neutral","rares"); assert(played[#played]:find("NeutralRareVoiceV140.wav",1,true))
H:Show("Rare",30,"rare","Hostile","rares"); assert(played[#played]:find("HostileRareVoiceV140.wav",1,true))
H:Show("Elite",30,"elite","Hostile","elites"); assert(played[#played]:find("EliteSirenV280.wav",1,true))
local count=#played; H.settings.elites.volume=0; H:Show("Elite",30,"elite","Hostile","elites"); assert(#played==count)
A:Navigate("alerts"); A.state.filter="Rares"; A:Refresh(); H.page.volume:SetValue(60); assert(H.settings.rares.volume==60)
H.settings.rares.nonHostile=true; u.classification="rare"; u.reaction=4; u.guid="neutralRare"
H:Inspect("target"); assert(H.warning.title:GetText()=="Neutral Rare detected")
print("PASS: creature detection, cooldowns, settings, secure targeting, three distinct sounds, volume selection and mute.")
H:Show("Elite",30,"elite","Hostile","elites")
assert(H.screenFlash:IsShown() and H.screenFlash:GetAlpha()==0)
for pulse=1,4 do
    H.screenFlash.scripts.OnUpdate(H.screenFlash,0.4)
    assert(math.abs(H.screenFlash:GetAlpha()-0.22)<0.0001)
    H.screenFlash.scripts.OnUpdate(H.screenFlash,0.4)
    assert(H.screenFlash:GetAlpha()<0.0001)
end
H.screenFlash.scripts.OnUpdate(H.screenFlash,0.001); assert(not H.screenFlash:IsShown())
H:Show("Neutral elite",30,"elite","Neutral","elites"); assert(not H.screenFlash:IsShown())
H:Show("Rare",30,"rare","Hostile","rares"); assert(H.screenFlash:IsShown())
H:Show("Rare elite",30,"rareelite","Hostile","rares"); assert(H.screenFlash:IsShown())
print("PASS: four flash pulses, neutral elite exclusion, and rare flash inclusion.")
H.settings.elites.enabled=true; H.settings.elites.nonHostile=true
H.settings.rares.enabled=true; H.settings.rares.nonHostile=true
instanceType="party"; local before=shown
u.guid="dungeonElite"; u.classification="elite"; u.reaction=2
H:Inspect("target"); assert(shown==before)
u.guid="dungeonNeutralElite"; u.reaction=4
H:Inspect("target"); assert(shown==before)
u.guid="dungeonRare"; u.classification="rare"; u.reaction=2
H:Inspect("target"); assert(shown==before+1 and H.warning.category=="rares")
u.guid="dungeonNeutralRare"; u.reaction=4
H:Inspect("target"); assert(shown==before+2 and H.warning.category=="rares")
u.guid="dungeonRareElite"; u.classification="rareelite"; u.reaction=2
H:Inspect("target"); assert(shown==before+3 and H.warning.category=="rares")
H.settings.rares.enabled=false; u.guid="dungeonRareEliteDisabled"
H:Inspect("target"); assert(shown==before+3)
instanceType="none"; u.guid="outsideElite"; u.classification="elite"
H:Inspect("target"); assert(shown==before+4 and H.warning.category=="elites")
instanceType="raid"; u.guid="raidElite"
H:Inspect("target"); assert(shown==before+4)
H.settings.rares.enabled=true; u.guid="raidRare"; u.classification="rare"
H:Inspect("target"); assert(shown==before+5 and H.warning.category=="rares")
u.guid="raidNeutralRare"; u.reaction=4
H:Inspect("target"); assert(shown==before+6 and H.warning.category=="rares")
print("PASS: dungeons and raids suppress elites while preserving hostile/neutral rares; outdoor elite alerts remain active.")
''')

import wave
for kind in ('NeutralRareVoiceV1','EliteSirenV2','HostileRareVoiceV1'):
    for volume in range(10,101,10):
        path=Path(__file__).resolve().parents[1]/'Media/CreatureSounds'/f'{kind}{volume}.wav'
        with wave.open(str(path)) as sound:
            assert 0.5 < sound.getnframes()/sound.getframerate() < 6
            assert sound.getnchannels()==1 and sound.getsampwidth()==2
print('PASS: all 30 sound variants exist and have valid WAV headers.')
