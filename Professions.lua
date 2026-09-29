-- Classic Era crafting selection uses actual skill AND learned recipe spells.
-- Craft thresholds: wowhead.com/classic/skill=129/first-aid and skill=202/engineering.
-- Skill ranks: Blizzard_UIPanels_Game/Classic/SkillFrame.lua (rank 4, temp 5, modifier 6).
-- Recipe knowledge: C_SpellBook.IsSpellKnown, not legacy IsSpellKnown (spellbook only).
local _, addon = ...
local P = {}
addon.Professions = P
P.autoFamilies = {bandage=true, dummy=true, antivenom=true}
P.recipes = {
    bandage = {
        {itemId=1251, spellId=3275, craftSkill=1, useSkill=1},
        {itemId=2581, spellId=3276, craftSkill=40, useSkill=20},
        {itemId=3530, spellId=3277, craftSkill=80, useSkill=50},
        {itemId=3531, spellId=3278, craftSkill=115, useSkill=75},
        {itemId=6450, spellId=7928, craftSkill=150, useSkill=100},
        {itemId=6451, spellId=7929, craftSkill=180, useSkill=125},
        {itemId=8544, spellId=10840, craftSkill=210, useSkill=150},
        {itemId=8545, spellId=10841, craftSkill=240, useSkill=175},
        {itemId=14529, spellId=18629, craftSkill=260, useSkill=200},
        {itemId=14530, spellId=18630, craftSkill=290, useSkill=225},
    },
    dummy = {
        {itemId=4366, spellId=3932, craftSkill=85, useSkill=85},
        {itemId=4392, spellId=3965, craftSkill=185, useSkill=185},
        {itemId=16023, spellId=19814, craftSkill=275, useSkill=275},
    },
    antivenom = {
        {itemId=6452, spellId=7934, craftSkill=80, useSkill=0},
        {itemId=6453, spellId=7935, craftSkill=130, useSkill=0},
        {itemId=19440, spellId=23787, craftSkill=300, useSkill=300},
    },
}
local familyOrder = {"bandage", "dummy", "cooking"}
local skillIDs, spellIDs = {bandage=129,dummy=202,antivenom=129,cooking=185}, {bandage=3273,dummy=4036,cooking=2550}
local names = {bandage="First Aid",dummy="Engineering",antivenom="First Aid",cooking="Cooking"}
local missingRecipe = {bandage="No bandage recipe learned",dummy="No target dummy recipe learned",antivenom="No anti-venom recipe learned"}
local byItem = {}
for family, recipes in pairs(P.recipes) do
    for _, recipe in ipairs(recipes) do
        recipe.family, recipe.skillLine = family, skillIDs[family]
        byItem[recipe.itemId] = recipe
    end
end
function P.ByItem(itemId) return byItem[itemId] end

local function integer(value, minimum, maximum)
    return type(value)=="number" and value==value and value>=minimum and value<=maximum
        and value==math.floor(value)
end
local function localizedName(family)
    if C_TradeSkillUI and type(C_TradeSkillUI.GetTradeSkillDisplayName)=="function" then
        local ok, name=pcall(C_TradeSkillUI.GetTradeSkillDisplayName,skillIDs[family])
        if ok and type(name)=="string" and name~="" then return name end
    end
    if C_Spell and type(C_Spell.GetSpellName)=="function" then
        local ok, name=pcall(C_Spell.GetSpellName,spellIDs[family])
        if ok and type(name)=="string" and name~="" then return name end
    end
    if type(GetSpellInfo)=="function" then
        local ok, name=pcall(GetSpellInfo,spellIDs[family])
        if ok and type(name)=="string" and name~="" then return name end
    end
    if type(GetLocale)=="function" then
        local ok, locale=pcall(GetLocale)
        if ok and (locale=="enUS" or locale=="enGB") then return names[family] end
    end
end

local function readSkills(result)
    if type(GetNumSkillLines)~="function" or type(GetSkillLineInfo)~="function" then return end
    local localized={}
    for _,family in ipairs(familyOrder) do localized[family]=localizedName(family) end
    local expanded, complete = {}, true
    local scanOK = pcall(function()
        local index=1
        while index<=1000 do
            local size=GetNumSkillLines()
            if not integer(size,1,1000) then complete=false; break end
            if index>size then break end
            local name, header, isExpanded, rank, temporary, modifier, maximum=GetSkillLineInfo(index)
            if type(name)~="string" then complete=false; break end
            if header and not isExpanded then
                if type(ExpandSkillHeader)~="function" or type(CollapseSkillHeader)~="function" then
                    complete=false
                else
                    expanded[#expanded+1]={index=index,name=name}
                    ExpandSkillHeader(index)
                    local sameName, sameHeader, nowExpanded=GetSkillLineInfo(index)
                    if sameName~=name or not sameHeader or not nowExpanded then complete=false; break end
                end
            elseif not header then
                for _, family in ipairs(familyOrder) do
                    if name==localized[family] then
                        if integer(rank,0,1000) and (temporary==nil or integer(temporary,-1000,1000))
                            and (modifier==nil or integer(modifier,-1000,1000)) then
                            result.skills[family]=math.max(0,rank+(temporary or 0)+(modifier or 0))
                            result.baseSkills[family]=rank
                            result.trainingSkills[family]=math.max(0,rank+(modifier or 0))
                            if integer(maximum,1,1000) then result.maxSkills[family]=maximum end
                        else complete=false end
                    end
                end
            end
            index=index+1
        end
    end)
    -- Reverse order restores indexes as each earlier expansion is undone.
    -- The caller's SKILL_LINES_CHANGED handler must ignore events while reading.
    for index=#expanded,1,-1 do
        local entry=expanded[index]
        local ok,name,header=pcall(GetSkillLineInfo,entry.index)
        if ok and name==entry.name and header then pcall(CollapseSkillHeader,entry.index) end
    end
    if scanOK and complete then
        for _, family in ipairs(familyOrder) do
            if localized[family] and result.skills[family]==nil then
                result.skills[family],result.baseSkills[family],result.maxSkills[family]=0,0,0
                result.trainingSkills[family]=0
            end
        end
    end
end

function P.Read()
    if P.reading then return P.lastSnapshot or {available=false,skills={},known={}} end
    P.reading=true
    local result={available=false,skills={},baseSkills={},trainingSkills={},maxSkills={},known={}}
    readSkills(result)
    local query=C_SpellBook and C_SpellBook.IsSpellKnown
    if type(query)~="function" then query=IsPlayerSpell end
    local recipeReady=type(query)=="function"
    if recipeReady then
        for _, recipes in pairs(P.recipes) do
            for _, recipe in ipairs(recipes) do
                local ok, known=pcall(query,recipe.spellId)
                if ok and type(known)=="boolean" then result.known[recipe.spellId]=known
                else recipeReady=false end
            end
        end
    end
    result.available=result.skills.bandage~=nil and result.skills.dummy~=nil and recipeReady
    P.lastSnapshot=result
    P.reading=false
    return result
end

function P.Best(snapshot,family)
    local familyName=names[family] or "Profession"
    -- Anti-venom and bandages share the same detected First Aid skill.
    local skill=snapshot and snapshot.skills and snapshot.skills[family=="antivenom" and "bandage" or family]
    local known=snapshot and snapshot.known or {}
    if not P.recipes[family] or not integer(skill,0,2000) then
        return {status="unknown",note=familyName.." skill unavailable"}
    end
    if skill==0 then return {status="unlearned",skill=0,note=familyName.." not learned"} end
    local best, unresolved
    for _, recipe in ipairs(P.recipes[family]) do
        if recipe.craftSkill<=skill then
            if known[recipe.spellId]==true then best=recipe
            elseif known[recipe.spellId]~=false then unresolved=recipe end
        end
    end
    if unresolved and (not best or unresolved.craftSkill>best.craftSkill) then
        return {status="unknown",skill=skill,note=familyName.." "..skill.." | Recipes unavailable"}
    end
    if best then
        return {status="selected",skill=skill,itemId=best.itemId,spellId=best.spellId,
            note=familyName.." "..skill.." | Best learned recipe"}
    end
    local minimum=P.recipes[family][1].craftSkill
    return {status="untrained",skill=skill,note=skill<minimum and ("Requires "..familyName.." "..minimum)
        or missingRecipe[family]}
end

-- Prefer the strongest missing tier craftable at the current skill. Otherwise
-- show the nearest higher threshold. Selection still uses P.Best; this is guidance only.
function P.NextUpgrade(snapshot,family)
    local recipes=P.recipes[family]
    local skill=snapshot and snapshot.skills and snapshot.skills[family=="antivenom" and "bandage" or family]
    if not recipes or not integer(skill,0,2000) then return {status="unknown"} end
    if skill==0 then return {status="unlearned"} end
    local best=P.Best(snapshot,family)
    if best.status=="unknown" then return {status="unknown"} end
    local index=0
    for i,recipe in ipairs(recipes) do if recipe.itemId==best.itemId then index=i end end
    local recipe
    for i=#recipes,index+1,-1 do
        if recipes[i].craftSkill<=skill then recipe=recipes[i]; break end
    end
    recipe=recipe or recipes[index+1]
    if not recipe then return {status="complete"} end
    local learned=(snapshot.known or {})[recipe.spellId]
    if type(learned)~="boolean" then return {status="unknown",recipe=recipe} end
    return {status=skill>=recipe.craftSkill and "learn" or "skill",recipe=recipe,learned=learned,skill=skill}
end

function P.NextRecipe(context,family)
    local upgrade=P.NextUpgrade(context and context.professions,family)
    if not upgrade.recipe or upgrade.learned~=false then return end
    local D=addon.Data and addon.Data.ProfessionProgression
    local recipe=upgrade.recipe
    local entry=D and D.recipes[recipe.spellId]
    if not entry then return end
    return {name=entry.name,spellId=recipe.spellId,itemId=recipe.itemId,craftSkill=recipe.craftSkill,
        recipeItemId=entry.recipeItemId,ahEligible=entry.ahEligible==true,skillMet=upgrade.skill>=recipe.craftSkill}
end

local function factionRoute(routes,faction)
    if faction=="Alliance" or faction=="Horde" then return routes and routes[faction] end
end
local function location(route)
    return route.name.." in "..route.place
end
local function acquisition(entry,family,faction,maximum)
    local D=addon.Data.ProfessionProgression
    if entry.kind=="book" then
        local detail=entry.acquisition
        if entry.vendors then
            local route=factionRoute(D[entry.vendors],faction)
            detail=route and ("Buy from "..location(route)..".")
                or "Faction unavailable; the faction-specific vendor route is hidden."
        end
        local ah=entry.ahEligible and "Tradable recipe; AH listings not checked. Self Found cannot use AH."
            or "AH recipe: unavailable; this recipe binds when picked up."
        return "Learn "..entry.recipeName..". "..(detail or ""),ah
    elseif entry.kind=="doctor" then
        local route=factionRoute(D.doctors,faction)
        local text=route and ("Learn from "..location(route)..".")
            or "Faction unavailable; the faction-specific doctor route is hidden."
        if not maximum or maximum<300 then text=text.." Artisan First Aid requires Triage (level 35 and First Aid 225)." end
        return text,"Trainer recipe; no recipe item to buy at the AH."
    end
    return entry.acquisition or ("Learn from a "..(names[family] or "profession").." trainer."),
        "Trainer recipe; no recipe item to buy at the AH."
end

local function trainingBlock(stage,family,context,trainingRank,maximum)
    local D=addon.Data.ProfessionProgression
    local body,meta
    if stage.kind=="triage" then
        local route=factionRoute(D.doctors,context.faction)
        if route then
            body="Complete Triage with "..location(route)..". Use the supplied Triage Bandages to save 15 patients before 6 die. "
                .."Optional introduction: "..route.introduction.." from "..route.guide.."; you can go directly to the doctor."
        else
            body="Complete your faction's Triage quest using the supplied Triage Bandages: save 15 patients before 6 die. Faction unavailable; the doctor route is hidden."
        end
        meta="Quest training; cannot be bought at the AH."
    elseif stage.kind=="clamlette" then
        body="Complete Clamlette Surprise with Dirge Quikcleave at the Gadgetzan inn in Tanaris. Bring 12 Giant Eggs, 10 Zesty Clam Meat and 20 Alterac Swiss."
        local introduction=factionRoute(D.cookingIntroductions,context.faction)
        if introduction then
            body=body.." Optional introduction: "..introduction.name.." from "..introduction.guide.."; you can go directly to Dirge."
        elseif context.faction~="Alliance" and context.faction~="Horde" then
            body=body.." Faction unavailable; the optional introduction is hidden."
        end
        meta="The quest raises the Cooking cap; it does not teach a Clamlette Surprise recipe. Ingredients are tradable; AH listings not checked. Self Found cannot use AH."
    else body,meta=acquisition(stage,family,context.faction,maximum) end
    local requirements="Requires "..names[family].." "..stage.skill
    if stage.level then requirements=requirements.." and character level "..stage.level end
    local level=context.characterLevel
    if stage.level and not integer(level,1,60) then requirements=requirements.." (character level unavailable)"
    elseif stage.level and level<stage.level then requirements=requirements.." (your character is level "..level..")" end
    return {title=stage.name.." - skill cap "..stage.cap,body=requirements..". "..body,meta=meta,
        kind="professionTraining",skillCap=stage.cap,itemId=stage.recipeItemId,recipeItemId=stage.recipeItemId,questId=stage.questId,
        requirementsMet=trainingRank>=stage.skill and (not stage.level or integer(level,stage.level,60))}
end

-- Plain presentation blocks for profession details. These always describe the
-- actual character's skill/faction/level, even while planning another level.
function P.Guidance(context,family)
    context=context or {}
    local D=addon.Data and addon.Data.ProfessionProgression
    if not D or not names[family] then return {} end
    local key=family=="antivenom" and "bandage" or family
    local snapshot=context.professions or {}
    local skill=(snapshot.skills or {})[key]
    local base=(snapshot.baseSkills or {})[key]
    local permanent=(snapshot.trainingSkills or {})[key]
    local maximum=(snapshot.maxSkills or {})[key]
    local blocks={}
    if not integer(skill,0,2000) then
        blocks[1]={title=names[family].." skill unavailable",body="Current progression cannot be checked until your character's profession information is available."}
        if key=="cooking" then
            blocks[2]={title="Cooking training reference",body="Expert Cookbook requires Cooking 125 and raises the cap to 225. It is tradable. At Cooking 225 and character level 35, complete Clamlette Surprise with Dirge Quikcleave in Gadgetzan to raise the cap to 300.",meta="Reference only; your current training and AH listings are not checked. Self Found cannot use AH."}
        end
        return blocks
    end
    if skill==0 then
        return {{title="Learn "..names[family],body="Visit a "..names[family].." trainer to start this profession. No learned progression is available yet."}}
    end
    local upgrade=P.recipes[family] and P.NextUpgrade(snapshot,family)
    if upgrade and upgrade.status=="unknown" then
        blocks[#blocks+1]={title="Recipe knowledge unavailable",body="A next recipe cannot be confirmed while learned-recipe information is incomplete."}
    elseif upgrade and upgrade.recipe then
        local recipe=upgrade.recipe
        local entry=D.recipes[recipe.spellId]
        if entry then
            local body,meta=acquisition(entry,family,context.faction,maximum)
            if upgrade.learned then body="This recipe is already learned. Raise "..names[family].." to "..recipe.craftSkill.." to craft it."; meta="No additional recipe purchase needed." end
            blocks[#blocks+1]={title=entry.name.." - next recipe",body=body,
                meta="Crafting requires "..names[family].." "..recipe.craftSkill..". "..meta,
                kind="professionRecipe",spellId=recipe.spellId,itemId=entry.recipeItemId,recipeItemId=entry.recipeItemId,
                ahEligible=entry.ahEligible==true,craftSkill=recipe.craftSkill,
                skillMet=skill>=recipe.craftSkill,learned=upgrade.learned}
        end
    end
    if integer(base,1,1000) and integer(maximum,1,1000) then
        for _,stage in ipairs(D.training[key] or {}) do
            if stage.cap>maximum then
                local trainingRank=stage.kind=="trainer" and (integer(permanent,1,2000) and permanent or base) or skill
                if trainingRank>=stage.skill or (upgrade and upgrade.recipe and upgrade.recipe.craftSkill>maximum) then
                    blocks[#blocks+1]=trainingBlock(stage,key,context,trainingRank,maximum)
                end
                break
            end
        end
    elseif key=="cooking" or (upgrade and upgrade.recipe and upgrade.recipe.craftSkill>225) then
        blocks[#blocks+1]={title=names[key].." skill cap unavailable",body="The current skill cap could not be read; a required training step cannot be confirmed."}
    end
    return blocks
end
