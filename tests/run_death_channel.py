"""Official channel auto-join without community opt-in or chat reconfiguration."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local H=TestAddon.Deaths
local now,joined,hardcore=0,false,true
local joins,timers={},{}
GetTime=function() return now end
C_GameRules={IsHardcoreActive=function() return hardcore end}
GetChannelName=function(name)
    assert(name==H.officialChannel)
    return joined and 7 or 0
end
JoinChannelByName=function(name,password)
    assert(name==H.officialChannel and password==nil)
    joins[#joins+1]=name
end
C_Timer.After=function(delay,callback)
    assert(delay==5); timers[#timers+1]=callback
end
H.db.settings.community=false
H.db.settings.alerts=false
H.officialChannelReady=nil; H.officialJoinScheduled=nil; H.nextOfficialJoin=nil
H.events.scripts.OnEvent(H.events,"PLAYER_ENTERING_WORLD")
H.events.scripts.OnEvent(H.events,"PLAYER_ENTERING_WORLD")
assert(#joins==0 and #timers==1,"Wait for normal login channels; coalesce zoning callbacks")
now=5; timers[1]()
assert(#joins==1 and joins[1]=="HardcoreDeaths","Auto-join with community and banners disabled")
now=20; H.events.scripts.OnUpdate(H.events,15)
assert(#joins==1,"Do not spam asynchronous join requests")
now=65; H.events.scripts.OnUpdate(H.events,15)
assert(#joins==2,"Retry a failed join after the cooldown")
joined=true; now=80; H.events.scripts.OnUpdate(H.events,15)
assert(#joins==2 and H.nextOfficialJoin==nil,"Existing membership must be preserved")
joined=false; now=95; H.events.scripts.OnUpdate(H.events,15)
assert(#joins==3,"Rejoin when membership is lost")
hardcore=false; now=200; H.events.scripts.OnUpdate(H.events,15)
assert(#joins==3,"Do not create a fake death channel outside Hardcore")
hardcore=true; joined=true
H.events.scripts.OnEvent(H.events,"PLAYER_ENTERING_WORLD")
timers[#timers]()
assert(#joins==3,"Entering the world while joined must not rejoin")
GetChannelName=nil
H:EnsureOfficialChannel()
print("PASS: Delayed official-channel auto-join, existing membership, bounded retries, lost membership, non-Hardcore guard, independent settings and missing APIs.")
''')

# Membership uses exactly the same localized channel as the report receiver.
lua2, addon2 = boot()
lua2.globals().GetLocale = lambda: 'deDE'
from pathlib import Path
lua2.execute((Path(__file__).resolve().parents[1]/'Deaths/Events.lua').read_text(encoding='utf-8'),
             'HardcoreBuddy', addon2)
lua2.execute('''
local H=TestAddon.Deaths
assert(H.officialChannel=="HardcoreTode")
GetChannelName=function(name) assert(name=="HardcoreTode"); return 0 end
JoinChannelByName=function(name) assert(name=="HardcoreTode") end
H:EnsureOfficialChannel()
print("PASS: Localized official channel matches auto-join and receipt handling.")
''')
