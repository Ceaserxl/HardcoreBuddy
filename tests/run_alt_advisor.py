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
local timestamp=1800000000
time=function() return timestamp end
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
assert(A.db.altEquipment[guid].equipment[11].unavailable,'A changed item cannot retain the old scored baseline while loading')
assert(A.db.altEquipment[guid].equipment[12].stats.ITEM_MOD_INTELLECT_SHORT==10,'The exact unchanged item retains its scored data while loading')
G.Equipped=old; assert(Alt:Capture()); guid='Player-bank'
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
local altStart=vendorLine+2
assert(_G[prefix..altStart]:GetText():find('SurvivorShield.tga',1,true),'Alt title includes shield icon')
assert(_G[prefix..vendorLine]:GetText()=='Vendor prices','Existing vendor text preserved')
assert(GameTooltip:NumLines()==altStart+3 and _G[prefix..(altStart+3)]:GetText()~=' ','Alt section ends on its final character, without a blank line')
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
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',11,false)
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
 assert(GameTooltip:NumLines()==state.start+4,'No blank line after the final comparison')
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

-- Final capture cannot abort the whole character because one tooltip is loading.
F.reset('MAGE',40,{0,0,31}); guid='Player-cache-logout'
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
local worn=F.item('INVTYPE_FINGER',{ITEM_MOD_INTELLECT_SHORT=10},4,0)
local head=F.item('INVTYPE_HEAD',{ITEM_MOD_INTELLECT_SHORT=5},4,1)
F.equip(12,worn); assert(Alt:Capture())
assert(A.db.altEquipment[guid].equipment[11]==false)
F.equip(11,worn); F.equip(1,head); head.loading=true
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',11)
assert(Alt.pending,'Normal equipment reads are debounced')
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT') -- no OnUpdate before exit
local cached=A.db.altEquipment[guid]
assert(cached.equipment[11].id==worn.id and cached.equipment[12].id==worn.id,
 'Logout writes newly filled slots even with an unrelated loading head item')
assert(cached.equipment[1].unavailable and cached.equipment[1].id==head.id,
 'Loading occupied equipment is recorded as unknown, never empty')
assert(not Alt.pending,'Logout performs its final read synchronously')
guid='Player-bank'
for _,entry in ipairs(Alt:Upgrades(G:Read(candidate.link))) do
 if entry.character.name=='Player-cache-logout' then
  assert(entry.row.percent==100 and not entry.row.zeroBaseline,'Other characters compare against final worn rings')
 end
end
-- Removing equipment at the last instant also replaces a stale occupied slot.
guid='Player-cache-logout'; F.equip(11,nil)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',11,false)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[11]==false,'Final empty slot persists despite another loading item')
F.equip(11,worn); worn.loading=true
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[11].unavailable,'Fresh occupied slot replaces old false even before its item data arrives')
local offline=G:Comparisons(G:Read(candidate.link),A.db.altEquipment[guid].profile,nil,A.db.altEquipment[guid].equipment)
assert(offline[1].status=='unknown' and offline[2].percent==100,
 'Unknown occupied slot is excluded; unchanged same-link scored slot remains usable')
-- Late item information must restart retries after the normal retry budget.
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',11)
for i=1,10 do Alt.events.scripts.OnUpdate(Alt.events,2) end
assert(not Alt.pending and Alt.incomplete and Alt.attempts==10)
worn.loading=false; head.loading=false
Alt.events.scripts.OnEvent(Alt.events,'GET_ITEM_INFO_RECEIVED',worn.id,true)
assert(Alt.pending,'Item data arrival restarts an exhausted incomplete capture')
Alt.events.scripts.OnUpdate(Alt.events,1)
assert(not Alt.incomplete and A.db.altEquipment[guid].equipment[11].stats,'Late data resolves unknown equipment')
-- The item variant must match, not just its item ID (random suffixes differ).
local variant={}
for k,v in pairs(worn) do variant[k]=v end
variant.link=worn.link:gsub(':-15:',':-16:'); variant.loading=true; F.alias(variant.link,variant); F.equip(11,variant)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[11].unavailable and A.db.altEquipment[guid].equipment[11].link==variant.link,
 'An unresolved same-ID different-suffix item never reuses old stats')
-- Unknown dependent weapon slots must also suppress combined/unique comparisons.
local p=A.db.altEquipment[guid].profile
local unknown={id=999,unavailable=true}
assert(G:Comparisons(two,p,nil,{[16]=unknown,[17]=false})[1].status=='unknown')
assert(G:Comparisons(two,p,nil,{[16]=G:Read(worn.link),[17]=unknown})[1].status=='unknown')
local uniqueCandidate=G:Read(candidate.link); uniqueCandidate.unique=true
for _,row in ipairs(G:Comparisons(uniqueCandidate,p,nil,{[11]=false,[12]=unknown})) do
 assert(row.status=='unknown','Unknown paired slot cannot establish unique-item eligibility')
end
-- Keep one incomplete character and one complete character for reload verification.
guid='Player-cache-complete'; F.equip(11,worn)
A.db.gearAdvisorActive=false; A.db.altAdvisorEnabled=false
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[11].id==worn.id,'Disabling tooltip advice does not disable final equipment caching')
ALT_RELOAD_CANDIDATE=G:Read(candidate.link)
print('PASS: final logout reads, partial item loading, filled/emptied slots, variant identity, late retries and dependent slots.')

-- Reproduce real saved characters whose entire equipment table became false.
F.reset('MAGE',40,{0,0,31}); guid='Player-shoulders'
local shoulders=F.item('INVTYPE_SHOULDER',{ITEM_MOD_INTELLECT_SHORT=10},4,1)
local upgrade=F.item('INVTYPE_SHOULDER',{ITEM_MOD_INTELLECT_SHORT=20},4,1)
F.equip(3,shoulders); F.equip(1,head); assert(Alt:Capture())
local live=A.db.altEquipment[guid]
local inventoryID,inventoryLink=GetInventoryItemID,GetInventoryItemLink
GetInventoryItemID=function() return nil end; GetInventoryItemLink=function() return nil end
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LEAVING_WORLD')
for slot in pairs(live.equipment) do Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',slot,false) end
Alt.events.scripts.OnUpdate(Alt.events,1)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid]==live and live.equipment[3].id==shoulders.id,
 'Inventory teardown cannot overwrite live shoulders or advance the snapshot timestamp')
assert(not Alt:Capture() and A.db.altEquipment[guid]==live,'An all-nil live read is also unavailable, not naked')
guid='Player-not-loaded'; assert(not Alt:Capture() and not A.db.altEquipment[guid],
 'An unavailable first read must not create an all-empty character')
guid='Player-shoulders'
GetInventoryItemID=function(unit,slot) if slot~=3 then return inventoryID(unit,slot) end end
GetInventoryItemLink=function(unit,slot) if slot~=3 then return inventoryLink(unit,slot) end end
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[3].id==shoulders.id,'Partial logout teardown preserves the last live slot')
GetInventoryItemID=inventoryID; GetInventoryItemLink=inventoryLink
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
assert(Alt:Capture())
local damaged={schema=1,name='Damaged',realm='Realm',faction='Alliance',profile=live.profile,equipment={}}
for slot in pairs(live.equipment) do damaged.equipment[slot]=false end
A.db.altEquipment['Player-damaged']=damaged
guid='Player-bank'
local found=false
for _,entry in ipairs(Alt:Upgrades(G:Read(upgrade.link))) do
 assert(entry.character~=damaged,'Legacy all-empty corruption never produces Empty slot advice')
 if entry.character.name=='Player-shoulders' then
  found=true; assert(entry.row.percent==100,'Shoulders compare with the saved worn item after logout')
 end
end
assert(found)
assert(G:Comparisons(G:Read(upgrade.link),live.profile,nil,{})[1].status=='unknown',
 'An absent cached slot is unknown; only explicit false means empty')
-- A real unequip remains distinguishable, including removing the final item.
guid='Player-shoulders'; F.equip(3,nil)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',3,false)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].equipment[3]==false,'A confirmed shoulder removal is saved')
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
F.equip(1,nil); Alt.events.scripts.OnEvent(Alt.events,'PLAYER_EQUIPMENT_CHANGED',1,false)
Alt.events.scripts.OnEvent(Alt.events,'PLAYER_LOGOUT')
assert(A.db.altEquipment[guid].schema==2 and A.db.altEquipment[guid].equipment[1]==false,
 'Confirmed removal of every item still saves a genuinely empty character')
assert(G:Comparisons(G:Read(upgrade.link),live.profile,nil,A.db.altEquipment[guid].equipment)[1].text=='Upgrade: empty slot')
-- Replace a damaged legacy character by logging in with its actual equipment.
guid='Player-damaged'; F.equip(3,shoulders); Alt.events.scripts.OnEvent(Alt.events,'PLAYER_ENTERING_WORLD')
Alt.events.scripts.OnUpdate(Alt.events,1)
assert(A.db.altEquipment[guid].schema==2 and A.db.altEquipment[guid].equipment[3].id==shoulders.id)
print('PASS: complete/partial inventory teardown, invalid legacy snapshots, real shoulders, genuine unequips and cache repair.')
-- Age filtering preserves real empty-slot upgrades and does not delete snapshots.
guid='Player-bank'
local empty=A.db.altEquipment['Player-shoulders']
local function contains(character)
 for _,entry in ipairs(Alt:Upgrades(G:Read(upgrade.link))) do
  if entry.character==character then return entry end
 end
end
assert(Alt:CacheDays()==7 and contains(empty).row.text=='Upgrade: empty slot','Fresh empty slots are still advertised')
empty.updated=timestamp-7*86400
assert(contains(empty),'Snapshot at the exact age limit is still current')
empty.updated=empty.updated-1
assert(not contains(empty) and A.db.altEquipment['Player-shoulders']==empty,'Expired gear is hidden, not erased')
assert(Alt:SetCacheDays(30) and contains(empty),'Increasing the age limit restores eligible cached advice')
for _,value in ipairs({0,-1,366,1.5,'invalid'}) do assert(not Alt:SetCacheDays(value)) end
assert(Alt:CacheDays()==30,'Invalid settings do not replace the saved cutoff')
empty.updated=nil; assert(not contains(empty),'Undated snapshots are unavailable')
empty.updated=timestamp+1; assert(not contains(empty),'Invalid future timestamps are unavailable')
empty.updated=timestamp; assert(contains(empty),'Refreshing restores valid empty slots')
assert(Alt:SetCacheDays(7))
A.db.altAdvisorEnabled=true; A.db.gearAdvisorActive=true
A:OpenSettings('Gear Advisor')
local page=A.Settings.pages['Gear Advisor']; local edit=page.altCacheDays
assert(edit:GetText()=='7' and edit:IsEnabled())
edit:SetFocus(); edit:SetText('14'); edit.scripts.OnEnterPressed(edit)
assert(Alt:CacheDays()==14,'Settings field persists the chosen age')
edit:SetFocus(); edit:SetText('30'); edit.scripts.OnEscapePressed(edit)
assert(Alt:CacheDays()==14 and edit:GetText()=='14','Escape cancels an age edit')
edit:SetFocus(); edit:SetText('400'); edit.scripts.OnEnterPressed(edit)
assert(Alt:CacheDays()==14 and edit:GetText()=='14','Invalid input restores the last valid age')
page.alts:SetChecked(false); MOCK.Click(page.alts)
assert(not edit:IsEnabled() and edit:GetAlpha()<1,'Disabled Alt Advisor dims and disables its dependent age control')
page.alts:SetChecked(true); MOCK.Click(page.alts)
assert(edit:IsEnabled())
assert(Alt:SetCacheDays(7))
print('PASS: fresh empty-slot upgrades, age boundaries, stale/invalid dates, cache retention and editable settings dependencies.')
''')

def plain(value):
    if hasattr(value, 'items'):
        return {k: plain(v) for k, v in value.items()}
    return value

account = plain(lua.globals().HardcoreBuddyDB)
candidate = plain(lua.globals().ALT_RELOAD_CANDIDATE)
fresh, _ = boot()
fresh.globals().HardcoreBuddyDB = fresh.table_from(account, recursive=True)
fresh.globals().AltReloadCandidate = fresh.table_from(candidate, recursive=True)
fresh.execute('time=function() return 1800000000 end')
fresh.execute('''
TestAddon:Initialize()
assert(TestAddon.AltAdvisor:CacheDays()==7 and TestAddon.db.altAdvisorCacheDays==7,'Configured cache cutoff survives SavedVariables reload')
UnitGUID=function() return 'Player-bank' end
GetRealmName=function() return 'Realm' end
UnitFactionGroup=function() return 'Alliance' end
local cache=TestAddon.db.altEquipment
assert(cache['Player-cache-logout'].equipment[11].unavailable,'Unknown occupied slot survives SavedVariables round trip')
assert(cache['Player-cache-complete'].equipment[11].stats,'Final scored gear survives SavedVariables round trip')
local found=false
for _,entry in ipairs(TestAddon.AltAdvisor:Upgrades(AltReloadCandidate)) do
 if entry.character.name=='Player-cache-complete' then
  found=true; assert(entry.row.percent==100 and not entry.row.zeroBaseline,'Fresh bank-character session uses final scored gear')
 end
end
assert(found)
''')
print('PASS: final equipment and unknown occupied slots persist into a fresh bank-character runtime.')
