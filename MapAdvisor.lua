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
for _,entry in ipairs({
    {"wolf","Wolf","Ability_Hunter_Pet_Wolf"},{"bear","Bear","Ability_Hunter_Pet_Bear"},
    {"cat","Cat","Ability_Hunter_Pet_Cat"},{"boar","Boar","Ability_Hunter_Pet_Boar"},
    {"raptor","Raptor","Ability_Hunter_Pet_Raptor"},{"spider","Spider","Ability_Hunter_Pet_Spider"},
    {"bat","Bat","Ability_Hunter_Pet_Bat"},{"owl","Owl","Ability_Hunter_Pet_Owl"},
    {"scorpid","Scorpid","Ability_Hunter_Pet_Scorpid"},{"turtle","Turtle","Ability_Hunter_Pet_Turtle"},
    {"gorilla","Gorilla","Ability_Hunter_Pet_Gorilla"},{"hyena","Hyena","Ability_Hunter_Pet_Hyena"},
    {"crocodile","Crocolisk","Ability_Hunter_Pet_Crocolisk"},{"serpent","Wind serpent","Ability_Hunter_Pet_WindSerpent"},
    {"bird","Carrion bird","Ability_Hunter_Pet_Vulture"},{"tallstrider","Tallstrider","Ability_Hunter_Pet_TallStrider"},
    {"dragon","Dragon","INV_Misc_Head_Dragon_01"},{"demon","Demon","Spell_Shadow_SummonFelHunter"},
    {"fire","Fire","Spell_Fire_FlameBolt"},{"frost","Frost","Spell_Frost_FrostBolt02"},
    {"lightning","Lightning","Spell_Nature_Lightning"},{"poison","Poison","Ability_Rogue_DualWeild"},
    {"shadow","Shadow","Spell_Shadow_ShadowBolt"},{"arcane","Arcane","Spell_Nature_StarFall"},
    {"holy","Holy","Spell_Holy_HolyBolt"},{"shield","Shield","Ability_Defend"},
    {"sword","Sword","Ability_MeleeDamage"},{"bow","Bow","Ability_Marksmanship"},
    {"stealth","Stealth","Ability_Stealth"},{"trap","Trap","Spell_Frost_ChainsOfIce"},
    {"fear","Fear","Spell_Shadow_Possession"},{"bleed","Bleed","Ability_Gouge"},
    {"heal","Healing","Spell_Holy_Heal"},{"stun","Stun","Ability_ThunderBolt"},
    {"eye","Eye","Spell_Shadow_DetectInvisibility"},{"paw","Paw","Ability_Druid_Maul"},
}) do
    local key=entry[1]; names[key]=entry[2]
    icons[key]={fallback="Interface\\Icons\\"..entry[3]}
    M.iconChoices[#M.iconChoices+1]=key
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
    s.tintAlpha=bounded(s.tintAlpha,0.55,0,1)
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
    if state.mapNPCs then return doc end
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

function M:LayoutControls(parent,left,top,width,visible)
    visible=visible and not A.state.mapNPCs
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
