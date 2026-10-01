"""One fixed, clickable Back control for nested pages across the main window."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local f=A.window
assert(A.state.view=="supplies" and A.state.filter=="All","First open defaults to All supplies")
A:Navigate("supplies"); assert(A.state.filter=="All","Supplies navigation defaults to All")
local function back()
    assert(f.back:IsVisible(),"Shared Back is hidden")
    local x,y,w,h=f.back:GetRect()
    local wx,wy,ww=f:GetRect()
    local _,contentTop=f.sidebar:GetRect()
    assert(x==wx+(A.state.view=="deaths" and 22 or 184) and y==contentTop,"Back is not above the left edge of the content")
    assert(MOCK.HitTest(x+w/2,y+h/2)==f.back,"Back cannot be clicked")
    for _,tab in ipairs(f.tabs) do
        local tx,ty,tw,th=tab:GetRect()
        assert(x>=tx+tw or y>=ty+th or x+w<=tx or y+h<=ty,"Tab overlaps Back")
    end
    MOCK.Click(f.back)
end
for _,page in ipairs({"Stat Weights"}) do
    A:OpenSettings("Gear Advisor"); A.Settings:OpenGearPage(page)
    A.Settings.scroll:SetVerticalScroll(100)
    back(); assert(not A.state.gearPage and A.state.filter=="Gear Advisor")
end
A:Navigate("petguide"); back(); assert(A.state.view=="training")
A:HandleSlashCommand("talents"); A:Activate({kind="advisor",command="path"})
back(); assert(A.state.filter=="Talents" and not A.state.talentPath)
A:OpenSettings("Map"); MOCK.Click(A.MapAdvisor.controls.icons.rare)
back(); assert(A.state.filter=="Map" and not A.state.mapIconKind)
A:Navigate("training"); A.state.filter="Zone Advisor"; A:Refresh(true)
A.MapAdvisor:Activate({command="zones"})
back(); assert(not A.state.mapZonePicker and A.state.filter=="Zone Advisor")
A:Navigate("instances"); A:Activate({kind="instance",id="rfc"})
back(); assert(not A.state.instance and A.state.view=="instances")
-- Current instance strips keep Back aligned with the content below them.
IsInInstance=function() return true,"party" end
GetInstanceInfo=function() return "Ragefire Chasm","party",1,"Normal",5,0,false,389 end
A:Navigate("supplies"); A:OpenCurrentInstance()
back(); assert(A.state.view=="supplies")
assert(not f.back:IsVisible(),"Back remains visible at a root page")
print("PASS: fixed shared Back position, hit testing, scrolling and nested return paths.")
''')

# Run the wider layout checks with the current TOC, including nested supplies.
lua.execute(Path(__file__).with_name('redesign.lua').read_text())
