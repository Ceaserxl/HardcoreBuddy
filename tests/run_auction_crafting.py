"""Learned recipes, yields, stock allocation, mutually exclusive choices and price plans."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT
lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text())
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text())
lua.execute('''
local A=TestAddon; local E=A.AuctionEssentials
local refresh=E.Refresh
local records={
 {itemId=900001,name="A Food",item={itemId=900001},missing=5,count=0,target=5,tracking=true},
 {itemId=900002,name="Z Bandages",item={itemId=900002},missing=4,count=0,target=4,tracking=true}}
A.Supplies.Build=function() return records end
A.Data.AuctionRecipes[900001]={spellId=1001,output=2,reagents={{900010,3}}}
A.Data.AuctionRecipes[900002]={spellId=1002,output=1,reagents={{900010,2},{900011,1}}}
local learned=true
C_SpellBook={IsSpellKnown=function(id) return learned and (id==1001 or id==1002) end}
C_Item.GetItemInfo=function(id) return "Material "..id end
local ctx={inventory={available=true,counts={[900010]=5,[900011]=4}}}
A.characterDB.auctionBank={counts={[900010]=2}}
A.GetContext=function() return ctx end
E.Refresh=function(self) self.items=self:Items(ctx) end
E:Refresh()
assert(not E.items[1].crafting and not E.selected[900001] and not E.selected[900010],"Craft and Buy default off")
E.craftChoices[900001]=true; E.craftChoices[900002]=true; E:Refresh()
assert(#E.items==4 and E.items[1].craftable and E.items[1].crafting)
assert(not E.selected[900001] and not E.selected[900002] and E.selected[900010])
assert(E.items[2].target==9 and E.items[2].missing==2,"Round crafts up for two-item output")
assert(E.materialRecords[900010].target==17 and E.materialRecords[900010].missing==10,"Shared bag/bank stock is deducted once")
assert(E.items[3].children[2].missing==0 and E.items[3].children[2].bagUsed==4 and not E.selected[900011],"Fully owned materials stay in the recipe but are hidden from refill rows")
E:Toggle(E.items[1])
assert(E.selected[900001] and not E.craftChoices[900001] and E.selected[900010],"Buy clears Craft but keeps other recipe's shared material")
assert(E.materialRecords[900010].missing==1)
E:Toggle(E.items[3])
assert(E.selected[900002] and not E.selected[900010],"No selected crafts leaves materials unchecked")
E:ToggleCraft(E.items[1]); assert(E.craftChoices[900001] and not E.selected[900001] and E.selected[900010])
E.results[900010]={offers={{count=2,buyout=20}},plans={[2]={need=2,units=2,cost=20,ceiling=50}}}
E.results[900002]={plans={[4]={need=4,units=4,cost=70,ceiling=100}}}
assert(E:CraftCost(E.items[1])==20)
local cost,units,need,unknown=E:Estimate()
assert(cost==90 and units==6 and need==6 and not unknown,"Basket uses net reagent cost plus selected finished item")
local queue=E:ScanItems(); local seen={}
for _,r in ipairs(queue) do assert(not seen[r.itemId]); seen[r.itemId]=true end
assert(seen[900001] and seen[900010] and seen[900011],"Scan finished and material prices once per item, including hidden stock shared between recipes")
local message
DEFAULT_CHAT_FRAME={AddMessage=function(_,text) message=text end}
assert(E:CraftNotice():find("bags and bank",1,true) and message,"Partial stock combination notice")
learned=false; E:Refresh(); assert(not E.items[1].craftable and #E.items==2,"Unlearned recipes never marked craftable")
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
learned=true; E.Refresh=refresh; E:Attach(); E.open=true
A.characterDB.auctionBank={counts={[900010]=2}}
E.craftChoices={[900001]=true,[900002]=true}; E.materialOverrides={}; E:Refresh()
assert(E.rows[1].cells[1]:GetText():find("|cff62d79b(Craftable)|r",1,true),"Green inline Craftable label")
assert(E.rows[1].craft:GetChecked() and not E.rows[1].buy:GetChecked(),"Craft checked, finished Buy unchecked")
assert(not E.rows[5]:IsShown() and not E.selected[900011],"Covered materials are hidden and remain unchecked")
MOCK.Click(E.rows[1])
assert(not E.rows[1].craft:GetChecked() and E.rows[1].buy:GetChecked() and not E.rows[2].buy:GetChecked(),"Row click switches finished item to Buy and clears its material row")
ctx.inventory.counts[900010]=0; A.characterDB.auctionBank.counts[900010]=9
E:ToggleCraft(E.items[1])
assert(E.craftParents[1].children[1].bankUsed==9 and E.craftParents[1].readyToCraft,"Bank fully covers required amount")
assert(E.rows[1].record.itemId==900002,"Fulfilled craft and material rows are both omitted")
assert(E.materialRecords[900010].missing==8,"Hidden craft still reserves shared materials for itself")
E.craftChoices={}; E.craftManual={}; E.selected={}; E.materialOverrides={}
ctx.inventory.counts[900010]=0; A.characterDB.auctionBank.counts[900010]=0
E.results={
 [900001]={offers={{count=5,buyout=1000}}},
 [900002]={offers={{count=4,buyout=1}}},
 [900010]={offers={{count=20,buyout=100}}},
}
local co=coroutine.create(function() E:SelectCheaperCrafts() end)
repeat local ok,err=coroutine.resume(co); assert(ok,err) until coroutine.status(co)=='dead'
assert(E.craftChoices[900001] and not E.craftChoices[900002],"Auto craft only when strictly cheaper")
assert(not E.selected[900001] and not E.selected[900002] and E.selected[900010],"Only chosen crafting materials auto select Buy")
E:ToggleCraft(E.items[1]); assert(not E.selected[900001],"Unchecking Craft leaves Buy off")
co=coroutine.create(function() E:SelectCheaperCrafts() end)
repeat local ok,err=coroutine.resume(co); assert(ok,err) until coroutine.status(co)=='dead'
assert(not E.craftChoices[900001],"Manual opt-out survives price comparison")
E.craftManual={}; E.craftChoices={}; E.selected={}
E.results[900001]={offers={{count=5,buyout=100}}}
co=coroutine.create(function() E:SelectCheaperCrafts() end)
repeat local ok,err=coroutine.resume(co); assert(ok,err) until coroutine.status(co)=='dead'
assert(not E.craftChoices[900001],"Equal costs do not auto select craft")
E.results[900001]={offers={{count=5,buyout=1000}}}; E.results[900010]=nil
co=coroutine.create(function() E:SelectCheaperCrafts() end)
repeat local ok,err=coroutine.resume(co); assert(ok,err) until coroutine.status(co)=='dead'
assert(not E.craftChoices[900001],"Missing material prices do not auto select craft")

print("PASS: recipe eligibility/cache, output rounding, shared stock, bank capture, linked selections, cost comparison and scan deduplication")
''')
