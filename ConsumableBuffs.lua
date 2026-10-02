-- Shared Classic Era consumable preparation. No class rotation is required.
local _,A=...
local B={}; A.ConsumableBuffs=B
B.classes={WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",
    PRIEST="Priest",SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"}
B.manaClasses={PALADIN=true,HUNTER=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
function B.RefreshDue(left) return type(left)=="number" and left<=300 end
local function info(id)
    if C_Spell and C_Spell.GetSpellInfo then local value=C_Spell.GetSpellInfo(id); if value then return value end end
    if GetSpellInfo then local name=GetSpellInfo(id); if name then return {name=name} end end
end
function B.IsDrinking(active)
    -- Classic drink ranks share a localized aura name. This also recognizes
    -- water that is not currently selected in the Supplies profile.
    local drink=info(1135)
    return not not (drink and drink.name and (active[drink.name] or 0)>0)
end
function B.Auras(unit,filter)
    local out,durations={},{}
    local now=GetTime and GetTime() or 0
    for i=1,40 do
        local a
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then a=C_UnitAuras.GetAuraDataByIndex(unit,i,filter)
        elseif UnitAura then
            local name,_,_,_,duration,expires=UnitAura(unit,i,filter)
            if name then a={name=name,duration=duration,expirationTime=expires} end
        end
        if not a then break end
        if a.name then
            local left=a.expirationTime and a.expirationTime>0 and math.max(0,a.expirationTime-now) or math.huge
            if left>0 and left>=(out[a.name] or 0) then out[a.name]=left; durations[a.name]=a.duration end
        end
    end
    return out,durations
end
-- Build class-filtered supply choices periodically; ownership and auras stay live.
function B:Recommend(s,readAuras,cache)
    local result={}
    cache=cache or self
    self.checks={}
    local class=self.classes[s.class]
    if not class then return result end
    if s.combat or s.dead or s.taxi or ((s.buffs or {}).iceblock or 0)>0 or s.channelKey then return result end
    local count=C_Item and C_Item.GetItemCount or GetItemCount
    local itemSpell=C_Item and C_Item.GetItemSpell or GetItemSpell
    local itemInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
    local usable=C_Item and C_Item.IsUsableItem or IsUsableItem
    local cd=C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if not count or not itemSpell or not itemInfo or not usable or not cd then return result end
    if cache.supplyClass~=class or cache.supplyLevel~=s.level or not cache.supplyAdviceAt or s.time>=cache.supplyAdviceAt then
        local context=A:GetContext()
        context.characterClass=class; context.level=s.level; context.mode="live"
        cache.supplyClass=class; cache.supplyLevel=s.level
        cache.supplyAdviceRows=A.Supplies.Build(context); cache.supplyAdviceAt=s.time+5
    end
    local active,durations=(readAuras or self.Auras)("player","HELPFUL")
    durations=durations or {}
    -- Food's use spell is the eating effect, not the lasting nourishment buff.
    -- Resolve Classic buff names through the client for non-English locales.
    local foodBuffRemaining,foodBuffDuration=0,nil
    for _,id in ipairs({19705,18194}) do -- Well Fed; Nightfin's Mana Regeneration.
        local buff=info(id)
        if buff and (active[buff.name] or 0)>=foodBuffRemaining then
            foodBuffRemaining=active[buff.name] or 0; foodBuffDuration=durations[buff.name]
        end
    end
    local intellectActive=false
    for _,id in ipairs({1459,23028}) do
        local buff=info(id)
        if buff and (active[buff.name] or 0)>0 then intellectActive=true end
    end
    local manaPercent=s.powerPercent or 100
    if s.powerType and s.powerType~=0 and UnitPower and UnitPowerMax then
        local maximum=UnitPowerMax("player",0)
        if type(maximum)=="number" and maximum>0 then manaPercent=100*(UnitPower("player",0) or 0)/maximum end
    end
    local best={}
    for _,row in ipairs(cache.supplyAdviceRows or {}) do
        local id=row.itemId; local item=row.item or {}; local family=row.family
        local recovery=family=="recovery" or family=="drink"
        local buffFood=family=="wellfed" or family=="manafood"
        local timed=row.category=="Elixirs" or row.category=="Scrolls"
        local owned=id and (recovery or timed or buffFood) and (count(id,false,false) or 0) or 0
        local classAllowed=not item.classes or A.Planner.MatchesClass(item,class)
        if family=="drink" or family=="manafood" or family=="scroll-intellect" then classAllowed=classAllowed and self.manaClasses[s.class] end
        if id and classAllowed and (recovery or timed or buffFood) then
            self.checks[id]={tracking=not not row.tracking,owned=owned,family=family}
        end
        if classAllowed and row.tracking and (recovery or timed or buffFood) and owned>0 then
            local name,spellID=itemSpell(id)
            local start,duration,enabled=cd(id)
            local left=name and active[name] or 0
            local isUsable=usable(id)
            local check=self.checks[id]
            check.name=name; check.spellID=spellID; check.usable=not not isUsable
            check.cooldownStart=start; check.cooldownDuration=duration; check.enabled=enabled
            check.auraRemaining=left; check.buffRemaining=buffFood and foodBuffRemaining or left
            local allowed=name and spellID and isUsable and enabled~=0 and enabled~=false
                and type(start)=="number" and type(duration)=="number" and start+duration<=s.time
            if buffFood then
                allowed=allowed and left==0 and self.RefreshDue(foodBuffRemaining,foodBuffDuration)
            elseif recovery then
                allowed=allowed and left==0 and (family=="recovery" and (s.playerHealth or 100)<90 or family=="drink" and manaPercent<90)
            else
                local detail=item.detail or ""
                local minutes=tonumber(detail:match("for (%d+) min"))
                local hours=tonumber(detail:match("for (%d+) hour")) or tonumber(detail:match("for (%d+) hr"))
                allowed=allowed and self.RefreshDue(left,durations[name]) and (row.category=="Scrolls" or (minutes or 0)>=5 or (hours or 0)>=1)
                -- Intellect scrolls are redundant with the Mage's class buff.
                if family=="scroll-intellect" and (intellectActive or ((s.buffs or {}).intellect or 0)>0 or (s.spells or {}).intellect) then allowed=false end
            end
            check.eligible=not not allowed
            if allowed then
                local itemName,_,_,_,_,_,_,_,_,icon=itemInfo(id)
                check.itemInfoAvailable=itemName~=nil
                local group=buffFood and "food-buff" or family or id
                local priority=buffFood and row.priority=="Essentials" and 1 or 0
                local old=best[group]
                if itemName and (not old or priority>old.priority or priority==old.priority and (item.level or 0)>old.level) then
                    best[group]={id=id,item=true,name=itemName,icon=icon,level=item.level or 0,priority=priority,
                        category="preparation",
                        reason=recovery and "Recover before the next fight." or "Refresh the tracked consumable buff."}
                end
            end
        end
    end
    for _,action in pairs(best) do result[#result+1]=action end
    table.sort(result,function(a,b) return a.id<b.id end)
    return result
end
