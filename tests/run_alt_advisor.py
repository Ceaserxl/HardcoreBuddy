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
local doubleLine=GameTooltip.AddDoubleLine
GameTooltip.AddDoubleLine=function(self,left,...)
 if left=='' then return end -- WoW can omit entirely empty native lines.
 return doubleLine(self,left,...)
end
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
C_Container.GetContainerItemLink=function() return candidate.link end
C_Container.GetContainerItemInfo=function() return {isBound=false} end
local function bagAdvice()
 GameTooltip.hardcoreBuddyAltLocation={bag=0,slot=1}; Alt:Add(GameTooltip)
end
ITEM_SOULBOUND='Soulbound'; ITEM_BIND_ON_PICKUP='Binds when picked up'
GameTooltip:SetHyperlink(candidate.link)
assert(Alt:Transferable(GameTooltip,candidate.link))
GameTooltip:AddLine('Vendor prices')
local vendorLine=GameTooltip:NumLines()
bagAdvice(); assert(GameTooltip.hardcoreBuddyAlt)
local gear=GameTooltip.hardcoreBuddyGear
local prefix=GameTooltip:GetName()..'TextLeft'
local altStart=vendorLine+1
assert(_G[prefix..altStart]:GetText():find('SurvivorShield.tga',1,true),'Alt title includes shield icon')
assert(_G[prefix..vendorLine]:GetText()=='Vendor prices','Existing vendor text preserved')
assert(_G[prefix..(altStart+6)]:GetText()==' ','Alt section ends with a gap')
G:Add(GameTooltip)
assert(_G[prefix..altStart]:GetText():find('Alt Advisor',1,true),'Gear refresh preserves Alt section')
local count=GameTooltip:NumLines(); bagAdvice(); assert(GameTooltip:NumLines()==count,'No duplicate Alt section')
GameTooltip:ClearLines(); GameTooltip:SetHyperlink(candidate.link); GameTooltip:AddLine('Soulbound')
assert(not Alt:Transferable(GameTooltip,candidate.link)); bagAdvice()
assert(not GameTooltip.hardcoreBuddyAlt,'Bound BoE instance must not receive advice')
binding=1; GameTooltip:SetHyperlink(candidate.link); assert(not Alt:Transferable(GameTooltip,candidate.link),'No BoP advice')
binding=0; GameTooltip:SetHyperlink(candidate.link); assert(Alt:Transferable(GameTooltip,candidate.link),'Nonbinding equipment is eligible')
binding=nil; assert(not Alt:Transferable(GameTooltip,candidate.link),'Unknown binding is excluded')
binding=2; Alt:SetEnabled(false); GameTooltip:SetHyperlink(candidate.link); bagAdvice()
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
-- Native setters finish the Alt section synchronously, after binding is present.
guid='Player-bank'; binding=2
GameTooltip:ClearLines(); GameTooltip:SetHyperlink(candidate.link)
local shows=0; local show=GameTooltip.Show
GameTooltip.Show=function(self) shows=shows+1; show(self) end
G:Add(GameTooltip); local before=shows; G:Add(GameTooltip)
assert(shows==before,'Unchanged gear text never calls Show again')
A.db.gearAdvisorEnabled=false
GameTooltip:ClearLines(); GameTooltip:SetHyperlink(candidate.link); bagAdvice(); GameTooltip:Show()
assert(GameTooltip.hardcoreBuddyAlt and not GameTooltip.hardcoreBuddyGear)
G:RefreshTooltips(); assert(GameTooltip:IsShown(),'Gear tooltip preference must not hide enabled Alt advice')
local previousHook=hooksecurefunc
hooksecurefunc=function(target,method,callback)
 local original=target[method]
 target[method]=function(self,...) original(self,...); callback(self,...) end
end
local hyperlink=GameTooltip.SetHyperlink
BankButtonIDToInvSlotID=function(index) return 39+index end
GameTooltip.SetBagItem=function(self,bag,slot)
 hyperlink(self,candidate.link)
 if slot==2 then self:AddLine('Soulbound') end
end
GameTooltip.hardcoreBuddyAltHook=nil; Alt.RegisterTooltip(GameTooltip)
GameTooltip:SetBagItem(0,1)
assert(GameTooltip.hardcoreBuddyAlt and not GameTooltip.hardcoreBuddyAltPending,'Alt advice present before first rendered frame')
GameTooltip:SetBagItem(0,2)
assert(not GameTooltip.hardcoreBuddyAlt,'Post-hook sees soulbound instance and excludes it')
GameTooltip:SetBagItem(-1,1)
assert(GameTooltip.hardcoreBuddyAlt,'Main bank container is eligible')
GameTooltip:SetBagItem(5,1)
assert(GameTooltip.hardcoreBuddyAlt,'Bank bags are eligible')
F.equip(40,candidate); GameTooltip:SetInventoryItem('player',40)
assert(GameTooltip.hardcoreBuddyAlt,'Native bank inventory slots are eligible')
F.equip(11,candidate); GameTooltip:SetInventoryItem('player',11)
assert(not GameTooltip.hardcoreBuddyAlt,'Equipped gear is excluded')
GameTooltip:SetHyperlink(candidate.link); Alt:Add(GameTooltip)
assert(not GameTooltip.hardcoreBuddyAlt,'Links and other tooltips have no bag provenance')
C_Container.GetContainerItemLink=function() return nil end
GameTooltip:SetBagItem(0,1); assert(not GameTooltip.hardcoreBuddyAlt,'Missing or stale container contents are excluded')
C_Container.GetContainerItemLink=function() return candidate.link end
C_Container.GetContainerItemInfo=function() return {isBound=true} end
GameTooltip:SetBagItem(0,1); assert(not GameTooltip.hardcoreBuddyAlt,'Native bound flag overrides absent binding text')
C_Container.GetContainerItemInfo=function() return {isBound=false} end
hooksecurefunc=previousHook
local report=G.Report; A.db.gearAdvisorEnabled=true
for _,labels in ipairs({{'Ring 1','Ring 2'},{'Trinket 1','Trinket 2'},{'Main hand','Both hands'}}) do
 G.Report=function() return {rows={{label=labels[1],text='+10%',status='up'},{label=labels[2],text='+20%',status='up'}}} end
 GameTooltip:ClearLines(); hyperlink(GameTooltip,candidate.link)
 local state=GameTooltip.hardcoreBuddyGear
 local prefix=GameTooltip:GetName()..'TextLeft'
 assert(_G[prefix..(state.start+3)]:GetText()==' ' and _G[prefix..(state.start+4)]:GetText()==labels[2],
  'Paired comparisons remain separated without stat losses')
 assert(_G[prefix..(state.start+5)]:GetText()==' ','Final comparison ends with spacing')
end
G.Report=report
GameTooltip:ClearLines(); hyperlink(GameTooltip,candidate.link)
local before=GameTooltip:NumLines()
bagAdvice(); assert(GameTooltip.hardcoreBuddyAlt and GameTooltip:NumLines()>before,'Only actual Alt lines are appended')
for i=1,GameTooltip:NumLines() do
 local region=_G[GameTooltip:GetName()..'TextLeft'..i]
 assert(region:IsShown() and region:GetText()~='', 'No hidden or empty reserved tooltip lines')
end
print('PASS: stable repeated refresh, independent Alt visibility and synchronous binding-safe native setter hooks.')
''')
