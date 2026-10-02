-- Permanent Classic Era enchants. Recommendations are leveling budgets, not
-- character-level use requirements. Never infer eligibility from armor weight.
local _, A = ...
local E={}; A.Enchants=E
local D=A.Data.Enchants
E.slots={{15,"Back","Cloak"},{5,"Chest","Chest"},{9,"Wrists","Bracer"},{10,"Hands","Gloves"},
    {7,"Legs","Legs"},{8,"Feet","Boots"},{16,"Main hand","Weapon"},{17,"Off hand","Weapon"}}
local locations={[15]={INVTYPE_CLOAK=true},[5]={INVTYPE_CHEST=true,INVTYPE_ROBE=true},[9]={INVTYPE_WRIST=true},
    [10]={INVTYPE_HAND=true},[7]={INVTYPE_LEGS=true},[8]={INVTYPE_FEET=true},
    [16]={INVTYPE_WEAPON=true,INVTYPE_WEAPONMAINHAND=true,INVTYPE_2HWEAPON=true},
    [17]={INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_SHIELD=true}}
local caster={Mage=true,Priest=true,Warlock=true}
local mana={Mage=true,Priest=true,Warlock=true,Druid=true,Paladin=true,Shaman=true,Hunter=true}
local melee={Warrior=true,Rogue=true,Paladin=true,Shaman=true}
local byId,byEnchant={},{}
local function family(r)
    return r.name:match(" %- (.*)$"):gsub("Minor ",""):gsub("Lesser ",""):gsub("Greater ","")
        :gsub("Superior ",""):gsub("Major ",""):gsub("Mighty ",""):gsub("Advanced ","")
end
for _,r in ipairs(D.recipes) do r.family=family(r); byId[r.spellId]=r; byEnchant[r.enchantId]=r end
E.byId=byId
local function points(r,class)
    local f=r.family
    local amount=tonumber(r.effect:match("(%d+)%s*$")) or 1
    local weights={Health=.35,Stamina=4,Defense=.05,Deflection=1,Stats=10,
        Agility=caster[class] and 0 or class=="Hunter" and 5 or 4,
        Strength=(melee[class] or class=="Druid") and 3 or 0,
        Intellect=mana[class] and (caster[class] and 5 or 3) or 0,
        Spirit=mana[class] and 1.5 or 0,Mana=mana[class] and .16 or 0,
        ["Mana Regeneration"]=mana[class] and 5 or 0,
        ["Spell Power"]=caster[class] and 5 or 0,["Healing Power"]=0,
        ["Winter's Might"]=class=="Mage" and 4 or 0,
        Striking=melee[class] and 8 or 0,Impact=melee[class] and 8 or 0}
    if f=="Speed" then return 100 end -- Movement speed is a survival choice.
    local w=weights[f]
    return type(w)=="number" and amount*w or 0
end
local function relevant(r,class)
    local f=r.family
    if f=="Intellect" or f=="Spirit" or f=="Mana" or f=="Mana Regeneration" then return mana[class] end
    if f=="Winter's Might" or f=="Frost Power" then return class=="Mage" or class=="Shaman" end
    if f=="Fire Power" then return class=="Mage" or class=="Warlock" or class=="Shaman" end
    if f=="Shadow Power" then return class=="Priest" or class=="Warlock" end
    if f=="Spell Power" then
        return caster[class] or class=="Druid" or class=="Shaman" or class=="Paladin"
    end
    if f=="Healing Power" then return class=="Priest" or class=="Druid" or class=="Shaman" or class=="Paladin" end
    if f=="Agility" or f=="Strength" or f=="Striking" or f=="Impact" or f=="Crusader" then return not caster[class] end
    return true -- Situational resistance, profession and proc enchants remain browsable.
end
function E.Compatible(r,gear)
    if gear.status=="unknown" or gear.status=="empty" or gear.status=="incompatible" then return false end
    if gear.itemLevel and gear.itemLevel<r.gearLevel then return false end
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
    local name,_,_,level,_,_,_,_,loc,_,_,classId=info(g.link)
    if not name or not level or level<=0 or not loc or loc=="" then return g end
    g.itemLevel,g.equipLoc,g.enchantId=level,loc,enchant
    if not locations[g.slotId][loc] or classId and classId~=2 and classId~=4 then g.status="incompatible"; return g end
    g.status="checked"; g.current=byEnchant[enchant]
    return g
end
function E.Options(context,g)
    local out={}
    for _,r in ipairs(D.recipes) do
        if r.level<=context.level and relevant(r,context.characterClass) and E.Compatible(r,g) then out[#out+1]=r end
    end
    table.sort(out,function(a,b)
        local av,bv=points(a,context.characterClass),points(b,context.characterClass)
        if av~=bv then return av>bv end
        if a.skill~=b.skill then return a.skill>b.skill end
        return a.spellId<b.spellId
    end)
    return out
end
function E.Scan(context)
    local result={}
    local choices=context.enchantChoices or (context.mode~="preview" and A.characterDB and A.characterDB.enchantChoices) or {}
    for _,slot in ipairs(E.slots) do
        local g
        if context.mode=="preview" then
            g={slotId=slot[1],name=slot[2],kind=slot[3],status="preview",
                equipLoc=slot[3]=="Weapon" and "INVTYPE_WEAPON" or next(locations[slot[1]])}
        else g=E.Read(slot) end
        g.options=E.Options(context,g)
        local choice=choices[g.slotId] or choices[tostring(g.slotId)]
        for _,r in ipairs(g.options) do if choice==r.spellId then g.recommendation=r; g.selected=true; break end end
        if not g.recommendation and choice~="kit" then
            for _,r in ipairs(g.options) do if points(r,context.characterClass)>0 then g.recommendation=r; break end end
        end
        local r=g.recommendation
        if r and g.status=="checked" then
            if g.enchantId==0 then g.status="missing"; g.needed=true
            elseif g.enchantId==r.enchantId then g.status="ready"
            elseif g.selected then g.status="replace"; g.needed=true
            elseif g.current and g.current.family==r.family
                and points(r,context.characterClass)>points(g.current,context.characterClass) then g.status="upgrade"; g.needed=true
            else g.status="enchanted" end
        end
        result[#result+1]=g
    end
    return result
end
function E.PlannedSlots(context)
    local out={}; for _,g in ipairs(E.Scan(context)) do if g.needed then out[g.slotId]=true end end; return out
end
function E.MaterialItems(context)
    local totals,uses={},{}
    for _,g in ipairs(E.Scan(context)) do if g.needed then
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
            route="Collect these materials for an enchanter. Self Found characters must supply and apply their own enchants.",
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
local function enchantBlock(g,r,action)
    local status,tone
    if not g.enchantId then status,tone=labels[g.status] or "Unknown","unknown"
    elseif g.enchantId==0 then status,tone="Missing","missing"
    elseif r and g.enchantId==r.enchantId then status,tone="Enchanted","ready"
    else status,tone="Alt Enchanted","ready" end
    local b=row(g.name.." - "..(r and r.name:match(" %- (.*)$") or "No recommendation"),
        r and r.description or labels[g.status],action,r and r.icon or "Trade_Engraving")
    b.enchantRow=true; b.enchantStatus=status; b.enchantTone=tone
    b.enchantTooltip=r
    return b
end
function E.Card(context)
    local blocks={}
    for _,g in ipairs(E.Scan(context)) do
        blocks[#blocks+1]=enchantBlock(g,g.recommendation,{kind="enchantSlot",slotId=g.slotId})
    end
    return {title="Enchants",note="Class and level recommendations. Choose a slot for alternatives and materials.",blocks=blocks,supplyTable=true}
end
function E.Detail(context,action)
    local g
    for _,v in ipairs(E.Scan(context)) do if v.slotId==action.slotId then g=v; break end end
    if not g then return {title="Enchants",blocks={}} end
    local selected=g.recommendation
    for _,option in ipairs(g.options) do if option.spellId==action.spellId then selected=option end end
    local blocks={}
    local function heading(title,right,body)
        local b=row(title,body); b.plain=true; b.textInset=0; b.rightColumn=right; blocks[#blocks+1]=b
    end
    heading("Recommended")
    blocks[#blocks+1]=enchantBlock(g,g.recommendation,g.recommendation and
        {kind="enchantRecipe",slotId=g.slotId,spellId=g.recommendation.spellId} or nil)
    if context.mode~="preview" then
        if g.selected or not g.recommendation then
            blocks[#blocks+1]=row("Automatic recommendation","Use the class and leveling recommendation",{kind="enchantChoose",slotId=g.slotId})
        end
        if g.slotId==5 or g.slotId==7 or g.slotId==8 or g.slotId==10 then
            blocks[#blocks+1]=row("Use armor kits","Track a compatible armor kit",{kind="enchantChoose",slotId=g.slotId,spellId="kit"},"INV_Misc_ArmorKit_17")
        end
    end
    heading("Alternatives")
    for _,option in ipairs(g.options) do if option~=g.recommendation then
        blocks[#blocks+1]=enchantBlock(g,option,{kind="enchantRecipe",slotId=g.slotId,spellId=option.spellId})
    end end
    heading("Materials",true,selected and selected.name or "No compatible enchant selected")
    if selected then
        if selected~=g.recommendation and context.mode~="preview" then
            local b=row("Use this enchant","Track materials for this alternative",{kind="enchantChoose",slotId=g.slotId,spellId=selected.spellId})
            b.rightColumn=true; blocks[#blocks+1]=b
        end
        for _,pair in ipairs(selected.reagents) do
            local m=D.materials[pair[1]]; local inv=context.inventory or {}
            local count=inv.available and inv.counts and (inv.counts[m.itemId] or 0) or nil
            local b=row(m.name,"Required: "..pair[2],nil,m.icon)
            b.itemId=m.itemId; b.supply=true; b.rightColumn=true
            b.count=count; b.target=pair[2]; b.readOnlyTarget=true
            b.status=count==nil and "unknown" or count>=pair[2] and "ready" or count==0 and "missing" or "low"
            blocks[#blocks+1]=b
        end
        local b=row("Requirements","Enchanting "..selected.skill.." | "..selected.tool..
            "\nFor one application. Materials are consumed; the rod is reusable."..
            (g.enchantId and g.enchantId>0 and "\nApplying a different enchant replaces the current enhancement." or ""))
        b.rightColumn=true; blocks[#blocks+1]=b
    end
    return {title=g.name.." enchants",blocks=blocks,itemLayout=true,fullWidth=true}
end
