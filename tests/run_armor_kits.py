"""Real gear-link inspection and kit advice; character and item levels stay separate."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua, addon = boot()
lua.execute('''
local A=TestAddon
local K=A.ArmorKits
local gear,levels={},{}
local function equip(slot,itemLevel,enchant)
    gear[slot]={id=100000+slot,enchant=enchant or 0}
    levels[100000+slot]=itemLevel
end
local slots={5,7,10,8}
GetInventoryItemID=function(unit,slot) assert(unit=="player"); return gear[slot] and gear[slot].id end
GetInventoryItemLink=function(unit,slot)
    assert(unit=="player")
    local g=gear[slot]
    if not g or g.uncached then return nil end
    return g.link or ("|cffffffff|Hitem:"..g.id..":"..g.enchant..":0:0:0:0:0:0:1|h[Localized armor]|h|r")
end
C_Item.GetItemInfo=function(link)
    local id=type(link)=="string" and tonumber(link:match("item:(%d+)")) or link
    -- Actual item level is the fourth result. Character use level is deliberately different.
    return "Armor",link,2,levels[id],1
end
local function recommendations(level)
    return K.Recommendations({mode="live",level=level,characterClass="Mage"})
end
local checks=0
local function check(ok,message) checks=checks+1; assert(ok,message) end
check(#A.Data.ArmorKits.items==6,"Classic catalog")
for level=1,60 do
    for itemLevel=1,65 do
        equip(5,itemLevel,0)
        local rows=recommendations(level)
        check(#rows==1 and rows[1].level<=level and rows[1].gearLevel<=itemLevel,"Separate use and gear gates")
        for _,other in ipairs(A.Data.ArmorKits.items) do
            check(other.defenseKit or other.level>level or other.gearLevel>itemLevel or other.power<=rows[1].power,"Strongest compatible armor kit")
        end
    end
end
check(K.Best(19,60).itemId==2313 and K.Best(20,14).itemId==2313,"Heavy requirements")
check(K.Best(20,15).itemId==4265,"Heavy threshold")
check(K.Best(30,24).itemId==4265 and K.Best(30,25).itemId==8173,"Thick item level")
check(K.Best(40,34).itemId==8173 and K.Best(40,35).itemId==15564,"Rugged item level")
gear={}
for _,slot in ipairs(slots) do
    for _,kit in ipairs(A.Data.ArmorKits.items) do
        equip(slot,60,kit.enchantId)
        local rows=recommendations(60)
        check(#rows==((kit.defenseKit or kit.power==40) and 0 or 1),"Existing kit detection")
        if kit.defenseKit or kit.power==40 then check(#rows==0,"Keep current/defense kits") end
        gear={}
    end
end
equip(5,40,16); equip(7,27,0); equip(10,40,1843); equip(8,40,911)
local rows,scan=recommendations(40)
check(#rows==2 and scan.upgrades==1 and scan.empty==1 and scan.enchanted==1,"Mixed equipped armor")
check(rows[1].itemId==15564 and rows[1].recommendedTarget==1 and rows[1].kitTargets:find("Medium Armor Kit",1,true),"Identify old kit")
check(rows[2].itemId==8173 and rows[2].kitTargets:find("item level 27",1,true),"Lower-level armor gets a compatible kit")
gear[5].uncached=true; levels[gear[7].id]=nil
rows,scan=recommendations(40)
check(#rows==0 and scan.unknown==2,"Unknown links or gear level must not look unenhanced")
gear[5].uncached=nil; levels[gear[7].id]=27
gear[5].link="item:100005:invalid:0:0"; rows,scan=recommendations(40)
check(#rows==1 and scan.unknown==1,"Malformed enchant is unknown")
gear[5].link="item:999999:0:0:0"; rows,scan=recommendations(40)
check(scan.unknown==1,"Stale cached link cannot describe a newly equipped item")
gear={}; rows,scan=recommendations(40)
check(#rows==0 and scan.equipped==0 and scan.unknown==0,"Empty gear slots")
for _,slot in ipairs(slots) do equip(slot,40,0) end
local context={mode="live",level=40,characterClass="Mage",inventory={available=true,counts={[15564]=2}},targets={}}
rows=A.Supplies.Build(context,{filter="Enchants"})
local kit
for _,r in ipairs(rows) do if r.item.armorKit then kit=r end end
check(kit.itemId==15564 and kit.target==4 and kit.count==2 and kit.missing==2,"One kit per needy piece, exact bag count")
context.inventory.available=false
check(A.Supplies.Record(context,kit.item).count==nil,"Unknown bag stock")
context.targets[15564]=7
check(A.Supplies.Record(context,kit.item).target==7,"Carry override")
context.mode="preview"; context.level=20
local read=GetInventoryItemID
GetInventoryItemID=function() error("Planning must not inspect live gear") end
rows=K.Recommendations(context)
check(#rows==1 and rows[1].itemId==4265 and rows[1].kitTargets:find("Planning only",1,true),"Preview isolation")
GetInventoryItemID=read
local craft=A.Crafting.GetInfo(rows[1],context)
check(craft.craftingText:find("Leatherworking 150",1,true) and craft.recipeSource:find("trainer",1,true),"Crafting facts")
check(K.Best(0/0,40)==nil,"Invalid input does not select a kit")

-- Applying an armor kit or enchant updates both the list and an open detail.
MOCK.level=40; A.db.profile.mode="live"
A:Navigate("supplies"); A.state.filter="Enchants"; A:Refresh()
local function listed()
    for _,card in ipairs(A.document.cards) do for _,block in ipairs(card.blocks) do
        if block.action and block.action.item and block.action.item.armorKit then return block end
    end end
end
local block=listed(); check(block~=nil,"Enchants lists kit recommendations")
A:Activate(block.action)
check(A.document.cards[1].blocks[1].target==4,"Detail shows automatic quantity")
for _,slot in ipairs(slots) do equip(slot,40,1843) end
MOCK.Fire("UNIT_INVENTORY_CHANGED","player")
check(A.document.cards[1].blocks[1].target==0,"Applied kits clear stale detail target")
A:Back(); check(listed()==nil,"Applied kits disappear from recommendations")
equip(5,40,15); MOCK.Fire("PLAYER_EQUIPMENT_CHANGED",5)
check(listed() and listed().target==1,"Newly equipped older kit is detected")
equip(5,40,911); MOCK.Fire("UNIT_INVENTORY_CHANGED","player")
check(listed()==nil,"Unrelated enchant removes recommendation")
for _,slot in ipairs(slots) do equip(slot,40,2503) end
MOCK.Fire("UNIT_INVENTORY_CHANGED","player")
check(listed()==nil,"Core kits remain intact")
equip(5,40,16); equip(7,27,0)
MOCK.Fire("UNIT_INVENTORY_CHANGED","player")
local core=A.Data.ArmorKits.items[6]
check(core.enchantId==2503 and core.defenseKit and core.power==3,"Core is defense, not a stronger armor kit")
print("PASS: "..checks.." armor-kit checks: all slots, character/item levels, existing enhancements, unknown data, stock, preview, crafting and live refresh.")
''')
if '--render' in sys.argv:
    composite(lua.globals().MOCK.frames, addon.window).save(ROOT / 'docs/layout-previews/armor-kit-upgrades.png')
