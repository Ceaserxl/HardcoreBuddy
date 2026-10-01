-- Update Blizzard's existing talent rank text and border in place.
local _,A=...
local R={ranks={},hooks={}}; A.TalentRanks=R
local T=A.TalentAdvisor

function R:Clear()
    for label,state in pairs(self.ranks) do
        -- A native refresh may already have replaced our text for another tree.
        -- Restore only our own display, leaving freshly populated ranks alone.
        if label:GetText()==state.written then
            label:SetText(state.text); label:SetShown(state.shown)
            if state.border then state.border:SetShown(state.borderShown) end
        end
        if state.border and state.border:GetWidth()==54 and state.border:GetHeight()==32 then
            state.border:SetSize(state.width,state.height)
        end
    end
    self.ranks={}
end

function R:Refresh()
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
        local name="PlayerTalentFrameTalent"..index
        local button,label,border=_G[name],_G[name.."Rank"],_G[name.."RankBorder"]
        if node.tree==tree and button and button:IsShown() and label and (desired>0 or current>0) then
            local color=current>desired and "ee6655" or current==desired and "66cc77" or "55bbff"
            local written=current.."/|cff"..color..desired.."|r"
            self.ranks[label]={text=label:GetText(),shown=label:IsShown(),written=written,
                border=border,borderShown=border and border:IsShown(),
                width=border and border:GetWidth(),height=border and border:GetHeight()}
            label:SetText(written); label:Show()
            if border then border:SetSize(54,32); border:Show() end
        end
    end
end

function R:Attach()
    local parent=PlayerTalentFrame
    if not parent then return end
    if not self.parent then
        self.parent=parent
        parent:HookScript("OnShow",function() R:Refresh() end)
        parent:HookScript("OnHide",function() R:Clear() end)
    end
    if hooksecurefunc then
        for _,name in ipairs({"TalentFrame_Update","PlayerTalentFrame_Refresh"}) do
            if type(_G[name])=="function" and not self.hooks[name] then
                hooksecurefunc(name,function() R:Refresh() end); self.hooks[name]=true
            end
        end
    end
    self:Refresh()
end

local events=CreateFrame("Frame"); R.events=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED","PLAYER_LEVEL_UP"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent",function(_,event)
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" then R:Attach() else R:Refresh() end
end)
R:Attach()
