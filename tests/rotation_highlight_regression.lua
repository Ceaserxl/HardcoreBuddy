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
    check(texture.desaturated and texture.vertexColor[1]==1 and texture.vertexColor[2]==.15 and texture.vertexColor[3]==.15,'Both native animation phases are red for optional advice')
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
units.player.power=0; usable[837]=false; usable[2136]=false
R.events.scripts.OnEvent(R.events,'START_AUTOREPEAT_SPELL')
check(not R.current and R.snapshot.wanding and not R.highlights[action]:IsShown(),'Auto-repeat start stops prompts that would toggle wand off')
R.events.scripts.OnEvent(R.events,'STOP_AUTOREPEAT_SPELL')
check(R.current.id==5019 and not R.snapshot.wanding,'Stopping wand restores Shoot when mana is low')
C_Spell.IsCurrentSpell=function(id) return id==5019 end
R:Update(); check(not R.current and R.snapshot.wanding,'Existing wand activity is detected without a new start event')
C_Spell.IsCurrentSpell=nil; units.player.power=900; usable={}; R:Update()
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
for _,note in ipairs({page.help,page.damage.note,page.survival.note}) do
    check(note:GetHeight()>=note:GetStringHeight(),'Settings descriptions have room to render all wrapped lines')
end
MOCK.Click(page.buttons.assistant)
check(A.characterDB.rotationMode=="assistant" and page.buttons.assistant.selected,"Mode stored per character and reflected in settings")
MOCK.Click(page.buttons.disabled); check(not page.buttons.assistant.selected,"Turning off mode clears selected appearance")
MOCK.class="HUNTER"; A:OpenSettings("Rotation Advisor")
check(page.buttons.assistant:IsEnabled() and page.buttons.disabled:IsEnabled(),"Other classes can enable shared consumable preparation")
R:SetMode('assistant'); check(R:Mode()=='assistant','Non-Mage characters can enable consumable highlights')
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

do
    local oldInfo,oldMacro,oldRange=GetActionInfo,GetMacroSpell,C_Spell.IsSpellInRange
    local oldActionRange=IsActionInRange
    local selected,kind,subtype=837,'macro','spell'
    GetActionInfo=function(slot)
        if slot==1 then return kind,selected,subtype end
        return oldInfo(slot)
    end
    R:Highlight({id=837})
    check(glow:IsShown(),'Conditional macro resolved to Frostbolt receives the normal spell glow')
    selected=133
    R.events.scripts.OnEvent(R.events,'MODIFIER_STATE_CHANGED','LALT',1)
    check(not glow:IsShown(),'Holding Alt removes Frostbolt guidance from the Fireball branch')
    R:Highlight({id=133})
    check(glow:IsShown(),'Fireball branch highlights when Fireball is recommended')
    selected=837
    R.events.scripts.OnEvent(R.events,'MODIFIER_STATE_CHANGED','LALT',0)
    check(glow:IsShown(),'Releasing Alt restores the Frostbolt macro highlight immediately')
    local starts=glow.ProcStartAnim.plays
    R:Update(); R:Update()
    check(glow.ProcStartAnim.plays==starts,'Repeated macro resolution does not restart its animation')
    selected=205; R:Highlight({id=837})
    check(not glow:IsShown(),'Explicit lower-rank macro does not match the recommended rank')
    selected=1; subtype=nil
    GetMacroSpell=function(id) check(id==1,'Legacy lookup receives the macro index'); return 837 end
    R:Highlight({id=837}); check(glow:IsShown(),'Macro-index clients resolve their selected spell through GetMacroSpell')
    GetMacroSpell=function() return 'Frostbolt','Rank 3',837 end
    R:Highlight({id=837}); check(glow:IsShown(),'Older name-rank-ID macro results preserve exact matching')
    GetMacroSpell=function() return nil end
    R:Highlight({id=837}); check(not glow:IsShown(),'Unresolved or empty macro clears stale guidance')
    subtype='item'; selected=837; GetMacroSpell=forbidden
    R:Highlight({id=837}); check(not glow:IsShown(),'Item macro is not mistaken for a spell with the same ID')
    kind='item'; R:Highlight({id=837}); check(not glow:IsShown(),'Ordinary items are not highlighted as spells')
    kind='macro'; subtype='spell'
    C_Spell.IsSpellInRange=function() end
    IsActionInRange=function(slot) return slot==1 and 1 or nil end
    check(R:SpellState(R.spells.frostbolt,'target').range==true,'Macro slots supply range fallback for their selected spell')
    IsActionInRange=function() return 0 end
    check(R:SpellState(R.spells.frostbolt,'target').range==false,'Macro range fallback preserves out-of-range results')
    action:Hide(); R:Highlight({id=837}); check(not glow:IsShown(),'Hidden macro button does not glow')
    action:Show()
    GetActionInfo,GetMacroSpell,C_Spell.IsSpellInRange=oldInfo,oldMacro,oldRange
    IsActionInRange=oldActionRange; R:Update()
end
