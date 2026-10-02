"""Elune macro creation, exact validation, repair and cursor pickup."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,A=boot()
lua.execute(r'''
local A=TestAddon; local C=A.Companion
local macros={}; local combat=false; local refreshed=0
A.Refresh=function() refreshed=refreshed+1 end
GetNumMacros=function() return 0,#macros end
GetMacroInfo=function(id) local m=macros[id-120]; if m then return m.name,134831,m.body end end
CreateMacro=function(name,icon,body,personal)
 assert(personal); macros[#macros+1]={name=name,body=body}; return 120+#macros
end
EditMacro=function(id,name,icon,body) macros[id-120].body=body; return id end
PickupMacro=function(id) assert(id==121); _G.picked=true end
InCombatLockdown=function() return combat end
assert(not C.EluneMacroState())
C.EluneMacroAction(false)
local id,correct=C.EluneMacroState(); assert(id==121 and correct and refreshed==1)
C.EluneMacroAction(false); assert(#macros==1 and refreshed==1)
C.EluneMacroAction(true); assert(picked)
for _,body in ipairs({C.eluneMacroBody..'\n',C.eluneMacroBody:gsub('\n','\r\n')..'\r\n'}) do
 macros[1].body=body
 id,correct=C.EluneMacroState(); assert(id==121 and correct,'Reload line endings are unchanged commands')
 C.EluneMacroAction(false); assert(refreshed==1,'Do not rewrite a valid reloaded macro')
end
for _,body in ipairs({'/use Hearthstone\n/use Light of Elune', C.eluneMacroBody..'\n/say extra', C.eluneMacroBody:gsub('Hearthstone','Other Item'), C.eluneMacroBody:gsub('\n','\n\n',1)}) do
 macros[1].body=body
 id,correct=C.EluneMacroState(); assert(id==121 and not correct,'Actual edits still require repair')
end
macros[1].body=C.eluneMacroBody..' '
id,correct=C.EluneMacroState(); assert(id==121 and not correct)
picked=false; C.EluneMacroAction(true); assert(not picked)
combat=true; C.EluneMacroAction(false); assert(macros[1].body~=C.eluneMacroBody)
combat=false; C.EluneMacroAction(false); assert(macros[1].body==C.eluneMacroBody)
local item
for _,i in ipairs(A.Data.Items.items) do if i.itemId==5816 then item=i end end
local ctx={characterClass='Mage',level=40,faction='Alliance',inventory={available=true,counts={}}}
local function controls()
 local card=C.Detail(ctx,{kind='item',item=item})
 local control,drag
 for _,b in ipairs(card.blocks) do if b.macroControl then control=b end; if b.macroDrag then drag=b end end
 return control,drag
end
local control,drag=controls(); assert(control.macroCorrect and drag.macroDrag)
macros[1].body='/use Hearthstone'
control,drag=controls(); assert(control.title=='FIX ELUNE MACRO!!' and control.macroBroken and not drag)
print('PASS: Elune macro creation, exact body validation, repair, combat guard, drag and page state')
''')
