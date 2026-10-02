"""All classes/profiles/levels: stat scores, roles, overrides and build selection."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot

lua, addon = boot()
lua.execute('''
local A=TestAddon; local E=A.Enchants
local build=A.TalentAdvisor.Build
local selected=1
A.TalentAdvisor.Build=function() return {profile=selected} end
local checks,profiles=0,0
local function check(value,why) checks=checks+1; assert(value,why) end
for class,list in pairs(A.Data.AdvisorGear) do
 for id in ipairs(list) do
  profiles=profiles+1; selected=id
  local title=class:sub(1,1)..class:sub(2):lower()
  local tank=class=="WARRIOR" and id>=3 or class=="PALADIN" and id==2 or class=="DRUID" and id==3
  local healer=class=="PRIEST" and id~=3 or class=="PALADIN" and id==1
      or class=="DRUID" and id==4 or class=="SHAMAN" and id==3
  for _,mode in ipairs({"level","max"}) do
   A.characterDB.enchantMode=mode
   for level=1,60 do
    local ctx={mode="preview",characterClass=title,level=level}
    local p=E.Profile(ctx)
    check(p.id==id and p.class==class,"Selected specialization controls weights")
    for _,g in ipairs(E.Scan(ctx)) do
     local best=g.recommendation and E.Score(g.recommendation,p) or 0
     for _,r in ipairs(E.Options(ctx,g,true)) do
      local score=E.Score(r,p)
      check(not score or best>=score,"Recommendation maximizes score across every eligible rank")
      check(r.family~="Threat" or tank,"Only tank profiles receive threat enchants")
      check(r.family~="Healing Power" or healer,"Healing-only enchants require healing specialization")
      check(not (r.family=="Fiery Weapon" and (class=="DRUID" or healer)),"Feral and healer profiles exclude weapon procs")
     end
    end
   end
  end
 end
end
-- Independent arithmetic fixtures catch stat parsing and old hardcoded weights.
local weights={strength=2,agility=3,stamina=4,intellect=5,spirit=6,mp5=7,mana=8,
    spellPower=9,healing=10,frost=11,armor=.2,defense=12}
local p={weights=weights}
check(E.Score({effect="All Stats +4"},p)==80,"All Stats sums all five weights")
check(E.Score({effect="Mana Regen 4 per 5 sec."},p)==28,"MP5 uses 4, not 5, and not mana weight")
check(E.Score({effect="Spell Damage +30"},p)==570,"Generic spell power also receives healing weight")
check(E.Score({effect="Frost Damage +20"},p)==220,"School bonus uses school weight only")
check(E.Score({armorKit=true,power=40},p)==8,"Armor kit uses armor weight")
check(E.Score({armorKit=true,defenseKit=true,power=3},p)==36,"Core kit uses defense weight")
check(E.Score({effect="Fiery Weapon"},p)==nil and E.Score({effect="Minor Speed Increase"},p)==nil,"Utility and procs have no fabricated score")
selected=3; A.characterDB.enchantMode="max"
local ctx={mode="preview",characterClass="Mage",level=60}
local function gloves()
 for _,g in ipairs(E.Scan(ctx)) do if g.slotId==10 then return g.recommendation end end
end
check(gloves().family=="Frost Power","Frost mage recommends frost damage")
A.characterDB.advisors.statWeights=A.characterDB.advisors.statWeights or {}
A.characterDB.advisors.statWeights["MAGE:3"]={armor=100}
check(gloves().armorKit,"Custom stat weights recalculate enchant recommendation")
A.characterDB.advisors.statWeights["MAGE:3"]=nil
selected=2
check(gloves().family=="Fire Power","Changing to Fire changes the recommendation")
A.TalentAdvisor.Build=build
-- Verify the real Talent Advisor selection path for every shipped build.
for class,paths in pairs(A.Data.AdvisorBuilds) do
 for id,path in ipairs(paths) do
  A.characterDB.advisors.builds[class]=id
  local p=E.Profile({characterClass=class,level=60})
  check(p.id==path.profile,"Real saved talent path selects its scoring profile")
 end
 A.characterDB.advisors.builds[class]=nil
end
print("PASS: "..checks.." enchant assertions; "..profiles.." profiles across all nine classes, levels 1-60, both modes, roles, custom weights and saved builds.")
''')
