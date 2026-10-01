local A=TestAddon
local T,D=A.TalentAdvisor,A.Data
local count,paths,points=0,0,0
local function check(ok,why) count=count+1; assert(ok,why) end
local classCount=0
for class,builds in pairs(D.AdvisorBuilds) do
    classCount=classCount+1
    local nodes=D.AdvisorTalents[class]
    for _,build in ipairs(builds) do
        paths=paths+1
        local ranks,spent={}, {0,0,0}
        check(#build.steps==build.maxLevel-9,"Complete level range")
        for index,key in ipairs(build.steps) do
            local n=nodes[key]
            local level=math.max(build.minLevel,index+9)
            check(n and spent[n.tree]>=(n.tier-1)*5,"Tier unlocked before learning")
            check((ranks[key] or 0)<n.maxRank,"Rank limit")
            check(not n.prerequisite or ranks[n.prerequisite]==nodes[n.prerequisite].maxRank,"Prerequisite fully learned")
            local plan=T.Plan(class,level,build,ranks)
            check(plan.next and plan.next.key==key and plan.next.rank==(ranks[key] or 0)+1,"Next point follows a legal path")
            ranks[key]=(ranks[key] or 0)+1; spent[n.tree]=spent[n.tree]+1; points=points+1
        end
        check(T.Plan(class,60,build,ranks).status=="Path complete","Finished path")
        check(T.Plan(class,9,build,{}).next==nil,"No points below ten")
        if build.minLevel>10 then check(T.Plan(class,build.minLevel-1,build,{}).next==nil,"Respec phase level gate") end
    end
    for level=1,60 do check(T:Build(class,level)~=nil,"Default path at every level") end
end
check(classCount==9 and paths==16,"All nine classes and 16 paths")
check(D.AdvisorBuilds.MAGE[1].steps[30]=="frostChanneling" and D.AdvisorBuilds.MAGE[1].steps[31]=="iceBarrier","Corrected level-40 Ice Barrier")
for class,threshold in pairs({DRUID=21,ROGUE=30,SHAMAN=20,WARRIOR=40}) do
    check(T:Build(class,threshold-1).id==1 and T:Build(class,threshold).id==2,"Automatic phase transition")
end

-- Native live trees use coordinates, not English talent names or assumed order.
MOCK.class,MOCK.level="HUNTER",40
local build=D.AdvisorBuilds.HUNTER[1]
local treeRows={ {}, {}, {} }
local ranks={}
for i=1,30 do local k=build.steps[i]; ranks[k]=(ranks[k] or 0)+1 end
for key,n in pairs(D.AdvisorTalents.HUNTER) do treeRows[n.tree][#treeRows[n.tree]+1]={key=key,node=n} end
for _,tree in ipairs(treeRows) do table.sort(tree,function(a,b) return a.node.column*10+a.node.tier>b.node.column*10+b.node.tier end) end
GetNumTalents=function(tree,inspect,pet) assert(inspect==false and pet==false); return #treeRows[tree] end
local available=1
UnitCharacterPoints=function() return available end
C_SpecializationInfo={GetTalentInfo=function(q)
    assert(q.isInspect==false and q.isPet==false)
    local r=treeRows[q.specializationIndex][q.talentIndex]; local n=r.node
    return {name="Localized "..n.name,icon=132127,tier=n.tier,column=n.column,rank=ranks[r.key] or 0,maxRank=n.maxRank}
end}
local live=T:ReadCurrent("HUNTER",40)
check(live and live.points==30 and live.unspent==1,"Native current ranks and free point")
check(live.names.bestialWrath=="Localized Bestial Wrath","Localized talent names")
check(T:ReadCurrent("MAGE",40)==nil,"Other classes never receive live ranks")
local calls=0
LearnTalent=function(tree,index,pet)
    assert(pet==false)
    local key=treeRows[tree][index].key
    assert(key=="bestialWrath")
    calls=calls+1; ranks[key]=(ranks[key] or 0)+1; available=available-1
end
local combat=false
InCombatLockdown=function() return combat end
check(not T:LearnNext(build.id,"intimidation",1) and calls==0,"Stale recommendation cannot spend a different point")
combat=true
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==0,"Combat guard")
combat=false
check(T:LearnNext(build.id,"bestialWrath",1) and calls==1,"Explicit click spends exactly one correct point")
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==1,"Repeated stale click cannot spend another point")
ranks.bestialWrath=0; available=0
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==1,"No available points")
available=1; ranks.counterattack=1
local plan=T.Plan("HUNTER",40,build,ranks)
check(plan.status=="Respec needed to follow this path" and not plan.next,"Off-path points require respec")
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==1,"Divergent build never auto-spends")
ranks.counterattack=nil
local modern=C_SpecializationInfo.GetTalentInfo
GetTalentInfo=function(tree,index,inspect,pet)
    local n=modern({specializationIndex=tree,talentIndex=index,isInspect=inspect,isPet=pet})
    return n.name,n.icon,n.tier,n.column,n.rank,n.maxRank
end
C_SpecializationInfo=nil
check(T:ReadCurrent("HUNTER",40).points==30,"Classic compatibility talent API")
local saved=GetTalentInfo
GetTalentInfo=function() return nil end
check(T:ReadCurrent("HUNTER",40)==nil,"Loading talents remain unknown")
GetTalentInfo=saved

A.db.profile.mode="live"; A:HandleSlashCommand("talents")
check(A.state.view=="advisors" and A.state.filter=="Talents","Slash entry point")
check(A.document.cards[1].title=="Talent Advisor" and #A.document.cards[2].blocks==51,"All 51 steps in one list")
check(A.window.content:GetHeight()>A.window.scroll:GetHeight(),"Continuous scrolling, no paging")
check(A.window.sidebarTitle:GetText()=="ADVISORS","Sidebar identity")
local lesson=A.document.cards[1].blocks[2]
check(lesson.action and lesson.action.command=="learn" and lesson.icon==132127,"Visible single-point button and native icon")
check(calls==1,"Opening advisor never spends a point")
for _,block in ipairs(A.document.cards[1].blocks) do
    check(block.title~="Choose a talent path" and (not block.action or block.action.command~="talentSettings"),"Talent page no longer has a path selector")
end
A:OpenSettings("Talent Advisor")
check(A.state.view=="settings" and A.state.filter=="Talent Advisor","Build selection moved to Talent Advisor settings")
T:Activate({kind="advisor",command="build",class="HUNTER",id=1})
check(A.state.filter=="Talent Advisor" and T:Build("HUNTER",40).id==1,"Persistent selected path")
local names={DRUID="Druid",HUNTER="Hunter",MAGE="Mage",PALADIN="Paladin",PRIEST="Priest",ROGUE="Rogue",SHAMAN="Shaman",WARLOCK="Warlock",WARRIOR="Warrior"}
for class,name in pairs(names) do
    A.db.profile.mode="preview"; A.db.profile.characterClass=name; A.db.profile.level=60
    A.state={view="advisors",filter="Talents"}; A:Refresh(true)
    check(A.document.view=="advisors" and A.document.cards[1].note:find(name,1,true),"Preview class stays on advisor page")
    for _,b in ipairs(A.document.cards[1].blocks) do check(not b.action or b.action.command~="learn","Preview cannot spend points") end
    check(#A.document.cards[2].blocks>0,"Every preview class has a path")
end
check(calls==1,"Previewing all classes never spends")
A.db.profile.mode="live"; A:HandleSlashCommand("gear")
check(A.state.filter=="Gear","Gear slash opens settings")
for _,block in ipairs(A.document.cards[1].blocks) do
    check(not block.action or block.action.command~="snapshot","Snapshots are not listed in Advisors Gear")
end
T:Activate({kind="advisor",command="build",class="HUNTER",id=1})
check(A.GearAdvisor:CurrentProfile().id==T:Build("HUNTER",40).profile,"Talent path sets the gear role")
T:Activate({kind="advisor",command="defaultBuild",class="HUNTER"})
check(not A.GearAdvisor:CurrentProfile().manual,"Automatic path restored")
A:HandleSlashCommand("gear off"); check(not A.db.gearAdvisorEnabled,"Gear can be disabled")
A:HandleSlashCommand("gear on"); check(A.db.gearAdvisorEnabled,"Gear can be enabled")
A:HandleSlashCommand("talents")
-- Blizzard loads the talent window on demand. Attach once, preserving its scripts.
local P=A.TalentPanel
check(not P.frame,"No talent panel is created before the native talent UI loads")
local nativeShows=0
PlayerTalentFrame=CreateFrame("Frame","PlayerTalentFrame",UIParent)
PlayerTalentFrame:SetSize(384,424); PlayerTalentFrame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-60)
PlayerTalentFrame:SetScript("OnShow",function() nativeShows=nativeShows+1 end)
PlayerTalentFrame:Hide()
function PlayerTalentFrame_Refresh() end
function hooksecurefunc(name,callback)
    local original=_G[name]; _G[name]=function(...) original(...); callback(...) end
end
MOCK.FireAll("ADDON_LOADED","Blizzard_TalentUI")
local panel=P.frame
check(panel and panel:GetParent()==PlayerTalentFrame and not panel:IsVisible(),"Panel is parented to the hidden native talent frame")
P:Attach(); PlayerTalentFrame:Show()
check(nativeShows==1 and panel:IsVisible(),"Native show script survives and attached panel appears")
local point,parent,relative=panel:GetPoint(1)
check(point=="TOPLEFT" and parent==PlayerTalentFrame and relative=="TOPRIGHT","Advisor is attached beside the native window")
check(panel.next:GetText()=="Localized Bestial Wrath" and panel.learn:IsEnabled(),"Panel displays localized next talent and available point")
check(calls==1,"Attaching and showing never spends points")
A.db.profile.mode="preview"; A.db.profile.characterClass="Mage"; A.db.profile.level=60
P:Refresh()
check(panel.next:GetText()=="Localized Bestial Wrath","Attached panel always uses the live character, not planner preview")
A.db.profile.mode="live"
combat=true; MOCK.FireAll("PLAYER_REGEN_DISABLED")
check(not panel.learn:IsEnabled(),"Combat disables the learn button")
combat=false; MOCK.FireAll("PLAYER_REGEN_ENABLED")
check(panel.learn:IsEnabled(),"Leaving combat restores deliberate learning")
MOCK.Click(panel.learn)
check(calls==2 and not panel.learn:IsEnabled() and panel.pointCount:GetText():find("0 available",1,true),"Click spends exactly one point and refreshes the recommendation")
PlayerTalentFrame.pet=true; PlayerTalentFrame_Refresh()
check(not panel:IsShown(),"Player advice is hidden for pet talents")
PlayerTalentFrame.pet=false; PlayerTalentFrame_Refresh()
check(panel:IsVisible(),"Player advice returns when leaving pet talents")
PlayerTalentFrame:Hide(); check(not panel:IsVisible(),"Closing Talents hides its companion panel")
PlayerTalentFrame:Show()
local scoring=A.GearAdvisor:CurrentProfile().id
MOCK.Click(panel.disable)
check(not T:IsEnabled() and not panel:IsShown(),"Disable button immediately hides talent advice")
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==2,"Disabled talent advisor cannot spend points")
check(A.GearAdvisor:CurrentProfile().id==scoring and A.GearAdvisor:IsEnabled(),"Disabling talent advice preserves independent gear scoring")
A:HandleSlashCommand("talents")
check(A.document.cards[1].note=="Disabled" and #A.document.cards==1,"Disabled advisor page does not present active recommendations")
A:OpenSettings("Talent Advisor")
check(A.Settings.pages["Talent Advisor"].toggle.label:GetText()=="Enable Talent Advisor","Settings offers reenable after panel is disabled")
MOCK.Click(A.Settings.pages["Talent Advisor"].toggle)
check(T:IsEnabled() and panel:IsVisible(),"Settings button reenables attached talent panel immediately")
GetTalentInfo=function() return nil end; P:Refresh()
check(not panel.learn:IsEnabled() and panel.recommendation==nil,"Unavailable talent data clears stale actionable advice")
GetTalentInfo=saved; P:Refresh()
A:OpenSettings("Gear Advisor"); MOCK.Click(A.Settings.pages["Gear Advisor"].toggle)
check(not A.GearAdvisor:IsEnabled() and T:IsEnabled(),"Gear disable button leaves talent advice enabled")
check(A.Settings.pages["Gear Advisor"].toggle.label:GetText()=="Enable Gear Advisor","Gear master control reflects disabled state")
MOCK.Click(A.Settings.pages["Gear Advisor"].toggle)
check(A.GearAdvisor:IsEnabled(),"Gear master control reenables gear advice")
A:HandleSlashCommand("talents")
print("PASS: "..count.." talent assertions; "..paths.." legal paths / "..points.." points; live spending, preview isolation and advisor navigation.")
