"""Exercise live adapters, replayable priorities, highlight isolation and UI lifecycle."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite

lua, addon = boot()
lua.execute(r'''
local A=TestAddon; local R=A.RotationAdvisor
local count=0
local function check(value,message) count=count+1; assert(value,message) end
local function decision(s,key)
    local actual,reason=R.Decide(s)
    check(actual==key,"Expected "..tostring(key)..", got "..tostring(actual)..": "..tostring(reason))
    check(type(reason)=="string" and #reason>0,"Every decision explains itself")
end
local function state(class,keys)
    local s={class=class,spells={},buffs={},combat=true,validTarget=true,
        playerHealth=100,targetHealth=100,powerPercent=100,power=100,
        targets=1,nearby=1,safeAOE=true,targetClose=true,combo=0}
    for _,key in ipairs(keys or (class=="ROGUE" and {"strike"} or {"frostbolt","fireball","fireblast"})) do
        s.spells[key]={id=1,ready=true,usable=true,range=true}
    end
    return s
end
for _,class in ipairs({"ROGUE","MAGE"}) do
    local base=class=="ROGUE" and "strike" or "frostbolt"
    decision(state(class),base)
    for _,field in ipairs({"dead","mounted","casting","controlled","targetPlayer"}) do
        local s=state(class); s[field]=true; decision(s,nil)
    end
    local s=state(class); s.validTarget=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].range=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].usable=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].ready=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].range=nil; decision(s,base)
end
decision(state("WARRIOR",{}),nil)
local s=state("ROGUE",{"strike","eviscerate","slice"})
s.combo=5; decision(s,"eviscerate")
s.combo=3; s.targetHealth=15; decision(s,"eviscerate")
s.combo=1; s.targetHealth=70; decision(s,"slice")
s.buffs.slice=10; decision(s,"strike")
s.buffs.slice=2; decision(s,"slice")
s.targetHealth=35; decision(s,"strike")
s=state("ROGUE",{"strike","kick","evasion"}); s.interrupt=true; decision(s,"kick")
s.spells.kick.range=false; decision(s,"strike")
s.playerHealth=25; s.attackingPlayer=true; decision(s,"evasion")
s.buffs.evasion=4; decision(s,"strike")
s=state("ROGUE",{"strike","cheapshot"}); s.stealthed=true; decision(s,"cheapshot")
s=state("ROGUE",{"strike","riposte"}); decision(s,"riposte")
s.spells.riposte.usable=false; decision(s,"strike")
s=state("ROGUE",{"strike","hemorrhage"}); decision(s,"hemorrhage")
s=state("ROGUE",{"strike","flurry"}); s.nearby=2; decision(s,"flurry")
s.safeAOE=false; decision(s,"strike")
s.safeAOE=true; s.buffs.flurry=3; decision(s,"strike")
s=state("MAGE",{"frostbolt","counterspell"}); s.interrupt=true; decision(s,"counterspell")
s.spells.counterspell.ready=false; decision(s,"frostbolt")
s=state("MAGE",{"frostbolt","barrier","nova","shield"})
s.playerHealth=55; decision(s,"barrier")
s.buffs.barrier=10; decision(s,"frostbolt")
s.playerHealth=35; decision(s,"nova")
s.safeAOE=false; decision(s,"frostbolt")
s.buffs.barrier=nil; s.spells.barrier.ready=false; decision(s,"shield")
s.powerPercent=30; decision(s,"frostbolt")
s=state("MAGE",{"evocation","frostbolt"}); s.combat=false; s.powerPercent=20; decision(s,"evocation")
s.combat=true; decision(s,"frostbolt")
s=state("MAGE",{"frostbolt","shoot"}); s.powerPercent=10; decision(s,"shoot")
s.spells.shoot.usable=false; decision(s,"frostbolt")
s=state("MAGE"); s.moving=true; decision(s,"fireblast")
s.spells.fireblast.ready=false; decision(s,nil)
s=state("MAGE"); s.targetHealth=15; decision(s,"fireblast")
s=state("MAGE",{"fireball"}); decision(s,"fireball")
s=state("MAGE",{"frostbolt","explosion"}); s.nearby=3; decision(s,"explosion")
s.safeAOE=false; decision(s,"frostbolt")
s.safeAOE=true; s.powerPercent=20; decision(s,"frostbolt")
s.powerPercent=100; s.targetClose=nil; decision(s,"frostbolt")
s.targetClose=true; s.powerPercent=nil; decision(s,"frostbolt")
s.powerPercent=100; s.playerHealth=nil; decision(s,"frostbolt")
s=state("ROGUE",{"strike","slice","flurry"}); s.combo=1; s.targetHealth=nil; s.nearby=2
decision(s,"strike")
s=state("MAGE",{"frostbolt","shoot","counterspell"}); s.powerPercent=10; s.wanding=true
decision(s,nil)
s.interrupt=true; decision(s,"counterspell")
s=state("MAGE",{"shoot"}); s.wanding=true; decision(s,nil)

-- Simulate actual client reads; selection uses learned ranks, not future ranks.
local now,combat=100,false
GetTime=function() return now end
InCombatLockdown=function() return combat end
MOCK.class="MAGE"
local spellData={
    [116]={name="Frostbolt",iconID=135846},[205]={name="Frostbolt",iconID=135846},
    [837]={name="Frostbolt",iconID=135846},[2136]={name="Fire Blast",iconID=135807},
    [122]={name="Frost Nova",iconID=135848},[118]={name="Polymorph",iconID=136071},
    [5019]={name="Shoot",iconID=135139},
}
local learned={[116]=true,[205]=true,[2136]=true,[122]=true,[5019]=true}
local ready,range,usable={},{},{}
C_Spell={
    GetSpellInfo=function(id) return spellData[id] end,
    GetSpellCooldown=function(id) return ready[id] or {startTime=0,duration=0,isEnabled=true} end,
    IsSpellUsable=function(id) return usable[id]~=false,usable[id]==false end,
    IsSpellInRange=function(id) return range[id] end,
    GetSpellSubtext=function(id) return id==837 and 'Rank 3' or nil end,
}
IsPlayerSpell=function(id) return learned[id] or false end
C_SpellBook=nil; IsSpellKnown=function() return false end
R:RefreshSpells()
check(R.spells.frostbolt.id==205,"Highest learned rank is used")
check(R.spells.barrier==nil,"Unlearned talent spells excluded")
learned[837]=true; R.dirty=true; R:RefreshSpells()
check(R.spells.frostbolt.id==837,"Newly trained rank replaces old rank")
check(R.spells.frostbolt.rank=='Rank 3','Recommendation retains learned rank for display')
local st=R:SpellState(R.spells.frostbolt,"target")
check(st.ready and st.usable and st.range==nil,"Unknown range stays unknown")
range[837]=0; st=R:SpellState(R.spells.frostbolt,"target"); check(st.range==false,"Legacy zero range is false")
range[837]=1; st=R:SpellState(R.spells.frostbolt,"target"); check(st.range==true,"Legacy one range is true")
ready[837]={startTime=99,duration=10,isEnabled=true}
check(not R:SpellState(R.spells.frostbolt,"target").ready,"Real cooldown blocks recommendation")
ready[837]={startTime=100,duration=1.5,isEnabled=true}; ready[61304]=ready[837]
check(R:SpellState(R.spells.frostbolt,"target").ready,"GCD alone does not clear next-spell guidance")
ready[837]={startTime=0,duration=0,isEnabled=false}
check(not R:SpellState(R.spells.frostbolt,"target").ready,"Disabled cooldown is not ready")
ready={}; usable[837]=false
check(R:SpellState(R.spells.frostbolt,"target").lowPower,"Mana failure is preserved")
usable={}

local units={
    player={health=700,max=1000,power=200,maxPower=1000,x=0,y=0,map=1},
    target={guid="enemy1",health=500,max=1000,power=100,maxPower=400,x=3,y=0,map=1,hostile=true,engaged=true},
    pet={health=30,max=100},
    nameplate1={guid="enemy1",x=3,y=0,map=1,hostile=true,engaged=true},
    nameplate2={guid="enemy2",x=4,y=0,map=1,hostile=true,engaged=true},
    nameplate3={guid="enemy3",x=5,y=0,map=1,hostile=true,engaged=true},
}
UnitExists=function(u) return units[u]~=nil end
UnitCanAttack=function(_,u) return units[u] and units[u].hostile end
UnitGUID=function(u) return units[u] and units[u].guid end
UnitIsDeadOrGhost=function(u) return units[u] and units[u].dead end
UnitHealth=function(u) return units[u] and units[u].health or 0 end
UnitHealthMax=function(u) return units[u] and units[u].max or 0 end
UnitPower=function(u) return units[u] and units[u].power or 0 end
UnitPowerMax=function(u) return units[u] and units[u].maxPower or 0 end
UnitPowerType=function() return 0 end
UnitThreatSituation=function(_,u) return units[u] and units[u].engaged and 0 or nil end
UnitIsUnit=function(a,b) return a==b end
UnitIsPlayer=function(u) return u=="player" end
UnitPosition=function(u) local p=units[u] or {}; return p.x,p.y,0,p.map end
CheckInteractDistance=function() return false end
GetComboPoints=function() return 0 end
GetUnitSpeed=function() return 0 end
IsStealthed=function() return false end
IsMounted=function() return false end
UnitOnTaxi=function() return false end
local casts={}
UnitCastingInfo=function(u) if casts[u] then return "Test cast",nil,nil,now*1000,(now+2)*1000,false,1,casts[u].blocked end end
UnitChannelInfo=function() end
local auras={}
C_UnitAuras={GetAuraDataByIndex=function(u,i,filter) return auras[u] and auras[u][filter] and auras[u][filter][i] end}
C_NamePlate={GetNamePlates=function() return {{namePlateUnitToken="nameplate1"},{UnitFrame={unit="nameplate2"}},{namePlateUnitToken="nameplate3"}} end}
local enemies,nearby,safe=R:Enemies()
check(enemies==3 and nearby==3 and safe,"Nameplates deduplicate target and establish observed engaged neighbors")
units.nameplate3.engaged=false
enemies,nearby,safe=R:Enemies(); check(enemies==2 and nearby==2 and not safe,"Nearby unengaged enemy prevents AoE")
units.nameplate3.engaged=true
auras.nameplate2={HARMFUL={{name="Polymorph",expirationTime=110}}}
enemies,nearby,safe=R:Enemies(); check(not safe,"Crowd-controlled neighbor prevents AoE")
auras={}; units.nameplate3.x=nil
enemies,nearby,safe=R:Enemies(); check(not safe,"Unknown neighbor distance prevents AoE")
units.nameplate3.x=50
enemies,nearby,safe=R:Enemies(); check(nearby==2 and safe,"Observed distant enemies do not count as close")
units.nameplate3.x=9; units.nameplate3.engaged=false
enemies,nearby,safe=R:Enemies(); check(not safe,'Unengaged enemy between 8 and 10 yards blocks Mage area damage')
units.nameplate3.engaged=true
R.class='ROGUE'; enemies,nearby,safe=R:Enemies()
check(nearby==2 and safe,'Rogue cleave counts five-yard enemies, not every ten-yard neighbor')
R.class='MAGE'
local position=UnitPosition
UnitPosition=function(u)
 local p=units[u] or {}; return p.x,p.y,u=='nameplate3' and 20 or 0,p.map
end
enemies,nearby,safe=R:Enemies(); check(nearby==2,'Enemy on another floor is not nearby')
UnitPosition=position
units.nameplate3.map=nil
enemies,nearby,safe=R:Enemies(); check(not safe,'Unavailable instance identity cannot establish an area-safe distance')
units.nameplate3.map=1; units.nameplate3.x=50
local snap=R:Snapshot()
check(snap.playerHealth==70 and snap.powerPercent==20 and snap.targetHealth==50,"Snapshot reads player and target percentages")
check(snap.targetMana==25 and snap.petHealth==30,"Target mana and pet health are available as context")
casts.target={blocked=false}; check(R:Snapshot().interrupt,"Interruptible target cast detected")
casts.target.blocked=true; check(not R:Snapshot().interrupt,"Uninterruptible cast excluded")
casts={}; auras.target={HARMFUL={{name="Polymorph",expirationTime=110}}}
check(R:Snapshot().controlled,"Current target crowd control detected")
auras.target.HARMFUL[1].expirationTime=99
check(not R:Snapshot().controlled,'Expired control aura does not stall the advisor')
auras={}; units.pet=nil
check(R:Snapshot().petHealth==nil,"Missing pets remain unknown, not zero health")
units.player.max=0; check(R:Snapshot().playerHealth==nil,"Unknown maximum health cannot divide by zero")
units.player.max=1000; units.player.power=900; combat=true

-- Overlay belongs to HCB. Native procs and secure action attributes stay untouched.
local action=CreateFrame("CheckButton","ActionButton1",UIParent); action:SetSize(36,36); action:Show(); action.action=1
local other=CreateFrame("CheckButton","MultiBarBottomLeftButton1",UIParent); other:Show(); other.action=2
local lower=CreateFrame('CheckButton','MultiBarBottomRightButton1',UIParent); lower:Show(); lower.action=3
action.nativeProcVisible=true
GetActionInfo=function(slot) return "spell",slot==1 and 837 or slot==3 and 205 or 2136 end
R:PrepareHighlights(); check(R.highlights[action]==nil,"Never create action-button regions during combat")
combat=false; R:PrepareHighlights(); check(R.highlights[action]~=nil,"Prepare overlay outside combat")
local regions=#MOCK.frames; combat=true
local function forbidden() error("Protected action or macro mutation attempted") end
CastSpellByName=forbidden; CastSpellByID=forbidden; RunMacroText=forbidden
CreateMacro=forbidden; EditMacro=forbidden; PickupMacro=forbidden
SetBinding=forbidden; SetBindingClick=forbidden
action.SetAttribute=forbidden; other.SetAttribute=forbidden; action.CreateTexture=forbidden
check(R:Mode()=="disabled","Default mode is disabled")
A.characterDB.rotationMode="assistant"; R.dirty=true; R:Update()
check(R.current and R.current.id==837,"Live assistant chooses learned spell")
check(R.highlights[action]:IsShown() and not R.highlights[other]:IsShown(),"Only matching spell glows")
check(not R.highlights[lower]:IsShown(),'Older rank with the same spell name is not highlighted')
check(action.nativeProcVisible,"Native proc state left alone")
local glow=R.highlights[action]
local firstCoord=glow.ants.texCoord[1]
glow.scripts.OnUpdate(glow,.035)
check(glow.ants.texCoord[1]~=firstCoord,"Proc artwork advances while the recommendation remains active")
local animationTime=glow.elapsed
R:Update()
check(glow.elapsed==animationTime,"Repeated recommendations do not restart the spinning highlight")
glow.scripts.OnUpdate(glow,5)
local coords=glow.ants.texCoord
check(coords[1]>=0 and coords[2]<=1 and coords[3]>=0 and coords[4]<=1,"Animation stays inside the artwork after a slow frame")
action.action=2; R:Update(); check(not R.highlights[action]:IsShown(),"Action-bar paging clears stale highlight")
action.action=1; action:Hide(); R:Update(); check(not R.highlights[action]:IsShown(),"Hidden bars cannot retain visible highlight")
action:Show(); R:Update(); check(R.highlights[action]:IsShown(),"Visible matching action regains highlight")
for i=1,100 do R.events.scripts.OnUpdate(R.events,.2) end
check(#MOCK.frames==regions,"Repeated updates do not allocate frames")
units.player.power=50
R.events.scripts.OnEvent(R.events,'START_AUTOREPEAT_SPELL')
check(not R.current and R.snapshot.wanding and not R.highlights[action]:IsShown(),'Auto-repeat start stops prompts that would toggle wand off')
R.events.scripts.OnEvent(R.events,'STOP_AUTOREPEAT_SPELL')
check(R.current.id==5019 and not R.snapshot.wanding,'Stopping wand restores Shoot when mana is low')
C_Spell.IsCurrentSpell=function(id) return id==5019 end
R:Update(); check(not R.current and R.snapshot.wanding,'Existing wand activity is detected without a new start event')
C_Spell.IsCurrentSpell=nil; units.player.power=900; R:Update()
R.events.scripts.OnEvent(R.events,'PLAYER_LEAVING_WORLD')
local snapshot=R.Snapshot; R.Snapshot=function() error('Loading world must not poll units') end
R.events.scripts.OnUpdate(R.events,.2); R:Update()
check(not R.highlights[action]:IsShown() and not R.current,'World transition clears and suspends guidance')
R.Snapshot=snapshot; R.events.scripts.OnEvent(R.events,'PLAYER_ENTERING_WORLD')
check(R.current.id==837 and R.highlights[action]:IsShown(),'Entering world resumes saved Assistant mode')
R:SetMode("disabled"); check(not R.highlights[action]:IsShown() and R.current==nil,"Disabling clears only HCB highlights")
local snapshots=0; local original=R.Snapshot
R.Snapshot=function(self) snapshots=snapshots+1; return original(self) end
for i=1,10 do R.events.scripts.OnUpdate(R.events,.2) end
check(snapshots==0,"Disabled mode does not poll live combat state")
R:SetMode("onebutton"); check(R:Mode()=="disabled" and not R.modes.onebutton,"Only approved Assistant/Disabled modes are available")
combat=false
A:OpenSettings("Rotation Advisor")
local page=R.settingsPage
check(not page.buttons.onebutton and not page.limit,"Settings omit the deferred mode and its limitation panel")
check(page.buttons.assistant:IsEnabled(),"Mage can enable assistant")
for _,note in ipairs({page.help,page.rogue.note,page.mage.note}) do
    check(note:GetHeight()>=note:GetStringHeight(),'Settings descriptions have room to render all wrapped lines')
end
MOCK.Click(page.buttons.assistant)
check(A.characterDB.rotationMode=="assistant" and page.buttons.assistant.selected,"Mode stored per character and reflected in settings")
MOCK.Click(page.buttons.disabled); check(not page.buttons.assistant.selected,"Turning off mode clears selected appearance")
MOCK.class="HUNTER"; A:OpenSettings("Rotation Advisor")
check(not page.buttons.assistant:IsEnabled() and page.buttons.disabled:IsEnabled(),"Unsupported classes can only disable")
R:SetMode('assistant'); check(R:Mode()=='disabled','Unsupported classes cannot enable via the setter either')
MOCK.class="MAGE"; A.lastClass=nil; A.characterDB.rotationMode="assistant"; R.dirty=true
A:HandleSlashCommand("rotation")
check(A.state.view=="training" and A.state.filter=="Rotation Advisor" and R.view:IsVisible(),"Slash opens Companion advisor")
check(not A:CanGoBack(),"Advisor root has no redundant Back")
check(R.view.settings:IsVisible() and R.view.settingsHeader.action==R.view.settings,"Settings button uses shared header alignment")
check(R.view.next.name:GetText()=='Frostbolt | Rank 3','Learned rank appears beside the recommendation')
local view=R.view; local card=view.character
local _,cy,_,ch=card:GetRect(); local _,ty=view.target:GetRect(); local _,vy=view:GetRect()
check(cy==ty,"Character and target cards are side by side")
check(not view.limit and view:GetHeight()==cy-vy+ch+A.Skin.layout.sectionGap,"View ends after the compact context cards")
A.window:Hide(); R:Update(); check(R.highlights[action]:IsShown(),"Advice continues with HCB window closed")
A.window:Show(); A:Navigate("supplies"); check(not R.view:IsShown(),"Switching tabs hides advisor UI")
A:Navigate("training")
for _,b in ipairs(A.window.filters) do if b.filter=="Rotation Advisor" then MOCK.Click(b) end end
check(R.view:IsVisible() and A.state.filter=="Rotation Advisor","Companion sidebar opens the advisor")
-- Classic clients without the modern spell/aura namespace use the legacy adapters.
local modern,modernAuras=C_Spell,C_UnitAuras
local oldInfo,oldCooldown,oldUsable,oldRange,oldAura=GetSpellInfo,GetSpellCooldown,IsUsableSpell,IsSpellInRange,UnitAura
C_Spell=nil; C_UnitAuras=nil
GetSpellInfo=function(id) local v=spellData[id]; if v then return v.name,id==837 and 'Rank 3' or nil,v.iconID end end
GetSpellCooldown=function() return 0,0,1 end
IsUsableSpell=function() return true,false end
IsSpellInRange=function(name) return name=='Frostbolt' and 1 or 0 end
UnitAura=function(unit,i,filter)
 if unit=='target' and i==1 and filter=='HARMFUL' then return 'Polymorph',nil,1,nil,10,now+5,'player',nil,nil,118 end
end
R.dirty=true; R:Update()
check(R.snapshot.controlled and not R.current,'Legacy aura fields protect crowd-controlled targets')
UnitAura=function() end; R:Update()
check(R.current.id==837 and R.current.rank=='Rank 3' and R.current.range==true,'Legacy learned rank, cooldown, usability and numeric range adapters work')
C_Spell,C_UnitAuras=modern,modernAuras
GetSpellInfo,GetSpellCooldown,IsUsableSpell,IsSpellInRange,UnitAura=oldInfo,oldCooldown,oldUsable,oldRange,oldAura
R.dirty=true
A:HandleSlashCommand("rotation")
MOCK.RotationChecks=count
print("PASS: "..count.." rotation checks: priorities, live reads, rank changes, conservative AoE, mode state, UI and highlight lifecycle.")
''')

# Fresh Lua state emulates per-character SavedVariables reload, not just toggling a field.
saved = lua.eval("TestAddon.characterDB.rotationMode")
fresh, _ = boot()
fresh.globals().savedRotationMode = saved
fresh.execute('''
TestAddon.characterDB.rotationMode=savedRotationMode
assert(TestAddon.RotationAdvisor:Mode()=="assistant")
TestAddon.characterDB={}; assert(TestAddon.RotationAdvisor:Mode()=="disabled")
TestAddon.characterDB.rotationMode='onebutton'; assert(TestAddon.RotationAdvisor:Mode()=='disabled')
''')
print("PASS: Saved character mode restores; a different character remains disabled.")

if "--render" in sys.argv:
    out = Path(__file__).resolve().parents[1] / ".release"
    out.mkdir(exist_ok=True)
    composite(lua.globals().MOCK.frames, addon.window).save(out / "rotation-advisor.png")
    lua.execute('TestAddon:OpenSettings("Rotation Advisor")')
    composite(lua.globals().MOCK.frames, addon.window).save(out / "rotation-settings.png")
