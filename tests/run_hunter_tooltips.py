import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot
lua,addon=boot()
lua.execute('''
local H=TestAddon.HunterTooltips
local class,guid,controlled="HUNTER",nil,false
UnitClass=function() return "Hunter",class end
UnitGUID=function() return guid end
UnitIsPlayer=function() return false end
UnitPlayerControlled=function() return controlled end
UnitLevel=function(unit) return unit=="player" and 30 or 20 end
local t={lines={}}
function t:GetUnit() return "Creature","mouseover" end
function t:AddLine(text) self.lines[#self.lines+1]=text end
local count=0
for id,pet in pairs(H.pets) do
    guid="Creature-0-1-2-3-"..id.."-0000000001"
    t.lines={}; t.hardcoreBuddyPetGUID=nil
    H:Add(t)
    assert(t.lines[1]==(pet.tameable and "Tamable" or "Untamable"))
    if pet.tameable then
        assert(#t.lines>=2)
        for i,skill in ipairs(pet.abilities or {}) do
            local name,rank=skill:match("^(.-)%s+(%d+)$")
            assert(t.lines[i+1]:find("|TInterface\\\\Icons\\\\",1,true))
            local plain=t.lines[i+1]:gsub("|T.-|t ","")
            assert(plain==(name and name.." (Rank "..rank..")" or skill))
        end
    end
    local n=#t.lines; H:Add(t); assert(#t.lines==n)
    count=count+1
end
class="MAGE"; t.lines={}; t.hardcoreBuddyPetGUID=nil; H:Add(t); assert(#t.lines==0)
class="HUNTER"; guid="Creature-0-1-2-3-999999-0000000001"; H:Add(t); assert(#t.lines==0)
guid="Player-1-12345"; H:Add(t); assert(#t.lines==0)
guid="Creature-0-1-2-3-"..next(H.pets).."-0000000001"; controlled=true
H:Add(t); assert(t.lines[1]=="Untamable")
print("PASS: "..count.." catalog tooltips, exact skill ranks, duplicate suppression, class gating, unknown IDs, players and controlled units.")
assert(H.pets[5807].tameable)
for _,id in ipairs({4950,14283,11671,11672,11673,4011,3058,6498,10220}) do assert(H.pets[id] and not H.pets[id].tameable) end
assert(not H.pets[205382] and not H.pets[1979],"Seasonal and test NPCs excluded")
assert(H.pets[10657] and H.pets[10042] and H.pets[15974] and H.pets[6508],"Previously unindexed beasts resolved")
''')
