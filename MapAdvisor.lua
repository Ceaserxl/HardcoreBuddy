-- Classic world-map preparation: known locations, not live creature tracking.
local addonName,A=...
local M={pins={},exploration={},hooks={},notified={}}; A.MapAdvisor=M
local colors={danger={1,0.3,0.2},rare={0.75,0.85,1},elite={1,0.7,0.2},boss={0.9,0.3,1}}
local names={danger="Dangerous",rare="Rare",elite="Elite",boss="World boss"}
local icons={
    danger="Interface\\AddOns\\HardcoreBuddy\\Media\\MapMarkers\\Danger.tga",
    rare="Interface\\AddOns\\HardcoreBuddy\\Media\\MapMarkers\\Rare.tga",
    elite="Interface\\AddOns\\HardcoreBuddy\\Media\\MapMarkers\\Elite.tga",
    boss="Interface\\AddOns\\HardcoreBuddy\\Media\\MapMarkers\\Boss.tga",
}
local function iconLabel(kind) return "|T"..icons[kind]..":18:18:0:0|t "..names[kind] end
local priority={danger=2,rare=1,elite=3,boss=4}
local PIN_SIZE,CLUSTER_RADIUS=18,28
local function action(command,id) return {kind="mapAdvisor",command=command,id=id} end
local function row(title,body,command,id) return {title=title,body=body,action=command and action(command,id)} end

function M:Settings()
    if not A.db then return end
    if type(A.db.mapAdvisor)~="table" then A.db.mapAdvisor={} end
    local s=A.db.mapAdvisor
    if s.reveal~="off" and s.reveal~="full" and s.reveal~="tint" then s.reveal="tint" end
    for _,key in ipairs({"danger","rare","elite","boss"}) do if s[key]==nil then s[key]=true end end
    if s.notify==nil then s.notify=false end
    return s
end

function M:CurrentMap()
    local id=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    for _=1,8 do
        if not id then return end
        if A.Data.MapZones[id] then return id end
        local info=C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        id=info and info.parentMapID
    end
end

function M:Records(id)
    local zone=A.Data.MapZones[id]; local list={}; local settings=self:Settings()
    if not zone or not settings then return list end
    local faction=UnitFactionGroup("player"); local side=faction=="Alliance" and 1 or faction=="Horde" and 2
    for _,npcID in ipairs(zone.npcs) do
        local npc=A.Data.MapNPCs[npcID]
        if npc and settings[npc.kind] and (not side or npc.react[side]~=1) then
            list[#list+1]={id=npcID,npc=npc}
        end
    end
    table.sort(list,function(a,b)
        if priority[a.npc.kind]~=priority[b.npc.kind] then return priority[a.npc.kind]>priority[b.npc.kind] end
        return a.npc.name<b.npc.name
    end)
    return list
end

function M:Clusters(id)
    -- Screen-distance grouping joins neighbours across grid boundaries. The
    -- grid only limits distance checks; connected points share one tooltip.
    local map=WorldMapFrame
    local canvas=map and map.GetCanvas and map:GetCanvas()
    local scale=map and map.GetCanvasScale and map:GetCanvasScale() or 1
    local width=(canvas and canvas:GetWidth() or 1002)*scale
    local height=(canvas and canvas:GetHeight() or 668)*scale
    local points,buckets={},{}
    local function root(point)
        while point.parent~=point do point.parent=point.parent.parent; point=point.parent end
        return point
    end
    for _,record in ipairs(self:Records(id)) do
        for _,xy in ipairs(record.npc.locations[id] or {}) do
            local p={x=xy[1]/100,y=xy[2]/100,record=record}
            p.px=p.x*width; p.py=p.y*height; p.parent=p
            local gx,gy=math.floor(p.px/CLUSTER_RADIUS),math.floor(p.py/CLUSTER_RADIUS)
            for x=gx-1,gx+1 do for y=gy-1,gy+1 do
                for _,near in ipairs(buckets[x..":"..y] or {}) do
                    local dx,dy=p.px-near.px,p.py-near.py
                    if dx*dx+dy*dy<=CLUSTER_RADIUS*CLUSTER_RADIUS then root(near).parent=root(p) end
                end
            end end
            local key=gx..":"..gy
            buckets[key]=buckets[key] or {}; buckets[key][#buckets[key]+1]=p
            points[#points+1]=p
        end
    end
    local clusters,byRoot={},{}
    for _,p in ipairs(points) do
        local key=root(p); local cell=byRoot[key]; local record=p.record
        if not cell then
            cell={x=0,y=0,count=0,records={},seen={},kind=record.npc.kind}
            byRoot[key]=cell; clusters[#clusters+1]=cell
        end
        cell.x=cell.x+p.x; cell.y=cell.y+p.y; cell.count=cell.count+1
        if not cell.seen[record.id] then
            cell.records[#cell.records+1]=record; cell.seen[record.id]=true
        end
        if priority[record.npc.kind]>priority[cell.kind] then cell.kind=record.npc.kind end
    end
    for _,cell in ipairs(clusters) do
        cell.x=cell.x/cell.count; cell.y=cell.y/cell.count
    end
    return clusters
end

local function level(npc)
    if not npc.min or not npc.max then return "Level unknown" end
    return "Level "..npc.min..(npc.max~=npc.min and ("-"..npc.max) or "")
end

function M:Tooltip(pin)
    if not pin.cluster or not GameTooltip then return end
    GameTooltip:SetOwner(pin,"ANCHOR_RIGHT")
    local count=#pin.cluster.records
    GameTooltip:SetText("HardcoreBuddy: known danger area"..(count>1 and (" ("..count.." NPCs)") or ""),1,0.8,0.4,1,true)
    for _,record in ipairs(pin.cluster.records) do
        GameTooltip:AddLine(record.npc.name.." | "..level(record.npc).." | "..iconLabel(record.npc.kind),unpack(colors[record.npc.kind]))
        if count==1 and record.npc.note then GameTooltip:AddLine(record.npc.note,0.85,0.85,0.75,true) end
    end
    GameTooltip:AddLine("Recorded spawn areas; creatures may roam or be absent.",0.7,0.7,0.7,true)
    GameTooltip:Show()
end

function M:PlacePins()
    local map=WorldMapFrame
    if not map or not map.GetCanvas then return end
    local canvas=map:GetCanvas(); local scale=map.GetCanvasScale and map:GetCanvasScale() or 1
    -- Native map pins use levels around 2000, far above the canvas itself.
    local manager=map.GetPinFrameLevelsManager and map:GetPinFrameLevelsManager()
    local top=manager and manager:GetValidFrameLevel("PIN_FRAME_LEVEL_TOPMOST",10000) or 2000
    local frameLevel=math.max(canvas:GetFrameLevel()+30,top+1)
    for _,pin in ipairs(self.pins) do
        if pin:IsShown() and pin.cluster then
            pin:SetFrameLevel(frameLevel)
            pin:ClearAllPoints(); pin:SetPoint("CENTER",canvas,"TOPLEFT",pin.cluster.x*canvas:GetWidth(),-pin.cluster.y*canvas:GetHeight())
            pin:SetSize(PIN_SIZE/math.max(0.1,scale),PIN_SIZE/math.max(0.1,scale))
        end
    end
end

function M:RefreshPins()
    for _,pin in ipairs(self.pins) do pin:Hide(); pin.cluster=nil end
    local map=WorldMapFrame
    if not map or not map:IsShown() or not map.GetMapID or not map.GetCanvas or not self:Settings() then return end
    local canvas=map:GetCanvas()
    for index,cluster in ipairs(self:Clusters(map:GetMapID())) do
        local pin=self.pins[index]
        if not pin then
            pin=CreateFrame("Frame",nil,canvas); self.pins[index]=pin
            pin:EnableMouse(true)
            pin.icon=pin:CreateTexture(nil,"ARTWORK"); pin.icon:SetAllPoints()
            pin:SetScript("OnEnter",function(p) M:Tooltip(p) end)
            pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
            pin:SetScript("OnHide",function(p) if GameTooltip.IsOwned and GameTooltip:IsOwned(p) then GameTooltip:Hide() end end)
        end
        pin.cluster=cluster; pin.icon:SetTexture(icons[cluster.kind]); pin:Show()
    end
    self:PlacePins()
end

local function rectKey(w,h,x,y) return w..":"..h..":"..x..":"..y end
local function padded(n) local p=16; while p<n do p=p*2 end; return p end

function M:Reveal(pin)
    local textures=self.exploration[pin]
    if not textures then textures={}; self.exploration[pin]=textures end
    for _,t in ipairs(textures) do t:Hide() end
    local s=self:Settings(); local map=pin:GetMap(); local id=map:GetMapID()
    local data=A.Data.MapTiles[id]
    if not s or s.reveal=="off" or not data or not C_Map or not C_Map.GetMapArtID
        or C_Map.GetMapArtID(id)~=data.art then return end
    local known={}
    if not C_MapExplorationInfo or not C_MapExplorationInfo.GetExploredMapTextures then return end
    for _,r in ipairs(C_MapExplorationInfo.GetExploredMapTextures(id) or {}) do
        known[rectKey(r.textureWidth,r.textureHeight,r.offsetX,r.offsetY)]=true
    end
    local layers=C_Map.GetMapArtLayers and C_Map.GetMapArtLayers(id)
    local container=map:GetCanvasContainer(); local layer=container:GetCurrentLayerIndex()
    local info=layers and layers[layer]
    if not info or info.tileWidth~=256 or info.tileHeight~=256 then return end
    local count=0
    for _,r in ipairs(data.tiles) do
        if not known[rectKey(r[1],r[2],r[3],r[4])] then
            local across=math.ceil(r[1]/256)
            for index,file in ipairs(r[5]) do
                local col=(index-1)%across; local rowIndex=math.floor((index-1)/across)
                local w=math.min(256,r[1]-col*256); local h=math.min(256,r[2]-rowIndex*256)
                count=count+1; local texture=textures[count]
                if not texture then texture=pin:CreateTexture(nil,"ARTWORK",nil,-1); textures[count]=texture end
                texture:ClearAllPoints(); texture:SetPoint("TOPLEFT",pin,"TOPLEFT",r[3]+col*256,-r[4]-rowIndex*256)
                texture:SetSize(w,h); texture:SetTexCoord(0,w/padded(w),0,h/padded(h)); texture:SetTexture(file)
                if s.reveal=="tint" then texture:SetVertexColor(0.35,0.65,1,0.55)
                else texture:SetVertexColor(1,1,1,1) end
                texture:Show()
            end
        end
    end
end

function M:Attach()
    local map=WorldMapFrame
    if not map or not hooksecurefunc then return end
    if not self.hooks.map then
        map:HookScript("OnShow",function() M:Attach(); M:RefreshPins() end)
        if map.SetMapID then hooksecurefunc(map,"SetMapID",function() M:RefreshPins() end) end
        if map.OnCanvasScaleChanged then hooksecurefunc(map,"OnCanvasScaleChanged",function() M:RefreshPins() end) end
        if map.OnCanvasSizeChanged then hooksecurefunc(map,"OnCanvasSizeChanged",function() M:RefreshPins() end) end
        self.hooks.map=true
    end
    if map.EnumeratePinsByTemplate then
        for pin in map:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
            if not self.hooks[pin] then
                hooksecurefunc(pin,"RefreshOverlays",function(p) M:Reveal(p) end)
                hooksecurefunc(pin,"RemoveAllData",function(p)
                    for _,t in ipairs(M.exploration[p] or {}) do t:Hide() end
                end)
                self.hooks[pin]=true
            end
            self:Reveal(pin)
        end
    end
end

function M:Changed()
    self:Attach(); self:RefreshPins(); A:Refresh(true)
end

function M:NotifyZone()
    local id=self:CurrentMap(); local _,instance=IsInInstance()
    if not id or instance=="party" or instance=="raid" then self.lastZone=nil; return end
    if InCombatLockdown and InCombatLockdown() then return end
    if id==self.lastZone then return end
    self.lastZone=id
    local s=self:Settings()
    if not s or not s.notify or (self.notified[id] and GetTime()-self.notified[id]<300) then return end
    local list=self:Records(id); local labels={}
    for _,r in ipairs(list) do if #labels<4 then labels[#labels+1]=r.npc.name end end
    if #labels==0 then return end
    self.notified[id]=GetTime()
    A:Print(A.Data.MapZones[id].name..": known dangers include "..table.concat(labels,", ")..
        (#list>#labels and (" (+"..(#list-#labels).." more)") or "")..". See Advisors > Map. These are recorded areas, not live sightings.")
end

function M:Activate(a)
    if a.command=="settings" then A:OpenSettings("Map"); return
    elseif a.command=="zones" then A.state.mapZonePicker=true
    elseif a.command=="zone" then A.state.mapZone=a.id; A.state.mapZonePicker=nil
    elseif a.command=="current" then A.state.mapZone=nil; A.state.mapZonePicker=nil
    elseif a.command=="open" then
        if InCombatLockdown and InCombatLockdown() then A:Print("Open the map after combat."); return end
        if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
        if WorldMapFrame then
            if ShowUIPanel then ShowUIPanel(WorldMapFrame) else WorldMapFrame:Show() end
            WorldMapFrame:SetMapID(a.id); self:Attach(); self:RefreshPins()
        end
        return
    end
    A:Refresh(true)
end

function M:Document(context,state)
    local doc={view="advisors",context=context,cards={}}
    if state.mapZonePicker then
        local zones={}; for id,z in pairs(A.Data.MapZones) do zones[#zones+1]={id=id,zone=z} end
        table.sort(zones,function(a,b) return a.zone.name<b.zone.name end)
        local blocks={row("Use my current zone","Follow your character as you travel.","current")}
        for _,z in ipairs(zones) do blocks[#blocks+1]=row(z.zone.name,#z.zone.npcs.." catalogued NPCs","zone",z.id) end
        doc.cards[1]={title="Choose a zone",note="Classic Era outdoor zones and cities",blocks=blocks}; return doc
    end
    local id=state.mapZone or self:CurrentMap(); local zone=A.Data.MapZones[id]
    local settingsRow=row("Map settings","Configure map reveal, marker categories and silent zone-entry notices.","settings")
    local blocks={settingsRow,row("Choose a zone","Browse the Classic outdoor zones and cities above.")}
    doc.cards[1]={title=zone and zone.name or "Map Advisor",note="Filtered for your faction. Hover map icons for NPC details.",blocks=blocks}
    if zone then
        blocks={settingsRow}
        for _,r in ipairs(self:Records(id)) do
            local locations=r.npc.locations[id]
            local location=locations and #locations>0 and string.format("Known area: %.1f, %.1f",locations[1][1],locations[1][2]) or "Coordinates unavailable; no pin shown"
            blocks[#blocks+1]=row(r.npc.name,level(r.npc).." | "..names[r.npc.kind].." | "..location..
                (r.npc.note and ("\n"..r.npc.note) or ""))
        end
        if #blocks==1 then blocks[2]=row("No matching dangers in this catalogue","Adjust the filters in Map settings. An empty list does not guarantee a safe zone.") end
        doc.cards[1].blocks=blocks
    end
    return doc
end

function M:LayoutSettings(parent,left,top,width,visible)
    if not self.controls and not visible then return 0 end
    local s=self:Settings()
    if not self.controls then
        local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); self.controls=f; A.Skin.Paint(f,"card")
        local function label(text,x,y,w)
            local l=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); l:SetFont(STANDARD_TEXT_FONT,12,"")
            l:SetPoint("TOPLEFT",x,-y); l:SetWidth(w); l:SetJustifyH("LEFT"); l:SetText(text); return l
        end
        label("Map",16,12,700):SetTextColor(unpack(A.Skin.colors.gold))
        label("Reveal unexplored terrain, or tint it blue to keep track of where you have been.",16,37,700)
        f.modes={}
        for i,mode in ipairs({{"off","Unchanged"},{"full","Reveal all"},{"tint","Tint unexplored"}}) do
            local key=mode[1]; local b=CreateFrame("Button",nil,f,"BackdropTemplate")
            b:SetSize(220,28); b:SetPoint("TOPLEFT",16+(i-1)*232,-65); A.Skin.Button(b,"utility")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetFont(STANDARD_TEXT_FONT,12,""); b.label:SetAllPoints(); b.label:SetText(mode[2])
            b:SetScript("OnClick",function() s.reveal=key; M:Changed() end); f.modes[key]=b
        end
        f.checks={}
        local function check(key,caption,x,y,w)
            local b=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); b:SetSize(22,22); b:SetPoint("TOPLEFT",x,-y); A.Skin.Paint(b,"edit")
            b.mark=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.mark:SetAllPoints(); b.mark:SetText("X")
            label(caption,x+30,y+4,w)
            b:SetScript("OnClick",function() s[key]=not not b:GetChecked(); M:Changed() end); f.checks[key]=b
        end
        for i,key in ipairs({"danger","rare","elite","boss"}) do check(key,iconLabel(key),16+(i-1)*177,108,135) end
        check("notify","Silent zone-entry notice (chat only)",16,146,650)
        label("Recorded spawn areas, not live sightings. Creatures may roam beyond these markers.",16,185,700)
    end
    local f=self.controls; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/744); f:SetScale(scale); f:SetSize(width/scale,212)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left/scale,-top/scale)
    for key,b in pairs(f.modes) do A.Skin.ButtonState(b,s.reveal==key,false,false) end
    for key,b in pairs(f.checks) do b:SetChecked(s[key]); b.mark:SetText(s[key] and "X" or "") end
    return 220*scale
end

function M:LayoutControls(parent,left,top,width,visible)
    if not self.navigation and not visible then return 0 end
    if not self.navigation then
        local f=CreateFrame("Frame",nil,parent); self.navigation=f
        for i,entry in ipairs({{"zones","Browse zones"},{"open","Open zone map"},{"current","Follow current zone"}}) do
            local command=entry[1]; local b=CreateFrame("Button",nil,f,"BackdropTemplate")
            b:SetSize(220,28); b:SetPoint("TOPLEFT",16+(i-1)*232,-8); A.Skin.Button(b,"utility")
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(entry[2])
            b:SetScript("OnClick",function()
                local id=A.state.mapZone or M:CurrentMap()
                if command~="open" or id then M:Activate(action(command,id)) end
            end)
        end
    end
    local f=self.navigation; f:SetShown(visible); if not visible then return 0 end
    local scale=math.min(1,width/744); f:SetScale(scale); f:SetSize(width/scale,44)
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",parent,"TOPLEFT",left/scale,-top/scale)
    return 52*scale
end

local events=CreateFrame("Frame"); M.events=events
for _,e in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","PLAYER_REGEN_ENABLED","MAP_EXPLORATION_UPDATED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
    if not A.db then return end
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" or event=="MAP_EXPLORATION_UPDATED" then M:Attach() end
    M.refreshAt=GetTime()+0.5
end)
events:SetScript("OnUpdate",function()
    if M.refreshAt and GetTime()>=M.refreshAt then
        M.refreshAt=nil; M:NotifyZone(); M:RefreshPins()
        if A.window and A.window:IsShown() and A.state.view=="advisors" and A.state.filter=="Map" then A:Refresh() end
    end
end)
