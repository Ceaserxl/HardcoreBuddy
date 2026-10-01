-- Decorative upgrade hints on native bag and quest reward item buttons.
-- Work is queued in small batches; no item or quest click handlers are replaced.
local _,A=...
local I={buttons=setmetatable({},{__mode="k"}),pending={},queue={},cache={},hooks={}}
A.GearIndicators=I
local worker=CreateFrame("Frame"); I.worker=worker

function I:IsUpgrade(link)
    local G=A.GearAdvisor
    if not link then return false end
    if self.revision~=G.revision then self.cache={}; self.revision=G.revision end
    if self.cache[link]~=nil then return self.cache[link] end
    local item=G:Read(link)
    local profile=G:CurrentProfile()
    if not item or not profile then return false end
    local upgrade=false
    if G.Allowed(item,profile) then
        -- Compare complete hands, not the tooltip's optional main-hand-only row.
        for _,row in ipairs(G:Comparisons(item,profile)) do
            if row.status=="up" and (G.Score(item,profile,row.slot) or 0)>0 then upgrade=true; break end
        end
    end
    self.cache[link]=upgrade
    return upgrade
end

function I:Paint(button,show)
    local art=button.hardcoreBuddyUpgrade
    if not show and not art then return end
    if not art then
        art={}; button.hardcoreBuddyUpgrade=art
        local name=button:GetName()
        local icon=button.icon or button.Icon or button.iconTexture or (name and _G[name.."IconTexture"]) or button
        local function line(width,height,point,relative,x,y,rotation)
            local t=button:CreateTexture(nil,"OVERLAY",nil,7)
            t:SetTexture("Interface\\Buttons\\WHITE8x8"); t:SetVertexColor(0.25,1,0.4,1)
            t:SetSize(width,height); t:SetPoint(point,icon,relative,x,y)
            if rotation then t:SetRotation(rotation) end
            art[#art+1]=t; return t
        end
        local top=line(1,2,"TOPLEFT","TOPLEFT",0,0); top:SetPoint("TOPRIGHT",icon,"TOPRIGHT",0,0)
        local bottom=line(1,2,"BOTTOMLEFT","BOTTOMLEFT",0,0); bottom:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",0,0)
        local left=line(2,1,"TOPLEFT","TOPLEFT",0,0); left:SetPoint("BOTTOMLEFT",icon,"BOTTOMLEFT",0,0)
        local right=line(2,1,"TOPRIGHT","TOPRIGHT",0,0); right:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",0,0)
        line(3,10,"TOPLEFT","TOPLEFT",8,-6)
        line(8,3,"CENTER","TOPLEFT",7,-7,math.pi/4)
        line(8,3,"CENTER","TOPLEFT",12,-7,-math.pi/4)
    end
    for _,texture in ipairs(art) do texture:SetShown(show) end
end

function I:Link(button,record)
    if not button:IsVisible() then return end
    if record.kind=="bag" then
        local bag=record.parent:GetID()
        if type(bag)~="number" or bag<0 or bag>(NUM_BAG_SLOTS or 4) then return end
        local get=C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
        return get and get(bag,button:GetID())
    elseif record.kind=="quest" and button.objectType=="item" and button.type=="choice" then
        local get=record.questLog and GetQuestLogItemLink or GetQuestItemLink
        return get and get("choice",button:GetID())
    end
end

function I:Queue(button)
    if self.pending[button] then return end
    self.pending[button]=true; self.queue[#self.queue+1]=button
    worker:SetScript("OnUpdate",function() I:Step() end)
end

function I:Watch(button,record)
    if not button then return end
    if not self.buttons[button] then
        button:HookScript("OnHide",function(b) I:Paint(b,false) end)
        button:HookScript("OnShow",function(b) I:Queue(b) end)
    end
    local previous=self.buttons[button]
    self.buttons[button]=record
    local link=self:Link(button,record)
    record.link=link
    if not previous or previous.link~=link then self:Paint(button,false) end
    self:Queue(button)
end

function I:Bags(frame)
    if not frame or not frame:IsShown() or not frame:GetName() then return end
    for index=1,frame.size or 0 do
        self:Watch(_G[frame:GetName().."Item"..index],{kind="bag",parent=frame})
    end
end

function I:Quests()
    local info=QuestInfoFrame
    local rewards=info and info.rewardsFrame
    if not rewards then return end
    for _,button in ipairs(rewards.RewardButtons or {}) do
        self:Watch(button,{kind="quest",questLog=not not info.questLog})
    end
end

function I:Step()
    for _=1,4 do
        local button=table.remove(self.queue,1)
        if not button then worker:SetScript("OnUpdate",nil); return end
        self.pending[button]=nil
        local record=self.buttons[button]
        local link=record and self:Link(button,record)
        if record then record.link=link end
        self:Paint(button,A.db and A.db.gearUpgradeMarkers~=false and link and self:IsUpgrade(link) or false)
    end
end

function I:Invalidate()
    self.cache={}
    for button in pairs(self.buttons) do
        self:Paint(button,false)
        if button:IsVisible() then self:Queue(button) end
    end
end

function I:Attach()
    if not hooksecurefunc then return end
    for _,entry in ipairs({{"ContainerFrame_Update",function(frame) I:Bags(frame) end},
        {"ContainerFrame_GenerateFrame",function(frame) I:Bags(frame) end},
        {"QuestInfo_Display",function() I:Quests() end},
        {"QuestInfo_ShowRewards",function() I:Quests() end}}) do
        if type(_G[entry[1]])=="function" and not self.hooks[entry[1]] then
            hooksecurefunc(entry[1],entry[2]); self.hooks[entry[1]]=true
        end
    end
end

for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","BAG_UPDATE_DELAYED","PLAYER_EQUIPMENT_CHANGED",
    "GET_ITEM_INFO_RECEIVED","UNIT_LEVEL","UNIT_INVENTORY_CHANGED","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","SPELLS_CHANGED","SKILL_LINES_CHANGED",
    "QUEST_DETAIL","QUEST_COMPLETE","QUEST_LOG_UPDATE","QUEST_FINISHED"}) do worker:RegisterEvent(event) end
worker:SetScript("OnEvent",function(_,event,unit)
    if (event=="UNIT_LEVEL" or event=="UNIT_INVENTORY_CHANGED") and unit~="player" then return end
    if event=="ADDON_LOADED" then I:Attach(); return end
    I:Invalidate()
    for index=1,NUM_CONTAINER_FRAMES or 13 do I:Bags(_G["ContainerFrame"..index]) end
    I:Quests()
end)
I:Attach()
