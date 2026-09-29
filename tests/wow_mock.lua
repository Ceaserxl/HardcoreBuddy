-- Strict, deliberately small native-UI mock. It is not a game-client emulator.
MOCK = {frames={}, class="HUNTER", level=32, petLevel=20, pet=true, faction="Alliance", messages={}}
STANDARD_TEXT_FONT="Fonts\\FRIZQT__.TTF"
ChatFontNormal={}
WOW_PROJECT_ID, WOW_PROJECT_CLASSIC=2,2
UISpecialFrames, SlashCmdList={},{}
function CreateColor(r,g,b,a)
    assert(type(r)=="number" and type(g)=="number" and type(b)=="number" and (a==nil or type(a)=="number"))
    local color={r=r,g=g,b=b,a=a==nil and 1 or a}
    function color:GetRGBA() return self.r,self.g,self.b,self.a end
    return color
end
local methods={}
function methods:SetMinMaxValues(low,high) self.minimum,self.maximum=low,high end
function methods:SetValueStep(step) self.step=step end
function methods:SetObeyStepOnDrag(value) self.obeyStep=value end
function methods:SetOrientation(value) self.orientation=value end
function methods:SetThumbTexture(path) self.thumb=self:CreateTexture(); self.thumb:SetTexture(path) end
function methods:GetThumbTexture() return self.thumb end
function methods:SetValue(value)
    local changed=self.value~=value; self.value=value
    if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
end
local mt={__index=function(_,key) return methods[key] end}
local function new(kind,name,parent)
    local frame=setmetatable({kind=kind,name=name,parent=parent,shown=true,points={},scripts={},children={},enabled=true,
        mouse=kind=="Button" or kind=="EditBox",justifyV=kind=="EditBox" and "MIDDLE" or nil,creationOrder=#MOCK.frames+1},mt)
    MOCK.frames[#MOCK.frames+1]=frame
    if parent then parent.children[#parent.children+1]=frame end
    if name then _G[name]=frame end
    return frame
end
function CreateFrame(kind,name,parent,template)
    local f=new(kind,name,parent); f.template=template
    if template and template:find("BackdropTemplate",1,true) then
        f.scripts.OnSizeChanged=function(self) self.backdropResizeCalls=(self.backdropResizeCalls or 0)+1 end
    end
    return f
end
function methods:CreateFontString(name,layer,template)
    local region=new("FontString",name,self); region.drawLayer=layer or "OVERLAY"; region.template=template; return region
end
function methods:CreateTexture(name,layer,template,subLevel)
    local region=new("Texture",name,self); region.drawLayer=layer or "ARTWORK"; region.template=template; region.drawSubLevel=subLevel or 0; return region
end
function methods:CreateMaskTexture(name,layer)
    local region=new("MaskTexture",name,self); region.drawLayer=layer or "ARTWORK"; return region
end
function methods:AddMaskTexture(mask)
    self.masks=self.masks or {}; self.masks[#self.masks+1]=mask
end
function methods:SetScript(event,fn) self.scripts[event]=fn end
function methods:HookScript(event,fn)
    assert(type(fn)=="function")
    local previous=self.scripts[event]
    self.scripts[event]=function(...) if previous then previous(...) end; fn(...) end
end
function methods:GetScript(event) return self.scripts[event] end
function methods:RegisterEvent(event) self.events=self.events or {}; self.events[event]=true end
function methods:UnregisterEvent(event) if self.events then self.events[event]=nil end end
function methods:SetPoint(point,a,b,c,d)
    local relative,relativePoint,x,y
    if type(a)=="table" then relative=a; relativePoint=b; x=c or 0; y=d or 0
    else relative=self.parent or UIParent; relativePoint=point; x=a or 0; y=b or 0 end
    for i,p in ipairs(self.points) do if p[1]==point then table.remove(self.points,i); break end end
    self.points[#self.points+1]={point,relative,relativePoint,x,y}
end
function methods:ClearAllPoints() self.points={} end
function methods:SetAllPoints(other)
    other=other or self.parent
    self:ClearAllPoints(); self:SetPoint("TOPLEFT",other,"TOPLEFT",0,0); self:SetPoint("BOTTOMRIGHT",other,"BOTTOMRIGHT",0,0)
end
local anchors={TOPLEFT={0,0},TOP={.5,0},TOPRIGHT={1,0},LEFT={0,.5},CENTER={.5,.5},RIGHT={1,.5},BOTTOMLEFT={0,1},BOTTOM={.5,1},BOTTOMRIGHT={1,1}}
local function relativePoint(p,self)
    local x,y,w,h=p[2]:GetRect()
    local anchor=anchors[p[3]]
    local ratio=p[2]:GetEffectiveScale()/self:GetEffectiveScale()
    return (x+w*anchor[1])*ratio+p[4],(y+h*anchor[2])*ratio-p[5]
end
local function multilineHeight(frame,width)
    local insets=frame.textInsets or {0,0,0,0}
    width=math.max(1,width-insets[1]-insets[2])
    if TEST_MEASURE then
        return TEST_MEASURE(frame.text or "",width,frame.fontSize or 12,frame.fontPath,true)+insets[3]+insets[4]
    end
    local lines=0
    for line in ((frame.text or "").."\n"):gmatch("(.-)\n") do
        lines=lines+math.max(1,math.ceil(#line*(frame.fontSize or 12)*.53/width))
    end
    return lines*((frame.fontSize or 12)+2)+insets[3]+insets[4]
end
function methods:GetRect()
    if self==UIParent then return 0,0,self.width,self.height end
    local p=self.points[1]
    local intrinsic = self.kind=="FontString" and self:GetStringWidth() or 0
    local w,h=self.width or intrinsic,self.height or 0
    if self.kind=="FontString" and not self.height then
        h=TEST_MEASURE and TEST_MEASURE(self.text or "",w,self.fontSize or 12,self.fontPath,self.wordWrap) or (self.fontSize or 12)+2
    end
    if not p then return 0,0,w,self.multiLine and math.max(h,multilineHeight(self,w)) or h end
    local x,y=relativePoint(p,self)
    local a=anchors[p[1]]
    local heightAnchored=false
    if #self.points>1 then
        local q=self.points[2]; local qx,qy=relativePoint(q,self); local b=anchors[q[1]]
        if a[1]~=b[1] then w=(qx-x)/(b[1]-a[1]) end
        if a[2]~=b[2] then h=(qy-y)/(b[2]-a[2]); heightAnchored=true end
    end
    if self.kind=="FontString" and not self.height and not heightAnchored and TEST_MEASURE then h=TEST_MEASURE(self.text or "",w,self.fontSize or 12,self.fontPath,self.wordWrap) end
    -- Blizzard's GuildInfo.xml uses a multiline ScrollChild editbox of height1;
    -- the native EditBox grows with content without an explicit SetHeight call.
    if self.multiLine and not heightAnchored then h=math.max(h,multilineHeight(self,w)) end
    x,y=x-w*a[1],y-h*a[2]
    if self.parent and self.parent.kind=="ScrollFrame" and self.parent.child==self then y=y-(self.parent.scroll or 0) end
    return x,y,w,h
end
function methods:GetWidth() local _,_,w=self:GetRect(); return w end
function methods:GetHeight() local _,_,_,h=self:GetRect(); return h end
function methods:GetCenter()
    local x,y,w,h=self:GetRect()
    return x+w/2,UIParent:GetHeight()*UIParent:GetEffectiveScale()/self:GetEffectiveScale()-(y+h/2)
end
function methods:SetWidth(w)
    assert(type(w)=="number" and w>=0); self.width=w
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,self:GetHeight()) end
end
function methods:SetHeight(h)
    assert(type(h)=="number" and h>=0); self.height=h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,self:GetWidth(),h) end
end
function methods:SetSize(w,h)
    assert(type(w)=="number" and w>=0 and type(h)=="number" and h>=0); self.width,self.height=w,h
    if self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self,w,h) end
end
function methods:SetText(text)
    self.text=tostring(text or "")
    if self.kind=="EditBox" and self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end
end
function methods:GetText() return self.text or "" end
function methods:SetFont(path,size,flags)
    assert(type(path)=="string" and type(size)=="number" and size>0 and (flags==nil or type(flags)=="string"))
    self.fontPath,self.fontSize,self.fontFlags=path,size,flags; return true
end
function methods:SetFontObject(object) self.fontSize=12 end
function methods:SetTextColor(r,g,b,a) self.color={r,g,b,a or 1} end
function methods:SetShadowColor(r,g,b,a) self.shadowColor={r,g,b,a or 1} end
function methods:SetShadowOffset(x,y) self.shadowOffset={x,y} end
function methods:GetStringWidth()
    if TEST_TEXT_WIDTH then return TEST_TEXT_WIDTH(self.text or "",self.fontSize or 12,self.fontPath) end
    return #(self.text or "")*(self.fontSize or 12)*0.53
end
function methods:SetJustifyH(value) self.justifyH=value end
function methods:SetJustifyV(value) self.justifyV=value end
function methods:SetTextInsets(left,right,top,bottom)
    assert(type(left)=="number" and type(right)=="number" and type(top)=="number" and type(bottom)=="number")
    self.textInsets={left,right,top,bottom}
end
function methods:GetStringHeight()
    if not self.text or self.text=="" then return 0 end
    if TEST_MEASURE then return TEST_MEASURE(self.text,self:GetWidth(),self.fontSize or 12,self.fontPath,self.wordWrap) end
    local count=0
    for line in (self.text.."\n"):gmatch("(.-)\n") do count=count+math.max(1,math.ceil(#line*(self.fontSize or 12)*0.53/math.max(1,self:GetWidth()))) end
    return count*((self.fontSize or 12)+2)
end
function methods:Show() local changed=not self.shown; self.shown=true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown; self.shown=false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(value) if value then self:Show() else self:Hide() end end
function methods:SetEnabled(value) self.enabled=value end
function methods:IsEnabled() return self.enabled end
function methods:EnableMouse(value) self.mouse=value end
function methods:IsMouseEnabled() return self.mouse==true end
function methods:EnableKeyboard(value) self.keyboard=value end
function methods:SetAlpha(value) self.alpha=value end
function methods:SetTexture(value)
    assert(value==nil or type(value)=="string" or type(value)=="number","Texture asset must be a path, file ID or nil")
    self.texture=value; self.colorTexture=nil; return true
end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetColorTexture(r,g,b,a)
    assert(type(r)=="number" and type(g)=="number" and type(b)=="number" and (a==nil or type(a)=="number"))
    self.colorTexture={r,g,b,a or 1}; self.texture=nil
end
function methods:SetVertexColor(r,g,b,a)
    assert(type(r)=="number" and type(g)=="number" and type(b)=="number" and (a==nil or type(a)=="number"))
    self.vertexColor={r,g,b,a or 1}
end
function methods:SetGradient(orientation,minColor,maxColor)
    assert(orientation=="HORIZONTAL" or orientation=="VERTICAL","Invalid gradient orientation")
    assert(type(minColor)=="table" and type(minColor.GetRGBA)=="function" and type(maxColor)=="table" and type(maxColor.GetRGBA)=="function",
        "SetGradient requires two ColorMixin values")
    local first,last={minColor:GetRGBA()},{maxColor:GetRGBA()}
    for _,color in ipairs({first,last}) do for i=1,4 do assert(type(color[i])=="number","Gradient channels must be numeric") end end
    self.gradient={orientation=orientation,first=first,last=last}
end
function methods:SetBlendMode(mode)
    assert(mode=="BLEND" or mode=="ADD" or mode=="MOD" or mode=="ALPHAKEY" or mode=="DISABLE")
    self.blendMode=mode
end
function methods:SetDrawLayer(layer,subLevel)
    assert(layer=="BACKGROUND" or layer=="BORDER" or layer=="ARTWORK" or layer=="OVERLAY" or layer=="HIGHLIGHT")
    assert(subLevel==nil or (type(subLevel)=="number" and subLevel>=-8 and subLevel<=7))
    self.drawLayer,self.drawSubLevel=layer,subLevel or 0
end
function methods:GetDrawLayer() return self.drawLayer or "ARTWORK",self.drawSubLevel or 0 end
function methods:SetRotation(radians,originX,originY)
    assert(type(radians)=="number" and (originX==nil or type(originX)=="number") and (originY==nil or type(originY)=="number"))
    self.rotation=radians; self.rotationOrigin={originX or .5,originY or .5}
end
function methods:SetHorizTile(value) self.horizTile=not not value end
function methods:SetVertTile(value) self.vertTile=not not value end
function methods:SetBackdrop(value) self.backdrop=value; if not value then self.background,self.border=nil,nil end end
function methods:SetBackdropColor(r,g,b,a) self.background={r,g,b,a} end
function methods:SetBackdropBorderColor(r,g,b,a) self.border={r,g,b,a or 1} end
function methods:SetFrameStrata(value) self.strata=value end
function methods:GetFrameStrata() return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
function methods:SetScrollChild(child) self.child=child; child:SetPoint("TOPLEFT",self,"TOPLEFT",0,0) end
function methods:SetVerticalScroll(value) assert(value>=0); self.scroll=value end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return math.max(0,self.child:GetHeight()-self:GetHeight()) end
function methods:HasFocus() return self.focus or false end
function methods:ClearFocus() local had=self.focus; self.focus=false; if had and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function methods:SetFocus() self.focus=true end
function methods:SetResizeBounds(a,b,c,d) assert(a<=c and b<=d); self.bounds={a,b,c,d} end
function methods:SetFrameLevel(value) self.frameLevel=value end
function methods:GetFrameLevel()
    if self.kind=="Texture" or self.kind=="FontString" then return self.parent and self.parent:GetFrameLevel() or 0 end
    return self.frameLevel or (self.parent and self.parent:GetFrameLevel()+1) or 0
end
function methods:SetHighlightTexture(value,blendMode)
    assert(type(value)=="string" or type(value)=="number" or (type(value)=="table" and value.kind=="Texture"),
        "SetHighlightTexture requires an asset; use ClearHighlightTexture to clear it")
    assert(blendMode==nil or type(blendMode)=="string","SetHighlightTexture blend mode must be a string")
    self.highlight=value
end
function methods:ClearHighlightTexture() self.highlight=nil end
function methods:SetTexCoord(...) self.texCoord={...} end
function methods:RegisterForClicks(...) self.clicks={...} end
function methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetScale(value) assert(type(value)=="number" and value>0); self.scale=value end
function methods:GetScale() return self.scale or 1 end
function methods:SetResizable(value) self.resizable=not not value end
function methods:IsResizable() return self.resizable or false end
function methods:StartSizing(point) self.sizing=point; MOCK.sizingCalls=(MOCK.sizingCalls or 0)+1 end
function methods:SetWordWrap(value) self.wordWrap=not not value end
function methods:SetMultiLine(value) self.multiLine=not not value end
for _,name in ipairs({"SetClampedToScreen","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","SetAutoFocus","SetNumeric","SetMaxLetters","EnableMouseWheel","UpdateScrollChildRect","SetCursorPosition"}) do
    methods[name]=function() end
end
UIParent=new("Frame","UIParent"); UIParent.width,UIParent.height=1920,1080
Minimap=new("Frame","Minimap",UIParent); Minimap:SetSize(140,140); Minimap:SetPoint("TOPRIGHT",-20,-20)
MOCK.time=1
function GetTime() return MOCK.time end
function GetCursorPosition() return MOCK.cursorX or 0, MOCK.cursorY or 0 end
GameTooltip=new("Tooltip","GameTooltip",UIParent)
function GameTooltip:SetOwner(owner,anchor) self.owner=owner; self.lines={}; self.hyperlink=nil end
function GameTooltip:ClearLines() self.lines={}; self.hyperlink=nil end
function GameTooltip:SetText(text,r,g,b,alpha,wrap)
    assert(type(alpha)=="number" and alpha>=0 and alpha<=1,"Tooltip alpha must be numeric")
    self.lines={text}
end
function GameTooltip:AddLine(text,r,g,b,wrap) self.lines[#self.lines+1]=text end
function GameTooltip:SetHyperlink(link)
    assert(link:match('^item:%d+$')); self.hyperlink=link
    if MOCK.missingItem then error('uncached item') end
    self.lines=MOCK.emptyItem and {} or {link}
end
function GameTooltip:NumLines() return #(self.lines or {}) end
function UnitClass(unit) return MOCK.class,MOCK.class end
function UnitFactionGroup(unit) assert(unit=="player"); return MOCK.faction,MOCK.faction end
function UnitLevel(unit) return unit=="pet" and MOCK.petLevel or MOCK.level end
function UnitExists(unit) if unit=="pet" then return MOCK.pet else return true end end
DEFAULT_CHAT_FRAME={AddMessage=function(_,message) MOCK.messages[#MOCK.messages+1]=message end}
function MOCK.Fire(event,arg)
    local f=TestAddon.events
    if f.events and f.events[event] then f.scripts.OnEvent(f,event,arg) end
end
function MOCK.Click(frame) assert(frame.enabled); frame.scripts.OnClick(frame,"LeftButton") end

-- Coordinates use GetRect's top-down convention, not native GetCursorPosition.
-- Equal-strata/equal-level siblings use creation order as a deterministic tie
-- break. Tests must also assert non-overlap for controls near a drag region;
-- the client can change sibling ordering as frames are raised or shown.
local strataOrder={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
local function contains(frame,x,y)
    local left,top,width,height=frame:GetRect()
    return width>0 and height>0 and x>=left and x<left+width and y>=top and y<top+height
end
local function clipped(frame,x,y)
    local child=frame
    while child.parent do
        local parent=child.parent
        -- Only the scroll-child subtree is clipped. Template scrollbars are
        -- ordinary ScrollFrame children and can sit outside the viewport.
        if parent.kind=="ScrollFrame" and parent.child==child and not contains(parent,x,y) then return true end
        child=parent
    end
    return false
end
function MOCK.HitTest(x,y)
    assert(type(x)=="number" and type(y)=="number","Hit-test coordinates must be numbers")
    local recipient,bestStrata,bestLevel,bestOrder=nil,-1,-1,-1
    for _,frame in ipairs(MOCK.frames) do
        if frame.kind~="FontString" and frame.kind~="Texture" and frame:IsVisible()
            and frame:IsMouseEnabled() and contains(frame,x,y) and not clipped(frame,x,y) then
            local strata=strataOrder[frame:GetFrameStrata()] or 0
            local level,order=frame:GetFrameLevel(),frame.creationOrder
            if strata>bestStrata or (strata==bestStrata and (level>bestLevel or (level==bestLevel and order>bestOrder))) then
                recipient,bestStrata,bestLevel,bestOrder=frame,strata,level,order
            end
        end
    end
    return recipient
end
function MOCK.ClickAt(x,y)
    local recipient=MOCK.HitTest(x,y)
    -- A disabled button or a mouse-enabled drag frame still absorbs the click.
    if recipient and recipient:IsEnabled() and recipient.scripts.OnClick then recipient.scripts.OnClick(recipient,"LeftButton") end
    return recipient
end
function MOCK.HoverAt(x,y)
    local recipient=MOCK.HitTest(x,y)
    if MOCK.hovered~=recipient then
        if MOCK.hovered and MOCK.hovered.scripts.OnLeave then MOCK.hovered.scripts.OnLeave(MOCK.hovered) end
        MOCK.hovered=recipient
        if recipient and recipient.scripts.OnEnter then recipient.scripts.OnEnter(recipient) end
    end
    return recipient
end
