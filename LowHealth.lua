local addonName, addon = ...
local H = {}
addon.LowHealth = H
local MEDIA="Interface\\AddOns\\"..addonName.."\\Media\\Health\\"

function H:StopSound()
    if self.soundHandle and StopSound then StopSound(self.soundHandle) end
    self.soundHandle=nil
end

function H:Alarm()
    self:StopSound()
    if self.settings.sound and self.settings.volume>0 and PlaySoundFile then
        local _,handle=PlaySoundFile(MEDIA.."AirHorn"..self.settings.volume..".wav","Master")
        self.soundHandle=handle
    end
end

function H:Update()
    if not self.settings then return end
    local health=UnitHealth and UnitHealth("player") or 0
    local maximum=UnitHealthMax and UnitHealthMax("player") or 0
    local dead=UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")
    local active=self.settings.enabled and not dead and health>0 and maximum>0
        and health/maximum*100<self.settings.threshold
    if active and not self.active then self.elapsed=0; self:Alarm() end
    if not active and self.active then self:StopSound() end
    self.active=active
    if not self.settings.sound then self:StopSound() end
    self.warning:SetShown(active or self.previewRemaining~=nil)
end

function H:Preview()
    self.previewRemaining=3; self.elapsed=0
    self:Alarm(); self.warning:Show()
end

function H:Initialize()
    addon.db.lowHealth=type(addon.db.lowHealth)=="table" and addon.db.lowHealth or {}
    self.settings=addon.db.lowHealth
    local s=self.settings
    if s.enabled==nil then s.enabled=true end
    if s.sound==nil then s.sound=true end
    local volume=tonumber(s.volume)
    s.volume=volume and volume==volume and math.max(0,math.min(100,math.floor(volume/10+0.5)*10)) or 70
    local threshold=tonumber(s.threshold)
    s.threshold=threshold and threshold==threshold and math.max(1,math.min(100,math.floor(threshold))) or 40
    local warning=CreateFrame("Frame","HardcoreBuddyLowHealthWarning",UIParent)
    self.warning=warning; self.elapsed=0
    warning:SetSize(760,90); warning:SetPoint("CENTER",UIParent,"CENTER",0,220)
    warning:SetFrameStrata("HIGH"); warning:EnableMouse(false)
    local text=warning:CreateFontString(nil,"OVERLAY")
    text:SetAllPoints(); text:SetFont("Fonts\\FRIZQT__.TTF",72,"OUTLINE")
    text:SetTextColor(0.988,0.125,0.110); text:SetJustifyH("CENTER")
    text:SetText("LOW HEALTH!"); self.text=text
    warning:SetScript("OnUpdate",function(_,elapsed)
        self.elapsed=self.elapsed+elapsed
        warning:SetAlpha(0.75+0.25*math.cos(self.elapsed*math.pi*4))
        if self.previewRemaining then
            self.previewRemaining=self.previewRemaining-elapsed
            if self.previewRemaining<=0 then
                self.previewRemaining=nil
                if not self.active then self:StopSound() end
                self:Update()
            end
        end
    end)
    self:Update()
end

function H:LayoutSettings(parent,x,y,width,height,visible)
    if not self.settings then return end
    if not self.page and visible then
        local page=CreateFrame("Frame",nil,parent)
        self.page=page
        local function label(text,size,x,y,width,owner)
            local f=(owner or page):CreateFontString(nil,"OVERLAY","GameFontHighlight")
            f:SetFont(STANDARD_TEXT_FONT,size,""); f:SetPoint("TOPLEFT",x,y)
            f:SetWidth(width); f:SetJustifyH("LEFT"); f:SetText(text)
            return f
        end
        page.title=label("Low Health",22,0,0,600)
        page.subtitle=label("Flashing red text and an alarm when health falls below your threshold.",12,0,-34,700)
        local warning=addon.Skin.Section(page,"Warning",62,208,1)
        local sound=addon.Skin.Section(page,"Sound",62,208,2)
        page.checks={}
        for i,entry in ipairs({{"enabled","Enable low health warning"},{"sound","Play alarm sound"}}) do
            local key=entry[1]
            local owner=i==1 and warning or sound
            local box=CreateFrame("CheckButton",nil,owner,"BackdropTemplate")
            box:SetSize(24,24); box:SetPoint("TOPLEFT",16,-48)
            addon.Skin.Paint(box,"edit")
            box.mark=box:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            box.mark:SetAllPoints()
            box.mark:SetJustifyH("CENTER"); box.mark:SetJustifyV("MIDDLE")
            box.label=label(entry[2],12,50,-52,260,owner)
            box:SetScript("OnClick",function()
                self.settings[key]=box:GetChecked() and true or false
                if key=="enabled" and not self.settings.enabled then self.previewRemaining=nil; self:StopSound() end
                box.mark:SetText(self.settings[key] and "X" or "")
                self:Update()
            end)
            page.checks[key]=box
        end
        page.thresholdLabels={label("Warn below",12,16,-92,100,warning)}
        local input=CreateFrame("EditBox",nil,warning,"BackdropTemplate")
        page.threshold=input; input:SetSize(54,28); input:SetPoint("TOPLEFT",122,-84)
        addon.Skin.Paint(input,"edit"); input:SetFont(STANDARD_TEXT_FONT,14,"")
        input:SetAutoFocus(false); input:SetNumeric(true); input:SetMaxLetters(3)
        input:SetJustifyH("CENTER")
        page.thresholdLabels[2]=label("% health",12,188,-92,140,warning)
        local function commit()
            local value=tonumber(input:GetText())
            if value then self.settings.threshold=math.max(1,math.min(100,math.floor(value))) end
            input:SetText(tostring(self.settings.threshold)); self:Update()
        end
        input:SetScript("OnEnterPressed",function() commit(); input:ClearFocus() end)
        input:SetScript("OnEditFocusLost",commit)
        input:SetScript("OnEscapePressed",function() input:SetText(tostring(self.settings.threshold)); input:ClearFocus() end)
        local preview=CreateFrame("Button",nil,warning,"BackdropTemplate")
        page.preview=preview; preview:SetSize(280,30); preview:SetPoint("TOPLEFT",16,-130)
        local title=preview:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        title:SetAllPoints(); title:SetJustifyH("CENTER"); title:SetJustifyV("MIDDLE"); title:SetText("Preview warning")
        preview.label=title
        addon.Skin.Button(preview,"utility")
        preview:SetScript("OnEnter",function() addon.Skin.ButtonState(preview,false,true,false) end)
        preview:SetScript("OnLeave",function() addon.Skin.ButtonState(preview,false,false,false) end)
        preview:SetScript("OnMouseDown",function() addon.Skin.ButtonState(preview,false,true,true) end)
        preview:SetScript("OnMouseUp",function() addon.Skin.ButtonState(preview,false,true,false) end)
        preview:SetScript("OnClick",function() input:ClearFocus(); self:Preview() end)
        page.volumeLabel=label("",12,16,-92,300,sound)
        local slider=CreateFrame("Slider",nil,sound,"BackdropTemplate"); page.volume=slider
        slider:SetPoint("TOPLEFT",16,-116); slider:SetSize(300,18); slider:SetOrientation("HORIZONTAL")
        addon.Skin.Paint(slider,"edit"); slider:SetMinMaxValues(0,100); slider:SetValueStep(10); slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
        slider:GetThumbTexture():SetSize(12,22); slider:GetThumbTexture():SetVertexColor(unpack(addon.Skin.colors.gold))
        slider:SetScript("OnValueChanged",function(_,value)
            self.settings.volume=math.max(0,math.min(100,math.floor(value/10+0.5)*10))
            page.volumeLabel:SetText("Alert volume")
            self:StopSound()
        end)
        addon.Skin.InlineSlider(slider,"%",10)
        page.soundHint=label("The alarm plays once when the warning starts. Volume follows game Master volume.\nDisable an equivalent WeakAura to avoid duplicate warnings.",12,16,-126,300,sound)
        page:SetScript("OnHide",function() input:ClearFocus() end)
    end
    if not self.page then return end
    local page=self.page
    page:ClearAllPoints(); page:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y); page:SetSize(width,height)
    addon.Skin.SettingsHeader(page,width,page.title,page.subtitle)
    addon.Skin.LayoutSections(page,width)
    local warning,sound=page.sectionCards[1],page.sectionCards[2]
    page.preview:SetWidth(warning:GetWidth()-32)
    page.volumeLabel:SetWidth(104)
    page.volume:ClearAllPoints(); page.volume:SetPoint("TOPLEFT",126,-86); page.volume:SetWidth(sound:GetWidth()-142)
    page.soundHint:SetWidth(sound:GetWidth()-32)
    page:SetShown(visible)
    page.volume:SetValue(self.settings.volume)
    page.volumeLabel:SetText("Alert volume")
    for key,box in pairs(page.checks) do box:SetChecked(self.settings[key]); box.mark:SetText(self.settings[key] and "X" or "") end
    if not page.threshold:HasFocus() then page.threshold:SetText(tostring(self.settings.threshold)) end
end

local events=CreateFrame("Frame")
H.events=events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,unit)
    if event=="ADDON_LOADED" then
        if unit~=addonName then return end
        H:Initialize(); events:UnregisterEvent("ADDON_LOADED")
        for _,name in ipairs({"UNIT_HEALTH","UNIT_MAXHEALTH","PLAYER_ENTERING_WORLD","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST"}) do events:RegisterEvent(name) end
    elseif unit==nil or unit=="player" or event=="PLAYER_ENTERING_WORLD" then
        H:Update()
    end
end)
