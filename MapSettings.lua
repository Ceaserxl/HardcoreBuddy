local _,A=...
local M,Skin=A.MapAdvisor,A.Skin

function M:OpenTintPicker()
    local picker=ColorPickerFrame
    if not picker then A:Print("Blizzard's color picker is unavailable."); return end
    picker:Hide()
    local s=self:Settings()
    local r,g,b=s.tintR,s.tintG,s.tintB
    local function apply(red,green,blue)
        local settings=M:Settings()
        settings.tintR,settings.tintG,settings.tintB=red,green,blue
        M.appearanceAt=GetTime()+0.05
        if M.controls then M.controls.swatch:SetVertexColor(red,green,blue,settings.tintAlpha) end
    end
    local changed=function() apply(picker:GetColorRGB()) end
    local cancel=function() apply(r,g,b) end
    picker:SetFrameStrata("FULLSCREEN_DIALOG")
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({r=r,g=g,b=b,hasOpacity=false,swatchFunc=changed,cancelFunc=cancel})
    else
        picker.hasOpacity=false; picker.opacityFunc=nil
        picker.func=nil; picker:SetColorRGB(r,g,b)
        picker.func=changed; picker.cancelFunc=cancel; picker:Show()
    end
end

function M:LayoutSettings(parent,left,top,width,visible)
    local picking=visible and A.state.mapIconKind~=nil
    self:LayoutIconPicker(parent,left,top,width,picking)
    visible=visible and not picking
    if not self.controls and not visible then return 0 end
    local s=self:Settings()
    if not self.controls then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.controls=f; Skin.Paint(f,"card")
        local function label(text,x,y,w)
            local l=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); l:SetFont(STANDARD_TEXT_FONT,12,"")
            l:SetPoint("TOPLEFT",x,-y); l:SetWidth(w); l:SetJustifyH("LEFT"); l:SetText(text); return l
        end
        local function button(text,x,y,w,click)
            local b=CreateFrame("Button",nil,f,"BackdropTemplate"); b:SetSize(w,28); b:SetPoint("TOPLEFT",x,-y); Skin.Button(b,"utility")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(text)
            b:SetScript("OnClick",click); return b
        end
        label("Map",16,12,700):SetTextColor(unpack(Skin.colors.gold))
        label("Choose how unexplored terrain and known NPCs appear on your map.",16,37,700)
        f.modes={}
        for i,mode in ipairs({{"off","Unchanged"},{"full","Reveal all"},{"tint","Tint unexplored"}}) do
            local key=mode[1]
            f.modes[key]=button(mode[2],16+(i-1)*232,65,220,function() M:Settings().reveal=key; M:Changed() end)
        end
        f.checks={}
        local function check(key,caption,x,y,w)
            local b=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); b:SetSize(22,22); b:SetPoint("TOPLEFT",x,-y); Skin.Paint(b,"edit")
            b.mark=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.mark:SetAllPoints(); b.mark:SetText("X")
            label(caption,x+30,y+4,w)
            b:SetScript("OnClick",function() M:Settings()[key]=not not b:GetChecked(); M:Changed() end); f.checks[key]=b
        end
        for i,kind in ipairs({"danger","rare","elite","boss"}) do check(kind,({danger="Dangerous",rare="Rares",elite="Elites",boss="World bosses"})[kind],16+(i-1)*177,108,135) end
        check("notify","Silent zone-entry notice (chat only)",16,146,650)
        label("Unexplored tint color",16,190,700):SetTextColor(unpack(Skin.colors.gold))
        f.swatch=f:CreateTexture(nil,"ARTWORK"); f.swatch:SetTexture("Interface\\Buttons\\WHITE8x8"); f.swatch:SetPoint("TOPLEFT",660,-189); f.swatch:SetSize(48,20)
        f.sliders={}
        local function slider(key,caption,x,y,w,low,high,default,multiplier,suffix)
            local text=label("",x,y,w)
            local b=CreateFrame("Slider",nil,f,"BackdropTemplate"); b:SetPoint("TOPLEFT",x,-y-23); b:SetSize(w,18)
            Skin.Paint(b,"edit"); b:SetOrientation("HORIZONTAL"); b:SetMinMaxValues(low,high); b:SetValueStep(1); b:SetObeyStepOnDrag(true)
            b:SetThumbTexture("Interface\\Buttons\\WHITE8x8"); b:GetThumbTexture():SetSize(10,22); b:GetThumbTexture():SetVertexColor(unpack(Skin.colors.gold))
            function b:Sync()
                self.syncing=true
                local value=math.floor((M:Settings()[key] or default)*multiplier+0.5)
                self:SetValue(value); text:SetText(caption..": "..value..suffix); self.syncing=nil
            end
            b:SetScript("OnValueChanged",function(self,value)
                if self.syncing then return end
                value=math.max(low,math.min(high,math.floor(value+0.5)))
                M:Settings()[key]=value/multiplier; text:SetText(caption..": "..value..suffix)
                -- Coalesce dragging: don't rebuild every map pin on each mouse movement.
                M.appearanceAt=GetTime()+0.05
                local settings=M:Settings(); f.swatch:SetVertexColor(settings.tintR,settings.tintG,settings.tintB,settings.tintAlpha)
            end)
            f.sliders[key]=b
        end
        f.tintColor=button("Choose tint color",16,220,210,function() M:OpenTintPicker() end)
        label("Use Blizzard's color picker. Cancel restores the previous color.",253,228,450)
        slider("tintAlpha","Tint opacity",16,280,328,0,100,0.55,100,"%")
        label("0% is transparent; 100% is opaque. Applies to Tint unexplored.",372,289,328)
        label("NPC marker appearance",16,346,700):SetTextColor(unpack(Skin.colors.gold))
        f.icons={}
        for i,kind in ipairs({"rare","elite","boss","danger"}) do
            local key=kind
            local b=button("",16+((i-1)%2)*352,372+math.floor((i-1)/2)*40,340,function()
                A.state.mapIconKind=key; A.Settings.scroll:SetVerticalScroll(0); A:Refresh(true)
            end)
            b.caption=({rare="Rare",elite="Elite",boss="Boss",danger="Dangerous"})[key]; f.icons[key]=b
        end
        label("Choose a category to browse all available icons.",16,450,700)
        slider("iconSize","Icon size",16,480,328,12,40,18,1," px")
        slider("iconAlpha","Icon opacity",372,480,328,10,100,1,100,"%")
        f.restore=button("Reset appearance",16,544,210,function()
            local settings=M:Settings()
            for _,key in ipairs({"tintR","tintG","tintB","tintAlpha","iconSize","iconAlpha","icons"}) do settings[key]=nil end
            M:Changed()
        end)
        label("Click map markers to view NPC models. Recorded spawn areas are not live sightings.",16,590,700)
    end
    local f=self.controls; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/744); f:SetScale(scale); f:SetSize(width/scale,626)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left/scale,-top/scale)
    for key,b in pairs(f.modes) do Skin.ButtonState(b,s.reveal==key,false,false) end
    for key,b in pairs(f.checks) do b:SetChecked(s[key]); b.mark:SetText(s[key] and "X" or "") end
    for _,b in pairs(f.sliders) do b:Sync() end
    for key,b in pairs(f.icons) do b.label:SetText(b.caption..": "..self:IconLabel(key,true)) end
    f.swatch:SetVertexColor(s.tintR,s.tintG,s.tintB,s.tintAlpha)
    return 634*scale
end

function M:IconPickerHeight() return 94+math.ceil(#self.iconChoices/6)*88 end

function M:LayoutIconPicker(parent,left,top,width,visible)
    if not self.iconPicker and not visible then return end
    if not self.iconPicker then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.iconPicker=f; Skin.Paint(f,"card")
        f.title=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f.title:SetPoint("TOPLEFT",16,-16)
        f.title:SetTextColor(unpack(Skin.colors.gold))
        local note=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); note:SetPoint("TOPLEFT",16,-44)
        note:SetText("Choose an icon. Use Back to return to Map settings.")
        f.choices={}
        for i,choice in ipairs(self.iconChoices) do
            local key=choice
            local b=CreateFrame("Button",nil,f,"BackdropTemplate")
            b:SetPoint("TOPLEFT",16+((i-1)%6)*118,-78-math.floor((i-1)/6)*88); b:SetSize(110,80)
            Skin.Button(b,"category")
            b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOP",0,-8); b.icon:SetSize(32,32)
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetPoint("TOP",0,-46)
            b.label:SetSize(102,28); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
            b:SetScript("OnEnter",function(self)
                Skin.ButtonState(self,self.selected,true,false)
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(M:IconName(key))
                GameTooltip:AddLine(self.selected and "Selected" or "Click to use this marker icon.",1,0.8,0.4); GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function(self) Skin.ButtonState(self,self.selected,false,false); GameTooltip:Hide() end)
            b:SetScript("OnHide",function(self) if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
            b:SetScript("OnClick",function()
                M:Settings().icons[A.state.mapIconKind]=key; M:Changed()
            end)
            f.choices[key]=b
        end
    end
    local f=self.iconPicker; f:SetShown(visible); if not visible then return end
    local scale=math.min(1,width/744); f:SetScale(scale); f:SetSize(width/scale,self:IconPickerHeight())
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left/scale,-top/scale)
    local kind=A.state.mapIconKind
    f.title:SetText((({rare="Rare",elite="Elite",boss="World boss",danger="Dangerous"})[kind] or "NPC").." marker icon")
    for key,b in pairs(f.choices) do
        local selected=self:Settings().icons[kind]==key
        b.selected=selected; b.label:SetText(self:IconName(key)); self:SetIconTexture(b.icon,key)
        Skin.ButtonState(b,selected,false,false)
    end
end

M.events:HookScript("OnUpdate",function()
    if M.appearanceAt and GetTime()>=M.appearanceAt then
        M.appearanceAt=nil; M:Attach(); M:RefreshPins()
    end
end)
