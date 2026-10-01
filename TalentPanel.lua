-- Companion panel for Blizzard's Classic talent window.
local _,A=...
local P={}; A.TalentPanel=P
local T,Skin=A.TalentAdvisor,A.Skin

local function text(parent,value,size,x,y,width,height,color)
    local label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    label:SetFont(STANDARD_TEXT_FONT,size,""); label:SetPoint("TOPLEFT",x,-y)
    label:SetSize(width,height); label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    label:SetTextColor(unpack(color or Skin.colors.white)); label:SetText(value)
    return label
end
local function button(parent,label,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width,28); b:SetPoint("TOPLEFT",x,-y)
    b.label=text(b,label,12,6,0,width-12,28); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    Skin.Button(b,"utility")
    b:SetScript("OnEnter",function() Skin.ButtonState(b,false,true,false) end)
    b:SetScript("OnLeave",function() Skin.ButtonState(b,false,false,false) end)
    b:SetScript("OnClick",callback)
    return b
end

function P:Create(parent)
    local panel=CreateFrame("Frame","HardcoreBuddyTalentPanel",parent,"BackdropTemplate")
    self.frame=panel; panel:SetSize(300,378)
    panel:SetPoint("TOPLEFT",parent,"TOPRIGHT",4,-16)
    panel:SetClampedToScreen(true); Skin.Paint(panel,"card")
    text(panel,"Talent Advisor",18,16,14,268,24,Skin.colors.gold)
    text(panel,"HardcoreBuddy",11,16,40,268,18,Skin.colors.muted)
    panel.build=text(panel,"",14,16,66,268,42)
    panel.status=text(panel,"",12,16,114,268,32,Skin.colors.gold)
    panel.pointCount=text(panel,"",12,16,151,268,20,Skin.colors.muted)
    panel.icon=panel:CreateTexture(nil,"ARTWORK"); panel.icon:SetSize(32,32); panel.icon:SetPoint("TOPLEFT",16,-180)
    panel.next=text(panel,"",14,58,178,226,38)
    panel.detail=text(panel,"",12,58,220,226,36,Skin.colors.muted)
    panel.learn=button(panel,"Learn one point",16,260,268,function()
        local nextPoint=panel.recommendation
        if nextPoint then T:LearnNext(nextPoint.build,nextPoint.key,nextPoint.rank) end
        P:Refresh()
    end)
    panel.path=button(panel,"View full path",16,302,130,function() A:HandleSlashCommand("talents") end)
    panel.settings=button(panel,"Settings",154,302,130,function() A:OpenSettings("Talent Advisor") end)
    panel.disable=button(panel,"Disable Talent Advisor",16,338,268,function() T:SetEnabled(false) end)
end

function P:Refresh()
    local panel=self.frame
    if not panel then return end
    local parent=panel:GetParent()
    local visible=T:IsEnabled() and parent:IsShown() and not parent.pet and not parent.inspect
    panel:SetShown(not not visible)
    panel.recommendation=nil; panel.learn:SetEnabled(false); panel.learn.label:SetText("Learn one point")
    if not visible then return end
    -- Always advise the live character, even when the main guide is in preview.
    local _,class=UnitClass("player"); local level=UnitLevel("player")
    local build=T:Build(class,level)
    panel.build:SetText(build and build.name or "No path available")
    panel.next:SetText(""); panel.detail:SetText(""); panel.icon:Hide(); panel.pointCount:SetText("")
    if not build then panel.status:SetText("No Classic talent path for this class."); return end
    local live,reason=T:ReadCurrent(class,level)
    if not live then
        panel.status:SetText("Talent data unavailable.")
        panel.next:SetText("Waiting for your talent tree")
        panel.detail:SetText(reason or "Open Talents and try again.")
        return
    end
    local plan=T.Plan(class,level,build,live.ranks)
    panel.status:SetText(plan.status)
    panel.pointCount:SetText(live.points.." spent  |  "..live.unspent.." available")
    if not plan.next then
        panel.next:SetText(#plan.divergences>0 and "Your talents differ from this path." or plan.status)
        panel.detail:SetText(#plan.divergences>0 and "Choose another path in Settings, or visit a trainer to respec." or "View the full path for details.")
        return
    end
    local nextPoint=plan.next; local node=A.Data.AdvisorTalents[class][nextPoint.key]
    panel.icon:SetTexture(live.icons[nextPoint.key] or 134400); panel.icon:Show()
    panel.next:SetText(live.names[nextPoint.key] or node.name)
    panel.detail:SetText(node.treeName.."\nRank "..nextPoint.rank.." / "..node.maxRank)
    panel.recommendation={build=build.id,key=nextPoint.key,rank=nextPoint.rank}
    local combat=InCombatLockdown and InCombatLockdown()
    panel.learn:SetEnabled(live.unspent>0 and plan.spent<level-9 and not combat)
    panel.learn.label:SetText(combat and "Available after combat" or live.unspent>0 and "Learn one point" or "Next level")
end

function P:Attach()
    local parent=PlayerTalentFrame or TalentFrame
    if not parent then return end
    if not self.frame then
        self:Create(parent)
        parent:HookScript("OnShow",function() P:Refresh() end)
    end
    if hooksecurefunc and PlayerTalentFrame_Refresh and not self.refreshHook then
        hooksecurefunc("PlayerTalentFrame_Refresh",function() P:Refresh() end)
        self.refreshHook=true
    end
    self:Refresh()
end

local events=CreateFrame("Frame"); P.events=events
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","PLAYER_TALENT_UPDATE","CHARACTER_POINTS_CHANGED",
    "PLAYER_LEVEL_UP","PLAYER_REGEN_ENABLED","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" then P:Attach()
    else P:Refresh() end
end)
P:Attach()
