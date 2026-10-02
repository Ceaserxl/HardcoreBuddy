"""Container-sized ammo targets and live ranged weapon transitions."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local M,S=A.Ammunition,A.Supplies
UnitClass=function() return 'Hunter','HUNTER' end
local bags={[1]={8,1},[2]={16,0}}
C_Container.GetContainerNumSlots=function(bag) return bags[bag] and bags[bag][1] or 0 end
C_Container.GetContainerNumFreeSlots=function(bag) return 0,bags[bag] and bags[bag][2] or 0 end
local weapon=1
GetInventoryItemID=function(_,slot) return slot==18 and weapon or nil end
C_Item.GetItemInfoInstant=function(id) return id,nil,nil,nil,nil,2,({[1]=2,[2]=3,[3]=18})[id] end
local c=A:GetContext(); c.mode='live'; c.characterClass='Hunter'; c.level=40; c.targets=A.characterDB.targets
A.characterDB.ammoCapacityTargets=nil
local arrows=M.Recommend(c)
assert(arrows.ammoKind=='arrows' and S.Record(c,arrows).target==1600,'Eight total quiver slots, not free slots or ordinary bag slots')
A:SetCarryTarget(arrows.itemId,1200)
bags[1]={16,1}; A.events.scripts.OnEvent(A.events,'PLAYER_EQUIPMENT_CHANGED',20)
assert(S.Record(c,arrows).target==3200,'Larger container raises target via equipment event')
bags[1]={6,1}; M.RefreshCapacity()
assert(S.Record(c,arrows).target==3200,'Smaller replacement does not reduce target')
A:SetCarryTarget(arrows.itemId,0); bags[1]={18,1}; M.RefreshCapacity()
assert(S.Record(c,arrows).target==0,'Disabled restocking stays disabled')
A:SetCarryTarget(arrows.itemId,nil)
assert(S.Record(c,arrows).target==3600,'Clearing manual target restores current automatic capacity')
bags[3]={12,2}; weapon=2
A.events.scripts.OnEvent(A.events,'PLAYER_EQUIPMENT_CHANGED',18)
local bullets=M.Recommend(c)
assert(bullets.ammoKind=='bullets' and bullets.itemId==11284 and S.Record(c,bullets).target==2400,'Gun selects bullets and ammo pouch target')
weapon=3; local crossbow=M.Recommend(c)
assert(crossbow.ammoKind=='arrows' and S.Record(c,crossbow).target==3600,'Crossbow restores arrow/quiver target')
c.level=52
assert(M.Recommend(c).itemId==18042 and S.Record(c,M.Recommend(c)).target==3600,'New ammo rank inherits container target')
c.mode='preview'; assert(S.Record(c,M.Recommend({mode='preview',characterClass='Hunter',previewAmmo='arrows',level=52})).target==1000,'Preview does not inherit live containers')
print('PASS: capacity defaults, larger/smaller containers, zero/manual targets, weapon swaps and new ammo ranks.')
''')
