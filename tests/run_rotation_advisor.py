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
    for _,field in ipairs({"dead","mounted","controlled","targetPlayer"}) do
        local s=state(class); s[field]=true; decision(s,nil)
    end
    local s=state(class); s.validTarget=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].range=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].usable=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].ready=false; decision(s,nil)
    s=state(class,{base}); s.spells[base].range=nil; decision(s,base)
    s.spells[base].requiresRange=true; decision(s,nil)
    s=state(class,{base}); s.casting=true; decision(s,base)
    s.moving=true; decision(s,base)
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
s.spells.fireblast.ready=false; decision(s,"frostbolt")
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

local function pullState()
    local pull=state('ROGUE',{'strike','throw'})
    pull.combat=false; pull.targetCombat=false; pull.targetClose=false; pull.thrownEquipped=true
    pull.spells.strike.range=false
    return pull
end
local pull=pullState()
local key,reason,optional=R.Decide(pull)
check(key=='throw' and optional==true and reason=='','Throw is optional without an instruction prompt')
for _,field in ipairs({'targetCombat','stealthed','dead','mounted','casting','controlled','targetPlayer','targetClose'}) do
    pull=pullState(); pull[field]=true
    local result,_,isOptional=R.Decide(pull)
    check(result~='throw' and not isOptional,'No optional pull while '..field)
end
pull=pullState(); pull.moving=true; check(R.Decide(pull)=='throw','Movement keeps optional Throw advice visible')
for _,field in ipairs({'validTarget','thrownEquipped'}) do
    pull=pullState(); pull[field]=false
    check(R.Decide(pull)~='throw','Pull requires '..field)
end
for _,field in ipairs({'ready','usable','range'}) do
    for _,unknown in ipairs({false,true}) do
        pull=pullState()
        if unknown then pull.spells.throw[field]=nil else pull.spells.throw[field]=false end
        check(R.Decide(pull)~='throw','Throw requires confirmed '..field)
    end
end
pull=pullState(); pull.spells.throw=nil; check(R.Decide(pull)~='throw','Unlearned Throw cannot be suggested')
pull=pullState(); pull.targetCombat=nil; check(R.Decide(pull)~='throw','Unknown target combat state cannot suggest a pull')
pull=pullState(); pull.class='MAGE'; check(R.Decide(pull)~='throw','Mage does not get Rogue pull advice')
pull=pullState(); pull.combat=true; pull.targetCombat=true
key,reason,optional=R.Decide(pull)
check(key=='throw' and optional and reason=='','Engaged enemies can receive another optional Throw without text')
pull.spells.throw.range=false
key,reason=R.Decide(pull)
check(key==nil and reason=='','No range-gap movement or waiting prompt')
pull=pullState(); pull.combat=true; pull.spells.strike.range=true; pull.targetClose=true
key,_,optional=R.Decide(pull)
check(key=='strike' and not optional,'Combat builders remain primary recommendations')

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
local ready,range,usable={},{[5019]=1},{}
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
ready[61304]=nil
check(R:SpellState(R.spells.frostbolt,"target").ready,'Learned filler supplies GCD timing when dedicated GCD reports zero')
ready[837]={startTime=99,duration=8,isEnabled=true}; ready[61304]={startTime=100,duration=1.5,isEnabled=true}
check(not R:SpellState(R.spells.frostbolt,'target').ready,'Long intrinsic cooldown remains blocked during GCD')
ready[837]={startTime=92.5,duration=8,isEnabled=true}
check(R:SpellState(R.spells.frostbolt,'target').ready,'Long cooldown previews its final half-second even during GCD')
ready[837]={startTime=92.01,duration=8,isEnabled=true}
check(R:SpellState(R.spells.frostbolt,'target').ready,'Long cooldown stays eligible in its final milliseconds')
ready[61304]=nil
ready[837]={startTime=93.01,duration=8,isEnabled=true}
check(not R:SpellState(R.spells.frostbolt,'target').ready,'More than one second remaining stays blocked without an active GCD')
ready[837].startTime=93
check(R:SpellState(R.spells.frostbolt,'target').ready,'Exactly one second remaining starts the preview without an active GCD')
ready[837].isEnabled=false
check(not R:SpellState(R.spells.frostbolt,'target').ready,'Disabled spell cannot preview its final second')
ready[837]=nil; ready[2136]={startTime=99.5,duration=1,isEnabled=true}
check(not R:SpellState(R.spells.fireblast,'target').ready,'Non-GCD cooldown shorter than the class GCD receives no early preview')
local previewClass=R.class; R.class='ROGUE'
ready[2136]={startTime=99.7,duration=1.3,isEnabled=true}
check(R:SpellState(R.spells.fireblast,'target').ready,'Rogue uses its one-second GCD when evaluating a longer cooldown')
R.class=previewClass; ready[2136]=nil
ready[837]={startTime=99.9,duration=5,isEnabled=true}; ready[61304]=nil
check(not R:SpellState(R.spells.frostbolt,'target').ready,'Long school lockout cannot be used as fallback GCD')
ready[837]={startTime=100,duration=1,isEnabled=true}; ready[61304]={startTime=100,duration=1,isEnabled=true}
check(R:SpellState(R.spells.frostbolt,'target').ready,'One-second GCD is ignored')
ready[837]={startTime=0,duration=0,isEnabled=false}
check(not R:SpellState(R.spells.frostbolt,"target").ready,"Disabled cooldown is not ready")
ready[837].isEnabled=0
check(not R:SpellState(R.spells.frostbolt,'target').ready,'Numeric disabled flag is respected by modern cooldown adapter')
local modernRange,legacyRange=C_Spell.IsSpellInRange,IsSpellInRange
C_Spell.IsSpellInRange=function(id,unit) if id=='Frostbolt' then return unit=='target' end end
check(R:SpellState(R.spells.frostbolt,'target').range==true,'Unknown ID range retries the localized spell name')
C_Spell.IsSpellInRange=function() end
IsSpellInRange=function(name,unit) return name=='Frostbolt' and unit=='target' and 1 or nil end
check(R:SpellState(R.spells.frostbolt,'target').range==true,'Unavailable modern range falls back to legacy API')
C_Spell.IsSpellInRange=function() return false end
check(R:SpellState(R.spells.frostbolt,'target').range==false,'Explicit out-of-range cannot be overwritten by a fallback')
C_Spell.IsSpellInRange,IsSpellInRange=modernRange,legacyRange
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
-- Model the native template's animation lifecycle, not its rendered artwork.
-- Contract: Blizzard_ActionBar/Shared/ActionButtonSpellAlerts.{xml,lua}, Era 1.15.9.
local createFrame=CreateFrame
local function animation()
    local a={playing=false,plays=0}
    function a:Play() self.playing=true; self.plays=self.plays+1 end
    function a:Stop() self.playing=false end
    function a:IsPlaying() return self.playing end
    function a:Finish()
        if not self.playing then return end
        self.playing=false
        if self.onFinished then self.onFinished() end
    end
    return a
end
CreateFrame=function(kind,name,parent,template)
    local frame=createFrame(kind,name,parent,template)
    if template=='ActionButtonSpellAlertTemplate' then
        frame:Hide()
        frame.ProcStartFlipbook=frame:CreateTexture(nil,'ARTWORK')
        frame.ProcStartFlipbook:SetSize(150,150); frame.ProcStartFlipbook:SetPoint('CENTER')
        frame.ProcStartFlipbook:SetAlpha(1)
        frame.ProcLoopFlipbook=frame:CreateTexture(nil,'ARTWORK')
        frame.ProcLoopFlipbook:SetAllPoints(frame); frame.ProcLoopFlipbook:SetAlpha(0)
        for _,texture in ipairs({frame.ProcStartFlipbook,frame.ProcLoopFlipbook}) do
            function texture:SetDesaturated(value) self.desaturated=value end
        end
        frame.ProcStartAnim=animation(); frame.ProcLoop=animation()
        frame.ProcStartAnim.onFinished=function() frame.ProcLoop:Play() end
        frame:SetScript('OnHide',function(self)
            self.nativeHideCalls=(self.nativeHideCalls or 0)+1
            self.ProcLoop:Stop()
        end)
    end
    return frame
end
local action=CreateFrame("CheckButton","ActionButton1",UIParent); action:SetSize(36,36); action:Show(); action.action=1
local other=CreateFrame("CheckButton","MultiBarBottomLeftButton1",UIParent); other:Show(); other.action=2
local lower=CreateFrame('CheckButton','MultiBarBottomRightButton1',UIParent); lower:Show(); lower.action=3
local nativeProc=CreateFrame('Frame',nil,action,'ActionButtonSpellAlertTemplate')
action.SpellActivationAlert=nativeProc; nativeProc:Show(); nativeProc.ProcLoop:Play()
local originalResizeCalls=0
action:SetScript('OnSizeChanged',function() originalResizeCalls=originalResizeCalls+1 end)
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
local glow=R.highlights[action]
check(glow.template=='ActionButtonSpellAlertTemplate','Uses the actual Blizzard proc-alert template')
check(glow.style=='primary' and glow.ProcStartFlipbook.desaturated==false and glow.ProcLoopFlipbook.vertexColor[1]==1,'Primary advice preserves the original gold artwork')
check(action.SpellActivationAlert==nativeProc and nativeProc~=glow and nativeProc.ProcLoop:IsPlaying(),'Native proc ownership and animation stay untouched')
check(glow.ProcStartAnim:IsPlaying() and glow.ProcStartAnim.plays==1,'New recommendation starts the native burst once')
check(math.abs(glow:GetWidth()-50.4)<.001 and math.abs(glow:GetHeight()-50.4)<.001,'Native glow uses Blizzard button-relative sizing')
check(math.abs(glow.ProcStartFlipbook:GetWidth()-150*36/42)<.001 and math.abs(glow.ProcStartFlipbook:GetHeight()-150*36/42)<.001,'Small Classic buttons scale the burst as well as the loop')
check(glow.mouse==false and glow:GetFrameLevel()>action:GetFrameLevel(),'Native glow stays above the button without intercepting clicks')
check(not glow.scripts.OnUpdate,'Blizzard animation groups drive the effect without a custom sprite loop')
R:Update()
check(glow.ProcStartAnim.plays==1,'Repeated recommendation does not restart the native burst')
glow.ProcStartAnim:Finish()
check(glow.ProcLoop:IsPlaying(),'Native startup completion begins the sustained proc loop')
R:Update()
check(glow.ProcStartAnim.plays==1 and glow.ProcLoop.plays==1,'Polling leaves the running native loop uninterrupted')
R:Highlight(R.current,true)
for _,texture in ipairs({glow.ProcStartFlipbook,glow.ProcLoopFlipbook}) do
    check(texture.desaturated and texture.vertexColor[1]==.2 and texture.vertexColor[2]==.6 and texture.vertexColor[3]==1,'Both native animation phases are blue for optional advice')
end
check(glow.ProcStartAnim.plays==1 and glow.ProcLoop.plays==1,'Changing advice color preserves animation continuity')
R:Update()
check(glow.ProcStartFlipbook.desaturated==false and glow.ProcLoopFlipbook.vertexColor[1]==1,'Primary advice restores gold on reused frames')
action:SetSize(42,40)
check(originalResizeCalls==1 and math.abs(glow:GetWidth()-58.8)<.001 and glow:GetHeight()==56,'Bar resizing preserves existing scripts and native glow proportions')
check(glow.ProcStartFlipbook:GetWidth()==150 and math.abs(glow.ProcStartFlipbook:GetHeight()-150*40/42)<.001,'Resizing updates the burst in both dimensions')
local resizeCalls=originalResizeCalls
for _,size in ipairs({24,36,42,64}) do
    action:SetSize(size,size)
    check(math.abs(glow.ProcStartFlipbook:GetWidth()/150-glow.ProcLoopFlipbook:GetWidth()/58.8)<.001,'Burst and loop retain the same art scale at button size '..size)
end
check(originalResizeCalls==resizeCalls+4,'All size changes preserve the original action-button handler')
local burstWidth,loopWidth=glow.ProcStartFlipbook:GetWidth(),glow.ProcLoopFlipbook:GetWidth()
action.action=2; R:Update(); check(not R.highlights[action]:IsShown(),"Action-bar paging clears stale highlight")
check(not glow.ProcLoop:IsPlaying() and not glow.ProcStartAnim:IsPlaying() and glow.nativeHideCalls==1,'Clearing advice stops both native animations and preserves template OnHide')
glow.ProcStartFlipbook:SetAlpha(0); glow.ProcLoopFlipbook:SetAlpha(1)
action.action=1; action:Hide(); R:Update(); check(not R.highlights[action]:IsShown(),"Hidden bars cannot retain visible highlight")
action:Show(); R:Update(); check(R.highlights[action]:IsShown(),"Visible matching action regains highlight")
check(glow.ProcStartFlipbook.alpha==1 and glow.ProcLoopFlipbook.alpha==0,'Reusing the glow clears stale loop opacity before the new burst')
glow.ProcStartAnim:Finish()
check(glow.ProcStartFlipbook:GetWidth()==burstWidth and glow.ProcLoopFlipbook:GetWidth()==loopWidth,'The burst-to-loop handoff does not change geometry')
R:Highlight(nil); R:Update()
R:Highlight(nil); glow.ProcStartAnim:Finish()
check(not glow.ProcLoop:IsPlaying(),'Clearing during the startup burst cannot start a hidden loop later')
R:Update()
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
check(action.SpellActivationAlert==nativeProc and nativeProc:IsShown() and nativeProc.ProcLoop:IsPlaying(),'Disabling guidance leaves a real Blizzard spell proc running')
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
GetSpellInfo=function(id) local v=spellData[id]; if v then return v.name,id==837 and 'Rank 3' or nil,v.iconID,nil,0,id==837 and 36 or nil end end
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
check(R.spells.frostbolt.maxRange==36 and R.spells.frostbolt.minRange==0,'Legacy spell info preserves range metadata for prediction')
C_Spell,C_UnitAuras=modern,modernAuras
GetSpellInfo,GetSpellCooldown,IsUsableSpell,IsSpellInRange,UnitAura=oldInfo,oldCooldown,oldUsable,oldRange,oldAura
R.dirty=true
A:HandleSlashCommand("rotation")

-- Live Rogue equipment/range reads feed blue advice and return to gold in melee.
local oldInventory,oldItemAPI,oldTargetCombat=GetInventoryItemID,C_Item,UnitAffectingCombat
local oldX,oldAction=units.target.x,action.action
local equippedRanged,targetCombat=2947,false
GetInventoryItemID=function(_,slot) if slot==18 then return equippedRanged end end
C_Item={GetItemInfoInstant=function(id) return id,'Weapon','Thrown','INVTYPE_THROWN',1,2,id==2947 and 16 or 3 end}
UnitAffectingCombat=function() return targetCombat end
spellData[1752]={name='Sinister Strike',iconID=136189}; spellData[2764]={name='Throw',iconID=132324}
learned[1752]=true; learned[2764]=true
range[1752]=false; range[2764]=true; units.target.x=15
local oldActionInfo=GetActionInfo
GetActionInfo=function(slot) if slot==4 then return 'spell',2764 elseif slot==5 then return 'spell',1752 end; return oldActionInfo(slot) end
MOCK.class='ROGUE'; R.dirty=true; combat=false; action.action=4
R:Update()
check(R.current and R.current.id==2764 and R.optional and R.snapshot.thrownEquipped,'Rogue with equipped throwing weapons gets optional Throw')
check(glow:IsShown() and glow.style=='optional','Throw button displays the blue native animation')
check(R.view.next.title:GetText()=='Optional Action' and R.view.next.bar:GetText():find('Blue',1,true),'Advisor labels optional advice and explains blue')
local throwStarts=glow.ProcStartAnim.plays
R:Update(); check(glow.ProcStartAnim.plays==throwStarts,'Optional advice does not restart on each poll')
combat=true; targetCombat=true; units.target.x=12; R:Update()
check(R.current.id==2764 and glow.style=='optional' and glow.ProcStartAnim.plays==throwStarts,'After pulling, an approaching enemy keeps the same blue Throw glow')
check(R.view.next.reason:GetText()=='','Throw advice adds no instruction text')
range[2764]=false; units.target.x=6; R:Update()
check(not R.current and not glow:IsShown() and R.view.next.reason:GetText()=='','Gap between throwing and melee range clears glow without movement text')
range[1752]=true; units.target.x=3; action.action=5; R:Update()
check(R.current.id==1752 and glow:IsShown() and glow.style=='primary','Approaching enemy enters melee and switches advice to gold')
range[1752]=false; range[2764]=true; units.target.x=18; action.action=4; R:Update()
check(R.current.id==2764 and R.optional and glow:IsShown() and glow.style=='optional','Fleeing enemy in throwing range restores blue Throw advice')
ready[2764]={startTime=now,duration=3,isEnabled=true}; R:Update()
check(not R.current and not glow:IsShown(),'Throw on an actual cooldown is not highlighted against a fleeing enemy')
ready[2764].startTime=now-1.99; R:Update()
check(not R.current and not glow:IsShown(),'Throw stays dark just outside the final-second preview')
ready[2764].startTime=now-2; R:Update()
check(R.current.id==2764 and glow:IsShown() and glow.style=='optional','Throw gets its blue preview exactly one second before cooldown completion')
local previewStarts=glow.ProcStartAnim.plays
range[2764]=false; R:Update()
check(not R.current and not glow:IsShown(),'Early cooldown preview still requires actual spell range')
range[2764]=true; R:Update(); previewStarts=glow.ProcStartAnim.plays
ready[2764]=nil; R:Update()
check(R.current.id==2764 and glow:IsShown(),'Another Throw is suggested when its actual cooldown expires')
check(glow.ProcStartAnim.plays==previewStarts,'Cooldown completion does not restart the early highlight')
combat=false; targetCombat=false
equippedRanged=nil; R:Update(); check(not R.current and not glow:IsShown(),'Removing ranged weapon clears the optional highlight')
equippedRanged=33333; R:Update(); check(not R.current,'A gun cannot produce a Throw suggestion')
equippedRanged=2947; range[2764]=nil; R:Update(); check(not R.current,'Unknown Throw range cannot suggest a pull')
range[2764]=true; targetCombat=true; R:Update(); check(not R.current,'Already engaged targets are not suggested for pulling')
targetCombat=false; usable[2764]=false; R:Update(); check(not R.current,'Unusable Throw clears the pull suggestion')
usable[2764]=nil; learned[2764]=nil; R.dirty=true; R:Update(); check(not R.current,'Unlearned Throw is excluded from live advice')
learned[2764]=true; R.dirty=true; R:Update()
A.characterDB.rotationMode='disabled'; R:Update()
check(not R.optional and not R.current and not glow:IsShown(),'Disabled mode clears optional state and blue glow')
A.characterDB.rotationMode='assistant'; combat=true; units.target.x=3; range[1752]=true; action.action=5
R:Update()
check(R.current.id==1752 and not R.optional and glow.style=='primary' and not glow.ProcLoopFlipbook.desaturated,'Entering melee restores the primary gold rotation on the same button')
check(R.view.next.title:GetText()=='Next Spell' and R.view.next.bar:GetText():find('Gold',1,true),'Main advice restores the normal heading and gold explanation')
check(action.SpellActivationAlert==nativeProc and nativeProc.ProcLoopFlipbook.desaturated==nil,'Optional coloring never changes native spell proc artwork')
GetInventoryItemID,C_Item,UnitAffectingCombat=oldInventory,oldItemAPI,oldTargetCombat
GetActionInfo=oldActionInfo; units.target.x=oldX; action.action=oldAction
MOCK.class='MAGE'; combat=false; R.dirty=true; R:Update()
-- Keep an in-range next spell lit through a GCD, movement, and an active cast.
local oldSpeed=GetUnitSpeed
GetUnitSpeed=function() return 7 end
range[837]=true; range[2136]=false; range[5019]=false
ready[837]={startTime=now,duration=1.5,isEnabled=true}; ready[61304]=nil
casts.player={blocked=false}; R:Update()
check(R.current.id==837 and glow:IsShown(),'Moving and casting during a fallback GCD still highlights the next in-range spell')
local starts=glow.ProcStartAnim.plays
R.events.scripts.OnUpdate(R.events,.2)
check(glow:IsShown() and glow.ProcStartAnim.plays==starts,'GCD polling keeps the existing glow animation running')
ready[837]={startTime=now,duration=8,isEnabled=true}; ready[61304]={startTime=now,duration=1.5,isEnabled=true}
R:Update(); check(not R.current and not glow:IsShown(),'Intrinsic cooldown longer than GCD hides the spell')
ready={}; casts={}; range[837]=false; R:Update()
check(not R.current and not glow:IsShown(),'Actual spell range hides the out-of-range spell while moving')
range[837]=true; R.events.scripts.OnUpdate(R.events,.2)
check(R.current.id==837 and glow:IsShown(),'Entering actual spell range restores the glow while still moving')
local oldSpellRange,oldLegacyRange,oldActionRange,oldActionAPI=C_Spell.IsSpellInRange,IsSpellInRange,IsActionInRange,C_ActionBar
C_Spell.IsSpellInRange=function() end; IsSpellInRange=function() end
C_ActionBar={IsActionInRange=function(slot) return slot==1 end}
R:Update(); check(R.current.id==837 and glow:IsShown(),'Action-slot range fills a missing spell range result')
C_ActionBar=nil; IsActionInRange=function(slot,unit) return slot==1 and unit=='target' and 1 or 0 end
R:Update(); check(R.current.id==837 and glow:IsShown(),'Classic numeric action-slot range fallback highlights correctly')
IsActionInRange=function() end
R:Update(); check(not R.current and not glow:IsShown(),'Unknown targeted-spell range is not treated as in range')
C_Spell.IsSpellInRange,IsSpellInRange,IsActionInRange,C_ActionBar=oldSpellRange,oldLegacyRange,oldActionRange,oldActionAPI
GetUnitSpeed=oldSpeed; range[2136]=nil; range[5019]=1; R:Update()
do
    local savedNow,savedX,savedClass,savedSlot=now,units.target.x,MOCK.class,action.action
    local savedPosition,savedSpeed,savedSame,savedInteract=UnitPosition,GetUnitSpeed,UnitIsUnit,CheckInteractDistance
    local targetSpeed,toward,near=7,true,true
    GetUnitSpeed=function(u) return u=='target' and targetSpeed or 0 end
    UnitIsUnit=function(a,b) return a==b or toward and a=='targettarget' and b=='player' end
    CheckInteractDistance=function() return near end
    GetActionInfo=function(slot) if slot==5 then return 'spell',1752 end; return oldActionInfo(slot) end
    MOCK.class='ROGUE'; combat=true; action.action=5; range[1752]=false; range[2764]=false
    R.dirty=true; R.approach=nil; units.target.x=8; R:Update()
    check(not R.snapshot.approachingMelee and not glow:IsShown(),'First distance sample cannot predict an approach')
    now=now+.2; units.target.x=6.8; R:Update()
    check(R.snapshot.approachingMelee and R.current.id==1752 and glow:IsShown() and glow.style=='primary','Closing enemy gets the gold melee spell just before range')
    check(R.current.range==false and R.view.next.reason:GetText()=='','Prediction preserves actual range and adds no instruction text')
    R.snapshot.spells.strike.ready=false
    local predictedKey,predictedReason=R.Decide(R.snapshot)
    check(not predictedKey and predictedReason=='','Approach prediction cannot bypass a long cooldown or add a waiting prompt')
    R.snapshot.spells.strike.ready=true; R.snapshot.spells.strike.usable=false
    check(R.Decide(R.snapshot)==nil,'Approach prediction still requires enough resources and a usable spell')
    local before=glow.ProcStartAnim.plays
    R:Update(); check(glow:IsShown() and glow.ProcStartAnim.plays==before,'Repeated same-frame reads preserve the approach preview')
    now=now+.2; units.target.x=5.5; R:Update()
    now=now+.2; units.target.x=4.5; range[1752]=true; R:Update()
    check(R.current.id==1752 and glow.ProcStartAnim.plays==before,'Preview continues smoothly into confirmed melee range')
    range[1752]=false; now=now+.2; units.target.x=6; R:Update()
    now=now+.2; units.target.x=7; R:Update()
    check(not R.snapshot.approachingMelee and not glow:IsShown(),'Fleeing enemy never gets a predicted melee glow')
    now=now+.2; units.target.x=6; R:Update()
    now=now+.2; R:Update()
    check(not R.snapshot.approachingMelee and not glow:IsShown(),'Stopping outside melee cancels the early highlight')
    now=now+.2; units.player.x=1; R:Update()
    check(not R.snapshot.approachingMelee,'Player movement alone cannot label a stationary enemy as approaching')
    units.player.x=0; now=now+1; units.target.x=5.8; R:Update()
    check(not R.snapshot.approachingMelee,'Stale position samples cannot predict an approach')
    now=now+.2; units.target.guid='different-enemy'; units.target.x=5.2; R:Update()
    check(not R.snapshot.approachingMelee,'A different target cannot inherit closing velocity')
    units.target.guid='enemy1'
    -- Coordinate-free Classic fallback: observed outer-to-inner Throw boundary.
    UnitPosition=function() end; R.approach=nil
    local band={class='ROGUE',validTarget=true,targetClose=false,spells={throw={range=true}},time=now}
    check(not R:UpdateRangePreview(band),'First range band cannot predict an approach')
    band.time=band.time+.2; band.spells.throw.range=false
    check(R:UpdateRangePreview(band),'Moving target attacking player crossing the inner Throw boundary permits a short preview')
    band.time=band.time+.2; targetSpeed=0
    check(not R:UpdateRangePreview(band),'Stopped target cancels coordinate-free prediction')
    targetSpeed=7; R.approach=nil; band.spells.throw.range=true; band.time=band.time+.2; R:UpdateRangePreview(band)
    band.spells.throw.range=false; near=false; band.time=band.time+.2
    check(not R:UpdateRangePreview(band),'Exiting the far edge of Throw range cannot trigger melee prediction')
    near=true; R.approach=nil; band.spells.throw.range=true; band.time=band.time+.2; R:UpdateRangePreview(band)
    band.spells.throw.range=false; toward=false; band.time=band.time+.2
    check(not R:UpdateRangePreview(band),'Unknown approach direction cannot trigger band prediction')
    toward=true; R.approach=nil; band.spells.throw.range=true; band.time=band.time+.2; R:UpdateRangePreview(band)
    band.spells.throw.range=false; band.time=band.time+.2; R:UpdateRangePreview(band)
    band.time=band.time+.3; R:UpdateRangePreview(band); band.time=band.time+.3
    check(not R:UpdateRangePreview(band),'Range-band prediction expires rather than staying lit indefinitely')
    R.approach={guid='enemy1',time=now,preview=true}
    R.events.scripts.OnEvent(R.events,'PLAYER_TARGET_CHANGED')
    check(not R.snapshot.approachingMelee,'Target-change event discards previous prediction')
    UnitPosition,GetUnitSpeed,UnitIsUnit,CheckInteractDistance=savedPosition,savedSpeed,savedSame,savedInteract
    now,units.target.x,MOCK.class,action.action=savedNow,savedX,savedClass,savedSlot
    GetActionInfo=oldActionInfo; combat=false; R.approach=nil; R.dirty=true; R:Update()
end
do
    local savedNow,savedX=now,units.target.x
    local oldMax,oldMin=spellData[837].maxRange,spellData[837].minRange
    local oldBlastMax=spellData[2136].maxRange
    spellData[837].maxRange=36; spellData[837].minRange=0; spellData[2136].maxRange=20
    MOCK.class='MAGE'; R.dirty=true; R.approach=nil
    range[837]=false; range[2136]=false; range[5019]=false
    units.target.x=38; now=now+1; R:Update()
    check(R.spells.frostbolt.maxRange==36 and R.snapshot.spells.frostbolt.maxRange==36,'Highest learned spell range reaches the shared predictor')
    check(not glow:IsShown(),'Mage prediction also requires movement history')
    units.target.x=37; now=now+.2; R:Update()
    check(R.current.id==837 and R.current.approaching and glow:IsShown() and glow.style=='primary','Mage previews Frostbolt before crossing its own range boundary')
    check(not R.snapshot.spells.fireblast.approaching,'Shorter-range Fire Blast cannot inherit Frostbolt range prediction')
    check(R.current.range==false and R.view.next.reason:GetText()=='','Mage preview preserves actual range and adds no movement text')
    local animationStarts=glow.ProcStartAnim.plays
    R:Update(); check(R.current.approaching and glow.ProcStartAnim.plays==animationStarts,'Shared preview survives repeated reads for Mage')
    units.target.x=35.8; now=now+.2; range[837]=true; R:Update()
    check(R.current.id==837 and not R.current.approaching and glow.ProcStartAnim.plays==animationStarts,'Mage preview becomes in-range guidance without restarting glow')
    range[837]=false; units.target.x=37; now=now+.2; R:Update()
    check(not R.current and not glow:IsShown(),'Moving away does not generate a ranged spell preview')
    units.target.x=36.5; now=now+.2; R:Update()
    now=now+.2; R:Update()
    check(not R.current and not glow:IsShown(),'Stationary target outside Mage range cancels the prediction')
    units.target.x=36.2; now=now+.2; ready[837]={startTime=now,duration=8,isEnabled=true}; R:Update()
    check(R.snapshot.spells.frostbolt.approaching and not R.current,'Mage approach cannot bypass an unready cooldown')
    ready={}; units.target.x=36.1; now=now+.2; usable[837]=false; R:Update()
    check(not R.current,'Mage approach cannot bypass insufficient mana')
    usable[837]=nil
    local spell={range=false,maxRange=30,minRange=8,requiresRange=true,ready=true,usable=true}
    local state={class='MAGE',validTarget=true,targetClose=false,time=now,spells={test=spell}}
    -- No class/spell-key allowlist: the predictor uses the spell's metadata.
    units.target.x=32; state.time=state.time+1; R.approach=nil; R:UpdateRangePreview(state)
    units.target.x=31; state.time=state.time+.2; R:UpdateRangePreview(state)
    check(spell.approaching,'Shared prediction handles any targeted spell with range metadata')
    units.target.x=7; state.time=state.time+1; R.approach=nil; R:UpdateRangePreview(state)
    units.target.x=6; state.time=state.time+.2; R:UpdateRangePreview(state)
    check(not spell.approaching,'Approaching inside a minimum range never previews a ranged attack')
    spell.maxRange=nil; units.target.x=31; state.time=state.time+1; R.approach=nil; R:UpdateRangePreview(state)
    units.target.x=30.5; state.time=state.time+.2; R:UpdateRangePreview(state)
    check(not spell.approaching,'Missing ranged-spell metadata does not invent a range')
    spell.approaching=true; state.controlled=true; R:UpdateRangePreview(state)
    check(not spell.approaching and not R.approach,'Invalid target clears all spell previews and movement history')
    spellData[837].maxRange,spellData[837].minRange=oldMax,oldMin; spellData[2136].maxRange=oldBlastMax
    now,units.target.x=savedNow,savedX; range[837]=true; range[2136]=nil; range[5019]=1
    R.approach=nil; R.dirty=true; R:Update()
end
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
