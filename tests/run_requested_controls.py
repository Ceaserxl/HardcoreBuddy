"""Behavior coverage for journal retention, talent batches, grids and scene fitting."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local T=A.TalentAdvisor
A.db.profile.mode="live"
local ranks,unspent,requests,pending={},3,{},nil
local activeClass
GetNumTalents=function(tree) local n=0; for _,v in pairs(A.Data.AdvisorTalents[activeClass]) do if v.tree==tree then n=n+1 end end; return n end
local function rows(tree)
    local list={}; for key,v in pairs(A.Data.AdvisorTalents[activeClass]) do if v.tree==tree then list[#list+1]={key=key,node=v} end end
    table.sort(list,function(a,b) return a.key<b.key end); return list
end
GetTalentInfo=function(tree,index)
    local r=rows(tree)[index]; local n=r.node
    return n.name,132127,n.tier,n.column,ranks[r.key] or 0,n.maxRank
end
C_SpecializationInfo=nil
UnitCharacterPoints=function() return unspent end
LearnTalent=function(tree,index,pet)
    assert(not pending and not pet,"Only one unacknowledged request is allowed")
    pending=rows(tree)[index].key; requests[#requests+1]=pending
end
local function tick() T.events.scripts.OnUpdate(T.events,0.25) end
for _,class in ipairs({"HUNTER","WARLOCK","MAGE","PRIEST","DRUID","ROGUE","SHAMAN","WARRIOR","PALADIN"}) do
    activeClass=class; MOCK.class=class; MOCK.level=12; A.lastClass=nil
    ranks={}; unspent=3; requests={}; pending=nil
    assert(T:ApplyUnused(false) and #requests==1)
    assert(not T:ApplyUnused(false),"Double click cannot start another batch")
    tick(); tick(); assert(#requests==1,"Waits for server confirmation")
    for i=1,3 do
        assert(pending); ranks[pending]=(ranks[pending] or 0)+1; pending=nil; unspent=unspent-1; tick()
    end
    assert(not T.applying and #requests==3 and unspent==0,"All unused points applied legally for "..class)
end
activeClass="HUNTER"; MOCK.class="HUNTER"; ranks={}; unspent=3; requests={}; pending=nil
A.characterDB.autoApplyTalents=nil
T.events.scripts.OnEvent(T.events,"PLAYER_LEVEL_UP"); tick(); assert(#requests==0,"Automatic application defaults off")
A.characterDB.autoApplyTalents=true
T.events.scripts.OnEvent(T.events,"PLAYER_LEVEL_UP"); tick(); assert(#requests==1)
A.characterDB.autoApplyTalents=false; tick(); assert(not T.applying,"Opting out stops the batch")
pending=nil; ranks={}; requests={}
A.db.profile.mode="preview"; assert(not T:ApplyUnused(false),"Same-class preview cannot spend real talents")
A.db.profile.mode="live"
local oldCombat=InCombatLockdown; InCombatLockdown=function() return true end
assert(not T:ApplyUnused(false)); InCombatLockdown=oldCombat
T:SetEnabled(false); assert(not T:ApplyUnused(false)); T:SetEnabled(true)
assert(T:ApplyUnused(false)); T.events.scripts.OnUpdate(T.events,5)
assert(not T.applying and #requests==1,"Timeout stops without repeating an unconfirmed point")
pending=nil; ranks={}; requests={}
local build=T:Build("HUNTER",12); local targets={}; for _,k in ipairs(build.steps) do targets[k]=true end
for k in pairs(A.Data.AdvisorTalents.HUNTER) do if not targets[k] then ranks[k]=1; break end end
T:ApplyUnused(false); assert(not T.applying and #requests==0,"Divergent path cannot spend points")
print("PASS: Nine-class acknowledged talent batches, default-off automation, preview/combat/disable guards, opt-out, divergence and timeout.")
''')

lua, addon = boot()
lua.execute('''
local A=TestAddon; local H=A.Deaths
local now=20000000; time=function() return now end
H.db.records={}; H.db.settings.retentionDays=30
H:Add({name="Recent",date=now,realm=H.realm,source="Blizzard",level=20},true)
H:Add({name="Expired",date=now-31*86400,realm=H.realm,source="Blizzard",level=20},true)
H:Add({name="Boundary",date=now-30*86400,realm=H.realm,source="Blizzard",level=20},true)
assert(#H.db.records==2)
now=now+1; H:PruneReports(); assert(#H.db.records==1 and H.db.records[1].name=="Recent")
A:OpenSettings("Death Journal")
local edit=H.options.retention; edit:SetFocus(); edit:SetText("1"); A:OpenSettings("Map")
assert(H.db.settings.retentionDays==1)
edit:SetFocus(); edit:SetText("0"); A:OpenSettings("Zone Advisor")
assert(H.db.settings.retentionDays==0,"Zero persists through settings navigation")
local oldLimit=H.MAX_RECORDS; H.MAX_RECORDS=1
assert(H:Add({name="Ancient",date=now-4000*86400,realm=H.realm,source="Blizzard",level=20},true))
assert(#H.db.records==2,"Never keeps old reports beyond count limit")
now=now+4001*86400; H:PruneReports(); assert(#H.db.records==2,"Never survives passage of time")
H.MAX_RECORDS=oldLimit
H.db.records={{name="Recent",date=now,realm=H.realm,source="Blizzard",level=20}}
H.db.settings.retentionDays=math.huge; H:PruneReports(); assert(H.db.settings.retentionDays==30)
H.db.settings.retentionDays=-5; H:PruneReports(); assert(H.db.settings.retentionDays==1)
A:OpenDeaths(); assert(not A.window.sidebar:IsShown() and not H.window.import)
local x,y,w,h=H.window.settings:GetRect(); assert(MOCK.HitTest(x+w/2,y+h/2)==H.window.settings)
MOCK.Click(H.window.settings); assert(A.state.filter=="Death Journal" and H.options.import:IsVisible())
A:OpenDeaths(); local generation=H.importGeneration or 0; H.importing=true
MOCK.Click(H.window.clear); assert(#H.db.records==1 and H.window.clear.label:GetText()=="Confirm clear")
MOCK.Click(H.window.clear); assert(#H.db.records==0 and #H.filtered==0 and not H.importing and H.importGeneration==generation+1)
local queued={}; local after=C_Timer.After; C_Timer.After=function(_,fn) queued[#queued+1]=fn end
deathlog_data={[H.realm]={}}
for i=1,105 do deathlog_data[H.realm][i]={name="Imported"..i,date=now,level=20} end
H:ImportLegacy(); assert(H.importing and #queued>0)
H:ClearReports()
for _,fn in ipairs(queued) do fn() end
assert(#H.db.records==0 and not H.importing,"Queued import callbacks cannot repopulate a cleared journal")
C_Timer.After=after
H.db.settings.retentionDays=0; H.MAX_RECORDS=1
deathlog_data={[H.realm]={}}
for i=1,3 do deathlog_data[H.realm][i]={name="OldImport"..i,date=now-4000*86400,level=20} end
H:ImportLegacy()
assert(not H.importing and #H.db.records==3,"Never also preserves unlimited old imported reports")
H.MAX_RECORDS=oldLimit
print("PASS: Retention boundaries and validation, persisted edits, journal settings link, no sidebar, confirmed clear and import cancellation.")
''')

lua, addon = boot()
lua.execute('''
local A=TestAddon; local M=A.MapAdvisor
M:OpenNPCs({records={{id=2757}}})
local f=M.viewer
-- Exaggerated, off-origin dragon bounds including its wings and tail.
f.actor.bottom={x=-20,y=-12,z=-5}; f.actor.top={x=40,y=14,z=23}
f.model.modelFileID=123; f.model.scripts.OnModelLoaded(f.model)
assert(f.modelState=="loaded" and f.actor.shown)
for _,angle in ipairs({0,0.35,1.5,3.14}) do
    f.facing=angle; f:ApplyCamera()
    local b=f.bounds; local p=f.actor.position; local c,s=math.cos(angle),math.sin(angle)
    assert(math.abs((b.x*c-b.y*s)/b.radius+p[1])<0.00001)
    assert(math.abs((b.x*s+b.y*c)/b.radius+p[2])<0.00001)
    assert(math.abs(b.z/b.radius+p[3])<0.00001)
    assert(f.cameraDistance>1/math.sin(f.scene.fov/2),"Entire bounding sphere fits vertically")
end
local x,y,w,h=f.scene:GetRect(); local xx,yy,ww,hh=f.modelBorder:GetRect()
assert(x==xx+1 and y==yy+1 and w==ww-2 and h==hh-2,"Viewport fills bordered section")
assert(f.status:GetFrameLevel()>f.scene:GetFrameLevel() and f.scene.lightVisible)
local loader=f.actor.SetModelByCreatureDisplayID; local requests=0
f.actor.SetModelByCreatureDisplayID=function() requests=requests+1; return false end
f:RequestModel(true); f.model.modelFileID=123
for i=1,10 do f.model.scripts.OnUpdate(f.model,0.1) end
assert(requests==1 and f.modelState=="loading","Uncached actor requests do not repeat every frame")
f.model.scripts.OnUpdate(f.model,3); f.model.modelFileID=123; f.model.scripts.OnUpdate(f.model,0.1)
assert(requests==2,"Retry timer owns the next display request")
f.actor.SetModelByCreatureDisplayID=loader
for _,tab in ipairs({"Spells","Zone Advisor"}) do
    A:Navigate("training"); A.state.filter=tab; A:Refresh(true)
    local checked=0
    for _,card in ipairs(A.window.cards) do
        if card:IsVisible() and card.content.blocks[2] and card.content.blocks[2]:IsShown() then
            local a,b=card.content.blocks[1],card.content.blocks[2]
            local x,y,w=a:GetRect(); local xx,yy=b:GetRect()
            assert(xx>=x+w and y==yy,"Paired "..tab.." rows"); checked=checked+1
        end
    end
    assert(checked>0)
end
A:Navigate("supplies")
local blocks=A.window.cards[1].content.blocks
local a,b=blocks[1],blocks[2]; local x,y,w=a:GetRect(); local xx,yy=b:GetRect()
assert(a.supplyTile and b.supplyTile and xx>=x+w and y==yy)
assert(not a.quantity:IsShown() and not a.count:IsShown(),"List hides bag and quantity controls")
MOCK.Click(a)
a=A.window.cards[1].content.blocks[1]
local q=A.window.cards[1].detailQuantity.quantity; assert(q:IsShown(),"Opening item exposes quantity editor")
local qx,qy,qw,qh=q:GetRect(); assert(MOCK.HitTest(qx+qw/2,qy+qh/2)==q,"Carry editor is above the card")
q:SetFocus(); q:SetText("17"); q:ClearFocus(); A:Refresh()
assert(A.window.cards[1].detailQuantity.quantity:GetText()=="17","Carry edits survive card refresh")
for _,section in ipairs(A.Settings.sections) do
    A:OpenSettings(section)
    local sx,sy,sw,sh=A.Settings.scroll:GetRect()
    for _,control in ipairs(MOCK.frames) do
        if control:IsVisible() and control:IsEnabled() and control.scripts.OnClick and control.skinButton then
            local parent=control:GetParent(); local inSettings=false
            while parent do if parent==A.Settings.content then inSettings=true; break end; parent=parent:GetParent() end
            if inSettings then
                local x,y,w,h=control:GetRect(); local cx,cy=x+w/2,y+h/2
                if cx>=sx and cx<sx+sw and cy>=sy and cy<sy+sh then
                    assert(MOCK.HitTest(cx,cy)==control,"Settings control is covered: "..section.." / "..tostring(control.label and control.label:GetText()))
                end
            end
        end
    end
    for _,frame in ipairs(MOCK.frames) do
        if frame.sectionCards and frame:IsVisible() then
            for _,panel in ipairs(frame.sectionCards) do
                if panel.sectionFill then assert(panel.sectionFill.drawLayer=="BACKGROUND" and not panel.mouse,"Decorations cannot cover controls") end
            end
        end
    end
end
print("PASS: Large off-center model bounds, rotation-safe centering, fitted viewport, two-column grids, editable supplies and background layering.")
''')
