-- Permanent Classic Era enchants. Eligibility follows actual item restrictions,
-- not the skill or level of the enchanter. Never infer it from armor weight.
local _, A = ...
local E={}; A.Enchants=E
local D=A.Data.Enchants
E.slots={{15,"Back","Cloak"},{5,"Chest","Chest"},{9,"Wrists","Bracer"},{10,"Hands","Gloves"},
    {7,"Legs","Legs"},{8,"Feet","Boots"},{16,"Main hand","Weapon"},{17,"Off-Hand","Weapon"},{18,"Ranged","Ranged"}}
local locations={[15]={INVTYPE_CLOAK=true},[5]={INVTYPE_CHEST=true,INVTYPE_ROBE=true},[9]={INVTYPE_WRIST=true},
    [10]={INVTYPE_HAND=true},[7]={INVTYPE_LEGS=true},[8]={INVTYPE_FEET=true},
    [16]={INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true,INVTYPE_2HWEAPON=true},
    [17]={INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_SHIELD=true},
    [18]={INVTYPE_RANGED=true,INVTYPE_RANGEDRIGHT=true}}
local scopeClasses={Hunter=true,Warrior=true,Rogue=true}
local mana={Mage=true,Priest=true,Warlock=true,Druid=true,Paladin=true,Shaman=true,Hunter=true}
local byId,byEnchant={},{}
local function family(r)
    if r.scope then return r.scopeHit and "scope-hit" or "scope-damage" end
    return r.name:match(" %- (.*)$"):gsub("Minor ",""):gsub("Lesser ",""):gsub("Greater ","")
        :gsub("Superior ",""):gsub("Major ",""):gsub("Mighty ",""):gsub("Advanced ","")
end
for _,r in ipairs(D.recipes) do r.family=family(r); byId[r.spellId]=r; byEnchant[r.enchantId]=r end
E.byId=byId
function E.Mode()
    return A.characterDB and A.characterDB.enchantMode=="max" and "max" or "level"
end
function E.SetMode(mode)
    if not A.characterDB or (mode~="max" and mode~="level") then return end
    A.characterDB.enchantMode=mode
    if A.Readiness then A.Readiness:SuppliesChanged() end
    A:Refresh(true)
end
local function withinRecommendationTier(r,context)
    if r.scope then return true end -- Scopes have explicit wearer levels, like armor kits.
    if E.Mode()=="max" then return true end
    -- Budget tiers guide recommendations, not whether a wearer can use an enchant.
    local level=context.level or 1
    local skill=level>=60 and 300 or level>=50 and 290 or level>=40 and 250
        or level>=30 and 200 or level>=20 and 150 or level>=10 and 100 or 50
    return r.skill<=skill
end
local kits={}
local kitSlots={[5]=true,[7]=true,[8]=true,[10]=true}
for _,item in ipairs(A.Data.ArmorKits.items) do
    local r={}; for k,v in pairs(item) do r[k]=v end
    r.spellId=item.crafting.spellId; r.skill=item.crafting.skill
    r.description=item.detail; r.effect=item.short
    kits[#kits+1]=r; byId[r.spellId]=r; byEnchant[r.enchantId]=r
    for _,pair in ipairs(r.reagents) do
        D.materials[pair[1]]=D.materials[pair[1]] or {itemId=pair[1],name=pair[3]}
    end
end
function E.Profile(context)
    local class=(context.characterClass or ""):upper()
    local build=A.TalentAdvisor:Build(class,context.level)
    local profile=A.GearAdvisor.Profile(class,context.level,nil,build and build.profile)
    if profile then
        profile.buildID=build and build.id
        profile=A.GearAdvisor:ApplyWeights(profile)
        local source=A.Data.AdvisorGear[class][profile.id]
        profile.weights.haste=source.stats.HASTE or 0
        if context.mode~="preview" and UnitRangedDamage then
            local speed=UnitRangedDamage("player")
            if type(speed)=="number" and speed>0 then profile.rangedSpeed=speed end
        end
    end
    return profile
end
local function role(profile)
    if not profile then return {} end
    local c,id=profile.class,profile.id
    local tank=c=="WARRIOR" and (id==3 or id==4) or c=="PALADIN" and id==2 or c=="DRUID" and id==3
    local healer=c=="PRIEST" and id~=3 or c=="PALADIN" and id==1
        or c=="DRUID" and id==4 or c=="SHAMAN" and id==3
    local feral=c=="DRUID" and (id==2 or id==3)
    local physical=c=="WARRIOR" or c=="ROGUE" or c=="PALADIN" and id~=1
        or c=="SHAMAN" and id==2 or c=="HUNTER" and id==4
    return {tank=tank,healer=healer,feral=feral,physical=physical}
end
local effectStats={Health="health",Mana="mana",Stamina="stamina",Strength="strength",Agility="agility",
    Intellect="intellect",Spirit="spirit",Armor="armor",Defense="defense",Dodge="dodge",Blocking="block",
    ["Healing Spells"]="healing",["Mana Regen"]="mp5",["Attack Speed"]="haste",
    ["Frost Spell Damage"]="frost",["Frost Damage"]="frost",["Fire Damage"]="fire",["Shadow Damage"]="shadow"}
-- Same weight sum as gear. No arbitrary score for procs, threat, movement,
-- profession skill or weapon damage without a weapon-speed model.
function E.Score(r,profile)
    if not profile then return nil end
    local w=profile.weights
    if r.scope then
        -- Scope hit is ranged-only; do not value it as melee hit for rogues/warriors.
        if r.scopeHit then return profile.class=="HUNTER" and r.power*(w.hit or 0) or 0 end
        -- A three-second estimate is used only when ranged speed is unavailable (e.g. preview).
        return r.power*(w.rangedDPS or 0)/(profile.rangedSpeed or 3)
    end
    if r.armorKit then return r.power*(w[r.defenseKit and "defense" or "armor"] or 0) end
    local effect=r.effect
    if type(effect)~="string" then return nil end
    local amount=tonumber(effect:match("%d+"))
    if not amount then return nil end
    if effect:match("^All Stats") then
        return amount*((w.strength or 0)+(w.agility or 0)+(w.stamina or 0)+(w.intellect or 0)+(w.spirit or 0))
    end
    if effect:match("^Spell Damage") then return amount*((w.spellPower or 0)+(w.healing or 0)) end
    if effect:find("All Resistances",1,true) then
        return amount*((w.fireResistance or 0)+(w.frostResistance or 0)+(w.natureResistance or 0)
            +(w.shadowResistance or 0)+(w.arcaneResistance or 0))
    end
    local school=effect:match("(%a+) Resistance")
    if school then return amount*(w[school:lower().."Resistance"] or 0) end
    local matched,length
    for prefix,key in pairs(effectStats) do
        if effect:sub(1,#prefix)==prefix and (not length or #prefix>length) then matched,length=key,#prefix end
    end
    if matched then return amount*(w[matched] or 0) end
    return nil
end
local professionBonuses={Mining="mining",Herbalism="herbalism",Skinning="skinning",Fishing="fishing"}
local meleeEffects={Striking=true,Impact=true,Crusader=true,["Fiery Weapon"]=true,
    ["Icy Chill"]=true,Lifestealing=true,["Unholy Weapon"]=true,Demonslaying=true,
    Beastslayer=true,["Elemental Slayer"]=true,Haste=true}
local function relevant(r,context,profile)
    local class=context.characterClass
    if r.scope then return scopeClasses[class] and context.level>=r.level end
    profile=profile or E.Profile(context)
    local roles=role(profile)
    local w=profile and profile.weights or {}
    local f=r.family
    local profession=professionBonuses[f]
    if profession then
        local skills=context.professions and (context.professions.baseSkills or context.professions.skills)
        return context.mode~="preview" and skills and (skills[profession] or 0)>0
    end
    if f=="Threat" then return roles.tank end
    if f=="Subtlety" then return not roles.tank end
    if f=="Stealth" then return class=="Rogue" or roles.feral end
    if f=="Haste" then return roles.physical or roles.feral end
    if meleeEffects[f] then return roles.physical end
    if f=="Intellect" or f=="Spirit" or f=="Mana" or f=="Mana Regeneration" then return mana[class] end
    if f=="Winter's Might" or f=="Frost Power" then return not roles.healer and (w.frost or 0)>0 end
    if f=="Fire Power" then return not roles.healer and (w.fire or 0)>0 end
    if f=="Shadow Power" then return not roles.healer and (w.shadow or 0)>0 end
    if f=="Spell Power" then
        return (w.spellPower or 0)>0 or roles.healer
    end
    if f=="Healing Power" then return roles.healer end
    if f=="Agility" then return roles.physical or roles.feral or class=="Hunter" end
    if f=="Strength" then return roles.physical or roles.feral end
    return true -- General survival, resistance and movement bonuses.
end
function E.Compatible(r,gear)
    if gear.status=="unknown" or gear.status=="empty" or gear.status=="incompatible" then return false end
    if gear.itemLevel and gear.itemLevel<r.gearLevel then return false end
    if r.scope then
        return gear.slotId==18 and (gear.subclassID==2 or gear.subclassID==3 or gear.subclassID==18)
    end
    if r.armorKit then return kitSlots[gear.slotId]==true end
    if r.slot=="2H Weapon" then return gear.equipLoc=="INVTYPE_2HWEAPON" end
    if r.slot=="Shield" then return gear.equipLoc=="INVTYPE_SHIELD" end
    if r.slot=="Weapon" then return gear.kind=="Weapon" and gear.equipLoc~="INVTYPE_SHIELD" end
    return r.slot==gear.kind
end
function E.Read(slot)
    local g={slotId=slot[1],name=slot[2],kind=slot[3],status="unknown"}
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not GetInventoryItemID or not GetInventoryItemLink or not info then return g end
    local id=GetInventoryItemID("player",g.slotId)
    if not id or id==0 then g.status="empty"; return g end
    g.itemId=id; g.link=GetInventoryItemLink("player",g.slotId)
    local linked,enchant=tostring(g.link):match("item:(%d+):([^:]*):")
    enchant=enchant=="" and 0 or tonumber(enchant)
    if tonumber(linked)~=id or not enchant or enchant<0 then return g end
    local name,_,_,level,_,_,_,_,loc,_,_,classId,subclassID=info(g.link)
    if not name or not level or level<=0 or not loc or loc=="" then return g end
    g.itemLevel,g.equipLoc,g.enchantId=level,loc,enchant
    g.subclassID=subclassID
    if not locations[g.slotId][loc] or classId and classId~=2 and classId~=4 then g.status="incompatible"; return g end
    if g.slotId==18 and not (subclassID==2 or subclassID==3 or subclassID==18) then g.status="incompatible"; return g end
    g.status="checked"; g.current=byEnchant[enchant]
    return g
end
-- Group equivalent effects, including Protection/Defense and Deflect/Deflection.
local function rankKey(r)
    if r.armorKit then return r.family end
    return (r.effect:gsub("%d+", "#"))
end
function E.Options(context,g,showLesser)
    local out,best={},{}
    local profile=E.Profile(context)
    local function add(r)
        if not E.Compatible(r,g) then return end
        if showLesser then out[#out+1]=r; return end
        local key=rankKey(r)
        local old=best[key]
        local amount=r.power or tonumber(r.effect:match("%d+")) or 0
        local previous=old and (old.power or tonumber(old.effect:match("%d+")) or 0)
        if not old or amount>previous or amount==previous and r.skill>old.skill then best[key]=r end
    end
    for _,r in ipairs(D.recipes) do
        if relevant(r,context,profile) and withinRecommendationTier(r,context) then add(r) end
    end
    for _,r in ipairs(kits) do
        if r.level<=context.level then add(r) end
    end
    if not showLesser then for _,r in pairs(best) do out[#out+1]=r end end
    table.sort(out,function(a,b)
        local av,bv=E.Score(a,profile) or -1,E.Score(b,profile) or -1
        if av~=bv then return av>bv end
        if a.skill~=b.skill then return a.skill>b.skill end
        return a.spellId<b.spellId
    end)
    return out
end
function E.Scan(context)
    local result={}
    local profile=E.Profile(context)
    for _,slot in ipairs(E.slots) do
        local g
        if context.mode=="preview" then
            g={slotId=slot[1],name=slot[2],kind=slot[3],status="preview",
                subclassID=slot[1]==18 and 2 or nil,
                equipLoc=slot[3]=="Weapon" and "INVTYPE_WEAPON" or next(locations[slot[1]])}
        else g=E.Read(slot) end
        g.options=E.Options(context,g)
        -- Browsing an alternative is temporary. Old saved choices must never
        -- replace the automatic recommendation or create material demand.
        g.profile=profile
        local first=g.options[1]
        g.recommendation=first and (E.Score(first,profile) or 0)>0 and first or nil
        local r=g.recommendation
        if r and g.status=="checked" then
            if g.enchantId==0 then g.status="missing"; g.needed=true
            elseif g.enchantId==r.enchantId then g.status="ready"
            elseif g.current and g.current.family==r.family
                and (E.Score(r,profile) or 0)>(E.Score(g.current,profile) or 0) then g.status="upgrade"; g.needed=true
            else g.status="enchanted" end
        end
        result[#result+1]=g
    end
    return result
end
function E.PlannedSlots(context)
    local out={}; for _,g in ipairs(E.Scan(context)) do if g.needed and not g.recommendation.armorKit then out[g.slotId]=true end end; return out
end
function E.MaterialItems(context)
    local totals,uses={},{}
    for _,g in ipairs(E.Scan(context)) do if g.needed and not g.recommendation.armorKit then
        for _,pair in ipairs(g.recommendation.reagents) do
            local id,n=pair[1],pair[2]; totals[id]=(totals[id] or 0)+n
            uses[id]=uses[id] or {}; uses[id][#uses[id]+1]=g.name..": "..g.recommendation.name
        end
    end end
    local items={}
    for id,n in pairs(totals) do
        local base=D.materials[id]
        items[#items+1]={itemId=id,name=base.name,icon=base.icon,family="enchant-material-"..id,
            enchantMaterial=true,supplyCategory="Enchants",recommendedTarget=n,classes={"All"},level=1,
            short="Need "..n.." for equipped gear",detail=table.concat(uses[id],"\n"),
            route="Materials for the listed enhancement's crafter. Self Found characters must craft their own enhancements.",
            caution="Materials are totaled across needed slots. Already enchanted, incompatible and unknown pieces are excluded."}
    end
    table.sort(items,function(a,b) return a.name<b.name end); return items
end
function E.DetailMaterial(context,item)
    for _,current in ipairs(E.MaterialItems(context)) do if current.itemId==item.itemId then return current end end
    local copy={}; for k,v in pairs(item) do copy[k]=v end
    copy.recommendedTarget=0; copy.short="No currently needed enchant uses this material"
    copy.detail="No verified equipped slot currently needs this material."
    return copy
end
local function row(title,body,action,icon,spell)
    return {title=title,body=body,action=action,icon=icon,spellId=spell}
end
local labels={empty="No item equipped",unknown="Waiting for item data",incompatible="This item cannot take these enchants",
    checked="Armor kit or situational enchant",missing="|cffff785eMissing enchant|r",upgrade="|cffffcd52Older enchant: upgrade available|r",
    ready="|cff62d79bAlready applied|r",replace="Selected replacement: overwrites current enhancement",
    enchanted="Existing enhancement kept",preview="Preview: gear eligibility not checked"}
function E.Subtitle(r)
    local effect=r.effect or r.description or ""
    if r.armorKit then effect="+"..r.power..(r.defenseKit and " Defense" or " Armor")
    else
        local stat,amount=effect:match("^(.-) %+(%d+%%?)$")
        if stat then effect="+"..amount.." "..stat end
        effect=effect:gsub("Mana Regen (%d+) per 5 sec%.","+%1 Mana / 5 sec")
    end
    if r.skill then effect=effect.." - "..(r.scope and "Engineering " or r.armorKit and "Leatherworking " or "Enchanting ")..r.skill end
    if r.armorKit or r.scope then effect=effect.." - Level "..r.level end
    if r.gearLevel and r.gearLevel>1 then effect=effect.." - Item level "..r.gearLevel.."+" end
    return effect
end
local function enchantBlock(g,r,action)
    local status,tone
    if not g.enchantId or g.status=="incompatible" then status,tone=labels[g.status] or "Unknown","unknown"
    elseif g.enchantId==0 then status,tone="Missing","missing"
    elseif r and g.enchantId==r.enchantId then status,tone="Enchanted","ready"
    else status,tone="Alt Enchanted","ready" end
    local name=r and (r.armorKit and r.name or r.name:match(" %- (.*)$"))
        or (g.status=="unknown" or g.status=="empty" or g.status=="incompatible") and labels[g.status] or "No recommendation"
    local b=row(g.name.." - "..name,
        r and E.Subtitle(r) or labels[g.status],action,r and r.icon or "Trade_Engraving")
    b.enchantRow=true; b.enchantStatus=status; b.enchantTone=tone
    b.enchantTooltip=r
    b.enchantScore=r and E.Score(r,g.profile)
    b.enchantProfile=g.profile and g.profile.name
    return b
end
function E.Card(context)
    local blocks={}
    for _,g in ipairs(E.Scan(context)) do
        local alternative=g.enchantId and g.enchantId>0 and g.status~="incompatible"
            and (not g.recommendation or g.enchantId~=g.recommendation.enchantId)
        local shown=alternative and g.current or g.recommendation
        if alternative and not g.current then
            shown={name="Enchant - Unidentified enhancement",description="An enhancement is applied; its effect is not in the catalog.",icon="Trade_Engraving"}
        end
        local b=enchantBlock(g,shown,{kind="enchantSlot",slotId=g.slotId})
        if b.enchantStatus=="Missing" and g.recommendation then b.enchantStatus="Not Enchanted"
        elseif alternative then b.enchantStatus="Alternative" end
        local visibleOffhand=g.slotId~=17 or g.itemId and g.status~="incompatible" and g.status~="unknown" and g.status~="empty"
        if visibleOffhand and (g.slotId~=18 or scopeClasses[context.characterClass] and g.status~="incompatible") then blocks[#blocks+1]=b end
    end
    return {title="Enchants",note="Recommendations for your class and equipped gear. Choose a slot for alternatives and materials.",blocks=blocks,supplyTable=true}
end
function E.Detail(context,action)
    local g
    for _,v in ipairs(E.Scan(context)) do if v.slotId==action.slotId then g=v; break end end
    if not g then return {title="Enchants",blocks={}} end
    local selected=g.current or g.recommendation
    local recommended=g.recommendation
    local options=E.Options(context,g,true)
    for _,option in ipairs(options) do if option.spellId==action.spellId then selected=option end end
    -- Future ranks are browsable, but still obey class and equipped-item rules.
    local requested=byId[action.spellId]
    if requested and E.Compatible(requested,g) and (requested.armorKit or relevant(requested,context)) then selected=requested end
    local blocks={}
    local function heading(title,right,body)
        local b=row(title,body); b.plain=true; b.textInset=0; b.rightColumn=right; blocks[#blocks+1]=b
    end
    heading(selected~=recommended and "Selected Alternative" or "Recommended")
    local selectedBlock=enchantBlock(g,selected)
    if selectedBlock.enchantStatus=="Alt Enchanted" then
        selectedBlock.enchantStatus="Missing"
        selectedBlock.enchantTone="missing"
    end
    blocks[#blocks+1]=selectedBlock
    heading("Alternatives",true)
    local listed={}
    local function alternative(option)
        if not option or option==selected or listed[option.spellId] then return end
        listed[option.spellId]=true
        local b=enchantBlock(g,option,{kind="enchantRecipe",slotId=g.slotId,spellId=option.spellId})
        b.enchantAlternative=true
        b.rightColumn=true
        if b.enchantStatus=="Alt Enchanted" then b.enchantStatus="" end
        if option==recommended then b.enchantStatus="|cff62d79bRecommended|r" end
        blocks[#blocks+1]=b
    end
    alternative(recommended)
    if g.current and (g.current.armorKit or relevant(g.current,context)) then alternative(g.current) end
    for _,option in ipairs(A.state and A.state.showLesserEnchants and options or g.options) do alternative(option) end
    heading("Materials",false,not selected and "No compatible enchant selected" or nil)
    if selected then
        for _,pair in ipairs(selected.reagents) do
            local m=D.materials[pair[1]]; local inv=context.inventory or {}
            local count=inv.available and inv.counts and (inv.counts[m.itemId] or 0) or nil
            local b=row(m.name,nil,nil,m.icon)
            b.itemId=m.itemId; b.supply=true
            b.count=count; b.target=pair[2]; b.readOnlyTarget=true; b.materialCount=true
            b.status=count==nil and "unknown" or count>=pair[2] and "ready" or count==0 and "missing" or "low"
            blocks[#blocks+1]=b
        end
    end
    local nextRank
    if selected then
        for _,catalog in ipairs({D.recipes,kits}) do
            for _,candidate in ipairs(catalog) do
                if rankKey(candidate)==rankKey(selected) and candidate.skill>selected.skill
                    and E.Compatible(candidate,g) and (candidate.armorKit or relevant(candidate,context))
                    and (not nextRank or candidate.skill<nextRank.skill) then nextRank=candidate end
            end
        end
    end
    heading("Next",true)
    if nextRank then
        local b=enchantBlock(g,nextRank,{kind="enchantRecipe",slotId=g.slotId,spellId=nextRank.spellId})
        b.enchantAlternative=true; b.rightColumn=true; blocks[#blocks+1]=b
    else
        blocks[#blocks+1]=A.Guide.MaximumSkillRow()
    end
    return {title=g.name.." enchants",blocks=blocks,itemLayout=true,fullWidth=true}
end
