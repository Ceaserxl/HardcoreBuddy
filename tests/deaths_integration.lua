local A, H = TestAddon, TestAddon.Deaths
assert(H.db == HardcoreBuddyDB.deaths)
assert(H.nativeSupported and not H.minimap)
assert(H.db.settings.sound==true,"new profiles enable alert sound")
assert(not RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"))
assert(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"))
local minimaps, listeners = 0, 0
for _, frame in ipairs(MOCK.frames) do
    if frame.parent == Minimap and frame.kind == "Button" then minimaps = minimaps + 1 end
    if frame:IsEventRegistered("HARDCORE_DEATHS") then listeners = listeners + 1 end
end
assert(minimaps == 1 and listeners == 1, "one minimap button and one death receiver")
MOCK.Click(A.minimap)
assert(A.window:IsShown())
local journalTab=A.window.tabs[4]
MOCK.Click(journalTab)
assert(A.state.view=="deaths" and H.host.parent==A.window and H.window:IsVisible())
local x,y,w,h=journalTab:GetRect()
assert(MOCK.HitTest(x+w/2,y+h/2)==journalTab,"journal tab is reachable by mouse")
A.minimap.scripts.OnClick(A.minimap,"RightButton")
assert(H.window:IsVisible() and A.window:IsShown(),"right-click opens main journal page")
SlashCmdList.HARDCOREBUDDY("deaths")
assert(A.state.view=="deaths" and H.window:IsVisible())
SlashCmdList.HARDCOREBUDDY("deaths settings")
assert(H.options:IsVisible() and not H.window:IsShown(),"settings stay inside right section")
assert(H.options.parent==H.host and H.details.parent==H.host)
SlashCmdList.HARDCOREDEATHS("")
assert(H.window:IsVisible() and not H.options:IsShown(),"old slash alias opens journal page")
SlashCmdList.HARDCOREBUDDY("deaths test")
assert(H.alert:IsShown() and #H.db.records == 0, "preview does not pollute history")
assert(H.alert.record.source=="Preview", "empty history uses a sample")
assert(H.ToggleWatch==nil and H.IsWatched==nil and H.details.watch==nil)
SlashCmdList.HARDCOREBUDDY("deaths watch MixedCase")
assert(H.db.watch==nil, "removed watch command cannot create saved preferences")
local message = "[Tester] has been slain by a Wolf in Elwynn! They were level 18"
MOCK.FireAll("HARDCORE_DEATHS", message)
MOCK.FireAll("HARDCORE_DEATHS", message)
assert(#H.db.records == 1 and H.alert.description:GetText() == "Wolf  |  Elwynn")
H.window.rows[1].scripts.OnEnter()
assert(GameTooltip:NumLines() == 4, "journal row tooltip uses native signature")
GameTooltip:Hide()

-- Simulate the legacy addon loading after its new optional dependency.
HardcoreDeathsDB = {
    records={{name="Legacy", realm="Realm", date=1900, source="Blizzard", level=40}},
    watch={["realm:legacy"]=true},
    settings={mini=false, alerts=false, scale=1.2, sound=false, minAlertLevel=20},
    positions={mini={"RIGHT", "RIGHT", -55, 70}},
}
local oldFrameCount = #MOCK.frames
if TEST_LEGACY_PATH then
    for _, path in ipairs({"Model.lua", "Core.lua", "UI.lua", "Events.lua"}) do
        assert(loadfile(TEST_LEGACY_PATH.."/"..path))("HardcoreDeaths", {})
    end
end
assert(#MOCK.frames == oldFrameCount, "standalone handoff creates no duplicate UI or receiver")
MOCK.FireAll("ADDON_LOADED", "HardcoreDeaths")
assert(#H.db.records == 2 and H.db.records[1].name == "Legacy")
assert(H.db.watch==nil and H.db.importedHardcoreDeaths,"legacy watchlist is not imported")
assert(H.db.settings.scale == 1.2 and not H.db.settings.mini and not H.db.settings.alerts)
assert(H.options.alertLevel:GetText()=="20", "migration refreshes visible alert threshold")
assert(not H.mini:IsShown() and not H.alert:IsShown())
assert(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"))
assert(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"))
assert(H.db.positions.mini[4] == 70)
assert(H.db.records[1] ~= HardcoreDeathsDB.records[1], "migration copies legacy data")
H.db.records[1].zone = "Westfall"
assert(HardcoreDeathsDB.records[1].zone == nil, "source history remains unchanged")
H:MigrateStandalone()
assert(#H.db.records == 2 and H.db.watch==nil, "migration runs once")
assert(HardcoreDeathsDB.watch["realm:legacy"], "original watchlist remains intact")
SlashCmdList.HARDCOREDEATHS("")
assert(H.window:IsVisible() and A.state.view=="deaths", "standalone cannot steal slash alias")
print("PASS: Shared entry points, single receiver, duplicate suppression, original text, tooltip, late legacy migration and unchanged legacy data.")

H:ShowDetails(H.db.records[1])
assert(H.details:IsVisible() and not H.window:IsShown())
MOCK.Click(H.details.back)
assert(H.window:IsVisible() and not H.details:IsShown())
for _,entry in ipairs({{1,"all"}}) do
    MOCK.Click(A.window.filters[entry[1]])
    assert(H.mode==entry[2] and H.window:IsVisible())
end
MOCK.Click(A.window.filters[2])
assert(H.options:IsVisible())
MOCK.Click(A.window.tabs[1])
assert(A.state.view=="supplies" and not H.host:IsShown() and A.window.scroll:IsVisible())
MOCK.Click(journalTab)
assert(H.window:IsVisible() and not A.window.scroll:IsShown())
A.window:Hide()
assert(not H.window:IsVisible() and not H.options:IsVisible() and not H.details:IsVisible())
SlashCmdList.HARDCOREDEATHS("")
assert(A.window:IsShown() and H.window:IsVisible())
assert(not HardcoreBuddyDeathsJournal and not HardcoreBuddyDeathsOptions and not HardcoreBuddyDeathsDetails,
    "death pages no longer create independent global windows")
for _,screen in ipairs({{1920,1080},{1024,768},{640,480}}) do
    UIParent.width,UIParent.height=screen[1],screen[2]
    A:RestoreWindow(); A:Refresh()
    local hx,hy,hw,hh=H.host:GetRect()
    local wx,wy,ww,wh=A.window:GetRect()
    assert(hx>=wx+180 and hy>wy+100 and hx+hw<=wx+ww and hy+hh<=wy+wh-40)
    for _,row in ipairs(H.window.rows) do
        if row:IsVisible() then
            local rx,ry,rw,rh=row:GetRect()
            assert(rx>=hx and rx+rw<=hx+hw and ry>=hy and ry+rh<=hy+hh-40)
        end
    end
    assert(H.host:GetEffectiveScale()==A.window:GetEffectiveScale(),"page inherits main-window scale")
end
print("PASS: Embedded journal navigation, options/details/back, visibility, sidebar filters and small-screen bounds.")
for i=1,30 do
    H:Add({name="PagePlayer"..i,realm="Realm",date=2100+i,source="Blizzard",level=i},true)
end
assert(#H.filtered==32 and H.window.page:GetText()=="1 / "..math.ceil(32/H.rowsPerPage))
local first=H.window.rows[1].record
MOCK.Click(H.window.next)
assert(H.page==2 and H.window.rows[1].record~=first)
MOCK.Click(H.window.previous)
assert(H.page==1 and H.window.rows[1].record==first)
H.window.search:SetText("PagePlayer30")
assert(#H.filtered==1 and H.window.rows[1].record.name=="PagePlayer30")
MOCK.Click(H.window.rows[1])
assert(H.details:IsVisible() and H.details.record.name=="PagePlayer30")
MOCK.Click(H.details.back)
assert(H.window:IsVisible() and H.query=="PagePlayer30" and #H.filtered==1)
H.window.minimum:SetText("40")
assert(#H.filtered==0 and H.window.empty:IsShown())
H.window.minimum:SetText("0"); H.window.search:SetText("")
local class=MOCK.class
MOCK.class="MAGE"; A:Refresh()
assert(A.state.view=="deaths", "class change does not eject the character-independent journal")
MOCK.class=class
MOCK.Click(A.window.filters[2])
H:ShowDetails(H.db.records[1])
MOCK.Click(H.details.back)
assert(H.window:IsVisible(), "details opened from options return to reports")
print("PASS: Journal search, level filtering, empty state, pagination, row details/back and class-change continuity.")

assert(A.window.filters[2].label:GetText()=="Options")
assert(not A.window.filters[3] or not A.window.filters[3]:IsShown(),"no Watchlist sidebar entry")
local count=#H.db.records
MOCK.Click(A.window.filters[2])
assert(H.options:IsVisible())
MOCK.Click(H.options.preview)
assert(H.alert.record==H.db.records[count] and H.alert.title==nil)
assert(#H.db.records==count,"real-record preview does not duplicate history")
local current=H.alert.record
local other={name="OtherRealm",realm="Elsewhere",date=9999,source="Blizzard",level=60,message="Original other-realm announcement"}
H:Add(other,true)
H:Slash("test")
assert(H.alert.record==current,"prefer current-realm history over newer cross-realm history")
local savedRecords=H.db.records
H.db.records={other}
H:Slash("test")
assert(H.alert.record==other and H.alert.description:GetText()=="Not reported  |  Location not reported","any existing record beats synthetic preview")
assert(other.source=="Blizzard" and other.name=="OtherRealm","preview does not mutate real records")
H.db.records=savedRecords
H:Refresh()
print("PASS: Watching removed; real-record preview prefers current realm, falls back across realms, preserves history and uses samples only for empty history.")

assert(A.window.filters[1].label:GetText()=="Reports" and A.window.filters[2].label:GetText()=="Options")
assert(not A.window.filters[3] or not A.window.filters[3]:IsShown(),"Verified tab is removed")
assert(H.db.settings.alertDuration==3,"existing installs keep three-second hold")
for _,pair in ipairs({{-1,1},{0,1},{1,1},{30,30},{90,30},{7.8,7},{"bad",3},{math.huge,3},{0/0,3}}) do
    assert(H.NormalizeAlertDuration(pair[1])==pair[2])
end
local duration=H.options.duration
duration:SetFocus(); duration:SetText("7")
duration.scripts.OnEnterPressed(duration)
assert(H.db.settings.alertDuration==7 and duration:GetText()=="7")
MOCK.Click(H.options.preview)
assert(H.alert.holdDuration==7)
H.alert.scripts.OnUpdate(H.alert,6.75)
assert(H.alert:IsShown() and H.alert:GetAlpha()==1,"custom hold stays fully visible")
H.alert.scripts.OnUpdate(H.alert,0.5)
assert(H.alert:IsShown() and math.abs(H.alert:GetAlpha()-0.5)<0.001,"short fade follows configured duration")
H.alert.scripts.OnUpdate(H.alert,0.25)
assert(not H.alert:IsShown(),"alert expires after hold plus fade")
duration:SetFocus(); duration:SetText("12"); duration:ClearFocus()
assert(H.db.settings.alertDuration==12,"focus loss commits duration")
duration:SetFocus(); duration:SetText("24"); duration.scripts.OnEscapePressed(duration)
assert(H.db.settings.alertDuration==12,"Escape discards an uncommitted duration")
duration:SetFocus(); duration:SetText(""); duration:ClearFocus()
assert(H.db.settings.alertDuration==12 and duration:GetText()=="12","empty duration retains saved value")
duration:SetFocus(); duration:SetText("99"); duration:ClearFocus()
assert(H.db.settings.alertDuration==30,"UI duration is bounded")
duration:SetFocus(); duration:SetText("7"); duration:ClearFocus()
for _,mode in ipairs({"live","preview"}) do
    A:SetProfile("mode",mode)
    A:OpenDeaths("Reports")
    local x,y,w,h=H.host:GetRect()
    for _,row in ipairs(H.window.rows) do if row:IsVisible() then
        local rx,ry,rw,rh=row:GetRect()
        assert(ry>=y+176 and ry+rh<=y+h-40,"redesigned rows stay clear of pagination")
        assert(row.zone:GetHeight()>=row.zone:GetStringHeight(),"location column text fits")
    end end
    A:OpenDeaths("Options")
    local px,py,pw,ph=H.options.preview:GetRect()
    local dx,dy,dw,dh=duration:GetRect()
    assert(dy>=y and dy+dh<py and px>=x and px+pw<=x+w and py+ph<=y+h)
end
print("PASS: Duration defaults, bounds, commit/cancel, exact hold/fade timing, removed Verified tab and redesigned live/planning bounds.")
for _,pair in ipairs({{"a Defias Knuckleduster","Defias Knuckleduster"},{"an Ogre","Ogre"},
    {"A Dust Devil","Dust Devil"},{"Ancient Protector","Ancient Protector"},{"drowned to death","drowned to death"}}) do
    assert(H:Cause({cause=pair[1]})==pair[2],"display cause strips only a leading article")
end
assert(not H.db.settings.sound,"explicit saved sound-off preference survives migration")
A:OpenDeaths("Reports")
for _,row in ipairs(H.window.rows) do if row:IsVisible() then
    local fields={row.level,row.name,row.zone,row.cause,row.source,row.age}
    for i=1,#fields-1 do
        local x,y,w,h=fields[i]:GetRect()
        local nx,ny,nw,nh=fields[i+1]:GetRect()
        assert(x+w<=nx and math.abs(y+h/2-ny-nh/2)<1,"journal columns are distinct and share one baseline")
    end
end end
local raw={name="Bellef",level=17,realm="Realm",date=4000,source="Blizzard",cause="a Defias Knuckleduster",
    zone="Sentinel Hill",message="[Bellef] has been slain by a Defias Knuckleduster in Sentinel Hill! They were level 17"}
H:ShowAlert(raw,true)
assert(H.alert.description:GetText()=="Defias Knuckleduster  |  Sentinel Hill")
assert(raw.cause=="a Defias Knuckleduster" and raw.message:find("%[Bellef%]"),"original report remains intact")
assert(H.alert:GetWidth()==896 and H.alert:GetHeight()==80)
assert(H.alert.art.texCoord[3]==0 and H.alert.art.texCoord[4]==1,"centered artwork is imported without exterior padding")
assert(H.alert.art.texture:find("AlertBanner",1,true),"alert uses its dedicated artwork")
MOCK.FireAll("DISPLAY_SIZE_CHANGED")
assert(H.alert:GetWidth()*H.alert:GetScale()<=UIParent:GetWidth()-24+0.01,"wide alert fits a small screen")
print("PASS: Separate columns, clean causes, concise alerts, sound defaults/preferences, dedicated banner and responsive overlay width.")
assert(H.alert.name.justifyH=="CENTER" and H.alert.description.justifyH=="CENTER")
assert(H.alert.name.fontSize==28 and H.alert.description.fontSize==16,"short alerts use the enlarged typography")
H:ShowAlert({name=string.rep("W",35),level=60,cause=string.rep("D",40),zone=string.rep("Z",40)},true)
assert(H.alert.name.fontSize<=28 and H.alert.name.fontSize>=22)
assert(H.alert.description.fontSize<=16 and H.alert.description.fontSize>=14)
assert(H.alert.name:GetStringWidth()<=H.alert.name:GetWidth())
assert(H.alert.description:GetStringWidth()<=H.alert.description:GetWidth())
H:ShowAlert(raw,true)
assert(H.alert.name.fontSize==28 and H.alert.description.fontSize==16,"short subsequent alerts restore large text")
print("PASS: Symmetric centered banner typography, long-text fitting and font reset between alerts.")
local mini=H.mini
H.db.settings.mini=true; H:ApplySettings()
assert(mini:GetWidth()==360 and mini:GetHeight()==218 and mini:IsVisible())
local recent=H.Filter(H.db.records,"","all",0,H.realm)
assert(#mini.rows==6,"compact feed shows six reports")
for i,row in ipairs(mini.rows) do
    assert(row:GetHeight()==20 and not row.rowArt,"compact rows have no framed artwork")
    assert(row.record==recent[i],"feed shows the latest current-realm reports")
    if row:IsVisible() then
        assert(row.level:GetText()==tostring(row.record.level or "?"))
        local nx,ny,nw,nh=row.name:GetRect()
        local ax,ay,aw,ah=row.age:GetRect()
        local zx,zy,zw,zh=row.zone:GetRect()
        local rx,ry,rw,rh=row:GetRect()
        assert(nx+nw<=zx and zx+zw<=ax and ax+aw<=rx+rw and math.abs(ny+nh/2-zy-zh/2)<1 and zy+zh<=ry+rh,
            "compact row labels fit without overlap")
        local _,footerY=mini.journal:GetRect()
        assert(ry+rh<=footerY,"six rows fit above footer controls")
    end
end
MOCK.Click(mini.journal)
assert(A.state.view=="deaths" and H.window:IsVisible())
MOCK.Click(mini.rows[1])
assert(H.details:IsVisible() and H.details.record==recent[1])
MOCK.Click(mini.hide)
assert(not mini:IsShown() and not H.db.settings.mini and H.events:IsEventRegistered("HARDCORE_DEATHS"),
    "hiding the feed preserves death tracking")
local records=H.db.records
H.db.records={}; H:Refresh()
assert(mini.empty:IsShown() and not mini.rows[1]:IsShown())
H.nativeSupported=false; H:Refresh()
assert(mini.status:GetText()=="Feed unavailable" and mini.empty:GetText():find("unavailable"))
H.nativeSupported=true; H.db.records=records; H:Refresh()
assert(not mini.empty:IsShown() and mini.status:GetText()=="Official death feed")
print("PASS: Redesigned compact feed geometry, latest reports, row bounds, journal/details links, hide behavior and empty/unavailable states.")

assert(H.alert.art.texture:find("AlertBannerIron",1,true),"new centered artwork is active")
assert(H.alert.artParts[1]:GetWidth()==H.alert.artParts[3]:GetWidth(),"ornamental ends are balanced")
local bx,by,bw,bh=H.alert:GetRect()
for _,label in ipairs({H.alert.name,H.alert.description,H.alert.rule}) do
    local x,y,w,h=label:GetRect()
    assert(math.abs(x+w/2-bx-bw/2)<0.01,"text and divider share the banner centerline")
    assert(y>=by and y+h<=by+bh,"centered text remains within the compact banner")
end
print("PASS: New symmetrical artwork, equal end caps and all text centered across the full banner.")

-- The named alert toggle stops automatic overlays while recording continues.
local oldAlerts,oldMini=H.db.settings.alerts,H.db.settings.mini
local showAlert=H.ShowAlert
local shown=0
H.ShowAlert=function() shown=shown+1 end
H.db.settings.alerts=true; H.db.settings.mini=true; H:ApplySettings()
H.options.checks.alerts:SetChecked(false)
H.options.checks.alerts.scripts.OnClick(H.options.checks.alerts)
assert(not H.db.settings.alerts and not H.alert:IsShown())
assert(H.mini:IsShown() and H.events:IsEventRegistered("HARDCORE_DEATHS"))
local added=H:Add({name="DisabledAlertTest",realm="Realm",date=987654,source="Blizzard",level=60})
assert(added and shown==0,"disabled alerts still record without invoking banner or sound")
assert(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"))
H.options.checks.alerts:SetChecked(true)
H.options.checks.alerts.scripts.OnClick(H.options.checks.alerts)
H:Add({name="EnabledAlertTest",realm="Realm",date=987655,source="Blizzard",level=60})
assert(shown==1,"alerts resume after enabling")
H.ShowAlert=showAlert
H.db.settings.alerts=oldAlerts; H.db.settings.mini=oldMini; H:ApplySettings()
print("PASS: Death alert checkbox disables automatic banner/sound, preserves recording/feed, and re-enables alerts.")
local originalPlaySoundFile=PlaySoundFile
local originalPlaySound=PlaySound
local nativeCount=0
PlaySound=function(kit,channel)
    assert(kit==((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959) and channel=="Master")
    nativeCount=nativeCount+1; return true,9000+nativeCount
end
H.db.settings.alertSound="RaidWarning"; H.db.settings.sound=true; H:ApplySettings()
assert(not H.options.volume:IsShown())
H:PlayAlertSound(); assert(nativeCount==1)
H.db.settings.sound=false; H:PlayAlertSound(); assert(nativeCount==1)
H.db.settings.alertSound="DeathBell"; H:ApplySettings()
assert(H.options.volume:IsShown())
local heard={}
PlaySoundFile=function(path,channel) assert(channel=="Master"); heard[#heard+1]=path; return true,#heard end
H.db.settings.sound=true
H.options.volume:SetValue(30)
H:ShowAlert({name="Volume test",level=30,zone="Test zone"},true)
assert(heard[1]:find("DeathBell30.wav",1,true))
H.options.volume:SetValue(0)
H:ShowAlert({name="Muted test",level=30,zone="Test zone"},true)
assert(#heard==1 and H.db.settings.volume==0)
H.options.volume:SetValue(70)
-- Real selector handlers cycle all clips, preview the selected one, and wrap.
for _,choice in ipairs(H.soundChoices) do
    H.db.settings.alertSound=choice.id; H:ApplySettings()
    assert(H.options.soundChoice.label:GetText()==choice.name)
    for volume=10,100,10 do
        H.options.volume:SetValue(volume)
        H:ShowAlert({name="Sound test",level=60},true)
        local extension=choice.id=="DeathBell" and ".wav" or ".ogg"
        if choice.id=="RaidWarning" then assert(nativeCount==1+volume/10)
        else assert(heard[#heard]:find(choice.id..volume..extension,1,true)) end
    end
end
H.db.settings.alertSound="DeathBell"; H:ApplySettings()
MOCK.Click(H.options.soundNext)
assert(H.db.settings.alertSound=="HeroFallen" and heard[#heard]:find("HeroFallen100.ogg",1,true))
MOCK.Click(H.options.soundPrev)
assert(H.db.settings.alertSound=="DeathBell")
MOCK.Click(H.options.soundPrev)
assert(H.db.settings.alertSound=="RaidWarning")
MOCK.Click(H.options.soundPrev)
assert(H.db.settings.alertSound=="golfclap")
local before=#heard
MOCK.Click(H.options.soundChoice)
assert(#heard==before+1 and heard[#heard]:find("golfclap100.ogg",1,true))
H.db.settings.alertSound="../invalid"; H:ApplySettings()
assert(H.db.settings.alertSound=="RaidWarning","Invalid saved sound must recover")
H.db.settings.sound=false; H:PlayAlertSound()
assert(#heard==before+1,"Sound toggle must mute selected Deathlog clip")
H.db.settings.sound=true; H.options.volume:SetValue(70)
PlaySoundFile=originalPlaySoundFile
PlaySound=originalPlaySound
print("PASS: Original native warning, custom bell and five Deathlog sounds, all volume steps, mute, selector clicks, wrapping and invalid-setting recovery.")
