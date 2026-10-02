"""Stable navigation reserve and content/scrollbar origins across pages."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local f=A.window
local expected
local function aligned(scroll)
 local _,top=scroll:GetRect(); local _,backTop=f.back:GetRect()
 expected=expected or top
 assert(top==expected and top==backTop+34,"Scroll origin must not depend on Back or search controls")
 return top
end
for _,view in ipairs({"supplies","training","advisors","instances","petguide"}) do
 A:Navigate(view)
 local top=aligned(f.scroll)
 local _,titleTop=f.cards[1].title:GetRect()
 assert(titleTop==top,"First heading starts at the scroll origin")
end
A:Navigate("supplies"); MOCK.Click(f.cards[1].content.blocks[1])
local top=aligned(f.scroll)
local _,itemTop=f.cards[1].content.blocks[1]:GetRect()
assert(itemTop==top,"Item detail border starts at scroll origin")
MOCK.Click(f.back); aligned(f.scroll)
A:Navigate("training"); A.state.filter="Spells"; A:Refresh(true); aligned(f.scroll)
local _,searchTop=f.search:GetRect(); local _,backTop=f.back:GetRect()
assert(searchTop==backTop,"Search shares reserved toolbar row")
for _,section in ipairs(A.Settings.sections) do
 A:OpenSettings(section); aligned(A.Settings.scroll)
end
A:OpenSettings("Gear Advisor"); A.Settings:OpenGearPage("Stat Weights"); aligned(A.Settings.scroll)
MOCK.Click(f.back); aligned(A.Settings.scroll)
-- Supply the native scrollbar children omitted by the offline UI mock.
for _,scroll in ipairs({A.Deaths.window.listScroll,A.Deaths.details.scroll}) do
 scroll.ScrollBar=CreateFrame("Slider",nil,scroll); scroll.ScrollBar:SetWidth(16)
end
A:OpenDeaths(); local hostTop=aligned(A.Deaths.host)
for _,scroll in ipairs({A.Deaths.window.listScroll,A.Deaths.details.scroll}) do
 local _,barTop=scroll.ScrollBar:GetRect()
 assert(barTop-16==hostTop,"Journal scrollbar's up-arrow aligns with other page tops")
end
print("PASS: Common scroll origins across roots, details, search pages, Settings and journal; headings/items start at the content top.")
''')
