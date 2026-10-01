-- Read the active pet's spellbook; never infer learned ranks from level.
local _, A = ...
local H = {}; A.HunterTraining = H
local spellIDs = {
    bite=17253,claw=16827,charge=7371,cower=1742,dash=23099,dive=23145,
    furioushowl=24604,growl=2649,lightningbreath=24844,prowl=24450,
    scorpidpoison=24640,screech=24423,shellshield=26064,thunderstomp=26090,
    greatstamina=4187,naturalarmor=24545,arcaneresistance=24493,
    fireresistance=24440,frostresistance=24447,natureresistance=24492,shadowresistance=24488,
}

function H.Read()
    local result={spells={},available=false}
    if not UnitExists("pet") then result.reason="Summon your pet to check its current spell ranks."; return result end
    if not HasPetSpells or not GetSpellBookItemName then
        result.reason="Pet spell information is unavailable."; return result
    end
    local count=HasPetSpells()
    if type(count)~="number" or count<1 then
        result.reason="Waiting for your pet's spellbook."; return result
    end
    local names={}
    for _,ability in ipairs(A.Data.PetGuide.abilities) do
        names[ability.name]=ability
        local id=spellIDs[ability.id]
        local name
        if GetSpellInfo then name=GetSpellInfo(id)
        elseif C_Spell and C_Spell.GetSpellInfo then
            local info=C_Spell.GetSpellInfo(id); name=info and info.name
        end
        if name then names[name]=ability end
    end
    for slot=1,math.min(count,128) do
        local name,sub=GetSpellBookItemName(slot,BOOKTYPE_PET or "pet")
        local ability=names[name]
        if ability then
            local rank=tonumber(tostring(sub or ""):match("%d+"))
            if not rank and #ability.ranks==1 then rank=1 end
            local old=result.spells[ability.id]
            if not old or (rank or 0)>(old.rank or 0) then
                result.spells[ability.id]={ability=ability,rank=rank}
            end
        end
    end
    result.available=true
    return result
end

local function sourceFor(rank,context,availableOnly)
    local best,score
    for _,source in ipairs(rank.sources or {}) do
        if not availableOnly or source.minLevel<=context.level then
            local group=source.zone:find("Dungeon",1,true) or source.zone:find("Raid",1,true)
            local value=(source.classification=="Normal" and 0 or 10000)+(group and 20000 or 0)
                +(A.Planner.SourceMatchesFaction(source,context.faction) and 0 or 1000)+source.minLevel
            if not score or value<score then best,score=source,value end
        end
    end
    return best
end

function H.Available(ability,context)
    local best,bestIndex,bestSource
    for index,rank in ipairs(ability.ranks) do
        local source=not rank.trainer and sourceFor(rank,context,true) or nil
        if context.petLevel and context.level>=10 and rank.petLevel<=context.petLevel
            and (rank.trainer or source) and (not best or rank.rank>best.rank) then
            best,bestIndex,bestSource=rank,index,source
        end
    end
    return best,bestIndex,bestSource
end

function H.Card(context)
    local card={title="Pet spell upgrades",blocks={}}
    if context.mode=="preview" then
        card.note="Return to your character to check your active pet's learned ranks."
        card.blocks[1]={title="Browse pet abilities",body="Plan ranks and taming sources for this level.",action={view="petguide",filter="Abilities"}}
        return card
    end
    local snapshot=H.Read()
    if not snapshot.available then card.note=snapshot.reason; return card end
    card.note="Available ranks for your Hunter and pet levels. Green: your active pet has it. Red: training needed.\n"
        .."For a temporary tame, stable your main pet first. Tame the source beast and let it use the skill until you learn it, then retrieve your pet and teach it through Beast Training. Family, training points and active-skill limits still apply."
    for _,ability in ipairs(A.Data.PetGuide.abilities) do
        local learned=snapshot.spells[ability.id]
        if learned then
            local rank,index,source=H.Available(ability,context)
            local title=ability.name.." | "..(rank and "Rank "..rank.rank or "Available rank unknown")
            local titleColor
            local body="Rank information is unavailable; no upgrade is assumed."
            local action={kind="ability",id=ability.id}
            if rank then
                action={kind="rank",id=ability.id,index=index}
                if not learned.rank then
                    title=title.." | learned rank unknown"
                elseif learned.rank>=rank.rank then
                    titleColor={0.42,0.84,0.59}
                    body="Your pet already has this rank or higher."
                else
                    titleColor={0.94,0.47,0.39}
                    body=rank.trainer and "Learn at a pet trainer, then teach through Beast Training."
                        or source and ("Tame "..source.name.." (Lv "..source.minLevel
                            ..(source.maxLevel~=source.minLevel and "-"..source.maxLevel or "")..") in "..source.zone..".")
                        or "No verified taming source is listed."
                    if source and source.classification~="Normal" then body=body.." "..source.classification.." encounter." end
                    body=body.." Check Beast Training first if you already learned this rank."
                end
            end
            local icon=A.Data.PetSkillIcons and A.Data.PetSkillIcons[ability.name]
            card.blocks[#card.blocks+1]={title=title,titleColor=titleColor,body=body,action=action,
                icon=icon and ("/images/"..icon..".jpg") or nil}
        end
    end
    if #card.blocks==0 then card.note="No supported pet spell ranks are available yet. Reopen after your pet's spellbook loads." end
    return card
end
