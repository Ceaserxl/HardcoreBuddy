"""Settings dependency transitions, automatic paths, footer space and icon compatibility."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local S=A.Settings
IsInInstance=function() return false,"none" end
InCombatLockdown=function() return false end
local count=0
local function check(ok,message) count=count+1; assert(ok,message) end
local function toggle(box,value) box:SetChecked(value); MOCK.Click(box) end
local function enabled(control,value)
    check(control:IsEnabled()==value,"Input enable state matches its feature")
    if not value then
        local alpha=control:GetAlpha(); local parent=control:GetParent()
        check(alpha<1 or parent:GetAlpha()<1,"Disabled input is dimmed")
    end
end
A:OpenSettings("Gear Advisor")
local gear=S.pages["Gear Advisor"]
local markerPreference=A.db.gearUpgradeMarkers
MOCK.Click(gear.toggle)
for _,b in ipairs({gear.enabled,gear.markers,gear.notify,gear.autoEquip,gear.openWeights}) do enabled(b,false) end
A:OpenSettings("Auction House"); enabled(S.pages["Auction House"].armor,false)
A:OpenSettings("Gear Advisor"); MOCK.Click(gear.toggle)
for _,b in ipairs({gear.enabled,gear.markers,gear.notify,gear.autoEquip,gear.openWeights}) do enabled(b,true) end
check(A.db.gearUpgradeMarkers==markerPreference,"Disabling advisor preserves preferences")
A:OpenSettings("Talent Advisor")
local talent=S.pages["Talent Advisor"]
local default=A.TalentAdvisor:DefaultBuild("HUNTER",A:GetContext().level)
local visible=0
for _,b in ipairs(talent.builds) do
    if b:IsShown() then
        visible=visible+1
        check(not b.label:GetText():find("Automatic Hardcore path",1,true),"No duplicate automatic row")
        if b.selected then check(b.label:GetText():find("(Automatic)",1,true),"Automatic label is on selected path") end
    end
end
check(visible==#A.Data.AdvisorBuilds.HUNTER,"Exactly one row per path")
MOCK.Click(talent.toggle)
enabled(talent.apply,false); enabled(talent.auto,false)
for _,b in ipairs(talent.builds) do if b:IsShown() then enabled(b,false) end end
MOCK.Click(talent.toggle)
for _,b in ipairs(talent.builds) do if b:IsShown() then enabled(b,true) end end
-- Automatic follows level phases; manual alternatives remain explicit.
for class,builds in pairs(A.Data.AdvisorBuilds) do
    for _,level in ipairs({10,20,40,60}) do
        A.characterDB.advisors.builds[class]=nil
        local selected,manual=A.TalentAdvisor:Build(class,level)
        check(not manual and selected==A.TalentAdvisor:DefaultBuild(class,level),"Automatic phase selection preserved")
    end
end
A:OpenSettings("Low Health")
local low=A.LowHealth.page
toggle(low.checks.enabled,false)
for _,b in ipairs({low.threshold,low.preview,low.checks.sound,low.volume}) do enabled(b,false) end
toggle(low.checks.enabled,true); enabled(low.threshold,true)
toggle(low.checks.sound,false); enabled(low.volume,false)
toggle(low.checks.sound,true); enabled(low.volume,true)
A:OpenSettings("NPC Alerts")
for _,page in pairs(A.CreatureAlerts.pages) do
    toggle(page.checks.enabled,false)
    for _,b in ipairs({page.duration,page.preview,page.checks.nonHostile,page.checks.sound,page.volume}) do enabled(b,false) end
    toggle(page.checks.enabled,true); enabled(page.duration,true)
    toggle(page.checks.sound,false); enabled(page.volume,false)
    toggle(page.checks.sound,true); enabled(page.volume,true)
    if page.category=="rares" then
        toggle(page.checks.nonHostile,false); enabled(page.neutralPreview,false)
        toggle(page.checks.nonHostile,true); enabled(page.neutralPreview,true)
    end
end
A:OpenSettings("Death Journal")
local death=A.Deaths.options
toggle(death.checks.alerts,false)
for _,b in ipairs({death.duration,death.alertLevel,death.checks.sound,death.volume,death.soundChoice,A.Deaths.appearance.preview}) do enabled(b,false) end
enabled(death.import,true); enabled(death.retention,true)
toggle(death.checks.alerts,true)
toggle(death.checks.sound,true); enabled(death.soundChoice,true); enabled(death.volume,true)
MOCK.Click(A.Deaths.appearance.styles["Text-only"]); enabled(A.Deaths.appearance.opacity,false)
MOCK.Click(A.Deaths.appearance.styles.Compact); enabled(A.Deaths.appearance.opacity,true)
MOCK.Click(A.Deaths.appearance.move)
check(A.Deaths.alert.positioning,"Position preview opens")
toggle(death.checks.alerts,false)
check(not A.Deaths.alert.positioning and not A.Deaths.alert:IsShown(),"Disabling alerts closes the position preview")
toggle(death.checks.alerts,true)
toggle(death.checks.sound,false); enabled(death.volume,false)
A:OpenSettings("General")
local ready=A.Readiness.options
toggle(ready.checks.panel,false); enabled(ready.previewPanel,false)
toggle(ready.checks.departure,false); enabled(ready.previewReminder,false)
toggle(ready.checks.panel,true); enabled(ready.previewPanel,true)
toggle(ready.checks.departure,true); enabled(ready.previewReminder,true)
A:OpenSettings("Zone Advisor")
local map=A.MapAdvisor.controls
MOCK.Click(map.modes.off); enabled(map.tintColor,false); enabled(map.sliders.tintAlpha,false)
MOCK.Click(map.modes.tint); enabled(map.tintColor,true); enabled(map.sliders.tintAlpha,true)
for _,kind in ipairs({"rare","elite","boss","danger"}) do toggle(map.checks[kind],false); enabled(map.icons[kind],false) end
enabled(map.sliders.iconSize,false); enabled(map.sliders.iconAlpha,false)
toggle(map.checks.rare,true); enabled(map.icons.rare,true); enabled(map.sliders.iconSize,true)
check(not A.window.footer and not A.window.skinChrome.footer,"Footer and its decoration are removed")
check(A.window.title:GetText():find("v"..A.version,1,true),"Version follows addon title")
for _,view in ipairs({"supplies","training","advisors","instances","petguide"}) do
    A:Navigate(view)
    local _,y,_,height=A.window:GetRect(); local _,sy,_,sh=A.window.scroll:GetRect()
    check(math.abs(y+height-sy-sh-18)<0.1,"Every content pane reclaims footer space")
end
-- Catalog only admits standalone atlases present in this client.
local M=A.MapAdvisor
C_Texture={GetAtlasInfo=function(name)
    if name=="QuestNormal" or name=="roleicon-tiny-tank" then return {width=32,height=32} end
end}
M:LoadIconChoices()
local seen={}
for _,key in ipairs(M.iconChoices) do check(not seen[key],"No duplicate choices"); seen[key]=true end
check(seen["quest-available"] and seen["role-tank"] and not seen["poi-cave"],"Unsupported atlases are omitted")
local total=#M.iconChoices; M:LoadIconChoices(); check(#M.iconChoices==total,"Catalog loads once")
print("PASS: "..count.." dependency, header, automatic path, viewport and icon catalog checks.")
''')
