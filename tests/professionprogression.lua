local A=TestAddon
local P,D=A.Professions,A.Data.ProfessionProgression
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local function snapshot(family,skill,cap,learnThrough)
    local key=family=="antivenom" and "bandage" or family
    local s={skills={[key]=skill},baseSkills={[key]=skill},maxSkills={[key]=cap},known={}}
    for index,r in ipairs(P.recipes[family] or {}) do s.known[r.spellId]=index<=(learnThrough or 0) end
    return s
end
local function text(blocks)
    local out={}
    for _,block in ipairs(blocks) do out[#out+1]=(block.title or "").." "..(block.body or "").." "..(block.meta or "") end
    return table.concat(out,"\n")
end
local function contains(value,needle) return value:find(needle,1,true)~=nil end
local function context(family,skill,cap,learnThrough,faction,level)
    return {professions=snapshot(family,skill,cap,learnThrough),faction=faction,characterLevel=level or 40,level=60}
end
local function training(blocks)
    for _,b in ipairs(blocks) do if b.kind=="professionTraining" then return b end end
end

for family,recipes in pairs(P.recipes) do
    for _,recipe in ipairs(recipes) do check(D.recipes[recipe.spellId]~=nil,"Every automatic recipe has an acquisition record") end
end
local c=context("bandage",150,225,5,"Alliance")
local blocks=P.Guidance(c,"bandage")
check(blocks[1].recipeItemId==16112 and blocks[1].ahEligible,"Heavy Silk uses a tradable manual, not a trainer")
check(blocks[1].itemId==16112,"The manual row uses the recipe item for its native icon and tooltip")
check(contains(blocks[1].meta,"Self Found cannot use AH"),"AH eligibility includes the Self Found restriction")
check(not blocks[1].skillMet and blocks[1].craftSkill==180,"Having First Aid150 does not make the180 manual usable")
check(P.NextRecipe(c,"bandage").name=="Heavy Silk Bandage" and P.NextRecipe(c,"bandage").craftSkill==180,"Compact hint returns the exact stronger unlearned recipe")
check(contains(text(blocks),"Deneb Walker") and not contains(text(blocks),"Balai"),"Alliance receives only its own book vendor")
c.faction="Horde"
check(contains(text(P.Guidance(c,"bandage")),"Balai Lok'Wein") and not contains(text(P.Guidance(c,"bandage")),"Deneb"),"Horde receives only its own book vendor")
c.faction=nil
local unknown=text(P.Guidance(c,"bandage"))
check(contains(unknown,"Faction unavailable") and not contains(unknown,"Deneb") and not contains(unknown,"Balai"),"Unknown faction never names a faction vendor")
check(contains(unknown,"Tradable") and contains(unknown,"not checked"),"Unknown faction retains neutral AH eligibility without claiming listings")
c=context("bandage",225,225,7,"Alliance",34)
blocks=P.Guidance(c,"bandage")
check(blocks[1].spellId==10841 and not blocks[1].ahEligible,"Heavy Mageweave is doctor training, not an AH manual")
local step=training(blocks)
check(step and step.skillCap==300 and not step.requirementsMet,"Planning level60 does not bypass actual level34 Triage requirement")
check(contains(step.body,"Gustaf VanHowzen") and not contains(step.body,"Gregory Victor"),"Alliance Triage route stays Alliance")
check(contains(step.body,"Optional introduction") and contains(step.body,"directly"),"Breadcrumb is not presented as a required prerequisite")
c.characterLevel=35
check(training(P.Guidance(c,"bandage")).requirementsMet,"Triage meets the exact character35/skill225 threshold")
c.characterLevel=nil
check(not training(P.Guidance(c,"bandage")).requirementsMet,"An unavailable actual character level cannot confirm quest eligibility")
c=context("bandage",225,225,7,"Horde",35)
check(contains(text(P.Guidance(c,"bandage")),"Gregory Victor") and not contains(text(P.Guidance(c,"bandage")),"Gustaf"),"Horde Triage route stays Horde")
c=context("bandage",290,300,9,"Alliance",35)
blocks=P.Guidance(c,"bandage")
check(blocks[1].spellId==18630 and blocks[1].skillMet,"Unlearned Heavy Runecloth is offered at its actual craft threshold")
check(not training(blocks),"An already raised cap does not ask for Triage again")
c.professions.known[18630]=true
check(P.NextUpgrade(c.professions,"bandage").status=="complete" and #P.Guidance(c,"bandage")==0,"All learned bandages have no spurious upgrade")
check(P.NextRecipe(c,"bandage")==nil,"All learned recipes suppress the compact upgrade hint")
c.professions.known[18630]=nil
check(P.NextUpgrade(c.professions,"bandage").status=="unknown","Missing knowledge is not treated as an unlearned recipe")
check(P.NextRecipe(c,"bandage")==nil,"Unknown recipe knowledge suppresses the compact hint")
check(P.Guidance(c,"bandage")[1].kind~="professionRecipe","Unknown highest knowledge suppresses a false next recipe")
c=context("bandage",300,300,1,"Alliance")
check(P.NextRecipe(c,"bandage").spellId==18630,"High skill skips obsolete missing intermediates for the strongest craftable bandage")
check(P.Best(c.professions,"bandage").itemId==1251,"Upgrade guidance does not change automatic learned-recipe selection")
c=context("bandage",230,300,1,"Alliance")
check(P.NextRecipe(c,"bandage").spellId==10840,"The strongest currently craftable missing bandage takes priority over a future threshold")
c=context("bandage",230,300,7,"Alliance")
check(P.NextRecipe(c,"bandage").spellId==10841 and not P.NextRecipe(c,"bandage").skillMet,"When no eligible recipe is missing, the nearest higher tier is shown")
c=context("dummy",300,300,0,"Alliance")
check(P.NextRecipe(c,"dummy").spellId==19814,"Engineering also skips obsolete missing intermediates at high skill")
c=context("antivenom",130,150,1,"Alliance")
check(P.Guidance(c,"antivenom")[1].recipeItemId==6454 and P.Guidance(c,"antivenom")[1].ahEligible,"Strong Anti-Venom is a tradable world-drop manual")
c=context("antivenom",300,300,2,"Horde")
blocks=P.Guidance(c,"antivenom")
check(blocks[1].recipeItemId==19442 and not blocks[1].ahEligible,"Powerful Anti-Venom formula is not AH eligible")
check(contains(text(blocks),"Honored") and contains(text(blocks),"binds when picked up"),"Powerful recipe reports both reputation and binding gates")
c=context("dummy",185,225,2,nil,40)
blocks=P.Guidance(c,"dummy")
check(blocks[1].recipeItemId==16046 and blocks[1].ahEligible and not blocks[1].skillMet,"Masterwork schematic is tradable but requires275")
check(contains(text(blocks),"Xizzer Fizzbolt"),"Neutral vendor stays available when faction is unknown")
check(training(blocks) and not training(blocks).requirementsMet,"Future275 recipe explains the200 base skill Artisan step")
c.professions.baseSkills.dummy=185;c.professions.skills.dummy=200;c.professions.trainingSkills={dummy=200}
check(training(P.Guidance(c,"dummy")).requirementsMet,"Permanent Gnome bonus is retained for Artisan training requirements")
c.professions.trainingSkills.dummy=185
check(not training(P.Guidance(c,"dummy")).requirementsMet,"Temporary skill alone is not used as permanent trainer skill")
c=context("cooking",225,225,0,"Alliance",35)
blocks=P.Guidance(c,"cooking")
step=training(blocks)
check(step and step.questId==6610 and step.requirementsMet,"Capped Cooking225 offers Clamlette Surprise at character35")
check(contains(step.body,"12 Giant Eggs") and contains(step.body,"10 Zesty Clam Meat") and contains(step.body,"20 Alterac Swiss"),"Artisan Cooking lists exact quest quantities")
check(contains(step.body,"I Know A Guy") and not contains(step.body,"Zamja"),"Cooking optional introduction follows actual Alliance faction")
check(contains(step.meta,"does not teach a Clamlette Surprise recipe"),"Quest skill training is not confused with a rewarded recipe")
c.faction="Horde"
check(contains(text(P.Guidance(c,"cooking")),"To Gadgetzan You Go!") and not contains(text(P.Guidance(c,"cooking")),"Daryl"),"Horde Cooking introduction is faction correct")
c.faction=nil
unknown=text(P.Guidance(c,"cooking"))
check(contains(unknown,"Dirge Quikcleave") and not contains(unknown,"Zamja") and not contains(unknown,"Daryl"),"Unknown faction retains the neutral Cooking quest only")
c=context("cooking",125,150,0,"Horde")
step=training(P.Guidance(c,"cooking"))
check(step and step.recipeItemId==16072 and contains(step.body,"Wulan"),"Expert Cooking uses the faction vendor's tradable cookbook")
check(step.itemId==16072 and contains(step.meta,"Self Found cannot use AH"),"Training book rows expose native item tooltips and the Self Found restriction")
c=context("cooking",225,300,0,"Alliance")
check(#P.Guidance(c,"cooking")==0,"Already Artisan Cooking never repeats the unlock quest")
unknown=text(P.Guidance({professions={skills={},known={}}},"cooking"))
check(contains(unknown,"unavailable") and contains(unknown,"Reference only"),"Unavailable Cooking APIs provide explicitly labeled neutral reference")
check(#P.Guidance({},"unknownFamily")==0,"Unsupported professions do not manufacture upgrade guidance")

local saved={GetNumSkillLines=GetNumSkillLines,GetSkillLineInfo=GetSkillLineInfo,
    C_TradeSkillUI=C_TradeSkillUI,C_SpellBook=C_SpellBook,lastSnapshot=P.lastSnapshot}
local ok,err=pcall(function()
    local rows={{"Erste Hilfe",210,15,0,225},{"Ingenieurskunst",185,0,15,225},{"Kochkunst",225,0,0,225}}
    GetNumSkillLines=function() return #rows end
    GetSkillLineInfo=function(index)
        local r=rows[index]
        return r[1],false,false,r[2],r[3],r[4],r[5]
    end
    C_TradeSkillUI={GetTradeSkillDisplayName=function(id) return ({[129]="Erste Hilfe",[202]="Ingenieurskunst",[185]="Kochkunst"})[id] end}
    C_SpellBook={IsSpellKnown=function() return false end}
    local read=P.Read()
    check(read.skills.cooking==225 and read.baseSkills.cooking==225 and read.maxSkills.cooking==225,"Cooking uses localized skill185 and the native max-rank return")
    check(read.skills.bandage==225 and read.baseSkills.bandage==210,"Effective First Aid and base quest skill remain separate")
    check(read.skills.dummy==200 and read.baseSkills.dummy==185 and read.trainingSkills.dummy==200 and read.maxSkills.dummy==225,"Engineering retains trained rank, permanent bonus and cap separately")
    check(read.trainingSkills.bandage==210,"Temporary points remain outside permanent trainer skill")
    rows[3][5]=0
    read=P.Read()
    check(read.skills.cooking==225 and read.maxSkills.cooking==nil,"Invalid cap is unknown while valid current skill remains usable")
    GetNumSkillLines=nil
    check(P.Read().skills.cooking==nil,"Unavailable skill API is not treated as unlearned Cooking")
end)
GetNumSkillLines=saved.GetNumSkillLines;GetSkillLineInfo=saved.GetSkillLineInfo
C_TradeSkillUI=saved.C_TradeSkillUI;C_SpellBook=saved.C_SpellBook;P.lastSnapshot=saved.lastSnapshot;P.reading=false
assert(ok,err)

print("PASS: "..checks.." profession progression checks cover faction routes, recipe books, AH eligibility, unknown knowledge and actual skill/level training gates.")
