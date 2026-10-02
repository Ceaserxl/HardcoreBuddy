"""Vendor priority and independent world/minimap marker geometry."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute('''
local A=TestAddon; local V,M=A.VendorServices,A.VendorMarker
local mapID=1453
local function vector(x,y) return {GetXY=function() return x,y end} end
CreateVector2D=vector
C_Map=C_Map or {}
C_Map.GetBestMapForUnit=function() return mapID end
C_Map.GetPlayerMapPosition=function() return vector(.5,.5) end
C_Map.GetWorldPosFromMapPos=function(map,p) local x,y=p:GetXY(); return map==1453 and 0 or 1,vector(-y*1000,-x*1000) end
UnitFactionGroup=function() return 'Alliance' end
InCombatLockdown=function() return false end
A.characterDB.vendorVisits={}
A.Data.SupplySoldBy[999]={1,2,3}
A.Data.SupplyVendors[1]={name='Roamer',faction='A',movement='roaming',locations={[1453]={{50.1,50}}}}
A.Data.SupplyVendors[2]={name='Fixed shop',faction='A',movement='stationary',locations={[1453]={{60,50}}}}
A.Data.SupplyVendors[3]={name='Enemy',faction='H',movement='stationary',locations={[1453]={{50,50}}}}
local chosen=V:FindVendor(999)
assert(chosen.name=='Fixed shop' and chosen.x==60,'Stationary seller wins over nearer roaming seller')
A.characterDB.vendorVisits[1]={name='Roamer',faction='A',items={[999]=true},locations={[1453]={{50,50}}}}
assert(V:FindVendor(999).name=='Fixed shop','Learned visits cannot promote a known roaming vendor to stationary')
A.Data.SupplySoldBy[999]={1,3}
assert(V:FindVendor(999).name=='Roamer','Roaming vendor used when stationary vendor does not sell the item')
WorldMapFrame=CreateFrame('Frame',nil,UIParent); WorldMapFrame:Show()
local canvas=CreateFrame('Frame',nil,WorldMapFrame); canvas:SetSize(1000,700)
WorldMapFrame.GetCanvas=function() return canvas end
WorldMapFrame.GetMapID=function() return mapID end
WorldMapFrame.GetCanvasScale=function() return 1 end
Minimap=CreateFrame('Frame',nil,UIParent); Minimap:SetSize(200,200)
Minimap.GetZoom=function() return 0 end
C_Minimap={GetViewRadius=function() return 200 end}
local rotate=false
GetCVar=function(key) return key=='rotateMinimap' and (rotate and '1' or '0') or '0' end
GetPlayerFacing=function() return math.pi/2 end
M:Set(chosen,'Food')
assert(M.mapPin:IsShown() and M.miniPin:IsShown())
local _,_,_,x,y=M.mapPin:GetPoint(); assert(x==600 and y==-350,'World map coordinates')
local _,_,_,x,y=M.miniPin:GetPoint(); assert(math.abs(x-50)<.01 and y==0,'East is right on minimap')
rotate=true; M:Update()
local _,_,_,x,y=M.miniPin:GetPoint(); assert(math.abs(x)<.01 and math.abs(y+50)<.01,'Rotating minimap projection')
rotate=false; chosen.x=99; M:Set(chosen,'Food')
local _,_,_,x,y=M.miniPin:GetPoint(); assert(math.abs(x-85)<.01,'Distant marker stays inside minimap edge')
C_Minimap.GetViewRadius=nil; M:Update()
assert(M.miniPin:IsShown(),'Classic minimap radius fallback')
WorldMapFrame:Hide(); M:Update(); assert(not M.mapPin:IsShown() and M.miniPin:IsShown(),'Closed world map leaves minimap marker visible')
WorldMapFrame:Show()
mapID=1454; M:Update(); assert(not M.mapPin:IsShown() and not M.miniPin:IsShown(),'Wrong zone/map instance hides pins')
mapID=1453; M:Update(); assert(M.mapPin:IsShown() and M.miniPin:IsShown())
M.mapPin.scripts.OnClick(); assert(not M.target and not M.driver:IsShown(),'Right-click clears only our marker')
A.Data.SupplySoldBy[999]={2}
A.Readiness:ShowPanel({{itemId=999,name='Food',count=0,target=5}})
local row=A.Readiness.panel.rows[1]
row.scripts.PostClick(row,'LeftButton',false)
assert(M.target.name=='Fixed shop' and A.Readiness.panel:IsShown(),'Missing item click marks vendor without closing panel')
print('PASS: stationary-first vendors, roaming fallback, map/minimap geometry, rotation, edge clamp, clear and essentials click.')
''')
