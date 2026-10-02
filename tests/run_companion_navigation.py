"""Overview mirrors Companion tabs, with working return paths and common hover states."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
for _,class in ipairs({"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}) do
    MOCK.class=class; A.lastClass=nil; A:Navigate("training")
    local tabs=A.Companion.Tabs(A:GetContext())
    local rows=A.document.cards[1].blocks
    assert(rows[1].title=="Before you pull" and rows[2].title=="Shared cooldowns and Self Found")
    assert(A.document.cards[1].title=="Overview")
    for i,tab in ipairs(tabs) do
        assert(A.window.filters[i].filter==tab and A.window.filters[i]:IsVisible(),"Sidebar uses shared tab order")
        local caption=tab=="Gear" and "Gear Advisor" or tab=="Talents" and "Talent Advisor" or tab
        assert(A.window.filters[i].label:GetText()==caption,"Companion tabs use full advisor names")
        if i>1 then
            local row=rows[i+1]
            assert(row.title==caption and row.action,"Overview mirrors the sidebar, without a self-link")
            local overview=A.state
            A:Activate(row.action)
            if row.action.kind=="profession" then assert(A.state.detail.family==row.action.family)
            else assert(A.state.view==row.action.view and A.state.filter==row.action.filter) end
            assert(A:CanGoBack()); A:Back(); assert(A.state==overview)
        end
    end
end
local checked=0
local function hovers()
    for _,b in ipairs(MOCK.frames) do
        if b.skinButton and b:IsVisible() and b:IsEnabled() then
            assert(b.scripts.OnEnter and b.scripts.OnLeave,"Styled button is missing hover handlers")
            b.scripts.OnEnter(b)
            assert(b.skinButton.hovered and b.skinButton.highlight:GetAlpha()==0.24,"Styled button uses tab hover wash")
            b.scripts.OnLeave(b)
            assert(not b.skinButton.hovered and not b.skinButton.pressed,"Mouse leave restores button state")
            checked=checked+1
        end
    end
end
for _,page in ipairs({"General","Map","Death Alerts","Low Health","NPC Alerts","Talent Advisor","Gear Advisor"}) do
    A:OpenSettings(page); hovers()
end
A:OpenSettings("Map")
local f=A.MapAdvisor.controls
for _,b in ipairs(f.buttons) do
    b.scripts.OnEnter(b); assert(b.skinButton.highlight:GetAlpha()==0.24)
    b.scripts.OnMouseDown(b); assert(b.skinButton.pressed)
    b.scripts.OnMouseUp(b); b.scripts.OnLeave(b); assert(not b.skinButton.pressed and not b.skinButton.hovered)
end
print("PASS: Overview links for all 9 classes match sidebar order and return correctly; "..checked.." visible styled buttons have matching hover states.")
A:Navigate("training")
local row=A.window.cards[1].content.blocks[2]
assert(row.block.action and row:GetHighlightTexture():GetAlpha()==0.24,"Clickable content rows use the tab gold wash")
assert(row.iconHit:GetHighlightTexture():GetAlpha()==0.24,"Icon hit area shares the row hover")
A:OpenSettings("Map")
assert(A.MapAdvisor.controls.checks.notify:GetHighlightTexture():GetAlpha()==0.24,"Checkboxes share the tab hover")
A.Skin.Hover(row,false); assert(not row.highlight,"Recycled passive rows lose the interactive highlight")
''')
