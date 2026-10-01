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
    local parts={}
    if copper>=10000 then parts[#parts+1]=math.floor(copper/10000).."g" end
    if copper>=100 then parts[#parts+1]=math.floor(copper/100)%100 .."s" end
    if copper%100>0 then parts[#parts+1]=copper%100 .."c" end
    return table.concat(parts," ")
end

function S.Build(context,state)
    local data=A.Data.ClassSpells[context.characterClass] or {}
    local race
    -- Keep racial spells tied to the real character's race in planning mode too.
    if UnitRace then local _,_,id=UnitRace("player"); race=id end
    local cards,total,nextLevel={},0,nil
    local query=(state.query or ""):lower()
    for level=context.level+1,60 do
        local blocks={}
        for _,entry in ipairs(data[level] or {}) do
            if allowed(entry,context,race) then
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
        if nextLevel and not state.showAllFutureSpells then break end
    end
    local note=(context.mode=="preview" and "Planned level " or "Your level ")..context.level.." | "..context.characterClass
        .."\nTrainer prices may vary. Talent ranks require the named talent. Earlier ranks and class quests may be required."
    if context.mode=="preview" then note=note.." Uses your current faction and race." end
    if #cards==0 then cards[1]={title=nextLevel and "No matching spells" or "No future training",
        blocks={{title=nextLevel and "Try clearing your search or showing all future spells." or "No later trainer spells in the Classic Era level 1-60 list."}}} end
    table.insert(cards,1,{title=state.showAllFutureSpells and "All future spells" or (nextLevel and "Next training: level "..nextLevel or "Spells"),note=note,blocks={}})
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
