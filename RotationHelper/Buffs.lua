-- Shared preparation and Classic buff conflicts. No class combat policy here.
local _,A=...
local H=A.RotationHelper
local D=A.Data.ConsumableBuffs
local B={}; H.Buffs=B; A.ConsumableBuffs=B
local names={WARRIOR="Warrior",PALADIN="Paladin",HUNTER="Hunter",ROGUE="Rogue",PRIEST="Priest",
    SHAMAN="Shaman",MAGE="Mage",WARLOCK="Warlock",DRUID="Druid"}
local manaFood={MAGE=true,PRIEST=true,WARLOCK=true}
local order={"intellect","stamina","spirit","strength","agility","armor","health","trollsblood","food"}
local items={}
for _,catalog in ipairs({A.Data.Items.items,A.Data.Scrolls.items}) do
    for _,item in ipairs(catalog) do if D.items[item.itemId] then items[#items+1]=item end end
end

function B:Module(class)
    if not names[class] then return end
    return {name=names[class],suppliesOnly=true,spells=D.classSpells[class] or {},rules={},auras={}}
end
function B:Invalidate() self.carried=nil end
function B:IsEating(c)
    for id in pairs(c.auras.player) do if D.eating[id] then return true end end
end
function B:Used(id,t)
    local groups={}
    local aura=D.auras[id]
    if aura then
        if aura.group then groups[aura.group]=true end
        for group in pairs(aura.effects or {}) do groups[group]=true end
    end
    for _,meta in pairs(D.items) do if meta.eating==id then groups[meta.group]=true end end
    for group in pairs(groups) do H.recent["buff:"..group]=t end
end
local function itemCooldown(id,t)
    local get=C_Container and C_Container.GetItemCooldown or GetItemCooldown
    if not get then return 0 end
    local start,duration,enabled=get(id)
    if enabled==0 or enabled==false then return math.huge end
    return math.max(0,(start or 0)+(duration or 0)-t)
end
local function power(c,meta,id,aura)
    local value=meta.power
    if meta.group=="food" then
        local preferred=manaFood[c.class] and "manafood" or "wellfed"
        return value+(meta.foodType==preferred and 1000 or 0)
    end
    -- Modern aura data can include the actual value after talents.
    local actual=aura and aura.points and tonumber(aura.points[1])
    if actual and actual>0 then return actual end
    if meta.group=="stamina" and c.class=="PRIEST" and (not aura or aura.sourceUnit=="player")
        and (id==1243 or id==1244 or id==1245 or id==2791 or id==10937 or id==10938) then
        value=value*(1+0.15*(c.talents.improvedPowerWordFortitude or 0))
    end
    return value
end
local function remaining(c,aura)
    local expires=aura.expirationTime
    if not expires or expires==0 then return math.huge end
    return math.max(0,expires-c.now)
end
local function due(c,candidate)
    for id,aura in pairs(c.auras.player) do
        local meta=D.auras[id]
        local amount=meta and (meta.group==candidate.group and power(c,meta,id,aura) or meta.effects and meta.effects[candidate.group])
        local left=remaining(c,aura)
        if amount and left>0 then
            -- Never advertise a downgrade, even when the stronger buff expires soon.
            if meta.keep or amount>candidate.power or amount==candidate.power and left>300 then return false end
        end
    end
    return true
end
local function better(a,b)
    if not b or a.power~=b.power then return not b or a.power>b.power end
    if a.kind~=b.kind then return a.kind=="spell" end -- Save consumables on equal strength.
    return a.id<b.id
end

function B:Add(c)
    local best={}
    local function consider(key,s,meta)
        local candidate={key=key,id=s.id,kind=s.kind,group=meta.group,power=power(c,meta,s.id)}
        if better(candidate,best[candidate.group]) then best[candidate.group]=candidate end
    end
    for key in pairs(D.classSpells[c.class] or {}) do
        local s=c.spells[key]
        if s and s.known and D.auras[s.id] then consider(key,s,D.auras[s.id]) end
    end
    if self.class~=c.class or self.level~=c.level then
        self:Invalidate(); self.class=c.class; self.level=c.level
    end
    local carried=self.carried
    if not carried then
        carried={}
        local inventory=A.Inventory.Read()
        local counts=inventory.counts or {}
        for _,item in ipairs(items) do
            if (counts[item.itemId] or 0)>0 and item.level<=c.level
                and A.Planner.MatchesClass(item,names[c.class]) then carried[#carried+1]=item end
        end
        if inventory.available then self.carried=carried end
    end
    for _,item in ipairs(carried) do
        local id=item.itemId
        local meta=D.items[id]
        local key="buffItem:"..id
        local used=H.recent["buff:"..meta.group]
        local s={id=id,known=true,kind="item",cost=0,range=true,cooldown=itemCooldown(id,c.now),
            blocked=used and c.now-used<1.5 or false}
        c.spells[key]=s
        consider(key,s,meta)
    end
    c.buffRules={}
    for _,group in ipairs(order) do
        local candidate=best[group]
        if candidate and due(c,candidate) then
            local used=H.recent["buff:"..group]
            local ready=not used or c.now-used>=1.5
            c.buffRules[#c.buffRules+1]={spell=candidate.key,category="preparation",group="buff:"..group,
                when=function(view)
                    return ready and not view.combat and not view.recovering
                        and "Apply or refresh your strongest available "..group.." buff"
                end}
            if group=="food" and ready and not c.combat and not c.recovering and not c.preparationBlocked
                and H.Eligible(c,candidate.key,true) then c.buffFoodPending=true end
        end
    end
end
