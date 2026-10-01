-- Native Classic artwork and a restrained field-journal palette.
local addonName, addon = ...
local S = {}
addon.Skin = S
S.windowWidth,S.windowHeight=1040,660
S.colors = {
    gold={0.94,0.76,0.43}, white={0.94,0.90,0.79}, muted={0.65,0.65,0.56},
    green={0.52,0.77,0.47}, red={0.89,0.38,0.30}, amber={0.96,0.67,0.30},
    bronze={0.55,0.39,0.19}, moss={0.27,0.34,0.21}, oxblood={0.35,0.12,0.09},
}

local WHITE="Interface\\Buttons\\WHITE8x8"
local DARK="Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local BORDER="Interface\\DialogFrame\\UI-DialogBox-Border"
local MEDIA="Interface\\AddOns\\"..addonName.."\\Media\\"
local BUTTON="Interface\\Buttons\\UI-Panel-Button-"
local styles={
    window={background=WHITE,tile=false,edge=BORDER,edgeSize=32,insets={left=11,right=12,top=12,bottom=11},
        fill={0.025,0.030,0.035,1},border={0.86,0.69,0.42,1}},
    card={background=WHITE,edge=WHITE,edgeSize=1,insets={left=1,right=1,top=1,bottom=1},
        fill={0.020,0.026,0.031,0.88},border={0.30,0.29,0.23,0.72}},
    row={background=WHITE,edgeSize=0,insets={left=0,right=0,top=0,bottom=0},
        fill={0.045,0.050,0.055,1},border={0.32,0.28,0.17,0}},
    note={background=WHITE,edgeSize=0,insets={left=0,right=0,top=0,bottom=0},
        fill={0,0,0,0},border={0,0,0,0}},
    edit={background=WHITE,edge=WHITE,edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1},fill={0.065,0.075,0.085,1},border={0.34,0.36,0.38,1}},
    menu={background=DARK,edge=BORDER,edgeSize=16,insets={left=5,right=5,top=5,bottom=5},
        fill={0.85,0.79,0.65,1},border={0.82,0.67,0.42,1}},
}

function S.Paint(frame,kind)
    local style=styles[kind] or styles.card
    frame:SetBackdrop({bgFile=style.background,edgeFile=style.edge,tile=style.tile~=false,tileEdge=true,
        tileSize=style.tileSize or 32,edgeSize=style.edgeSize,insets=style.insets})
    frame:SetBackdropColor(unpack(style.fill))
    frame:SetBackdropBorderColor(unpack(style.border))
    frame.skinKind=kind
    if kind=="edit" and frame.GetObjectType and frame:GetObjectType()=="CheckButton" then S.Hover(frame) end
    if kind=="edit" and not frame.flatEditHooks then
        frame.flatEditHooks=true
        frame:HookScript("OnEnter",function(self) self:SetBackdropBorderColor(0.72,0.56,0.29,1) end)
        frame:HookScript("OnLeave",function(self) self:SetBackdropBorderColor(0.34,0.36,0.38,1) end)
    end
    if kind=="row" then S.RowArtwork(frame)
    elseif frame.rowArt then for _,part in ipairs(frame.rowArt) do part:Hide() end end
end

local function texture(parent,layer,sublevel,path)
    local t=parent:CreateTexture(nil,layer,nil,sublevel)
    t:SetTexture(path or WHITE)
    return t
end

-- Native button highlights keep row colors and item borders intact while using
-- the same flat gold wash as navigation tabs (including child icon hit areas).
function S.Hover(button,enabled)
    if enabled==false then button:ClearHighlightTexture(); return end
    button:SetHighlightTexture(type(enabled)=="string" and enabled or WHITE,"BLEND")
    local highlight=button:GetHighlightTexture()
    highlight:SetVertexColor(unpack(S.colors.gold)); highlight:SetAlpha(0.24)
end

function S.Unsnap(region)
    if region.SetSnapToPixelGrid then region:SetSnapToPixelGrid(false) end
    if region.SetTexelSnappingBias then region:SetTexelSnappingBias(0) end
end
function S.RowArtwork(frame)
    -- Rows use the flat backdrop fill; retire any previously created artwork.
    if frame.rowArt then for _,part in ipairs(frame.rowArt) do part:Hide() end end
end
function S.Divider(parent)
    local line=texture(parent,"ARTWORK",0)
    line:SetHeight(1)
    line:SetVertexColor(0.68,0.48,0.23,0.64)
    return line
end

function S.DecorateWindow(frame)
    if frame.skinChrome then return frame.skinChrome end
    local chrome={}
    frame.skinChrome=chrome
    S.Paint(frame,"window")
    chrome.headerBase=texture(frame,"BACKGROUND",0)
    chrome.headerBase:SetVertexColor(9/255,12/255,12/255,1)
    chrome.banner=texture(frame,"BACKGROUND",1,MEDIA.."JourneyBanner")
    chrome.banner:SetVertexColor(1,1,1,1)
    chrome.bannerBlend=texture(frame,"BACKGROUND",2)
    chrome.bannerBlend:SetBlendMode("BLEND")
    chrome.bannerBlend:SetGradient("HORIZONTAL",CreateColor(9/255,12/255,12/255,0.65),CreateColor(9/255,12/255,12/255,0))
    chrome.bannerShade=texture(frame,"BACKGROUND",3)
    chrome.bannerShade:SetVertexColor(0.025,0.031,0.020,0.06)
    chrome.bannerShade:SetAllPoints(chrome.headerBase)
    chrome.crest=texture(frame,"ARTWORK",1,MEDIA.."SurvivorShield")
    chrome.crest:SetVertexColor(1,1,1,1)
    chrome.topline=S.Divider(frame)
    chrome.toplineShadow=texture(frame,"ARTWORK",0)
    chrome.toplineShadow:SetVertexColor(0,0,0,0.82)
    chrome.toplineShadow:SetHeight(1)
    chrome.bottomline=S.Divider(frame)
    chrome.bottomline:SetVertexColor(0.47,0.36,0.18,0.55)
    chrome.footer=texture(frame,"BACKGROUND",1,DARK)
    chrome.footer:SetVertexColor(0.53,0.51,0.38,0.74)
    chrome.leftAccent=texture(frame,"BORDER",0)
    chrome.leftAccent:SetVertexColor(0.42,0.30,0.14,0.32)
    chrome.rightAccent=texture(frame,"BORDER",0)
    chrome.rightAccent:SetVertexColor(0.42,0.30,0.14,0.32)
    return chrome
end

function S.LayoutWindow(frame,width,height,compact)
    local chrome=S.DecorateWindow(frame)
    local headerHeight=frame.headerHeight or (height<500 and 64 or compact and 78 or 106)
    local bannerWidth=math.max(1,width-16)
    local bannerHeight=math.max(42,headerHeight-8)
    chrome.headerBase:ClearAllPoints()
    chrome.headerBase:SetPoint("TOPLEFT",frame,"TOPLEFT",8,-8)
    chrome.headerBase:SetSize(bannerWidth,bannerHeight)
    -- Fill the entire header without stretching the panorama. Crop equally
    -- from the vertical edges when the header is wider than the source strip.
    local sourceAspect=2172/240
    local targetAspect=bannerWidth/bannerHeight
    local u,v=math.min(1,targetAspect/sourceAspect),math.min(1,sourceAspect/targetAspect)
    chrome.banner:ClearAllPoints()
    chrome.banner:SetAllPoints(chrome.headerBase)
    chrome.banner:SetTexCoord((1-u)/2,(1+u)/2,(1-v)/2,(1+v)/2)
    chrome.banner:SetAlpha(1)
    chrome.bannerBlend:ClearAllPoints()
    chrome.bannerBlend:SetPoint("TOPLEFT",chrome.banner,"TOPLEFT",0,0)
    chrome.bannerBlend:SetSize(math.min(380,bannerWidth*0.4),bannerHeight)
    chrome.crest:ClearAllPoints()
    chrome.crest:SetPoint("LEFT",chrome.headerBase,"LEFT",13,0)
    local crestSize=math.min(92,bannerHeight)
    chrome.crest:SetSize(crestSize,crestSize)
    chrome.topline:ClearAllPoints()
    chrome.topline:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-headerHeight)
    chrome.topline:SetWidth(math.max(1,width-36))
    chrome.toplineShadow:ClearAllPoints()
    chrome.toplineShadow:SetPoint("TOPLEFT",frame,"TOPLEFT",18,-headerHeight-1)
    chrome.toplineShadow:SetWidth(math.max(1,width-36))
    chrome.bottomline:ClearAllPoints()
    chrome.bottomline:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",18,37)
    chrome.bottomline:SetWidth(math.max(1,width-36))
    chrome.footer:ClearAllPoints()
    chrome.footer:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",14,13)
    chrome.footer:SetSize(math.max(1,width-28),24)
    chrome.leftAccent:ClearAllPoints()
    chrome.leftAccent:SetPoint("TOPLEFT",frame,"TOPLEFT",13,-headerHeight-1)
    chrome.leftAccent:SetSize(1,math.max(1,height-headerHeight-40))
    chrome.rightAccent:ClearAllPoints()
    chrome.rightAccent:SetPoint("TOPRIGHT",frame,"TOPRIGHT",-13,-headerHeight-1)
    chrome.rightAccent:SetSize(1,math.max(1,height-headerHeight-40))
    return headerHeight
end

local coordinates={
    left={0,0.09375,0,0.6875}, middle={0.09375,0.53125,0,0.6875}, right={0.53125,0.625,0,0.6875},
}
function S.Button(button,kind)
    local skin=button.skinButton
    if not skin then
        skin={}; button.skinButton=skin
        -- Supply the same interaction states for every styled button, including
        -- utility buttons whose callers only install a click handler.
        button:HookScript("OnEnter",function(self) S.ButtonState(self,nil,true,false) end)
        button:HookScript("OnLeave",function(self) S.ButtonState(self,nil,false,false) end)
        button:HookScript("OnMouseDown",function(self) S.ButtonState(self,nil,nil,true) end)
        button:HookScript("OnMouseUp",function(self) S.ButtonState(self,nil,nil,false) end)
        button:HookScript("OnHide",function(self) S.ButtonState(self,nil,false,false) end)
        button:SetScript("OnSizeChanged",function(self) S.ButtonState(self) end)
        button:SetBackdrop(nil)
        skin.left=texture(button,"BACKGROUND",0)
        skin.middle=texture(button,"BACKGROUND",0)
        skin.right=texture(button,"BACKGROUND",0)
        skin.highlight=texture(button,"ARTWORK",1,BUTTON.."Highlight")
        skin.highlight:SetTexCoord(0,0.625,0,0.6875)
        skin.highlight:SetBlendMode("ADD")
        skin.highlight:SetAllPoints(button)
        for _,part in ipairs({"left","middle","right"}) do skin[part]:SetTexCoord(unpack(coordinates[part])) end
        if button.label then
            button.label:SetShadowColor(0,0,0,1)
            button.label:SetShadowOffset(0,-1)
        end
    end
    skin.kind=kind or skin.kind or "normal"
    S.ButtonState(button)
    return skin
end

function S.ButtonState(button,active,hovered,pressed)
    local skin=button.skinButton
    if not skin then return end
    if active~=nil then skin.active=active end
    if hovered~=nil then skin.hovered=hovered end
    if pressed~=nil then skin.pressed=pressed end
    local enabled=button:IsEnabled()
    do
        for _,part in ipairs({skin.left,skin.middle,skin.right,skin.highlight}) do part:Hide() end
        button:SetBackdrop({bgFile=WHITE,edgeFile=WHITE,edgeSize=1})
        local selected=skin.active
        local shade=skin.pressed and 0.065 or skin.hovered and 0.105 or selected and 0.085 or 0.040
        button:SetBackdropColor(shade,shade+0.006,shade+0.009,1)
        button:SetBackdropBorderColor(selected and 0.48 or 0.16,selected and 0.37 or 0.17,selected and 0.19 or 0.18,1)
        do
            -- A full-width gold wash makes hover and selection unmistakable.
            skin.highlight:SetTexture(WHITE)
            skin.highlight:SetTexCoord(0,1,0,1)
            skin.highlight:SetBlendMode("BLEND")
            skin.highlight:SetVertexColor(0.94,0.76,0.43,1)
            skin.highlight:SetAlpha(not enabled and 0 or skin.pressed and 0.10 or skin.hovered and 0.24 or selected and 0.15 or 0)
            skin.highlight:Show()
            if enabled and skin.hovered then button:SetBackdropBorderColor(0.72,0.56,0.29,1) end
        end
        if not skin.indicator then skin.indicator=texture(button,"ARTWORK",1) end
        skin.indicator:ClearAllPoints()
        if skin.kind=="tab" then
            skin.indicator:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1)
            skin.indicator:SetPoint("BOTTOMRIGHT",button,"BOTTOMRIGHT",-1,1)
            skin.indicator:SetHeight(2)
        else
            skin.indicator:SetPoint("TOPLEFT",button,"TOPLEFT",1,-1)
            skin.indicator:SetPoint("BOTTOMLEFT",button,"BOTTOMLEFT",1,1)
            skin.indicator:SetWidth(2)
        end
        skin.indicator:SetVertexColor(unpack(S.colors.gold)); skin.indicator:SetShown(selected and enabled and (skin.kind=="tab" or skin.kind=="category"))
        if button.label then button.label:SetTextColor(unpack(not enabled and S.colors.muted or (selected or skin.hovered) and S.colors.gold or S.colors.white)) end
        return
    end

end

-- Return navigation belongs directly above the content, aligned to its left edge.
function S.PlaceBackButton(button,parent,top,left,height)
    button:ClearAllPoints()
    button:SetSize(100,height or 28)
    button:SetPoint("TOPLEFT",parent,"TOPLEFT",left or 22,-top)
end

function S.IconBorder(parent,icon)
    local frame=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    frame:EnableMouse(false)
    frame:SetPoint("TOPLEFT",icon,"TOPLEFT",-1,1)
    frame:SetPoint("BOTTOMRIGHT",icon,"BOTTOMRIGHT",1,-1)
    frame:SetFrameLevel(parent:GetFrameLevel()+1)
    frame:SetBackdrop({edgeFile=WHITE,edgeSize=1})
    frame:SetBackdropBorderColor(0.42,0.40,0.32,1)
    return frame
end
