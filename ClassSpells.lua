local _,A=...
local S={pending={}}; A.ClassSpells=S

local function spellInfo(id)
    local name,rank,icon
    if C_Spell and C_Spell.GetSpellInfo then
        local info=C_Spell.GetSpellInfo(id)
        if info then name,icon=info.name,info.iconID end
        if C_Spell.GetSpellSubtext then rank=C_Spell.GetSpellSubtext(id) end
    elseif GetSpellInfo then name,rank,icon=GetSpellInfo(id) end
    if not name and C_Spell and C_Spell.RequestLoadSpellData and not S.pending[id] then
        S.pending[id]=true; C_Spell.RequestLoadSpellData(id)
    end
    return name or ("Spell #"..id.." (loading)"),rank,icon or 134400
end

local function allowed(entry,context,race)
    if entry.faction and entry.faction~=context.faction then return false end
    if entry.race and entry.race~=race then return false end
    if entry.races then
        local found=false
        for _,id in ipairs(entry.races) do if id==race then found=true end end
        if not found then return false end
    end
    return true
end

local function costText(copper)
    if copper==0 then return "Free" end
    if GetCoinTextureString then return GetCoinTextureString(copper,12) end
    local parts={}
    local function coin(value,kind)
        if value>0 then parts[#parts+1]=value.."|TInterface\\MoneyFrame\\UI-"..kind.."Icon:12:12:2:0|t" end
    end
    coin(math.floor(copper/10000),"Gold")
    coin(math.floor(copper/100)%100,"Silver")
    coin(copper%100,"Copper")
    return table.concat(parts," ")
end

-- Hunter ranks use the reviewed pet guide, including skills learned by taming.
-- Use the later of pet level, taming-source level and the level-10 pet unlock.
function S.PetEntries(context)
    if context.characterClass=="Warlock" then return A.Data.DemonGrimoires end
    local levels={}
    if context.characterClass~="Hunter" then return levels end
    for _,ability in ipairs(A.Data.PetGuide.abilities) do
        for index,rank in ipairs(ability.ranks) do
            local source
            if not rank.trainer then
                for _,candidate in ipairs(rank.sources or {}) do
                    if not source or candidate.minLevel<source.minLevel
                        or candidate.minLevel==source.minLevel and candidate.classification=="Normal" and source.classification~="Normal" then source=candidate end
                end
            end
            if rank.trainer or source then
                local level=math.max(10,rank.petLevel,source and source.minLevel or 0)
                local icon=A.Data.PetSkillIcons and A.Data.PetSkillIcons[ability.name]
                local body=rank.trainer and "Pet trainer | Teach through Beast Training."
                    or ("Tame "..source.name.." (level "..source.minLevel..") in "..source.zone.."."
                        ..(source.classification~="Normal" and (" "..source.classification.." encounter.") or ""))
                levels[level]=levels[level] or {}
                levels[level][#levels[level]+1]={title=ability.name.." | Rank "..rank.rank,
                    body=body.." Pet level "..rank.petLevel.." | "..rank.trainingPoints.." training points.",
                    meta=rank.effect,icon=icon and ("/images/"..icon..".jpg") or 134400,
                    action={kind="rank",id=ability.id,index=index},level=level}
            end
        end
    end
    return levels
end

function S.Build(context,state)
    local data=A.Data.ClassSpells[context.characterClass] or {}
    local pets=S.PetEntries(context)
    local race
    -- Keep racial spells tied to the real character's race in planning mode too.
    if UnitRace then local _,_,id=UnitRace("player"); race=id end
    local cards,total,nextLevel={},0,nil
    local query=(state.query or ""):lower()
    for level=context.level+1,60 do
        local blocks={}
        for _,entry in ipairs(data[level] or {}) do
            if not entry.pet and allowed(entry,context,race) then
                if not nextLevel then nextLevel=level end
                if state.showAllFutureSpells or level==nextLevel then
                    local name,rank,icon=spellInfo(entry.id)
                    local body="Listed cost: "..costText(entry.cost)
                    if entry.requiredTalentId then
                        local talent=spellInfo(entry.requiredTalentId)
                        body=body.." | Requires talent: "..talent
                    end
                    local title=name..(rank and rank~="" and (" | "..rank) or "")
                    if (title.." "..body):lower():find(query,1,true) then
                        blocks[#blocks+1]={title=title,body=body,icon=icon,spellId=entry.id,level=level}
                        total=total+1
                    end
                end
            end
        end
        if #blocks>0 then
            table.sort(blocks,function(a,b) if a.title==b.title then return a.spellId<b.spellId end; return a.title<b.title end)
            cards[#cards+1]={title="Level "..level,blocks=blocks}
        end
        local petBlocks={}
        for _,entry in ipairs(pets[level] or {}) do
            if not nextLevel then nextLevel=level end
            if state.showAllFutureSpells or level==nextLevel then
                local row=entry
                if context.characterClass=="Warlock" then
                    local name,rank,icon=spellInfo(entry.id)
                    row={title=name..(rank and rank~="" and (" | "..rank) or ""),
                        body=entry.family.." | Grimoire from a demon trainer | Listed cost: "..costText(entry.cost),
                        meta="Summon the matching demon to teach it with this grimoire.",
                        icon=icon,spellId=entry.id,itemId=entry.itemId,level=level}
                end
                if (row.title.." "..row.body):lower():find(query,1,true) then petBlocks[#petBlocks+1]=row; total=total+1 end
            end
        end
        if #petBlocks>0 then
            table.sort(petBlocks,function(a,b) return a.title<b.title end)
            cards[#cards+1]={title="Level "..level.." | "..(context.characterClass=="Hunter" and "Pet abilities" or "Demon grimoires"),blocks=petBlocks}
        end
        if nextLevel and not state.showAllFutureSpells then break end
    end
    if #cards==0 then cards[1]={title=nextLevel and "No matching spells" or "No future training",
        blocks={{title=nextLevel and "Try clearing your search or showing all future spells." or "No later trainer spells in the Classic Era level 1-60 list."}}} end
    local title=state.showAllFutureSpells and "All future spells" or (nextLevel and "Next training: Level "..nextLevel or "Spells")
    if not state.showAllFutureSpells and cards[1].title=="Level "..tostring(nextLevel) then
        -- The page heading already identifies this level; keep its spells directly below it.
        cards[1].title=title
    else
        table.insert(cards,1,{title=title,blocks={}})
    end
    return {view="training",context=context,cards=cards,continuous=true,page=1,pages=1,total=total,searchable=true,levelFilter=true}
end

local events=CreateFrame("Frame")
events:RegisterEvent("SPELL_DATA_LOAD_RESULT")
events:SetScript("OnEvent",function(_,_,id,success)
    if not S.pending[id] then return end
    -- Retain failed requests to avoid a repeated request/refresh loop.
    if success then S.pending[id]=nil end
    if A.window and A.window:IsShown() and A.state.view=="training" and A.state.filter=="Spells" then A.needsRefresh=true end
end)
