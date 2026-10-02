"""Independent low-stock triggers and full refill targets."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local S,R,V=A.Supplies,A.Readiness,A.VendorServices
local item={itemId=117,name='Tough Jerky',family='recovery',group='Food & drink'}
local c={characterClass='Hunter',targets={[117]=20},refillThresholds={},inventory={available=true,counts={[117]=19}}}
local build=S.Build
S.Build=function(context) return {S.Record(context,item)} end
assert(#R:Missing(c)==0,'19/20 does not notify')
c.inventory.counts[117]=6; assert(#R:Missing(c)==0,'Above refill amount does not notify')
c.inventory.counts[117]=5; assert(#R:Missing(c)==1,'Exactly five triggers restocking')
c.inventory.counts[117]=4; assert(#R:Missing(c)==1 and R:Missing(c)[1].missing==16,'Four triggers full target shortfall')
c.refillThresholds[117]=3; assert(#R:Missing(c)==0,'Per-item threshold applies')
c.inventory.counts[117]=2; assert(#R:Missing(c)==1)
c.refillThresholds[117]=0; c.inventory.counts[117]=0; assert(#R:Missing(c)==0,'Zero disables restocking even when empty')
c.inventory.available=false; assert(#R:Missing(c)==0,'Unknown quantity is not low stock')
local ammo={itemId=2512,name='Arrows',family='ammunition',ammoKind='arrows',group='Class'}
c.inventory.available=true; c.inventory.counts[2512]=200
assert(S.Record(c,ammo).refillNeeded,'Ammo triggers at exactly 200')
c.inventory.counts[2512]=201; assert(not S.Record(c,ammo).refillNeeded)
c.inventory.counts[2512]=199
assert(S.Record(c,ammo).refillNeeded and S.Record(c,ammo).target==1000,'Ammo uses separate 200/1000 defaults')
S.Build=build
A:SetCarryTarget(117,20); A:SetRefillThreshold(117,5)
local context=A:GetContext(); assert(context.targets[117]==20 and context.refillThresholds[117]==5)
A:Activate({kind='item',item=A.Data.Items.items[1]})
local editor=A.window.cards[1].detailQuantity
assert(editor and editor.refill and editor.refill:GetText()=='5','Both controls are exposed in item details')
editor.refill:SetText('3'); editor.refill.scripts.OnEditFocusLost(editor.refill)
assert(A.characterDB.refillThresholds[117]==3,'Threshold editor saves separately')
local custom={itemId=999999,id='user-999999',name='Custom supply',family='user-999999',group='User',classes={'All'},userItem=true,level=1,ease=0}
A.characterDB.userItems[#A.characterDB.userItems+1]=custom
A:Activate({kind='item',item=custom})
editor=A.window.cards[1].detailQuantity
assert(editor:IsShown() and editor.refill:IsShown(),'User-added items expose both controls')
A:SetCarryTarget(custom.itemId,20); A:SetRefillThreshold(custom.itemId,5)
local userContext=A:GetContext(); userContext.inventory={available=true,counts={[custom.itemId]=5}}
local userRecord=S.Record(userContext,custom)
assert(userRecord.refillNeeded and userRecord.target==20,'User items use the same threshold and target')
userContext.priorities={}
local function missingCustom()
 for _,record in ipairs(R:Missing(userContext)) do if record.itemId==custom.itemId then return true end end
end
assert(not missingCustom(),'Optional custom items do not trigger reminders')
userContext.priorities[custom.family]='Essentials'
assert(missingCustom(),'Custom items marked Essentials do trigger reminders')

-- Every restockable built-in item uses the same inclusive boundary.
for _,supply in ipairs(A.Data.Items.items) do
 if supply.itemId and supply.itemId~=5816 then
  local context={characterClass='Hunter',targets={[supply.itemId]=20},refillThresholds={[supply.itemId]=5},inventory={available=true,counts={[supply.itemId]=5}}}
  assert(S.Record(context,supply).refillNeeded,'Inclusive boundary for '..supply.name)
  context.inventory.counts[supply.itemId]=6
  assert(not S.Record(context,supply).refillNeeded,'Above boundary for '..supply.name)
  context.inventory.counts[supply.itemId]=20; context.refillThresholds[supply.itemId]=20
  assert(not S.Record(context,supply).refillNeeded,'Full stock does not need refill for '..supply.name)
 end
end

-- A refill must keep buying after its first stack passes the trigger threshold.
local count,now=0,100
InCombatLockdown=function() return false end
GetTime=function() return now end
GetMoney=function() return 100000 end
A.Inventory.Read=function() return {available=true,counts={[117]=count}} end
R.LiveContext=function() return {inventory=A.Inventory.Read(),targets={[117]=60},refillThresholds={[117]=5}} end
S.Build=function(context) return {S.Record(context,item)} end
V.Stock=function() return {{id=117,name='Food',index=1,price=5,bundle=5,available=-1,purchasable=true}} end
V.LearnVendor=function() end
V.Capacity=function() return 200 end
GetMerchantItemMaxStack=function() return 20 end
local purchases=0
BuyMerchantItem=function(_,quantity) count=count+quantity; purchases=purchases+1 end
assert(not V.settings.autoBuy,'Automatic buying remains opt-in')
V.open=true; V:Buy(false)
for i=1,10 do now=now+1; V:Tick() end
assert(count==60 and purchases==3 and not V.running,'Crossing threshold does not interrupt full refill')
count=19; assert(#V:Plan()==0,'Next visit does not buy above threshold')
count=5; assert(#V:Plan()==1,'Vendor purchase plan triggers at exactly refill amount')
print('PASS: low-stock boundaries, per-item controls, ammo defaults, unknown counts and full multi-stack refills.')
''')
