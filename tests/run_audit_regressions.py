"""Cross-consumer regressions for the 2026-10-02 audit fixes."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot

lua,A=boot()
lua.execute(r'''
local A=TestAddon; local S,G,C=A.Supplies,A.GearAdvisor,A.Companion
local checks=0
local function check(value,reason) checks=checks+1; assert(value,reason) end
local function copy(t) local v={}; for k,x in pairs(t) do v[k]=x end; return v end
local items={}
for _,i in ipairs(A.Data.Items.items) do items[i.itemId]=i end
local c={mode="preview",characterClass="Mage",level=1,faction="Alliance",inventory={available=true,counts={}},
 professions={available=true,skills={bandage=0,dummy=0},known={}},priorities={},targets={},refillThresholds={},supplyDefaults={}}
-- A built-in item added as User remains one item, with one effective preference.
local user=copy(items[5997]); user.userItem=true; user.family="user-5997"; user.group="User"
c.userItems={user}; c.priorities[user.family]="Essentials"; c.targets[5997]=17; c.refillThresholds[5997]=6
for _,filter in ipairs({"User","All","Essentials"}) do
 local matches=0
 for _,r in ipairs(S.Build(c,{filter=filter})) do if r.itemId==5997 then
  matches=matches+1; check(r.priority=="Essentials" and r.target==17 and r.refillThreshold==6,"Same identity/controls in "..filter)
 end end
 check(matches==1,"Exactly one duplicate item in "..filter)
end
local missing=false
for _,r in ipairs(A.Readiness:Missing(c)) do if r.itemId==5997 then missing=true end end
check(missing,"User override reaches Missing Essentials")
local getContext=A.GetContext; A.GetContext=function() return c end
local oldUsers,oldPriorities=A.characterDB.userItems,A.characterDB.priorities
A.characterDB.userItems=c.userItems; A.characterDB.priorities=c.priorities
A:CyclePriority(items[5997])
check(S.Priority(c,user)=="Advanced" and S.Priority(c,items[5997])=="Advanced","Cycle either copy updates both")
c.userItems={}; check(S.Priority(c,items[5997])=="Optional","Removing User override restores built-in priority")
A.characterDB.userItems,A.characterDB.priorities=oldUsers,oldPriorities; A.GetContext=getContext
local oldChanged=A.Readiness.SuppliesChanged; local changed=0
A.Readiness.SuppliesChanged=function() changed=changed+1 end
check(A:EditUserItem('999999',false),"Add user item"); check(A:EditUserItem('999999',true),"Remove user item")
check(changed==2,"Both user mutations invalidate readiness"); A.Readiness.SuppliesChanged=oldChanged

-- Independent food arithmetic across all profiles and levels: score the actual
-- buff amounts, not the recommendation implementation under test.
for _,class in ipairs(A.Planner.classes) do for level=1,60 do
 c.characterClass=class; c.level=level; c.priorities={}; c.supplyProfile=nil
 local p=S.Profile(c); local expected,best=nil,-math.huge
 for _,i in ipairs(A.Data.Items.items) do
  if (i.family=="wellfed" or i.family=="manafood") and not i.alternative and i.ease<=2
    and A.Planner.AvailableAt(i)<=level and A.Planner.MatchesClass(i,class) then
   local meta=A.Data.ConsumableBuffs.items[i.itemId]
   local score=meta.power*(meta.foodType=="manafood" and (p.weights.mp5 or 0) or (p.weights.stamina or 0)+(p.weights.spirit or 0))
   if score>best then best=score; expected=i.family end
  end
 end
 for _,r in ipairs(S.Build(c,{filter="Food & Drink"})) do
  if r.family=="wellfed" or r.family=="manafood" then
   local meta=A.Data.ConsumableBuffs.items[r.itemId]
   if r.priority=="Essentials" then check(S.BuffScore(meta,p)==best,"Essential food has maximum build score: "..class.." "..level) end
  end
 end
end end
c.characterClass="Mage"; c.level=40
for _,case in ipairs({{{stamina=100,spirit=100,mp5=0},"wellfed"},{{stamina=0,spirit=0,mp5=100},"manafood"}}) do
 c.supplyProfile={weights=case[1]}
 check(S.Priority(c,items[17222])==(case[2]=="wellfed" and "Essentials" or "Optional"),"Custom weight food priority")
 local choices={items[17222],items[21217]}; A.Guide.SortSupplyItems(choices,c)
 check(choices[1].family==case[2],"Custom ordering agrees")
end
c.supplyProfile=nil
-- Manual lower scroll preference survives resolution and cannot select a future rank.
local scroll=A.Data.Scrolls.items[1]; c.level=60; c.characterClass=scroll.classes[1]=="All" and "Mage" or scroll.classes[1]
c.supplyDefaults[scroll.family]=scroll.itemId
local page=C.Detail(c,{kind="item",item=scroll})
check(page.defaultItem and page.isDefault,"Lower scroll has functioning default control")
for _,r in ipairs(S.Build(c,{filter="Scrolls"})) do if r.family==scroll.family then check(r.itemId==scroll.itemId,"Lower scroll selected on root") end end

-- Use restrictions are separate from crafting: purchased unlearned bandages work.
c.level=32; c.characterClass="Hunter"; c.maxHealth=700; c.supplyDefaults={}; c.professions.skills.bandage=0
local wanted=S.Selection(c,"bandage"); check(wanted==8544,"Future health recommendation preserved")
for _,r in ipairs(A.Readiness:Missing(c,true)) do check(r.itemId~=wanted,"Unusable planning bandage excluded from purchases/reminders") end
check(not S.Record(c,items[wanted]).usableNow,"Use skill gate")
c.professions.skills.bandage=150
check(S.Record(c,items[wanted]).usableNow,"Usable without learned crafting recipe")
c.professions.skills.bandage=80
local direct=C.Detail(c,{kind="item",item=items[wanted]})
local family=C.Build(c,{view="supplies",detail={kind="supplyFamily",family="bandage"}}).cards[1]
check(#direct.blocks==#family.blocks,"Bandage entry paths share one layout")
for i,b in ipairs(direct.blocks) do
 local other=family.blocks[i]
 check(b.itemId==other.itemId and b.rightColumn==other.rightColumn and b.supply==other.supply,"Identical bandage row policy")
end
check(#family.blocks[1].body<=48 and family.blocks[1].selectionReason:find("learned recipe",1,true),"Compact unavailable subtitle, detailed hover reason")

-- Every editable weight has a gain/loss explanation, including both-weapon totals.
local aliases={strength="ITEM_MOD_STRENGTH_SHORT",agility="ITEM_MOD_AGILITY_SHORT",stamina="ITEM_MOD_STAMINA_SHORT",
 intellect="ITEM_MOD_INTELLECT_SHORT",spirit="ITEM_MOD_SPIRIT_SHORT",armor="RESISTANCE0_NAME",health="ITEM_MOD_HEALTH_SHORT",mana="ITEM_MOD_MANA_SHORT",
 attackPower="ITEM_MOD_ATTACK_POWER_SHORT",rangedAttackPower="ITEM_MOD_RANGED_ATTACK_POWER_SHORT",feralAttackPower="ITEM_MOD_FERAL_ATTACK_POWER_SHORT",
 hit="ITEM_MOD_HIT_RATING_SHORT",crit="ITEM_MOD_CRIT_RATING_SHORT",spellPower="ITEM_MOD_SPELL_POWER_SHORT",healing="ITEM_MOD_SPELL_HEALING_DONE_SHORT",
 spellHit="ITEM_MOD_HIT_SPELL_RATING_SHORT",spellCrit="ITEM_MOD_CRIT_SPELL_RATING_SHORT",mp5="ITEM_MOD_POWER_REGEN0_SHORT",
 healthRegen="ITEM_MOD_HEALTH_REGENERATION_SHORT",spellPenetration="ITEM_MOD_SPELL_PENETRATION_SHORT",defense="ITEM_MOD_DEFENSE_SKILL_RATING_SHORT",
 dodge="ITEM_MOD_DODGE_RATING_SHORT",parry="ITEM_MOD_PARRY_RATING_SHORT",block="ITEM_MOD_BLOCK_RATING_SHORT",blockValue="ITEM_MOD_BLOCK_VALUE_SHORT"}
for _,school in ipairs({"frost","fire","shadow","nature","arcane","holy"}) do aliases[school]="ITEM_MOD_"..school:upper().."_DAMAGE_SHORT" end
for school,n in pairs({fire=2,nature=3,frost=4,shadow=5,arcane=6}) do aliases[school.."Resistance"]="RESISTANCE"..n.."_NAME" end
local profile=G.Profile("MAGE",60,nil,3)
for _,field in ipairs(G.WeightFields) do
 local key=field[1]; local a,b
 a={stats={},classID=4}; b={stats={},classID=4}
 if aliases[key] then a.stats[aliases[key]]=10; b.stats[aliases[key]]=20
 else
  check(key=="meleeDPS" or key=="rangedDPS" or key=="wandDPS","Independent stat alias covers "..key)
  a.classID=2; a.subclassID=key=="wandDPS" and 19 or 2; a.equip=key=="meleeDPS" and "INVTYPE_WEAPON" or "INVTYPE_RANGED"; a.dps=10
  b=copy(a); b.dps=20
 end
 check(G.GainSummary(b,profile,{a},true,false)~=nil,"Explained gain: "..key)
 check(G.LossSummary(a,profile,{b},true,false)~=nil,"Explained loss: "..key)
 check(G.LossSummary(a,profile,{a,b},true,false)~=nil,"Both-hands loss: "..key)
end
local axe={required=1,classID=2,subclassID=1,equip="INVTYPE_2HWEAPON",stats={},dps=10}
for _,level in ipairs({1,19,20,60}) do
 local p=G.Profile("SHAMAN",level,nil,2); p.cachedCapabilities=true
 check(not G.Allowed(axe,p),"Unknown cached talent never borrowed from live character")
 p.cachedTwoHandAxesMaces=false; check(not G.Allowed(axe,p),"Talent reset denies axe")
 p.cachedTwoHandAxesMaces=true; check(not not G.Allowed(axe,p)==(level>=20),"Cached enabling talent and level")
end

-- Catalog additions carry recipes, materials, levels and compound effect weights.
for _,id in ipairs({13452,13454,21546,9155,6373,3386,6048,6049,6050,6051,6052,13457,13456,13458,13461,13459}) do
 local i=items[id]; check(i and A.Data.Crafting.items[id] and A.Data.AuctionRecipes[id],"Complete catalog entry "..id)
 check(#A.Crafting.MaterialBlocks(i,c)>0,"Materials for "..id)
 check(S.Priority(c,i)=="Optional","Added consumables never automatically Essential")
end
check(S.Score(items[13452],c,{weights={agility=2,crit=3}})==56,"Mongoose includes agility AND crit")
local blocks,note,output=A.Crafting.MaterialBlocks(items[5530],c)
check(#blocks==1 and blocks[1].itemId==3818 and blocks[1].target==1 and output==1,"Blinding Powder reagent and batch")
for _,case in ipairs({{items[159],"Not Crafted"},{scroll,"Not Crafted"},{items[5513],"No Materials Required"},
 {{itemId=999999,name="Unknown",level=1},"Recipe Materials Unknown"}}) do
 local rows,status=A.Crafting.MaterialBlocks(case[1],c)
 check(#rows==0 and status==case[2],"Empty material states remain distinct")
end

local E=A.AuctionEssentials
local p=E:RefillPlan({{buyout=100000000,count=1}},1)
check(p.units==0 and p.priceLimited and p.excluded==1,"Sole overpriced listing blocked")
A.characterDB.auctionEssentialUnitGold=2
p=E:RefillPlan({{buyout=10000,count=1},{buyout=30000,count=1}},2)
check(p.units==1 and p.cost==10000 and p.priceLimited,"Partial supply inside absolute budget")
A.characterDB.auctionEssentialUnitGold=0
p=E:RefillPlan({{buyout=100000000,count=1}},1)
check(p.units==1,"Explicit unlimited budget is respected")
A.characterDB.auctionEssentialUnitGold=nil
E.results={sentinel=true}; E.complete=true
check(E:SetUnitPriceLimit(10) and E.results.sentinel and E.complete,"Unchanged budget preserves scan, including Escape")
check(not E:SetUnitPriceLimit(-1) and not E:SetUnitPriceLimit("bad"),"Reject invalid budgets")
check(E:SetUnitPriceLimit(3) and not next(E.results) and not E.complete,"Changed budget invalidates cached plans")
A.characterDB.auctionEssentialUnitGold=nil
for _,id in ipairs({6109,15192,15481,15757}) do check(A.MapAdvisor:LevelText(A.Data.MapNPCs[id])=="Level ??","Unknown boss level") end
check(A.MapAdvisor:LevelText({min=61,max=63})=="Level 61-63","Legitimate above-60 levels")
check(A.MapAdvisor:LevelText({})=="Level ??","Unavailable level")
print("PASS: "..checks.." focused cross-consumer audit regressions.")
''')
