-- The only game-state adapter. Classes consume facts; they never query WoW.
local _,A=...
local H=A.RotationHelper
H.state={}; H.recent={}; H.immunities={}
local function now() return GetTime() end
local function info(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local s=C_Spell.GetSpellInfo(id)
        if s then return s.name,s.iconID,s.castTime end
    elseif GetSpellInfo then
        local name,_,icon,cast=GetSpellInfo(id); return name,icon,cast
    end
end
H.SpellInfo=info
local function known(id)
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    return IsSpellKnown and IsSpellKnown(id) or false
end
local function count(id)
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id,false,false) or 0 end
    return GetItemCount and GetItemCount(id,false,false) or 0
end
local function cooldown(id,item,t)
    if not id or id==0 then return 0,0,0 end
    local start,duration,enabled
    if item then
        local f=(C_Container and C_Container.GetItemCooldown) or GetItemCooldown
        if f then start,duration,enabled=f(id) end
    elseif C_Spell and C_Spell.GetSpellCooldown then
        local cd=C_Spell.GetSpellCooldown(id)
        if cd then start,duration,enabled=cd.startTime,cd.duration,cd.isEnabled end
    elseif GetSpellCooldown then start,duration,enabled=GetSpellCooldown(id) end
    if enabled==0 or enabled==false then return math.huge,0,0 end
    return math.max(0,(start or 0)+(duration or 0)-t),start or 0,duration or 0
end
local function cost(id,powerType)
    local f=C_Spell and C_Spell.GetSpellPowerCost or GetSpellPowerCost
    local costs=f and f(id)
    local value=0
    for _,v in ipairs(costs or {}) do
        if v.type==powerType and (not v.requiredAuraID or v.requiredAuraID==0 or v.hasRequiredAura) then value=math.max(value,v.cost or 0) end
    end
    return value
end
local function cast(unit,t)
    local name,_,_,start,finish,_,token,notInterruptible,id
    if UnitCastingInfo then name,_,_,start,finish,_,token,notInterruptible,id=UnitCastingInfo(unit) end
    local channel
    if not name and UnitChannelInfo then
        name,_,_,start,finish,_,notInterruptible,id=UnitChannelInfo(unit); channel=not not name
    end
    if name and start and finish then return {id=id,name=name,apiID=token,
        token=token~=nil and "cast:"..tostring(token) or "time:"..tostring(id or name)..":"..start,
        guid=type(token)=="string" and token or nil,start=start/1000,finish=finish/1000,
        remaining=math.max(0,finish/1000-t),channel=channel,interruptible=not notInterruptible} end
end
function H:PlayerCast()
    local current=cast("player",now())
    local previous=self.lastCast
    if current and previous and current.id==previous.id and current.channel==previous.channel then
        local sameID=current.apiID~=nil and current.apiID==previous.apiID
        -- Channels and clients without an API cast ID use the START-event GUID
        -- while the observed cast intervals overlap. A new START overrides it.
        local sameInterval=current.apiID==nil and previous.apiID==nil and previous.guid
            and current.start<previous.finish and current.finish>previous.start
        if sameID or sameInterval then
            current.guid=current.guid or previous.guid
            current.token=previous.token
        end
    end
    return current
end
local function matchesCast(value,guid,id)
    return value and value.id==id and (not guid or value.guid and value.guid==guid)
end
function H:CastEvent(event,guid,id)
    local current=self:PlayerCast()
    if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_CHANNEL_START" then
        if current and current.id==id and (type(current.apiID)~="string" or current.apiID==guid) then
            current.guid=guid
            if guid then current.token="cast:"..guid end
            self.lastCast=current
        end
        return
    end
    -- A successful instant can consume the held next action after the previous
    -- cast has ended. It has no casting API entry to match against lastCast.
    if event=="UNIT_SPELLCAST_SUCCEEDED" and not current and self.state.lock
        and self.state.lock.id==id and not matchesCast(self.lastCast,guid,id) then self.state={} end
    -- Never match a failed extra press by spell alone.
    local ended=current or self.lastCast
    if not matchesCast(ended,guid,id) then return end
    self.finishedCast={token=ended.token,interrupted=event~="UNIT_SPELLCAST_SUCCEEDED"}
    if self.finishedCast.interrupted then self.state={} end
end
local function auraList(unit,filter)
    local result={}
    for i=1,40 do
        local aura
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then aura=C_UnitAuras.GetAuraDataByIndex(unit,i,filter)
        elseif UnitAura then
            local name,icon,stacks,dispel,duration,expiration,source,_,_,id=UnitAura(unit,i,filter)
            if name then aura={name=name,icon=icon,applications=stacks,dispelName=dispel,duration=duration,expirationTime=expiration,sourceUnit=source,spellId=id} end
        end
        if not aura then break end
        result[#result+1]=aura
    end
    return result
end
-- Breakable control only; roots deliberately do not suppress ranged attacks.
local controls={118,12824,12825,12826,28271,28272,6770,2070,11297,1776,1777,8629,11285,11286,
    19386,24132,24133,9484,9485,10955,3355,14308,14309,710,18647,2637,18657,18658,2094,
    5782,6213,6215,8122,8124,10888,10890,5484,17928,5246,1513,14326,14327,6358,19503}
local controlled={}; for _,id in ipairs(controls) do controlled[id]=true end
local function hasControl(list)
    for _,a in ipairs(list) do if controlled[a.spellId] then return true end end
    return false
end

function H:Rebuild(preservePlan)
    local _,class=UnitClass("player"); self.module=self.classes[class]
    self.definitions={}; self.byID={}; self.talents={}; self.treePoints={0,0,0}
    if not preservePlan then self.state={} end
    if not self.module then return end
    if self.Glow and A.characterDB and A.characterDB.rotationHelperEnabled then self.Glow:Discover() end
    local catalog=A.Data.ClassSpells[self.module.name] or {}
    for key,def in pairs(self.module.spells) do
        local ranks={}
        if def.ranks then for _,id in ipairs(def.ranks) do ranks[#ranks+1]=id end
        elseif def.root then
            ranks[1]=def.root
            local included={[def.root]=true}
            for level=1,60 do for _,entry in ipairs(catalog[level] or {}) do
                if not included[entry.id] then
                    for _,parent in ipairs(entry.requiredIds or {}) do
                        if included[parent] then ranks[#ranks+1]=entry.id; included[entry.id]=true; break end
                    end
                end
            end end
        end
        local selected,barRank
        for index,id in ipairs(ranks) do
            self.byID[id]=key
            if known(id) then
                selected=index
                if def.lowest and not barRank and self.Glow and self.Glow:HasSpell(id) then barRank=index end
            end
        end
        selected=barRank or selected
        self.definitions[key]={def=def,ranks=ranks,id=selected and ranks[selected],index=selected}
    end
    if A.TalentAdvisor then
        local read=A.TalentAdvisor:ReadCurrent(class,UnitLevel("player"))
        self.talents=read and read.ranks or {}
    end
    for key,rank in pairs(self.talents) do
        local talent=A.Data.AdvisorTalents[class] and A.Data.AdvisorTalents[class][key]
        if talent then self.treePoints[talent.tree]=self.treePoints[talent.tree]+rank end
    end
end

local C={}
function C:remaining(group,unit)
    local best=0
    for _,id in ipairs(self.module.auras[group] or {}) do
        local a=self.auras[unit or "player"][id]
        if a then best=math.max(best,a.expirationTime==0 and math.huge or math.max(0,(a.expirationTime or 0)-self.now)) end
    end
    return best
end
function C:stacks(group,unit)
    local n=0
    for _,id in ipairs(self.module.auras[group] or {}) do
        local a=self.auras[unit or "player"][id]; if a then n=math.max(n,a.applications or 0) end
    end
    return n
end
function C:strength(group)
    local value=0
    for id,strength in pairs(self.module.strengths and self.module.strengths[group] or {}) do
        if self.auras.player[id] then value=math.max(value,strength) end
    end
    return value
end

function H:Snapshot()
    if not self.module then return end
    local t=now()
    local c=setmetatable({now=t,module=self.module,spells={},immune={},auras={player={},target={}},talents=self.talents,treePoints=self.treePoints},{__index=C})
    c.dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") or false
    c.taxi=UnitOnTaxi and UnitOnTaxi("player") or false
    c.combat=UnitAffectingCombat and UnitAffectingCombat("player") or false
    c.grouped=IsInGroup and IsInGroup() or false
    c.health=UnitHealth("player")/math.max(1,UnitHealthMax("player"))
    c.powerType=UnitPowerType and UnitPowerType("player") or 0
    c.power=UnitPower and UnitPower("player",c.powerType) or 0
    c.maxPower=UnitPowerMax and UnitPowerMax("player",c.powerType) or 0
    c.powerFraction=c.power/math.max(1,c.maxPower)
    c.mana=(UnitPower and UnitPower("player",0) or 0)/math.max(1,UnitPowerMax and UnitPowerMax("player",0) or 0)
    c.cast=self:PlayerCast()
    if c.cast then
        self.lastCast=c.cast
        if self.finishedCast and self.finishedCast.token==c.cast.token then
            if self.finishedCast.interrupted then c.cast=nil
            else c.cast.paid=true end
        end
    end
    c.casting=c.cast and self.byID[c.cast.id]
    local gcd,gcdStart,gcdDuration=cooldown(61304,false,t)
    c.actionDelay=math.max(c.cast and c.cast.remaining or 0,gcd==math.huge and 0 or gcd)
    local pending=c.cast and not c.cast.paid and not c.cast.channel and c.cast.id and cost(c.cast.id,c.powerType) or 0
    local regen=0
    if c.powerType==0 and GetManaRegen then local _; _,regen=GetManaRegen()
    elseif c.powerType~=0 and GetPowerRegen then regen=GetPowerRegen() end
    -- Only guaranteed casting regeneration, after reserving this cast's cost.
    local available=math.max(0,c.power-pending)
    c.nextPower=math.min(c.maxPower,available+(regen or 0)*c.actionDelay)
    c.futurePower=math.min(c.maxPower,available+(regen or 0)*math.max(self.lead,c.actionDelay))
    c.targetGUID=UnitGUID and UnitGUID("target")
    c.hostile=c.targetGUID and UnitCanAttack and UnitCanAttack("player","target")
        and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("target")) and not (UnitIsPlayer and UnitIsPlayer("target"))
        and not (UnitIsTapDenied and UnitIsTapDenied("target")) or false
    c.targetCombat=c.hostile and UnitAffectingCombat and UnitAffectingCombat("target") or false
    c.targetHealth=c.hostile and UnitHealth("target")/math.max(1,UnitHealthMax("target")) or 1
    local classification=c.hostile and UnitClassification and UnitClassification("target")
    c.tough=classification=="elite" or classification=="rareelite" or classification=="worldboss"
    c.targetAttacking=c.hostile and c.targetCombat and UnitIsUnit and UnitIsUnit("targettarget","player") or false
    c.attacked=c.targetAttacking
    c.targetCast=c.hostile and cast("target",t)
    local harmful=auraList("player","HARMFUL")
    for _,a in ipairs(harmful) do
        if a.dispelName=="Curse" then c.cursed=true end
        if a.spellId then c.auras.player[a.spellId]=a end
    end
    for _,unit in ipairs({"player","target"}) do
        local list=auraList(unit,unit=="player" and "HELPFUL" or "HARMFUL")
        if unit=="target" then c.controlled=hasControl(list) end
        for _,a in ipairs(list) do if a.spellId then c.auras[unit][a.spellId]=a end end
    end
    for _,id in ipairs(self.module.pauseAuras or {}) do if c.auras.player[id] then c.paused=true end end
    local foodName=info(433); local drinkName=info(430)
    for _,a in pairs(c.auras.player) do if a.name==foodName or a.name==drinkName then c.recovering=true end end
    for _,id in ipairs(self.module.recoveryChannels or {}) do
        if c.cast and c.cast.channel and c.cast.id==id then c.recovering=true end
    end
    local castingDef=c.casting and self.definitions[c.casting]
    c.preparationBlocked=c.recovering or c.cast and (not castingDef or castingDef.def.enemy) or false
    c.nearbyCC=c.controlled
    -- Observed units only. This does not claim to count unseen enemies.
    local seen={}
    c.attackers=0; c.enemiesObserved=0
    local function observe(unit)
        local guid=UnitGUID and UnitGUID(unit)
        if not guid or seen[guid] or not UnitCanAttack or not UnitCanAttack("player",unit) then return end
        seen[guid]=true
        if UnitAffectingCombat and UnitAffectingCombat(unit) then
            c.enemiesObserved=c.enemiesObserved+1
            if UnitIsUnit and UnitIsUnit(unit.."target","player") then c.attackers=c.attackers+1; c.attacked=true end
        end
    end
    observe("target")
    if C_NamePlate and C_NamePlate.GetNamePlates then for _,plate in ipairs(C_NamePlate.GetNamePlates()) do
        local unit=plate.namePlateUnitToken
        if unit then
            observe(unit)
            if hasControl(auraList(unit,"HARMFUL")) then c.nearbyCC=true end
        end
    end end
    for key,entry in pairs(self.definitions) do
        local def=entry.def
        local id=entry.id
        if def.items then for _,item in ipairs(def.items) do if count(item)>0 then id=item end end end
        local item=def.items~=nil
        local cd,start,duration=cooldown(id or 0,item,t)
        if not item and gcdDuration>0 and math.abs(duration-gcdDuration)<0.05 and math.abs(start-gcdStart)<0.05 then cd=0 end
        local name,icon
        if id and not item then name,icon=info(id) end
        local s={id=id,name=name,icon=icon,known=id~=nil,kind=item and "item" or "spell",enemy=def.enemy,
            cost=not item and id and cost(id,c.powerType) or 0,cooldown=cd,range=true}
        if def.enemy then
            if def.near then s.range=CheckInteractDistance and CheckInteractDistance("target",3) or false
            elseif C_Spell and C_Spell.IsSpellInRange and id then s.range=C_Spell.IsSpellInRange(id,"target")
            elseif IsSpellInRange and name then local value=IsSpellInRange(name,"target"); s.range=value==1 or value==true
            else s.range=nil end
        end
        if def.wand then
            local link=GetInventoryItemLink and GetInventoryItemLink("player",18)
            local equip
            if link and GetItemInfoInstant then local a,b,d; a,b,d,equip=GetItemInfoInstant(link) end
            s.known=s.known and equip=="INVTYPE_RANGEDRIGHT"
        end
        s.blocked=self.recent[key] and t-self.recent[key]<0.6 and (item or not def.enemy or def.hasCooldown) or false
        if c.casting==key and not def.enemy then s.blocked=true end
        if def.creates then s.createdCount=count(def.creates[entry.index or 1]) end
        local immunity=self.immunities[c.targetGUID or ""]
        if immunity and immunity[key] and t<immunity[key] then c.immune[key]=true end
        c.spells[key]=s
    end
    if self.AddSupplies then self:AddSupplies(c) end
    return c
end

function H:Enabled()
    return A.characterDB and A.characterDB.rotationHelperEnabled==true and self.module~=nil and not self.suspended
end
function H:SetEnabled(value)
    A.characterDB.rotationHelperEnabled=value==true
    self:Rebuild(); self:Wake()
end
function H:Clear()
    self.state={}; self.picks={}
    self.lastCast=nil; self.finishedCast=nil
    if self.Glow then self.Glow:Apply({}) end
end
function H:Tick()
    if not self:Enabled() then self:Clear(); return end
    local c=self:Snapshot()
    if c then
        self.picks,self.state=self.Select(c,self.module,self.state)
        self.Glow:Apply(self.picks); self.Glow:NotifyMissing(self.picks)
    end
end
function H:Wake()
    self.elapsed=0
    if not self:Enabled() then
        self.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); self.frame:SetScript("OnUpdate",nil); self:Clear(); return
    end
    self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self.Glow:Discover()
    self.frame:SetScript("OnUpdate",function(_,elapsed)
        self.elapsed=self.elapsed+elapsed
        if self.elapsed>=0.1 then self.elapsed=0; self:Tick() end
    end)
    self:Tick()
end
H.frame=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_LEAVING_WORLD","PLAYER_REGEN_ENABLED","PLAYER_TALENT_UPDATE","SPELLS_CHANGED",
    "ACTIONBAR_SLOT_CHANGED","UPDATE_MACROS","ACTIONBAR_PAGE_CHANGED","MODIFIER_STATE_CHANGED","UPDATE_SHAPESHIFT_FORM",
    "UNIT_SPELLCAST_START","UNIT_SPELLCAST_CHANNEL_START","UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_SUCCEEDED","UNIT_SPELLCAST_INTERRUPTED","UNIT_SPELLCAST_FAILED","BAG_UPDATE_DELAYED"}) do H.frame:RegisterEvent(event) end
H.frame:SetScript("OnEvent",function(_,event,unit,castGUID,spellID)
    if event=="PLAYER_LEAVING_WORLD" then
        H.suspended=true; H.frame:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED"); H.frame:SetScript("OnUpdate",nil); H:Clear(); return
    end
    if event=="PLAYER_ENTERING_WORLD" or event=="PLAYER_TALENT_UPDATE" or event=="SPELLS_CHANGED" then
        if event=="PLAYER_ENTERING_WORLD" then H.suspended=nil; H.recent={}; H.immunities={}; H.lastCast=nil; H.finishedCast=nil end
        H.supplyItems=nil; H:Rebuild(); H:Wake(); return
    end
    if not H:Enabled() then return end
    if event:find("^UNIT_") and unit~="player" then return end
    if event=="COMBAT_LOG_EVENT_UNFILTERED" then
        if not CombatLogGetCurrentEventInfo then return end
        local _,kind,_,source,_,_,_,dest,_,_,_,id,_,_,miss=CombatLogGetCurrentEventInfo()
        if source==UnitGUID("player") and kind=="SPELL_MISSED" and miss=="IMMUNE" and dest then
            H.immunities={[dest]=H.immunities[dest] or {}}
            -- Root immunity is not damage immunity. Remember only the failed
            -- spell family, not every spell in its school.
            local key=H.byID[id]; if key then H.immunities[dest][key]=now()+10 end
        end
        return
    end
    if event=="UNIT_SPELLCAST_START" or event=="UNIT_SPELLCAST_CHANNEL_START" or event=="UNIT_SPELLCAST_CHANNEL_STOP" then
        H:CastEvent(event,castGUID,spellID)
    elseif event=="UNIT_SPELLCAST_SUCCEEDED" then
        local key=H.byID[spellID]; if key then H.recent[key]=now() end
        H:CastEvent(event,castGUID,spellID)
    elseif event=="UNIT_SPELLCAST_INTERRUPTED" or event=="UNIT_SPELLCAST_FAILED" then
        H:CastEvent(event,castGUID,spellID)
    elseif event=="BAG_UPDATE_DELAYED" then H.supplyItems=nil
    elseif event=="PLAYER_REGEN_ENABLED" or event=="ACTIONBAR_SLOT_CHANGED" or event=="UPDATE_MACROS" then H:Rebuild(true); H.Glow:Discover() end
    H:Tick()
end)
