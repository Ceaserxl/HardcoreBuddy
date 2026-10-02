-- Ammunition tiers verified against Classic item tooltips; crafting is acquisition, not a use requirement.
local _, A = ...
local M = {}; A.Ammunition = M
local tiers = {
    arrows={{2512,1,"Rough Arrow",1.5},{2515,10,"Sharp Arrow",3.5},{3030,25,"Razor Arrow",7.5},{11285,40,"Jagged Arrow",13},{18042,52,"Thorium Headed Arrow",17.5}},
    bullets={{2516,1,"Light Shot",1.5},{8067,5,"Crafted Light Shot",2},{2519,10,"Heavy Shot",3.5},
        {8068,15,"Crafted Heavy Shot",4.5},{3033,25,"Solid Shot",7.5},{8069,30,"Crafted Solid Shot",8.5},
        {10512,37,"Hi-Impact Mithril Slugs",12.5},{11284,40,"Accurate Slugs",13},
        {10513,44,"Mithril Gyro-Shot",15},{15997,52,"Thorium Shells",17.5}},
    thrown={{2947,1,"Small Throwing Knife"},{2946,3,"Balanced Throwing Dagger"},{3107,11,"Keen Throwing Knife"},{3108,22,"Heavy Throwing Dagger"},{15327,35,"Wicked Throwing Dagger"}},
}
local icons={[2512]="inv_ammo_arrow_02",[2515]="inv_ammo_arrow_02",[3030]="inv_ammo_arrow_02",[11285]="inv_weapon_shortblade_25",
    [18042]="inv_ammo_arrow_02",[8067]="inv_ammo_bullet_02",[8068]="inv_ammo_bullet_02",[8069]="inv_ammo_bullet_02",
    [10512]="inv_ammo_bullet_01",[10513]="inv_ammo_bullet_01",[15997]="inv_ammo_bullet_03",
    [2516]="inv_ammo_bullet_02",[2519]="inv_ammo_bullet_02",[3033]="inv_ammo_bullet_02",[11284]="inv_ammo_bullet_01",
    [2947]="inv_throwingknife_02",[2946]="inv_weapon_shortblade_05",[3107]="inv_throwingknife_01",[3108]="inv_throwingknife_03",[15327]="inv_throwingknife_03"}
M.items = {}
local crafted={[8067]="Rough Blasting Powder, Copper Bar",[8068]="Coarse Blasting Powder, Copper Bar",
    [8069]="Heavy Blasting Powder, Bronze Bar",[10512]="Mithril Bar, Solid Blasting Powder",
    [10513]="2 Mithril Bars, 2 Solid Blasting Powder",[15997]="2 Thorium Bars, Dense Blasting Powder"}
for kind, entries in pairs(tiers) do
    for _, entry in ipairs(entries) do
        local item={itemId=entry[1],id="ammo-"..entry[1],level=entry[2],name=entry[3],icon=icons[entry[1]]..".jpg",
            family="ammunition",ammoKind=kind,ammoDPS=entry[4],group="Class",classes={"Hunter","Warrior","Rogue"},ease=1,
            short=kind=="thrown" and "Thrown weapon supply" or "Ammunition for your ranged weapon",
            route="Buy from a weapons or ammunition vendor. Match the ammunition to your equipped ranged weapon."}
        if item.ammoDPS then item.short="+"..item.ammoDPS.." ranged DPS"; item.detail=item.short end
        if crafted[item.itemId] then
            item.ingredients=crafted[item.itemId]
            item.route="Craft with Engineering or obtain from another engineer where trading is allowed. Produces 200 rounds."
        elseif item.itemId==18042 then
            item.ingredients="200 Thorium Shells"
            item.route="Exchange 200 Thorium Shells for 200 arrows with Artilleryman Sheldonore in Ironforge or Bounty Hunter Kolark in Orgrimmar. Shells are made by engineers."
        end
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
                local base=M.items[equipped] or pick
                local copy={}; for key,value in pairs(base) do copy[key]=value end
                copy.itemId,copy.id,copy.name,copy.level,copy.icon=equipped,"ammo-"..equipped,name,math.max(1,level),icon
                if not M.items[equipped] then
                    copy.ammoDPS=nil; copy.ingredients=nil
                    copy.short="Currently equipped ammunition"; copy.detail=nil
                    copy.route="Currently equipped. Check the item's tooltip for its source."
                end
                pick=copy; M.items[equipped]=copy
            end
        end
    end
    local result={}; for key,value in pairs(pick) do result[key]=value end
    result.options={}
    for _,entry in ipairs(tiers[kind]) do
        if entry[2]<=context.level and entry[1]~=pick.itemId then result.options[#result.options+1]=entry.item end
    end
    table.sort(result.options,function(a,b) return (a.ammoDPS or a.level)>(b.ammoDPS or b.level) end)
    return result
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
