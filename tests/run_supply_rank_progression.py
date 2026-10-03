"""Audit every bundled elixir and scroll rank, including nested detail navigation."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua, addon=boot()
lua.execute('''
local A=TestAddon
local originalProfile=A.Enchants.Profile
local weights={agility=10,intellect=1}
A.Enchants.Profile=function() return {weights=weights} end
local choices={{itemId=3012,level=10},{itemId=955,level=5}}
A.Guide.SortSupplyItems(choices,{characterClass="Mage",level=60})
assert(choices[1].itemId==3012,"Agility build puts agility first")
weights={agility=1,intellect=10}
A.Guide.SortSupplyItems(choices,{characterClass="Mage",level=60})
assert(choices[1].itemId==955,"Build weight changes reorder alternatives")
A.Enchants.Profile=originalProfile
local chains={{3382,3388,3826,20004},{5997,3389,8951,13445},{2458,3825},
    {2457,3390,8949,9187,13452},{2454,3391,9206},{3383,9179},
    {9155,13454},{6373,21546},{3386}}
local items={}; local audited={}; local checks=0
for _,item in ipairs(A.Data.Items.items) do items[item.itemId]=item end
for _,chain in ipairs(chains) do for index,id in ipairs(chain) do
    local item=assert(items[id]); audited[id]=true
    for _,class in ipairs(A.Planner.classes) do if A.Planner.MatchesClass(item,class) then
        for _,level in ipairs({1,25,40,60}) do
            local ctx={level=level,characterClass=class,faction="Alliance"}
            local copy={}; for k,v in pairs(item) do copy[k]=v end
            copy.next=items[chain[#chain]] -- A cached character-level hint must not skip ranks.
            local nextItem=A.Guide.NextSupply(copy,ctx)
            assert((nextItem and nextItem.itemId)==chain[index+1],item.name.." next rank at character level "..level)
            local page=A.Companion.Detail(ctx,{kind="item",item=copy})
            for i,b in ipairs(page.blocks) do if b.title=="Next" then
                local nextRow=page.blocks[i+1]
                assert(chain[index+1] and nextRow.itemId==chain[index+1]
                    or not chain[index+1] and nextRow.disabled and nextRow.emptySection=="Next")
            end end
            checks=checks+1
        end
    end end
end end
for _,item in ipairs(A.Data.Items.items) do
    if A.Supplies.Category(item)=="Elixirs" then assert(audited[item.itemId],"Elixir missing from audit: "..item.name) end
end
for _,item in ipairs(A.Data.Scrolls.items) do
    local class=item.classes[1]=="All" and "Mage" or item.classes[1]
    local ctx={characterClass=class,level=60,faction="Alliance"}
    local highest=item; local nextRank
    for _,other in ipairs(A.Data.Scrolls.items) do if other.family==item.family then
        if other.level>highest.level then highest=other end
        if other.level>item.level and (not nextRank or other.level<nextRank.level) then nextRank=other end
    end end
    assert(A.Guide.NextSupply(item,ctx)==nextRank,"Scroll advances exactly one rank")
    local page=A.Companion.Detail(ctx,{kind="item",item=item})
    local alternatives={}; local inAlternatives=false
    for _,b in ipairs(page.blocks) do
        if b.title=="Next" then inAlternatives=false end
        if b.title=="Alternatives" then inAlternatives=true end
        if inAlternatives and b.itemId then alternatives[b.itemId]=b end
    end
    for _,other in ipairs(A.Data.Scrolls.items) do if other.family==item.family and other.itemId~=item.itemId then
        assert(alternatives[other.itemId] or other==nextRank,"Other scroll ranks remain accessible without duplicating Next")
    end end
    if item~=highest and highest~=nextRank then assert(alternatives[highest.itemId].recommendedAlternative) end
    checks=checks+1
end
print("PASS: "..checks.." elixir/scroll rank and detail-page cases; all catalog elixirs covered.")
''')
