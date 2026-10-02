"""Custom-build subpanels need real scroll-frame bounds, including an empty library."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
lua.execute(r'''
local A=TestAddon; local U,B=A.CustomBuildsUI,A.CustomBuilds
local count=0
local function check(ok,message) count=count+1; assert(ok,message) end
local function panel(frame)
    local x,y,w,h=frame:GetRect()
    check(frame:IsVisible() and w>0 and h>0,"Active custom-build panel has nonzero scroll-frame bounds")
    for _,child in ipairs({frame:GetChildren()}) do
        if child:IsShown() then
            local cx,cy,cw,ch=child:GetRect()
            check(cx>=x-.1 and cy>=y-.1 and cx+cw<=x+w+.1 and cy+ch<=y+h+.1,
                "Panel encloses "..tostring(child.label and child.label:GetText() or child.kind))
        end
    end
    local _,py,_,ph=U.page:GetRect()
    check(y+h<=py+ph+.1,"Settings content includes the full active panel")
end
for _,class in ipairs({"WARLOCK","DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARRIOR"}) do
    MOCK.class=class; MOCK.level=20; A.db.customBuilds={}; A.lastClass=nil
    A:OpenSettings("Talent Advisor"); MOCK.Click(A.Settings.pages["Talent Advisor"].manage)
    check(U.mode=="library" and #B:List(class)==0,"Open empty class library through real Settings button")
    panel(U.list)
    check(U.list.new:IsVisible() and U.list.import:IsVisible(),"Empty library shows Create and Import")
    check(not U.editor:IsShown() and not U.transfer:IsShown(),"Inactive panels stay hidden")
    MOCK.Click(U.list.new); panel(U.editor)
    check(U.draft.class==class and U.editor.save:IsVisible(),"Create opens current class editor")
    U.editor.name:SetText(class.." test build"); MOCK.Click(U.editor.save)
    panel(U.list); check(#B:List(class)==1,"Saving returns to populated library")
    local row=U.list.rows[1]; check(row:IsVisible(),"Saved build row visible")
    MOCK.Click(row.share); panel(U.transfer)
    check(U.transfer.code:IsVisible() and U.transfer.review:IsVisible(),"Export code and review controls visible")
    MOCK.Click(U.transfer.review); panel(U.transfer)
    check(U.preview and U.transfer.import:IsEnabled(),"Reviewed full path and weights remain in sized panel")
    U:Back(); panel(U.list)
    MOCK.Click(row.edit); panel(U.editor)
    U:Back(); MOCK.Click(row.delete); MOCK.Click(row.delete); panel(U.list)
    check(#B:List(class)==0 and not row:IsShown(),"Deleting last build preserves empty library controls")
    MOCK.Click(U.list.import); panel(U.transfer)
    U.transfer.code:SetText("invalid"); MOCK.Click(U.transfer.review); panel(U.transfer)
    check(U.message and not U.transfer.import:IsEnabled(),"Import error keeps form visible")
    U:Back(); panel(U.list)
    U:Back(); check(not A.state.customBuildPage,"Back returns to Talent Advisor settings")
end
-- Match the report's Warlock library and check its bounds at scaled window sizes.
MOCK.class="WARLOCK"; A.lastClass=nil
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]; A:RestoreWindow()
    U:Open(); panel(U.list)
    MOCK.Click(U.list.new); panel(U.editor)
    A.Settings.scroll:SetVerticalScroll(A.Settings.range)
    local _,cy,_,ch=A.Settings.content:GetRect(); local _,sy,_,sh=A.Settings.scroll:GetRect()
    check(cy+ch<=sy+sh+.1,"Editor bottom reachable using main Settings scroll bar")
    U:Back(); MOCK.Click(U.list.import); panel(U.transfer)
end
UIParent.width,UIParent.height=1920,1080; A:RestoreWindow(); U:Open()
print("PASS: "..count.." custom-build panel geometry and navigation checks across nine classes and three screen sizes.")
''')

if "--render" in sys.argv:
    (ROOT / ".release").mkdir(exist_ok=True)
    composite(lua.globals().MOCK.frames, addon.window).save(ROOT / ".release/custom-builds-empty-fixed.png")
