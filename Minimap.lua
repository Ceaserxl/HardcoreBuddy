local _, addon = ...

function addon:PositionMinimapButton()
    self.minimap:SetShown(not self.db.minimapHidden)
    local angle = math.rad(self.db.minimapAngle)
    local x, y = math.cos(angle), math.sin(angle)
    if GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local edge = math.max(math.abs(x), math.abs(y))
        x, y = x / edge, y / edge
    end
    self.minimap:ClearAllPoints()
    self.minimap:SetPoint("CENTER", Minimap, "CENTER",
        x * (Minimap:GetWidth() / 2 + 5), y * (Minimap:GetHeight() / 2 + 5))
end

function addon:CreateMinimapButton()
    local angle = tonumber(self.db.minimapAngle)
    self.db.minimapAngle = angle and angle == angle and math.abs(angle) < math.huge and angle % 360 or 225
    if self.minimap then self:PositionMinimapButton(); return end
    local button = CreateFrame("Button", "HardcoreBuddyMinimapButton", Minimap)
    self.minimap = button
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20); background:SetPoint("TOPLEFT", 7, -5)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24); icon:SetPoint("TOPLEFT", 4, -3)
    icon:SetTexture("Interface\\AddOns\\HardcoreBuddy\\Media\\SurvivorShield")
    icon:SetTexCoord(0, 1, 0, 1)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53); border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function(frame, mouseButton)
        if frame.dragging or GetTime() < (frame.ignoreClickUntil or 0) then return end
        if mouseButton == "RightButton" then
            if self.Deaths and self.Deaths.db then self.Deaths:Slash("") end
        else self:ToggleWindow() end
    end)
    button:SetScript("OnDragStart", function(frame)
        frame.dragging = true
        GameTooltip:Hide()
        frame:SetScript("OnUpdate", function()
            local x, y = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            if not cx or not cy or scale <= 0 then return end
            self.db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx)) % 360
            self:PositionMinimapButton()
        end)
    end)
    local function stopDrag(frame)
        if frame.dragging then frame.ignoreClickUntil = GetTime() + 0.2 end
        frame.dragging = false
        frame:SetScript("OnUpdate", nil)
    end
    button:SetScript("OnDragStop", stopDrag)
    button:SetScript("OnHide", function(frame) stopDrag(frame); GameTooltip:Hide() end)
    button:SetScript("OnEnter", function(frame)
        if frame.dragging then return end
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        GameTooltip:SetText("HardcoreBuddy", 0.83, 0.69, 0.43, 1, true)
        GameTooltip:AddLine("Left-click: open / close the field kit", 0.94, 0.92, 0.87, true)
        GameTooltip:AddLine("Right-click: open the Death Journal page", 0.94, 0.92, 0.87, true)
        GameTooltip:AddLine("Drag: move around the minimap", 0.72, 0.73, 0.75, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self:PositionMinimapButton()
end
