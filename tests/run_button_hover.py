"""Audit every instantiated interactive button, including ones outside the shared skin."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

# Independent fixtures avoid leaking auction API mocks into map navigation.
for fixtures in (("gear_advisor.lua", "auction_upgrades.lua"), ("map_advisor.lua",)):
    lua, addon = boot()
    for fixture in fixtures:
        lua.execute((ROOT / "tests" / fixture).read_text(encoding="utf-8"))
    lua.execute('''
local A=TestAddon
A:ShowKitUpdate(33,{"Food"})
A.AuctionDiagnostics:Show()
for _,section in ipairs(A.Settings.sections) do A:OpenSettings(section) end
A:OpenSettings("Map")
A.state.mapIconKind="rare"; A:Refresh(true)
local choice=A.MapAdvisor.iconPicker.choices.rare
choice.scripts.OnEnter(choice); A:Refresh(true)
assert(choice.skinButton.hovered,"Refreshing the icon picker preserves hover")
choice.scripts.OnLeave(choice)
local checked=0
for _,b in ipairs(MOCK.frames) do
    if (b.kind=="Button" or b.kind=="CheckButton") and
        (b.scripts.OnClick or b==A.CreatureAlerts.targetButton) then
        -- Pooled informational rows and their icon hit areas intentionally have
        -- no hover when they do not lead anywhere. Blizzard fixture tabs are not ours.
        local block=b.block or (b.parent and b.parent.block)
        if b==A.AuctionUpgrades.tab then
            assert(b.template=="AuctionTabTemplate","Auction tab retains Blizzard native highlight template")
        end
        if (not block or block.action) and b~=A.AuctionUpgrades.tab then
            assert(b.skinButton or b.highlight,"Interactive button has no hover: "..tostring(b.name or b.label and b.label:GetText()))
            if b.skinButton and b:IsEnabled() then
                assert(b.scripts.OnEnter and b.scripts.OnLeave,"Styled button is missing mouse handlers")
                b.scripts.OnEnter(b)
                assert(b.skinButton.hovered and b.skinButton.highlight:GetAlpha()==0.24,"Button differs from tab hover")
                A.Skin.Button(b)
                assert(b.skinButton.hovered and b.skinButton.highlight:GetAlpha()==0.24,"Restyling loses hover")
                b.scripts.OnLeave(b)
                assert(not b.skinButton.hovered,"Button retains hover after leaving")
            elseif not b.skinButton then
                local t=b:GetHighlightTexture()
                assert(t:GetAlpha()==0.24,"Native highlight differs from tab opacity")
            end
            checked=checked+1
        end
    end
end
print("PASS: "..checked.." interactive controls audited, including hidden controls; hover survives refresh.")
''')
