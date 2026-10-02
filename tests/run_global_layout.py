"""Shared compact spacing, typography and journal toolbar geometry."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
lua.execute('''
local A=TestAddon
local count=0
local function check(value,message) count=count+1; assert(value,message) end
local function near(a,b) return math.abs(a-b)<0.1 end
local function cards()
    local previous
    for i,data in ipairs(A.document.cards or {}) do
        local c=A.window.cards[i]
        if c and c:IsVisible() then
            local x,y,w,h=c:GetRect()
            if previous then check(near(y-previous,8),"Every section has the same compact 8px gap") end
            previous=y+h
            if not data.itemLayout then
                local tx,ty=c.title:GetRect(); local _,size=c.title:GetFont()
                check(near(x,tx) and near(y,ty),"No extra inset before section titles")
                check(size==(i==1 and not data.supplyTable and 22 or 15),"Shared heading hierarchy")
                if data.note and data.note~="" then
                    local _,ny=c.note:GetRect(); local _,_,_,th=c.title:GetRect()
                    local _,ns=c.note:GetFont()
                    check(ns==12 and ny>=ty+th and ny-ty-th<=8,"Compact 12px subtitles below titles")
                    local _,_,_,nh=c.note:GetRect(); local _,cy=c.content:GetRect()
                    check(cy>=ny+nh,"Wrapped subtitles cannot collide with content")
                end
            end
        end
    end
end
for _,class in ipairs({"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}) do
    MOCK.class=class; A.lastClass=nil
    for _,view in ipairs({"supplies","training","petguide","instances"}) do
        A:Navigate(view)
        local filters={}
        for _,entry in ipairs(A.document.filters or {}) do filters[#filters+1]=type(entry)=="table" and (entry.id or entry.name or entry[1]) or entry end
        cards()
        for _,filter in ipairs(filters) do A.state.filter=filter; A:Refresh(true); cards() end
    end
end
MOCK.class="HUNTER"; A.lastClass=nil
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]; A:RestoreWindow()
    for _,view in ipairs({"training","instances"}) do
        A:Navigate(view)
        if view=="training" then A.state.filter="Spells"; A:Refresh(true) end
        local f=A.window
        local x,y,w=f.cards[1].content:GetRect(); local bx,by,bw=f.atLevel:GetRect()
        check(near(x+w,bx+bw),"Spells and instances toolbar ends at the content right edge")
        local sx,sy,sw=f.search:GetRect(); local cx,cy,cw=f.clear:GetRect()
        check(near(cx-sx-sw,8) and near(bx-cx-cw,8),"Compact search controls share 8px gaps")
    end
    A:OpenDeaths()
    local j=A.Deaths.window
    local _,toolbarY=A.window.back:GetRect()
    local sx,sy,sw=j.search:GetRect(); local mx,my,mw=j.minimum:GetRect()
    local cx,cy,cw=j.clear:GetRect(); local lx,ly,lw,lh=j.minimumLabel:GetRect()
    check(near(sy,toolbarY) and near(my,toolbarY) and near(cy,toolbarY),"Journal filters share the main toolbar")
    check(sx+sw<lx and lx+lw<mx and mx+mw<cx,"Search, level filter and clear button do not overlap")
    check(ly>=sy and ly+lh<=sy+28,"Minimum level label fits the toolbar")
    local _,ty=j.title:GetRect(); local _,ry=j.realm:GetRect()
    check(near(ry-ty,30),"Journal uses the shared compact header")
    local _,tableY=j.tableCard:GetRect(); local _,statY,_,statH=j.stats[1]:GetRect()
    check(near(tableY-statY-statH,8),"Reports follow summary cards by 8px")
    A:Navigate("supplies"); MOCK.Click(A.window.cards[1].content.blocks[1])
    local rows=A.window.cards[1].content.blocks
    local x,y,w=rows[1]:GetRect(); local dx,dy=rows[2]:GetRect()
    check(near(y,dy) and near(dx-x-w,8),"Selected item and details align with the shared column gap")
end
print("PASS: "..count.." compact section, typography, item alignment and journal toolbar checks.")
''')

if '--render' in sys.argv:
    output = ROOT / '.release' / 'settings-previews'
    output.mkdir(parents=True, exist_ok=True)
    lua.execute('UIParent.width=1920; UIParent.height=1080; TestAddon:RestoreWindow()')
    pages = {
        'compact-item': 'A:Navigate("supplies"); MOCK.Click(A.window.cards[1].content.blocks[1])',
        'compact-supplies': 'A:Navigate("supplies")',
        'compact-journal': 'A:OpenDeaths()',
        'compact-general': 'A:OpenSettings("General")',
        'compact-settings-gear': 'A:OpenSettings("Gear Advisor")',
        'compact-settings-talents': 'A:OpenSettings("Talent Advisor")',
        'compact-settings-deaths': 'A:OpenSettings("Death Journal")',
        'compact-settings-zone': 'A:OpenSettings("Zone Advisor")',
        'compact-spells': 'A:Navigate("training"); A.state.filter="Spells"; A:Refresh(true)',
        'compact-firstaid': 'A:Navigate("training"); A.state.filter="First Aid"; A:Refresh(true)',
    }
    for name, code in pages.items():
        lua.execute('local A=TestAddon; '+code)
        composite(lua.globals().MOCK.frames, addon.window).save(output / (name+'.png'))
    print('Rendered previews:', output)
