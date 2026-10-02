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
check(A.document.cards[1].title=="Talent Advisor" and #A.document.cards==1,"Path is collapsed into a button")
local pathLink=A.document.cards[1].blocks[#A.document.cards[1].blocks-1]
check(pathLink.action.command=="path","Dedicated path button")
local overview=A.state
A:Activate(pathLink.action)
check(A.state.talentPath and #A.document.cards==1 and #A.document.cards[1].blocks==51,"All 51 steps in the separate path page")
check(A.window.content:GetHeight()>A.window.scroll:GetHeight() and A:CanGoBack(),"Scrollable path with shared Back")
check(A.document.cards[1].talentTable and #A.window.cards[1].talentHeaders==5,"Talent path has five table columns")
for i,step in ipairs(A.document.cards[1].blocks) do
    local rendered=A.window.cards[1].content.blocks[i]
    check(step.talentColumns[1]==tostring(i+9),"Table preserves level order")
    check(rendered.icon:IsShown() and rendered.icon:GetWidth()==24 and rendered:GetHeight()==32,"Compact table keeps each talent icon")
    check(#rendered.talentCells==5 and not rendered.meta:IsShown(),"Status is in its own column")
end
MOCK.Click(A.window.back)
check(A.state==overview and not A.state.talentPath,"Back restores the talent overview")
check(A.window.cards[1].content.blocks[1].icon:GetWidth()==34 and not A.window.cards[1].talentHeaders[1]:IsShown(),"Back restores overview icon size and hides table headings")
check(A.window.sidebarTitle:GetText()=="ADVISORS","Sidebar identity")
local lesson=A.document.cards[1].blocks[1]
check(lesson.title=="Next Talent" and lesson.recommendation.summary=="Click to apply 1pt","Stable next talent label and compact apply hint")
check(A.document.cards[1].note:find("spent | ",1,true) and A.document.cards[1].note:find(" unspent",1,true),"Point counts follow the advisor level subtitle")
check(lesson.action and lesson.action.command=="learn" and lesson.icon==132127,"Visible single-point button and native icon")
check(#A.document.cards[1].blocks==3 and lesson.body:find("Localized Bestial Wrath",1,true)
    and lesson.body:find("Rank 1 / 1",1,true),"Next recommendation is inside the status item")
check(calls==1,"Opening advisor never spends a point")
for _,block in ipairs(A.document.cards[1].blocks) do
    check(block.title~="Choose a talent path","Talent page no longer has an inline path selector")
end
local settingsLink=A.document.cards[1].blocks[#A.document.cards[1].blocks]
check(settingsLink.action.command=="talentSettings","Talent settings link belongs to Talents")
A:Activate(settingsLink.action)
check(A.state.view=="settings" and A.state.filter=="Talent Advisor","Talent settings row opens the correct section")
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
    A:Activate({kind="advisor",command="path"})
    check(#A.document.cards[1].blocks>0 and A.state.talentPath,"Every preview class has a separate path")
    A:Back()
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
-- Update native rank labels and widen their original borders in place.
local O=A.TalentRanks
check(not O.parent and not HardcoreBuddyTalentPanel,"No side panel exists")
local nativeShows=0
PlayerTalentFrame=CreateFrame("Frame","PlayerTalentFrame",UIParent)
PlayerTalentFrame:SetSize(384,424); PlayerTalentFrame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",30,-60)
PlayerTalentFrame:SetScript("OnShow",function() nativeShows=nativeShows+1 end)
PlayerTalentFrame:Hide()
local selectedTree=1
PanelTemplates_GetSelectedTab=function(frame) assert(frame==PlayerTalentFrame); return selectedTree end
local nativeClicks=0
local nativeClick=function() nativeClicks=nativeClicks+1 end
for i=1,30 do
    local b=CreateFrame("Button","PlayerTalentFrameTalent"..i,PlayerTalentFrame)
    function b:GetName() return self.name end
    b:SetSize(32,32); b:SetScript("OnClick",nativeClick)
    b.rank=b:CreateFontString(b:GetName().."Rank","OVERLAY","GameFontNormalSmall")
    b.rank:SetSize(34,16); b.rank:SetPoint("BOTTOMRIGHT",b,"BOTTOMRIGHT",5,-3)
    b.border=b:CreateTexture(b:GetName().."RankBorder","ARTWORK")
    b.border:SetSize(32,32); b.border:SetPoint("CENTER",b.rank,"CENTER",0,0)
end
function TalentFrame_Update()
    for i=1,30 do
        local b=_G["PlayerTalentFrameTalent"..i]
        local row=treeRows[selectedTree] and treeRows[selectedTree][i]
        b:SetShown(row~=nil)
        if row then
            b:SetPoint("TOPLEFT",PlayerTalentFrame,"TOPLEFT",45+(row.node.column-1)*70,-25-(row.node.tier-1)*50)
            local rank=ranks[row.key] or 0
            b.rank:SetText(tostring(rank)); b.rank:SetShown(rank>0 or available>0)
            b.border:SetShown(b.rank:IsShown())
        end
    end
end
function PlayerTalentFrame_Refresh() TalentFrame_Update() end
function hooksecurefunc(name,callback)
    local original=_G[name]; _G[name]=function(...) original(...); callback(...) end
end
local frameCount=#MOCK.frames
MOCK.FireAll("ADDON_LOADED","Blizzard_TalentUI")
O:Attach(); PlayerTalentFrame:Show(); PlayerTalentFrame_Refresh()
local function rankLabel(key)
    local index=T:ReadCurrent("HUNTER",40).indices[key]
    return _G["PlayerTalentFrameTalent"..index.."Rank"]
end
check(nativeShows==1 and O.parent==PlayerTalentFrame,"Native show script is preserved")
check(rankLabel("bestialWrath"):IsVisible() and rankLabel("bestialWrath"):GetText()=="0/|cff55bbff1|r",
    "Unlearned recommended talent shows current/target rank in blue")
local key=build.steps[1]
local current=ranks[key]
check(rankLabel(key):GetText()==current.."/|cff66cc77"..current.."|r","Completed build ranks are green")
check(calls==1 and not HardcoreBuddyTalentPanel,"Drawing ranks never spends points or creates a side panel")
check(#MOCK.frames==frameCount,"Drawing talent targets creates no frames, textures or font strings")
for label,state in pairs(O.ranks) do
    check(label:GetParent():GetScript("OnClick")==nativeClick,"Native talent clicks remain unchanged")
    check(state.border==_G[label:GetParent():GetName().."RankBorder"] and state.border:GetWidth()==54,
        "Only the existing native rank border widens to fit current/target text")
end
A.db.profile.mode="preview"; A.db.profile.characterClass="Mage"; A.db.profile.level=60
O:Refresh()
check(rankLabel("bestialWrath"):IsVisible(),"Rank text uses live character even when planner previews another class")
A.db.profile.mode="live"
ranks.bestialWrath=1; available=0; MOCK.FireAll("PLAYER_TALENT_UPDATE")
check(rankLabel("bestialWrath"):GetText()=="1/|cff66cc771|r","Spending a point updates the displayed rank")
selectedTree=3; ranks.counterattack=1; PlayerTalentFrame_Refresh()
check(rankLabel("counterattack"):IsVisible() and rankLabel("counterattack"):GetText()=="1/|cffee66550|r",
    "Tree switch reuses icons and shows off-build ranks in red")
selectedTree=4; PlayerTalentFrame_Refresh()
check(next(O.ranks)==nil,"Non-talent tabs clear modified ranks")
for i=1,30 do
    local b=_G["PlayerTalentFrameTalent"..i]
    check(not b.rank:GetText():find("/",1,true) and b.border:GetWidth()==32,"Leaving talents restores native text and border width")
end
selectedTree=1; ranks.counterattack=nil; PlayerTalentFrame_Refresh()
PlayerTalentFrame.pet=true; PlayerTalentFrame_Refresh()
check(rankLabel("bestialWrath"):GetText()=="1","Pet view retains native numbers without build targets")
PlayerTalentFrame.pet=false; PlayerTalentFrame.inspect=true; PlayerTalentFrame_Refresh()
check(rankLabel("bestialWrath"):GetText()=="1","Inspection retains native numbers without player build targets")
PlayerTalentFrame.inspect=false; PlayerTalentFrame_Refresh()
check(rankLabel("bestialWrath"):IsVisible(),"Returning to player talents restores recommendations")
PlayerTalentFrame:Hide(); check(rankLabel("bestialWrath"):GetText()=="1","Closing Talents restores native text")
PlayerTalentFrame:Show()
local scoring=A.GearAdvisor:CurrentProfile().id
T:SetEnabled(false)
check(rankLabel("bestialWrath"):GetText()=="1" and next(O.ranks)==nil,"Disable immediately restores native ranks")
check(rankLabel("bestialWrath"):GetParent().border:GetWidth()==32,"Disable restores the original border size")
check(not T:LearnNext(build.id,"bestialWrath",1) and calls==1,"Disabled talent advisor cannot spend points")
check(A.GearAdvisor:CurrentProfile().id==scoring and A.GearAdvisor:IsEnabled(),"Disabling talent advice preserves gear scoring")
A:HandleSlashCommand("talents")
check(A.document.cards[1].note=="Disabled" and #A.document.cards==1,"Disabled advisor page does not present active recommendations")
A:OpenSettings("Talent Advisor")
check(A.Settings.pages["Talent Advisor"].toggle.label:GetText()=="Enable Talent Advisor","Settings offers reenable")
MOCK.Click(A.Settings.pages["Talent Advisor"].toggle)
check(T:IsEnabled() and rankLabel("bestialWrath"):IsVisible(),"Settings reenables native talent labels immediately")
selectedTree=2; PlayerTalentFrame_Refresh()
local future=rankLabel("efficiency")
check(future:IsShown() and future:GetText():find("0/",1,true),"Recommended future talents show their target in the native hidden rank field")
T:SetEnabled(false)
check(future:GetText()=="0" and not future:IsShown() and not future:GetParent().border:IsShown(),
    "Disable restores native hidden zero-rank text and border with no free points")
T:SetEnabled(true); selectedTree=1; PlayerTalentFrame_Refresh()
GetTalentInfo=function() return nil end; O:Refresh()
check(next(O.ranks)==nil,"Unavailable talent data clears modified ranks")
GetTalentInfo=saved; O:Refresh()
A:OpenSettings("Gear Advisor"); MOCK.Click(A.Settings.pages["Gear Advisor"].toggle)
check(not A.GearAdvisor:IsEnabled() and T:IsEnabled(),"Gear disable button leaves talent advice enabled")
check(A.Settings.pages["Gear Advisor"].toggle.label:GetText()=="Enable Gear Advisor","Gear control reflects disabled state")
MOCK.Click(A.Settings.pages["Gear Advisor"].toggle)
check(A.GearAdvisor:IsEnabled(),"Gear control reenables gear advice")
A:HandleSlashCommand("talents")
print("PASS: "..count.." talent assertions; "..paths.." legal paths / "..points.." points; live spending, preview isolation and advisor navigation.")
