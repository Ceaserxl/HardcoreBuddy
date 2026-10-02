"""Merchant purchase and repair boundaries in a full addon runtime."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local V=A.VendorServices
assert(A.characterDB.auctionHighestArmorOnly==true)
assert(not V.settings.autoBuy and not V.settings.autoRepair)
local now,cash,count,stock,free,combat=100,1000,0,-1,2,false
local buys,repairs=0,0
GetTime=function() return now end
InCombatLockdown=function() return combat end
GetMoney=function() return cash end
A.Inventory.Read=function() return {available=true,counts={[117]=count}} end
A.Readiness.LiveContext=function() return {inventory=A.Inventory.Read()} end
A.Readiness.Missing=function() return count<12 and {{itemId=117,missing=12-count}} or {} end
C_Container.GetContainerNumFreeSlots=function(bag) return bag==0 and free or 0,0 end
C_Container.GetContainerNumSlots=function() return 0 end
GetMerchantNumItems=function() return 1 end
GetMerchantItemLink=function() return 'item:117' end
local extended=false
GetMerchantItemInfo=function() return 'Food',1,50,5,stock,true,true,extended end
GetMerchantItemMaxStack=function() return 20 end
BuyMerchantItem=function(i,q) assert(i==1 and q%5==0 and q<=12-count); buys=buys+1; count=count+q; cash=cash-q*10 end
CanMerchantRepair=function() return true end
GetRepairAllCost=function() return 100,true end
RepairAllItems=function(guild) assert(guild==false); repairs=repairs+1; cash=cash-100 end
local function event(e) V.events.scripts.OnEvent(V.events,e) end
local function tick() now=now+1; V:Tick() end
event('MERCHANT_SHOW'); tick()
assert(V.prompt:IsShown() and buys==0 and repairs==0)
assert(V.prompt.items:GetText():find('Food x 10',1,true))
MOCK.Click(V.prompt.cancel); tick(); assert(buys==0 and not V.prompt:IsShown())
event('MERCHANT_CLOSED'); event('MERCHANT_SHOW'); tick()
V.prompt.auto:SetChecked(true); MOCK.Click(V.prompt.buy)
tick(); tick(); tick()
assert(buys==1 and count==10 and V.settings.autoBuy and not V.running,'No overshoot for bundle of five')
count=0; event('MERCHANT_CLOSED'); event('MERCHANT_SHOW'); tick(); tick(); tick(); tick()
assert(buys==2 and count==10)
local receipt=false; for _,s in ipairs(MOCK.messages) do if s:find('Auto bought 10 x Food',1,true) then receipt=true end end
assert(receipt,'Automatic purchases announced')
count=0; cash=40; assert(#V:Plan()==0,'Insufficient money')
cash=1000; free=0; assert(#V:Plan()==0,'Full bags')
free=2; stock=3; assert(#V:Plan()==0,'Limited stock below bundle')
stock=5; assert(V:Plan()[1].quantity==5)
stock=-1; extended=true; assert(#V:Plan()==0,'No special currency'); extended=false
V.settings.autoRepair=true; event('MERCHANT_SHOW'); assert(repairs==1 and cash==900)
event('MERCHANT_UPDATE'); tick(); assert(repairs==1)
event('MERCHANT_CLOSED'); tick(); assert(not V.running and not V.pending)
cash=50; event('MERCHANT_SHOW'); assert(repairs==1)
cash=1000; combat=true; event('MERCHANT_SHOW'); tick(); assert(repairs==1 and not V.running)
combat=false; V.open=true; V.decided=nil; V:Buy(true)
BuyMerchantItem=function() buys=buys+1 end
local before=buys; tick(); now=now+4; V:Tick(); tick()
assert(buys==before+1 and not V.running,'Unconfirmed purchase stops without repeated spending')
C_Map=C_Map or {}; C_Map.GetBestMapForUnit=function() return 1453 end
C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .5,.5 end} end
A.Data.SupplySoldBy[117]={999001,999002}
A.Data.SupplyVendors[999001]={name='Friendly',faction='A',locations={[1453]={{51,50}}}}
A.Data.SupplyVendors[999002]={name='Hostile',faction='H',locations={[1453]={{50,50}}}}
assert(V:FindVendor(117).name=='Friendly')
local driver
RegisterStateDriver=function(frame,kind,value) assert(kind=="visibility"); driver=value end
A.Readiness:ShowPanel({{itemId=117,name="Food",count=0,target=12}})
local row=A.Readiness.panel.rows[1]
assert(row:GetAttribute("type")=="macro" and row:GetAttribute("macrotext")=="/targetexact Friendly")
assert(driver=="[combat] hide; show")
row.scripts.OnEnter(row); assert(GameTooltip:IsShown()); row.scripts.OnLeave(row)
MOCK.Click(A.Readiness.panel.close); assert(driver=="hide")
A.characterDB.auctionHighestArmorOnly=false; A.characterDB.debugAutoReload=true
A:Initialize()
assert(A.characterDB.auctionHighestArmorOnly==false and A.characterDB.debugAutoReload==true)

C_Map.GetBestMapForUnit=function() return 1429 end
assert(not V:FindVendor(117),'No cross-zone vendors')
UnitName=function() return 'Stock test vendor' end
UnitGUID=function() return 'Creature-0-0-0-0-999003-0' end
V:LearnVendor({{id=999100,available=-1,purchasable=true},{id=999101,available=1,purchasable=true},
 {id=999102,available=0,purchasable=true},{id=999103,available=-1,purchasable=false}})
assert(V:UnlimitedSource('item:999100')=='Stock test vendor')
for _,id in ipairs({999101,999102,999103}) do assert(not V:UnlimitedSource('item:'..id),'Limited, sold-out and restricted stock must not block AH') end
V:LearnVendor({{id=999100,available=2,purchasable=true}})
assert(not V:UnlimitedSource('item:999100'),'New finite stock removes previous unlimited evidence')
print('PASS: prompt consent, opt-in automation, receipts, stock/bundle/money/bag limits, repair, interruption and vendor faction/location.')
''')

