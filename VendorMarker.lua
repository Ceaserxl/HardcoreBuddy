-- One selected supply vendor, independent of Blizzard guard POIs and other addons.
local _,A=...
local M={}; A.VendorMarker=M
local function world(map,x,y)
    if not C_Map or not C_Map.GetWorldPosFromMapPos or not CreateVector2D then return end
    return C_Map.GetWorldPosFromMapPos(map,CreateVector2D(x,y))
end
function M:Clear()
    self.target=nil
    if self.mapPin then self.mapPin:Hide() end
    if self.miniPin then self.miniPin:Hide() end
    self.driver:Hide()
end
function M:Pin(parent)
    local pin=CreateFrame("Button",nil,parent)
    pin:SetSize(20,20); pin:SetFrameLevel(parent:GetFrameLevel()+30)
    pin:RegisterForClicks("RightButtonUp")
    local icon=pin:CreateTexture(nil,"OVERLAY"); icon:SetAllPoints()
    local coords=C_Minimap and C_Minimap.GetPOITextureCoords or GetPOITextureCoords
    if coords then
        -- Blizzard's guard destination: red flag with a yellow exclamation mark.
        icon:SetTexture("Interface\\Minimap\\POIIcons"); icon:SetTexCoord(coords(6))
    else icon:SetTexture("Interface\\Minimap\\Tracking\\POI") end
    pin:SetScript("OnClick",function() M:Clear() end)
    pin:SetScript("OnEnter",function(p)
        local t=M.target; if not t then return end
        GameTooltip:SetOwner(p,"ANCHOR_RIGHT"); GameTooltip:SetText(t.name,1,.82,.3)
        GameTooltip:AddLine(t.item,1,1,1)
        if t.movement=="roaming" then GameTooltip:AddLine("Roaming vendor: recorded location",1,.7,.2)
        elseif t.observed then GameTooltip:AddLine("Last visited location",.7,.7,.7) end
        GameTooltip:AddLine("Right-click to clear marker",.7,.7,.7); GameTooltip:Show()
    end)
    pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return pin
end
function M:Set(vendor,item)
    if not vendor or not vendor.map or not vendor.x or not vendor.y then return end
    self.target={name=vendor.name,map=vendor.map,x=vendor.x/100,y=vendor.y/100,
        movement=vendor.movement,observed=vendor.observed,item=item or "Missing essential"}
    self.driver:Show(); self:Update()
end
function M:Update()
    local t=self.target; if not t then return end
    local map=WorldMapFrame
    if map and map.GetCanvas and map.GetMapID and map:IsShown() and map:GetMapID()==t.map then
        local canvas=map:GetCanvas()
        if not self.mapPin then self.mapPin=self:Pin(canvas) end
        local pin=self.mapPin; pin:SetParent(canvas)
        pin:SetFrameLevel(math.max(2100,canvas:GetFrameLevel()+30))
        local scale=map.GetCanvasScale and map:GetCanvasScale() or 1
        pin:SetSize(20/math.max(.1,scale),20/math.max(.1,scale))
        pin:ClearAllPoints(); pin:SetPoint("CENTER",canvas,"TOPLEFT",t.x*canvas:GetWidth(),-t.y*canvas:GetHeight()); pin:Show()
    elseif self.mapPin then self.mapPin:Hide() end
    if not Minimap or not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return end
    if not self.miniPin then self.miniPin=self:Pin(Minimap) end
    local pin=self.miniPin
    local playerMap=C_Map.GetBestMapForUnit("player")
    local position=playerMap and C_Map.GetPlayerMapPosition(playerMap,"player")
    if not position then pin:Hide(); return end
    local instance,target=world(t.map,t.x,t.y)
    local px,py=position:GetXY()
    local playerInstance,player=world(playerMap,px,py)
    if not target or not player or instance~=playerInstance then pin:Hide(); return end
    local north,west=target:GetXY(); local playerNorth,playerWest=player:GetXY()
    local dx,dy=playerWest-west,north-playerNorth
    -- World-map projection is in yards. Check before zoom/rotation/clamping.
    if dx*dx+dy*dy<=25 then self:Clear(); return end
    if GetCVar and GetCVar("rotateMinimap")=="1" then
        local facing=GetPlayerFacing and GetPlayerFacing() or 0
        dx,dy=dx*math.cos(facing)+dy*math.sin(facing),dy*math.cos(facing)-dx*math.sin(facing)
    end
    local radius=C_Minimap and C_Minimap.GetViewRadius and C_Minimap.GetViewRadius()
    if not radius or radius<=0 then
        local zoom=Minimap:GetZoom()
        local outdoor=not GetCVar or tonumber(GetCVar("minimapZoom"))==zoom
        local diameters=outdoor and {[0]=466.6667,400,333.3333,266.6667,200,133.3333} or {[0]=300,240,180,120,80,50}
        radius=(diameters[zoom] or diameters[0])/2
    end
    dx,dy=dx/radius,dy/radius
    local length=math.sqrt(dx*dx+dy*dy)
    if length>.85 then dx,dy=dx*.85/length,dy*.85/length end
    pin:ClearAllPoints(); pin:SetPoint("CENTER",Minimap,"CENTER",dx*Minimap:GetWidth()/2,dy*Minimap:GetHeight()/2); pin:Show()
end
M.driver=CreateFrame("Frame"); M.driver:Hide()
local elapsed=0
M.driver:SetScript("OnUpdate",function(_,delta)
    elapsed=elapsed+delta
    if elapsed>=.1 then elapsed=0; M:Update() end
end)
