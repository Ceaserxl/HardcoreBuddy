-- Independent Classic talent recommendations with opt-in, acknowledged spending.
local _,A=...
local T={}; A.TalentAdvisor=T
function T:IsEnabled() return A.db and A.db.talentAdvisorEnabled~=false end
function T:SetEnabled(enabled)
    A.db.talentAdvisorEnabled=not not enabled
    if enabled then self.checkAutomatic=true end
    if A.TalentRanks then A.TalentRanks:Refresh() end
    if A.window and A.window:IsShown() then A:Refresh() end
end
local D=A.Data
local tokens={Druid="DRUID",Hunter="HUNTER",Mage="MAGE",Paladin="PALADIN",Priest="PRIEST",Rogue="ROGUE",Shaman="SHAMAN",Warlock="WARLOCK",Warrior="WARRIOR"}
local function settings()
    if not A.characterDB then return end
    A.characterDB.advisors=A.characterDB.advisors or {}
    local s=A.characterDB.advisors; s.builds=s.builds or {}
    return s
end
local function row(title,body,action,meta,icon)
    return {title=title,body=body,action=action,meta=meta,icon=icon}
end
local function card(title,note,blocks) return {title=title,note=note,blocks=blocks} end
local function action(command,id,class) return {kind="advisor",command=command,id=id,class=class} end
local function spellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then return C_Spell.GetSpellTexture(id) end
    if GetSpellTexture then return GetSpellTexture(id) end
    return 134400
end

function T:Build(class,level)
    local builds=D.AdvisorBuilds[class]
    if not builds then return end
    local s=settings()
    local chosen=s and s.builds[class]
    if chosen and builds[chosen] then return builds[chosen],true end
    return self:DefaultBuild(class,level),false
end

function T:DefaultBuild(class,level)
    local builds=D.AdvisorBuilds[class]
    if not builds then return end
    -- The first path is the Hardcore default. Short early-level phases switch
    -- to their next path when their stated range ends, with respec advice.
    for _,build in ipairs(builds) do
        if level<=build.maxLevel then return build end
    end
    return builds[#builds]
end

function T:ReadCurrent(class,level)
    local _,actual=UnitClass("player")
    if class~=actual then return nil,"Preview: recommendations for another class" end
    local result={ranks={},indices={},icons={},names={},points=0}
    if level<10 then result.unspent=0; return result end
    local getCount=GetNumTalents or (C_SpecializationInfo and C_SpecializationInfo.GetNumTalents)
    local modern=C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo
    if not getCount or not (modern or GetTalentInfo) then return nil,"Open your Talents window to load talent data." end
    local coordinates={}
    for key,t in pairs(D.AdvisorTalents[class] or {}) do coordinates[t.tree..":"..t.tier..":"..t.column]=key end
    for tree=1,3 do
        local count=getCount(tree,false,false)
        if type(count)~="number" or count<1 or count>50 then return nil,"Talent data is loading. Open Talents and try again." end
        for index=1,count do
            local info
            if modern then
                info=modern({specializationIndex=tree,talentIndex=index,isInspect=false,isPet=false})
            else
                local name,icon,tier,column,rank,maxRank=GetTalentInfo(tree,index,false,false)
                if name then info={name=name,icon=icon,tier=tier,column=column,rank=rank,maxRank=maxRank} end
            end
            if not info or type(info.rank)~="number" then return nil,"Talent data is loading. Open Talents and try again." end
            local key=coordinates[tree..":"..tostring(info.tier)..":"..tostring(info.column)]
            local node=key and D.AdvisorTalents[class][key]
            if not node or node.maxRank~=info.maxRank or info.rank<0 or info.rank>info.maxRank then
                return nil,"This talent tree does not match Classic Era. Recommendations are unavailable."
            end
            result.ranks[key]=info.rank; result.indices[key]=index
            result.icons[key]=info.icon; result.names[key]=info.name
            result.points=result.points+info.rank
        end
    end
    for key in pairs(D.AdvisorTalents[class]) do
        if result.ranks[key]==nil then return nil,"Talent data is incomplete. Open Talents and try again." end
    end
    local available=UnitCharacterPoints and UnitCharacterPoints("player")
    result.unspent=type(available)=="number" and available or math.max(0,level-9-result.points)
    return result
end

function T.Plan(class,level,build,ranks)
    ranks=ranks or {}
    local nodes=D.AdvisorTalents[class]
    local target,spent,trees={},0,{0,0,0}
    for _,key in ipairs(build.steps) do target[key]=(target[key] or 0)+1 end
    local result={target=target,divergences={},build=build}
    for key,rank in pairs(ranks or {}) do
        local node=nodes[key]
        if node then
            spent=spent+rank; trees[node.tree]=trees[node.tree]+rank
            if rank>(target[key] or 0) then result.divergences[#result.divergences+1]=node.name end
        end
    end
    table.sort(result.divergences)
    result.spent=spent
    if level<10 then result.status="Talents unlock at level 10"; return result end
    if level<build.minLevel then result.status="This path starts at level "..build.minLevel; return result end
    if #result.divergences>0 then result.status="Respec needed to follow this path"; return result end
    local seen={}
    for position,key in ipairs(build.steps) do
        seen[key]=(seen[key] or 0)+1
        local node=nodes[key]
        if (ranks[key] or 0)<seen[key] then
            local prerequisite=node.prerequisite
            local ready=trees[node.tree]>=(node.tier-1)*5 and
                (not prerequisite or (ranks[prerequisite] or 0)==nodes[prerequisite].maxRank)
            if ready then
                result.next={key=key,rank=(ranks[key] or 0)+1,position=position,tree=node.tree}
                result.status=spent<level-9 and "Next recommended point" or "Next level"
                return result
            end
        end
    end
    result.status=spent>=#build.steps and "Path complete" or "No legal next point"
    return result
end

function T:LearnNext(expectedBuild,expectedKey,expectedRank)
    if not self:IsEnabled() then return false end
    if A:GetContext().mode=="preview" then return false end
    if InCombatLockdown and InCombatLockdown() then A:Print("Spend talent points after combat."); return false end
    local _,class=UnitClass("player"); local level=UnitLevel("player")
    local build=self:Build(class,level)
    local live,reason=self:ReadCurrent(class,level)
    if not build or not live then A:Print(reason or "Talent data unavailable."); return false end
    local plan=self.Plan(class,level,build,live.ranks)
    local nextPoint=plan.next
    -- Do not spend a different point if a stale row is clicked after a respec,
    -- class/build switch or another addon has spent the previous point.
    if build.id~=expectedBuild or not nextPoint or nextPoint.key~=expectedKey or nextPoint.rank~=expectedRank then
        A:Refresh(); return false
    end
    if live.unspent<1 or plan.spent>=level-9 or not LearnTalent then return false end
    LearnTalent(nextPoint.tree,live.indices[nextPoint.key],false)
    return true
end

function T:ApplyUnused(automatic)
    if self.applying or not self:IsEnabled() or not A.characterDB then return false end
    if A:GetContext().mode=="preview" or (InCombatLockdown and InCombatLockdown()) then return false end
    local _,class=UnitClass("player"); local level=UnitLevel("player")
    local build=self:Build(class,level)
    local live=self:ReadCurrent(class,level)
    if not build or not live or live.unspent<1 then return false end
    self.applying={build=build.id,class=class,automatic=automatic,elapsed=0}
    A.needsRefresh=true
    self:ContinueApplying()
    return true
end

function T:ContinueApplying()
    local run=self.applying; if not run then return end
    if not self:IsEnabled() or A:GetContext().mode=="preview" or (InCombatLockdown and InCombatLockdown())
        or (run.automatic and not A.characterDB.autoApplyTalents) then self.applying=nil; return end
    local _,class=UnitClass("player"); local level=UnitLevel("player")
    local build=self:Build(class,level); local live=self:ReadCurrent(class,level)
    if not live or class~=run.class or not build or build.id~=run.build then self.applying=nil; return end
    -- A server update must acknowledge the last request before another is sent.
    if run.key then
        if live.ranks[run.key]~=run.rank then return end
        run.key=nil; run.elapsed=0
    end
    local nextPoint=self.Plan(class,level,build,live.ranks).next
    if live.unspent<1 or not nextPoint then self.applying=nil; return end
    run.key=nextPoint.key; run.rank=nextPoint.rank; run.elapsed=0
    if not self:LearnNext(build.id,nextPoint.key,nextPoint.rank) then self.applying=nil end
end

function T:OpenTalents()
    if InCombatLockdown and InCombatLockdown() then A:Print("Open Talents after combat."); return end
    if not ToggleTalentFrame then
        if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_TalentUI")
        elseif UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_TalentUI") end
    end
    if ToggleTalentFrame then ToggleTalentFrame() end
end

function T:Activate(a)
    if a.command=="hideLearned" then
        A.state.hideLearnedTalents=not A.state.hideLearnedTalents
        A:Refresh(true); return
    end
    if a.command=="path" then
        A:CommitInputs()
        A.history=A.history or {}; A.history[#A.history+1]=A.state
        A.state={view="advisors",filter="Talents",talentPath=true}
        A:Refresh(true); return
    end
    if a.command=="settings" then A:OpenSettings("Gear Advisor"); return end
    if a.command=="talentSettings" then A:OpenSettings("Talent Advisor"); return end
    local s=settings(); if not s then return end
    if a.command=="build" then
        if D.AdvisorBuilds[a.class] and D.AdvisorBuilds[a.class][a.id] then s.builds[a.class]=a.id end
    elseif a.command=="defaultBuild" then s.builds[a.class]=nil
    elseif a.command=="toggleGear" then A.GearAdvisor:SetEnabled(not A.GearAdvisor:IsEnabled())
    elseif a.command=="learn" then self:LearnNext(a.id,a.key,a.rank)
    elseif a.command=="open" then self:OpenTalents()
    end
    if a.command=="build" or a.command=="defaultBuild" then
        s.gearProfile=nil
        if A.AuctionUpgrades then A.AuctionUpgrades:Invalidate() end
        if A.GearIndicators then A.GearIndicators:Invalidate() end
    end
    A.GearAdvisor.revision=A.GearAdvisor.revision+1
    if A.GearBagAdvisor then A.GearBagAdvisor:Changed() end
    if A.TalentRanks then A.TalentRanks:Refresh() end
    A.GearAdvisor:RefreshTooltips(); A:Refresh(true)
end

function T:Document(context,state)
    local class=tokens[context.characterClass]
    local level=context.level
    local doc={context=context,view="advisors",cards={}}
    if not D.AdvisorBuilds[class] then return doc end
    local filter=state.filter or "Gear"
    local _,actual=UnitClass("player")
    local preview=context.mode=="preview"
    if filter=="Gear" then
        local profile=A.GearAdvisor:CurrentProfile()
        local description=profile and (profile.name.." | "..(profile.buildName or "Leveling default")) or "Character data loading"
        local blocks={
            row("|cff73d696Green: upgrade|r   |cfff56e61Red: downgrade|r","Enchants, armor kits, procs, use effects and set bonuses are excluded. Check the stat losses before replacing an item."),
            row("Two slots and weapons","Each ring or trinket is compared separately. Two-handed weapons replace both hands; zero-score baselines are labeled without an invented percentage."),
            row("Gear advisor settings", "Configure scoring, tooltips, upgrade markers and automatic equipping in Settings.",action("settings"))}
        doc.cards[1]=card("Gear Advisor",description.."\nPercentage change in weighted item stats, not a damage or survival simulation.",blocks)
        return doc
    end
    if not self:IsEnabled() then
        doc.cards[1]=card("Talent Advisor","Disabled",{row("Talent Advisor settings","Enable talent recommendations in Settings.",action("talentSettings"))})
        return doc
    end
    local build,manual=self:Build(class,level)
    local live,reason
    if not preview then live,reason=self:ReadCurrent(class,level) else reason="Preview: no talent points will be spent." end
    local ranks=live and live.ranks or {}
    local plan=self.Plan(class,level,build,ranks)
    local top={}
    if live then
        top[#top+1]=row("Next Talent",plan.status,
            action("open"),#plan.divergences>0 and table.concat(plan.divergences,", ") or nil)
    else top[#top+1]=row("Next Talent",reason,not preview and action("open") or nil) end
    local nextPoint=plan.next
    if nextPoint then
        local node=D.AdvisorTalents[class][nextPoint.key]
        local canLearn=live and live.unspent>0 and plan.spent<level-9 and level>=build.minLevel
        local learn=canLearn and action("learn",build.id) or nil
        if learn then learn.key=nextPoint.key; learn.rank=nextPoint.rank end
        local nextRow=top[1]
        nextRow.body=live and "Click to Apply Talent" or reason
        nextRow.recommendation={summary=nextRow.body,
            name=live and live.names[nextPoint.key] or node.name,
            detail=node.treeName.." | Rank "..nextPoint.rank.." / "..node.maxRank}
        nextRow.body=nextRow.body.."\n"..(live and live.names[nextPoint.key] or node.name)..
            "\n"..node.treeName.." | Rank "..nextPoint.rank.." / "..node.maxRank
        nextRow.icon=live and live.icons[nextPoint.key] or spellIcon(node.spellID)
        if learn then nextRow.action=learn; nextRow.meta=nil end
    end
    top[#top+1]=row("Point-by-point path","View the complete talent path.",action("path"))
    top[#top+1]=row("Talent Advisor settings","Choose your talent build and configure auto talents.",action("talentSettings"))
    local subtitle=context.characterClass.." | Level "..level
    if live then subtitle=subtitle.." | "..live.points.." spent | "..live.unspent.." unspent" end
    doc.cards[1]=card("Talent Advisor",subtitle,top)
    doc.cards[1].headerText=build.name
    if not state.talentPath then return doc end
    local steps,occurrences={},{}
    for index,key in ipairs(build.steps) do
        occurrences[key]=(occurrences[key] or 0)+1
        local node=D.AdvisorTalents[class][key]
        local rank=occurrences[key]
        local learned=(ranks[key] or 0)>=rank
        local nextStep=nextPoint and nextPoint.key==key and nextPoint.rank==rank
        local color=learned and "73d696" or nextStep and "efc26e" or "abb0b8"
        local atLevel=math.max(build.minLevel,index+9)
        local title="|cff"..color..""..(live and live.names[key] or node.name).."  "..rank.."/"..node.maxRank.."|r"
        if not state.hideLearnedTalents or not learned then
            steps[#steps+1]=row(title,"Level "..atLevel.."  |  "..node.treeName,nil,
                learned and "Learned" or nextStep and "Next Point" or nil,live and live.icons[key] or spellIcon(node.spellID))
            steps[#steps].talentColumns={tostring(atLevel),live and live.names[key] or node.name,
                rank.." / "..node.maxRank,node.treeName,
                "|cff"..color..(learned and "Learned" or nextStep and "Next Point" or "Upcoming").."|r"}
            steps[#steps].spellId=node.spellID
            if live and live.indices[key] then
                steps[#steps].talentTooltip={tree=node.tree,index=live.indices[key]}
            end
        end
    end
    if #steps==0 then steps[1]=row("All talents learned","Use Show Learned to review the complete path.") end
    doc.cards={card("Your point-by-point path",context.characterClass.." | "..build.name.." | Scroll to see the complete path.",steps)}
    doc.cards[1].talentTable=true; doc.cards[1].fullWidth=true
    doc.cards[1].headerAction={label=state.hideLearnedTalents and "Show Learned" or "Hide Learned",action=action("hideLearned")}
    return doc
end

local events=CreateFrame("Frame"); T.events=events
for _,event in ipairs({"CHARACTER_POINTS_CHANGED","PLAYER_TALENT_UPDATE","PLAYER_LEVEL_UP","PLAYER_ENTERING_WORLD","PLAYER_REGEN_ENABLED","ADDON_LOADED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" and name~="Blizzard_TalentUI" then return end
    T.checkAutomatic=true
    if A.window and A.window:IsShown() and A.state and A.state.view=="advisors" then A:Refresh() end
end)
events:SetScript("OnUpdate",function(_,elapsed)
    if T.applying then
        T.applying.elapsed=T.applying.elapsed+elapsed
        T.pollElapsed=(T.pollElapsed or 0)+elapsed
        if T.pollElapsed<0.2 then return end
        T.pollElapsed=0
        if T.applying.elapsed>4 then T.applying=nil; A:Print("Talent application stopped: waiting for the server. Try Apply unused points again.")
        else T:ContinueApplying() end
        if not T.applying then A.needsRefresh=true end
    elseif T.checkAutomatic then
        T.checkAutomatic=nil
        if A.characterDB and A.characterDB.autoApplyTalents then T:ApplyUnused(true) end
    end
end)
