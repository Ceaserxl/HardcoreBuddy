"""Auto-equip context attaches to native binding prompts without accepting them."""
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
local old=F.item('INVTYPE_HEAD',{ITEM_MOD_AGILITY_SHORT=10,ITEM_MOD_STAMINA_SHORT=5},4,3)
F.equip(1,old)
local item=F.item('INVTYPE_HEAD',{ITEM_MOD_AGILITY_SHORT=20,ITEM_MOD_STAMINA_SHORT=2},4,3)
local row=G:Comparisons(item,G:CurrentProfile())[1]
local d=CreateFrame('Frame',nil,UIParent); d:SetSize(380,110); d:SetPoint('CENTER'); d:SetFrameStrata('DIALOG'); d:Hide()
StaticPopup_Show=function(which,_,_,slot) d.which=which; d.data=slot; d:Show(); return d end
StaticPopup_FindVisible=function(which) return d:IsShown() and d.which==which and d end
hooksecurefunc=function(name,callback) local fn=_G[name]; _G[name]=function(...) local r=fn(...); callback(...); return r end end
B:PrepareBindDetails({link=item.link,item=item},row)
StaticPopup_Show('EQUIP_BIND',nil,nil,2); assert(not B.bindDetails,'Wrong target slot not decorated')
StaticPopup_Show('EQUIP_BIND',nil,nil,1)
assert(B.bindDetails:IsVisible() and B.bindDetails:GetParent()==d)
assert(B.bindDetails.score:GetText():find('Upgrade'))
assert(B.bindDetails.gains:GetText():find('+10 Agi',1,true))
assert(B.bindDetails.losses:GetText():find('-3 Sta',1,true))
assert(not B:Safe(),'Do not replace a pending binding decision')
local originalLink=GameTooltip.SetHyperlink
GameTooltip.SetHyperlink=function(self,link) self.link=link end
B.bindDetails.iconButton.scripts.OnEnter(B.bindDetails.iconButton)
assert(GameTooltip.link==item.link)
B.bindDetails.iconButton.scripts.OnLeave(B.bindDetails.iconButton)
d:Hide(); assert(not B.bindDetails:IsShown())
StaticPopup_Show('EQUIP_BIND',nil,nil,1); assert(not B.bindDetails:IsShown(),'Manual prompt never reuses stale details')
B:PrepareBindDetails({link=item.link,item=item},row); StaticPopup_Show('EQUIP_BIND',nil,nil,1)
print('PASS: binding slot association, icon tooltip, score/stat details, no auto-accept, and cleanup on popup reuse.')
''')
composite(lua.globals().MOCK.frames,a.GearBagAdvisor.bindDetails).save(str(ROOT/'.release/bind-details.png'))
