-- Cosmetic copies of Blizzard's proc alert. Never claim or clear another
-- addon's/native SpellActivationAlert, change actions, or execute a spell.
local _,A=...
local H=A.RotationHelper
local G={buttons={},seen={},warnedMissing={}}; H.Glow=G
local prefixes={"ActionButton","MultiBarBottomLeftButton","MultiBarBottomRightButton","MultiBarRightButton","MultiBarLeftButton",
    "MultiBar5Button","MultiBar6Button","MultiBar7Button","BT4Button","DominosActionButton","ElvUI_Bar1Button","ElvUI_Bar2Button",
    "ElvUI_Bar3Button","ElvUI_Bar4Button","ElvUI_Bar5Button","ElvUI_Bar6Button"}

function G:Register(button)
    if not button or self.seen[button]~=nil or (InCombatLockdown and InCombatLockdown()) then return end
    local ok,glow=pcall(CreateFrame,"Frame",nil,button,"ActionButtonSpellAlertTemplate")
    if not ok or not glow or not glow.ProcLoop then
        if ok and glow then glow:Hide() end
        self.seen[button]=false; self.unavailable=true; return
    end
    -- A second, additive pass brightens every category without enlarging the
    -- animation or reintroducing the oversized birth texture.
    local layers={glow}
    local boosted,boost=pcall(CreateFrame,"Frame",nil,button,"ActionButtonSpellAlertTemplate")
    if boosted and boost and boost.ProcLoop then
        boost:SetAlpha(0.65)
        for _,key in ipairs({"ProcStartFlipbook","ProcLoopFlipbook"}) do
            if boost[key] then boost[key]:SetBlendMode("ADD") end
        end
        layers[#layers+1]=boost
    else
        if boosted and boost then boost:Hide() end
        boost=nil
    end
    for i,layer in ipairs(layers) do
        layer:EnableMouse(false); layer:SetPoint("CENTER",button,"CENTER",0,0)
        layer:SetFrameLevel(button:GetFrameLevel()+4+i)
    end
    local function size()
        local w,h=button:GetSize()
        for _,layer in ipairs(layers) do
            layer:SetSize(w*1.4,h*1.4)
            -- The birth texture has a fixed size in Blizzard's template.
            if layer.ProcStartFlipbook then layer.ProcStartFlipbook:ClearAllPoints(); layer.ProcStartFlipbook:SetAllPoints(layer) end
        end
    end
    size(); button:HookScript("OnSizeChanged",size)
    for _,layer in ipairs(layers) do layer:Hide() end
    local entry={button=button,glow=glow,boost=boost,layers=layers}
    self.seen[button]=entry; self.buttons[#self.buttons+1]=entry
    button:HookScript("OnHide",function()
        for _,layer in ipairs(layers) do layer.ProcLoop:Stop(); layer:Hide() end
        entry.pick=nil
    end)
end
function G:Discover()
    if InCombatLockdown and InCombatLockdown() then return end
    for _,prefix in ipairs(prefixes) do for i=1,120 do self:Register(_G[prefix..i]) end end
    if ActionBarButtonEventsFrame and ActionBarButtonEventsFrame.frames then
        for _,button in pairs(ActionBarButtonEventsFrame.frames) do if type(button)=="table" then self:Register(button) end end
    end
end

function G.SlotAction(slot)
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

function G.Action(button)
    return G.SlotAction(button.action or (button.GetAttribute and button:GetAttribute("action")))
end

function G:HasSpell(id)
    for _,entry in ipairs(self.buttons) do
        local kind,spell=self.Action(entry.button)
        if kind=="spell" and spell==id then return true end
    end
    return false
end

function G:NotifyMissing(picks)
    local pending={}
    for _,pick in ipairs(picks) do
        if pick.kind=="spell" and pick.id and not self.warnedMissing[pick.id] then pending[pick.id]=true end
    end
    if not next(pending) then return end
    for _,entry in ipairs(self.buttons) do
        local kind,id=self.Action(entry.button)
        if kind=="spell" and id then pending[id]=nil end
    end
    -- Hidden/paged bars still count as having the spell. Resolve macros through
    -- the same API as the glow, including the currently selected modifier.
    if next(pending) then
        local slots=math.max(120,MAX_ACTION_BUTTONS or 0,(NUM_ACTIONBAR_PAGES or 0)*(NUM_ACTIONBAR_BUTTONS or 12))
        for slot=1,slots do
            local kind,id=self.SlotAction(slot)
            if kind=="spell" and id then pending[id]=nil end
            if not next(pending) then break end
        end
    end
    for _,pick in ipairs(picks) do
        if pick.kind=="spell" and pending[pick.id] then
            local name=H.SpellInfo(pick.id)
            if name then
                local link=GetSpellLink and GetSpellLink(pick.id)
                A:Print("Rotation Helper: "..(link or name).." is missing from your action bars. Add the recommended rank or a macro that casts it.")
                self.warnedMissing[pick.id]=true
                pending[pick.id]=nil
            end
        end
    end
end

function G:Apply(picks)
    local actions={}
    for _,pick in ipairs(picks) do actions[pick.kind..":"..pick.id]=pick end
    for _,entry in ipairs(self.buttons) do
        local b=entry.button
        local kind,id=self.Action(b)
        local pick=b:IsVisible() and kind and id and actions[kind..":"..id]
        -- A rank-one control button may coexist with a highest-rank damage
        -- button. Match exact spell IDs, not every rank with the same name.
        if pick then
            local signature=kind..":"..id..":"..pick.category
            if entry.pick~=signature then
                local color=H.colors[pick.category]
                for _,layer in ipairs(entry.layers) do
                    for _,key in ipairs({"ProcStartFlipbook","ProcLoopFlipbook"}) do
                        if layer[key] then layer[key]:SetVertexColor(unpack(color)) end
                    end
                    if layer.ProcAltGlow then layer.ProcAltGlow:Hide() end
                    if layer.ProcStartAnim then layer.ProcStartAnim:Stop() end
                    layer:Show()
                    if not layer.ProcLoop:IsPlaying() then layer.ProcLoop:Play() end
                end
                entry.pick=signature
            end
        elseif entry.pick then
            for _,layer in ipairs(entry.layers) do layer.ProcLoop:Stop(); layer:Hide() end
            entry.pick=nil
        end
    end
end
