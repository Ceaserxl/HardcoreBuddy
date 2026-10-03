-- Shared recovery items; no class-specific consumable logic in the engine.
local _,A=...
local H=A.RotationHelper
local families={recovery="food",drink="water"}
-- Conjured recovery items aren't stock recommendations in the supply catalog.
local conjured={
    {itemId=5349,level=1,family="recovery"},{itemId=1113,level=5,family="recovery"},
    {itemId=1114,level=15,family="recovery"},{itemId=1487,level=25,family="recovery"},
    {itemId=8075,level=35,family="recovery"},{itemId=8076,level=45,family="recovery"},
    {itemId=22895,level=55,family="recovery"},
    {itemId=5350,level=1,family="drink"},{itemId=2288,level=5,family="drink"},
    {itemId=2136,level=15,family="drink"},{itemId=3772,level=25,family="drink"},
    {itemId=8077,level=35,family="drink"},{itemId=8078,level=45,family="drink"},{itemId=8079,level=55,family="drink"},
}
function H:AddSupplies(c)
    if not self.supplyItems then
        local counts=A.Inventory.Read().counts or {}
        local selected={}
        local function consider(item)
            local key=families[item.family]
            if key and (counts[item.itemId] or 0)>0 and item.level<=UnitLevel("player")
                and (not selected[key] or item.level>selected[key].level) then selected[key]=item end
        end
        for _,item in ipairs(A.Data.Items.items) do consider(item) end
        for _,item in ipairs(conjured) do consider(item) end
        self.supplyItems=selected
    end
    for _,key in ipairs({"food","water"}) do
        local item=self.supplyItems[key]
        local cd=item and self.PreparationItemCooldown(item.itemId,c) or 0
        c.spells[key]={known=item~=nil,id=item and item.itemId,kind="item",cost=0,cooldown=cd,range=true}
    end
end
H.sharedRules={
    {spell="food",category="preparation",when=function(c)
        return not c.combat and H.PreparationAllowed(c,"food") and not c.cast and not c.buffFoodPending and c.health<0.85 and "Recover health before pulling"
    end},
    {spell="water",category="preparation",when=function(c)
        return not c.combat and H.PreparationAllowed(c,"water") and not c.cast and c.powerType==0 and c.mana<0.65 and "Recover mana before pulling"
    end},
}
