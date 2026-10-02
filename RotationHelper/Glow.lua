-- Cosmetic copies of Blizzard's proc alert. Never claim or clear another
-- addon's/native SpellActivationAlert, change actions, or execute a spell.
local _,A=...
local H=A.RotationHelper
local G={buttons={},seen={}}; H.Glow=G
local prefixes={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton",
    "MultiBar5Button","MultiBar6Button","MultiBar7Button","BT4Button","DominosActionButton","ElvUI_Bar1Button","ElvUI_Bar2Button",
    "ElvUI_Bar3Button","ElvUI_Bar4Button","ElvUI_Bar5Button","ElvUI_Bar6Button"}

function G:Register(button)
    if not button or self.seen[button]~=nil or (InCombatLockdown and InCombatLockdown()) then return end
    local ok,glow=pcall(CreateFrame,"Frame",nil,button,"ActionButtonSpellAlertTemplate")
    if not ok or not glow or not glow.ProcLoop then
        if glow then glow:Hide() end
        self.seen[button]=false; self.unavailable=true; return
    end
    glow:EnableMouse(false); glow:SetPoint("CENTER",button,"CENTER",0,0)
    glow:SetFrameLevel(button:GetFrameLevel()+5)
    local function size()
        local w,h=button:GetSize(); glow:SetSize(w*1.4,h*1.4)
        -- The birth texture has a fixed size in Blizzard's template. Use only
        -- its continuous animation, with identical bounds for both textures.
        if glow.ProcStartFlipbook then glow.ProcStartFlipbook:ClearAllPoints(); glow.ProcStartFlipbook:SetAllPoints(glow) end
    end
    size(); button:HookScript("OnSizeChanged",size)
    glow:Hide()
    local entry={button=button,glow=glow}
    self.seen[button]=entry; self.buttons[#self.buttons+1]=entry
    button:HookScript("OnHide",function() glow.ProcLoop:Stop(); glow:Hide(); entry.pick=nil end)
end
function G:Discover()
    if InCombatLockdown and InCombatLockdown() then return end
    for _,prefix in ipairs(prefixes) do for i=1,120 do self:Register(_G[prefix..i]) end end
    if ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames then
        for _,button in pairs(ActionBarButtonEventsFrame.frames) do if type(button)=="table" then self:Register(button) end end
    end
end

function G.Action(button)
    local slot=button.action or (button.GetAttribute and button:GetAttribute("action"))
    if type(slot)~="number" or not GetActionInfo then return end
    local kind,id,subtype=GetActionInfo(slot)
    if kind=="macro" then
        -- Modern clients return the resolved action, including macro modifiers.
        if subtype=="spell" or subtype=="item" then return subtype,id end
        local spell=GetMacroSpell and GetMacroSpell(id)
        if spell then return "spell",spell end
        if GetMacroItem then local _,link=GetMacroItem(id); if link then return "item",tonumber(link:match("item:(%d+)")) end end
    elseif kind=="spell" or kind=="item" then return kind,id end
end

function G:HasSpell(id)
    for _,entry in ipairs(self.buttons) do
        local kind,spell=self.Action(entry.button)
        if kind=="spell" and spell==id then return true end
    end
    return false
end

function G:Apply(picks)
    local actions={}
    for _,pick in ipairs(picks) do actions[pick.kind..":"..pick.id]=pick end
    for _,entry in ipairs(self.buttons) do
        local b,glow=entry.button,entry.glow
        local kind,id=self.Action(b)
        local pick=b:IsVisible() and kind and id and actions[kind..":"..id]
        -- A rank-one control button may coexist with a highest-rank damage
        -- button. Match exact spell IDs, not every rank with the same name.
        if pick then
            local signature=kind..":"..id..":"..pick.category
            if entry.pick~=signature then
                local color=H.colors[pick.category]
                for _,key in ipairs({"ProcStartFlipbook","ProcLoopFlipbook"}) do
                    if glow[key] then glow[key]:SetVertexColor(unpack(color)) end
                end
                if glow.ProcAltGlow then glow.ProcAltGlow:Hide() end
                if glow.ProcStartAnim then glow.ProcStartAnim:Stop() end
                glow:Show()
                if not glow.ProcLoop:IsPlaying() then glow.ProcLoop:Play() end
                entry.pick=signature
            end
        elseif entry.pick then glow.ProcLoop:Stop(); glow:Hide(); entry.pick=nil end
    end
end
