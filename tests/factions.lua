-- Faction affects local acquisition advice, never the usability of tradable food
-- or the completeness of the wild-beast catalog.
local A=TestAddon
local P,G,C,S,D=A.Planner,A.Guide,A.Companion,A.Supplies,A.Data
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local function context(faction)
    return {characterClass="Hunter",level=60,petLevel=60,characterLevel=32,mode="preview",
        faction=faction or nil,factionUnknown=not faction,inventory={available=true,counts={}},
        professions={available=true,skills={bandage=180,dummy=0,cooking=150},
            baseSkills={bandage=180,dummy=0,cooking=150},maxSkills={bandage=225,dummy=0,cooking=150},
            known={[3275]=true,[3276]=true,[3277]=true,[3278]=true,[7928]=true,[7929]=false}}}
end
local function allText(value,seen)
    if type(value)=="string" then return value end
    if type(value)~="table" then return "" end
    seen=seen or {}; if seen[value] then return "" end; seen[value]=true
    local parts={}; for _,v in pairs(value) do parts[#parts+1]=allText(v,seen) end
    return table.concat(parts,"\n")
end
local function has(text,part) return text:find(part,1,true)~=nil end
local function original(id)
    for _,item in ipairs(D.Items.items) do if item.itemId==id then return item end end
    error("Missing test item "..id)
end
local function listed(plan,id)
    for _,key in ipairs({"rows","backups","specialist","advanced"}) do
        for _,item in ipairs(plan[key]) do if item.itemId==id then return true end end
    end
    return false
end

check(P.ContextFaction(context("Alliance"))=="Alliance","Known faction retained")
check(P.ContextFaction(context(false))==false,"Unknown is explicit, not unrestricted")
check(P.ContextFaction({})==nil,"Legacy fixture contract retained")
for _,faction in ipairs({"Alliance","Horde",false}) do
    local ctx=context(faction)
    local plan=P.BuildList("Hunter",60,P.ContextFaction(ctx))
    check(listed(plan,4941)==(faction=="Horde"),"Glue is a Horde quest reward")
    check(listed(plan,3434)==(faction=="Horde"),"Sand is a Horde quest reward")
    check(listed(plan,5816)==(faction=="Alliance"),"Light of Elune is an Alliance reward")
    check(listed(plan,8952),"Ordinary vendor food remains available")
    local supplies=S.Build(ctx,{filter="Optional"})
    for _,record in ipairs(supplies) do
        check(P.MatchesFaction(record.item,P.ContextFaction(ctx)),"Supplies cannot bypass faction restrictions")
    end
    local quivers=allText(G.Quivers({level=60,detailed=true,faction=ctx.faction,factionUnknown=ctx.factionUnknown}))
    check(has(quivers,"Night Watch")== (faction=="Alliance"),"Night Watch only offered to Alliance")
    check(has(quivers,"Blackrock Depths") and has(quivers,"Molten Core"),"Shared quiver routes retained")
end

local alliance,horde,unknown=context("Alliance"),context("Horde"),context(false)
for _,sample in ipairs({
    {3665,"Kendor Kabonka","Nerrist"},
    {12210,"Corporal Bluth","Nerrist"},
    {12212,"Corporal Bluth","Nerrist"},
    {13443,"Ulthir","Algernon"},
    {5634,"Soolie Berryfizz","Kor'geld"},
}) do
    local item=original(sample[1])
    local a=P.ItemForFaction(item,"Alliance")
    local h=P.ItemForFaction(item,"Horde")
    local u=P.ItemForFaction(item,false)
    check(a and h and u,"Tradeable items stay usable for both factions")
    check(has(a.route,sample[2]) and not has(a.route,sample[3]),"Alliance local vendor")
    check(has(h.route,sample[3]) and not has(h.route,sample[2]),"Horde local vendor")
    check(not has(u.route,sample[2]) and not has(u.route,sample[3]),"Unknown hides faction vendor")
end
local goulash=P.ItemForFaction(original(1082),"Horde")
check(goulash and has(goulash.route,"trading") and not has(goulash.route,"Stormwind"),"Foreign food has trade route, not foreign shopping advice")
check(has(P.ItemForFaction(original(3726),false).route,"Super-Seller 680"),"Neutral recipe vendor remains when faction unknown")
check(has(P.ItemForFaction(original(12218),"Horde").route,"Himmik"),"Neutral vendor remains for Horde")
check(not has(P.ItemForFaction(original(12218),"Horde").route,"Malygen"),"Alliance-only alternative removed")

local synthetic={itemId=8952,name="Shared",family="recovery",options={original(5816),original(4941)},
    progression={original(5816),original(4941)},next=original(5816)}
local filtered=P.ItemForFaction(synthetic,"Horde")
check(#filtered.options==1 and filtered.options[1].itemId==4941,"Nested alternatives filtered")
check(#filtered.progression==1 and filtered.progression[1].itemId==4941 and not filtered.next,"Progression and next filtered")
check(#synthetic.options==2 and synthetic.next.itemId==5816,"Source records not mutated")
check(#G.ItemBlocks(original(5816),unknown)==0,"Unknown detail cannot fall through to legacy unrestricted mode")
check(C.Detail(horde,{kind="item",item=original(5816)}).title=="Unavailable route","Stale cross-faction item detail denied")

-- Routine recommendations respect home zones at every supported level. The
-- complete pet/rank lookup intentionally keeps creatures from both factions.
for _,faction in ipairs({"Alliance","Horde",false}) do
    for level=10,60 do
        local plan=P.HunterPlan(level,level,faction)
        for _,category in ipairs(plan.categories) do
            for _,pet in ipairs(category.pets) do
                check(P.SourceMatchesFaction(pet,faction),"Wrong home-zone pet in routine recommendation")
            end
        end
        for _,pet in ipairs(plan.pets) do check(P.SourceMatchesFaction(pet,faction),"Wrong home-zone starter") end
        for _,ability in pairs(plan.abilities) do
            for _,source in ipairs(ability.sources) do check(P.SourceMatchesFaction(source,faction),"Wrong home-zone training source") end
        end
    end
end
local a10=P.HunterPlan(10,10,"Alliance")
local h10=P.HunterPlan(10,10,"Horde")
check(has(allText(a10.categories),"Moonstalker Runt"),"Alliance gets a practical local cat")
check(has(allText(h10.categories),"Durotar Tiger"),"Horde gets a practical local cat")
check(not has(allText(a10.categories),"Durotar Tiger"),"Alliance starter advice omits Horde home route")
check(not has(allText(h10.categories),"Moonstalker Runt"),"Horde starter advice omits Alliance home route")
check(has(allText(P.HunterPlan(32,32,false).categories),"Salt Flats Vulture"),"Shared routine tame remains without faction")
local localAlliance,localHorde=context("Alliance"),context("Horde")
localAlliance.level,localAlliance.petLevel,localHorde.level,localHorde.petLevel=10,10,10,10
local choices
for _,b in ipairs(C.Build(localAlliance,{view="training"}).cards[1].blocks) do
    if b.title=="Common pet choices" then choices=b.action end
end
check(choices and has(allText(C.Detail(localAlliance,choices)),"Moonstalker Runt"),"Opened detail has current Alliance choices")
check(has(allText(C.Detail(localHorde,choices)),"Durotar Tiger")
    and not has(allText(C.Detail(localHorde,choices)),"Moonstalker Runt"),"Open detail re-evaluates faction instead of keeping cached routes")
for _,ctx in ipairs({alliance,horde,unknown}) do
    check(C.Build(ctx,{view="petguide",filter="Pets"}).total==#D.PetGuide.pets,"Full beast catalog is faction-independent")
    for _,ability in ipairs(D.PetGuide.abilities) do
        for index,rank in ipairs(ability.ranks) do
            if #rank.sources>0 then
                check(#C.Detail(ctx,{kind="rank",id=ability.id,index=index}).blocks==#rank.sources+1,"Gameplay creature source rows retained")
            end
        end
    end
end

-- Training remains discoverable with no profession; supply details explain the
-- next recipe using the actual character, independent of the planned level.
local training=C.Build(alliance,{view="training"})
local seen={}
for _,card in ipairs(training.cards) do
    for _,b in ipairs(card.blocks) do
        if b.action and b.action.kind=="profession" then seen[b.action.family]=true end
    end
end
check(seen.cooking and seen.bandage and seen.dummy,"Three profession details accessible from Companion")
local bandage=C.Detail(alliance,{kind="supplyFamily",family="bandage"})
check(has(allText(bandage),"Heavy Silk Bandage"),"Supply-family detail includes next recipe")
check(has(allText(bandage),"Deneb") and not has(allText(bandage),"Balai"),"Profession detail is faction-local")
check(not G.References,"Removed external Sources API")
for _,doc in ipairs({training,bandage,C.Build(alliance,{view="supplies"}),C.Build(alliance,{view="petguide",filter="Care"})}) do
    check(not has(allText(doc),"https://") and not has(allText(doc),"http://"),"No outward URL metadata")
    for _,card in ipairs(doc.cards or {doc}) do
        for _,block in ipairs(card.blocks) do check(not block.sources,"No Sources presentation on blocks") end
    end
end
print("PASS: "..checks.." faction checks cover exclusive rewards, local vendors, shared supplies, recursive alternatives, routine pet routes, full creature lookup and profession guidance.")
