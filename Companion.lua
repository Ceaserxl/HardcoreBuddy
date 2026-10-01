-- Focused companion views with live inventory and crafting recommendations.
local _, A = ...
local P, G, D, S = A.Planner, A.Guide, A.Data, A.Supplies
local C = {}; A.Companion = C
local families, abilities = {}, {}
for _, f in ipairs(D.PetGuide.families) do families[f.id]=f end
for _, a in ipairs(D.PetGuide.abilities) do abilities[a.id]=a end
local function card(title,note,blocks) return {title=title,note=note,blocks=blocks or {}} end
local function row(title,body,action,meta)
    return {title=title,body=body,action=action,meta=meta}
end
function C.Tabs(context)
    return context.characterClass=="Hunter" and {"Overview","Zone Advisor","Spells","Pet Training","Pet Guide","First Aid","Engineering","Cooking"}
        or {"Overview","Zone Advisor","Spells","First Aid","Engineering","Cooking"}
end
local tabDescriptions={["Zone Advisor"]="Recommended leveling zones, dangerous NPCs and maps.",Spells="Your next training level and future class and pet spells.",
    ["Pet Training"]="Learn and teach pet abilities.",["Pet Guide"]="Pet families, abilities, taming sources and care.",
    ["First Aid"]="Your next bandage recipe and skill training.",Engineering="Target dummy recipes and profession training.",
    Cooking="Recipes and training for your next skill tier."}
function C.TabAction(tab)
    local family=({["First Aid"]="bandage",Engineering="dummy",Cooking="cooking"})[tab]
    if family then return {kind="profession",family=family} end
    if tab=="Pet Guide" then return {view="petguide",filter="Families"} end
    return {view="training",filter=tab~="Overview" and tab or nil}
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
local function upgradeHint(context,family)
    local nextRecipe=A.Professions.NextRecipe and A.Professions.NextRecipe(context,family)
    if nextRecipe then return "Next recipe: "..nextRecipe.name.." | Click for training" end
end
local function supplyRow(record)
    local b=itemRow(record.item)
    b.title=record.name
    b.body=record.quantityNote or record.item.short
    b.supply=true
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
        block.autoRank=true
        block.readOnlyTarget=selected~=record.itemId
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
                    if r.groupFamily=="dummy" then b.itemId,b.icon=r.itemId,r.item.icon end
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
                local b=supplyRow(r)
                if onlyFamily then
                    if rankState(b,r,context) then track(r) end
                else track(r) end
                if include(r) then blocks[#blocks+1]=b end
            end
        end
    end
    for family,group in pairs(groups) do
        local r=group.selected
        if r then
            local b=supplyRow(r); b.action={kind="supplyFamily",family=family}
            b.autoRank=group.automatic~=nil
            b.body=group.automatic and (upgradeHint(context,family) or group.automatic.note)
                or (r.quantityNote or "").." | Change rank"
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
    if kind=="hunterChoices" then
        local guide=G.Hunter(context)
        return card("Common pet choices",nil,{guide.blocks[1]})
    end
    if kind=="quivers" then return G.Quivers(context) end
    if kind=="item" then
        local item=P.ItemForFaction(action.item,P.ContextFaction(context))
        if not item then return card("Unavailable route",nil,{row(nil,"This quest reward is not available for your faction.")}) end
        if item.armorKit and A.ArmorKits then item=A.ArmorKits.DetailItem(context,item) end
        local family=P.grouped[item.family] and item.family or nil
        local blocks=G.ItemBlocks(item,context)
        if family then blocks[#blocks+1]=row("Profession training","Next recipes, skill books and training routes",{kind="profession",family=family}) end
        local out=card(item.displayName or item.name,nil,blocks)
        out.supplyTable=true
        local r=S.Record(context,item,family)
        table.insert(out.blocks,1,supplyRow(r)); out.blocks[1].action=nil
        if family then rankState(out.blocks[1],r,context) end
        return out
    end
    if kind=="supplyFamily" then
        local blocks=professionBlocks(context,action.family)
        for _,b in ipairs(supplyRows(context,{},action.family)) do blocks[#blocks+1]=b end
        local _,automatic=S.Selection(context,action.family)
        local note=automatic and (automatic.note..". Your character's learned recipes determine the rank; materials are not checked.")
            or "Select one rank for your list. Check its skill requirement; other ranks stay optional."
        local out=card(groupNames[action.family],note,blocks)
        out.supplyTable=true; return out
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
    if state.view=="training" and state.filter=="Zone Advisor" then return A.MapAdvisor:Document(context,state) end
    if state.view=="training" and state.filter=="Spells" and not state.detail then return A.ClassSpells.Build(context,state) end
    if (state.view=="instances" or state.view=="dungeons" or state.view=="raids") and not state.detail then
        return A.Instances.Build(context,state)
    end
    local result={context=context,cards={},view=state.view or "supplies",continuous=true,page=1,pages=1}
    if result.view=="now" then result.view="supplies" end
    local view=result.view
    if state.detail then result.cards[1]=C.Detail(context,state.detail); result.isDetail=true
    elseif view=="supplies" then
        result.filters=S.filters
        local rows,summary=supplyRows(context,state)
        result.summary=summary
        if not state.filter or state.filter=="All" then
            result.continuous=true
            result.total,result.pages,result.page=#rows,1,1
            for index=2,#S.categories do
                local category=S.categories[index]
                local group={}
                for _,b in ipairs(rows) do if b.category==category then group[#group+1]=b end end
                local section=card(category,#group==0 and "No matching items in this category." or nil,group)
                if category=="Buffs" and A.ArmorKits then section.note=A.ArmorKits.Summary(context) end
                section.supplyTable=true
                result.cards[#result.cards+1]=section
                if category=="Class" and context.characterClass=="Hunter" and A.HunterTraining then
                    result.cards[#result.cards+1]=A.HunterTraining.Card(context)
                end
            end
            if #rows==0 then result.cards={card("Your supplies",nil,{})} end
        else
            result.cards[1]=card(state.filter=="Essentials" and "Essentials" or "Your supplies",
                state.filter=="Essentials" and "Your core supplies. Open an item to change its priority; set Carry to 0 to skip restocking." or nil,rows)
            result.cards[1].supplyTable=true
            if state.filter=="Buffs" and A.ArmorKits then result.cards[1].note=A.ArmorKits.Summary(context) end
            if state.filter=="Class" and context.characterClass=="Hunter" and A.HunterTraining then
                result.cards[#rows==0 and 1 or #result.cards+1]=A.HunterTraining.Card(context)
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
                if index>1 then table.insert(blocks,index+1,row(tab,tabDescriptions[tab],C.TabAction(tab))) end
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
