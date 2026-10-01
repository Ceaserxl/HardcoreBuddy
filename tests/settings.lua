local A=TestAddon
local S=A.Settings
local count=0
local function check(ok,why) count=count+1; assert(ok,why) end
check(table.concat(S.sections,",")=="General,Gear Advisor,Talent Advisor,Auction House,Death Journal,Low Health,NPC Alerts,Zone Advisor,Debug","Consolidated sidebar order")
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
    for pageName,page in pairs(S.pages) do check(page:IsVisible()==(pageName==name),"Correct settings parent: "..pageName) end
    check(A.Deaths.options:IsVisible()==(name=="Death Journal") and A.Deaths.appearance:IsVisible()==(name=="Death Journal"),"Death controls share one tab")
    if A.LowHealth.page then check(A.LowHealth.page:IsVisible()==(name=="Low Health"),"Health page visibility") end
    for _,page in pairs(A.CreatureAlerts.pages or {}) do check(page:IsVisible()==(name=="NPC Alerts"),"Both NPC categories share one tab") end
    check(A.Readiness.options:IsVisible()==(name=="General"),"Preparation is nested in General")
    if A.MapAdvisor.controls then check(A.MapAdvisor.controls:IsVisible()==(name=="Zone Advisor"),"Map controls live in Settings") end
end
check(A.LowHealth.settings.volume==30 and A.Deaths.db.settings.alertDuration==8,"Moving controls preserves saved preferences")
A:HandleSlashCommand("health")
check(A.state.view=="settings" and A.state.filter=="Low Health","Health command opens Settings")
A.LowHealth.page.threshold:SetFocus(); A.LowHealth.page.threshold:SetText("27")
A:OpenSettings("Rares")
check(A.LowHealth.settings.threshold==27,"Leaving a page commits its pending edit")
check(A.state.filter=="NPC Alerts","Old rare route resolves to NPC Alerts")
A.CreatureAlerts.pages.rares.duration:SetFocus(); A.CreatureAlerts.pages.rares.duration:SetText("17")
A:Refresh()
check(A.CreatureAlerts.pages.rares.duration:HasFocus() and A.CreatureAlerts.pages.rares.duration:GetText()=="17","Combined NPC page preserves pending edits on refresh")
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
check(A.state.filter=="Death Journal" and A.Deaths.appearance:IsVisible() and A.Deaths.options:IsVisible(),"Appearance shortcut opens combined death settings")
local _,optionY,_,optionH=A.Deaths.options:GetRect()
local _,appearanceY,_,appearanceH=A.Deaths.appearance:GetRect()
check(appearanceY>optionY+optionH,"Combined death sections do not overlap")
S.scroll:SetVerticalScroll(S.range)
local _,scrollY,_,scrollH=S.scroll:GetRect()
local _,buttonY,_,buttonH=A.Deaths.appearance.move:GetRect()
check(buttonY>=scrollY and buttonY+buttonH<=scrollY+scrollH,"Banner controls remain reachable by scrolling")
A:OpenDeaths()
check(A.state.view=="deaths" and A.Deaths.window:IsVisible() and not S.scroll:IsShown(),"Journal remains a separate reports page")
check(not A.window.sidebar:IsShown() and not A.window.filters[1]:IsShown(),"Journal has no sidebar")
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
local blocks=A.document.cards[1].blocks
check(#A.document.cards==1 and A.document.cards[1].note:find("\nPercentage change",1,true),"Score explanation follows profile subtext")
check(blocks[#blocks].action.command=="settings","Gear settings link is last after supporting text")
for _,b in ipairs(blocks) do check(not b.action or b.action.command~="talentSettings","Talent settings link removed from Gear") end
A:Activate(blocks[#blocks].action)
check(A.state.view=="settings" and A.state.filter=="Gear Advisor","Advisor settings link works")
check(gear.openWeights:IsVisible() and not gear.openSnapshot and not gear.weights[1]:IsVisible(),"Gear settings show navigation buttons instead of inline editors")
MOCK.Click(gear.openWeights)
check(A.state.gearPage=="Stat Weights" and A.state.filter=="Gear Advisor" and gear.weights[1]:IsVisible(),"Stat Weights opens within Gear Advisor")
check(not gear:IsVisible() and A.window.back:IsVisible(),"Weights page uses the shared Back button")
S.scroll:SetVerticalScroll(100)
MOCK.Click(A.window.back)
check(not A.state.gearPage and gear:IsVisible() and S.scroll:GetVerticalScroll()==0,"Weights Back returns to the compact Gear settings page")
A:OpenSettings("Debug")
check(S.pages.Debug:IsVisible() and S.pages.Debug.dump.label:GetText()=="Dump Data","Debug replaces the Gear Snapshot page")
check(not A.GearSnapshot.panel and not S.pages["Gear Snapshot"],"Old snapshot controls removed")
A:OpenSettings("Gear Advisor")
MOCK.Click(gear.openWeights)
MOCK.Click(A.window.filters[1])
MOCK.Click(A.window.filters[2])
check(A.state.filter=="Gear Advisor" and not A.state.gearPage and gear:IsVisible(),"Sidebar navigation resets nested gear pages")
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
