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
local s=M:Settings(); assert(s.reveal=="tint" and s.notify)
s.notify=false; assert(not M:Settings().notify,"Explicit opt-out survives default change")
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
scale=2; map:OnCanvasScaleChanged(); assert(M.pins[1]:GetWidth()==9)
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
-- Classic Era EPL uses different geometry from Wrath's expanded map.
mapID=1423; art=1213
pin:RefreshOverlays()
local files={}
for _,texture in ipairs(M.exploration[pin]) do if texture:IsShown() then files[texture.texture]=true end end
assert(files[271530] and not files[4357862] and not files[4357864],"Era overlays, not Wrath's green missing assets")
local setTexture=t.SetTexture
t.SetTexture=function() return false end
pin:RefreshOverlays(); assert(not t:IsShown(),"Failed texture stays hidden")
t.SetTexture=setTexture
mapID=1436; art=1240; pin:RefreshOverlays()
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
assert((not M.navigation or not M.navigation:IsShown()) and (not M.controls or not M.controls:IsVisible()) and A.document.cards[1].title=="Map Advisor")
A:Activate({kind="mapAdvisor",command="zones"})
assert(#A.document.cards[1].blocks==47,"All zones in a single scrollable list")
A:Activate({kind="mapAdvisor",command="zone",id=1421})
assert(A.document.cards[2].title=="Silverpine Forest")
A:Activate(A.document.cards[1].blocks[2].action)
assert(A.state.view=="settings" and A.state.filter=="Map" and M.controls:IsVisible() and (not M.navigation or not M.navigation:IsShown()))
local before=s.rare; M.controls.checks.rare:SetChecked(not before)
MOCK.Click(M.controls.checks.rare); assert(s.rare~=before)
A:Navigate("supplies"); assert(not M.controls:IsShown())

-- Nearby locations merge even across the former 3-percent cell boundary.
local records=M.Records
local function record(id,name,kind,locations)
    return {id=id,npc={name=name,kind=kind,min=20,max=22,locations={[1436]=locations}}}
end
local fixture={record(1,"Rare neighbour","rare",{{2.9,10},{3,10}}),
    record(2,"Elite neighbour","elite",{{3.9,10}}),record(3,"Far away","danger",{{70,70}})}
M.Records=function() return fixture end
mapID=1436; scale=1; canvas:SetSize(1000,1000)
map:OnCanvasSizeChanged()
local clusters=M:Clusters(1436)
assert(#clusters==2 and #clusters[1].records==2 and clusters[1].kind=="elite","Close mixed categories combine; duplicate NPC locations appear once")
M:Tooltip(M.pins[1])
assert(GameTooltip.lines[1]:find("2 NPCs",1,true))
assert(GameTooltip.lines[2]:find("Rare neighbour",1,true))
assert(GameTooltip.lines[3]:find("Elite neighbour",1,true))
assert(M.pins[1]:GetWidth()==18,"Smaller map icons")
scale=2; map:OnCanvasScaleChanged()
local shown=0; for _,p in ipairs(M.pins) do if p:IsShown() then shown=shown+1 end end
assert(shown==3 and M.pins[1]:GetWidth()==9,"Zoom rebuilds clusters without enlarging icons")
scale=1; map:OnCanvasScaleChanged()
assert(not M.pins[3]:IsShown(),"Merged pins leave no stale icon")
fixture={}
for i=1,12 do fixture[i]=record(i,"Grouped NPC "..i,"rare",{{30+i/100,30}}) end
M:RefreshPins(); M:Tooltip(M.pins[1])
assert(GameTooltip.lines[13]:find("Grouped NPC 12",1,true),"Combined tooltip includes every NPC")
M.Records=records

-- Close chains cannot merge an entire camp; all members must fit the radius.
M.Records=function() return {record(1,"A","rare",{{10,10}}),record(2,"B","rare",{{11,10}}),record(3,"C","rare",{{12,10}})} end
scale=1
assert(#M:Clusters(1436)==2,"No transitive chain clustering")
M.Records=function() return {record(1,"A","rare",{{10,10}}),record(2,"B","rare",{{11.5,10}})} end
assert(#M:Clusters(1436)==1,"Slightly wider 16px cluster distance includes a 15px neighbour")
local previousTexture=C_Texture
C_Texture={GetAtlasInfo=function(name) return {width=32,height=32} end}
for _,p in ipairs(M.pins) do p.icon.SetAtlas=function(self,name) self.testAtlas=name end end
M.Records=function() return {record(1,"Rare","rare",{{10,10}}),record(2,"Elite","elite",{{40,40}}),record(3,"Danger","danger",{{70,70}}),record(4,"Boss","boss",{{90,90}})} end
M:RefreshPins()
assert(M.pins[1].icon.testAtlas=="nameplates-icon-elite-silver")
assert(M.pins[2].icon.testAtlas=="nameplates-icon-elite-gold")
assert(M.pins[3].icon.testAtlas=="services-icon-warning")
assert(M.pins[4].icon.texture=="Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
C_Texture=previousTexture; M.Records=records

-- Appearance settings update the map, persist, and reset independently of filters.
s.notify=false
A:OpenSettings("Map")
local controls=M.controls
ColorPickerFrame=CreateFrame("Frame")
function ColorPickerFrame:GetColorRGB() return self.r,self.g,self.b end
function ColorPickerFrame:SetupColorPickerAndShow(info) self.info=info; self.r,self.g,self.b=info.r,info.g,info.b; self:Show() end
MOCK.Click(controls.tintColor)
assert(ColorPickerFrame.info.r==s.tintR and not ColorPickerFrame.info.hasOpacity,"Native color picker opens with saved RGB")
ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=1,0,128/255
ColorPickerFrame.info.swatchFunc()
assert(s.tintR==1 and s.tintG==0 and s.tintB==128/255,"Native picker previews RGB")
ColorPickerFrame.info.cancelFunc()
assert(s.tintR==0.35 and s.tintG==0.65 and s.tintB==1,"Cancel restores RGB")
ColorPickerFrame.info.swatchFunc(); ColorPickerFrame:Hide()
-- Classic fallback uses the same saved color and restores it on cancel.
ColorPickerFrame.SetupColorPickerAndShow=nil
function ColorPickerFrame:SetColorRGB(r,g,b) self.r,self.g,self.b=r,g,b end
MOCK.Click(controls.tintColor)
ColorPickerFrame.r,ColorPickerFrame.g,ColorPickerFrame.b=0,1,0
ColorPickerFrame.func(); assert(s.tintG==1)
ColorPickerFrame.cancelFunc(); ColorPickerFrame:Hide()
assert(s.tintR==1 and s.tintG==0 and s.tintB==128/255 and s.tintAlpha==0.55,"Color choice leaves opacity unchanged")
controls.sliders.tintAlpha:SetValue(25)
controls.sliders.iconSize:SetValue(30); controls.sliders.iconAlpha:SetValue(40)
now=now+1; M.events.scripts.OnUpdate(M.events)
mapID=1436; art=1240; scale=1; s.reveal="tint"; known={}
M:Attach(); M:RefreshPins()
assert(t.vertexColor[1]==1 and t.vertexColor[2]==0 and t.vertexColor[3]==128/255 and t.vertexColor[4]==0.25)
assert(M.pins[1]:GetWidth()==30 and M.pins[1].icon:GetAlpha()==0.4)
local oldIcon=s.icons.rare; MOCK.Click(controls.icons.rare)
assert(s.icons.rare==oldIcon and A.state.mapIconKind=="rare" and M.iconPicker:IsVisible() and not controls:IsShown(),"Category opens picker without changing its icon")
local choices=0
for _,key in ipairs(M.iconChoices) do
    local b=M.iconPicker.choices[key]; assert(b and b:IsVisible()); choices=choices+1
    MOCK.Click(b); assert(s.icons.rare==key and b.selected and b.icon)
end
assert(choices==24 and A:CanGoBack(),"All 24 transparent map symbols are listed")
for index,key in ipairs(M.iconChoices) do
    local button=M.iconPicker.choices[key]
    local x,y,w,h=button:GetRect()
    if index%6~=1 then
        local px,py,pw=M.iconPicker.choices[M.iconChoices[index-1]]:GetRect()
        assert(x>=px+pw and y==py,"Six columns without overlap")
    elseif index>1 then
        local px,py=M.iconPicker.choices[M.iconChoices[index-6]]:GetRect()
        assert(x==px and math.abs(y-py)>h,"Next row starts in the first column")
    end
end
assert(M.iconPicker:IsVisible(),"Icon grid opens")
MOCK.Click(A.window.back)
assert(not A.state.mapIconKind and not M.iconPicker:IsShown() and controls:IsVisible())
MOCK.Click(controls.icons.elite); MOCK.Click(M.iconPicker.choices.star)
assert(s.icons.elite=="star" and M.iconPicker.choices.rare.label:GetText()=="Rare","Picker previews actual choices, not another category's saved icon")
A:OpenSettings("General"); A:OpenSettings("Map")
assert(not M.iconPicker:IsShown() and controls:IsVisible(),"Picker hides on section changes")
assert(s.tintR==1 and s.iconSize==30 and not s.notify)
MOCK.Click(controls.resetExploration); MOCK.Click(controls.resetMarkers)

-- Changing icon size rebuilds cluster membership, not just pin dimensions.
M.Records=function() return {record(1,"A","rare",{{10,10}}),record(2,"B","elite",{{12,10}})} end
scale=1; canvas:SetSize(1000,1000); mapID=1436
controls.sliders.iconSize:SetValue(12); now=now+1; M.events.scripts.OnUpdate(M.events)
assert(M.pins[1]:IsShown() and M.pins[2]:IsShown(),"Small icons stay separate")
controls.sliders.iconSize:SetValue(30); now=now+1; M.events.scripts.OnUpdate(M.events)
assert(#M.pins[1].cluster.records==2 and not M.pins[2]:IsShown(),"Larger icons recluster and hide the old pin")
controls.sliders.iconSize:SetValue(12); now=now+1; M.events.scripts.OnUpdate(M.events)
assert(M.pins[2]:IsShown(),"Reducing icon size splits the cluster again")
M.Records=records; MOCK.Click(controls.resetExploration); MOCK.Click(controls.resetMarkers)
assert(s.tintR==0.35 and s.iconSize==18 and s.iconAlpha==1 and s.icons.rare=="rare" and not s.notify)
s.iconSize=999; s.iconAlpha=-10; s.icons.rare="bad"; M:Settings()
assert(s.iconSize==40 and s.iconAlpha==0.1 and s.icons.rare=="rare")
MOCK.Click(controls.resetExploration); MOCK.Click(controls.resetMarkers)

-- Section resets stay isolated; Reset all clears only Map preferences.
s.reveal="off"; s.tintR=1; s.iconSize=30; s.icons.rare="star"; s.rare=false; s.notify=false
MOCK.Click(controls.resetExploration)
assert(s.reveal=="tint" and s.tintR==0.35 and s.iconSize==30 and s.icons.rare=="star" and not s.rare and not s.notify,"Exploration reset is isolated")
s.reveal="off"; s.tintR=1
MOCK.Click(controls.resetMarkers)
assert(s.iconSize==18 and s.icons.rare=="rare" and s.rare and s.reveal=="off" and s.tintR==1 and not s.notify,"Marker reset is isolated")
MOCK.Click(controls.resetNotices)
assert(s.notify and s.reveal=="off" and s.tintR==1,"Notices reset is isolated")
MOCK.Click(controls.tintColor)
local cancel=ColorPickerFrame.cancelFunc
MOCK.Click(controls.resetAll); cancel()
assert(s.reveal=="tint" and s.tintR==0.35 and s.tintG==0.65 and s.tintB==1 and s.tintAlpha==0.55
    and s.iconSize==18 and s.iconAlpha==1 and s.notify and s.rare and s.elite and s.boss and s.danger,"Reset all restores Map defaults; stale picker Cancel cannot undo it")
assert(A.Settings.content.skinKind=="note" and controls:GetHeight()==M:SettingsHeight(),"Map has no nested background or unused trailing section")
ColorPickerFrame:Hide()
-- Marker click opens a paged native model inside HardcoreBuddy; Back restores context.
A:Navigate("supplies"); local previousState=A.state
M.pins[1].cluster={records={{id=589},{id=2529},{id=589}}}
MOCK.Click(M.pins[1])
assert(A.state.view=="advisors" and A.state.filter=="Map" and #A.state.mapNPCs==2)
assert(not map:IsShown() and A:CanGoBack())
local viewer=M.viewer
assert(viewer:IsVisible() and viewer.model.creatureID==589 and not viewer.previous:IsEnabled() and viewer.next:IsEnabled())
assert(viewer.title:GetText()==A.Data.MapNPCs[589].name)
assert(viewer.modelState=="loading" and viewer.loading:GetText()=="Loading Model...." and viewer.status:IsShown() and not viewer.retry:IsShown())
viewer.model.scripts.OnUpdate(viewer.model,0.1)
local alpha=viewer.dots[1]:GetAlpha()
viewer.model.scripts.OnUpdate(viewer.model,0.2)
assert(viewer.dots[1]:GetAlpha()~=alpha,"Loading dots animate while waiting")
viewer.model.modelFileID=123; viewer.model.scripts.OnModelLoaded(viewer.model)
assert(viewer.modelState=="loaded" and not viewer.status:IsShown() and not viewer.retry:IsShown() and viewer.reset:IsShown())
assert(viewer.actor.shown and viewer.bounds and viewer.cameraDistance>0)
assert(viewer.info.skinKind=="card" and viewer.modelBorder.skinKind=="card","Model matches surrounding section")
assert(math.abs(viewer:GetHeight()*viewer:GetScale()-A.window.scroll:GetHeight())<0.01,"Viewer fills available section height")
local ix,iy,iw,ih=viewer.info:GetRect()
local bx,by,bw,bh=viewer.modelBorder:GetRect()
local mx,my,mw,mh=viewer.scene:GetRect()
assert(ix+iw<bx and iy==by and ih==bh,"Details and model are separate side-by-side panels")
assert(mx>bx and my>by and mx+mw<bx+bw and my+mh<by+bh,"Model scene fills the border with a one-pixel inset")
local refreshed=viewer.scene.cameraUpdates
viewer.model.scripts.OnUpdate(viewer.model,0.2); viewer.model.scripts.OnUpdate(viewer.model,0.4)
assert(viewer.scene.cameraUpdates==refreshed+2 and not viewer.settle,"Camera settles twice after model data arrives")
viewer.scene.scripts.OnMouseWheel(viewer.scene,1); assert(math.abs(viewer.distance-1.65)<0.001)
viewer.scene.scripts.OnMouseWheel(viewer.scene,-10); assert(viewer.distance>1.8,"Can zoom out past the default camera")
viewer.scene.scripts.OnMouseWheel(viewer.scene,-100); assert(viewer.distance==8)
MOCK.Click(viewer.reset); assert(viewer.distance==1.8 and viewer.actor.scale>0 and viewer.facing==0.35)
viewer.scene.scripts.OnMouseWheel(viewer.scene,1)
assert(not viewer.settle,"Manual camera changes cancel deferred reframing")
MOCK.Click(viewer.next)
assert(viewer.model.creatureID==2529 and viewer.previous:IsEnabled() and not viewer.next:IsEnabled())
assert(viewer.distance==1.8 and viewer.attempts==1,"New NPC resets its camera and retry count")
viewer.model.scripts.OnUpdate(viewer.model,3)
assert(viewer.attempts==2 and viewer.waiting==0 and viewer.modelState=="loading" and not viewer.retry:IsShown(),"Automatic second attempt")
viewer.model.scripts.OnUpdate(viewer.model,3)
assert(viewer.attempts==3 and viewer.waiting==0,"Automatic third attempt")
viewer.model.scripts.OnUpdate(viewer.model,3)
assert(viewer.loading:GetText():find("unavailable",1,true) and viewer.model.modelFileID==nil,"No previous model on a failed next page")
assert(viewer.retry:IsShown() and viewer.modelState=="failed" and not viewer.dots[1]:IsShown(),"Failure offers Retry Model instead of loading animation")
viewer.model.scripts.OnUpdate(viewer.model,100); assert(viewer.attempts==3 and not viewer.waiting,"Retries are bounded")
MOCK.Click(viewer.retry); assert(viewer.waiting==0 and viewer.attempts==1 and not viewer.retry:IsShown())
viewer.model.scripts.OnUpdate(viewer.model,3)
viewer.model.modelFileID=456; viewer.model.scripts.OnUpdate(viewer.model,0.1)
assert(not viewer.waiting and viewer.attempts==2 and viewer.modelState=="loaded","Retry success is detected even without OnModelLoaded")
viewer.model.scripts.OnUpdate(viewer.model,10); assert(viewer.attempts==2,"Success cancels further retries")
MOCK.Click(viewer.previous); assert(viewer.model.creatureID==589)
A:Back(); assert(A.state==previousState and not viewer:IsShown())
M:OpenNPCs({records={{id=589}}})
assert(not viewer.next:IsEnabled() and not viewer.previous:IsEnabled())
local attempts=viewer.attempts
A:Navigate("supplies"); assert(not viewer:IsShown() and viewer.model.creatureID==nil)
viewer.model.scripts.OnUpdate(viewer.model,100); viewer.model.scripts.OnModelLoaded(viewer.model)
assert(viewer.attempts==attempts and not viewer.waiting and not viewer.settle,"Closing cancels requests and camera work")
local setCreature=viewer.model.SetCreature
viewer.model.SetCreature=function() error("Uncached creature") end
M:OpenNPCs({records={{id=589}}})
for i=1,3 do viewer.model.scripts.OnUpdate(viewer.model,3) end
assert(viewer.attempts==3 and not viewer.waiting,"Native request errors also retry with a limit")
viewer.model.SetCreature=setCreature; A:Navigate("supplies")

-- Zone controls and NPC rows have distinct cards; row navigation preserves Back.
A:Navigate("advisors"); A.state.filter="Map"; A.state.mapZone=1436; A:Refresh(true)
local overview=A.state
local doc=A.document
assert(#doc.cards==2 and #doc.cards[1].blocks==2 and doc.cards[1].blocks[1].action.command=="zones" and doc.cards[1].blocks[2].action.command=="settings")
assert(doc.cards[2].title=="Westfall" and #doc.cards[2].blocks>0)
local npcRow=doc.cards[2].blocks[1]
assert(npcRow.action.command=="npc" and A.Data.MapNPCs[npcRow.action.id].name==npcRow.title)
A:Activate(npcRow.action)
assert(viewer.npcID==npcRow.action.id and #A.state.mapNPCs==1 and viewer.modelState=="loading")
A:Back(); assert(A.state==overview and not viewer:IsShown())
