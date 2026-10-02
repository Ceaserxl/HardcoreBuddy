"""Vendor foods across classes, local equivalents, and zone-wide sellers."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local P,V=A.Planner,A.VendorServices
for _,class in ipairs(P.classes) do
    local drink
    for _,row in ipairs(P.BuildList(class,60,'Alliance').rows) do if row.family=='drink' then drink=row end end
    local ids={[drink.itemId]=true}
    for _,item in ipairs(drink.options) do ids[item.itemId]=true end
    for _,id in ipairs({159,1179,1205,1708,1645,8766,19300}) do assert(ids[id],'Vendor drink alternative '..id) end
end
local elune
for _,item in ipairs(A.Data.Items.items) do if item.itemId==5816 then elune=item end end
local ctx={characterClass='Mage',level=40,faction='Alliance',inventory={available=true,counts={}},targets={[5816]=99}}
C_QuestLog={IsQuestFlaggedCompleted=function(id) assert(id==1016 or id==1017); return false end}
local r=A.Supplies.Record(ctx,elune)
assert(r.target==1 and r.count==0 and r.name:find('(Obtainable)',1,true) and not r.refillNeeded)
local detail=A.Companion.Detail(ctx,{kind='item',item=elune})
assert(not detail.quantityRecord,'Quest reward has no refill controls')
local chain={}
for _,b in ipairs(detail.blocks) do
    if b.action and b.action.kind=='questLink' then
        assert(b.rightColumn and b.body:find('Not completed',1,true)); chain[#chain+1]=b.action.questId
    end
end
assert(chain[1]==1016 and chain[2]==1017 and #chain==2)
StaticPopupDialogs={}
StaticPopup_Show=function(key,name,unused,url)
    assert(name=='Elemental Bracers' and url=='https://www.wowhead.com/classic/quest=1016')
    local edit=CreateFrame('EditBox')
    StaticPopupDialogs[key].OnShow({editBox=edit},url)
    assert(edit:GetText()==url)
end
A:Activate({kind='questLink',questId=1016,name='Elemental Bracers'})
C_QuestLog.IsQuestFlaggedCompleted=function() return true end
r=A.Supplies.Record(ctx,elune)
assert(r.count==0 and r.target==1 and not r.name:find('Obtainable'))
ctx.inventory.counts[5816]=1
r=A.Supplies.Record(ctx,elune)
assert(r.count==1 and r.target==1 and r.status=='ready')
C_QuestLog=nil
assert(A.Supplies.filters[4]=='Elixirs' and A.Supplies.filters[5]=='Scrolls','Elixirs followed by Scrolls')
local lone={itemId=1,name='Only item',level=1,classes={'All'},recommendLevel=5,next={itemId=2,name='Next',level=10}}
for _,b in ipairs(A.Guide.ItemBlocks(lone,{})) do
    if b.title=='Next' then assert(b.body==nil,'No suggested line without alternatives') end
    for _,f in ipairs(b.fields or {}) do assert(f.label~='Suggested from') end
end
for _,class in ipairs(P.classes) do
 for _,level in ipairs({1,5,15,25,35,45,60}) do
  local food,drink
  for _,row in ipairs(P.BuildList(class,level,'Alliance').rows) do
   if row.family=='recovery' then food=row elseif row.family=='drink' then drink=row end
  end
  assert(food and drink,class..' has food and drink')
  local count=food.vendorFood and 1 or 0
  for _,item in ipairs(food.options) do
   assert(item.level<=level,'No unusable food')
   if item.vendorFood then count=count+1 end
  end
  assert(count>=6,'All six standard vendor food types available for '..class)
 end
end
local map=1453
C_Map=C_Map or {}
C_Map.GetBestMapForUnit=function() return map end
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .01,.01 end} end
UnitFactionGroup=function() return 'Alliance' end
A.characterDB.vendorVisits={}
assert(not V:FindVendor(2287),'No invented Stormwind Haunch of Meat seller')
local equivalent=V:FindSupplyVendor(2287,4)
assert(equivalent and equivalent.alternativeName and equivalent.map==1453,'Stormwind equivalent food seller')
assert(not V:FindSupplyVendor(2287,5),'Five owned blocks alternative vendor suggestion')
assert(not V:FindSupplyVendor(2287),'Unknown quantity never suggests a substitute')
assert(V:FindSupplyVendor(equivalent.alternativeID,20),'Exact seller remains available regardless of stock')
local food
for _,row in ipairs(P.BuildList('Mage',5,'Alliance').rows) do if row.family=='recovery' then food=row end end
local context={characterClass='Mage',supplyDefaults={},inventory={available=true,counts={[2287]=4}}}
local selected=A.Supplies.PreferredItem(context,food)
assert(selected.itemId~=2287 and V:FindVendor(selected.itemId),'Recommend locally sold food')
context.inventory.counts[2287]=5
assert(A.Supplies.PreferredItem(context,food).itemId==2287,'Five owned preserves selected food')
context.inventory.available=false
assert(A.Supplies.PreferredItem(context,food).itemId==2287,'Unknown stock preserves selected food')
local saved=A.Supplies.PreferredItem({characterClass='Mage',supplyDefaults={recovery=2287}},food)
assert(saved.itemId==2287,'Keep explicit food choice')
map=1429
A.Data.SupplySoldBy[999]={999001,999002}
A.Data.SupplyVendors[999001]={name='Distant fixed',faction='A',movement='stationary',locations={[1429]={{90,90}}}}
A.Data.SupplyVendors[999002]={name='Closer fixed',faction='A',movement='stationary',locations={[1429]={{70,70}}}}
assert(V:FindVendor(999).name=='Closer fixed','Closest eligible seller, no zone distance limit')
print('PASS: every class, all vendor food families, drink access, Stormwind equivalents, saved defaults and zone-wide nearest vendors.')
''')
