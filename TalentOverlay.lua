-- Current/recommended ranks on Blizzard's talent icons. No click handlers change.
local _,A=...
local O={badges={},hooks={}}; A.TalentOverlay=O
local T=A.TalentAdvisor

function O:Clear()
    for _,badge in pairs(self.badges) do badge:Hide() end
end

function O:Badge(button)
    local badge=self.badges[button]
    if badge then return badge end
    -- A mouse-transparent decoration above the native rank; disabling it reveals
    -- Blizzard's original rank and border without changing either region.
    badge=CreateFrame("Frame",nil,button)
    badge:SetSize(34,16); badge:EnableMouse(false)
    local rank=_G[button:GetName().."Rank"]
    if rank then badge:SetPoint("RIGHT",rank,"RIGHT",3,0)
    else badge:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",5,-3) end
    badge.background=badge:CreateTexture(nil,"BACKGROUND")
    badge.background:SetTexture("Interface\\Buttons\\WHITE8x8")
    badge.background:SetVertexColor(0,0,0,1); badge.background:SetAllPoints()
    badge.label=badge:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    badge.label:SetFont(STANDARD_TEXT_FONT,12,"OUTLINE")
    badge.label:SetAllPoints(); badge.label:SetJustifyH("CENTER"); badge.label:SetJustifyV("MIDDLE")
    self.badges[button]=badge
    return badge
end

function O:Refresh()
    self:Clear()
    local parent=PlayerTalentFrame
    if not T:IsEnabled() or not parent or not parent:IsShown() or parent.pet or parent.inspect then return end
    local tree=PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(parent)
    if type(tree)~="number" or tree<1 or tree>3 then return end
    local _,class=UnitClass("player"); local level=UnitLevel("player")
    local build=T:Build(class,level)
    local live=T:ReadCurrent(class,level)
    if not build or not live then return end
    local target={}
    for _,key in ipairs(build.steps) do target[key]=(target[key] or 0)+1 end
    for key,index in pairs(live.indices) do
        local node=A.Data.AdvisorTalents[class][key]
        local current,desired=live.ranks[key],target[key] or 0
        local button=_G["PlayerTalentFrameTalent"..index]
        if node.tree==tree and button and button:IsShown() and (desired>0 or current>0) then
            local badge=self:Badge(button)
            local color=current>desired and "ee6655" or current==desired and "66cc77" or "55bbff"
            badge.label:SetText(current.."/|cff"..color..desired.."|r")
            badge.label:SetTextColor(1,1,1,1); badge:Show()
        end
    end
end

function O:Attach()
    local parent=PlayerTalentFrame
    if not parent then return end
    if not self.parent then
        self.parent=parent
        parent:HookScript("OnShow",function() O:Refresh() end)
        parent:HookScript("OnHide",function() O:Clear() end)
    end
    -- The base update repopulates the same icons when selecting another tree.
    if hooksecurefunc then
        for _,name in ipairs({"TalentFrame_Update","PlayerTalentFrame_Refresh"}) do
            if type(_G[name])=="function" and not self.hooks[name] then
                hooksecurefunc(name,function() O:Refresh() end); self.hooks[name]=true
            end
        end
    end
    self:Refresh()
end

local events=CreateFrame("Frame"); O.events=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","PLAYER_LEVEL_UP"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent",function(_,event)
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" then O:Attach() else O:Refresh() end
end)
O:Attach()
