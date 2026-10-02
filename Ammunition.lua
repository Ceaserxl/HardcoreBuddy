-- Vendor ammunition tiers verified against Classic item tooltips.
local _, A = ...
local M = {}; A.Ammunition = M
local tiers = {
    arrows={{2512,1,"Rough Arrow"},{2515,10,"Sharp Arrow"},{3030,25,"Razor Arrow"},{11285,40,"Jagged Arrow"}},
    bullets={{2516,1,"Light Shot"},{2519,10,"Heavy Shot"},{3033,25,"Solid Shot"},{11284,40,"Accurate Slugs"}},
    thrown={{2947,1,"Small Throwing Knife"},{2946,3,"Balanced Throwing Dagger"},{3107,11,"Keen Throwing Knife"},{3108,22,"Heavy Throwing Dagger"},{15327,35,"Wicked Throwing Dagger"}},
}
local icons={[2512]="inv_ammo_arrow_02",[2515]="inv_ammo_arrow_02",[3030]="inv_ammo_arrow_02",[11285]="inv_weapon_shortblade_25",
    [2516]="inv_ammo_bullet_02",[2519]="inv_ammo_bullet_02",[3033]="inv_ammo_bullet_02",[11284]="inv_ammo_bullet_01",
    [2947]="inv_throwingknife_02",[2946]="inv_weapon_shortblade_05",[3107]="inv_throwingknife_01",[3108]="inv_throwingknife_03",[15327]="inv_throwingknife_03"}
M.items = {}
for kind, entries in pairs(tiers) do
    for _, entry in ipairs(entries) do
        local item={itemId=entry[1],id="ammo-"..entry[1],level=entry[2],name=entry[3],icon=icons[entry[1]]..".jpg",
            family="ammunition",ammoKind=kind,group="Class",classes={"Hunter","Warrior","Rogue"},ease=1,
            short=kind=="thrown" and "Thrown weapon supply" or "Ammunition for your ranged weapon",
            route="Buy from a weapons or ammunition vendor. Match the ammunition to your equipped ranged weapon."}
        M.items[item.itemId]=item; entry.item=item
    end
end
function M.Kind()
    if not GetInventoryItemID then return nil end
    local id=GetInventoryItemID("player",18)
    local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
    if not id or not instant then return nil end
    local _,_,_,_,_,classID,subclassID=instant(id)
    if classID~=2 then return nil end
    return (subclassID==2 or subclassID==18) and "arrows" or subclassID==3 and "bullets" or subclassID==16 and "thrown" or nil
end
function M.Recommend(context)
    if context.characterClass~="Hunter" and context.characterClass~="Warrior" and context.characterClass~="Rogue" then return nil end
    -- Preview weapon choices must not inherit the real character's equipment.
    local kind=context.mode=="preview" and context.previewAmmo or M.Kind()
    if not tiers[kind] then return nil end
    local pick
    for _,entry in ipairs(tiers[kind]) do if entry[2]<=context.level then pick=entry.item end end
    if context.mode~="preview" and GetInventoryItemID then
        local equipped=GetInventoryItemID("player",kind=="thrown" and 18 or 0)
        if equipped and equipped>0 then
            local instant=C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
            local _,_,_,_,_,classID,subclassID
            if instant then _,_,_,_,_,classID,subclassID=instant(equipped) end
            if not classID then return nil end
            local compatible=kind=="thrown" and classID==2 and subclassID==16
                or kind=="arrows" and classID==6 and subclassID==2
                or kind=="bullets" and classID==6 and subclassID==3
            local info=C_Item and C_Item.GetItemInfo or GetItemInfo
            local name,level,icon
            if info then name,_,_,_,level,_,_,_,_,icon=info(equipped) end
            if compatible and not name then return nil end -- Wait for item cache, not a guessed shortage.
            -- Equipped low-rank ammo must not suppress a newly usable vendor tier.
            if compatible and name and type(level)=="number" and level<=context.level and level>=pick.level then
                local copy={}; for key,value in pairs(pick) do copy[key]=value end
                copy.itemId,copy.id,copy.name,copy.level,copy.icon=equipped,"ammo-"..equipped,name,math.max(1,level),icon
                copy.route="Currently equipped. Check the item's tooltip or a weapons/ammunition vendor for replacements."
                pick=copy; M.items[equipped]=copy
            end
        end
    end
    return pick
end
function M.Count(context,item)
    local inventory=context.inventory or {}
    if not inventory.available then return nil end
    local count=(inventory.counts or {})[item.itemId] or 0
    -- Selected arrows/bullets still live in bags. Only thrown weapons move to
    -- the ranged slot, so add that stack once rather than counting ammo twice.
    if context.mode~="preview" and item.ammoKind=="thrown" and GetInventoryItemID
        and GetInventoryItemID("player",18)==item.itemId then
        if not GetInventoryItemCount then return nil end
        local equipped=GetInventoryItemCount("player",18)
        if type(equipped)~="number" or equipped<0 then return nil end
        count=count+equipped
    end
    return count
end
