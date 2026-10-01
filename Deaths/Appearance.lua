local _,A=...
local H=A.Deaths
local styles={Compact={520,58,20,14,18,8,34},Banner={896,80,28,16,80,12,49},["Text-only"]={520,52,20,14,12,4,30}}
local function label(parent,size,x,y,width,value)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size,""); f:SetPoint("TOPLEFT",x,y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetWordWrap(true); f:SetText(value or "")
    return f
end
local function button(parent,title,width,x,y,action)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(width,28); b:SetPoint("TOPLEFT",x,y)
    b.label=label(b,12,0,0,width,title); b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    A.Skin.Button(b,"utility"); b:SetScript("OnClick",action)
    b:SetScript("OnEnter",function() A.Skin.ButtonState(b,b.selected,true,false) end)
    b:SetScript("OnLeave",function() A.Skin.ButtonState(b,b.selected,false,false) end)
    return b
end
function H:ApplyAppearance()
    local s,a=self.db.settings,self.alert
    if not styles[s.alertStyle] then s.alertStyle="Compact" end
    local value=tonumber(s.backgroundOpacity)
    s.backgroundOpacity=value and value==value and math.max(0,math.min(100,value)) or 65
    local style=styles[s.alertStyle]
    a:SetSize(style[1],style[2]); a.nameSize=style[3]; a.detailSize=style[4]; a.nameMinimum=style[3]-4
    for i,fs in ipairs({a.name,a.description}) do
        fs:ClearAllPoints(); fs:SetPoint("TOPLEFT",style[5],-style[5+i])
        fs:SetSize(style[1]-style[5]*2,i==1 and style[3]+4 or style[4]+4)
        fs:SetFont(STANDARD_TEXT_FONT,i==1 and style[3] or style[4],"")
    end
    local alpha=s.backgroundOpacity/100
    for _,art in ipairs(a.artParts) do art:SetShown(s.alertStyle=="Banner"); art:SetAlpha(alpha) end
    a.rule:SetShown(s.alertStyle=="Banner"); a.rule:SetAlpha(alpha)
    if a.flat then a.flat:SetShown(s.alertStyle=="Compact"); a.flat:SetAlpha(alpha) end
    a.dragHandle:SetHeight(style[2]-16)
    a:EnableMouse(not s.locked or a.positioning==true)
    a.dragHandle:EnableMouse(not s.locked or a.positioning==true)
    if self.appearance then
        self.appearance.opacity:SetValue(s.backgroundOpacity)
        self.appearance.opacityText:SetText("Background opacity: "..math.floor(s.backgroundOpacity).."%")
        for name,b in pairs(self.appearance.styles) do
            b.selected=name==s.alertStyle; A.Skin.ButtonState(b,b.selected,nil,false)
        end
        self.appearance.move.label:SetText(a.positioning and "Save position" or "Unlock and move")
        a.done:SetShown(a.positioning==true)
    end
end
function H:FinishPositioning()
    local a=self.alert
    a:StopMovingOrSizing()
    local point,relativeTo,relative,x,y=a:GetPoint()
    if relativeTo and relativeTo~=UIParent then
        -- Saving without dragging must preserve a RaidWarningFrame-relative
        -- starting position instead of reinterpreting its offsets on UIParent.
        local cx,cy=a:GetCenter()
        local ux,uy=UIParent:GetCenter()
        local ratio=UIParent:GetEffectiveScale()/a:GetEffectiveScale()
        point,relative,x,y="CENTER","CENTER",cx-ux*ratio,cy-uy*ratio
    end
    self.db.positions=self.db.positions or {}; self.db.positions.alert={point,relative,x,y}
    a.positioning=nil; self.db.settings.locked=true; a:Hide(); self:ApplySettings()
end
function H:TogglePositioning()
    if self.alert.positioning then self:FinishPositioning(); return end
    self.db.settings.locked=false; self.alert.positioning=true
    self:ApplySettings(); self:Slash("test")
end
function H:BuildAppearance(host)
    local a=self.alert
    a.flat=a:CreateTexture(nil,"BACKGROUND"); a.flat:SetAllPoints(a)
    a.flat:SetColorTexture(0.025,0.03,0.035,1); a.flat:AddMaskTexture(a.cornerMask)
    a.done=button(a,"Save position",132,0,0,function() self:FinishPositioning() end)
    a.done:ClearAllPoints(); a.done:SetPoint("TOPLEFT",a,"BOTTOMLEFT",0,-8); a.done:Hide()
    local f=CreateFrame("Frame",nil,host,"BackdropTemplate"); self.appearance=f
    f:SetAllPoints(host); A.Skin.Paint(f,"card"); f:Hide()
    label(f,22,20,-18,700,"Death alert appearance"):SetTextColor(unpack(A.Skin.colors.gold))
    label(f,12,20,-56,700,"Choose how much space a death report takes. Background opacity leaves text readable.")
    f.styles={}
    for i,name in ipairs({"Compact","Banner","Text-only"}) do
        f.styles[name]=button(f,name,140,20+(i-1)*152,-100,function()
            self.db.settings.alertStyle=name; self:ApplySettings(); self:Slash("test")
        end)
    end
    f.opacityText=label(f,13,20,-166,500)
    local slider=CreateFrame("Slider",nil,f,"BackdropTemplate"); f.opacity=slider
    slider:SetPoint("TOPLEFT",20,-196); slider:SetSize(300,18); slider:SetOrientation("HORIZONTAL")
    A.Skin.Paint(slider,"edit"); slider:SetMinMaxValues(0,100); slider:SetValueStep(5); slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    slider:GetThumbTexture():SetSize(12,22); slider:GetThumbTexture():SetVertexColor(unpack(A.Skin.colors.gold))
    slider:SetScript("OnValueChanged",function(_,value)
        self.db.settings.backgroundOpacity=math.max(0,math.min(100,value))
        f.opacityText:SetText("Background opacity: "..math.floor(value).."%")
        for _,art in ipairs(a.artParts) do art:SetAlpha(value/100) end
        a.flat:SetAlpha(value/100); a.rule:SetAlpha(value/100)
    end)
    f.move=button(f,"Unlock and move",180,20,-256,function() self:TogglePositioning() end)
    f.preview=button(f,"Preview alert",140,212,-256,function() self:Slash("test") end)
    button(f,"Reset position",140,364,-256,function() self:Slash("resetposition") end)
    label(f,12,20,-310,690,"Unlock and move keeps a silent preview on screen. Drag the alert, then click Save position. Locked alerts let clicks pass through to the game.")
    label(f,12,20,-372,690,"Duration, sound, volume and live feed controls are above. Your saved position is shared by all three styles.")
end
