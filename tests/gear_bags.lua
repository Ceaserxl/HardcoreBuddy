local A=TestAddon
local B,G=A.GearBagAdvisor,A.GearAdvisor
local now,combat,cursor=100,false,false
local items,bags,equipment,messages,equips={},{},{},{},{}
GetTime=function() return now end
InCombatLockdown=function() return combat end
GetCursorInfo=function() return cursor and "item" end
UnitIsDeadOrGhost=function() return false end
UnitOnTaxi=function() return false end
GetInventoryItemLink=function(_,slot) return equipment[slot] end
GetInventoryItemID=function(_,slot) local i=items[equipment[slot]]; return i and i.id end
local function item(id,value,equip,binding)
    local link="item:"..id
    items[link]={id=id,name=link,link=link,required=1,equip=equip or "INVTYPE_HEAD",classID=4,subclassID=1,
        stats={ITEM_MOD_AGILITY_SHORT=value},spellEffectsComplete=true,binding=binding or 0}
    return link
end
G.Read=function(_,link) return items[link] end
local profile=G.Profile("HUNTER",41,1)
G.CurrentProfile=function() return profile end
C_Item.GetItemInfo=function(link)
    local i=items[link]
    if i then return i.name,link,2,40,1,"Armor","Cloth",1,i.equip,1,1,i.classID,i.subclassID,i.binding end
end
C_Container={
    GetContainerNumSlots=function(bag) return bag==0 and #bags or 0 end,
    GetContainerItemLink=function(bag,slot) return bag==0 and bags[slot] and bags[slot].link end,
    GetContainerItemInfo=function(bag,slot) return {isLocked=bags[slot].locked or false} end,
    GetContainerItemQuestInfo=function(bag,slot) return {isQuestItem=bags[slot].quest or false,questID=bags[slot].questID} end,
}
local fail=false
C_Item.EquipItemByName=function(link,slot)
    equips[#equips+1]={link=link,slot=slot}
    if fail then return end
    for _,bag in ipairs(bags) do if bag.link==link then
        bag.link=equipment[slot]; equipment[slot]=link
        if items[link].equip=="INVTYPE_2HWEAPON" then equipment[17]=nil end
        G.revision=G.revision+1
        B.worker.scripts.OnEvent(B.worker,"PLAYER_EQUIPMENT_CHANGED",slot)
        return
    end end
end
A.Print=function(_,message) messages[#messages+1]=message end
local function drain()
    for _=1,30 do
        now=now+1
        local update=B.worker:GetScript("OnUpdate")
        if not update then return end
        update(B.worker)
    end
end
local function scan() B:Queue(); drain() end
local old=item(100,1); local upgrade=item(101,20); local better=item(102,30)
equipment[1]=old; bags={{link=upgrade},{link=better}}
assert(not A.db.gearBagNotify and not A.db.gearAutoEquip)
scan(); assert(#messages==0 and #equips==0)
A.db.gearBagNotify=true; B:Changed(); drain(); assert(#messages==2 and #equips==0)
scan(); assert(#messages==2,"Repeated updates do not repeat notices")
A.db.gearAutoEquip=true; scan()
assert(#equips==1 and equipment[1]==better,"Equip best candidate, then rescore remaining bags")
scan(); assert(#equips==1,"Never oscillate into the replaced item")

-- Wearing a quest item is the protection requirement, not just bag flags.
equipment[1]=old; items[old].binding=4; bags={{link=better}}; equips={}
B:Changed(); drain(); assert(#equips==0 and equipment[1]==old,"Do not replace worn quest gear")
items[old].binding=nil; scan(); assert(#equips==0,"Unknown equipped quest status is protected")
items[old].binding=0; bags[1].quest=true; scan(); assert(#equips==0)
bags[1].quest=false; bags[1].questID=123; scan(); assert(#equips==0)
bags[1].questID=nil; bags[1].locked=true; scan(); assert(#equips==0)
bags[1].locked=false; combat=true; scan(); assert(#equips==0)
combat=false; cursor=true; scan(); assert(#equips==0)
cursor=false; B.worker.scripts.OnEvent(B.worker,"PLAYER_REGEN_ENABLED"); drain()
assert(equipment[1]==better and #equips==1)

-- A two-hander must not remove a quest off-hand, even if its score wins.
local main=item(110,2,"INVTYPE_WEAPONMAINHAND")
local off=item(111,2,"INVTYPE_HOLDABLE",4)
local two=item(112,100,"INVTYPE_2HWEAPON")
items[main].classID=2; items[main].subclassID=7; items[main].dps=10
items[two].classID=2; items[two].subclassID=10; items[two].dps=10
equipment={[16]=main,[17]=off}; bags={{link=two}}; equips={}
B:Changed(); drain(); assert(#equips==0 and equipment[17]==off)
items[off].binding=0; scan(); assert(#equips==1 and equipment[16]==two)

local questRing=item(120,1,"INVTYPE_FINGER",4)
local ordinaryRing=item(121,2,"INVTYPE_FINGER")
local newRing=item(122,20,"INVTYPE_FINGER")
equipment={[11]=questRing,[12]=ordinaryRing}; bags={{link=newRing}}; equips={}
B:Changed(); drain()
assert(#equips==1 and equips[1].slot==12 and equipment[11]==questRing,"Use the unprotected ring slot")

-- A failed equip is attempted once until the equipment changes or options reset.
equipment={[1]=old}; bags={{link=better}}; equips={}; fail=true
B:Changed(); drain(); scan(); scan(); assert(#equips==1)
fail=false; A.db.gearAdvisorActive=false; B:Changed(); drain(); assert(#equips==1)
A.db.gearAdvisorActive=true; A.db.gearAutoEquip=false
B:Changed(); drain(); assert(#equips==1,"Notification-only never equips")

-- Revalidate the exact bag link after a multi-frame scan.
A.db.gearAutoEquip=true; equips={}
bags={{link=better},{link=old},{link=old},{link=old},{link=old}}
B:Changed(); now=now+1; B:Step()
bags[1].link=old; drain(); assert(#equips==0,"A stale candidate cannot equip")

A:OpenSettings("Gear Advisor")
local page=A.Settings.pages["Gear Advisor"]
assert(page.notify:IsVisible() and page.autoEquip:IsVisible())
page.autoEquip:SetChecked(false); MOCK.Click(page.autoEquip)
assert(not A.db.gearAutoEquip)
page.notify:SetChecked(false); MOCK.Click(page.notify)
assert(not A.db.gearBagNotify and not B.worker:GetScript("OnUpdate"))
print("PASS: opt-in controls, deduplicated notices, best upgrades, worn quest gear, both hands, rings, combat/cursor/locks, master disable and stale candidates.")
