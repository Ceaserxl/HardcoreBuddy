"""Repeated page changes, permanent scroll children and reentrant UI callbacks."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
A:HandleSlashCommand("talents")
local card=A.window.cards[2]
local scroll,content=card.tableScroll,card.tableContent
local standard=card.content
check(scroll and content and content:GetParent()==scroll,"Dedicated talent scroll child")
check(standard:GetParent()==card,"Standard card content keeps its parent")
local function stableParent(frame,expected)
    local original=frame.SetParent
    frame.SetParent=function(self,parent)
        check(parent==expected,"Page change must never reparent permanent row containers")
        return original(self,parent)
    end
end
stableParent(content,scroll); stableParent(standard,card)
local setChild=scroll.SetScrollChild
scroll.SetScrollChild=function(self,child)
    check(child==content,"Talent scroll child must not be replaced by a reused card")
    return setChild(self,child)
end
for cycle=1,3 do
    for _,class in ipairs({"DRUID","HUNTER","MAGE","PALADIN","PRIEST","ROGUE","SHAMAN","WARLOCK","WARRIOR"}) do
        MOCK.class=class; A.lastClass=nil
        A:HandleSlashCommand("talents")
        check(A.window.cards[2].tableContent==content and content:GetParent()==scroll,"Talent row pool remains stable")
        A.TalentAdvisor:Activate({command="hideLearned"})
        A.TalentAdvisor:Activate({command="hideLearned"})
        scroll.scripts.OnMouseWheel(scroll,-1)
        A:Layout(); A:Refresh()
        for _,category in ipairs({"All","Food & Drink","Enchants","Essentials","User"}) do
            A:Navigate("supplies"); A.state.filter=category; A:Refresh(true)
            check(not scroll:IsVisible() and not A.window.activeTableScroll,"Talent table hidden on supply pages")
            check(standard:GetParent()==card and content:GetParent()==scroll,"Page reuse preserves both content parents")
            if category=="Enchants" then
                A:Activate(A.document.cards[1].blocks[1].action)
                A:Back()
            end
        end
        A:Navigate("training")
        for _,tab in ipairs(A.Companion.Tabs(A:GetContext())) do
            A.state={view="training",filter=tab}; A:Refresh(true)
        end
        for _,section in ipairs(A.Settings.sections) do A:OpenSettings(section) end
        A:Navigate("deaths"); A:Navigate("instances")
        A.window:Hide(); A.window:Show()
    end
end
-- A visibility/focus callback requesting a refresh must not rebuild live frames
-- in the middle of the current layout pass.
A:HandleSlashCommand("talents")
local original=A.window.scroll.SetShown
local calls=0
A.window.scroll.SetShown=function(self,value)
    calls=calls+1
    if calls==1 then A:Refresh(true) end
    return original(self,value)
end
A:Refresh()
check(calls==1 and A.needsRefresh and A.pendingResetScroll,"Reentrant refresh is deferred")
A.window.scroll.SetShown=original
A.window.scripts.OnUpdate(A.window,0.1)
check(not A.refreshing and not A.layoutInProgress and not A.pendingResetScroll,"Deferred refresh completes")
local oldContext=A.GetContext
A.GetContext=function() error("lifecycle test error") end
local ok=pcall(A.Refresh,A)
check(not ok and not A.refreshing,"Errors propagate without wedging refresh guard")
A.GetContext=oldContext; A:Refresh()
check(not A.layoutInProgress,"Layout remains usable after errors")
print("PASS: "..checks.." lifecycle checks; 27 class/page cycles, stable scroll ownership and deferred UI callbacks.")
''')
