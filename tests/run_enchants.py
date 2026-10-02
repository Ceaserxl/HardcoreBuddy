"""Enchant eligibility, preservation, shared reagents, preview and UI navigation."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua,addon=boot()
lua.execute('''
local A=TestAddon; local E=A.Enchants
local gear={}; local checks=0
local function check(ok,msg) checks=checks+1; assert(ok,msg) end
GetInventoryItemID=function(_,slot) return gear[slot] and 10000+slot end
GetInventoryItemLink=function(_,slot)
    local g=gear[slot]; if not g or g.unknown then return nil end
    return "item:"..(10000+slot)..":"..(g.enchant or 0)..":0:0"
end
C_Item.GetItemInfo=function(link)
    local slot=tonumber(link:match("item:(%d+)"))-10000; local g=gear[slot]
    if g.noInfo then return end
    return "Equipped",link,2,g.level or 50,1,"Armor",g.weight or "Cloth",1,g.loc,123,0,g.class or 4
end
local ctx={mode="live",level=60,characterClass="Mage",inventory={available=true,counts={}},enchantChoices={}}
local function slot(id) for _,g in ipairs(E.Scan(ctx)) do if g.slotId==id then return g end end end

check(E.Mode()=="level","Level appropriate is the default")
ctx.level=1; gear[9]={loc="INVTYPE_WRIST",level=1}
local budget=slot(9).recommendation
check(budget.skill<=50,"Low-level recommendation uses leveling tier")
A.characterDB.enchantMode="max"
check(slot(9).recommendation.skill>budget.skill,"Max mode recalculates recommendation")
A.characterDB.enchantMode="level"
check(slot(9).recommendation==budget,"Returning to level mode restores the recommendation")
A:OpenSettings("Gear Advisor")
local settings=A.Settings.pages["Gear Advisor"]
MOCK.Click(settings.enchantMode)
check(settings.enchantMenu:IsShown(),"Enchant dropdown opens")
MOCK.Click(settings.enchantOptions.max)
check(E.Mode()=="max" and not settings.enchantMenu:IsShown(),"Dropdown saves max mode and closes")
MOCK.Click(settings.enchantMode); MOCK.Click(settings.enchantOptions.level)
check(E.Mode()=="level","Dropdown saves level mode")
A.characterDB.enchantMode="max"
-- Skill requirements belong to the enchanter, never the wearer.
ctx.level=1; ctx.characterClass="Rogue"
gear[16]={loc="INVTYPE_WEAPON",level=1,class=2}
local fiery=false
for _,r in ipairs(slot(16).options) do if r.spellId==13898 then fiery=true end end
check(fiery,"Fiery Weapon available on level-one melee gear")
ctx.characterClass="Mage"; gear[9]={loc="INVTYPE_WRIST",level=1}
check(slot(9).recommendation.skill>200,"High-skill enchants available to low-level wearers")
local top=E.Options(ctx,slot(9)); local all=E.Options(ctx,slot(9),true)
check(#all>#top,"Lesser-rank toggle expands compatible enchants")
ctx.level=60; gear[7]={loc="INVTYPE_LEGS",level=50}
local allKits=E.Options(ctx,slot(7),true)
check(#allKits==6,"Lesser-rank toggle includes all applicable armor kits")
gear[7].level=14
for _,r in ipairs(E.Options(ctx,slot(7),true)) do check(r.gearLevel<=14,"Lesser ranks preserve item restrictions") end
ctx.level=1
for _,r in ipairs(E.Options(ctx,slot(7),true)) do check(r.level<=1,"Armor kits retain actual use level requirements") end

ctx.level=60
local gloves={status="checked",kind="Gloves",slotId=10,itemLevel=60,equipLoc="INVTYPE_HAND"}
local weapon={status="checked",kind="Weapon",slotId=16,itemLevel=60,equipLoc="INVTYPE_WEAPON"}
local professionFamilies={Mining="mining",Herbalism="herbalism",Skinning="skinning",Fishing="fishing"}
local tanks={Warrior=true,Paladin=true,Druid=true,Shaman=true}
local meleeClasses={Warrior=true,Rogue=true,Paladin=true,Shaman=true}
for _,mode in ipairs({"level","max"}) do
 A.characterDB.enchantMode=mode
 for _,class in ipairs({"Mage","Priest","Warlock","Hunter","Rogue","Warrior","Paladin","Shaman","Druid"}) do
  ctx.characterClass=class; ctx.professions={skills={}}
  for _,lesser in ipairs({false,true}) do
   for _,r in ipairs(E.Options(ctx,gloves,lesser)) do
    check(not professionFamilies[r.family],"Unknown professions hide every skill bonus")
    check(r.family~="Threat" or tanks[class],"Threat enchant limited to tank-capable classes")
   end
   for _,r in ipairs(E.Options(ctx,weapon,lesser)) do
    check(r.family~="Fiery Weapon" or meleeClasses[class],"Weapon proc class filtering")
    check(r.family~="Strength" or meleeClasses[class] or class=="Druid","No strength enchant for hunter/caster")
   end
  end
 end
end
ctx.characterClass="Mage"
for family,profession in pairs(professionFamilies) do
 ctx.professions={baseSkills={[profession]=1},skills={[profession]=6}}
 local seen=false
 for _,r in ipairs(E.Options(ctx,gloves,true)) do
  if r.family==family then seen=true end
  check(not professionFamilies[r.family] or professionFamilies[r.family]==profession,"Only matching learned profession bonuses")
 end
 check(seen,"Learned profession enables its enchant ranks")
 ctx.professions.baseSkills[profession]=0
 for _,r in ipairs(E.Options(ctx,gloves,true)) do check(r.family~=family,"Unlearning profession hides bonus despite modifiers") end
end
ctx.professions=nil
ctx.level=60; gear={}; A.characterDB.enchantMode="level"

check(#A.Data.Enchants.recipes==138,"Complete Era profession catalog including six scopes")
for _,r in ipairs(A.Data.Enchants.recipes) do
    check(r.spellId<30000 and r.enchantId>0 and r.gearLevel>=1 and #r.reagents>0,"Validated recipe")
    for _,p in ipairs(r.reagents) do check(A.Data.Enchants.materials[p[1]] and p[2]>0,"Material metadata") end
end
check(#E.MaterialItems(ctx)==0,"Empty equipment has no material shopping list")
gear[9]={loc="INVTYPE_WRIST"}
local g=slot(9); check(g.needed and (g.recommendation.family=="Intellect" or g.recommendation.family=="Stamina"),"Mage survival/intellect recommendation")
for _,weight in ipairs({"Cloth","Leather","Mail","Plate"}) do
    gear[9].weight=weight; check(slot(9).recommendation==g.recommendation,"Armor weight does not block enchant")
end
gear[9].enchant=g.recommendation.enchantId
check(slot(9).status=="ready" and #E.MaterialItems(ctx)==0,"Already applied excludes materials")
local lower
for _,r in ipairs(E.Options(ctx,g,true)) do
 if r.family==g.recommendation.family and E.Score(r,g.profile)<E.Score(g.recommendation,g.profile) then lower=r; break end
end
check(lower,"A lower rank of the recommended stat exists")
gear[9].enchant=lower.enchantId
check(slot(9).status=="upgrade" and slot(9).needed,"Older matching stat enchant upgrades")
gear[9].enchant=99999
check(slot(9).status=="enchanted" and not slot(9).needed,"Unknown permanent enhancement preserved")
ctx.enchantChoices[9]=g.recommendation.spellId
check(slot(9).status=="enchanted" and not slot(9).needed,"Legacy selection does not replace an applied enchant")
ctx.enchantChoices={}; gear[9].enchant=0; gear[9].unknown=true
check(slot(9).status=="unknown" and #E.MaterialItems(ctx)==0,"Unloaded link is unknown")
gear[9].unknown=nil; gear[9].noInfo=true
check(not slot(9).needed,"Uncached item stats cannot collect materials")
gear[9].noInfo=nil
gear[17]={loc="INVTYPE_HOLDABLE"}; check(#slot(17).options==0,"Held-in-offhand is not a shield or weapon")
gear[17]={loc="INVTYPE_SHIELD"}
for _,r in ipairs(slot(17).options) do check(r.slot=="Shield","Only shield enchants") end
gear[16]={loc="INVTYPE_2HWEAPON",class=2}
local twoHand=false
for _,r in ipairs(E.Options(ctx,slot(16),true)) do if r.slot=="2H Weapon" then twoHand=true end end
check(twoHand,"Two-hand enchants allowed on staff")
gear[16].loc="INVTYPE_WEAPON"
for _,r in ipairs(slot(16).options) do check(r.slot~="2H Weapon","No two-hand enchant on dagger") end
gear[16].loc="INVTYPE_RANGEDRIGHT"; check(#slot(16).options==0,"Wands excluded")
gear={ [9]={loc="INVTYPE_WRIST"}, [5]={loc="INVTYPE_ROBE"}, [7]={loc="INVTYPE_LEGS"}, [8]={loc="INVTYPE_FEET"} }
local legs=slot(7)
check(legs.recommendation.armorKit and legs.recommendation.itemId==15564,"Legs recommend the highest compatible armor kit")
local armorRanks=0
for _,r in ipairs(legs.options) do if r.armorKit and not r.defenseKit then
    armorRanks=armorRanks+1; check(r.itemId==15564,"Only highest applicable armor kit offered")
end end
check(armorRanks==1,"Lower armor kit ranks hidden from alternatives")
check(slot(5).recommendation.armorKit~=true,"Useful chest enchant competes with kits")
gear[10]={loc="INVTYPE_HAND"}
check(slot(10).recommendation.family=="Frost Power","Frost mage gloves prefer scored frost damage over armor kit")
gear[10]=nil
gear[7].level=14
check(slot(7).recommendation.itemId==2313,"Armor kit item-level restriction")
for _,r in ipairs(slot(7).options) do if r.armorKit then check(r.itemId==2313,"Highest compatible kit replaces unavailable higher ranks") end end
gear[7].level=50; gear[7].enchant=1843
check(slot(7).status=="ready" and not slot(7).needed,"Applied recommended armor kit recognized")
gear[7].enchant=15
check(slot(7).status=="upgrade" and slot(7).needed,"Outdated armor kit upgrade recognized")
gear[7].enchant=0
local kitDetail=E.Detail(ctx,{kind="enchantSlot",slotId=7})
local kitMaterials=false
for _,b in ipairs(kitDetail.blocks) do
    if b.itemId==8170 and not b.rightColumn then kitMaterials=true end
    if b.enchantTooltip and b.enchantTooltip.armorKit then check(b.body:find("Leatherworking",1,true),"Kit subtitle includes crafting requirement") end
end
check(kitMaterials,"Kit crafting materials in comparison details")
ctx.enchantChoices[7]=22727
local coreKit=A.ArmorKits.Recommendations(ctx)
check(#coreKit==1 and coreKit[1].itemId==15564,"Legacy Core kit selection cannot override recommendation")
ctx.enchantChoices[7]=nil
local expected={}
for _,s in ipairs(E.Scan(ctx)) do if s.needed then for _,p in ipairs(s.recommendation.reagents) do expected[p[1]]=(expected[p[1]] or 0)+p[2] end end end
for _,m in ipairs(E.MaterialItems(ctx)) do
    check(m.recommendedTarget==expected[m.itemId],"Shared material quantities aggregated across slots")
    ctx.inventory.counts[m.itemId]=math.max(0,m.recommendedTarget-1)
    check(A.Supplies.Record(ctx,m).missing==1,"Exact material bag counts")
end
local kits=A.ArmorKits.Recommendations(ctx)
check(#kits==1 and kits[1].recommendedTarget==1 and kits[1].targetSlots[1]=="Legs","Do not double-plan kits and enchants")
ctx.enchantChoices[5]="kit"
kits=A.ArmorKits.Recommendations(ctx)
check(kits[1].recommendedTarget==1,"Legacy kit choice does not override chest recommendation")
for _,r in ipairs(A.Supplies.Build(ctx,{filter="Buffs"})) do check(not r.item.armorKit,"Kits removed from Buffs") end
for _,class in ipairs({"Mage","Priest","Warlock","Rogue","Hunter","Warrior","Paladin","Shaman","Druid"}) do
    ctx.characterClass=class
    for level=1,60 do ctx.level=level
        for _,s in ipairs(E.Scan(ctx)) do for _,r in ipairs(s.options) do check(r.level<=level,"Class-level gate") end end
    end
end
local read=GetInventoryItemID; GetInventoryItemID=function() error("No live gear reads during preview") end
ctx.mode="preview"; check(#E.Scan(ctx)==9 and #E.MaterialItems(ctx)==0,"Preview isolation")
GetInventoryItemID=read
ctx.mode="live";ctx.level=60;ctx.characterClass="Mage"
check(not E.Compatible({slot="Bracer",gearLevel=35},{status="checked",kind="Bracer",itemLevel=34}),"Minimum item level gate")
MOCK.class="MAGE";MOCK.level=60;A.db.profile.mode="live";A:Navigate("supplies"); A.state.filter="Enchants"; A:Refresh()
check(A.document.cards[1].title=="Enchants","Enchants root")
for _,block in ipairs(A.document.cards[1].blocks) do check(block.action.slotId~=17,"Main enchants menu excludes off hand") end
check(#A.document.cards==1,"Kits integrated in comparison rows, no duplicate kit section")
local action=A.document.cards[1].blocks[3].action; A:Activate(action)
check(A:CanGoBack() and A.document.cards[1].title=="Wrists enchants","Slot detail and Back")
local recipe
for _,b in ipairs(A.document.cards[1].blocks) do if b.action and b.action.kind=="enchantRecipe" then recipe=b.action; break end end
check(recipe~=nil,"Recipe alternatives available")
A:Activate(recipe)
check(A.document.cards[1].title=="Wrists enchants","Recipe detail")
local detail=A.document.cards[1]
check(detail.blocks[1].title=="Selected Alternative" and detail.blocks[2].enchantTooltip.spellId==recipe.spellId,"Selected alternative replaces recommendation display")
check(detail.blocks[3].title=="Alternatives" and detail.blocks[3].rightColumn,"Alternatives in right column")
check(detail.blocks[2].body:find("Enchanting",1,true),"Requirements integrated into enchant subtitle")
check(detail.blocks[4].enchantStatus=="|cff62d79bRecommended|r" and not detail.blocks[4].title:find("(Recommended)",1,true),"Recommended enchant first in alternatives with green top-right label")
local selectedReagents={}
for _,pair in ipairs(E.byId[recipe.spellId].reagents) do selectedReagents[pair[1]]=pair[2] end
for _,b in ipairs(detail.blocks) do
    check(b.title~="Automatic recommendation" and b.title~="Use this enchant","Removed selection buttons")
    if b.itemId and not b.rightColumn then check(b.target==selectedReagents[b.itemId],"Materials match selected alternative") end
end
local material=false
for _,b in ipairs(A.document.cards[1].blocks) do if b.itemId then material=true end end
check(material,"Recipe material rows have item tooltips")
A.characterDB.enchantChoices={[8]="kit"}
local feet
for _,v in ipairs(E.Scan(A:GetContext())) do if v.slotId==8 then feet=v end end
check(feet.recommendation.family~="Speed" and feet.recommendation==feet.options[1],"Boots recommend highest stat score, with speed as a situational alternative")
local feetCard=E.Card(A:GetContext()).blocks[6]
check(feetCard.enchantTooltip==feet.recommendation and feetCard.enchantStatus=="Not Enchanted","Overview shows automatic recommendation when missing")
gear[8].enchant=1843
feetCard=E.Card(A:GetContext()).blocks[6]
check(feetCard.title=="Feet - Rugged Armor Kit" and feetCard.enchantStatus=="Alternative","Overview shows actually applied alternative")
local feetDetail=E.Detail(A:GetContext(),{slotId=8,kind="enchantSlot"})
check(feetDetail.blocks[1].title=="Selected Alternative" and feetDetail.blocks[2].enchantTooltip.itemId==15564,"Applied alternative detail matches overview")
local other
for _,option in ipairs(feet.options) do if option~=feet.recommendation and option.enchantId~=1843 then other=option; break end end
local ordered=E.Detail(A:GetContext(),{slotId=8,spellId=other.spellId})
check(ordered.blocks[4].enchantStatus=="|cff62d79bRecommended|r" and ordered.blocks[5].enchantTooltip.enchantId==1843 and ordered.blocks[5].enchantStatus=="Enchanted","Applied enchant follows recommendation in alternatives")
local recommendedDetail=E.Detail(A:GetContext(),{slotId=8,spellId=feet.recommendation.spellId})
check(recommendedDetail.blocks[1].title=="Recommended" and recommendedDetail.blocks[2].enchantStatus=="Missing" and recommendedDetail.blocks[2].enchantTone=="missing","Selected recommendation is red and missing when an alternative is applied")
check(recommendedDetail.blocks[4].enchantStatus=="Enchanted" and recommendedDetail.blocks[4].enchantTooltip.enchantId==1843,"Applied alternative remains enchanted beneath selected missing recommendation")
for _,slot in ipairs(E.Scan(A:GetContext())) do
    if gear[slot.slotId] and #slot.options>0 then
        local oldEnchant=gear[slot.slotId].enchant
        gear[slot.slotId].enchant=slot.options[1].enchantId
        for _,option in ipairs(slot.options) do
            local selectedCard=E.Detail(A:GetContext(),{slotId=slot.slotId,spellId=option.spellId}).blocks[2]
            local applied=option.enchantId==slot.options[1].enchantId
            check(selectedCard.enchantStatus==(applied and "Enchanted" or "Missing") and selectedCard.enchantTone==(applied and "ready" or "missing"),"Every slot selection reflects whether that exact enchant is applied")
        end
        gear[slot.slotId].enchant=oldEnchant
    end
end
gear[8].enchant=0
local mats=E.MaterialItems(ctx)
local saved=mats[1]
for _,s in ipairs(E.Scan(ctx)) do if s.recommendation and gear[s.slotId] then gear[s.slotId].enchant=s.recommendation.enchantId end end
check(saved and E.DetailMaterial(ctx,saved).recommendedTarget==0,"Open material detail drops obsolete default quantity")
A:Back();check(A.state.filter=="Enchants" and not A.state.detail and #A.history==0 and not A:CanGoBack(),"One Back clears alternative history and restores Enchants root")
local tile=A.document.cards[1].blocks[3]
check(tile.title:find("Wrists - ",1,true)==1 and tile.enchantStatus=="Enchanted" and tile.enchantTone=="ready","Applied recommendation green")
gear[9].enchant=99999; A:Refresh()
check(A.document.cards[1].blocks[3].enchantStatus=="Alternative" and A.document.cards[1].blocks[3].enchantTone=="ready","Other permanent enchant green")
gear[9].enchant=0; A:Refresh()
check(A.document.cards[1].blocks[3].enchantStatus=="Not Enchanted" and A.document.cards[1].blocks[3].enchantTone=="missing","Missing enchant stock label red")
local frame=A.window.cards[1].content.blocks[3]
check(frame.icon.texture=="Interface\\\\Icons\\\\"..frame.block.icon,"Bare enchant icon resolves to native texture")
frame.scripts.OnEnter(frame)
check(GameTooltip.hyperlink==nil and GameTooltip.lines[2]==frame.block.enchantTooltip.description,"Effect tooltip instead of crafting spell tooltip")
A:Activate(frame.block.action)
check(A.document.cards[1].itemLayout and A.document.cards[1].blocks[1].title=="Recommended","Two-column enchant detail")
local right=false
for _,b in ipairs(A.document.cards[1].blocks) do if b.itemId and not b.rightColumn then right=true; check(b.supply and b.target>0,"Tracked reagent rows") end end
check(right,"Materials occupy left column")
local before=#A.document.cards[1].blocks
MOCK.Click(A.window.enchantRanks)
check(A.state.showLesserEnchants and #A.document.cards[1].blocks>before,"Show Lesser Ranks expands the displayed alternatives")
for _,b in ipairs(A.document.cards[1].blocks) do if b.action then
    A:Activate(b.action); break
end end
check(A.state.showLesserEnchants,"Selecting an alternative preserves rank toggle")
MOCK.Click(A.window.enchantRanks)
check(not A.state.showLesserEnchants,"Hide Lesser Ranks restores compact list")
A.state={view="supplies",filter="Enchants",page=1}; A:Refresh(true)
check(A.window.enchantMode:IsShown(),"Enchants main page has recommendation dropdown")
MOCK.Click(A.window.enchantMode)
check(A.window.enchantModeMenu:IsShown(),"Recommendation dropdown opens")
MOCK.Click(A.window.enchantModeOptions.max)
check(E.Mode()=="max" and not A.window.enchantModeMenu:IsShown(),"Dropdown saves shared max mode and closes")
check(A.window.enchantMode.label:GetText():find("Show Max Enchants",1,true),"Selected mode displayed")
MOCK.Click(A.window.enchantModeOptions.level)
check(E.Mode()=="level","Dropdown restores level appropriate recommendations")
A.state.filter="Food & Drink"; A:Refresh(true)
check(not A.window.enchantMode:IsShown() and not A.window.enchantModeMenu:IsShown(),"Dropdown hidden on other supply pages")
print("Enchant checks passed: "..checks)
''')
composite(lua.globals().MOCK.frames,addon.window).save(ROOT/'.release/enchants-preview.png')
