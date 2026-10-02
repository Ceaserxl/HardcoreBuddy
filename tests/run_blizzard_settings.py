"""Blizzard addon category registration and the single settings launcher."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

for modern in (True, False):
    lua, addon = boot()
    lua.globals().TEST_MODERN = modern
    lua.execute('''
local A=TestAddon; local registrations=0; local panel
if TEST_MODERN then
 Settings={
  RegisterCanvasLayoutCategory=function(frame,name)
   assert(name=="HardcoreBuddy"); panel=frame
   return {ID=812,name=name}
  end,
  RegisterAddOnCategory=function(category)
   assert(category.ID==812); registrations=registrations+1
  end,
 }
else
 Settings=nil
 InterfaceOptions_AddCategory=function(frame)
  assert(frame.name=="HardcoreBuddy"); panel=frame; registrations=registrations+1
 end
end
A:Initialize(); A.Settings:RegisterBlizzardOptions()
assert(registrations==1 and panel==A.Settings.blizzardPanel,"Register exactly one addon entry")
local controls=0
for _,f in ipairs(MOCK.frames) do
 if f:GetParent()==panel and f.kind=="Button" then controls=controls+1 end
end
assert(controls==1 and panel.open.label:GetText()=="Open HardcoreBuddy Settings")
SettingsPanel=CreateFrame("Frame",nil,UIParent); SettingsPanel:Show()
InterfaceOptionsFrame=CreateFrame("Frame",nil,UIParent); InterfaceOptionsFrame:Show()
GameMenuFrame=CreateFrame("Frame",nil,UIParent); GameMenuFrame:Show()
HideUIPanel=function(frame) frame:Hide() end
panel:Show(); MOCK.Click(panel.open)
assert(not SettingsPanel:IsShown() and not InterfaceOptionsFrame:IsShown() and not GameMenuFrame:IsShown())
assert(A.window:IsShown() and A.state.view=="settings" and A.state.filter=="General")
print("PASS: "..(TEST_MODERN and "Modern" or "Legacy").." addon options registration, duplicate guard and Open Settings button.")
''')
