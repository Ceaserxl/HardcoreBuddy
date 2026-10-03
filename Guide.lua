-- Presentation model: no frames, game APIs, inventory or protected actions.
local _, addon = ...
local P, D = addon.Planner, addon.Data
local G = {}
addon.Guide = G
function G.MaximumSkillRow()
    return {title="Maximum Skill Reached",disabled=true,compactRow=true,rightColumn=true}
end
-- Shared compact copy for selected supplies, alternatives and future ranks.
function G.SupplySubtitle(item,context)
    local effect=(item.detail or item.short or ""):gsub("^Use: *","")
    if item.family=="wellfed" or item.family=="manafood" then effect=item.short or effect end
    effect=effect:gsub("the target's ",""):gsub("the player's maximum ","")
    effect=effect:gsub("Must remain seated while %a+%.",""):gsub("%s*%([^)]*[Cc]ooldown%)","")
        :gsub("^Restores ","+"):gsub("^Instantly restores ","+"):gsub("^Heals ","+")
        :gsub("(%d+) to (%d+)","%1–%2"):gsub(" over "," / ")
        :gsub("^Increases your (.-) by ([%d%.]+%%?)","+%2 %1")
        :gsub("^Increases (.-) by ([%d%.]+%%?)","+%2 %1")
        :gsub("^Target is cured of poisons up to level ","Cures poison up to Lvl ")
        :gsub("^Gives the imbiber invisibility","Invisibility")
        :gsub("^Makes you immune to Stun and Movement Impairing effects for the next ","Stun & slow immunity / ")
        :gsub("^Regenerate (%d+) health every 5 sec","+%1 health / 5 sec")
        :gsub(" for "," / "):gsub(" hours?"," hr")
    if item.family=="dummy" then effect="Taunts nearby enemies" end
    if item.name=="Restorative Potion" then effect="Removes magic, curse, poison or disease / 5 sec for 30 sec" end
    if item.name=="Flask of Petrification" then effect="Immune to damage; cannot act / 1 min" end
    if item.family=="bandage" then effect=effect:gsub(" damage"," health") end
    effect=effect:match("^(.-)%.%s") or effect
    effect=effect:gsub("%s+$",""):gsub("%.$","")
    local info=addon.Crafting.GetInfo(item,context)
    if info.craftable and info.profession and info.skill then effect=effect.." - "..info.profession.." "..info.skill end
    return effect
end
function G.NextSupply(item,context)
    if item.next and item.next.itemId~=item.itemId then return item.next end
    local grouped=addon.Planner.grouped[item.family]
    local cookedFood=item.family=="wellfed" or item.family=="manafood"
    local function rank(i)
        local info=addon.Crafting.GetInfo(i,context)
        return grouped and (info.skill or i.power or 0) or cookedFood and i.level or addon.Planner.AvailableAt(i)
    end
    local minimum=rank(item)
    if not grouped and not cookedFood then minimum=math.max(minimum,context.level or 1) end
    local nextItem
    for _,catalog in ipairs({addon.Data.Items.items,addon.Data.Scrolls.items}) do
        for _,other in ipairs(catalog) do
            if other.family==item.family and other.itemId~=item.itemId and (cookedFood or not other.alternative)
                and addon.Planner.MatchesClass(other,context.characterClass)
                and addon.Planner.MatchesFaction(other,addon.Planner.ContextFaction(context)) and rank(other)>minimum
                and (not nextItem or rank(other)<rank(nextItem)) then nextItem=other end
        end
    end
    return nextItem
end
local function add(card, block) card.blocks[#card.blocks + 1] = block; return block end
local function text(card, title, body, meta)
    return add(card, {title=title, body=body, meta=meta})
end
local function card(title, note, kind) return {title=title, note=note, kind=kind, blocks={}} end
local function join(lines) return table.concat(lines, "\n") end
local function requirement(item)
    return item.useSkill and (item.useSkill.name .. " " .. item.useSkill.value) or ("Use level " .. item.level)
end
local function hasAlternatives(item)
    local options=item.options or (P.grouped[item.family] and item.progression) or {}
    for _,other in ipairs(options) do if other.itemId~=item.itemId then return true end end
    return false
end
local function fullRequirement(item)
    local result = requirement(item)
    if item.craftSkill then result = result .. " | Craft: " .. item.craftSkill.name .. " " .. item.craftSkill.value end
    if item.recommendLevel and hasAlternatives(item) then result = result .. " | Suggested from level " .. item.recommendLevel end
    return result
end
function G.ItemFields(item,context)
    local info=addon.Crafting and addon.Crafting.GetInfo(item,context or {}) or {}
    local fields={}
    local function field(label,value,itemId,wide)
        if value~=nil and value~="" then
            fields[#fields+1]={label=label,value=tostring(value),itemId=itemId,wide=wide}
        end
    end
    field("Effect",(item.detail or item.short or ""):gsub("^Use: ",""),nil,true)
    if item.armorKit then
        field("Armor to enhance",item.kitTargets,nil,true)
        field("Gear requirement",item.gearLevel>1 and ("Target armor must be item level "..item.gearLevel.." or higher.")
            or "No minimum armor item level.",nil,true)
    end
    local crafting=info.craftingText
    if not crafting and item.craftSkill then crafting=item.craftSkill.name.." "..item.craftSkill.value end
    field("Crafting",crafting)
    field(info.craftKind=="classSpell" and "Spell training" or info.craftKind=="poison" and "Ability training" or "Profession rank",info.rankText)
    local source=info.recipeSource or item.route
    field(info.craftKind=="classSpell" and "Spell source" or (info.craftable or item.craftSkill) and "Recipe source" or "Acquisition",source,
        info.recipeItemId,true)
    if info.recipeAHText or info.finishedAHText then
        field("Recipe AH",info.recipeAHText,info.recipeItemId)
        field("Finished item AH",info.finishedAHText)
    else field("Auction House",info.ahText) end
    field("Materials",info.materials or item.ingredients,nil,true)
    if item.armorKit and item.reagents then
        local stock=context and context.inventory or {}
        for _,material in ipairs(item.reagents) do
            local count=stock.available and stock.counts and (stock.counts[material[1]] or 0)
            field(material[3],(count and (count>=material[2] and "|cff62d79b" or "|cffff785e")..count.."/"..material[2].."|r in bags" or "Need "..material[2].." | Bags unavailable").." (per kit)",material[1],true)
        end
    end
    field("Use level","Level "..item.level)
    if item.useSkill then field("Use requirement",item.useSkill.name.." "..item.useSkill.value) end
    if item.recommendLevel and hasAlternatives(item) then field("Suggested from","Level "..item.recommendLevel) end
    local notes={}
    if item.binding then notes[#notes+1]="Binds on pickup; obtain it yourself." end
    if item.caution and item.caution~="" then notes[#notes+1]=item.caution end
    if info.tradeNote then notes[#notes+1]=info.tradeNote end
    field("Notes",#notes>0 and table.concat(notes,"\n") or nil,nil,true)
    return fields
end
-- Compact presentation for the Supplies detail page; full reference fields
-- remain available to the other guides and exports.
function G.CompactItemFields(item,context)
    local fields=G.ItemFields(item,context)
    local out={}
    local function compact(value)
        return value:gsub("Must remain seated while eating%.","Seated.")
            :gsub("Must remain seated while drinking%.","Seated.")
            :gsub("Restores (%d+) health over (%d+) sec%.","+%1 health over %2 sec.")
            :gsub("Restores (%d+) mana over (%d+) sec%.","+%1 mana over %2 sec.")
            :gsub(" %(recipe must be learned%)","")
            :gsub("Learn this recipe from ",""):gsub("Learn from ","")
            :gsub("Buy from a food vendor or innkeeper that stocks this tier%. Equivalent bread and fish work too%.","Food vendors and innkeepers.")
            :gsub("Buy from a food vendor or innkeeper that stocks this tier%. Equivalent bread, cheese and fish work too%.","Food vendors and innkeepers.")
            :gsub("Buy from a drink vendor or innkeeper that stocks this tier%.","Drink vendors and innkeepers.")
            :gsub("AH listings are not checked%. Self Found cannot use the Auction House or player trading%.","Self Found: no AH or trading.")
            :gsub("Binds on pickup; obtain it yourself%.","Binds on pickup.")
            :gsub("Recovery food has no Well Fed buff%. Eat only after reaching safety%.","No Well Fed buff. Eat in safety.")
            :gsub("Target armor must be item level (%d+) or higher%.","Item level %1+")
            :gsub(" %(per kit%)","")
    end
    local requirement="Level "..item.level
    if item.useSkill then requirement=requirement.." | "..item.useSkill.name.." "..item.useSkill.value end
    for _,f in ipairs(fields) do
        local label,value=f.label,compact(f.value)
        if label=="Use level" then label,value="Requires",requirement
        elseif label=="Use requirement" then value=nil
        elseif label=="Crafting" and value=="Not profession-crafted." then value=nil
        elseif label=="Profession rank" then
            label="Training"
            value=value:gsub(" %- train at skill "," | Skill "):gsub(", character level "," | Level ")
                :gsub(" %- initial training",""):gsub("; no additional character%-level requirement","")
                :gsub("Learn the Expert skill book%.","Expert skill book."):gsub("Complete ","")
        elseif label=="Acquisition" or label=="Recipe source" then label="Source"
        elseif label=="Recipe AH" then
            if value:find("No recipe item",1,true) or value:find("quest teaches",1,true) then value=nil
            elseif value:find("Tradable recipe",1,true) then value="Tradable recipe"
            elseif value:find("binds when picked up",1,true) then value="Recipe binds on pickup" end
        elseif label=="Finished item AH" then
            label="Trading"
            value=value:find("Tradable",1,true) and "Trade / AH; stock not checked"
                or value:find("conjured",1,true) and "Conjured; no AH"
                or value:find("bound",1,true) and "Bound; no trading" or "Tradability unknown"
        elseif label=="Materials" and item.armorKit and item.reagents then value=nil end
        if value and value~="" then out[#out+1]={label=label,value=value,itemId=f.itemId,wide=f.wide} end
    end
    return out
end
local function itemBlock(target, item, detailed, child, context)
    local grouped = P.grouped[item.family] and item.progression
    local lines = {item.short or ""}
    if grouped then
        lines[#lines + 1] = "Profession skill not checked. Match the explicit use requirement."
    elseif item.useSkill then lines[#lines + 1] = "Requires " .. requirement(item)
    elseif item.binding then lines[#lines + 1] = "Binds on pickup: obtain it yourself."
    elseif item.family == "wellfed" then lines[#lines + 1] = "Well Fed: general leveling choice."
    elseif item.family == "manafood" then lines[#lines + 1] = "Mana-food alternative." end
    add(target, {title=item.displayName or item.name, body=not detailed and join(lines) or nil,
        fields=detailed and G.ItemFields(item,context) or nil,itemId=item.itemId, icon=item.icon,
        meta=(item.family ~= "dummy" and P.ease[item.ease + 1] or "Engineering"),
        family=item.family, recordId=item.id, child=child})
    if grouped and (detailed or item.family == "dummy") then
        for _, rank in ipairs(item.progression) do
            add(target, {title=rank.name, body=not detailed and requirement(rank) or nil,fields=detailed and G.ItemFields(rank,context) or nil,
                itemId=rank.itemId, icon=rank.icon, child=true, recordId=rank.id})
        end
    elseif detailed and item.options then
        if #item.options > 0 then text(target, "Alternatives", "Easiest to obtain first; choose for your build and route.") end
        for _, other in ipairs(item.options) do itemBlock(target, other, true, true,context) end
        if item.next then
            local nextItem = item.next
            add(target, {title="Next: " .. nextItem.name, body="Suggested from level " .. P.AvailableAt(nextItem)
                .. " | " .. fullRequirement(nextItem), child=true})
        end
    end
end
local function beast(s)
    local range = tostring(s.minLevel) .. (s.maxLevel ~= s.minLevel and ("-" .. s.maxLevel) or "")
    return s.name .. " | Lv " .. range .. " | " .. s.zone .. " | NPC " .. s.npcId
end
local function familyNames(ids)
    local names = {}
    for _, id in ipairs(ids) do
        for _, family in ipairs(D.Companions.families) do if family.id == id then names[#names + 1] = family.name end end
    end
    return #names > 0 and table.concat(names, ", ") or "All pet families"
end
local function hunter(context)
    local level, detailed = context.level, context.detailed
    local faction=P.ContextFaction(context)
    local plan = P.HunterPlan(level, context.petLevel, faction)
    local out = card("Hunter pet - leveling plan", "Common tames and training opportunities; learned abilities are not checked.", "hunter")
    local columns = {}
    for _, category in ipairs(plan.categories) do
        local col = {}
        col[1] = {title=category.name, body=category.pick .. "\n" .. category.text}
        for _, pet in ipairs(category.pets) do col[#col + 1] = {body=beast(pet)} end
        if level < 10 then col[#col + 1] = {body="Choose after the level-10 pet quest."} end
        columns[#columns + 1] = col
    end
    add(out, {columns=columns})
    if not plan.unlocked then
        text(out, "Before taming", "Complete the level-10 taming, feeding and training quest sequence. Keep suitable pet food ready.")
    else
        text(out, nil, "Keep a happy, leveled pet. These are training targets, not required replacements. Only tame a beast at or below your Hunter level; check the individual spawn.")
        if level >= 16 and level < 32 and faction=="Horde" then
            text(out, nil, "Keep a local companion until the shared Salt Flats Vulture route at level 32.")
        end
        text(out, nil, context.mode == "preview" and ("Planning assumes pet level " .. level .. ". Return to your character to use your active pet's actual level.")
            or context.petLevel and ("Active pet level " .. context.petLevel .. ". Ranks below respect both pet and Hunter level; family compatibility and training points still apply.")
            or "Active pet level unknown: no current rank is assumed. Summon your pet, or plan a level for reference.")
        local skills = {"growl", "screech", "claw", "bite"}
        if level >= 30 then skills[#skills + 1] = "dive"; skills[#skills + 1] = "dash" end
        for _, id in ipairs(skills) do
            local ability, lines = plan.abilities[id], {}
            local current, nextRank = ability.current, ability.next
            if current then
                lines[#lines + 1] = "Pet " .. current.petLevel .. "+ | " .. current.trainingPoints .. " training points"
                if current.trainer then lines[#lines + 1] = "Learn at the pet trainer."
                else
                    for index, s in ipairs(ability.sources) do
                        if detailed or index == 1 then lines[#lines + 1] = beast(s) end
                    end
                end
            else
                lines[#lines + 1] = context.petLevel and "No routine rank available at these Hunter/pet levels." or "Pet level unknown. Reference requirements below."
            end
            if nextRank and (detailed or not current) then
                lines[#lines + 1] = "Next rank " .. nextRank.rank .. ": Hunter " .. P.TrainingLevel(nextRank) .. "+, pet " .. nextRank.petLevel .. "+."
                if not current and not nextRank.trainer then
                    local first
                    for _, s in ipairs(nextRank.sources) do if s.routine and (not first or s.minLevel < first.minLevel) then first=s end end
                    if first then lines[#lines + 1] = beast(first) end
                end
            end
            if detailed then lines[#lines + 1] = familyNames(ability.families) end
            add(out, {title=ability.name .. (current and (" - Rank " .. current.rank) or " - Not yet / unknown"),
                body=join(lines), abilityId=id, rank=current and current.rank})
        end
        text(out, nil, "Solo Growl on, Cower off. Claw spends focus quickly: disable it if Growl or Screech is delayed. Owls cannot learn Bite; bats cannot learn Claw.")
    end
    if detailed then
        text(out, "Bite, Claw and Screech", "Bite: 35 focus, 10-second cooldown. Claw: 25 focus, repeats on the global cooldown. Screech: 20 focus, single-target damage and nearby melee attack-power reduction. Avoid interfering with crowd control.\nCat: learn Bite/Claw, manage Claw around Growl. Owl: prioritize Growl/Screech, optional Claw. No universal winner across ranks and focus budgets.")
        local stamina = plan.abilities.greatstamina.current
        local armor = plan.abilities.naturalarmor.current
        text(out, "Train without losing your main pet", "1. Stable your main pet and leave room for a temporary tame.\n2. Tame a common source, feed it and let it use the skill until you learn it.\n3. Retrieve your main pet and teach through Beast Training.\nRecipient family, pet level, loyalty/training points and four-active-skill limit apply. Lower ranks may be skipped.\nTrainer ceilings: Great Stamina " .. (stamina and stamina.rank or "unknown / not yet") .. ", Natural Armor " .. (armor and armor.rank or "unknown / not yet") .. ". Maximum ranks are not a promise that all are affordable together.")
        text(out, "Rank roadmap - common sources", "Hunter gates include source tame level. Travel and nearby enemies may make a route unsuitable. Dungeon ranks never replace routine defaults.")
        for _, id in ipairs({"screech", "bite", "claw", "dive", "dash", "charge", "growl"}) do
            local ability = plan.abilities[id]
            text(out, ability.name)
            for _, rank in ipairs(ability.ranks) do
                local unlock, first = P.TrainingLevel(rank)
                for _, s in ipairs(rank.sources) do if s.routine and (not first or s.minLevel < first.minLevel) then first=s end end
                local desc
                if rank.trainer then desc = "Pet trainer | Hunter " .. unlock .. "+"
                elseif first then desc = "Hunter " .. unlock .. "+ | " .. beast(first)
                elseif #rank.sources > 0 then
                    desc = "Optional group route: " .. beast(rank.sources[1]) .. " | " .. rank.sources[1].classification
                        .. ". Keep the previous routine rank until safely learned."
                else desc = "No faction-local training route listed. Keep your previous rank." end
                add(out, {title="R" .. rank.rank .. " | Pet " .. rank.petLevel .. "+ | " .. rank.trainingPoints .. " points",
                    body=desc, child=true})
            end
        end
        text(out, "Family choices", "Descriptive family roles, not talent specializations. Owls remain Offensive despite Screech's defensive value.")
        for _, category in ipairs(plan.categories) do
            text(out, category.name)
            for _, family in ipairs(category.families) do
                local skills = {}
                for _, id in ipairs(family.abilities) do
                    if id ~= "cower" and id ~= "growl" then skills[#skills + 1] = D.Companions.abilityNames[id] or id end
                end
                add(out, {title=family.name, body="Diet: " .. family.diet .. "\n" .. table.concat(skills, ", "),familyId=family.id})
            end
        end
    end
    return out
end
local bags = {}
for _, bag in ipairs(D.Quivers) do bags[bag.id] = bag end
local function quivers(context)
    local plan = P.QuiverPlan(context.level)
    local out = card("Quiver / ammo pouch", "Bows / crossbows use quivers; guns use pouches. Equip the matching bag.", "quiver")
    local function tier(t, title)
        local a, b = bags[t.ids[1]], bags[t.ids[2]]
        add(out, {title=title .. " - Lv " .. t.level .. "+", body=a.name .. " / " .. b.name .. "\n" .. t.route,
            meta=a.slots .. " slots | +" .. a.speed .. "% total ranged speed", itemId=a.id})
    end
    tier(plan.current, "Routine choice")
    if plan.next then tier(plan.next, "Next upgrade") end
    if context.detailed then
        text(out, "Easy upgrade path")
        for _, t in ipairs(D.Presentation.quiverTiers) do if t ~= plan.current then tier(t, "Routine tier") end end
        text(out, "Optional routes")
        if P.MatchesFaction({itemId=3605},P.ContextFaction(context)) then
            add(out, {title="Quiver / Bandolier of the Night Watch", body="12 slots, +11%. Duskwood quest chain. Minimum quest level 18, final quest level 30: not a safe level-18 shopping trip."})
        end
        add(out, {title="Ribbly's Quiver / Bandolier", body="Requires 50, 16 slots, +14%. Blackrock Depths drop: optional group route, not a solo errand."})
        add(out, {title="Ancient Sinew Wrapped Lamina", body="Requires 60, 18 slots, +15%. Hunter epic quest beginning with Ancient Petrified Leaf in Molten Core. Quiver turn-in requires Mature Blue Dragon Sinew."})
    end
    text(out, nil, "Keep the level-40 crafted bag until an optional upgrade is obtained. Speed is the bag's total bonus; extra bags do not stack it.")
    return out
end
local function warlock(context)
    local plan = P.WarlockPlan(context.level)
    local out = card("Warlock demon - leveling plan", "Assumes the demon quest is complete and abilities trained. Ownership is not checked.", "warlock")
    text(out, plan.primary, plan.reason)
    if context.level >= 10 then text(out, nil, plan.sacrifice and "Sacrifice gives an emergency absorb and consumes your Voidwalker."
        or "Sacrifice is not available yet. Its first grimoire requires level 16.") end
    if plan.next then text(out, "Next", plan.next) end
    for _, demon in ipairs(plan.alternatives) do text(out, demon.name, demon.role .. "\n" .. demon.text) end
    local skills = {}
    for _, skill in ipairs(plan.skills) do
        if context.detailed or skill.demon == plan.primary then skills[#skills + 1] = skill.name .. " " .. skill.rank end
    end
    text(out, "Training opportunities", table.concat(skills, " | ") .. "\nHigher ranks use Demon Trainer grimoires. Summon the matching demon to teach it.")
    if context.detailed then
        text(out, "Choose for the pull", "Voidwalker is the cautious default, not guaranteed threat or fastest leveling. Succubus / Incubus supports damage/drain-tanking from 20. Soul Link and Dark Pact depend on talents.")
        text(out, "Utility unlocks", (plan.seduction and "Seduction: level-26 grimoire, humanoid control that breaks on damage. Keep DoTs off the target." or "Seduction requires the level-26 grimoire.")
            .. "\n" .. (plan.spellLock and "Spell Lock: level-36 grimoire. Save the interrupt for dangerous casts." or "Felhunter arrives at 30 with magic dispel; Spell Lock waits until 36."))
        text(out, "Keep the demon ready", "Keep Soul Shards for replacement summons and Healthstones. Imp needs no shard. Use passive/follow near extra packs and ledges; manage Health Funnel without risking yourself. Sacrifice is not a guaranteed escape. Infernal/Doomguard are situational, not normal leveling companions. Soulstone resurrection does not work on Hardcore.")
    end
    return out
end
G.ItemBlocks = function(item,context)
    local out={blocks={}}
    local faction
    if context then faction=P.ContextFaction(context) end
    item=P.ItemForFaction(item,faction)
    if item then
        add(out,{fields=G.ItemFields(item,context),family=item.family,recordId=item.id})
        local alternatives=item.options or (P.grouped[item.family] and item.progression) or {}
        local hasOptions=hasAlternatives(item)
        if hasOptions then text(out,"Alternatives","Open a different item to compare its requirements.") end
        for _,other in ipairs(alternatives) do
            if other.itemId~=item.itemId then
                add(out,{title=other.name,body=other.short,itemId=other.itemId,icon=other.icon,
                    action={kind="item",item=other},child=true})
            end
        end
        if item.next then
            text(out,"Next",hasOptions and ("Suggested from level "..P.AvailableAt(item.next)) or nil)
            add(out,{title=item.next.name,body=item.next.short,itemId=item.next.itemId,icon=item.next.icon,
                action={kind="item",item=item.next},child=true})
        end
    end
    return out.blocks
end
G.Hunter, G.Quivers, G.Warlock = hunter, quivers, warlock
function G.Build(context)
    local result = {cards={}, context=context, classNote=P.classNotes[context.characterClass]}
    local list = P.BuildList(context.characterClass, context.level,P.ContextFaction(context))
    local notes = {"Recovery and food-buff alternatives. Choose one buff for your build.",
        "Keep recovery potions; sustained elixir buffs are optional preparation.",
        "Match tools to actual profession skills. Potions share a cooldown."}
    for index, name in ipairs(P.groups) do
        local out = card(name, notes[index], "carry")
        for _, item in ipairs(list.rows) do if item.group == name then itemBlock(out, item, context.detailed,nil,context) end end
        result.cards[#result.cards + 1] = out
    end
    if context.characterClass == "Hunter" then
        result.cards[#result.cards + 1] = hunter(context)
        result.cards[#result.cards + 1] = quivers(context)
    elseif context.characterClass == "Warlock" then result.cards[#result.cards + 1] = warlock(context) end
    if context.detailed then
        for _, group in ipairs({{"Specialist food alternatives", list.specialist}, {"Route-specific backups", list.backups}, {"Advanced emergency options", list.advanced}}) do
            if #group[2] > 0 then
                local out = card(group[1], "Optional routes: acquisition readiness is separate from item use level.", "extra")
                for _, item in ipairs(group[2]) do itemBlock(out, item, true,nil,context) end
                result.cards[#result.cards + 1] = out
            end
        end
        local out = card("How this list is ranked", "Editorial effort bands, not live prices or guaranteed availability.", "method")
        text(out, nil, "Choose the strongest eligible routine recovery/elixir rank; prefer repeatable food buffs. Sort each section and alternatives by acquisition effort: Vendor > Simple craft > Recipe / travel > Farm / limited > Special access.\nKnown recipes, professions, faction and nearby ingredients may change the practical order. Use skill and craft skill are different. No profession, known recipe, quest, inventory or cooldown readiness is assumed.")
        text(out, "Cooldowns and Self Found", "Healing, mana and escape potions compete for a cooldown. Healthstones, mana gems, target dummies and Felwood healing plants also share a cooldown; they are not independent back-to-back saves. Food buffs are alternatives.\nSelf Found disables trading, auction house and mail: obtain recipes/materials yourself. Other classes can receive a Warlock Healthstone only when trading is allowed.")
        result.cards[#result.cards + 1] = out
    end
    return result
end
