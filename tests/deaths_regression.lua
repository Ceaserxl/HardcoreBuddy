-- Run from HardcoreBuddy with Lua 5.1; embedded module regression coverage.
local passed=0
local function eq(actual,expected,label)
    assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
    passed=passed+1
end
local addon={db={},Skin={Paint=function() end,Button=function() end,ButtonState=function() end}}
function addon:OpenDeaths(section,record)
    self.state={view="deaths",filter=section or "All reports",deathRecord=record}
    self.Deaths:LayoutPage(UIParent,184,146,816,468,self.state)
    self.Deaths.host:Show()
end
assert(loadfile("Deaths/Model.lua"))("HardcoreBuddy",addon)
local H=addon.Deaths
local r=H.ParseOfficial("[Tester] has been slain by a Defias Bandit in Westfall! They were level 18","Realm",1000)
eq(r.name,"Tester");eq(r.level,18);eq(r.cause,"a Defias Bandit");eq(r.zone,"Westfall")
local env=H.ParseOfficial("[Tester] drowned to death in Mist's Edge! They were level 18","Realm",1000)
eq(env.cause,"drowned to death");eq(env.zone,"Mist's Edge")
local foreign=H.ParseOfficial("Une annonce locale sans format reconnu","Realm",1000)
eq(foreign.name,"Unknown adventurer");eq(foreign.message,"Une annonce locale sans format reconnu")
eq(H.Clean("|cffff0000|Hplayer:Tester|h[Tester]|h|r |Tbad:50|t"),"[Tester] ")
eq(H.Clean("a\nb"),"a b")
local packet="1$Tester~Guild~123~1~2~18~~12~~"
local peer=H.ParseCommunity(packet,"Tester-Realm","Realm",1001)
eq(peer.name,"Tester");eq(peer.level,18);eq(peer.source,"Community")
eq(H.ParseCommunity(packet,"Imposter","Realm",1001),nil)
eq(H.ParseCommunity("1$Tester~G~1~1~1~900~~~","Tester","Realm",1001),nil)
eq(H.ParseCommunity("2$checksum","Tester","Realm",1001),nil)
eq(H.ParseCommunity(string.rep("a",2049),"Tester","Realm",1001),nil)
local records={}
eq(H.Insert(records,peer,5),true)
eq(H.Insert(records,r,5),false,"official merges community")
eq(#records,1);eq(records[1].source,"Blizzard");eq(records[1].classID,2)
eq(records[1].date,1001,"dedup retains first receipt")
peer.date=1002
eq(H.Insert(records,peer,5),false)
eq(records[1].source,"Blizzard","unverified cannot downgrade")
eq(#H.Filter(records,"tester","all",1,"Realm"),1)
eq(#H.Filter(records,"not found","all",1,"Realm"),0)
eq(#H.Filter(records,"","all",20,"Realm"),0)
eq(#H.Filter(records,"","all",0,"Elsewhere"),0)
eq(#H.Filter(records,"[","all",0,"Realm"),1,"search uses literal text")
eq(H.Stats(records).average,18)
eq(H.Stats({}).average,nil)
for i=1,8 do H.Insert(records,{name="Player"..i,realm="Realm",date=1100+i,source="Blizzard",level=i},5) end
eq(#records,5);eq(records[1].name,"Player4");eq(H.Stats(records).average,6)
H.Insert(records,{name="Ancient",realm="Realm",date=1,source="Imported",level=60},5)
eq(#records,5);eq(records[1].name,"Player4","old imports cannot evict recent records")
local many={}
for i=1,400 do H.Insert(many,{name="P"..i,realm="Realm",date=i,source="Imported",level=10},500) end
eq(H.Insert(many,{name="P1",realm="Realm",date=1,source="Imported",level=10},500),false,"repeat import dedups beyond 300")
eq(#many,400)

local now=2000
function time()return now end
function GetTime()return now end
function GetRealmName()return "Realm"end
function date()return "2026-09-23 13:00"end
function GetClassInfo()return "Paladin","PALADIN"end
function UnitGUID()return "Player-1"end
function UnitName()return "SelfPlayer"end
function UnitLevel()return 30 end
function UnitClass()return "Warrior","WARRIOR",1 end
function GetGuildInfo()return "Guild"end
function GetRealZoneText()return "Duskwood"end
C_ClassicHardcore={IsHardcoreSelf=function()return true end}
function GetChannelName()return 0 end
local joins=0
function JoinChannelByName()joins=joins+1 end
local pending={}
C_Timer={After=function(delay,fn)pending[#pending+1]={delay,fn}end}
local function flush()
    local callbacks=pending;pending={}
    for _,item in ipairs(callbacks)do item[2]()end
end
local messages={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg)messages[#messages+1]=msg end}
RAID_CLASS_COLORS={PALADIN={r=1,g=.5,b=.7}}
UISpecialFrames={}
SlashCmdList={}
tinsert=table.insert
SOUNDKIT={RAID_WARNING=1}
local sounds=0
function PlaySound()sounds=sounds+1 end
function PlaySoundFile()sounds=sounds+1; return true,sounds end
local methods={}
local frames={}
function CreateFrame(_,name,parent)
    local f=setmetatable({scripts={},shown=true,parent=parent},{__index=methods})
    frames[#frames+1]=f
    if name then _G[name]=f end
    return f
end
function methods:HasFocus()return false end
function methods:GetFont()return "font",12,""end
function methods:CreateFontString()return CreateFrame()end
function methods:CreateTexture()return CreateFrame()end
function methods:SetMinMaxValues()end
function methods:SetValueStep()end
function methods:SetObeyStepOnDrag()end
function methods:SetOrientation()end
function methods:SetThumbTexture()end
function methods:GetThumbTexture()return CreateFrame()end
function methods:SetValue(value)self.value=value end
function methods:CreateMaskTexture()return CreateFrame()end
function methods:AddMaskTexture(mask)self.mask=mask end
function methods:GetHighlightTexture()return CreateFrame()end
function methods:SetText(text)self.text=text end
function methods:GetText()return self.text or ""end
function methods:GetStringHeight()return 200 end
function methods:GetStringWidth()return #(self.text or "")*7 end
function methods:SetSize(w,h)self.width,self.height=w,h end
function methods:GetWidth()return self.width or 140 end
function methods:GetHeight()return self.height or 140 end
function methods:GetCenter()return 0,0 end
function methods:GetEffectiveScale()return 1 end
function methods:SetPoint(...)self.point={...}end
function methods:GetPoint()return unpack(self.point)end
function methods:SetScript(name,fn)self.scripts[name]=fn end
function methods:RegisterEvent(event)self.events=self.events or {};self.events[event]=true end
function methods:IsEventRegistered(event)return self.events and self.events[event] or false end
function methods:UnregisterEvent(event)if self.events then self.events[event]=nil end end
function methods:SetShown(value)self.shown=value end
function methods:IsShown()return self.shown end
function methods:Show()self.shown=true end
function methods:Hide()self.shown=false end
function methods:SetChecked(value)self.checked=value end
function methods:GetChecked()return self.checked end
for _,name in ipairs({"SetShadowColor","SetShadowOffset","SetEnabled","SetTextInsets","SetParent","SetFont","SetJustifyH","SetJustifyV","SetWidth","SetHeight","SetWordWrap","SetFrameStrata",
    "SetClampedToScreen","SetMovable","EnableMouse","SetBackdrop","SetBackdropColor","SetBackdropBorderColor",
    "SetNormalTexture","SetHighlightTexture","SetVertexColor","SetColorTexture","SetAllPoints","SetTexture",
    "SetAlpha","SetTextColor","RegisterForClicks","RegisterForDrag","SetAutoFocus","SetMaxLetters",
    "SetNumeric","SetScale","ClearAllPoints","ClearFocus","StartMoving","StopMovingOrSizing","SetScrollChild","SetVerticalScroll","SetFrameLevel","SetTexCoord"})do
    methods[name]=function()end
end
UIParent=CreateFrame();Minimap=CreateFrame()
RaidWarningFrame=CreateFrame()
RaidWarningFrame:RegisterEvent("HARDCORE_DEATHS")
RaidWarningFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
GameTooltip={SetOwner=function()end,SetText=function()end,AddLine=function()end,Show=function()end,Hide=function()end}
assert(loadfile("Deaths/Core.lua"))("HardcoreBuddy",addon)
assert(loadfile("Deaths/UI.lua"))("HardcoreBuddy",addon)
-- Events.lua is loaded with the actual addon argument in game.
local eventLoader=assert(loadfile("Deaths/Events.lua"))
eventLoader("HardcoreBuddy",addon)
local eventFrame=frames[#frames]
eventFrame.scripts.OnEvent(eventFrame,"ADDON_LOADED","HardcoreBuddy")
eq(H.nativeSupported,true)
eq(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"),false,"default death announcement replaced")
eq(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"),true,"raid warnings preserved")
eq(eventFrame:IsEventRegistered("HARDCORE_DEATHS"),true,"journal still receives native reports")
eq(H.alert.point[2],RaidWarningFrame,"replacement uses Blizzard announcement anchor")
H.db.settings.alerts=false;H:ApplySettings()
eq(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"),true,"disabling restores original message")
H.db.settings.alerts=true;H:ApplySettings()
eq(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"),false,"reenabling removes duplicate")
H.nativeSupported=false;H:UpdateAnnouncementReplacement()
eq(RaidWarningFrame:IsEventRegistered("HARDCORE_DEATHS"),true,"unsupported client preserves default")
H.nativeSupported=true;H:UpdateAnnouncementReplacement()
eq(H.host:IsShown(),false);eq(H.mini:IsShown(),true)
eq(H.mini.width,360)
eq(H.mini.height,218,"redesigned compact viewer")
eq(H.minimap,nil,"embedded module has no second minimap button")
eq(H.window.width,nil,"journal sizing belongs to parent page")
eq(H.db.settings.community,false);eq(H.db.settings.sound,true,"alert sound defaults on")
eventFrame.scripts.OnEvent(eventFrame,"PLAYER_ENTERING_WORLD");flush();eq(joins,1,"official death channel joins without community opt-in")
eventFrame.scripts.OnEvent(eventFrame,"HARDCORE_DEATHS","[Tester] has been slain by a Wolf in Elwynn! They were level 18")
eq(#H.db.records,1);eq(H.alert:IsShown(),true)
eq(H.alert.description:GetText(),"Wolf  |  Elwynn","alert omits repeated character announcement")
eventFrame.scripts.OnEvent(eventFrame,"HARDCORE_DEATHS","[Tester] has been slain by a Wolf in Elwynn! They were level 18")
eq(#H.db.records,1)
H:Slash("test");eq(#H.db.records,1,"preview never adds fake history")
eq(H.alert.record,H.db.records[1],"preview uses actual history")
eq(H.ToggleWatch,nil);eq(H.IsWatched,nil)
H:Slash("");eq(H.window:IsShown(),true)
H:Slash("settings");eq(H.options:IsShown(),true)
H:ShowDetails(H.db.records[1]);eq(H.details:IsShown(),true)
eq(H.details.watch,nil,"player watching removed")
H:Slash("mini");eq(H.mini:IsShown(),false)
H:Slash("lock");eq(H.db.settings.locked,false)
H:Slash("resetposition");eq(next(H.db.positions),nil)
H.db.settings.community=true
H:JoinCommunity();eq(joins,2)
eventFrame.scripts.OnEvent(eventFrame,"CHAT_MSG_CHANNEL",packet,"Tester","Common","1. other",nil,nil,nil,nil,"other")
eq(#H.db.records,1,"wrong channel ignored")
eventFrame.scripts.OnEvent(eventFrame,"CHAT_MSG_CHANNEL",packet,"Tester","Common","1. hcdeathalertschannel",nil,nil,nil,nil,"hcdeathalertschannel")
eq(#H.db.records,1,"community merge without duplicate")
eventFrame.scripts.OnEvent(eventFrame,"PLAYER_DEAD")
eq(#H.db.records,2);eq(H.db.records[2].source,"Self")
deathlog_data={Realm={a={name="Legacy",level=25,date=1900,guild="Old Guild"}}}
H:ImportLegacy();flush()
eq(#H.db.records,3);eq(H.db.records[1].name,"Legacy")
H:ImportLegacy();flush();eq(#H.db.records,3,"repeat legacy import idempotent")
H.mode="all";H:Refresh();eq(#H.filtered,3)
H.mode="verified";H:Refresh();eq(#H.filtered,3,"stale verified state does not hide reports")
H.db.settings.sound=true;local before=sounds;H:Slash("test");eq(sounds,before+1)
H.alert.scripts.OnUpdate(H.alert,3.5);eq(H.alert:IsShown(),false)
eq(H:Cause({npcID=-2}),"Drowning")
eq(H:Cause({npcID=-1}),"Not reported")
H.MAX_RECORDS=100
deathlog_data={Realm={}}
for i=1,151 do deathlog_data.Realm[i]={name="Old"..i,level=10,date=1000+i} end
H:ImportLegacy()
eq(H.importing,true,"large import yields between batches")
for i=1,100 do if H.importing then flush() end end
eq(H.importing,false,"batched import finishes")
eq(#H.db.records,100,"large import respects retention cap")
eq(H.db.records[#H.db.records].source,"Self","import retains newest live reports")
for i=2,#H.db.records do assert(H.db.records[i-1].date<=H.db.records[i].date,"history is chronological") end
-- Chat set to everyone, native warnings filtered to guild: collection stays broad.
H.db.records={};H.alertedRecords=nil;H.db.settings.community=false
H.db.settings.alerts=true;H.db.settings.minAlertLevel=1
local alertCount=0
H.ShowAlert=function() alertCount=alertCount+1 end
local function chat(message, channel)
    eventFrame.scripts.OnEvent(eventFrame,"CHAT_MSG_CHANNEL",message,"","", "1. "..channel,
        nil,nil,nil,nil,channel)
end
local function native(message)
    eventFrame.scripts.OnEvent(eventFrame,"HARDCORE_DEATHS",message)
end
local stranger="[Stranger] has been slain by a Wolf in Elwynn! They were level 18"
chat(stranger,"HardcoreDeaths")
eq(#H.db.records,1,"all-player chat recorded with community disabled")
eq(H.db.records[1].source,"Blizzard","official chat remains verified")
eq(#H.filtered,1,"chat report visible in journal")
eq(alertCount,0,"chat-only stranger does not bypass guild warning selection")
chat(stranger,"HardcoreDeaths")
eq(#H.db.records,1,"duplicate chat ignored")
local guildmate="[Guildmate] has been slain by a Wolf in Elwynn! They were level 18"
chat(guildmate,"HardcoreDeaths");native(guildmate);native(guildmate)
eq(#H.db.records,2,"chat-first guild report stored once")
eq(alertCount,1,"chat-first native warning alerts exactly once")
local other="[OtherGuildmate] has been slain by a Wolf in Elwynn! They were level 18"
native(other);chat(other,"HardcoreDeaths");native(other)
eq(#H.db.records,3,"native-first report stored once")
eq(alertCount,2,"native-first warning alerts exactly once")
chat("Ordinary chat","General")
eq(#H.db.records,3,"unrelated channel excluded")
H.db.settings.alerts=false
chat("[Silent] drowned to death in Westfall! They were level 20","HardcoreDeaths")
eq(#H.db.records,4,"disabled alerts do not disable journal")
eq(alertCount,2,"disabled alerts remain silent")
eq(RaidWarningFrame:IsEventRegistered("CHAT_MSG_RAID_WARNING"),true,"ordinary warnings remain intact")
print("PASS: "..passed.." embedded death-module assertions")
