local A=TestAddon
local S=A.Settings
local count=0
local function check(ok,why) count=count+1; assert(ok,why) end
local settingsTab
for _,tab in ipairs(A.window.tabs) do
    check(tab.view~="alerts","Old Alerts tab is replaced by Settings")
    if tab.view=="settings" then settingsTab=tab end
end
check(settingsTab~=nil,"Settings has a top-level tab")
A.LowHealth.settings.volume=30; A.Deaths.db.settings.alertDuration=8
MOCK.Click(settingsTab)
check(A.state.view=="settings" and S.pages.General:IsVisible(),"Settings defaults to General")
for i,name in ipairs(S.sections) do
    MOCK.Click(A.window.filters[i])
    check(A.state.filter==name and S.scroll:IsVisible() and not A.window.scroll:IsShown(),"Section opens: "..name)
    local visible=0
    for _,page in pairs(S.pages) do if page:IsVisible() then visible=visible+1 end end
    for _,page in ipairs({A.Deaths.options,A.Deaths.appearance,A.LowHealth.page or UIParent,
        A.CreatureAlerts.page or UIParent,A.Readiness.options or UIParent}) do
        if page~=UIParent and page:IsVisible() then visible=visible+1 end
    end
    check(visible==1,"Exactly one settings page is visible: "..name)
end
check(A.LowHealth.settings.volume==30 and A.Deaths.db.settings.alertDuration==8,"Moving controls preserves saved preferences")
A:HandleSlashCommand("health")
check(A.state.view=="settings" and A.state.filter=="Low Health","Health command opens Settings")
A.LowHealth.page.threshold:SetFocus(); A.LowHealth.page.threshold:SetText("27")
A:OpenSettings("Rares")
check(A.LowHealth.settings.threshold==27,"Leaving a page commits its pending edit")
A.CreatureAlerts.page.duration:SetFocus(); A.CreatureAlerts.page.duration:SetText("17")
A:OpenSettings("Elites")
check(A.CreatureAlerts.settings.rares.duration==17 and A.CreatureAlerts.settings.elites.duration==10,
    "Switching creature sections commits the old category before changing it")
A:HandleSlashCommand("deaths settings")
check(A.state.view=="settings" and A.Deaths.options:IsVisible(),"Existing death settings command redirects")
A.Deaths.options.duration:SetFocus(); A.Deaths.options.duration:SetText("12"); A:Refresh()
check(A.Deaths.options.duration:HasFocus() and A.Deaths.options.duration:GetText()=="12",
    "Ordinary refresh does not hide the active settings page or interrupt edits")
A:OpenDeaths("Appearance")
check(A.Deaths.db.settings.alertDuration==12,"Leaving death settings commits its pending duration")
check(A.state.filter=="Death Banner" and A.Deaths.appearance:IsVisible(),"Appearance shortcut redirects")
A:OpenDeaths()
check(A.state.view=="deaths" and A.Deaths.window:IsVisible() and not S.scroll:IsShown(),"Journal remains a separate reports page")
check(A.window.filters[1].label:GetText()=="Reports" and not A.window.filters[2]:IsShown(),"Journal no longer has scattered settings sections")
A:HandleSlashCommand("settings")
local general=S.pages.General
general.minimap:SetChecked(false); MOCK.Click(general.minimap)
check(A.db.minimapHidden and not A.minimap:IsShown(),"Minimap can be hidden centrally")
A:PositionMinimapButton(); check(not A.minimap:IsShown(),"Position updates preserve minimap preference")
general.minimap:SetChecked(true); MOCK.Click(general.minimap)
general.kit:SetChecked(false); MOCK.Click(general.kit); A:ShowKitUpdate(42,{"example"})
check(A.db.kitNotifications==false and (not A.kitAlert or not A.kitAlert:IsShown()),"Field kit notice toggle takes effect")
general.kit:SetChecked(true); MOCK.Click(general.kit)
A:OpenSettings("Gear Advisor")
local gear=S.pages["Gear Advisor"]
gear.enabled:SetChecked(false); MOCK.Click(gear.enabled)
check(A.db.gearAdvisorEnabled==false,"Gear tooltip setting takes effect")
check(not gear.profiles,"Gear settings no longer have an independent profile selector")
A:OpenSettings("Talent Advisor")
local talent=S.pages["Talent Advisor"]
MOCK.Click(talent.builds[2])
check(A.state.filter=="Talent Advisor" and A.GearAdvisor:CurrentProfile().fromBuild,"Build selection stays in settings and controls gear scoring")
MOCK.Click(talent.builds[1]); check(not A.GearAdvisor:CurrentProfile().manual,"Automatic Hardcore path remains available")
gear.enabled:SetChecked(true); MOCK.Click(gear.enabled)
A:Navigate("advisors")
check(A.document.cards[1].blocks[1].action.command=="settings","Advisor page links to centralized configuration")
A:Activate(A.document.cards[1].blocks[1].action)
check(A.state.view=="settings" and A.state.filter=="Gear Advisor","Advisor settings link works")
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]; A:RestoreWindow()
    for _,section in ipairs(S.sections) do
        A:OpenSettings(section)
        local x,y,w,h=S.scroll:GetRect(); local wx,wy,ww,wh=A.window:GetRect()
        check(x>=wx and x+w<=wx+ww and y>=wy and y+h<=wy+wh-40,"Settings viewport fits: "..section)
    end
end
UIParent.width,UIParent.height=1920,1080; A:RestoreWindow()
S:Layout(A.window,184,180,800,200,"Gear Advisor",true)
S.scroll.scripts.OnMouseWheel(S.scroll,-5)
check(S.scroll:GetVerticalScroll()>0 and S.range>0,"Long settings pages scroll")
A:OpenSettings("General"); check(S.scroll:GetVerticalScroll()==0,"Changing sections resets scrolling")
print("PASS: "..count.." centralized settings assertions; routing, saved preferences, controls, focus and viewport bounds.")
