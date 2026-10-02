"""Missing Essentials presentation and isolated, repeatable previews."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local R=A.Readiness
local now=100; GetTime=function() return now end
local combat=false; InCombatLockdown=function() return combat end
IsResting=function() return false end
IsInInstance=function() return false,"none" end
R.settings.panel=false; R.settings.departure=false; R.resting=false; R.dismissed=true; R.lastReminder=77
A:OpenSettings("General")
local options=R.options
assert(options.previewPanel:IsVisible() and options.previewReminder:IsVisible())
assert(not options.previewPanel:IsEnabled() and not options.previewReminder:IsEnabled(),"Disabled features disable their preview controls")
R.settings.panel=true; R.settings.departure=true; A:Refresh()
MOCK.Click(options.previewPanel)
assert(R.panel:IsShown() and R.previewUntil==120)
assert(R.panel:GetFrameStrata()=="DIALOG" and R.panel:GetFrameLevel()>A.window:GetFrameLevel())
assert(R.panel.summary:GetText()=="Preview | Example supplies")
for i=1,5 do
 local row=R.panel.rows[i]
 assert(row:IsVisible() and row.name:GetText()~="" and not row.stock)
 assert(row.need:GetText():match("^%(%d+/%d+%)$"))
 local x,y,w,h=row:GetRect()
 assert(MOCK.HitTest(x+w/2,y+h/2)==row,"Vendor target rows receive their own clicks")
 local state=A.state
 MOCK.ClickAt(x+w/2,y+h/2)
 assert(A.state==state and not R.panel.scripts.OnClick,"Row clicks do not navigate")
end
assert(#R.panel.rows==5 and R.panel:GetHeight()==282,'Five compact rows fit in the panel')
R:Refresh(); assert(R.panel:IsShown(),"Bag/rest refresh preserves preview")
assert(R.settings.panel and R.settings.departure and R.dismissed and R.lastReminder==77)
MOCK.Click(R.panel.close)
assert(not R.panel:IsShown() and not R.previewUntil and R.dismissed,"Preview close preserves normal dismissal")
MOCK.Click(options.previewPanel); now=121; R.panel.scripts.OnUpdate(R.panel,21)
assert(not R.panel:IsShown() and not R.previewUntil,"Panel preview expires")
MOCK.Click(options.previewReminder)
assert(R.toast:IsShown() and R.toast.title:GetText():find("Preview:",1,true))
assert(R.lastReminder==77 and not R.departure,"Preview does not consume reminder cooldown")
R.toast.scripts.OnUpdate(R.toast,4.5); assert(not R.toast:IsShown())
MOCK.Click(options.previewReminder); assert(R.toast.elapsed==0 and R.toast:GetAlpha()==1)
combat=true; R:Refresh(); assert(not R.panel:IsShown() and not R.toast:IsShown())
MOCK.Click(options.previewPanel); assert(not R.panel:IsShown())
combat=false; MOCK.Click(options.previewPanel)
local x,y,w,h=R.panel.review:GetRect()
assert(MOCK.HitTest(x+w/2,y+h/2)==R.panel.review,"Review is above the panel click target")
MOCK.Click(R.panel.review)
assert(A.state.view=="supplies" and A.state.filter=="Essentials" and R.previewUntil and R.panel:IsShown(),"Review opens Essentials without dismissing the panel")
R:Refresh(); assert(R.panel:IsShown(),"Preview remains visible after reviewing supplies")
local rows={}
for i=1,6 do rows[i]={itemId=117,name="Example "..i,count=i,target=20,missing=20-i} end
R:ShowPanel(rows)
assert(R.panel.rows[5]:IsShown() and R.panel.more:GetText()=="+ 1 more in Essentials")
assert(not R.panel.hint:IsShown(),'Overflow shares the footer instead of adding empty height')
R:ShowPanel({rows[1]})
assert(not R.panel.rows[2]:IsShown() and not R.panel.more:IsShown(),"Rows and overflow hide on refresh")
print("PASS: Preview controls, layout rows, sample labeling, layering, expiry, cooldown isolation, combat and Review navigation.")
''')
