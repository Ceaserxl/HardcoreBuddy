local A=TestAddon
local P=A.Professions
local checks=0
local function check(value,message) checks=checks+1; assert(value,message) end
local saved={}
local globals={"GetNumSkillLines","GetSkillLineInfo","ExpandSkillHeader","CollapseSkillHeader",
    "C_TradeSkillUI","C_Spell","GetSpellInfo","GetLocale","C_SpellBook","IsPlayerSpell","IsSpellKnown"}
for _,key in ipairs(globals) do saved[key]=_G[key] end
local oldSnapshot=P.lastSnapshot
local function run()
    local allKnown={}
    for _,family in ipairs({"bandage","dummy","antivenom"}) do
        for _,r in ipairs(P.recipes[family]) do allKnown[r.spellId]=true end
    end
    local snapshot={skills={},known=allKnown}
    for _,family in ipairs({"bandage","dummy","antivenom"}) do
        local skill=family=="antivenom" and "bandage" or family
        for index,recipe in ipairs(P.recipes[family]) do
            snapshot.skills[skill]=recipe.craftSkill
            check(P.Best(snapshot,family).itemId==recipe.itemId,"Select recipe at its exact crafting threshold")
            snapshot.skills[skill]=recipe.craftSkill-1
            check(P.Best(snapshot,family).itemId==(P.recipes[family][index-1] or {}).itemId,
                "Do not select a recipe one skill point below its crafting threshold")
            check(P.ByItem(recipe.itemId).spellId==recipe.spellId,"Item recipe lookup retains the learned spell ID")
        end
    end
    snapshot.skills.bandage=225
    check(P.Best(snapshot,"bandage").itemId==8544,"First Aid225 can make Mageweave; using Heavy Runecloth requires only225")
    snapshot.skills.bandage=300
    local anti=P.recipes.antivenom
    allKnown[anti[3].spellId]=false
    check(P.Best(snapshot,"antivenom").itemId==anti[2].itemId,"First Aid300 without the Powerful Anti-Venom book retains Strong")
    allKnown[anti[2].spellId]=false
    check(P.Best(snapshot,"antivenom").itemId==anti[1].itemId,"Missing both anti-venom books retains the trained basic recipe")
    allKnown[anti[3].spellId]=nil
    check(P.Best(snapshot,"antivenom").status=="unknown","Unknown Powerful recipe knowledge is not assumed unlearned")
    allKnown[anti[3].spellId]=true
    check(P.Best(snapshot,"antivenom").itemId==anti[3].itemId and snapshot.skills.antivenom==nil,"Anti-venom uses First Aid without a separate profession key")
    allKnown[18630]=false
    check(P.Best(snapshot,"bandage").itemId==14529,"An unlearned best recipe falls back to the strongest learned recipe")
    allKnown[18630]=nil
    check(P.Best(snapshot,"bandage").status=="unknown","Unknown higher recipe knowledge never becomes a false best-rank claim")
    allKnown[18630]=true
    snapshot.skills.dummy=300
    allKnown[19814]=false
    check(P.Best(snapshot,"dummy").itemId==4392,"Engineering300 without Masterwork schematic selects Advanced")
    snapshot.skills.dummy=0
    check(P.Best(snapshot,"dummy").status=="unlearned","Unlearned profession does not select a recipe")
    snapshot.skills.dummy=nil
    check(P.Best(snapshot,"dummy").status=="unknown","Unknown skill is distinct from not learned")
    snapshot.skills.dummy=84
    check(P.Best(snapshot,"dummy").status=="untrained","Engineering below85 has no craftable target dummy")
    snapshot.skills.dummy=300
    allKnown[3932],allKnown[3965]=false,false
    check(P.Best(snapshot,"dummy").status=="untrained","Known missing recipes do not fall back to a skill-only recommendation")
    snapshot.selections={dummy=16023,bandage=1251}
    allKnown[3965]=true
    check(P.Best(snapshot,"dummy").itemId==4392,"Stale manual selections do not affect automatic choice")

    -- A localized, collapsed skill tree exercises live reads and synchronous
    -- SKILL_LINES_CHANGED reentry without opening a profession or spellbook.
    local sections={
        {name="Berufe",open=false,children={{name="Ingenieurskunst",rank=165,temporary=5,modifier=15}}},
        {name="Sekundarfertigkeiten",open=false,children={{name="Erste Hilfe",rank=145,temporary=5,modifier=0}}},
        {name="Waffen",open=true,children={{name="Dolche",rank=100,modifier=0}}},
    }
    local function visible()
        local rows={}
        for _,section in ipairs(sections) do
            rows[#rows+1]=section
            if section.open then for _,entry in ipairs(section.children) do rows[#rows+1]=entry end end
        end
        return rows
    end
    C_TradeSkillUI={GetTradeSkillDisplayName=function(id) return id==129 and "Erste Hilfe" or id==202 and "Ingenieurskunst" end}
    GetNumSkillLines=function() return #visible() end
    GetSkillLineInfo=function(index)
        local row=visible()[index]
        if row.children then return row.name,true,row.open,0,0,0,0 end
        return row.name,false,false,row.rank,row.temporary or 0,row.modifier,300
    end
    local reentries=0
    ExpandSkillHeader=function(index)
        visible()[index].open=true
        reentries=reentries+1; local nested=P.Read()
        assert(nested and P.reading,"Synchronous skill event must not recursively scan")
    end
    CollapseSkillHeader=function(index) visible()[index].open=false; reentries=reentries+1; P.Read() end
    C_SpellBook={IsSpellKnown=function(id) return id==7928 or id==3275 or id==3965 or id==3932 or id==anti[2].spellId end}
    IsSpellKnown=function() error("Legacy spellbook-only API must not be used for recipes") end
    local read=P.Read()
    check(read.available and read.skills.bandage==150 and read.skills.dummy==185,"Read localized ranks including temporary points and engineering racial modifier")
    check(P.Best(read,"bandage").itemId==6450 and P.Best(read,"dummy").itemId==4392,"Closed-window recipe knowledge drives automatic best selection")
    check(P.Best(read,"antivenom").itemId==anti[2].itemId and read.skills.antivenom==nil,"Localized First Aid drives anti-venom with no extra skill line")
    check(not sections[1].open and not sections[2].open and sections[3].open and reentries==4 and not P.reading,
        "Restore each header and guard synchronous recursive events")
    sections[1].children={}
    read=P.Read()
    check(read.skills.dummy==0 and P.Best(read,"dummy").status=="unlearned","A complete skill scan detects an unlearned profession")
    C_SpellBook=nil
    IsPlayerSpell=function(id) return id==3275 or id==anti[1].spellId end
    read=P.Read()
    check(P.Best(read,"bandage").itemId==1251,"Legacy IsPlayerSpell is a valid outside-spellbook recipe fallback")
    check(P.Best(read,"antivenom").itemId==anti[1].itemId,"Legacy recipe API reads anti-venom too")
    IsPlayerSpell=nil
    read=P.Read()
    check(not read.available and P.Best(read,"bandage").status=="unknown","Unavailable recipe APIs stay unknown")
    check(P.Best(read,"antivenom").status=="unknown","Unavailable recipe APIs do not select an anti-venom rank")
    C_SpellBook={IsSpellKnown=function() error("not ready") end}
    check(P.Best(P.Read(),"bandage").status=="unknown","Recipe query errors do not imply unlearned recipes")
    GetNumSkillLines=nil
    read=P.Read()
    check(read.skills.bandage==nil and P.Best(read,"bandage").status=="unknown" and not P.reading,"Missing skill API is explicit and releases reader guard")
    GetNumSkillLines=function() return 0 end
    check(P.Read().skills.bandage==nil,"An empty startup skill list does not imply no profession")
    GetNumSkillLines=function() return #visible() end
    GetSkillLineInfo=function(index) if index==2 then error("partial scan") end; return "Berufe",true,sections[1].open,0,0,0 end
    read=P.Read()
    check(not sections[1].open and not P.reading and read.skills.bandage==nil,"Partial scan errors restore expanded headers and remain unknown")
end
local ok,err=pcall(run)
for _,key in ipairs(globals) do _G[key]=saved[key] end
P.lastSnapshot=oldSnapshot; P.reading=false
assert(ok,err)
print("PASS: "..checks.." profession checks cover exact craft thresholds, learned recipes, localized skills, collapsed headers, reentry and unknown APIs.")
