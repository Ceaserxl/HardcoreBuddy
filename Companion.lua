-- Focused companion views with live inventory and crafting recommendations.
local _, A = ...
local P, G, D, S = A.Planner, A.Guide, A.Data, A.Supplies
local C = {}; A.Companion = C
C.eluneMacroBody="#showtooltip Light of Elune\n/use Light of Elune\n/use Hearthstone"
-- Macro serialization may normalize line endings and add a final newline.
-- Ignore only those differences; preserve command text, order and spacing.
local function sameEluneBody(body)
    if type(body)~="string" then return false end
    return body:gsub("\r\n","\n"):gsub("\r","\n"):gsub("\n+$","")==C.eluneMacroBody
end
function C.EluneMacroState()
    if not GetMacroInfo or not GetNumMacros then return nil,false end
    local general,character=GetNumMacros()
    local found,correct
    local function check(index)
        local name,_,body=GetMacroInfo(index)
        if name=="Light of Elune" then
            found=index; correct=sameEluneBody(body)
        elseif not found and sameEluneBody(body) then found=index; correct=true end
    end
    for i=1,general do check(i) end
    for i=1,character do check((MAX_ACCOUNT_MACROS or 120)+i) end
    return found,correct
end
function C.EluneMacroAction(drag)
    local function notice(text)
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcd52HardcoreBuddy:|r "..text) end
    end
    if InCombatLockdown and InCombatLockdown() then notice("Leave combat to create, fix or drag the Elune macro."); return end
    local index,correct=C.EluneMacroState()
    if drag then
        if index and correct then PickupMacro(index) else notice("Create or fix the Elune macro first.") end
        return
    end
    if correct then return end
    local ok,result
    if index then
        ok,result=pcall(EditMacro,index,nil,"INV_Potion_13",C.eluneMacroBody)
    else
        local general,character=GetNumMacros()
        local perCharacter=character<(MAX_CHARACTER_MACROS or 18)
        if not perCharacter and general>=(MAX_ACCOUNT_MACROS or 120) then notice("Your macro slots are full. Delete a macro, then try again."); return end
        ok,result=pcall(CreateMacro,"Light of Elune","INV_Potion_13",C.eluneMacroBody,perCharacter)
    end
    if not ok or not result then notice("Could not save the Elune macro. Check your available macro slots.") end
    A:Refresh()
end
local families, abilities = {}, {}
for _, f in ipairs(D.PetGuide.families) do families[f.id]=f end
for _, a in ipairs(D.PetGuide.abilities) do abilities[a.id]=a end
local function card(title,note,blocks) return {title=title,note=note,blocks=blocks or {}} end
local function row(title,body,action,meta)
    return {title=title,body=body,action=action,meta=meta}
end
function C.Tabs(context)
    local tabs=context.characterClass=="Hunter" and {"Overview","Zone Advisor","Gear","Talents","Spells","Pet Training","Pet Guide","First Aid","Engineering","Cooking"}
        or {"Overview","Zone Advisor","Gear","Talents","Spells","First Aid","Engineering","Cooking"}
    table.insert(tabs,5,"Rotation Helper")
    return tabs
end
local tabDescriptions={["Zone Advisor"]="Recommended leveling zones, dangerous NPCs and maps.",Spells="Untrained spells, current trainer spells and future class and pet training.",
    ["Rotation Helper"]="Shared buff and consumable highlights. Mage combat advice.",
    Gear="Equipment scoring and upgrade advice.",Talents="Your next talent and point-by-point build path.",
    ["Pet Training"]="Learn and teach pet abilities.",["Pet Guide"]="Pet families, abilities, taming sources and care.",
    ["First Aid"]="Bandages, anti-venom and profession training.",Engineering="Target dummy recipes and profession training.",
    Cooking="Food recommendations and profession training."}
function C.TabAction(tab)
    local family=({Engineering="dummy"})[tab]
    if family then return {kind="profession",family=family,companionTab=true} end
    if tab=="Pet Guide" then return {view="petguide",filter="Families",companionTab=true} end
    return {view="training",filter=tab~="Overview" and tab or nil,companionTab=true}
end
local function match(text,query)
    for word in (query or ""):lower():gmatch("%S+") do
        local haystack=(text or ""):lower()
        local start=haystack:find(word,1,true)
        while start and start>1 and haystack:sub(start-1,start-1):match("[%w]") do
            start=haystack:find(word,start+1,true)
        end
        if not start then return false end
    end
    return true
end
local function familyNames(ids)
    local names={}; for _,id in ipairs(ids) do names[#names+1]=families[id].name end
    return #names>0 and table.concat(names,", ") or "All families"
end
local function itemRow(item)
    local b=row(item.displayName or item.name,item.short,{kind="item",item=item})
    b.itemId,b.icon=item.itemId,item.icon
    return b
end
local function professionBlocks(context,family)
    return A.Professions.Guidance and A.Professions.Guidance(context,family) or {}
end
local function supplyRow(record,context)
    local b=itemRow(record.item)
    b.title=record.name
    b.body=G.SupplySubtitle(record.item,context)
    b.supply=true
    b.materialCount=record.item.enchantMaterial==true
    b.category=record.category
    b.priority=record.priority
    b.count,b.target,b.targetKey=record.count,record.target,record.targetKey
    b.status,b.missing=record.tracking and record.status or "off",record.missing
    return b
end
local groupNames={bandage="Bandages",dummy="Target dummies",antivenom="Anti-venom"}
local function rankState(block,record,context)
    local selected,automatic=S.Selection(context,record.groupFamily)
    block.rankFamily=record.groupFamily
    if automatic then
        block.autoRank=not automatic.manual
        block.readOnlyTarget=selected~=record.itemId
        if record.groupFamily=="bandage" then
            local plan=A.Professions.BandagePlan(context)
            if plan.canMake and plan.recommended.itemId==record.itemId then block.readOnlyTarget=false end
        end
        block.pickRank=false
        if not block.readOnlyTarget then
            block.body=automatic.note
        else
            local recipe=A.Professions.ByItem(record.itemId)
            local profession=record.groupFamily=="dummy" and "Engineering" or "First Aid"
            block.body="Crafting: "..profession.." "..recipe.craftSkill
                .." | "..((context.professions and context.professions.known or {})[recipe.spellId]==true and "Recipe learned" or "Recipe not learned")
            if not context.professions or (context.professions.known or {})[recipe.spellId]==nil then
                block.body="Crafting: "..profession.." "..recipe.craftSkill.." | Recipe unknown"
            end
            block.status="off"
        end
    else block.pickRank=selected~=record.itemId end
    return selected==record.itemId
end
local function supplyRows(context,state,onlyFamily)
    local entries=S.Build(context,{filter=onlyFamily and "All" or state.filter or "All",query=state.query})
    local blocks,groups={},{}
    local summary={ready=0,tracked=0,missing=0,unset=0}
    local function track(r)
        if r.tracking then
            summary.tracked=summary.tracked+1
            if r.status=="ready" then summary.ready=summary.ready+1 end
            if r.missing and r.missing>0 then summary.missing=summary.missing+1 end
        end
    end
    local function include(r) return state.stock~="Missing" or (r.missing and r.missing>0) end
    for _,r in ipairs(entries) do
        if not onlyFamily or r.groupFamily==onlyFamily then
            if r.groupFamily and not onlyFamily then
                local group=groups[r.groupFamily]
                if not group then
                    local selected,automatic=S.Selection(context,r.groupFamily)
                    local b=row(groupNames[r.groupFamily],automatic and automatic.note or "Select one rank to track",{kind="supplyFamily",family=r.groupFamily})
                    b.supply,b.groupSupply,b.status=true,true,"choose"
                    b.priority=S.Priority(context,r.item)
                    b.target=r.target
                    b.icon=r.item.icon
                    if r.groupFamily=="dummy" then b.itemId=r.itemId end
                    b.category="Emergency"
                    if automatic then
                        b.autoRank=true
                        b.status=automatic.status=="unknown" and "unknown" or "off"
                    end
                    b.count=context.inventory and context.inventory.available and 0 or nil
                    blocks[#blocks+1]=b
                    group={block=b,index=#blocks,selectedId=selected,automatic=automatic}; groups[r.groupFamily]=group
                end
                if group.block.count and r.count then group.block.count=group.block.count+r.count end
                if group.selectedId==r.itemId then group.selected=r end
            else
                local b=supplyRow(r,context)
                if onlyFamily then
                    if rankState(b,r,context) then track(r) end
                    b.body=G.SupplySubtitle(r.item,context)
                else track(r) end
                if include(r) then blocks[#blocks+1]=b end
            end
        end
    end
    for family,group in pairs(groups) do
        local r=group.selected
        if r then
            local b=supplyRow(r,context); b.action={kind="supplyFamily",family=family}
            b.autoRank=group.automatic~=nil and not group.automatic.manual
            b.omit=not include(r); blocks[group.index]=b; track(r)
        else
            if not group.automatic then summary.unset=summary.unset+1 end
            group.block.omit=state.stock=="Missing" or (group.automatic and group.selectedId~=nil)
        end
    end
    local visible={}
    for _,b in ipairs(blocks) do if not b.omit then visible[#visible+1]=b end end
    return visible,summary
end
local function bandageCards(context,state)
    local plan=A.Professions.BandagePlan(context)
    local items={}
    for _,item in ipairs(D.Items.items) do if item.family=="bandage" then items[item.itemId]=item end end
    local function bandage(id)
        local item=items[id]; if not item then return end
        local record=S.Record(context,item,"bandage")
        local block=supplyRow(record,context); rankState(block,record,context)
        block.editTarget=true; block.body=G.SupplySubtitle(item,context); block.supplyDetail=true
        return block
    end
    local cards={card("Recommended",nil,{})}
    local recommended=plan.recommended
    if recommended and plan.canMake then
        cards[1].blocks={bandage(recommended.itemId)}
        cards[1].supplyTable=true; cards[1].fullWidth=true
    elseif recommended then
        local block=bandage(recommended.itemId)
        block.body=block.body.."\n"..(plan.highest.status=="unknown" and "First Aid or recipe data is unavailable."
            or "You cannot make it yet.").." Requires First Aid "..recommended.craftSkill.." and the learned recipe."
        cards[1].blocks={block}
        cards[1].supplyTable=true; cards[1].fullWidth=true
    end
    local highest=plan.highest
    if highest.itemId and (not plan.canMake or highest.itemId~=recommended.itemId) then
        local section=card("Highest Rank Available",nil,{bandage(highest.itemId)})
        section.supplyTable=true; section.fullWidth=true; cards[#cards+1]=section
    elseif not highest.itemId and not plan.canMake then
        cards[#cards+1]=card("Highest Rank Available",nil,{row("No confirmed craftable rank","Learn First Aid and the recipe to unlock a recommendation.")})
    end
    -- Reuse the ordinary supply details layout and toolbar. Keep the other
    -- health/recipe ranks in the right column, without duplicating the selected item.
    local selected=S.Selection(context,"bandage")
        or (recommended and recommended.itemId) or highest.itemId
    if not selected or not items[selected] then
        local alternatives={}
        for _,recipe in ipairs(A.Professions.recipes.bandage) do alternatives[#alternatives+1]=bandage(recipe.itemId) end
        cards[#cards+1]=card("Next",nil,{G.EmptySupplyRow("Next",{family="bandage"})})
        cards[#cards+1]=card("Alternatives",nil,alternatives)
        return cards
    end
    local out=C.Detail(context,{kind="item",item=items[selected]})
    local blocks,nextBlocks={},{}
    local inNext=false
    for _,block in ipairs(out.blocks) do
        if not block.rightColumn then blocks[#blocks+1]=block end
        if block.rightColumn and block.title=="Alternatives" then inNext=false end
        if block.rightColumn and block.title=="Next" then inNext=true end
        if inNext and block.rightColumn then nextBlocks[#nextBlocks+1]=block end
    end
    local nextId=nextBlocks[2] and nextBlocks[2].itemId
    if nextId then nextBlocks[2]=bandage(nextId); nextBlocks[2].rightColumn=true end
    for _,section in ipairs(cards) do
        local remaining={}
        for _,block in ipairs(section.blocks) do
            if block.itemId==nextId and block.itemId~=selected then
                block.rightColumn=true; nextBlocks[2]=block
            elseif block.itemId~=selected then
                remaining[#remaining+1]=block
            elseif block.supply then
                out.itemSectionTitle=recommended and selected~=recommended.itemId and "Selected Alternative" or "Recommended"
                if recommended and selected==recommended.itemId and not plan.canMake then out.blocks[1].body=block.body end
            end
        end
        if #remaining>0 then
            local heading=row(section.title,section.note)
            heading.plain=true; heading.textInset=0; heading.rightColumn=true
            blocks[#blocks+1]=heading
            for _,block in ipairs(remaining) do block.rightColumn=true; blocks[#blocks+1]=block end
        end
    end
    if nextBlocks[1] then nextBlocks[1].body=nil end
    for _,block in ipairs(nextBlocks) do blocks[#blocks+1]=block end
    local used={}
    for _,block in ipairs(blocks) do if block.itemId then used[block.itemId]=true end end
    local heading=row("Alternatives")
    heading.plain=true; heading.textInset=0; heading.rightColumn=true
    blocks[#blocks+1]=heading
    for _,recipe in ipairs(A.Professions.recipes.bandage) do
        if not used[recipe.itemId] then
            local block=bandage(recipe.itemId); block.rightColumn=true
            blocks[#blocks+1]=block
        end
    end
    out.blocks=blocks
    return {out}
end
function C.TabLabel(tab)
    return tab=="Gear" and "Gear Advisor" or tab=="Talents" and "Talent Advisor" or tab
end
local function professionCards(context,family)
    local profession=family=="bandage" and "First Aid" or "Cooking"
    local snapshot=context.professions or {}
    local skill=(snapshot.skills or {})[family]
    local cap=(snapshot.maxSkills or {})[family]
    local status=skill==nil and "Skill unavailable" or skill==0 and "Not learned"
        or ("Skill "..skill.." / "..(cap or "unknown cap"))
    local note=status.." | Your character's profession"
    if context.mode=="preview" then note=note..(family=="cooking" and "; food uses your planned level." or "; health and recipes use your live character.") end
    local training=A.Professions.NextTraining(context,family)
    local nextStep=row(training.title,training.body,nil,training.meta)
    -- Keep the overview compact; books, quests and prerequisites open as details.
    if training.kind=="professionTraining" then
        nextStep=row(training.title,training.requirementsMet and "Training requirements met. View the trainer, book or quest route."
            or "Upcoming skill-cap training. View requirements and where to learn it.",
            {kind="card",card=card(training.title,nil,{training})})
    end
    local cards={card(profession,note,{nextStep})}
    if family=="bandage" then
        local best=A.Professions.Best(snapshot,"bandage")
        local bestName
        for _,recipe in ipairs(A.Professions.recipes.bandage) do
            if recipe.itemId==best.itemId then bestName=D.ProfessionProgression.recipes[recipe.spellId].name end
        end
        cards[#cards+1]=card("Supplies",nil,{
            row("Bandages for your health",(bestName and ("Best learned: "..bestName..". ") or (best.note..". "))..
                "Compare ranks against your maximum health.",{kind="supplyFamily",family="bandage"}),
            row("Anti-venom","Compare poison cures, skill requirements and recipe sources.",{kind="supplyFamily",family="antivenom"})})
        local recipes={}
        for _,block in ipairs(professionBlocks(context,"bandage")) do
            if block.kind=="professionRecipe" or block.title=="Recipe knowledge unavailable" then recipes[#recipes+1]=block end
        end
        if #recipes>0 then cards[#cards+1]=card("Next bandage recipe",nil,recipes) end
    else
        local foods={}
        for _,record in ipairs(S.Build(context,{filter="Food & Drink"})) do
            local item=record.item
            local info=A.Crafting.GetInfo(item,context)
            if info.craftable and info.profession=="Cooking" then
                local block=itemRow(item)
                block.body=(item.short or "").." | Cooking "..info.skill
                foods[#foods+1]=block
            end
        end
        if #foods==0 then foods[1]=row("Browse food & drink","Review recovery food and buffs for your class and level.",{view="supplies",filter="Food & Drink"}) end
        cards[#cards+1]=card("Food to prepare","For your class and level. Open an item for ingredients and recipe sources; recipe knowledge is not checked.",foods)
    end
    return cards
end
local function petRow(pet,index)
    return row(pet.name,pet.level.."  |  "..families[pet.family].name.."  |  "..pet.zone,
        {kind="pet",index=index},not pet.tameable and "Cannot be tamed" or pet.classification~="Normal" and (pet.classification.." - reference only")
            or (pet.zone:find("Dungeon",1,true) or pet.zone:find("Raid",1,true)) and "Group encounter - reference only" or nil)
end
local guides={
    {name="Learn and teach a pet skill",body="Stable your main pet and keep a slot free. Tame a beast that knows the desired rank; let it use that ability until the learned message appears. Retrieve your main pet, then use Beast Training on the General spellbook tab.\n\nThe recipient must meet the family and level requirements and have enough training points. Check the individual creature with Beast Lore when available. Trainer skills are bought from a pet trainer, separate from the Hunter trainer."},
    {name="Training points and ability limits",body="Total training points = pet level x (loyalty level - 1). Spent points reduce the available balance. A level-60 pet at loyalty 6 has 300 total points.\n\nA pet can learn four active abilities, plus affordable passives. You can skip ranks. Upgrading refunds the points spent on the lower rank of that ability. Growl costs no training points. A pet trainer can reset trained skills for a fee."},
    {name="Feeding, loyalty and stable slots",body="Finish both parts of the level-10 Hunter quest chain to learn taming, feeding and training. Feed foods accepted by the pet's family; check the Families tab for diets. Happiness and loyalty need attention, especially just after taming.\n\nClassic allows one active pet and two stable slots. Leave room for temporary training tames. A newly tamed pet keeps its original level and gains levels through combat."},
    {name="Attack speed",body="A tamed pet retains its creature's attack speed in Classic. Faster swings do less damage per hit within the same family; a faster attack speed alone does not increase sustained DPS.\n\nSearch Pets for a creature to see its listed speed in seconds. A missing speed is shown as unknown, never estimated. Rare pets are catalog entries, not routine taming recommendations."},
    {name="Historical caster pets",body="The old Vanilla caster-stat penalty is obsolete in Classic. A mana bar on a wild beast is not a reason to reject it.\n\nHistorical entries are marked in pet details for reference."},
}

function C.Detail(context, action)
    local kind=action.kind
    if kind=="enchantSlot" or kind=="enchantRecipe" then return A.Enchants.Detail(context,action) end
    if kind=="hunterChoices" then
        local guide=G.Hunter(context)
        return card("Common pet choices",nil,{guide.blocks[1]})
    end
    if kind=="quivers" then return G.Quivers(context) end
    if kind=="item" then
        local item=P.ItemForFaction(action.item,P.ContextFaction(context))
        if not item then return card("Unavailable route",nil,{row(nil,"This quest reward is not available for your faction.")}) end
        if item.armorKit and A.ArmorKits then item=A.ArmorKits.DetailItem(context,item) end
        if item.enchantMaterial then item=A.Enchants.DetailMaterial(context,item) end
        local family=P.grouped[item.family] and item.family or nil
        local defaults=S.DefaultGroup(context,item)
        local recommended=defaults
        if item.group=="Scrolls" then
            for _,candidate in ipairs(D.Scrolls.items) do
                if candidate.family==item.family and candidate.level<=context.level
                    and P.MatchesClass(candidate,context.characterClass)
                    and (not recommended or candidate.level>recommended.level) then recommended=candidate end
            end
        end
        if not recommended and item.family and not item.userItem then
            local plan=P.BuildList(context.characterClass,context.level,P.ContextFaction(context))
            for _,section in ipairs({plan.rows,plan.specialist,plan.backups,plan.advanced}) do
                for _,candidate in ipairs(section or {}) do
                    if candidate.family==item.family then recommended=candidate; break end
                end
                if recommended then break end
            end
        end
        if family=="bandage" then
            local plan=A.Professions.BandagePlan(context)
            recommended=plan.recommended and {itemId=plan.recommended.itemId} or recommended
        elseif family then
            local best=A.Professions.Best(context.professions,family)
            for _,candidate in ipairs(D.Items.items) do
                if candidate.itemId==best.itemId then recommended=candidate; break end
            end
        end
        if defaults then
            local copy={}; for k,v in pairs(item) do copy[k]=v end; item=copy
            item.options={defaults}
            for _,other in ipairs(defaults.options) do item.options[#item.options+1]=other end
            item.supplyCategory=S.Category(defaults)
            item.next=item.next or defaults.next
        end
        local blocks={}
        local function heading(title,right,body)
            blocks[#blocks+1]={title=title,body=body,plain=true,textInset=0,rightColumn=right or false}
        end
        local materials,note=A.Crafting.MaterialBlocks(item,context)
        heading("Materials",false,note)
        for _,block in ipairs(materials) do blocks[#blocks+1]=block end
        if item.itemId~=5816 and not item.userItem then
            local alternatives=item.options or (family and item.progression) or {}
            if item.group=="Scrolls" then
                alternatives={}
                for _,candidate in ipairs(D.Scrolls.items) do
                    if candidate.family==item.family and candidate.level<(recommended or item).level then
                        alternatives[#alternatives+1]=candidate
                    end
                end
                table.sort(alternatives,function(a,b) return a.level>b.level end)
            end
            if family and family~="bandage" then
                alternatives={}
                for _,candidate in ipairs(D.Items.items) do
                    if candidate.family==family then alternatives[#alternatives+1]=candidate end
                end
            end
            local choices={}
            if recommended and recommended.itemId~=item.itemId and family~="bandage" then choices[1]=recommended end
            for _,other in ipairs(alternatives) do
                if other.itemId~=item.itemId and (not recommended or other.itemId~=recommended.itemId) then choices[#choices+1]=other end
            end
            if family~="bandage" then
                heading("Alternatives",true)
                if #choices==0 then blocks[#blocks+1]=G.EmptySupplyRow("Alternatives",item) end
            end
            for _,other in ipairs(family=="bandage" and {} or choices) do
                local block=itemRow(other); block.body=G.SupplySubtitle(other,context); block.rightColumn=true; block.plain=true; block.supplyDetail=true
                block.recommendedAlternative=recommended and other.itemId==recommended.itemId
                blocks[#blocks+1]=block
            end
            local nextItem=G.NextSupply(item,context)
            heading("Next",true)
            if nextItem then
                local block=itemRow(nextItem); block.body=G.SupplySubtitle(nextItem,context); block.rightColumn=true; block.plain=true; block.supplyDetail=true
                blocks[#blocks+1]=block
            else
                blocks[#blocks+1]=G.EmptySupplyRow("Next",item)
            end
            if family=="bandage" then
                heading("Alternatives",true)
                for _,other in ipairs(D.Items.items) do
                    if other.family=="bandage" and other.itemId~=item.itemId and (not nextItem or other.itemId~=nextItem.itemId) then
                        local block=itemRow(other); block.body=G.SupplySubtitle(other,context)
                        block.rightColumn=true; block.plain=true; block.supplyDetail=true
                        blocks[#blocks+1]=block
                    end
                end
            end
        end
        if family then blocks[#blocks+1]=row("Profession training","Next recipes, skill books and training routes",{kind="profession",family=family}) end
        local out=card(item.displayName or item.name,nil,blocks)
        out.supplyTable=true
        local r=S.Record(context,item,family)
        table.insert(out.blocks,1,supplyRow(r,context)); out.blocks[1].action=nil; out.blocks[1].editTarget=not r.oneTime
        if family then rankState(out.blocks[1],r,context) end
        out.blocks[1].body=G.SupplySubtitle(item,context)
        out.blocks[1].supplyDetail=true
        out.itemLayout=true
        out.itemSectionTitle=recommended and recommended.itemId~=item.itemId and "Selected Alternative" or "Recommended"
        if defaults then
            out.defaultItem=item
            out.isDefault=S.PreferredItem(context,defaults).itemId==item.itemId
        elseif S.CanDefaultBandage(context,item) then
            out.defaultItem=item
            out.isDefault=S.Selection(context,"bandage")==item.itemId
        end
        if not r.oneTime then out.quantityRecord={title="Auto-buy amount",quantityEditor=true,targetKey=r.targetKey,target=r.target,refillThreshold=r.refillThreshold} end
        if item.itemId==5816 then
            out.blocks[#out.blocks+1]={title="How to Obtain",plain=true,textInset=0,rightColumn=true}
            local completed=C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted or IsQuestFlaggedCompleted
            for _,quest in ipairs({{1016,"Elemental Bracers"},{1017,"Mage Summoner"}}) do
                local done=completed and completed(quest[1])
                local status=done==true and "|cff66ee99Completed|r" or done==false and "|cffff6666Not completed|r" or "Status unknown"
                out.blocks[#out.blocks+1]={title=quest[2]..(quest[1]==1017 and " - Suggested Level (28-30+)" or ""),body=status,rightColumn=true,
                    action={kind="questLink",questId=quest[1],name=quest[2]}}
            end
            local macro,correct=C.EluneMacroState()
            out.blocks[#out.blocks+1]={title="Create Elune Macro",plain=true,textInset=0,rightColumn=true}
            out.blocks[#out.blocks+1]={title=correct and "Macro Created" or macro and "FIX ELUNE MACRO!!" or "Create Macro",
                rightColumn=true,macroControl=true,macroCorrect=correct,macroBroken=macro and not correct,
                action={kind="eluneMacro"}}
            out.blocks[#out.blocks+1]={title="Light of Elune",body=correct and "Drag to your action bar" or "Create the macro to drag it to your action bar",
                icon="Interface\\Icons\\INV_Potion_13",rightColumn=true,macroDrag=correct,
                action=correct and {kind="eluneMacro",drag=true} or nil}
        end
        return out
    end
    if kind=="supplyFamily" then
        -- Keep an opened rank stable while recipe updates arrive or quantities are edited.
        if action.item then return C.Detail(context,{kind="item",item=action.item}) end
        local selected=S.Selection(context,action.family)
        local fallback
        for _,item in ipairs(D.Items.items) do
            if item.family==action.family then
                fallback=fallback or item
                if item.itemId==selected then action.item=item; return C.Detail(context,{kind="item",item=item}) end
            end
        end
        if fallback then action.item=fallback; return C.Detail(context,{kind="item",item=fallback}) end
        return card(groupNames[action.family],nil,{})
    end
    if kind=="profession" then
        local title=action.family=="cooking" and "Cooking" or action.family=="dummy" and "Engineering" or "First Aid"
        return card(title,"Your character's skills and learned recipes",professionBlocks(context,action.family))
    end
    if kind=="card" then return action.card end
    if kind=="guide" then
        local g=guides[action.index]
        return card(g.name,"Classic pet care",{row(nil,g.body)})
    end
    if kind=="family" then
        local f=families[action.id]
        local blocks={row("Diet",f.diet),row("Family attributes",f.modifiers,nil,f.role.." role"),
            row("Browse "..f.name,"Locations, levels, appearances and attack speeds",{view="petguide",filter="Pets",query=f.name})}
        for _,id in ipairs(f.abilities) do
            blocks[#blocks+1]=row(abilities[id].name,"View ranks and training sources",{kind="ability",id=id})
        end
        blocks[#blocks+1]=row("Shared passive training","Armor, stamina and resistances are in the Abilities tab.",{view="petguide",filter="Abilities"})
        return card(f.name,"Family guide",blocks)
    end
    if kind=="ability" then
        local ability=abilities[action.id]; local blocks={}
        for index,r in ipairs(ability.ranks) do
            local levelText="Pet "..r.petLevel.."+  |  "..r.trainingPoints.." training points"
            if context.petLevel and context.petLevel<r.petLevel then levelText=levelText.."  |  Above your pet's level" end
            blocks[#blocks+1]=row("Rank "..r.rank..(r.trainer and " - Pet trainer" or " - Tame to learn"),r.effect,
                {kind="rank",id=ability.id,index=index},levelText)
        end
        return card(ability.name,"Compatible: "..familyNames(ability.families),blocks)
    end
    if kind=="rank" then
        local ability=abilities[action.id]; local rank=ability.ranks[action.index]
        local blocks={row(nil,rank.effect,nil,"Pet "..rank.petLevel.."+  |  "..rank.trainingPoints.." training points")}
        if rank.trainer then blocks[#blocks+1]=row("Pet trainer","Buy this skill from a pet trainer, then teach it through Beast Training.")
        elseif #rank.sources==0 then blocks[#blocks+1]=row("No known source","No taming source is listed for this rank.")
        else
            for _,s in ipairs(rank.sources) do
                local tag=s.classification or "Classification unverified"
                if s.zone:find("Dungeon",1,true) or s.zone:find("Raid",1,true) then tag=tag.." / Group encounter" end
                local gate=s.minLevel>context.level and "Above your Hunter level" or "Check the individual spawn's level"
                blocks[#blocks+1]=row(s.name,"Lv "..s.minLevel..(s.maxLevel~=s.minLevel and ("-"..s.maxLevel) or "").."  |  "..s.zone,nil,
                    tag.."  |  "..gate)
            end
        end
        return card(ability.name.." - Rank "..rank.rank,"Catalog sources include rare and group encounters. Learned skills are not checked.",blocks)
    end
    if kind=="pet" then
        local p=D.PetGuide.pets[action.index]
        local blocks={row("Location",p.zone,nil,"Level "..p.level),
            row("Taming",p.tameable and "Listed as tameable. Your Hunter must be at least the individual creature's level." or "Not tameable in Classic.",nil,p.classification),
            row("Attack speed",p.attackSpeed and (p.attackSpeed.." seconds between attacks") or "Not listed"),
            row("Known wild abilities",#p.abilities>0 and table.concat(p.abilities,", ") or "None listed. Verify with Beast Lore."),
            row("Appearance",table.concat(p.looks,", ")),
            row(families[p.family].name,"Diet, family modifiers and compatible abilities",{kind="family",id=p.family})}
        if p.historicalCaster then blocks[#blocks+1]=row("Historical caster entry","The Vanilla caster penalty is obsolete in Classic.",{kind="guide",index=5}) end
        return card(p.name,"Creature details",blocks)
    end
end

function C.Build(context,state)
    if state.view=="training" and state.filter=="Rotation Helper" then return A.RotationHelper:Document(context) end
    if state.view=="training" and (state.filter=="Gear" or state.filter=="Talents") then return A.TalentAdvisor:Document(context,state) end
    if state.view=="training" and state.filter=="Zone Advisor" then return A.MapAdvisor:Document(context,state) end
    if state.view=="training" and state.filter=="Spells" and not state.detail then return A.ClassSpells.Build(context,state) end
    if (state.view=="instances" or state.view=="dungeons" or state.view=="raids") and not state.detail then
        return A.Instances.Build(context,state)
    end
    local result={context=context,cards={},view=state.view or "supplies",continuous=true,page=1,pages=1}
    if result.view=="now" then result.view="supplies" end
    local view=result.view
    local profession=state.view=="training" and not state.detail and ({["First Aid"]="bandage",Cooking="cooking"})[state.filter]
        or state.detail and state.detail.kind=="profession" and (state.detail.family=="bandage" or state.detail.family=="cooking") and state.detail.family
    if profession then
        result.cards=professionCards(context,profession); result.professionPage=true
    elseif state.detail then
        if state.detail.kind=="supplyFamily" and state.detail.family=="bandage" then result.cards=bandageCards(context,state)
        else result.cards[1]=C.Detail(context,state.detail) end
        result.isDetail=true
    elseif view=="supplies" then
        if state.filter=="Buffs" then state.filter="Elixirs" end
        if state.filter=="Food & drink" then state.filter="Food & Drink" end
        result.filters=S.filters
        local rows,summary=supplyRows(context,state)
        result.summary=summary
        if not state.filter or state.filter=="All" then
            result.continuous=true
            result.total,result.pages,result.page=#rows,1,1
            for index=2,#S.categories do
                local category=S.categories[index]
                local group={}
                for _,b in ipairs(rows) do
                    if b.category==category then b.supplyColumns=true; group[#group+1]=b end
                end
                if category=="Enchants" then
                    result.total=result.total-#group
                    group=A.Enchants.Card(context).blocks
                    for _,b in ipairs(group) do b.supplyColumns=true; b.category=category end
                    result.total=result.total+#group
                end
                local section=card(category,#group==0 and "No matching items in this category." or nil,group)
                section.supplyTable=true; section.allSupplyTable=true; section.fullWidth=true
                result.cards[#result.cards+1]=section
                if category=="Class" and context.characterClass=="Hunter" and A.HunterTraining then
                    result.cards[#result.cards+1]=A.HunterTraining.Card(context)
                end
            end
        else
            result.cards[1]=card(state.filter,
                state.filter=="User" and "Drag an item from your bags anywhere onto this page to add it." or nil,rows)
            result.cards[1].supplyTable=true
            if state.filter=="Enchants" then
                result.cards={A.Enchants.Card(context)}
            end
            if state.filter=="Class" and context.characterClass=="Hunter" and A.HunterTraining then
                result.cards[#result.cards+1]=A.HunterTraining.Card(context)
            end
        end
        result.searchable,result.stockFilter=false,false
    elseif view=="training" then
        local petTraining=context.characterClass=="Hunter" and state.filter=="Pet Training"
        local blocks={row("Before you pull",P.classNotes[context.characterClass])}
        if petTraining then
            local ctx={characterClass="Hunter",level=context.level,petLevel=context.petLevel,mode=context.mode,detailed=false,
                faction=context.faction,factionUnknown=context.factionUnknown}
            local h=G.Hunter(ctx)
            blocks={row("Train a new pet skill","A short guide to learning and teaching abilities",{kind="guide",index=1}),
                row("Training points and ability limits","Plan your pet's active abilities and passive skills",{kind="guide",index=2})}
            for _,b in ipairs(h.blocks) do if b.abilityId then
                blocks[#blocks+1]=row(b.title,b.body,{kind="ability",id=b.abilityId},"Training opportunity; learned ranks are not checked")
            end end
            if context.level<10 then blocks[#blocks+1]=row("First pet quest","Taming, feeding and training unlock through the level-10 quest chain.") end
        elseif context.characterClass=="Hunter" then
            blocks[#blocks+1]=row("Common pet choices","Leveling companions and common tames",{kind="hunterChoices"})
            blocks[#blocks+1]=row("Quivers and ammo pouches","Your current tier and next upgrade",{kind="quivers"})
        elseif context.characterClass=="Warlock" then
            local ctx={level=context.level,detailed=true}
            local w=G.Warlock(ctx)
            for _,b in ipairs(w.blocks) do
                if b.title then blocks[#blocks+1]=row(b.title,(b.body or ""):match("^[^\n]+"),{kind="card",card=card(b.title,nil,{b})}) end
            end
        else
            blocks[#blocks+1]=row("Emergency supplies","Choose tools that fit your profession and escape plan.",{view="supplies",filter="Emergency"})
        end
        if not petTraining then
            table.insert(blocks,2,row("Shared cooldowns and Self Found","Read before planning a sequence of emergency items.",{kind="card",card=card("Emergency planning",nil,{
                row("Shared cooldowns","Healing, mana and escape potions compete for a cooldown. Healthstones, mana gems, target dummies and Felwood healing plants share another cooldown. Do not plan to chain those as independent saves."),
                row("Self Found","Trading, auction house and mail are unavailable. Check recipe access and obtain materials yourself. Item recommendations do not imply ownership or a known recipe.")})}))
            for index,tab in ipairs(C.Tabs(context)) do
                if index>1 then table.insert(blocks,index+1,row(C.TabLabel(tab),tabDescriptions[tab],C.TabAction(tab))) end
            end
        end
        result.cards[1]=card(petTraining and "Pet training" or "Overview",
            petTraining and (context.petLevel and ((context.mode=="preview" and "Planned" or "Active").." pet level "..context.petLevel) or "No active pet level detected; no current rank assumed.") or nil,blocks)
    elseif view=="petguide" then
        result.filters={"Families","Abilities","Pets","Care"}; result.searchable=true
        local filter=state.filter or "Families"; local blocks={}
        if filter=="Families" then
            for _,f in ipairs(D.PetGuide.families) do if match(f.name.." "..f.id.." "..f.diet.." "..f.role,state.query) then blocks[#blocks+1]=row(f.name,f.role.."  |  Eats: "..f.diet,{kind="family",id=f.id}) end end
        elseif filter=="Abilities" then
            for _,a in ipairs(D.PetGuide.abilities) do if match(a.name.." "..familyNames(a.families),state.query) then blocks[#blocks+1]=row(a.name,#a.ranks.." ranks  |  "..familyNames(a.families),{kind="ability",id=a.id}) end end
        elseif filter=="Pets" then
            result.levelFilter=true
            for i,p in ipairs(D.PetGuide.pets) do
                local searchable=p.name.." "..p.family.." "..families[p.family].name.." "..p.zone.." "..table.concat(p.abilities," ").." "..table.concat(p.looks," ").." "..p.classification.." "..tostring(p.attackSpeed or "")
                if match(searchable,state.query) and (not state.atLevel or (context.level>=10 and p.tameable and p.maxLevel<=context.level)) then blocks[#blocks+1]=petRow(p,i) end
            end
        else
            for i,g in ipairs(guides) do if match(g.name.." "..g.body,state.query) then blocks[#blocks+1]=row(g.name,"Open quick guide",{kind="guide",index=i}) end end
        end
        result.cards[1]=card(filter,nil,blocks)
    end
    if #result.cards==1 then
        local out=result.cards[1]; local all=out.blocks
        result.total=#all
        if #all==0 then
            local unknown=context.inventory and not context.inventory.available and view=="supplies"
            out.blocks[1]=row(unknown and "Bag counts unavailable" or state.stock=="Missing" and "Nothing to restock here" or "No matches",
                context.inventory and not context.inventory.available and view=="supplies" and "Bag counts are unavailable. Try again after entering the world."
                or state.stock=="Missing" and "Your visible carry targets are met. Change categories or show all items."
                or "Try another search or filter.")
        end
    end
    return result
end
