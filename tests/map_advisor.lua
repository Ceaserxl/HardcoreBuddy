local A=TestAddon
local M=A.MapAdvisor
local count=0
for id,z in pairs(A.Data.MapZones) do
    count=count+1
    for _,npc in ipairs(z.npcs) do assert(A.Data.MapNPCs[npc],z.name) end
end
assert(count==46)
assert(A.Data.MapNPCs[2529].locations[1421],"Original Son of Arugal in Silverpine")
assert(A.Data.MapNPCs[589].kind=="danger")
assert(not A.Data.MapNPCs[203139],"No SoD replacement data")
for _,id in ipairs({14887,14888,14889,14890}) do
    local npc=A.Data.MapNPCs[id]; assert(npc.kind=="boss")
    for _,map in ipairs({1431,1425,1444,1440}) do assert(#npc.locations[map]==1) end
end
for _,n in pairs(A.Data.MapNPCs) do
    for map,points in pairs(n.locations) do
        assert(A.Data.MapZones[map])
        for _,xy in ipairs(points) do assert(xy[1]>=0 and xy[1]<=100 and xy[2]>=0 and xy[2]<=100) end
    end
end
for _,data in pairs(A.Data.MapTiles) do
    for _,r in ipairs(data.tiles) do assert(#r[5]==math.ceil(r[1]/256)*math.ceil(r[2]/256)) end
end

-- Model only the Blizzard map API contract; native pools remain untouched.
local map=CreateFrame("Frame",nil,UIParent); WorldMapFrame=map
local canvas=CreateFrame("Frame",nil,map); canvas:SetSize(1002,668)
local pin=CreateFrame("Frame",nil,canvas)
local native=pin:CreateTexture(); native:SetTexture(999); native:Show()
local container={GetCurrentLayerIndex=function() return 1 end}
local mapID,scale,current,art,known=1436,1,1436,1240,{}
map.GetMapID=function() return mapID end
map.GetCanvas=function() return canvas end
map.GetCanvasScale=function() return scale end
map.GetCanvasContainer=function() return container end
map.OnCanvasScaleChanged=function() end
map.OnCanvasSizeChanged=function() end
map.SetMapID=function(_,id) mapID=id; pin:RefreshOverlays() end
pin.GetMap=function() return map end
pin.RemoveAllData=function() end
pin.RefreshOverlays=function(self) self:RemoveAllData() end
map.EnumeratePinsByTemplate=function(_,template)
    assert(template=="MapExplorationPinTemplate")
    local done=false; return function() if not done then done=true; return pin end end
end
hooksecurefunc=function(object,key,callback)
    local original=assert(object[key]); object[key]=function(...) original(...); callback(...) end
end
C_Map={GetBestMapForUnit=function() return current end,
    GetMapArtID=function() return art end,
    GetMapArtLayers=function() return {{tileWidth=256,tileHeight=256}} end,
    GetMapInfo=function(id) return id==999 and {parentMapID=1436} end}
C_MapExplorationInfo={GetExploredMapTextures=function() return known end}
local s=M:Settings(); assert(s.reveal=="tint" and not s.notify)
M:Attach(); M:RefreshPins()
assert(#M.exploration[pin]>0 and #M.pins>0)
local t=M.exploration[pin][1]
assert(t:IsShown() and t.vertexColor[4]==0.55 and t.drawSubLevel==-1)
assert(native:IsShown() and native.texture==999)
for _,p in ipairs(M.pins) do if p:IsShown() then
    local _,relative,anchor,x,y=p:GetPoint()
    assert(relative==canvas and anchor=="TOPLEFT")
    assert(x==p.cluster.x*1002 and y==-p.cluster.y*668)
end end
scale=2; map:OnCanvasScaleChanged(); assert(M.pins[1]:GetWidth()==13)
canvas:SetSize(900,600); map:OnCanvasSizeChanged()
local _,_,_,pinX,pinY=M.pins[1]:GetPoint()
assert(pinX==M.pins[1].cluster.x*900 and pinY==-M.pins[1].cluster.y*600)
s.reveal="off"; M:Attach(); assert(not t:IsShown() and native:IsShown())
s.reveal="full"; M:Attach(); assert(t:IsShown() and t.vertexColor[4]==1)
known={}
for _,r in ipairs(A.Data.MapTiles[1436].tiles) do
    known[#known+1]={textureWidth=r[1],textureHeight=r[2],offsetX=r[3],offsetY=r[4]}
end
pin:RefreshOverlays()
for _,texture in ipairs(M.exploration[pin]) do assert(not texture:IsShown()) end
assert(native:IsShown(),"Discovering the zone leaves native textures intact")
known={}; pin:RefreshOverlays(); assert(t:IsShown())
art=1; pin:RefreshOverlays(); assert(not t:IsShown(),"Mismatched art is never drawn")
art=1240; pin:RefreshOverlays(); assert(t:IsShown())
pin:RemoveAllData(); assert(not t:IsShown())
map:SetMapID(9999)
for _,p in ipairs(M.pins) do assert(not p:IsShown()) end
current=999; assert(M:CurrentMap()==1436); current=1436

-- Faction filter, category switches and records with no mapped locations.
for _,r in ipairs(M:Records(1453)) do assert(r.npc.react[1]~=1) end
s.danger=false
for _,r in ipairs(M:Records(1436)) do assert(r.npc.kind~="danger") end
s.danger=true
for _,c in ipairs(M:Clusters(1436)) do
    for _,r in ipairs(c.records) do assert(#r.npc.locations[1436]>0) end
end
local now,combat,instance=1000,false,"none"
GetTime=function() return now end
InCombatLockdown=function() return combat end
IsInInstance=function() return instance~="none",instance end
local messages={}; local printOriginal=A.Print
A.Print=function(_,message) messages[#messages+1]=message end
local soundCalls=0; PlaySound=function() soundCalls=soundCalls+1 end
PlaySoundFile=function() soundCalls=soundCalls+1 end
M:NotifyZone(); assert(#messages==0)
s.notify=true; M.lastZone=nil; M:NotifyZone(); assert(#messages==1)
M:NotifyZone(); assert(#messages==1)
current=1421; combat=true; M:NotifyZone(); assert(#messages==1)
combat=false; M.events.scripts.OnEvent(M.events,"PLAYER_REGEN_ENABLED"); now=now+1
M.events.scripts.OnUpdate(M.events); assert(#messages==2)
current=1436; M:NotifyZone(); assert(#messages==2,"Zone oscillation cooldown")
current=1429; instance="party"; M:NotifyZone(); assert(#messages==2)
instance="raid"; M:NotifyZone(); assert(#messages==2)
instance="none"; M:NotifyZone(); assert(#messages==3 and soundCalls==0)
assert(messages[1]:find("recorded areas",1,true))
A.Print=printOriginal

A:Navigate("advisors"); A.state.filter="Map"; A:Refresh(true)
assert(M.navigation:IsShown() and (not M.controls or not M.controls:IsVisible()) and A.document.cards[1].title=="Elwynn Forest")
A:Activate({kind="mapAdvisor",command="zones"})
assert(#A.document.cards[1].blocks==47,"All zones in a single scrollable list")
A:Activate({kind="mapAdvisor",command="zone",id=1421})
assert(A.document.cards[1].title=="Silverpine Forest")
A:Activate(A.document.cards[1].blocks[1].action)
assert(A.state.view=="settings" and A.state.filter=="Map" and M.controls:IsVisible() and not M.navigation:IsShown())
local before=s.rare; M.controls.checks.rare:SetChecked(not before)
MOCK.Click(M.controls.checks.rare); assert(s.rare~=before)
A:Navigate("supplies"); assert(not M.controls:IsShown())
