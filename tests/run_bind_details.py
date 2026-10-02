"""Auto-equip context is inserted inside native binding prompts without accepting them."""
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
local d=CreateFrame('Frame',nil,UIParent); d:SetSize(320,110); d:SetPoint('CENTER'); d:SetFrameStrata('DIALOG'); d:Hide()
A.Skin.Paint(d,'card')
d.Text=d:CreateFontString(nil,'OVERLAY','GameFontHighlight'); d.Text:SetPoint('TOP',d,'TOP',0,-16); d.Text:SetWidth(290); d.Text:SetText('Equipping this item will bind it to you.')
d.ButtonContainer=CreateFrame('Frame',nil,d); d.ButtonContainer:SetSize(260,24)
local accepted,cancelled=0,0
d.accept=CreateFrame('Button',nil,d.ButtonContainer); d.accept:SetSize(120,24); d.accept:SetPoint('TOPLEFT'); d.accept:SetScript('OnClick',function() accepted=accepted+1 end)
d.cancel=CreateFrame('Button',nil,d.ButtonContainer); d.cancel:SetSize(120,24); d.cancel:SetPoint('TOPRIGHT'); d.cancel:SetScript('OnClick',function() cancelled=cancelled+1 end)
local acceptScript,cancelScript=d.accept:GetScript('OnClick'),d.cancel:GetScript('OnClick')
function d:SetupInsertedFrame(frame) frame:SetParent(self) end
-- Native contract: Text -> insertedFrame -> ButtonContainer; native hide releases it.
function d:SetupElementAnchoring()
 local previous=self.Text
 if self.insertedFrame and self.insertedFrame:IsShown() then
  self.insertedFrame:ClearAllPoints(); self.insertedFrame:SetPoint('TOP',previous,'BOTTOM',0,0); previous=self.insertedFrame
 end
 self.ButtonContainer:ClearAllPoints(); self.ButtonContainer:SetPoint('TOP',previous,'BOTTOM',0,-9)
end
function d:Resize()
 self:SetHeight(16+self.Text:GetStringHeight()+(self.insertedFrame and self.insertedFrame:GetHeight() or 0)+9+24+16)
end
d:SetScript('OnHide',function(self)
 if self.insertedFrame then self.insertedFrame:Hide(); self.insertedFrame:SetParent(nil); self.insertedFrame=nil end
end)
StaticPopup_Show=function(which,_,_,slot) d.which=which; d.data=slot; d:Show(); d:SetupElementAnchoring(); d:Resize(); return d end
StaticPopup_FindVisible=function(which) return d:IsShown() and d.which==which and d end
hooksecurefunc=function(name,callback) local fn=_G[name]; _G[name]=function(...) local r=fn(...); callback(...); return r end end
B:PrepareBindDetails({link=item.link,item=item},row)
StaticPopup_Show('EQUIP_BIND',nil,nil,2); assert(not B.bindDetails,'Wrong target slot not decorated')
StaticPopup_Show('EQUIP_BIND',nil,nil,1)
assert(B.bindDetails:IsVisible() and d.insertedFrame==B.bindDetails and B.bindDetails:GetParent()==d)
assert(not B.bindDetails.backdrop,'Details do not create a second bordered window')
local dx,dy,dw,dh=d:GetRect(); local fx,fy,fw,fh=B.bindDetails:GetRect()
local _,buttonY=d.ButtonContainer:GetRect()
assert(fx>=dx and fx+fw<=dx+dw and fy>=dy and fy+fh<buttonY and buttonY+24<=dy+dh)
local height=d:GetHeight(); d:Resize(); assert(d:GetHeight()==height,'Native relayout does not duplicate height')
assert(d.accept:GetScript('OnClick')==acceptScript and d.cancel:GetScript('OnClick')==cancelScript)
assert(accepted==0 and cancelled==0,'Showing details does not accept or cancel binding')
assert(B.bindDetails.score:GetText():find('Upgrade'))
assert(B.bindDetails.gains:GetText():find('+10 Agi',1,true))
assert(B.bindDetails.losses:GetText():find('-3 Sta',1,true))
assert(not B:Safe(),'Do not replace a pending binding decision')
local originalLink=GameTooltip.SetHyperlink
GameTooltip.SetHyperlink=function(self,link) self.link=link end
B.bindDetails.iconButton.scripts.OnEnter(B.bindDetails.iconButton)
assert(GameTooltip.link==item.link)
B.bindDetails.iconButton.scripts.OnLeave(B.bindDetails.iconButton)
d:Hide(); assert(not B.bindDetails:IsShown() and not d.insertedFrame)
StaticPopup_Show('EQUIP_BIND',nil,nil,1); assert(not B.bindDetails:IsShown(),'Manual prompt never reuses stale details')
B:PrepareBindDetails({link=item.link,item=item},row); StaticPopup_Show('EQUIP_BIND',nil,nil,1)
print('PASS: binding slot association, icon tooltip, score/stat details, no auto-accept, and cleanup on popup reuse.')
''')
composite(lua.globals().MOCK.frames,a.GearBagAdvisor.bindDetails.GetParent(a.GearBagAdvisor.bindDetails)).save(str(ROOT/'.release/bind-details.png'))
