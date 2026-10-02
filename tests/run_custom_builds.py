"""Custom bundle validation, persistence, scoring, editor and sharing regression checks."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT, composite
lua,A=boot()
lua.execute(r'''
local A=TestAddon; local B,U=A.CustomBuilds,A.CustomBuildsUI
local count=0
local function check(ok,msg) count=count+1; assert(ok,msg) end
for class,paths in pairs(A.Data.AdvisorBuilds) do
 for _,path in ipairs(paths) do
  local d=B:Draft(class,path)
  local code,err=B:Export(d); check(code,err)
  local decoded,reason=B:Decode(code); check(decoded,reason)
  check(#decoded.steps==#path.steps and decoded.class==class,'Complete path round trip')
  for _,f in ipairs(A.GearAdvisor.WeightFields) do check(decoded.weights[f[1]]==d.weights[f[1]],'Exact weight round trip') end
 end
end
local _,class=UnitClass('player')
local draft=B:Draft(class,A.TalentAdvisor:Build(class,UnitLevel('player')))
draft.name='My Custom Build'; draft.weights.stamina=123.456
local saved=B:Save(draft); check(saved and saved.id:find('custom:',1,true),'Save custom bundle')
draft.steps[1]='bad'; check(saved.steps[1]~='bad','Save copies draft')
local selectedBefore=A.TalentAdvisor:Build(class,UnitLevel('player'))
local code=B:Export(saved)
local imported=B:Save(B:Decode(code))
check(imported.id~=saved.id and A.TalentAdvisor:Build(class,UnitLevel('player')).id==selectedBefore.id,'Import creates copy without selection')
A.characterDB.autoApplyTalents=true
A.TalentAdvisor:Activate({command='build',id=saved.id,class=class})
check(not A.characterDB.autoApplyTalents,'Custom selection requires explicit automatic-spending opt-in')
local profile=A.GearAdvisor:CurrentProfile()
check(profile.buildID==saved.id and profile.weights.stamina==123.456,'Gear uses bundle weights')
check(A.Enchants.Profile(A:GetContext()).weights.stamina==123.456,'Enchants use bundle weights')
check(A.GearAdvisor:SetWeight(profile,'stamina',987),'Custom weights editable')
check(B:Get(saved.id).weights.stamina==987 and B:Get(imported.id).weights.stamina==123.456,'Weight changes isolated to bundle')
check(B:Decode(B:Export(B:Get(saved.id))).weights.stamina==987,'Export includes weight edits')
local liveRead=A.TalentAdvisor.ReadCurrent
A.TalentAdvisor.ReadCurrent=function() local ranks={}; for i=1,12 do local k=saved.steps[i]; ranks[k]=(ranks[k] or 0)+1 end; return {ranks=ranks,points=12,unspent=1} end
local captured=B:FromCurrent(class,saved.profile)
check(captured and #captured.steps==12 and B:Validate(captured),'Current talents captured in legal order')
A.TalentAdvisor.ReadCurrent=liveRead
local ranks={}
for i,key in ipairs(saved.steps) do
 local plan=A.TalentAdvisor.Plan(class,i+9,saved,ranks)
 check(plan.next and plan.next.key==key,'Custom next talent follows saved order')
 ranks[key]=(ranks[key] or 0)+1
end
local over=B.Copy(saved); while #over.steps<=51 do over.steps[#over.steps+1]=saved.steps[1] end
check(not B:Validate(over),'Reject more than 51 points')
local bad=B.Copy(saved); bad.weights.stamina=0/0; check(not B:Validate(bad),'Reject NaN')
bad=B.Copy(saved); bad.weights.stamina=math.huge; check(not B:Validate(bad),'Reject infinity')
bad=B.Copy(saved); bad.weights.stamina=-1; check(not B:Validate(bad),'Reject negative weights')
bad=B.Copy(saved); bad.profile=nil; check(not B:Validate(bad),'Reject missing specialization')
bad=B.Copy(saved); bad.name='|Hplayer:fake|h'; check(not B:Validate(bad),'Reject link injection')
bad=B.Copy(saved); bad.steps={}; check(not B:Validate(bad),'Reject empty path')
for _,text in ipairs({'','return os.execute("bad")',code..'x',string.rep('x',4097),'HCB2|x'}) do check(not B:Decode(text),'Reject invalid code') end
bad=B.Copy(saved); bad.steps={saved.steps[1]}; local node=A.Data.AdvisorTalents[class][saved.steps[1]]
for i=1,node.maxRank+1 do bad.steps[i]=saved.steps[1] end
check(not B:Validate(bad),'Reject rank overflow')
for key,n in pairs(A.Data.AdvisorTalents[class]) do if n.tier>1 then bad=B.Copy(saved); bad.steps={key}; check(not B:Validate(bad),'Reject illegal first point'); break end end
-- UI entry, editing and persistent selection.
U:Open(); check(A.state.customBuildPage and A:CanGoBack(),'Nested custom page')
U:Edit(saved,saved.id); U.editor.name:SetText('Edited Build'); U.editor.weights.stamina:SetText('321')
MOCK.Click(U.editor.save)
check(B:Get(saved.id).name=='Edited Build' and B:Get(saved.id).weights.stamina==321,'Editor saves bundle')
check(A.Settings.pages['Custom Builds']:IsShown(),'Editor stays inside settings')
U:Transfer(B:Get(saved.id)); MOCK.Click(U.transfer.review)
check(U.preview and U.transfer.import:IsEnabled(),'Review enables import')
U.transfer.code:SetText('broken'); U.transfer.code.scripts.OnTextChanged()
check(not U.preview and not U.transfer.import:IsEnabled(),'Changed text invalidates preview')
U:Back(); check(U.mode=='library','Back returns to library')
U:Back(); check(not A.state.customBuildPage,'Back returns to advisor settings')
-- Existing account library and character choice survive initialization.
local id=saved.id; A:Initialize()
check(B:Get(id).name=='Edited Build' and A.TalentAdvisor:Build(class,UnitLevel('player')).id==id,'Saved library and selection survive initialization')
-- In-game sharing is chunked and click-to-review, never automatic import/spending.
local packets={}; C_ChatInfo=C_ChatInfo or {}
C_ChatInfo.SendAddonMessage=function(prefix,text,channel,target) packets[#packets+1]={text=text,channel=channel,target=target}; check(#text<=254,'Packet bounds') end
check(B:Share(B:Get(id),'Friend-Realm'),'Share enqueues')
for i=1,30 do B.shareEvents.scripts.OnUpdate(nil,.2) end
check(#packets>0 and #B.outgoing==0,'Transfer sent in bounded chunks')
local librarySize=#B:List(class)
for _,p in ipairs(packets) do B:Receive(p.text,p.channel,'Friend-Realm') end
check(B.received[1] and #B:List(class)==librarySize,'Receipt does not import')
B:OpenLink('addon:HardcoreBuddy:build:1')
check(U.preview and U.preview.name=='Edited Build','Link opens preview')
check(not B:Share(B:Get(id),'bad target'),'Invalid recipient rejected')
check(B:Delete(id),'Delete custom bundle')
check(A.TalentAdvisor:Build(class,UnitLevel('player')).id~=id,'Deleting selected build restores automatic path')
check(B:Get(imported.id)~=nil,'Deleting preserves other builds')
A.characterDB.advisors.builds[class]=id; A.characterDB.autoApplyTalents=true
A.TalentAdvisor:Build(class,UnitLevel('player'))
check(not A.characterDB.autoApplyTalents and not A.characterDB.advisors.builds[class],'Deleted account build cannot trigger default-path auto spending on another character')
A.TalentAdvisor:Activate({command='build',class=class,id=imported.id})
A.characterDB.autoApplyTalents=true
local changed=B.Copy(imported); changed.name='Changed elsewhere'; B:Save(changed,imported.id)
A.characterDB.autoApplyTalents=true
A.TalentAdvisor:Build(class,UnitLevel('player'))
check(not A.characterDB.autoApplyTalents,'Changed account build revision pauses automatic spending')

check(not B:Delete(1),'Bundled paths cannot be deleted')
U:Open(); U:Edit(B:Get(imported.id),imported.id)
print('PASS: '..count..' custom build assertions across all classes, bundle isolation, validation, editor, selection and sharing')
''')
# Round-trip account and character SavedVariables through a fresh runtime.
def plain(value):
    if hasattr(value, 'items'):
        return {k: plain(v) for k, v in value.items()}
    return value
account, character = plain(lua.globals().HardcoreBuddyDB), plain(lua.globals().HardcoreBuddyCharacterDB)
fresh, fresh_addon = boot()
fresh.globals().HardcoreBuddyDB = fresh.table_from(account, recursive=True)
fresh.globals().HardcoreBuddyCharacterDB = fresh.table_from(character, recursive=True)
fresh.execute("TestAddon:Initialize(); local _,class=UnitClass('player'); local b=TestAddon.TalentAdvisor:Build(class,UnitLevel('player')); assert(b.custom and b.name=='Changed elsewhere' and b.weights.stamina==123.456)")
print('PASS: custom path, selected build and bundled weights restored in fresh Lua runtime')
if '--render' in sys.argv:
    (ROOT/'.release').mkdir(exist_ok=True)
    composite(lua.globals().MOCK.frames,A.window).save(ROOT/'.release/custom-builds-preview.png')
    lua.execute("TestAddon.CustomBuildsUI:Back()")
    composite(lua.globals().MOCK.frames,A.window).save(ROOT/'.release/custom-builds-library.png')
    lua.execute("local U=TestAddon.CustomBuildsUI; U:Transfer(U.list.rows[1].build); MOCK.Click(U.transfer.review)")
    composite(lua.globals().MOCK.frames,A.window).save(ROOT/'.release/custom-builds-transfer.png')
