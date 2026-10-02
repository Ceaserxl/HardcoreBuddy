"""Offline character equipment, transferability and best-slot tooltip checks."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua, addon = boot()
lua.execute((ROOT/'tests/gear_advisor.lua').read_text())
lua.execute(r'''
local A,F=TestAddon,GEAR_FIXTURES
local Alt,G=A.AltAdvisor,A.GearAdvisor
local guid='Player-bank'
UnitGUID=function() return guid end
GetRealmName=function() return 'Realm' end
UnitName=function() return guid end
UnitFactionGroup=function() return 'Alliance' end
F.reset('MAGE',40,{0,0,31})
local weak=F.item('INVTYPE_FINGER',{ITEM_MOD_INTELLECT_SHORT=5},4,0)
local strong=F.item('INVTYPE_FINGER',{ITEM_MOD_INTELLECT_SHORT=10},4,0)
local candidate=F.item('INVTYPE_FINGER',{ITEM_MOD_INTELLECT_SHORT=20},4,0)
F.equip(11,weak); F.equip(12,strong)
guid='Player-first'; assert(Alt:Capture())
F.equip(11,strong)
guid='Player-second'; assert(Alt:Capture())
guid='Player-bank'
local item=G:Read(candidate.link)
local upgrades=Alt:Upgrades(item)
assert(#upgrades==2 and upgrades[1].character.name=='Player-first')
assert(upgrades[1].row.percent==300 and upgrades[2].row.percent==100)
assert(upgrades[1].row.slot==11,'One best slot per character')
assert(A.db.altEquipment['Player-first'].equipment[11].stats.ITEM_MOD_INTELLECT_SHORT==5,'Snapshots are independent')
guid='Player-first'; assert(#Alt:Upgrades(item)==1,'Exclude current character'); guid='Player-bank'
A.db.altEquipment['Player-second'].realm='Other'
assert(#Alt:Upgrades(item)==1,'Exclude different realms')
A.db.altEquipment['Player-second'].realm='Realm'; A.db.altEquipment['Player-second'].faction='Horde'
assert(#Alt:Upgrades(item)==1,'Exclude opposite faction')
A.db.altEquipment['Player-second'].faction='Alliance'
local old=G.Equipped
G.Equipped=function() return nil,'Item data loading' end
guid='Player-first'; assert(not Alt:Capture())
assert(A.db.altEquipment[guid].equipment[11].stats.ITEM_MOD_INTELLECT_SHORT==5,'Loading never overwrites complete saved gear')
G.Equipped=old; guid='Player-bank'
local info=C_Item.GetItemInfo
local binding=2
C_Item.GetItemInfo=function(link)
 local values={info(link)}; values[14]=binding; return unpack(values,1,14)
end
ITEM_SOULBOUND='Soulbound'; ITEM_BIND_ON_PICKUP='Binds when picked up'
GameTooltip:SetHyperlink(candidate.link)
assert(Alt:Transferable(GameTooltip,candidate.link))
Alt:Add(GameTooltip); assert(GameTooltip.hardcoreBuddyAlt)
local count=GameTooltip:NumLines(); Alt:Add(GameTooltip); assert(GameTooltip:NumLines()==count,'No duplicate Alt section')
GameTooltip:ClearLines(); GameTooltip:SetHyperlink(candidate.link); GameTooltip:AddLine('Soulbound')
assert(not Alt:Transferable(GameTooltip,candidate.link)); Alt:Add(GameTooltip)
assert(not GameTooltip.hardcoreBuddyAlt,'Bound BoE instance must not receive advice')
binding=1; GameTooltip:SetHyperlink(candidate.link); assert(not Alt:Transferable(GameTooltip,candidate.link),'No BoP advice')
binding=0; GameTooltip:SetHyperlink(candidate.link); assert(Alt:Transferable(GameTooltip,candidate.link),'Nonbinding equipment is eligible')
binding=nil; assert(not Alt:Transferable(GameTooltip,candidate.link),'Unknown binding is excluded')
binding=2; Alt:SetEnabled(false); GameTooltip:SetHyperlink(candidate.link); Alt:Add(GameTooltip)
assert(not GameTooltip.hardcoreBuddyAlt,'Setting disables advice')
Alt:SetEnabled(true)
local noUpgrade=G:Read(weak.link); assert(#Alt:Upgrades(noUpgrade)==0,'No equal/downgrade entries')
local unique=G:Read(candidate.link); unique.unique=true
A.db.altEquipment['Player-first'].equipment[12]=unique
local found
for _,entry in ipairs(Alt:Upgrades(unique)) do if entry.character.name=='Player-first' then found=true end end
assert(not found,'Unique item already in other slot is excluded')
local profile=A.db.altEquipment['Player-first'].profile
profile.cachedDualWield=false; IsSpellKnown=function() return true end
assert(not G.CanDualWield(profile),'Offline dual wield does not use bank character skills')
guid='Player-event'
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
Alt.events.scripts.OnUpdate(Alt.events,1)
assert(A.db.altEquipment[guid],'Login event captures gear automatically')
F.equip(11,nil)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[11]==false,'Logout persists an explicitly empty slot')
local p=G:CurrentProfile(); p.cachedDualWield=false
local two=F.item('INVTYPE_2HWEAPON',{ITEM_MOD_INTELLECT_SHORT=25},2,10)
two=G:Read(two.link); two.dps=10
local baseline={[16]=G:Read(weak.link),[17]=G:Read(strong.link)}
local rows=G:Comparisons(two,p,nil,baseline)
assert(rows[1].label=='Both hands','Offline two-hand comparison includes both equipped slots')
local expected=(G.Score(two,p,16)/(G.Score(baseline[16],p,16)+G.Score(baseline[17],p,17))-1)*100
assert(math.abs(rows[1].percent-math.floor(expected*100)/100)<.02)
print('PASS: cached profiles/equipment, best-slot ranking, faction/realm identity, binding, tooltip deduplication and disable setting.')
''')
