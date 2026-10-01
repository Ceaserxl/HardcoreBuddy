local _,A=...
local M,Skin=A.MapAdvisor,A.Skin

function M:OpenTintPicker()
    local picker=ColorPickerFrame
    if not picker then A:Print("Blizzard's color picker is unavailable."); return end
    picker:Hide()
    self.tintRevision=(self.tintRevision or 0)+1
    local revision=self.tintRevision
    local s=self:Settings()
    local r,g,b=s.tintR,s.tintG,s.tintB
    local function apply(red,green,blue)
        if M.tintRevision~=revision then return end
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

local resetKeys={
    exploration={"reveal","tintR","tintG","tintB","tintAlpha"},
    markers={"rare","elite","boss","danger","icons","iconSize","iconAlpha"},
    notices={"notify"},
}
function M:ResetSettings(section)
    local s=self:Settings()
    if section=="all" then
        for _,keys in pairs(resetKeys) do for _,key in ipairs(keys) do s[key]=nil end end
    else for _,key in ipairs(resetKeys[section] or {}) do s[key]=nil end end
    if section=="all" or section=="exploration" then self.tintRevision=(self.tintRevision or 0)+1 end
    self:Changed()
end
function M:SettingsHeight() return 714 end

function M:LayoutSettings(parent,left,top,width,visible)
    local picking=visible and A.state.mapIconKind~=nil
    self:LayoutIconPicker(parent,left,top,width,picking)
    visible=visible and not picking
    if not self.controls and not visible then return 0 end
    local s=self:Settings()
    if not self.controls then
        local f=CreateFrame("Frame",nil,parent); self.controls=f
        f.buttons={}; f.modes={}; f.checks={}; f.sliders={}; f.icons={}
        local function label(parent,text,x,y,w,size)
            local l=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            l:SetFont(STANDARD_TEXT_FONT,size or 12,""); l:SetPoint("TOPLEFT",x,-y)
            l:SetWidth(w); l:SetJustifyH("LEFT"); l:SetText(text); return l
        end
        local function button(parent,text,x,y,w,click)
            local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
            b:SetSize(w,28); b:SetPoint("TOPLEFT",x,-y); Skin.Button(b,"utility")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints()
            b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE"); b.label:SetText(text)
            b:SetScript("OnClick",click); f.buttons[#f.buttons+1]=b; return b
        end
        label(f,"Map",12,12,480,22):SetTextColor(unpack(Skin.colors.gold))
        label(f,"Choose how terrain, NPC markers and zone notices appear.",12,46,700)
        f.resetAll=button(f,"Reset all",0,12,120,function() M:ResetSettings("all") end)
        f.resetAll:ClearAllPoints(); f.resetAll:SetPoint("TOPRIGHT",-12,-12)
        local function section(name,title,description,y,height)
            local panel=CreateFrame("Frame",nil,f,"BackdropTemplate"); Skin.Paint(panel,"card")
            panel:SetPoint("TOPLEFT",12,-y); panel:SetSize(720,height)
            label(panel,title,16,16,460,15):SetTextColor(unpack(Skin.colors.gold))
            label(panel,description,16,44,680)
            local reset=button(panel,"Reset",0,12,120,function() M:ResetSettings(name) end)
            reset:ClearAllPoints(); reset:SetPoint("TOPRIGHT",-16,-12)
            return panel,reset
        end
        f.exploration,f.resetExploration=section("exploration","Exploration","Choose how undiscovered areas look on the map.",82,202)
        f.markers,f.resetMarkers=section("markers","NPC markers","Choose visible categories and click an icon to change it.",296,284)
        f.notices,f.resetNotices=section("notices","Zone notices","A quiet reminder of known dangers when you enter a zone.",592,110)
        for i,mode in ipairs({{"off","Unchanged"},{"full","Reveal all"},{"tint","Tint unexplored"}}) do
            local key=mode[1]
            f.modes[key]=button(f.exploration,mode[2],16+(i-1)*232,70,216,function() M:Settings().reveal=key; M:Changed() end)
        end
        local function check(parent,key,caption,x,y,w)
            local b=CreateFrame("CheckButton",nil,parent,"BackdropTemplate"); b:SetSize(22,22); b:SetPoint("TOPLEFT",x,-y); Skin.Paint(b,"edit")
            b.mark=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.mark:SetAllPoints(); b.mark:SetText("X")
            label(parent,caption,x+30,y+4,w)
            b:SetScript("OnClick",function() M:Settings()[key]=not not b:GetChecked(); M:Changed() end)
            f.checks[key]=b
        end
        local function slider(parent,key,caption,x,y,w,low,high,default,multiplier,suffix)
            local text=label(parent,"",x,y,w)
            local b=CreateFrame("Slider",nil,parent,"BackdropTemplate"); b:SetPoint("TOPLEFT",x,-y-23); b:SetSize(w,18)
            b.caption=text
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
                M.appearanceAt=GetTime()+0.05
                local settings=M:Settings(); f.swatch:SetVertexColor(settings.tintR,settings.tintG,settings.tintB,settings.tintAlpha)
            end)
            f.sliders[key]=b
        end
        f.tintColor=button(f.exploration,"Choose tint color",16,126,216,function() M:OpenTintPicker() end)
        f.swatch=f.tintColor:CreateTexture(nil,"ARTWORK"); f.swatch:SetTexture("Interface\\Buttons\\WHITE8x8")
        f.swatch:SetPoint("RIGHT",-10,0); f.swatch:SetSize(18,18)
        slider(f.exploration,"tintAlpha","Tint opacity",376,116,328,0,100,0.55,100,"%")
        label(f.exploration,"Color and opacity apply to Tint unexplored.",16,174,680)
        for i,kind in ipairs({"rare","elite","boss","danger"}) do
            local key=kind
            local caption=({rare="Rares",elite="Elites",boss="World bosses",danger="Dangerous NPCs"})[kind]
            check(f.markers,key,caption,16,78+(i-1)*36,175)
            f.icons[key]=button(f.markers,"",240,74+(i-1)*36,464,function()
                A.state.mapIconKind=key; A.Settings.scroll:SetVerticalScroll(0); A:Refresh(true)
            end)
        end
        slider(f.markers,"iconSize","Icon size",16,230,328,12,40,18,1," px")
        slider(f.markers,"iconAlpha","Icon opacity",376,230,328,10,100,1,100,"%")
        check(f.notices,"notify","Silent zone-entry notice (chat only)",16,72,650)
    end
    local f=self.controls; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/744); local baseWidth=width/scale
    f:SetScale(scale); f:SetSize(baseWidth,self:SettingsHeight())
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left/scale,-top/scale)
    local panelWidth=baseWidth-24
    for _,panel in ipairs({f.exploration,f.markers,f.notices}) do panel:SetWidth(panelWidth) end
    local modeWidth=(panelWidth-56)/3
    for i,key in ipairs({"off","full","tint"}) do
        local b=f.modes[key]; b:SetWidth(modeWidth); b:ClearAllPoints(); b:SetPoint("TOPLEFT",16+(i-1)*(modeWidth+12),-70)
        Skin.ButtonState(b,s.reveal==key,nil,false)
    end
    for key,b in pairs(f.checks) do b:SetChecked(s[key]); b.mark:SetText(s[key] and "X" or "") end
    for _,b in pairs(f.sliders) do b:Sync() end
    local sliderWidth=(panelWidth-56)/2
    f.sliders.iconSize:SetWidth(sliderWidth)
    for _,key in ipairs({"iconAlpha","tintAlpha"}) do
        local b=f.sliders[key]; b:SetWidth(sliderWidth); b:ClearAllPoints()
        b:SetPoint("TOPLEFT",40+sliderWidth,-(key=="iconAlpha" and 253 or 139))
        b.caption:ClearAllPoints(); b.caption:SetPoint("TOPLEFT",40+sliderWidth,-(key=="iconAlpha" and 230 or 116)); b.caption:SetWidth(sliderWidth)
    end
    for key,b in pairs(f.icons) do b:SetWidth(panelWidth-256); b.label:SetText(self:IconLabel(key,true)) end
    f.swatch:SetVertexColor(s.tintR,s.tintG,s.tintB,s.tintAlpha)
    return self:SettingsHeight()*scale
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
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(M:IconName(key),1,0.8,0.4,1,true)
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
        Skin.ButtonState(b,selected,nil,false)
    end
end

M.events:HookScript("OnUpdate",function()
    if M.appearanceAt and GetTime()>=M.appearanceAt then
        M.appearanceAt=nil; M:Attach(); M:RefreshPins()
    end
end)
