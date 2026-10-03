-- Classic world-map preparation: known locations, not live creature tracking.
local addonName,A=...
local M={pins={},exploration={},hooks={},notified={}}; A.MapAdvisor=M
local colors={danger={1,0.3,0.2},rare={0.75,0.85,1},elite={1,0.7,0.2},boss={0.9,0.3,1}}
local names={danger="Dangerous",rare="Rare",elite="Elite",boss="World boss"}
local icons={
    danger={atlas="services-icon-warning",fallback="Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"},
    rare={atlas="nameplates-icon-elite-silver",fallback="Interface\\TargetingFrame\\UI-TargetingFrame-Skull"},
    elite={atlas="nameplates-icon-elite-gold",fallback="Interface\\TargetingFrame\\UI-TargetingFrame-Skull"},
    boss={fallback="Interface\\TargetingFrame\\UI-TargetingFrame-Skull"},
    star={fallback="Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"},
    diamond={fallback="Interface\\TargetingFrame\\UI-RaidTargetingIcon_3"},
    cross={fallback="Interface\\TargetingFrame\\UI-RaidTargetingIcon_7"},
}
local function atlasFor(kind)
    local atlas=icons[kind].atlas
    local lookup=C_Texture and C_Texture.GetAtlasInfo or GetAtlasInfo
    return atlas and lookup and lookup(atlas) and atlas
end
function M:IconLabel(kind,showChoice)
    local s=self:Settings(); local key=s and s.icons[kind] or kind
    local atlas=atlasFor(key)
    local caption=showChoice and (names[key] or (key:sub(1,1):upper()..key:sub(2))) or names[kind]
    return (atlas and ("|A:"..atlas..":18:18|a") or ("|T"..icons[key].fallback..":18:18:0:0|t")).." "..caption
end
function M:IconChoiceLabel(key)
    local atlas=atlasFor(key)
    local caption=names[key] or (key:sub(1,1):upper()..key:sub(2))
    return (atlas and ("|A:"..atlas..":18:18|a") or ("|T"..icons[key].fallback..":18:18:0:0|t")).." "..caption
end
M.iconChoices={"rare","elite","boss","danger","star","diamond","cross"}
for _,entry in ipairs({{"circle",2},{"triangle",4},{"moon",5},{"square",6},{"skull",8}}) do
    icons[entry[1]]={fallback="Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..entry[2]}
    M.iconChoices[#M.iconChoices+1]=entry[1]
end
-- Native map symbols have transparent silhouettes rather than square spell art.
for _,entry in ipairs({
    {"inn","Inn","Innkeeper"},{"flight","Flight path","FlightMaster"},
    {"repair","Repair","Repair"},{"stable","Stable","StableMaster"},
    {"bank","Bank","Banker"},{"auction","Auction house","Auctioneer"},
    {"trainer","Trainer","Profession"},{"food","Food","Food"},
    {"reagents","Reagents","Reagents"},{"mailbox","Mailbox","Mailbox"},
    {"poisons","Poison","Poisons"},{"battle","Battleground","BattleMaster"},
    {"ammunition","Ammunition","Ammunition"},{"class-trainer","Class trainer","Class"},
    {"fishing","Fishing","Fish"},
    {"herbs","Herbs","Herbalism"},{"ore","Ore","Mining"},
}) do
    local key=entry[1]; names[key]=entry[2]
    icons[key]={fallback="Interface\\Minimap\\Tracking\\"..entry[3]}
    M.iconChoices[#M.iconChoices+1]=key
end
-- Standalone Blizzard symbols only. Atlas availability varies across Classic
-- builds, so show only symbols the running client actually supplies.
local atlasChoices={
    {"quest-available","Quest available","QuestNormal"},
    {"quest-complete","Quest complete","QuestTurnin"},
    {"quest-incomplete","Quest incomplete","QuestInProgress"},
    {"quest-daily","Daily quest","QuestDaily"},
    {"quest-daily-complete","Daily complete","QuestDailyTurnin"},
    {"quest-repeatable","Repeatable quest","QuestRepeatableTurnin"},
    {"quest-trivial","Trivial quest","QuestNormalTrivial"},
    {"quest-legendary","Legendary quest","QuestLegendary"},
    {"quest-legendary-complete","Legendary complete","QuestLegendaryTurnin"},
    {"quest-campaign","Campaign quest","Quest-Campaign-Available"},
    {"quest-campaign-complete","Campaign complete","Quest-Campaign-TurnIn"},
    {"quest-important","Important quest","ImportantAvailableQuest"},
    {"quest-important-complete","Important complete","ImportantQuestTurnin"},
    {"quest-shield","Quest objective","QuestNormal-Shield"},
    {"quest-area","Quest area","QuestArea"},
    {"quest-boss","Quest boss","QuestBoss"},
    {"objective","Objective","QuestObjective"},
    {"poi-rare","Rare creature","VignetteKill"},
    {"poi-elite","Elite creature","VignetteKillElite"},
    {"poi-loot","Treasure","VignetteLoot"},
    {"poi-loot-elite","Rare treasure","VignetteLootElite"},
    {"poi-event","Event","VignetteEvent"},
    {"poi-event-elite","Elite event","VignetteEventElite"},
    {"poi-dungeon","Dungeon","Dungeon"},
    {"poi-raid","Raid","Raid"},
    {"poi-cave","Cave","poi-cave"},
    {"poi-door","Door","poi-door"},
    {"poi-portal","Portal","poi-portal"},
    {"poi-boat","Boat","poi-boat"},
    {"poi-town","Town","poi-town"},
    {"poi-hub","Quest hub","poi-hub"},
    {"poi-camp","Camp","poi-camp"},
    {"poi-campfire","Campfire","poi-campfire"},
    {"poi-flight","Flight point","FlightMaster"},
    {"poi-graveyard","Graveyard","poi-graveyard"},
    {"poi-stable","Stable","poi-stable"},
    {"poi-anvil","Anvil","poi-anvil"},
    {"poi-mine","Mine","poi-mine"},
    {"poi-fishing","Fishing spot","Fishing-Hole"},
    {"service-repair","Repair service","services-icon-repair"},
    {"service-vendor","Vendor","services-icon-vendor"},
    {"service-bank","Bank service","services-icon-bank"},
    {"service-auction","Auction service","services-icon-auctionhouse"},
    {"service-transmog","Appearance","services-icon-transmogrification"},
    {"role-tank","Tank","roleicon-tiny-tank"},
    {"role-healer","Healer","roleicon-tiny-healer"},
    {"role-damage","Damage","roleicon-tiny-dps"},
    {"checkmark","Check mark","common-icon-checkmark"},
    {"red-x","Red X","common-icon-redx"},
    {"shield","Shield","UI-HUD-UnitFrame-Player-PortraitOn-Bar-Shield"},
}
for _,entry in ipairs(atlasChoices) do
    names[entry[1]]=entry[2]
    icons[entry[1]]={atlas=entry[3],fallback="Interface\\TargetingFrame\\UI-TargetingFrame-Skull"}
end
function M:LoadIconChoices()
    if self.iconCatalogLoaded then return end
    self.iconCatalogLoaded=true
    for _,entry in ipairs(atlasChoices) do
        if atlasFor(entry[1]) then self.iconChoices[#self.iconChoices+1]=entry[1] end
    end
end
function M:IconName(key) return names[key] or (key:sub(1,1):upper()..key:sub(2)) end
function M:SetIconTexture(texture,key)
    local atlas=atlasFor(key)
    texture:SetTexCoord(0,1,0,1)
    if atlas and texture.SetAtlas then texture:SetAtlas(atlas,false)
    else texture:SetTexture(icons[key].fallback) end
end
local function bounded(value,default,low,high)
    value=tonumber(value); if not value or value~=value then value=default end
    return math.max(low,math.min(high,value))
end
local priority={danger=2,rare=1,elite=3,boss=4}
local function action(command,id) return {kind="mapAdvisor",command=command,id=id} end
local function row(title,body,command,id) return {title=title,body=body,action=command and action(command,id)} end

function M:Settings()
    if not A.db then return end
    if type(A.db.mapAdvisor)~="table" then A.db.mapAdvisor={} end
    local s=A.db.mapAdvisor
    if s.reveal~="off" and s.reveal~="full" and s.reveal~="tint" then s.reveal="tint" end
    for _,key in ipairs({"danger","rare","elite","boss"}) do if s[key]==nil then s[key]=true end end
    if s.notify==nil then s.notify=true end
    s.tintR=bounded(s.tintR,0.35,0,1); s.tintG=bounded(s.tintG,0.65,0,1); s.tintB=bounded(s.tintB,1,0,1)
    s.tintAlpha=bounded(s.tintAlpha,1,0,1)
    s.iconSize=bounded(s.iconSize,18,12,40); s.iconAlpha=bounded(s.iconAlpha,1,0.1,1)
    if type(s.icons)~="table" then s.icons={} end
    for _,kind in ipairs({"danger","rare","elite","boss"}) do if not icons[s.icons[kind]] then s.icons[kind]=kind end end
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

function M:Records(id,allCategories)
    local zone=A.Data.MapZones[id]; local list={}; local settings=self:Settings()
    if not zone or not settings then return list end
    local faction=UnitFactionGroup("player"); local side=faction=="Alliance" and 1 or faction=="Horde" and 2
    for _,npcID in ipairs(zone.npcs) do
        local npc=A.Data.MapNPCs[npcID]
        if npc and (allCategories or settings[npc.kind]) and (not side or npc.react[side]~=1) then
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
    -- Every point must be close to every other point in its group. Nearby
    -- chains cannot pull a whole camp into one marker.
    local map=WorldMapFrame
    local canvas=map and map.GetCanvas and map:GetCanvas()
    local scale=map and map.GetCanvasScale and map:GetCanvasScale() or 1
    local width=(canvas and canvas:GetWidth() or 1002)*scale
    local height=(canvas and canvas:GetHeight() or 668)*scale
    -- Preserve the default 16px radius at 18px, and follow the marker footprint.
    local radius=self:Settings().iconSize*16/18
    local clusters={}
    for _,record in ipairs(self:Records(id)) do
        for _,xy in ipairs(record.npc.locations[id] or {}) do
            local px,py=xy[1]/100*width,xy[2]/100*height
            local cell
            for _,candidate in ipairs(clusters) do
                local fits=true
                for _,point in ipairs(candidate.points) do
                    local dx,dy=px-point[1],py-point[2]
                    if dx*dx+dy*dy>radius*radius then fits=false; break end
                end
                if fits then cell=candidate; break end
            end
            if not cell then
                cell={x=0,y=0,count=0,records={},seen={},points={},kind=record.npc.kind}
                clusters[#clusters+1]=cell
            end
            cell.points[#cell.points+1]={px,py}
            cell.x=cell.x+xy[1]/100; cell.y=cell.y+xy[2]/100; cell.count=cell.count+1
            if not cell.seen[record.id] then cell.records[#cell.records+1]=record; cell.seen[record.id]=true end
            if priority[record.npc.kind]>priority[cell.kind] then cell.kind=record.npc.kind end
        end
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
        GameTooltip:AddLine(record.npc.name.." | "..level(record.npc).." | "..self:IconLabel(record.npc.kind),unpack(colors[record.npc.kind]))
        if count==1 and record.npc.note then GameTooltip:AddLine(record.npc.note,0.85,0.85,0.75,true) end
    end
    GameTooltip:AddLine("Recorded spawn areas; creatures may roam or be absent.",0.7,0.7,0.7,true)
    GameTooltip:AddLine("Click to view NPC appearances in HardcoreBuddy.",1,0.8,0.4,true)
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
            local s=self:Settings()
            pin:SetSize(s.iconSize/math.max(0.1,scale),s.iconSize/math.max(0.1,scale))
            pin.icon:SetAlpha(s.iconAlpha)
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
            pin=CreateFrame("Button",nil,canvas); self.pins[index]=pin
            A.Skin.Hover(pin)
            pin:EnableMouse(true)
            pin.icon=pin:CreateTexture(nil,"ARTWORK"); pin.icon:SetAllPoints()
            pin:SetScript("OnEnter",function(p) M:Tooltip(p) end)
            pin:SetScript("OnLeave",function() GameTooltip:Hide() end)
            pin:SetScript("OnClick",function(p) M:OpenNPCs(p.cluster) end)
            pin:SetScript("OnHide",function(p) if GameTooltip.IsOwned and GameTooltip:IsOwned(p) then GameTooltip:Hide() end end)
        end
        pin.cluster=cluster
        local key=self:Settings().icons[cluster.kind]
        self:SetIconTexture(pin.icon,key)
        pin:Show()
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
                texture:SetSize(w,h); texture:SetTexCoord(0,w/padded(w),0,h/padded(h))
                local loaded=texture:SetTexture(file)
                if s.reveal=="tint" then texture:SetVertexColor(s.tintR,s.tintG,s.tintB,s.tintAlpha)
                else texture:SetVertexColor(1,1,1,1) end
                -- Failed client assets must never leave a green placeholder.
                texture:SetShown(loaded~=false)
            end
        end
    end
end

function M:MapMarkerControls(map)
    if not self.markerBar then
        local bar=CreateFrame("Frame",nil,map); self.markerBar=bar
        bar:SetSize(520,24); bar:SetPoint("BOTTOM",map,"BOTTOM",0,4)
        bar:SetFrameLevel(map:GetFrameLevel()+30)
        bar.checks={}
        local title=bar:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        title:SetPoint("LEFT",4,0); title:SetText("NPC markers:")
        for i,entry in ipairs({{"rare","Rares"},{"elite","Elites"},{"boss","Bosses"},{"danger","Dangerous"}}) do
            local key=entry[1]
            local b=CreateFrame("CheckButton",nil,bar,"UICheckButtonTemplate")
            b:SetSize(24,24); b:SetPoint("LEFT",100+(i-1)*100,0)
            local text=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
            text:SetPoint("LEFT",b,"RIGHT",0,0); text:SetText(entry[2])
            b:SetScript("OnClick",function(self)
                M:Settings()[key]=not not self:GetChecked(); M:Changed()
            end)
            bar.checks[key]=b
        end
    end
    local s=self:Settings()
    for key,b in pairs(self.markerBar.checks) do b:SetChecked(s[key]) end
end

function M:Attach()
    local map=WorldMapFrame
    if not map or not hooksecurefunc then return end
    self:MapMarkerControls(map)
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
    if not self:Settings().notify then self:HideZoneNotice() end
    self:Attach(); self:RefreshPins(); A:Refresh(true)
end

function M:HideZoneNotice()
    if self.zoneNotice then
        self.zoneNotice:Hide(); self.zoneNotice.box:Hide()
        self.zoneNotice.footer.zoneID=nil
        for _,row in ipairs(self.zoneNotice.rows) do row.npcID=nil; row:Hide() end
    end
    self.zoneNoticeMap=nil
    for _,saved in ipairs(self.zoneNoticeTimes or {}) do
        if saved.frame.holdTime==saved.extended then saved.frame.holdTime=saved.hold end
        if saved.frame.fadeOutTime==saved.shortened then saved.frame.fadeOutTime=saved.fadeOut end
    end
    self.zoneNoticeTimes=nil
end

function M:LayoutZoneNotice()
    if not self.zoneNoticeMap or not self.zoneNotice then return end
    local anchor=ZoneTextString
    -- Blizzard moves the subzone below territory text. Follow the final native
    -- line, including arena text, instead of covering any part of the title.
    for _,name in ipairs({"PVPInfoTextString","SubZoneTextString","PVPArenaTextString"}) do
        local region=_G[name]
        if region and region:GetText() and region:GetText()~="" then anchor=region end
    end
    self.zoneNotice:ClearAllPoints()
    self.zoneNotice:SetPoint("TOP",anchor,"BOTTOM",0,-8)
    local frame=self.zoneNotice
    local width=math.min(520,UIParent:GetWidth()*.8)
    frame:SetWidth(width-32)
    frame.box:ClearAllPoints(); frame.box:SetWidth(width)
    frame.box:SetPoint("TOP",ZoneTextString,"TOP",0,16)
    frame.box:SetPoint("BOTTOM",frame.note,"BOTTOM",0,-16)
    local columns={8,frame:GetWidth()-172,frame:GetWidth()-112}
    local widths={frame:GetWidth()-188,52,102}
    local function place(cell,index)
        cell:ClearAllPoints(); cell:SetPoint("LEFT",cell:GetParent(),"LEFT",columns[index],0)
        cell:SetWidth(widths[index]); cell:SetJustifyH(index==2 and "CENTER" or "LEFT")
    end
    for i,cell in ipairs(frame.headers) do place(cell,i) end
    for _,row in ipairs(frame.rows) do for i,cell in ipairs(row.cells) do place(cell,i) end end
end

function M:CreateZoneNotice()
    if self.zoneNotice then return self.zoneNotice end
    local skin=A.Skin
    local frame=CreateFrame("Frame",nil,ZoneTextFrame,"BackdropTemplate"); self.zoneNotice=frame
    frame:EnableMouse(false); frame:SetFrameLevel(ZoneTextFrame:GetFrameLevel()+1); skin.Paint(frame,"card")
    -- Parent background regions sit behind both native title frames; a child
    -- backdrop would otherwise cover the zone title at a higher frame level.
    frame.box=skin.SectionBackdrop(ZoneTextFrame,0,1)
    frame.box.sectionFill:SetVertexColor(.025,.030,.035,.96)
    for _,edge in ipairs(frame.box.backgroundEdges) do edge:SetVertexColor(unpack(skin.colors.bronze)) end
    local function text(parent,role)
        local label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
        skin.TextStyle(label,role); label:SetJustifyV("MIDDLE"); label:SetWordWrap(false)
        return label
    end
    frame.heading=CreateFrame("Frame",nil,frame); frame.heading:SetHeight(22)
    frame.heading:SetPoint("TOPLEFT",1,-1); frame.heading:SetPoint("TOPRIGHT",-1,-1)
    frame.headers={}
    for i,title in ipairs({"NPC","LEVEL","TYPE"}) do
        local cell=text(frame.heading,"column"); cell:SetText(title); frame.headers[i]=cell
    end
    local rule=skin.Divider(frame.heading); rule:SetPoint("BOTTOMLEFT"); rule:SetPoint("BOTTOMRIGHT")
    frame.rows={}
    for i=1,5 do
        local row=CreateFrame("Frame",nil,frame,"BackdropTemplate"); frame.rows[i]=row
        row:SetPoint("TOPLEFT",1,-23-(i-1)*26); row:SetPoint("TOPRIGHT",-1,-23-(i-1)*26); row:SetHeight(26)
        row:EnableMouse(false); skin.Paint(row,"row")
        if i%2==0 then row:SetBackdropColor(.025,.030,.035,1) end
        row.cells={text(row,"body"),text(row,"subtitle"),text(row,"subtitle")}
    end
    local footer=CreateFrame("Button",nil,frame,"BackdropTemplate"); frame.footer=footer
    skin.Paint(footer,"row"); skin.Hover(footer); footer:SetHeight(30)
    footer.more=text(footer,"subtitle"); footer.more:SetPoint("LEFT",8,0)
    footer.more:SetPoint("RIGHT",footer,"CENTER",12,0)
    footer.link=text(footer,"field"); footer.link:SetText("Click to view zone >")
    footer.link:SetPoint("LEFT",footer,"CENTER",20,0); footer.link:SetPoint("RIGHT",-8,0); footer.link:SetJustifyH("RIGHT")
    local line=skin.Divider(footer); line:SetPoint("TOPLEFT"); line:SetPoint("TOPRIGHT")
    footer:SetScript("OnClick",function(self)
        local zoneID=self.zoneID
        if not zoneID or not A.Data.MapZones[zoneID] then return end
        M:HideZoneNotice()
        if ZoneText_Clear then ZoneText_Clear() end
        A:CreateWindow(); M:Activate({command="zone",id=zoneID}); A.window:Show()
    end)
    frame.note=text(frame,"subtitle"); frame.note:SetText("Recorded locations, not live sightings.")
    frame.note:SetPoint("TOPLEFT",frame,"BOTTOMLEFT",0,-6); frame.note:SetPoint("TOPRIGHT",frame,"BOTTOMRIGHT",0,-6)
    frame.note:SetHeight(16); frame.note:SetJustifyH("CENTER")
    ZoneTextFrame:HookScript("OnHide",function() M:HideZoneNotice() end)
    if hooksecurefunc then
        if SetZoneText then hooksecurefunc("SetZoneText",function() M:LayoutZoneNotice() end) end
        if ZoneText_Clear then hooksecurefunc("ZoneText_Clear",function() M:HideZoneNotice() end) end
    end
    return frame
end

function M:ShowZoneNotice(id,list)
    if not ZoneTextFrame or not ZoneTextString or not FadingFrame_Show then return false end
    self:HideZoneNotice()
    if not ZoneTextFrame:IsShown() then
        -- Deferred combat notices and login still use Blizzard's current zone,
        -- subzone and territory labels, rather than an independent banner.
        if not ZoneText_OnEvent then return false end
        ZoneText_OnEvent(ZoneTextFrame,"ZONE_CHANGED_NEW_AREA")
    end
    -- ZoneText_Clear may have suppressed the announcement for another central
    -- UI panel while our delayed map refresh was pending.
    if not ZoneTextString:GetText() or ZoneTextString:GetText()=="" then return false end
    local frame=self:CreateZoneNotice()
    local shown=math.min(5,#list)
    for i,row in ipairs(frame.rows) do
        row:SetShown(i<=shown)
        if i<=shown then
            local record=list[i]; local npc=record.npc; row.npcID=record.id
            row.cells[1]:SetText(npc.name)
            local known=npc.min and npc.max and npc.min>0 and npc.max<=100
            row.cells[2]:SetText(known and level(npc):gsub("^Level ","") or "??")
            row.cells[3]:SetText(names[npc.kind]); row.cells[3]:SetTextColor(unpack(colors[npc.kind]))
        end
    end
    local extra=#list-shown
    frame.footer.more:SetText(extra>0 and (extra.." additional NPC"..(extra==1 and "" or "s")) or ("All "..shown.." NPC"..(shown==1 and "" or "s").." shown"))
    frame.footer.zoneID=id
    frame.footer:ClearAllPoints(); frame.footer:SetPoint("TOPLEFT",1,-23-shown*26)
    frame.footer:SetPoint("TOPRIGHT",-1,-23-shown*26)
    frame:SetHeight(23+shown*26+31)
    self.zoneNoticeMap=id
    self:LayoutZoneNotice()
    -- Allow time to read the list, then shorten the native fade slightly.
    -- Restore previous timings when the list clears; leave other addons' edits.
    self.zoneNoticeTimes={}
    for _,frame in ipairs({ZoneTextFrame,SubZoneTextFrame}) do
        local hold=frame.holdTime; local extended=2
        local fadeOut=frame.fadeOutTime; local shortened=math.min(fadeOut or 2,1.5)
        self.zoneNoticeTimes[#self.zoneNoticeTimes+1]={frame=frame,hold=hold,extended=extended,fadeOut=fadeOut,shortened=shortened}
        frame.holdTime=extended; frame.fadeOutTime=shortened
    end
    frame:Show(); frame.box:Show()
    return true
end

function M:NotifyZone()
    local id=self:CurrentMap(); local _,instance=IsInInstance()
    if id~=self.zoneNoticeMap then self:HideZoneNotice() end
    if not id or instance=="party" or instance=="raid" then self.lastZone=nil; self:HideZoneNotice(); return end
    if InCombatLockdown and InCombatLockdown() then return end
    if id==self.lastZone then return end
    self.lastZone=id
    local s=self:Settings()
    if not s or not s.notify or (self.notified[id] and GetTime()-self.notified[id]<300) then return end
    local list=self:Records(id)
    if #list==0 then return end
    if self:ShowZoneNotice(id,list) then self.notified[id]=GetTime()
    else self.lastZone=nil end
end

function M:Activate(a)
    if a.command=="settings" then A:OpenSettings("Zone Advisor"); return
    elseif a.command=="npc" then self:OpenNPCs({records={{id=a.id}}}); return
    elseif a.command=="filter" then
        if a.id~="all" and not names[a.id] then return end
        A.state.zoneNPCFilter=a.id
    elseif a.command=="zones" then A.state.mapZonePicker=true
    elseif a.command=="zone" then
        if not A.Data.MapZones[a.id] then return end
        A:CommitInputs(); A.history=A.history or {}; A.history[#A.history+1]=A.state
        if A.window then A.window.search:ClearFocus(); A.window.classMenu:Hide() end
        A.state={view="training",filter="Zone Advisor",mapZone=a.id}
    elseif a.command=="current" then
        A:CommitInputs(); A.history=A.history or {}; A.history[#A.history+1]=A.state
        A.state={view="training",filter="Zone Advisor",mapCurrent=true}
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
    local doc={view="training",context=context,cards={}}
    if state.mapNPCs then return doc end
    if not state.mapZone and not state.mapCurrent and not state.mapZonePicker then
        return A.LevelingZones.Build(context,state)
    end
    if state.mapZonePicker then
        local zones={}; for id,z in pairs(A.Data.MapZones) do zones[#zones+1]={id=id,zone=z} end
        table.sort(zones,function(a,b) return a.zone.name<b.zone.name end)
        local blocks={row("Use my current zone","Follow your character as you travel.","current")}
        for _,z in ipairs(zones) do blocks[#blocks+1]=row(z.zone.name,#z.zone.npcs.." catalogued NPCs","zone",z.id) end
        doc.cards[1]={title="Choose a zone",note="Classic Era outdoor zones and cities",blocks=blocks}; return doc
    end
    local id=state.mapZone or self:CurrentMap(); local zone=A.Data.MapZones[id]
    if zone then
        local blocks={}
        local records=self:Records(id,true)
        table.sort(records,function(a,b)
            local amin,bmin=a.npc.min or math.huge,b.npc.min or math.huge
            if amin~=bmin then return amin<bmin end
            local amax,bmax=a.npc.max or amin,b.npc.max or bmin
            if amax~=bmax then return amax<bmax end
            if a.npc.name~=b.npc.name then return a.npc.name<b.npc.name end
            return a.id<b.id
        end)
        for _,r in ipairs(records) do
            if not state.zoneNPCFilter or state.zoneNPCFilter=="all" or r.npc.kind==state.zoneNPCFilter then
                local locations=r.npc.locations[id]
                local location=locations and #locations>0 and string.format("%.1f, %.1f",locations[1][1],locations[1][2]) or "Unknown"
                local block=row(r.npc.name,level(r.npc).." | "..names[r.npc.kind].." | Known area: "..location..
                    (r.npc.note and ("\n"..r.npc.note) or ""),"npc",r.id)
                block.npcColumns={level(r.npc):gsub("^Level ",""),r.npc.name,names[r.npc.kind],location}
                block.npcKind=r.npc.kind
                blocks[#blocks+1]=block
            end
        end
        local count=#blocks
        if count==0 then blocks[1]=row("No matching NPCs","Try another category. An empty list does not guarantee a safe zone.") end
        doc.cards[1]={title=zone.name,headerAction={label="Open Map",action={kind="mapAdvisor",command="open",id=id}},
            note=count.." NPCs | Recorded spawn areas. Click a row for its model and details.",blocks=blocks,npcTable=true,fullWidth=true}
    else
        doc.cards[1]={title="Zone unavailable",note="Your current area is not in the outdoor zone catalogue. Use Back to choose a zone.",blocks={}}
    end
    return doc
end

function M:LayoutControls()
    if self.navigation then self.navigation:Hide() end
    return 0
end

local events=CreateFrame("Frame"); M.events=events
for _,e in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","ZONE_CHANGED_INDOORS","PLAYER_REGEN_ENABLED","MAP_EXPLORATION_UPDATED"}) do events:RegisterEvent(e) end
events:SetScript("OnEvent",function(_,event)
    if not A.db then return end
    if event=="ZONE_CHANGED_NEW_AREA" or event=="PLAYER_ENTERING_WORLD"
        or M.zoneNoticeMap and M:CurrentMap()~=M.zoneNoticeMap then M:HideZoneNotice() end
    if event=="ADDON_LOADED" or event=="PLAYER_ENTERING_WORLD" or event=="MAP_EXPLORATION_UPDATED" then M:Attach() end
    M.refreshAt=GetTime()+0.5
end)
events:SetScript("OnUpdate",function()
    if M.refreshAt and GetTime()>=M.refreshAt then
        M.refreshAt=nil; M:NotifyZone(); M:RefreshPins()
        if A.window and A.window:IsShown() and A.state.view=="training" and A.state.filter=="Zone Advisor" then A:Refresh() end
    end
end)
