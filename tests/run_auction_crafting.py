"""Global craft preference, recipe eligibility, shared materials and cached row purchases."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua, addon = boot()
for name in ('gear_advisor.lua', 'auction_upgrades.lua', 'auction_essentials_fixture.lua'):
    lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
lua.execute(r'''
local A,E,F=TestAddon,TestAddon.AuctionEssentials,ESSENTIAL_FIXTURE
F.stock={[900001]={name='A Food',target=5},[900002]={name='Z Bandages',target=4}}
A.Data.AuctionRecipes[900001]={spellId=1001,output=2,reagents={{900010,3,'Material A'}}}
A.Data.AuctionRecipes[900002]={spellId=1002,output=1,reagents={{900010,2,'Material A'},{900011,1,'Material B'}}}
local learned=true
C_SpellBook={IsSpellKnown=function(id) return learned and (id==1001 or id==1002) end}
C_Item.GetItemInfo=function(id) return id==900010 and 'Material A' or 'Material B' end
F.bags={[900010]=5,[900011]=4}; A.characterDB.auctionBank={counts={[900010]=2}}
F.auctions={
 [900001]={[0]={{count=5,price=1000}}}, [900002]={[0]={{count=4,price=10}}},
 [900010]={name='Material A',[0]={{count=2,price=20},{count=8,price=80}}},
 [900011]={name='Material B',[0]={{count=4,price=40}}},
}
E:Refresh()
assert(not E:PreferCraft() and #E.items==2 and E.rows[1].buy:IsShown(),'Craft preference defaults off; only finished rows shown')
E:Start(); F.finish(); local sent=#F.queries
assert(sent==4 and not E:PreferCraft(),'Prices never turn a manual preference on automatically')
E:SetPreferCraft(true); F.finish()
assert(#F.queries==sent and A.characterDB.auctionEssentialsPreferCraft,'Preference saved without rescanning')
assert(#E.items==4 and E.items[1].craftable and E.items[1].crafting)
assert(E.items[2].target==9 and E.items[2].missing==2,'Minimum recipe yield rounds number of crafts up')
assert(E.materialRecords[900010].target==17 and E.materialRecords[900010].missing==10,'Shared bag/bank materials allocated once')
assert(E.items[3].children[2].missing==0 and E.items[3].children[2].bagUsed==4,'Fully owned reagent hidden but retained in recipe')
assert(not E.rows[1].buy:IsShown() and E.rows[2].buy:IsShown() and E.rows[2].buy:IsEnabled(),'Craftable parents have no Buy; material rows have Buy')
assert(not E.rows[3].buy:IsShown(),'Preference applies even when the finished item is cheaper')
assert(E:CraftCost(E.items[1])==20)
local message
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) message=text end}
assert(E:CraftNotice():find('bags and bank',1,true) and message)
E:BuyRow(E.items[1]); assert(not E.batch and not E.confirmation,'Hidden parent button cannot buy through backend')
MOCK.Click(E.rows[2].buy); F.finish(); assert(E.confirmation.count==2 and #F.queries==sent+1)
F.accept(); F.ack(); F.finish()
assert(E:MailCount(900010)==2 and E.craftParents[1].readyToCraft,'Purchased materials fill first craft')
assert(#E.items==2 and E.items[1].itemId==900002 and E.items[2].missing==8,'Ready craft disappears while reserving its material stock')
assert(E.rows[2].buy:IsEnabled(),'Other recipe can use remaining saved offers without rescan')
MOCK.Click(E.rows[2].buy); F.finish(); F.accept(); F.ack(true); F.finish()
assert(#E.items==0 and E:MailCount(900010)==10,'Last reagent purchase removes completed parent and material rows')
E:SetPreferCraft(false); F.finish()
assert(#E.items==2 and E.rows[1].buy:IsShown() and E.rows[2].buy:IsShown(),'Unchecked preference restores finished-item buying')
learned=false; E:Refresh(); assert(not E.items[1].craftable and #E.items==2,'Unlearned recipes never marked craftable')
-- Cache a custom learned recipe, with its real minimum yield and reagent count.
GetNumTradeSkills=function() return 1 end
GetTradeSkillItemLink=function() return "item:900003:0" end
GetTradeSkillRecipeLink=function() return "enchant:1003" end
GetTradeSkillNumMade=function() return 3,4 end
GetTradeSkillNumReagents=function() return 1 end
GetTradeSkillReagentItemLink=function() return "item:900010:0" end
GetTradeSkillReagentInfo=function() return "Material",nil,2 end
E:CaptureRecipes()
assert(A.characterDB.auctionRecipes[900003].output==3 and A.characterDB.auctionRecipes[900003].reagents[1][2]==2)
E.bankOpen=true
C_Container.GetContainerNumSlots=function(bag) return bag==-1 and 2 or 0 end
C_Container.GetContainerItemInfo=function(_,slot) return {itemID=900010,stackCount=slot} end
local previous=A.characterDB.auctionBank
E.craftingEvents.scripts.OnEvent(nil,"BANKFRAME_OPENED")
assert(A.characterDB.auctionBank==previous and not E.bankDraft,"Opening bank does not cache contents")
E:CaptureBank(); assert(A.characterDB.auctionBank==previous,"Bank changes remain staged until close")
C_Container.GetContainerItemInfo=function(_,slot) return {itemID=900010,stackCount=slot+1} end
E.craftingEvents.scripts.OnEvent(nil,"BANKFRAME_CLOSED")
assert(A.characterDB.auctionBank.counts[900010]==5,"Closing bank persists final contents")
local persisted=A.characterDB.auctionBank
E.craftingEvents.scripts.OnEvent(nil,"BANKFRAME_OPENED")
C_Container.GetContainerNumSlots=function() return 0 end
E.craftingEvents.scripts.OnEvent(nil,"BANKFRAME_CLOSED")
assert(A.characterDB.auctionBank==persisted,"Unavailable bank API preserves saved snapshot")

learned=true
-- A reload uses the saved per-character choice, independent of transient UI state.
A.characterDB.auctionEssentialsPreferCraft=true
E:Refresh(); assert(E:PreferCraft() and E.preferCraft:GetChecked())
print('PASS: global craft preference, material-only purchases, recipe yields, shared stock, cached plans and bank persistence')
''')
