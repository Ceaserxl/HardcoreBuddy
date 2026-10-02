"""Section boundaries, paired navigation and inline slider values across page types."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local checked=0
local function inside(child,parent)
    local x,y,w,h=child:GetRect(); local px,py,pw,ph=parent:GetRect()
    assert(x>=px-.1 and y>=py-.1 and x+w<=px+pw+.1 and y+h<=py+ph+.1,"Control escapes its section")
    checked=checked+1
end
local function separate(a,b)
    local x,y,w,h=a:GetRect(); local xx,yy,ww,hh=b:GetRect()
    assert(x+w<=xx+.1 or xx+ww<=x+.1 or y+h<=yy+.1 or yy+hh<=y+.1,"Section cards overlap")
end
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]; A:RestoreWindow()
    for _,name in ipairs(A.Settings.sections) do
        A:OpenSettings(name)
        for _,frame in ipairs(MOCK.frames) do
            if frame.sectionCards and frame:IsVisible() then
                for i,card in ipairs(frame.sectionCards) do
                    inside(card,frame)
                    for j=1,i-1 do separate(card,frame.sectionCards[j]) end
                end
            end
        end
        if name=="Gear Advisor" then
            local gear=A.Settings.pages[name]
            for _,b in ipairs({gear.enabled,gear.markers,gear.notify,gear.autoEquip,gear.openWeights}) do inside(b,b:GetParent()) end
        elseif name=="Low Health" then
            local p=A.LowHealth.page
            inside(p.threshold,p.threshold:GetParent()); inside(p.preview,p.preview:GetParent()); inside(p.volume,p.volume:GetParent())
            p.volume:SetValue(0); assert(p.volume.valueText:GetText()=="0%")
            p.volume:SetValue(73); assert(p.volume.valueText:GetText()=="70%" and A.LowHealth.settings.volume==70)
        elseif name=="NPC Alerts" then
            separate(A.CreatureAlerts.pages.rares,A.CreatureAlerts.pages.elites)
            for _,p in pairs(A.CreatureAlerts.pages) do
                for _,b in ipairs({p.duration,p.preview,p.neutralPreview,p.volume}) do inside(b,p) end
            end
        end
    end
end
UIParent.width,UIParent.height=1920,1080; A:RestoreWindow()
for _,class in ipairs({"HUNTER","WARLOCK","WARRIOR","PALADIN","ROGUE","MAGE","PRIEST","DRUID","SHAMAN"}) do
    MOCK.class=class; A.lastClass=nil; A:Navigate("training")
    local rows=A.window.cards[1].content.blocks
    local left,right=rows[3],rows[4]
    separate(left,right)
    local x,y,w,h=left:GetRect(); local xx,yy=right:GetRect()
    assert(xx>x and yy==y,"Overview follows sidebar order across paired cards")
    local state=A.state
    local hit=MOCK.ClickAt(x+w/2,y+h/2)
    assert(hit==left and A.state.filter=="Zone Advisor","Section card backdrop must not intercept navigation")
    A:Back(); assert(A.state==state)
end
print("PASS: "..checked.." section/control bounds at three screen sizes; nine-class paired navigation and inline slider values.")
''')
