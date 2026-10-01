"""Full-TOC debug export, incremental generation, copy selection and cache."""
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
assert(p:IsVisible() and p.dump.label:GetText()=="Dump Data" and p.copy.label:GetText()=="Copy")
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
assert(not p.edit:HasFocus())
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
assert(p.edit:GetText()==saved.text:sub(1,#p.partText) and #p.partText<=8192 and not p.sheen:IsShown())
local parts={}
repeat
    local part=p.edit:GetText(); assert(#part<=8192,"Native text selection is bounded")
    parts[#parts+1]=part
    if not p.next:IsEnabled() then break end
    MOCK.Click(p.next)
until false
assert(table.concat(parts)==saved.text,"All parts reconstruct the complete dump without loss")
assert(p.previous:IsEnabled() and not p.next:IsEnabled())
MOCK.Click(p.previous); assert(p.next:IsEnabled())
MOCK.Click(p.copy)
assert(p.edit:HasFocus() and p.status:GetText():find("Ctrl+C",1,true),"Copy selects text and explains the required keypress")
local job=D.Collect
D.Collect=function() error("capture failure fixture") end
D:Start(); D:Step(.016)
assert(A.characterDB.debugDump==saved and D.error,"Failure preserves last good cache")
D.Collect=job
D:Start(); finish()
assert(#A.characterDB.debugDump.text<#saved.text*1.1,"Repeated dumps do not recursively include the cache")
DEBUG_SAVED_TEXT=A.characterDB.debugDump.text
DEBUG_SAVED_AT=A.characterDB.debugDump.capturedAt
print("PASS: incremental comprehensive dump, animation, cycles, addon isolation, Copy selection and failure recovery.")
''')
offline = LuaRuntime(unpack_returned_tuples=True)
offline.execute(lua.globals().DEBUG_SAVED_TEXT)
fresh, fresh_addon = boot()
fresh.globals().RESTORED_TEXT = lua.globals().DEBUG_SAVED_TEXT
fresh.execute('''
TestAddon.characterDB.debugDump={schema=1,text=RESTORED_TEXT,capturedAt=123}
TestAddon:OpenSettings("Debug")
assert(TestAddon.DebugDump.page.edit:GetText()==RESTORED_TEXT:sub(1,#TestAddon.DebugDump.page.partText))
assert(#TestAddon.DebugDump.page.edit:GetText()<=8192)
assert(not TestAddon.DebugDump.job,"Opening Debug must not recapture")
local D=TestAddon.DebugDump
local unicode=string.char(226,152,131)
local fixture=string.rep("x",8191)..unicode..string.rep("y",9000)
TestAddon.characterDB.debugDump={schema=1,text=fixture,capturedAt=123}
D:Refresh()
assert(#D.page.edit:GetText()==8191,"Do not split a UTF-8 codepoint")
D:ShowPart(1); assert(D.page.edit:GetText():sub(1,3)==unicode)
local full=TestAddon.characterDB.debugDump.text
D.page.edit.scripts.OnTextChanged(D.page.edit,true)
assert(#D.page.edit:GetText()<=8192 and TestAddon.characterDB.debugDump.text==full,"Editing cannot restore a full-sized report into the textbox")
''')
print("PASS: dump parses offline and cached text restores in a fresh addon runtime.")
