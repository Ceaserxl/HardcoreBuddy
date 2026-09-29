import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon=boot()
lua.execute('''
local A=TestAddon
local H=A.CreatureAlerts
local id,classification,faction=4314,"elite","Alliance"
UnitExists=function() return true end
UnitGUID=function() return "Creature-0-1-2-3-"..id.."-12345" end
UnitClassification=function() return classification end
UnitFactionGroup=function() return faction end
UnitName=function() return "Localized NPC name" end
UnitReaction=function() return 2 end
UnitCanAttack=function() return true end
UnitIsPlayer=function() return false end
UnitPlayerControlled=function() return false end
UnitIsDeadOrGhost=function() return false end
UnitOnTaxi=function() return false end
IsInInstance=function() return false,"none" end
UnitLevel=function() return 55 end
GetRaidTargetIndex=function() return nil end
IsInRaid=function() return false end
local marks,alerts=0,0
SetRaidTarget=function() marks=marks+1 end
H.Show=function() alerts=alerts+1 end
for _,side in ipairs({"Alliance","Horde","Unknown"}) do
    faction=side
    for _,npc in ipairs({4314,8018,1387,2851,2389}) do
        id=npc; assert(H:IsExcluded("target"))
        H:Inspect("target",true)
    end
end
assert(marks==0 and alerts==0 and next(H.pending)==nil)
id=1423; faction="Alliance"; assert(H:IsExcluded("target"))
faction="Horde"; assert(not H:IsExcluded("target"),"Enemy Stormwind guards remain enabled for Horde")
faction="Unknown"; assert(not H:IsExcluded("target"))
for npc,mask in pairs(A.Data.CreatureAlertExclusions) do
    id=npc; classification="elite"
    for _,side in ipairs({"Alliance","Horde","Unknown"}) do
        faction=side
        assert(H:IsExcluded("target")== (mask==3 or (mask==1 and side=="Alliance") or (mask==2 and side=="Horde")))
    end
    classification="rare"; assert(not H:IsExcluded("target"))
    classification="rareelite"; assert(not H:IsExcluded("target"))
end
id=2529; classification="elite"; faction="Alliance"
assert(not H:IsExcluded("target"),"Son of Arugal remains enabled")
id=999999; assert(not H:IsExcluded("target"),"Unlisted elites remain enabled")
H:Inspect("target"); assert(alerts==1 and marks==1)
-- A queued candidate is checked again before presenting or marking.
H.warning:Hide(); H.lastPresented=nil
id=4314; local guid=UnitGUID("target")
H.pending={test={unit="target",guid=guid,time=GetTime(),category="elites",classification="elite",reactionValue=2}}
H:Present(); assert(next(H.pending)==nil and alerts==1 and marks==1)
print("PASS: All 226 exclusions, both factions/unknown faction, localized names, no alert/marker, pending checks, rare preservation and unrelated elite detection.")
''')
