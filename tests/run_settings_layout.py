"""Audit shared headers, control containment, paired rows and scroll reachability."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local count=0
local function check(value,message) count=count+1; assert(value,message) end
local function near(a,b) return math.abs(a-b)<0.1 end
local function inside(child,parent)
    local x,y,w,h=child:GetRect(); local px,py,pw,ph=parent:GetRect()
    check(x>=px-0.1 and y>=py-0.1 and x+w<=px+pw+0.1 and y+h<=py+ph+0.1,"Control fits its section: "..tostring(child.label and child.label:GetText()))
end
local function header(page)
    local h=page.settingsHeader
    check(h and h.title and h.subtitle,"Every settings page uses the shared header")
    local x,y=page:GetRect(); local tx,ty=h.title:GetRect()
    check(near(x,tx) and near(y,ty),"Title aligns to content origin")
    local _,size=h.title:GetFont(); check(size==22,"Consistent title size")
    local _,_,_,sx,sy=h.subtitle:GetPoint()
    check(sx==0 and sy==-30,"Consistent compact subtitle origin")
    if h.action then
        local ax,ay,aw=h.action:GetRect(); local _,_,pw=page:GetRect()
        check(near(ay,y) and near(ax+aw,x+pw-12),"Header action aligns to top right")
        check(h.action:GetHeight()==28,"Header actions share a height")
        local _,_,tw=h.title:GetRect(); check(tx+tw<ax,"Title cannot overlap its action")
    end
end
local function sections(page)
    for _,panel in ipairs(page.sectionCards or {}) do
        local controls={}
        for _,frame in ipairs(MOCK.frames) do
            if frame:GetParent()==panel and frame:IsVisible() and
                (frame.kind=="Button" or frame.kind=="CheckButton" or frame.kind=="EditBox" or frame.kind=="Slider") then
                inside(frame,panel); controls[#controls+1]=frame
            end
        end
        for i,a in ipairs(controls) do
            local ax,ay,aw,ah=a:GetRect()
            for j=i+1,#controls do
                local bx,by,bw,bh=controls[j]:GetRect()
                check(ax+aw<=bx or bx+bw<=ax or ay+ah<=by or by+bh<=ay,"Interactive controls do not overlap")
            end
        end
    end
end
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]; A:RestoreWindow()
    for _,name in ipairs(A.Settings.sections) do
        A:OpenSettings(name)
        local page=A.Settings.pages[name] or (name=="Death Journal" and A.Deaths.options) or
            (name=="Low Health" and A.LowHealth.page) or A.MapAdvisor.controls
        header(page); sections(page)
        if name=="Death Journal" then
            local appearance=A.Deaths.appearance
            check(not appearance.title:IsShown() and not appearance.subtitle:IsShown(),"Combined death settings has one page header")
            check(not appearance.preview:IsShown(),"Preview appears only in the main header")
            sections(appearance)
        elseif name=="General" then
            local r=A.Readiness.options
            inside(r.previewPanel,r); inside(r.previewReminder,r)
            local x,y,w=r.previewPanel:GetRect(); local rx,ry=r.previewReminder:GetRect()
            check(near(y,ry) and rx>x+w,"Preparation previews sit side by side")
        elseif name=="NPC Alerts" then
            for _,p in pairs(A.CreatureAlerts.pages) do
                for _,f in ipairs({p.duration,p.preview,p.volume}) do inside(f,p) end
                if p.neutralPreview:IsVisible() then
                    inside(p.neutralPreview,p)
                    local x,y,w=p.preview:GetRect(); local nx,ny=p.neutralPreview:GetRect()
                    check(near(y,ny) and nx>x+w,"Rare previews share a row without overlap")
                end
            end
        end
        A.Settings.scroll:SetVerticalScroll(A.Settings.range)
        local _,cy,_,ch=A.Settings.content:GetRect(); local _,sy,_,sh=A.Settings.scroll:GetRect()
        check(cy+ch<=sy+sh+0.1,"Bottom of settings remains reachable")
    end
    A:OpenSettings("Gear Advisor"); A.Settings:OpenGearPage("Stat Weights")
    header(A.Settings.pages["Stat Weights"])
    local edits=A.Settings.pages["Gear Advisor"].weights
    for _,edit in ipairs(edits) do inside(edit,A.Settings.pages["Stat Weights"].sectionCards[1]) end
    A:OpenSettings("Zone Advisor"); A.state.mapIconKind="rare"; A:Refresh(true)
    header(A.MapAdvisor.iconPicker)
    for _,choice in pairs(A.MapAdvisor.iconPicker.choices) do inside(choice,A.MapAdvisor.iconPicker) end
end
print("PASS: "..count.." settings geometry checks across three screen sizes, including nested pages and scroll endpoints.")
''')

