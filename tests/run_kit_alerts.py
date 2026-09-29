"""Level-up notifications against the actual supply catalog and UI mock."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot
lua, addon = boot()
lua.globals().TestAddon = addon
lua.execute('''
local A=TestAddon
A.db.profile.mode="preview"
A.db.profile.level=60
if A.window then A.window:Hide() end
local changed,unchanged=0,0
for level=2,60 do
    MOCK.level=level-1
    A.kitLevel=level-1
    local context=A:GetContext()
    context.characterClass="Hunter"; context.mode="live"
    context.level=level-1; context.characterLevel=level-1
    local old={}
    for _,row in ipairs(A.Supplies.Build(context)) do old[row.itemId]=true end
    context.level=level; context.characterLevel=level
    local expected=false
    for _,row in ipairs(A.Supplies.Build(context)) do
        if not old[row.itemId] then expected=true end
    end
    local count=#MOCK.messages
    MOCK.Fire("PLAYER_LEVEL_UP",level)
    assert(#MOCK.messages==count+(expected and 1 or 0),"wrong alert at level "..level)
    if expected then
        changed=changed+1
        assert(A.kitAlert:IsShown())
        assert(A.kitAlert.title:GetText():find(tostring(level),1,true))
        A.kitAlert.scripts.OnUpdate(A.kitAlert,8.25)
        assert(A.kitAlert:GetAlpha()==0.5)
        A.kitAlert.scripts.OnUpdate(A.kitAlert,0.25)
        assert(not A.kitAlert:IsShown())
    else unchanged=unchanged+1 end
    MOCK.Fire("PLAYER_LEVEL_UP",level)
    assert(#MOCK.messages==count+(expected and 1 or 0),"duplicate alert")
    MOCK.level=level; MOCK.Fire("PLAYER_XP_UPDATE","player")
    assert(#MOCK.messages==count+(expected and 1 or 0),"XP duplicate")
end
assert(changed>0 and unchanged>0)
A:ShowKitUpdate(60,{"Test supply"})
MOCK.Click(A.kitAlert)
assert(A.window:IsShown() and A.db.profile.mode=="live" and A.state.view=="supplies")
assert(not A.kitAlert:IsShown())
local count=#MOCK.messages
MOCK.Fire("PLAYER_ENTERING_WORLD")
assert(#MOCK.messages==count)
print("PASS: 59 level transitions, unchanged levels, duplicate/XP suppression, preview isolation, fade and click-to-open.")
''')
