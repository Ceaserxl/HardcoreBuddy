"""Full-TOC debug export, incremental generation, saved-file export and cache."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot
from lupa.lua51 import LuaRuntime

lua, addon = boot()
lua.execute('''
local A,D=TestAddon,TestAddon.DebugDump
A:OpenSettings("Debug")
local p=D.page
assert(p:IsVisible() and p.dump.label:GetText()=="Dump Data" and not p.copy and not p.previous and not p.next)
assert(not A.Settings.pages["Gear Advisor"].openSnapshot)
A.db.dumpFixture={nested="all account settings",number=123}
A.characterDB.dumpFixture={flag=false}
A.characterDB.dumpFixture.self=A.characterDB.dumpFixture
local forbidden=setmetatable({},{__index=function() error("Other addon accessed") end})
ZygorGuidesViewer=forbidden
local function finish()
    local frames=0
    while D.job do frames=frames+1; assert(frames<20000,"Dump never finished"); D:Step(.016) end
    assert(not D.error,D.error); return frames
end
MOCK.Click(p.dump)
assert(D.job and not p.dump:IsEnabled(),"Dump runs asynchronously")
D:Step(.016)
assert(D.job and p.sheen:IsShown() and D.displayProgress>0,"Animated progress during work")
A:OpenSettings("General")
assert(not p.edit and not p.scroll,"No dump textbox")
assert(finish()>1,"Large export is spread across frames")
local saved=A.characterDB.debugDump
assert(saved and #saved.text>100000 and loadstring(saved.text),"Full dump is valid serializable Lua text")
local data=assert(loadstring(saved.text))()
assert(data.account.dumpFixture.nested=="all account settings")
assert(data.character.dumpFixture.flag==false and data.character.dumpFixture.self["$ref"])
assert(data.capture.equipment and data.capture.bags and data.capture.quests and data.capture.spells and data.capture.auras)
assert(data.referenceData.MapZones and data.referenceData.PetGuide and data.runtime)
assert(not data.character.debugDump,"Previous dump is excluded")
A:OpenSettings("Debug")
assert(not p.edit and not p.copy and not p.scroll)
assert(p.savedPath:GetText():find("SavedVariables/HardcoreBuddy.lua",1,true))
assert(not A.characterDB.debugAutoReload)
local reloads,clicked,prompt=0,false,nil
StaticPopupDialogs={}
StaticPopup_Show=function(id) prompt=id end
ReloadUI=function() assert(clicked,"Reload must run inside a user click"); reloads=reloads+1 end
A.characterDB.debugAutoReload=true
D:Start(); finish()
assert(prompt=="HARDCOREBUDDY_DUMP_RELOAD" and reloads==0,"Completion prompts without a background reload")
for i=1,10 do D:Step(.016) end
assert(reloads==0,"Worker never attempts a protected reload")
clicked=true; StaticPopupDialogs[prompt].OnAccept(); clicked=false
assert(reloads==1,"User confirmation reloads immediately")
D:Step(.016); assert(reloads==1)
saved=A.characterDB.debugDump
A.characterDB.debugAutoReload=false
local job=D.Collect
D.Collect=function() error("capture failure fixture") end
D:Start(); D:Step(.016)
assert(A.characterDB.debugDump==saved and D.error,"Failure preserves last good cache")
D.Collect=job
D:Start(); finish()
assert(#A.characterDB.debugDump.text<#saved.text*1.1,"Repeated dumps do not recursively include the cache")
DEBUG_SAVED_TEXT=A.characterDB.debugDump.text
DEBUG_SAVED_AT=A.characterDB.debugDump.capturedAt
print("PASS: incremental comprehensive dump, animation, cycles, addon isolation, saved-file export and click-confirmed reload and failure recovery.")
''')
offline = LuaRuntime(unpack_returned_tuples=True)
offline.execute(lua.globals().DEBUG_SAVED_TEXT)
fresh, fresh_addon = boot()
fresh.globals().RESTORED_TEXT = lua.globals().DEBUG_SAVED_TEXT
fresh.execute('''
TestAddon.characterDB.debugDump={schema=1,text=RESTORED_TEXT,capturedAt=123}
TestAddon:OpenSettings("Debug")
assert(TestAddon.characterDB.debugDump.text==RESTORED_TEXT)
assert(not TestAddon.DebugDump.job and not TestAddon.DebugDump.page.edit)
assert(not TestAddon.DebugDump.Copy and not TestAddon.DebugDump.ShowPart)
''')
print("PASS: dump parses offline and cached text restores in a fresh addon runtime.")
