local A = TestAddon
local S, I = A.Supplies, A.Inventory
local checked = 0
local function check(value, message) checked=checked+1; assert(value, message) end
local saved = {container=C_Container, bags=NUM_BAG_SLOTS, keyring=KEYRING_CONTAINER, enum=Enum}
local bagSlots, bagData, touched = {[0]=4,[1]=2,[2]=0,[3]=1,[4]=0,[-2]=1,[-1]=1,[5]=1}, {
    [0]={{itemID=858,stackCount=3}, {itemID=858,stackCount=2}, {itemID=159,stackCount=20}},
    [1]={{itemID=858,stackCount=4}, {itemID=1251,stackCount=6}},
    [3]={{itemID=2581,stackCount=8}}, [-2]={{itemID=12382,stackCount=1}},
    [-1]={{itemID=858,stackCount=100}}, [5]={{itemID=858,stackCount=100}},
}, {}
C_Container = {
    GetContainerNumSlots=function(bag) touched[bag]=true; return bagSlots[bag] or 0 end,
    GetContainerItemInfo=function(bag,slot) return bagData[bag] and bagData[bag][slot] end,
}
NUM_BAG_SLOTS, KEYRING_CONTAINER = 4, -2
local inventory=I.Read()
check(inventory.available and inventory.counts[858]==9, "Aggregate split stacks across carried bags")
check(inventory.counts[12382]==1, "Include the Classic keyring")
check(not touched[-1] and not touched[5], "Never read bank containers")
check(inventory.counts[1251]==6 and inventory.counts[2581]==8, "Keep profession rank itemIDs separate")
bagData[0][4]={itemID=99999}
check(not I.Read().available, "An incomplete item result must not become a missing supply")
bagData[0][4]=nil
C_Container.GetContainerItemInfo=function() error("temporarily unavailable") end
check(not I.Read().available, "API errors produce unknown inventory")
C_Container=nil
check(not I.Read().available, "Missing bag API produces unknown inventory")
C_Container, NUM_BAG_SLOTS, KEYRING_CONTAINER, Enum = saved.container, saved.bags, saved.keyring, saved.enum

local context={characterClass="Mage", level=32, inventory=inventory, targets={}}
local function find(rows, family)
    for _, row in ipairs(rows) do if row.family==family then return row end end
end
local rows=S.Build(context)
local healing, mana, food, gem=find(rows,"healing"),find(rows,"mana"),find(rows,"recovery"),find(rows,"managem")
check(healing.category=="Potions" and mana.category=="Potions", "Healing and mana potions have their own category")
check(healing.target==5 and food.target==20 and gem.target==1, "Default carry targets distinguish stackable and conjured supplies")
check(healing.count==0 and healing.status=="missing" and healing.missing==5, "Count the exact recommended potion rank")
local bandages={}
for _,row in ipairs(rows) do if row.groupFamily=="bandage" then bandages[row.itemId]=row end end
check(bandages[1251].count==6 and bandages[2581].count==8, "Separate profession ranks retain their real counts")
check(bandages[1251].name=="Linen Bandage" and bandages[2581].name=="Heavy Linen Bandage", "No generic rank label tied to a concrete itemID")
context.inventory.counts[healing.itemId]=2
context.inventory.counts[mana.itemId]=5
rows=S.Build(context)
check(find(rows,"healing").status=="low" and find(rows,"healing").missing==3, "Partial stock reports the remaining quantity")
check(find(rows,"mana").status=="ready" and find(rows,"mana").owned, "Enough carried stock reports ready")
local missing=S.Build(context,{stock="Missing"})
check(find(missing,"healing") and not find(missing,"mana"), "Missing includes low stock and excludes ready stock")
context.targets[tostring(healing.itemId)]=12
check(find(S.Build(context),"healing").target==12, "Saved string-key overrides are accepted")
context.targets[healing.itemId]=0
local ignored=find(S.Build(context),"healing")
check(ignored.target==0 and ignored.missing==0 and ignored.status=="ready" and not ignored.tracking, "A zero target opts out of restocking")
check(not find(S.Build(context,{stock="Missing"}),"healing"), "Opted-out supplies are absent from restock view")
check(S.NormalizeTarget(999)==200 and S.NormalizeTarget(-10)==0 and S.NormalizeTarget(7.8)==7,
    "Quantity inputs are bounded whole numbers")
check(S.NormalizeTarget("oops")==nil and S.NormalizeTarget(math.huge)==nil and S.NormalizeTarget(0/0)==nil,
    "Invalid quantities cannot poison saved targets")
context.inventory={available=false,counts={}}
local unknown=find(S.Build(context),"mana")
check(unknown.count==nil and unknown.status=="unknown" and unknown.missing==nil and not unknown.available,
    "Unknown bags are not shown as zero carried")
check(#S.Build(context,{stock="Missing"})==0, "Unknown bags do not create false missing-item claims")
local buffs=S.Build(context,{category="Buffs"})
check(not find(buffs,"healing") and not find(buffs,"mana") and #buffs>0, "Potion categories remain correct when filtered")
local searched=S.Build(context,{category="Potions",query="healing potion"})
check(#searched==1 and searched[1].family=="healing", "Supply search combines category and all query terms")
local preview={characterClass="Hunter",level=12,mode="preview",inventory={available=true,counts={}},targets={}}
local inspected=find(S.Build(preview),"healing").item
preview.inventory.counts[inspected.itemId]=3
preview.targets[inspected.itemId]=9
preview.level=21
check(find(S.Build(preview),"healing").itemId~=inspected.itemId, "Preview level changes the current potion recommendation")
local detail=S.Record(preview,inspected)
check(detail.itemId==inspected.itemId and detail.count==3 and detail.target==9 and detail.missing==6 and detail.status=="low",
    "An inspected item retains exact stock and its custom target after preview level changes")
local bandageDetail=S.Record(preview,bandages[2581].item)
check(bandageDetail.groupFamily=="bandage" and bandageDetail.quantityNote=="Requires First Aid 20",
    "Single-item details retain profession rank requirements")
-- Restore the planner before asserting the synthetic duplicate test.
local build=A.Planner.BuildList
local duplicate={itemId=17056,id="same",name="Light Feather",family="feather",group="Emergency supplies"}
A.Planner.BuildList=function() return {rows={duplicate},specialist={},backups={duplicate},advanced={duplicate}} end
local duplicateOK, duplicateResult=pcall(S.Build,{characterClass="Mage",level=32,inventory={available=true,counts={[17056]=7}}},{filter="Class"})
A.Planner.BuildList=build
check(duplicateOK and #duplicateResult==1 and duplicateResult[1].count==7,
    "Duplicate source records do not duplicate item quantities or restock targets")
print("PASS: "..checked.." supply and inventory checks cover carried stacks, bank exclusion, unknown state, targets, rank counts and emergency potions.")
