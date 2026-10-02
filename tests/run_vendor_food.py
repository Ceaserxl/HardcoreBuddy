"""Vendor foods across classes, local equivalents, and zone-wide sellers."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local P,V=A.Planner,A.VendorServices
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
local equivalent=V:FindSupplyVendor(2287)
assert(equivalent and equivalent.alternativeName and equivalent.map==1453,'Stormwind equivalent food seller')
local food
for _,row in ipairs(P.BuildList('Mage',5,'Alliance').rows) do if row.family=='recovery' then food=row end end
local selected=A.Supplies.PreferredItem({characterClass='Mage',supplyDefaults={}},food)
assert(selected.itemId~=2287 and V:FindVendor(selected.itemId),'Recommend locally sold food')
local saved=A.Supplies.PreferredItem({characterClass='Mage',supplyDefaults={recovery=2287}},food)
assert(saved.itemId==2287,'Keep explicit food choice')
map=1429
A.Data.SupplySoldBy[999]={999001,999002}
A.Data.SupplyVendors[999001]={name='Distant fixed',faction='A',movement='stationary',locations={[1429]={{90,90}}}}
A.Data.SupplyVendors[999002]={name='Closer fixed',faction='A',movement='stationary',locations={[1429]={{70,70}}}}
assert(V:FindVendor(999).name=='Closer fixed','Closest eligible seller, no zone distance limit')
print('PASS: every class, all vendor food families, drink access, Stormwind equivalents, saved defaults and zone-wide nearest vendors.')
''')
