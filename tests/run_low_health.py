import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua, addon=boot()
lua.execute('''
local A=TestAddon
local H=A.LowHealth
local health,maximum,dead=100,100,false
local sounds,stops=0,0
UnitHealth=function(unit) assert(unit=="player"); return health end
UnitHealthMax=function() return maximum end
UnitIsDeadOrGhost=function() return dead end
PlaySoundFile=function(path,channel) assert(path:find("HardcoreBuddy",1,true) and channel=="Master"); sounds=sounds+1; return true,sounds end
StopSound=function() stops=stops+1 end
local function fire(event,unit) H.events.scripts.OnEvent(H.events,event,unit) end
assert(H.settings.threshold==40 and H.settings.enabled and H.settings.sound)
fire("PLAYER_ENTERING_WORLD")
assert(not H.warning:IsShown())
health=40; fire("UNIT_HEALTH","player"); assert(not H.active)
health=39; fire("UNIT_HEALTH","target"); assert(not H.active)
fire("UNIT_HEALTH","player"); assert(H.active and H.warning:IsShown() and sounds==1)
health=20; fire("UNIT_HEALTH","player"); assert(sounds==1)
H.warning.scripts.OnUpdate(H.warning,0.25); assert(H.warning:GetAlpha()==0.5)
health=40; fire("UNIT_HEALTH","player"); assert(not H.active and not H.warning:IsShown() and stops==1)
health=39; fire("UNIT_HEALTH","player"); assert(sounds==2)
dead=true; fire("PLAYER_DEAD"); assert(not H.active and not H.warning:IsShown())
dead=false; health=0; fire("PLAYER_ALIVE"); assert(not H.active)
health=10; maximum=0; fire("UNIT_MAXHEALTH","player"); assert(not H.active)
health=100; maximum=100; fire("PLAYER_ALIVE")
A:HandleSlashCommand("health")
assert(A.state.view=="alerts" and H.page:IsVisible() and not A.window.scroll:IsShown())
local p=H.page
p.threshold:SetText("25"); p.threshold.scripts.OnEnterPressed(p.threshold)
assert(H.settings.threshold==25)
health=24; fire("UNIT_HEALTH","player"); assert(H.active)
p.checks.enabled:SetChecked(false); p.checks.enabled.scripts.OnClick(p.checks.enabled)
assert(not H.active and not H.warning:IsShown())
p.checks.sound:SetChecked(false); p.checks.sound.scripts.OnClick(p.checks.sound)
p.checks.enabled:SetChecked(true); p.checks.enabled.scripts.OnClick(p.checks.enabled)
local before=sounds
assert(H.active); fire("UNIT_HEALTH","player"); assert(sounds==before)
health=100; fire("UNIT_HEALTH","player")
p.preview.scripts.OnClick(p.preview); assert(H.warning:IsShown() and sounds==before)
H.warning.scripts.OnUpdate(H.warning,3.1); assert(not H.warning:IsShown())
p.threshold:SetText("999"); p.threshold.scripts.OnEnterPressed(p.threshold); assert(H.settings.threshold==100)
p.threshold:SetText("0"); p.threshold.scripts.OnEnterPressed(p.threshold); assert(H.settings.threshold==1)
p.threshold:SetText("40"); p.threshold.scripts.OnEnterPressed(p.threshold)
p.checks.sound:SetChecked(true); p.checks.sound.scripts.OnClick(p.checks.sound)
A:Navigate("supplies"); assert(not H.page:IsShown())
A:Navigate("alerts"); assert(H.page:IsVisible())
assert(H.settings.volume==70)
p.volume:SetValue(0); local before=sounds; H:Preview(); assert(sounds==before)
p.volume:SetValue(30)
PlaySoundFile=function(path,channel) assert(path:find("AirHorn30.wav",1,true)); sounds=sounds+1; return true,sounds end
H:Preview(); assert(sounds==before+1 and H.settings.volume==30)
print("PASS: Low health thresholds, player-only events, single alarm, recovery/death, invalid health, toggles, preview expiry and settings navigation.")
''')
composite(lua.globals().MOCK['frames'], addon['window']).convert('RGB').save(ROOT/'docs/layout-previews/hardcorebuddy-health-options.png')
addon['LowHealth']['Preview'](addon['LowHealth'])
composite(lua.globals().MOCK['frames'], addon['LowHealth']['warning']).convert('RGB').save(ROOT/'docs/layout-previews/hardcorebuddy-low-health.png')
