import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,addon=boot()
lua.execute('''
local H=TestAddon.CreatureAlerts
local now,taxi,dead,raid,leader=0,false,false,false,false
local units={}
GetTime=function() return now end
UnitOnTaxi=function() return taxi end
UnitIsDeadOrGhost=function(unit) return unit=="player" and dead or (units[unit] and units[unit].dead) end
UnitExists=function(unit) return units[unit]~=nil end
UnitIsPlayer=function() return false end
UnitPlayerControlled=function() return false end
UnitGUID=function(unit) return units[unit].guid end
UnitName=function(unit) return units[unit].name end
UnitLevel=function() return 30 end
UnitClassification=function(unit) return units[unit].class end
UnitReaction=function(unit) return units[unit].reaction end
UnitCanAttack=function() return true end
IsInInstance=function() return false,"none" end
IsInRaid=function() return raid end
UnitIsGroupLeader=function() return leader end
UnitIsGroupAssistant=function() return false end
GetRaidTargetIndex=function(unit) return units[unit].mark end
local marks=0
SetRaidTarget=function(unit,mark) assert(mark==4); units[unit].mark=mark; marks=marks+1 end
local shown=0
local show=H.Show
H.Show=function(self,...) shown=shown+1; show(self,...) end
local function mob(id,spawn,class,reaction)
    return {guid="Creature-0-1-2-3-"..id.."-"..spawn,name="Mob "..id,class=class or "elite",reaction=reaction or 2}
end
units.target=mob(1,1)
taxi=true; H:Scan(); assert(shown==0 and marks==0)
taxi=false; dead=true; H:Scan(); assert(shown==0)
dead=false; H:Scan(); assert(shown==1 and marks==1)
-- A new member of the same pack cannot restart the alert.
units.nameplate1=mob(1,2); H.plates.nameplate1=true
now=1; H:Scan(); assert(shown==1)
-- Hostile rare waits for speech gap, then replaces an ordinary elite.
units.nameplate2=mob(2,1,"rare"); H.plates.nameplate2=true
now=2; H:Scan(); assert(shown==1)
now=4; H:Scan(); assert(shown==2 and H.warning.category=="rares")
units.nameplate3=mob(3,1); H.plates.nameplate3=true
now=8; H:Scan(); assert(shown==2)
H.warning:Hide(); now=15; H:Scan(); assert(shown==3)
-- Continuously visible creatures do not repeat after 120 seconds.
for t=16,160 do now=t; H:Scan(); H.warning:Hide() end
assert(shown==3)
units={}; now=191; H:Scan()
units.target=mob(1,1); now=192; H:Scan(); assert(shown==4)
-- Preserve an existing mark and respect raid permissions.
units.target.mark=8; H:Inspect("target",true); assert(units.target.mark==8)
units.target.mark=nil; raid=true; leader=false
local before=marks; H:Inspect("target",true); assert(marks==before)
leader=true; H:Inspect("target",true); assert(marks==before+1 and units.target.mark==4)
-- Suppression clears current visuals and does not consume pending encounters.
taxi=true; H:Scan(); assert(not H.warning:IsShown() and not H.screenFlash:IsShown())
print("PASS: taxi/death suppression, pack grouping, audio gap, priority, sustained visibility, rearming, marker preservation and raid permissions.")
''')
