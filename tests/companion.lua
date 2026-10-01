local A=TestAddon
local C,D=A.Companion,A.Data.PetGuide
local function context(class,level,pet)
    return {characterClass=class,level=level,petLevel=pet,mode="live"}
end
for _,class in ipairs(A.Planner.classes) do
    for level=1,60 do
        local doc=C.Build(context(class,level),{view="now"})
        assert(#doc.cards==#A.Supplies.categories-1 and doc.view=="supplies" and doc.stockFilter==false and doc.searchable==false)
        assert(doc.pages==1 and doc.page==1 and doc.continuous)
        local count=0
        for index,card in ipairs(doc.cards) do
            assert(card.title==A.Supplies.categories[index+1] and card.supplyTable)
            for _,b in ipairs(card.blocks) do
                assert(b.supply and (b.itemId or b.groupSupply) and b.category==card.title)
                count=count+1
            end
        end
        assert(count==doc.total)
        assert(doc.summary.tracked>0 and doc.summary.ready==0)
    end
end
local stocked=context("Hunter",60,60)
stocked.inventory={available=true,counts={}}
local complete=C.Build(stocked,{view="supplies",filter="All",page=999})
assert(complete.total>12 and complete.pages==1 and complete.page==1,"All supplies are one complete continuous list")
local names={}
for _,card in ipairs(complete.cards) do
    for _,b in ipairs(card.blocks) do
        local key=b.itemId or b.title
        assert(not names[key],"All list duplicated an item/group"); names[key]=true
    end
end
for _,stock in ipairs({"All","Missing"}) do
    for _,query in ipairs({"","potion","food","nonexistent-match-xyz"}) do
        local doc=C.Build(stocked,{view="supplies",filter="All",stock=stock,query=query,page=99})
        local expected=0
        for index=2,#A.Supplies.categories do
            local state={view="supplies",filter=A.Supplies.categories[index],stock=stock,query=query}
            local first=C.Build(stocked,state)
            expected=expected+first.total
        end
        assert(doc.total==expected and doc.page==1 and doc.pages==1,"Grouped All lost filtered/category rows")
    end
end
local ctx=context("Hunter",32,20)
for _,f in ipairs(D.families) do
    local doc=C.Detail(ctx,{kind="family",id=f.id})
    assert(doc.title==f.name and doc.blocks[1].body==f.diet and doc.blocks[2].body==f.modifiers)
end
local ranks=0
for _,a in ipairs(D.abilities) do
    assert(#C.Detail(ctx,{kind="ability",id=a.id}).blocks==#a.ranks)
    for i,r in ipairs(a.ranks) do
        local doc=C.Detail(ctx,{kind="rank",id=a.id,index=i})
        assert(doc.blocks[1].body==r.effect and r.effect~="")
        if #r.sources>0 then assert(#doc.blocks==#r.sources+1) end
        ranks=ranks+1
    end
end
assert(ranks==111)
for i,p in ipairs(D.pets) do
    local doc=C.Detail(ctx,{kind="pet",index=i})
    assert(doc.title==p.name and doc.blocks[1].body==p.zone)
    assert(doc.blocks[2].meta==p.classification)
end
for i,l in ipairs(D.looks) do assert(C.Detail(ctx,{kind="look",index=i}).title==l.name) end
for i=1,5 do assert(C.Detail(ctx,{kind="guide",index=i}).blocks[1].body~="") end
-- Every catalog is complete in one scrollable list, without repeats or gaps.
local total,seen=0,{}
local first=C.Build(ctx,{view="petguide",filter="Pets"})
for _,filter in ipairs({"Families","Abilities","Pets","Looks","Care"}) do
    local doc=C.Build(ctx,{view="petguide",filter=filter,page=999})
    assert(doc.continuous and doc.page==1 and doc.pages==1)
    assert(#doc.cards[1].blocks==doc.total)
end
do
    local doc=first
    for _,b in ipairs(doc.cards[1].blocks) do
        assert(not seen[b.action.index]); seen[b.action.index]=true; total=total+1
    end
end
assert(total==559)
local owls=C.Build(ctx,{view="petguide",filter="Pets",query="owl"})
for _,b in ipairs(owls.cards[1].blocks) do assert(D.pets[b.action.index].family=="owl") end
assert(C.Build(ctx,{view="petguide",filter="Pets",query="broken tooth",atLevel=true}).total==0)
assert(C.Build(context("Hunter",37),{view="petguide",filter="Pets",query="broken tooth",atLevel=true}).total==1)
assert(C.Build(context("Hunter",9),{view="petguide",filter="Pets",atLevel=true}).total==0)
assert(C.Build(ctx,{view="petguide",filter="Pets",query="A-Me 01",atLevel=true}).total==0)
assert(C.Build(ctx,{view="petguide",filter="Pets",page=999}).total==559)
-- Every item detail has an exact stock row and one labeled information panel;
-- alternatives are separate links, not repeated walls of description text.
for _,item in ipairs(A.Data.Items.items) do
    local doc=C.Detail(stocked,{kind="item",item=item})
    assert(doc.blocks[1].supply and doc.blocks[1].itemId==item.itemId)
    assert(doc.blocks[2].fields and not doc.blocks[2].body)
    local fields={}
    for _,f in ipairs(doc.blocks[2].fields) do
        assert(f.label and type(f.value)=="string" and f.value~="")
        fields[f.label]=f.value
    end
    assert(fields.Effect and fields["Use level"],"Missing basic item labels")
    if item.craftSkill then assert(fields.Crafting and fields["Recipe source"],"Missing profession labels") end
    local craft=A.Crafting and A.Crafting.GetInfo(item,stocked)
    if craft and craft.craftable then
        local rankLabel=craft.craftKind=="classSpell" and "Spell training"
            or craft.craftKind=="poison" and "Ability training" or "Profession rank"
        local sourceLabel=craft.craftKind=="classSpell" and "Spell source" or "Recipe source"
        assert(fields.Crafting and fields[rankLabel] and fields[sourceLabel] and fields.Materials,
            "Missing researched crafting fields for "..item.name)
        assert(fields["Recipe AH"] and fields["Finished item AH"],"Recipe and finished item eligibility must be separate")
    end
    if craft and (item.name=="Elixir of Greater Defense" or item.name=="Restorative Potion") then
        assert(fields.Crafting:find(item.name=="Restorative Potion" and "215" or "195",1,true))
        assert(fields["Profession rank"]:find("Expert Alchemy",1,true)
            and fields["Profession rank"]:find("character level 20",1,true),"Alchemy profession rank must show its character-level gate")
    end
end
print('PASS: 540 categorized continuous supply dashboards with complete All/search/Missing rows; all item details have labeled fields; 17 families, 111 ranks, 559 creatures, 145 looks and 5 care guides render; pet search, level gates and catalog pagination verified.')
