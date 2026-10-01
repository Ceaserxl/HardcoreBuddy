-- Bag-only advice using the same live profile and complete-hand comparisons.
local _,A=...
local B={notified={},attempted={}}; A.GearBagAdvisor=B
local worker=CreateFrame("Frame"); B.worker=worker
local function container(name) return C_Container and C_Container[name] or _G[name] end
local function itemAPI(name) return C_Item and C_Item[name] or _G[name] end
local function linkAt(bag,slot)
    local get=container("GetContainerItemLink"); return get and get(bag,slot)
end
local function locked(bag,slot)
    local get=container("GetContainerItemInfo")
    if not get then return true end
    local info,_,lock=get(bag,slot)
    if type(info)=="table" then return info.isLocked end
    return not info or lock
end
local function questLink(link)
    local get=itemAPI("GetItemInfo")
    if not get then return nil end
    local name,_,_,_,_,_,_,_,_,_,_,class,_,binding=get(link)
    if not name or class==nil or binding==nil then return nil end
    return class==12 or binding==4
end

function B:Enabled()
    return A.GearAdvisor:IsEnabled() and (A.db.gearBagNotify or A.db.gearAutoEquip)
end

function B:Safe()
    return not InCombatLockdown() and not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player"))
        and not (UnitOnTaxi and UnitOnTaxi("player")) and not (GetCursorInfo and GetCursorInfo())
end

-- Unknown quest status is not permission to remove an equipped item.
function B:Protected(slot)
    if not GetInventoryItemID or not GetInventoryItemLink then return true end
    local id=GetInventoryItemID("player",slot)
    if not id or id==0 then return false end
    local link=GetInventoryItemLink("player",slot)
    return not link or questLink(link)~=false
end

function B:CanEquip(candidate,row)
    if not self:Safe() or locked(candidate.bag,candidate.slot) then return false end
    if linkAt(candidate.bag,candidate.slot)~=candidate.link or questLink(candidate.link)~=false then return false end
    local get=container("GetContainerItemQuestInfo")
    if not get then return false end
    local q,id=get(candidate.bag,candidate.slot)
    if C_Container and get==C_Container.GetContainerItemQuestInfo and type(q)~="table" then return false end
    if type(q)=="table" then
        if q.isQuestItem or q.questID then return false end
    elseif q or id then return false end
    if self:Protected(row.slot) then return false end
    if candidate.item.equip=="INVTYPE_2HWEAPON" and self:Protected(17) then return false end
    return true
end

function B:Queue()
    self.job=nil
    if not self:Enabled() then self.due=nil; worker:SetScript("OnUpdate",nil); return end
    self.due=GetTime()+0.5
    worker:SetScript("OnUpdate",function() B:Step() end)
end

function B:Changed()
    self.notified={}; self.attempted={}; self:Queue()
end

function B:Start()
    local count=container("GetContainerNumSlots")
    local profile=A.GearAdvisor:CurrentProfile()
    if not count or not profile then return end
    local job={items={},index=1,profile=profile,revision=A.GearAdvisor.revision,upgrades={}}
    for bag=0,NUM_BAG_SLOTS or 4 do
        for slot=1,count(bag) or 0 do
            local link=linkAt(bag,slot)
            if link then job.items[#job.items+1]={bag=bag,slot=slot,link=link} end
        end
    end
    self.job=job
end

function B:Finish(job)
    local G=A.GearAdvisor
    local equipment={}
    for slot=1,18 do equipment[slot]=GetInventoryItemLink and GetInventoryItemLink("player",slot) or "-" end
    local fingerprint=table.concat(equipment,";")
    if self.fingerprint~=fingerprint then self.attempted={}; self.fingerprint=fingerprint end
    local best
    for _,candidate in ipairs(job.upgrades) do
        local present=linkAt(candidate.bag,candidate.slot)==candidate.link
        if present and A.db.gearBagNotify and not self.notified[candidate.link] then
            self.notified[candidate.link]=true
            local row=candidate.rows[1]
            A:Print("|cff73d697Bag upgrade:|r "..candidate.link.." | "..row.label.." | "..row.text)
        end
        if present and A.db.gearAutoEquip then
            for _,row in ipairs(candidate.rows) do
                local key=candidate.link..":"..row.slot
                if not self.attempted[key] and self:CanEquip(candidate,row) then
                    local rank=row.percent or math.huge
                    local score=G.Score(candidate.item,job.profile,row.slot) or 0
                    if not best or rank>best.rank or (rank==best.rank and score>best.score) then
                        best={candidate=candidate,row=row,rank=rank,score=score,key=key}
                    end
                end
            end
        end
    end
    if best and A.db.gearAutoEquip and self:Enabled() and self:CanEquip(best.candidate,best.row) then
        local equip=itemAPI("EquipItemByName")
        if equip then
            self.attempted[best.key]=true
            -- One mutation per pass. The equipment event triggers fresh scoring.
            -- Never accept a bind popup or clear a cursor on the user's behalf.
            equip(best.candidate.link,best.row.slot)
        end
    end
end

function B:Step()
    if not self:Enabled() then self:Queue(); return end
    if GetTime()<(self.due or 0) then return end
    if not self:Safe() then self.due=GetTime()+1; return end
    if self.job and self.job.revision~=A.GearAdvisor.revision then self:Queue(); return end
    if not self.job then self:Start() end
    local job=self.job
    if not job then worker:SetScript("OnUpdate",nil); return end
    local G=A.GearAdvisor
    for _=1,4 do
        local candidate=job.items[job.index]; job.index=job.index+1
        if not candidate then
            self.job=nil; worker:SetScript("OnUpdate",nil); self:Finish(job); return
        end
        if linkAt(candidate.bag,candidate.slot)==candidate.link then
            local item=G:Read(candidate.link)
            if item and G.Allowed(item,job.profile) then
                candidate.item=item; candidate.rows={}
                for _,row in ipairs(G:Comparisons(item,job.profile)) do
                    if row.status=="up" and (G.Score(item,job.profile,row.slot) or 0)>0 then
                        candidate.rows[#candidate.rows+1]=row
                    end
                end
                if #candidate.rows>0 then job.upgrades[#job.upgrades+1]=candidate end
            end
        end
    end
end

for _,event in ipairs({"PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED","GET_ITEM_INFO_RECEIVED",
    "PLAYER_REGEN_ENABLED","CURSOR_CHANGED","ITEM_LOCK_CHANGED","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED",
    "UNIT_LEVEL","SPELLS_CHANGED","SKILL_LINES_CHANGED"}) do worker:RegisterEvent(event) end
worker:SetScript("OnEvent",function(_,event,unit)
    if event=="UNIT_LEVEL" and unit~="player" then return end
    B:Queue()
end)
