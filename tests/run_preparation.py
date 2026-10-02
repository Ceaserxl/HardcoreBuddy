"""Preparation priorities, weapon-aware stock, rest transitions and alert styling."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local R,S,M,H=A.Readiness,A.Supplies,A.Ammunition,A.Deaths
assert(R.settings.panel and R.settings.departure)
assert(A.LowHealth.settings.enabled,"Low health stays enabled by default")
A:Navigate("supplies"); A.state.filter="Essentials"; A:Refresh()
assert(A.document.cards[1].title=="Essentials")
local c=A:GetContext()
c.level=60; c.characterClass="Hunter"; c.mode="preview"; c.previewAmmo="arrows"
local seen={}
for _,r in ipairs(S.Build(c)) do seen[r.family]=r end
for _,family in ipairs({"recovery","drink","healing","wellfed","Swiftness Potion","Swim Speed Potion","ammunition"}) do
    assert(seen[family] and seen[family].priority=="Essentials",family)
end
for _,family in ipairs({"Flask of Petrification","Free Action Potion","Limited Invulnerability Potion","Restorative Potion"}) do
    assert(seen[family] and seen[family].priority=="Advanced",family)
end
assert(seen.invisibility.priority=="Optional")
assert(seen["Light of Elune"].target==0,"Do not demand an unavailable one-time quest reward")
local food=seen.recovery.item
A:CyclePriority(food)
assert(S.Priority(A:GetContext(),food)=="Advanced")
A:CyclePriority(food); A:CyclePriority(food)
assert(S.Priority(A:GetContext(),food)=="Essentials")
A:Activate({kind="item",item=food})
assert(A.window.priorityChoice:IsShown())
MOCK.Click(A.window.priorityChoice)
assert(S.Priority(A:GetContext(),food)=="Advanced")
A:CyclePriority(food); A:CyclePriority(food)

-- Live arrows/bullets follow the actual weapon and selected ammo. A wand never needs ammo.
local ranged,selected,stack=10001,3030,0
local subclasses={[10001]=2,[10002]=3,[10003]=18,[10004]=19,[3108]=16}
GetInventoryItemID=function(_,slot) return slot==18 and ranged or slot==0 and selected or nil end
GetInventoryItemCount=function(_,slot) assert(slot==18); return stack end
C_Item.GetItemInfoInstant=function(id)
    local sub=subclasses[id]
    if sub then return id,nil,nil,nil,nil,2,sub end
    return id,nil,nil,nil,nil,6,id==3033 and 3 or 2
end
C_Item.GetItemInfo=function(id)
    local item=M.items[id]
    if item then return item.name,nil,1,1,item.level,nil,nil,nil,nil,1234 end
end
c.mode="live"; c.inventory={available=true,counts={[3030]=650,[3033]=90,[3108]=20}}
local ammo=M.Recommend(c); assert(ammo.itemId==3030 and ammo.ammoKind=="arrows")
assert(S.Record(c,ammo).count==650,"Equipped arrow selection is not a second stack")
ranged=10003; assert(M.Recommend(c).ammoKind=="arrows")
ranged=10002; selected=3033; assert(M.Recommend(c).ammoKind=="bullets")
local cached=C_Item.GetItemInfo
C_Item.GetItemInfo=function() return nil end
assert(M.Recommend(c)==nil,"Uncached selected ammo must not become a guessed shortage")
C_Item.GetItemInfo=cached
ranged=10004; assert(M.Recommend(c)==nil,"Wands need no ammunition")
ranged=3108; selected=nil; stack=73
ammo=M.Recommend(c); assert(ammo.itemId==3108)
assert(S.Record(c,ammo).count==93,"Equipped thrown stack counted exactly once")
c.inventory.available=false; assert(S.Record(c,ammo).count==nil)
c.inventory.available=true
c.characterClass="Mage"; assert(M.Recommend(c)==nil)
c.characterClass="Rogue"; assert(S.Record(c,ammo).target==100)
c.mode="preview"; c.previewAmmo="bullets"; c.level=24
assert(M.Recommend(c).itemId==2519); c.level=25; assert(M.Recommend(c).itemId==3033)
c.previewAmmo="thrown"; c.level=34; assert(M.Recommend(c).itemId==3108)
c.level=35; assert(M.Recommend(c).itemId==15327)
c.previewAmmo="none"; assert(M.Recommend(c)==nil)
A:SetCarryTarget(3033,2200); assert(A.characterDB.targets[3033]==2200)
assert(S.NormalizeTarget(999)==200 and S.NormalizeTarget(99999,10000)==10000)
A:Activate({kind="item",item=ammo})
assert(A.document.isDetail and A.window.priorityChoice:IsShown(),"Ammunition has complete item details")

-- Rest reminders use the real character while the user is planning an alt.
local resting,combat,now=false,false,1000
IsResting=function() return resting end
InCombatLockdown=function() return combat end
GetTime=function() return now end
UnitOnTaxi=function() return false end
UnitIsDeadOrGhost=function() return false end
IsInInstance=function() return false,"none" end
A.db.profile.mode="preview"; A.db.profile.characterClass="Mage"; A.db.profile.level=60
assert(R:LiveContext().characterClass=="Hunter" and R:LiveContext().mode=="live")
local live=R:LiveContext()
live.inventory={available=false,counts={}}
assert(#R:Missing(live)==0,"Unknown bags are never missing")
assert(#R:Missing(nil)==0,"Unknown live character never becomes missing")
live.inventory={available=true,counts={}}; live.targets={}
for _,r in ipairs(S.Build(live,{filter="Essentials"})) do live.targets[r.itemId]=0 end
assert(#R:Missing(live)==0,"Carry 0 skips restocking")
R.settings.panel=true; R.settings.departure=true
R:Refresh(); assert(not R.toast:IsShown(),"No login departure")
resting=true; R:Refresh(); assert(R.panel:IsShown())
-- Priority and quantity edits do not fire bag events, but must update this frame.
local missing=R:Missing(R:LiveContext()); local edited=missing[1]
local originalTarget=A.characterDB.targets[edited.itemId]
A:CyclePriority(edited.item)
assert(R.refreshAt==now,"Priority change schedules readiness refresh immediately")
R.events.scripts.OnUpdate(R.events)
assert(not R.refreshAt and #R:Missing(R:LiveContext())==#missing-1,"Priority removes the essential on the next frame")
assert(R.panel.summary:GetText()==(#missing-1).." supplies below target","Visible panel updates without a bag event")
A:CyclePriority(edited.item); A:CyclePriority(edited.item)
R.events.scripts.OnUpdate(R.events)
assert(R.panel.summary:GetText()==#missing.." supplies below target","Changing back restores the essential")
A:SetCarryTarget(edited.itemId,0); R.events.scripts.OnUpdate(R.events)
assert(R.panel.summary:GetText()==(#missing-1).." supplies below target","Quantity changes also refresh the panel")
A:SetCarryTarget(edited.itemId,originalTarget); R.events.scripts.OnUpdate(R.events)
local opens=0; local originalOpen=R.Open
R.Open=function() opens=opens+1 end
R.panel.scripts.OnDragStart(R.panel)
assert(R.dragging)
R:Refresh(); assert(R.dragging and R.panel:IsShown(),"Bag refresh must not interrupt a drag")
R.panel:ClearAllPoints(); R.panel:SetPoint("CENTER",UIParent,"CENTER",123,45)
R.panel.scripts.OnDragStop(R.panel)
assert(not R.dragging and R.settings.position.x==123 and R.settings.position.y==45)
local x,y=R.panel:GetRect()
MOCK.ClickAt(x+15,y+16); assert(opens==0,"Releasing a drag must not open Supplies")
now=now+1; MOCK.ClickAt(x+15,y+16); assert(opens==0,"Panel clicks do not open Supplies")
MOCK.Click(R.panel.review); assert(opens==1,"Review button opens Supplies")
R.panel.scripts.OnDragStart(R.panel); combat=true; R:Refresh()
assert(not R.dragging and not R.panel:IsShown(),"Unsafe hide stops and saves movement")
combat=false; R:Refresh(); R.Open=originalOpen
MOCK.Click(R.panel.close); R:Refresh(); assert(not R.panel:IsShown(),"Dismiss for this visit")
resting=false; R:Refresh(); assert(R.toast:IsShown() and R.lastReminder==now)
R.toast:Hide(); resting=true; R:Refresh(); assert(R.panel:IsShown())
resting=false; now=now+10; R:Refresh(); assert(not R.toast:IsShown(),"Boundary oscillation is throttled")
resting=true; R:Refresh(); combat=true; resting=false; now=now+310; R:Refresh()
assert(not R.panel:IsShown() and not R.toast:IsShown(),"No reminders during combat")
combat=false; now=now+21; R:Refresh(); assert(not R.toast:IsShown(),"Do not replay stale departures")
resting=true; R:Refresh(); resting=false; now=now+1; R:Refresh(); assert(R.toast:IsShown())
R.toast.scripts.OnUpdate(R.toast,4.25); assert(R.toast:GetAlpha()==0.5)
MOCK.Click(R.toast); assert(A.state.filter=="Essentials" and A.db.profile.mode=="live")
A:Navigate("alerts"); A.state.filter="Preparation"; A:Refresh()
assert(R.options:IsVisible())

-- Compact is the new default; all backgrounds fade independently of text.
assert(H.db.settings.alertStyle=="Compact")
A:OpenDeaths("Appearance"); assert(H.appearance:IsVisible() and not H.window:IsShown())
local record={name="Lilyrae",level=36,zone="Kolkar Village",cause="Kolkar Windchaser"}
for _,entry in ipairs({{"Compact",520,58},{"Banner",896,80},{"Text-only",520,52}}) do
    H.db.settings.alertStyle=entry[1]; H.db.settings.backgroundOpacity=25; H:ApplySettings(); H:ShowAlert(record,true)
    assert(H.alert:GetWidth()==entry[2] and H.alert:GetHeight()==entry[3])
    assert(H.alert.name:GetAlpha()==1 and H.alert:GetAlpha()==1,"Text remains readable")
    assert(H.alert.art:GetAlpha()==0.25 and H.alert.flat:GetAlpha()==0.25)
    assert(H.alert.art:IsShown()==(entry[1]=="Banner"))
    assert(H.alert.flat:IsShown()==(entry[1]=="Compact"))
end
local played=0; local play=H.PlayAlertSound
H.PlayAlertSound=function() played=played+1 end
H.db.positions.alert=nil; H:ApplySettings()
local beforeX,beforeY=H.alert:GetCenter()
H:TogglePositioning(); H:FinishPositioning()
local afterX,afterY=H.alert:GetCenter()
assert(math.abs(beforeX-afterX)<0.01 and math.abs(beforeY-afterY)<0.01,"Save without dragging must not jump")
H:TogglePositioning(); assert(H.alert.positioning and H.alert:IsShown() and H.alert.done:IsShown())
H.alert.scripts.OnUpdate(H.alert,60); assert(H.alert:IsShown() and H.alert:GetAlpha()==1)
assert(played==0,"Positioning preview is silent")
H.alert:ClearAllPoints(); H.alert:SetPoint("CENTER",UIParent,"CENTER",123,47)
MOCK.Click(H.alert.done)
assert(H.db.settings.locked and not H.alert.positioning and not H.alert:IsShown())
assert(H.db.positions.alert[3]==123 and H.db.positions.alert[4]==47)
H:ApplySettings(); local _,_,_,x,y=H.alert:GetPoint(); assert(x==123 and y==47)
H.db.settings.alertStyle="invalid"; H.db.settings.backgroundOpacity="invalid"; H:ApplySettings()
assert(H.db.settings.alertStyle=="Compact" and H.db.settings.backgroundOpacity==65)
H.PlayAlertSound=play
print("PASS: supply priorities and overrides, ammo/weapon routing and counts, restock boundaries, quiet notifications, death styles and movable preview.")
''')

# Restore only serialized character/account data into a clean Lua runtime.
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
def plain(value):
    return {key: plain(child) for key, child in value.items()} if hasattr(value, 'items') else value
fresh = LuaRuntime(unpack_returned_tuples=True)
restored = fresh.table()
for file in ('tests/wow_mock.lua', 'tests/deaths_mock.lua'):
    fresh.execute((root / file).read_text(encoding='utf-8'))
fresh.globals().HardcoreBuddyDB = fresh.table_from(plain(addon.db), recursive=True)
fresh.globals().HardcoreBuddyCharacterDB = fresh.table_from(plain(addon.characterDB), recursive=True)
for file in (root / 'HardcoreBuddy.toc').read_text().splitlines():
    if file and not file.startswith('#'):
        fresh.execute((root / file.replace('\\', '/')).read_text(encoding='utf-8'), 'HardcoreBuddy', restored)
fresh.globals().TestAddon = restored
fresh.globals().MOCK.FireAll('ADDON_LOADED', 'HardcoreBuddy')
fresh.execute('''
local A=TestAddon
assert(A.characterDB.targets[3033]==2200)
assert(A.characterDB.priorities.recovery=="Essentials")
assert(A.Readiness.settings.panel and A.Readiness.settings.departure)
local _,_,_,rx,ry=A.Readiness.panel:GetPoint()
assert(rx==123 and ry==45,"Missing essentials position survives a fresh login")
assert(A.Deaths.db.settings.alertStyle=="Compact" and A.Deaths.db.settings.backgroundOpacity==65)
assert(A.Deaths.db.positions.alert[3]==123 and A.Deaths.db.positions.alert[4]==47)
assert(not A.Readiness.toast:IsShown() and not A.Deaths.alert.positioning)
print("PASS: Fresh-runtime restoration of priorities, ammo targets, preparation settings and death appearance/position.")
''')
