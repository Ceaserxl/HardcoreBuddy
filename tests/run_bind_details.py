"""Bind details survive delayed events, unavailable popup APIs and repeated decisions."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT, composite
lua,a=boot()
lua.execute((ROOT/'tests/gear_advisor.lua').read_text())
lua.execute('''
local A,F=TestAddon,GEAR_FIXTURES
local B,G=A.GearBagAdvisor,A.GearAdvisor
F.reset('HUNTER',40,{31,0,0})
local old=F.item('INVTYPE_HEAD',{ITEM_MOD_AGILITY_SHORT=10,ITEM_MOD_STAMINA_SHORT=5},4,3); F.equip(1,old)
local item=F.item('INVTYPE_HEAD',{ITEM_MOD_AGILITY_SHORT=20,ITEM_MOD_STAMINA_SHORT=2},4,3)
local row=G:Comparisons(item,G:CurrentProfile())[1]
local d=CreateFrame('Frame','StaticPopup1',UIParent); d:SetSize(320,90); d:SetPoint('CENTER'); d:SetFrameStrata('DIALOG'); d:Hide()
-- No modern layout methods, no FindVisible, no StaticPopup_Show hook.
StaticPopup_FindVisible=nil; StaticPopup_Visible=nil; StaticPopup_Show=nil
local function prepare() B:PrepareBindDetails({link=item.link,item=item},row) end
local function tick() B.bindWatcher.scripts.OnUpdate(B.bindWatcher,.016) end
local function event(e) B.bindWatcher.scripts.OnEvent(B.bindWatcher,e,999) end
local function verify()
 assert(B.bindDetails:IsVisible() and B.bindDetails:GetParent()==d)
 assert(not d.insertedFrame and d:GetHeight()==90,'Blizzard dialog remains unchanged')
 local _,dy,_,dh=d:GetRect(); local _,fy=B.bindDetails:GetRect(); assert(fy>=dy+dh)
 assert(B.bindDetails.score:GetText():find('Upgrade'))
 assert(B.bindDetails.gains:GetText():find('+10 Agi',1,true))
 assert(B.bindDetails.losses:GetText():find('-3 Sta',1,true))
 assert(not B:Safe(),'No second auto-equip while confirmation is open')
end
prepare(); event('EQUIP_BIND_CONFIRM'); tick(); assert(not B.bindDetails)
MOCK.time=MOCK.time+5; d.which='EQUIP_BIND'; d:Show(); tick(); verify()
MOCK.time=MOCK.time+40; tick(); verify() -- Never expires while the user is deciding.
GameTooltip.SetHyperlink=function(self,link) self.link=link end
B.bindDetails.iconButton.scripts.OnEnter(B.bindDetails.iconButton); assert(GameTooltip.link==item.link)
d:Hide(); assert(not B.pendingBind and not B.bindDetails:IsShown())
d:Show(); tick(); assert(not B.bindDetails:IsShown(),'Reused manual popup has no stale details'); d:Hide()
for _,kind in ipairs({'EQUIP_BIND','EQUIP_BIND_REFUNDABLE','EQUIP_BIND_TRADEABLE'}) do
 prepare(); d.which=kind; d:Show(); tick(); verify(); d:Hide()
end
prepare(); MOCK.time=MOCK.time+31; tick(); assert(not B.pendingBind and not B.bindWatcher:IsShown(),'Failed equip releases watcher')
-- Hook path may omit data or use a different slot token; metadata comes from our equip attempt.
StaticPopup_Show=function(which) d.which=which; d:Show() end
hooksecurefunc=function(name,callback) local fn=_G[name]; _G[name]=function(...) fn(...); callback(...) end end
prepare(); StaticPopup_Show('EQUIP_BIND',nil,nil,nil); verify(); d:Hide()
prepare(); StaticPopup_Show('EQUIP_BIND_TRADEABLE',nil,nil,999); verify(); d:Hide()
-- Visibility API fallback without numbered globals.
StaticPopup1=nil; StaticPopup_Visible=function(which) return nil,d.which==which and d:IsShown() and d or nil end
prepare(); d.which='EQUIP_BIND'; d:Show(); tick(); verify()
print('PASS: delayed popup/event ordering, all three bind types, missing APIs/slot data, repeated accept/cancel cycles, tooltip and timeout cleanup.')
''')
(ROOT/'.release').mkdir(exist_ok=True)
composite(lua.globals().MOCK.frames,a.GearBagAdvisor.bindDetails).save(str(ROOT/'.release/bind-details.png'))
