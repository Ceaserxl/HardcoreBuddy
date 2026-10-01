local A=TestAddon
local G=A.GearAdvisor
local checks=0
local function check(ok,message) checks=checks+1; assert(ok,message) end
local function close(a,b) return a and math.abs(a-b)<0.00001 end
local items,equipment,talents={}, {}, {0,0,0}
local readLinks={}
GetLocale=function() return "enUS" end
GetTalentTabInfo=function(tab,inspect,pet)
    assert(inspect==false and pet==false)
    -- Current Classic compatibility API: id/name/description/icon/points.
    return 100+tab,"Localized tree "..tab,"Talent description",123,talents[tab],"Background",0,true
end
IsSpellKnown=function(id) return id==674 end
UnitDefense=function() return MOCK.level*5,0 end
GetInventoryItemID=function(unit,slot) assert(unit=="player"); return equipment[slot] and equipment[slot].id end
GetInventoryItemLink=function(unit,slot) assert(unit=="player"); return equipment[slot] and equipment[slot].link end
C_Item.GetItemInfo=function(link)
    readLinks[#readLinks+1]=link
    local v=items[link]
    if not v or v.loading then return end
    return v.name,link,2,35,v.required or 1,"Armor","Localized subclass",1,v.equip,123,100,v.classID,v.subclassID
end
C_Item.GetItemStats=function(link) return items[link] and items[link].stats end
DPS_TEMPLATE="(%.1f damage per second)"
ITEM_UNIQUE,ITEM_UNIQUE_EQUIPPABLE="Unique","Unique-Equipped"

-- Named left/right FontStrings mimic the native tooltip API, including clear
-- and item hooks. These are fixtures, not claims about the game renderer.
local function nativeTooltip(tip)
    tip.lines={}
    function tip:GetName() return self.name end
    function tip:SetOwner(owner,anchor) self.owner=owner end
    function tip:GetItem() return self.link and "Fixture",self.link end
    function tip:NumLines() return #self.lines end
    function tip:ClearLines()
        for i=1,#self.lines do
            _G[self.name.."TextLeft"..i]:SetText("")
            _G[self.name.."TextRight"..i]:SetText("")
        end
        self.lines={}; self.link=nil
        if self.scripts.OnTooltipCleared then self.scripts.OnTooltipCleared(self) end
    end
    function tip:AddDoubleLine(left,right,lr,lg,lb,rr,rg,rb)
        self.lines[#self.lines+1]={left,right}
        for i,side in ipairs({"Left","Right"}) do
            local name=self.name.."Text"..side..#self.lines
            local region=_G[name] or self:CreateFontString(name,"OVERLAY")
            region:SetText(i==1 and left or right)
            region:SetTextColor(i==1 and lr or rr,i==1 and lg or rg,i==1 and lb or rb)
            function region:GetTextColor() return unpack(self.color) end
            region:Show()
        end
    end
    function tip:AddLine(text,r,g,b) self:AddDoubleLine(text,"",r or 1,g or 1,b or 1,1,1,1) end
    function tip:SetHyperlink(link)
        self:ClearLines(); self.link=link
        local item=items[link]
        if not item then error("Unknown fixture link") end
        self:AddLine(item.name,1,1,1)
        for _,entry in ipairs(item.lines or {}) do
            self:AddDoubleLine(entry[1],entry[2] or "",entry.red and 1 or 0.5,entry.red and 0.1 or 1,entry.red and 0.1 or 0.5,
                1,entry.rightRed and 0.1 or 1,entry.rightRed and 0.1 or 1)
        end
        if self.scripts.OnTooltipSetItem then self.scripts.OnTooltipSetItem(self) end
    end
    function tip:SetInventoryItem(unit,slot)
        assert(unit=="player")
        self.inventorySlot=slot
        self:SetHyperlink(GetInventoryItemLink(unit,slot))
    end
    return tip
end
nativeTooltip(GameTooltip)
ItemRefTooltip=nativeTooltip(CreateFrame("GameTooltip","ItemRefTooltip",UIParent))
G:RegisterTooltip(ItemRefTooltip)
local create=CreateFrame
CreateFrame=function(kind,name,parent,template)
    local result=create(kind,name,parent,template)
    if kind=="GameTooltip" then nativeTooltip(result) end
    return result
end
local serial=20000
local function item(equip,stats,classID,subclassID,lines)
    serial=serial+1
    local link="item:"..serial..":0:0:0:0:0:-15:0:30"
    local result={id=serial,link=link,name="Fixture "..serial,equip=equip,stats=stats or {},classID=classID or 4,subclassID=subclassID or 1,lines=lines}
    items[link]=result
    return result
end
local function withEnchant(base,enchantId,stats,lines)
    local result={}
    for key,value in pairs(base) do result[key]=value end
    result.link=base.link:gsub("^(item:%d+):0:","%1:"..enchantId..":")
    result.stats,result.lines=stats,lines
    items[result.link]=result
    return result
end
local function report(v) return G:Report(v.link) end
-- Retain legacy score/slot regression coverage for historical snapshots.
-- Native tooltip and projection tests below exercise the real Report path.
local function row(v,n)
    local item,reason=G:Read(v.link)
    local profile=G:CurrentProfile()
    if not item or not profile then return report(v).rows[n or 1] end
    local allowed=G.Allowed(item,profile)
    return allowed and G:Comparisons(item,profile)[n or 1] or report(v).rows[n or 1]
end
local function reset(class,level,points)
    MOCK.class,MOCK.level=class or "WARRIOR",level or 40
    equipment={}; talents=points or {0,0,0}
    A.characterDB.advisors=nil
    A.db.gearAdvisorEnabled=true
    GameTooltip:ClearLines(); ItemRefTooltip:ClearLines()
end

-- Reference tables cover every class and tree through the whole leveling range.
for class,profiles in pairs(A.Data.AdvisorGear) do
    for level=1,60 do
        for tree=1,3 do
            local p=G.Profile(class,level,tree)
            check(p and p.class==class and p.level==level,"All Classic trees and levels")
        end
    end
    for _,profile in ipairs(profiles) do check(G.Profile(class,60,nil,profile.id).name==profile.name,"Manual roles") end
end
reset("HUNTER",40,{31,0,0})
check(G:CurrentProfile().name=="Beast Mastery","Classic compatibility talent API")
local legacy=GetTalentTabInfo
C_SpecializationInfo={GetSpecializationInfo=function(tab) return tab,"Tree "..tab,"description",1,"DAMAGER",2,talents[tab] end}
GetTalentTabInfo=function() error("Deprecated API used") end
check(G:CurrentProfile().name=="Beast Mastery","Modern API points are return seven")
talents={0,nil,0}
check(G:CurrentProfile().fallback==true,"Missing talent data has a labeled leveling default")
C_SpecializationInfo=nil; GetTalentTabInfo=legacy
reset("DRUID",60,{0,0,51}); check(G:CurrentProfile().name=="Restoration","Druid tree maps past feral tank role")
A.characterDB.advisors={gearProfile=3}
check(G:CurrentProfile().name=="Feral TANK","Manual feral tank role")
reset("MAGE",30,{10,10,0}); check(G:CurrentProfile().name=="Arcane","Stable tree-order tie")
A.db.profile.mode="preview"; A.db.profile.characterClass="Warrior"; A.db.profile.level=60
check(G:CurrentProfile().class=="MAGE" and G:CurrentProfile().level==30,"Planned character does not change live scoring")

-- Reproduce the user's actual item comparisons with reference weights.
reset("HUNTER",40,{31,0,0})
local gloves=item("INVTYPE_HAND",{RESISTANCE0_NAME=171,ITEM_MOD_CRIT_RATING_SHORT=1},4,3,
    {{"171 Armor"},{"+7 Stamina"},{"+6 Spirit"},{"Equip: Improves your chance to get a critical strike by 1%."}})
gloves.name="Dragonscale Gauntlets"
local kit=withEnchant(gloves,1843,{RESISTANCE0_NAME=211,ITEM_MOD_CRIT_RATING_SHORT=1},
    {{"171 Armor"},{"+7 Stamina"},{"+6 Spirit"},{"Reinforced Armor +40"}})
equipment[10]=kit
local scorpid=item("INVTYPE_HAND",{},4,3,{{"155 Armor"},{"+10 Agility"},{"+9 Spirit"}})
scorpid.name="Tough Scorpid Gloves"
check(close(G.Score(G:Read(kit.link),G:CurrentProfile(),10),11.155),"Reference glove score; armor kit excluded")
check(close(row(scorpid).percent,77.27),"Reference +77.27 percent comparison")
check(row(scorpid).losses:find("-7 Sta",1,true) and row(scorpid).losses:find("-1% Crit",1,true),"Lost survival and secondary stats remain visible")
local shoulders=item("INVTYPE_SHOULDER",{ITEM_MOD_AGILITY_SHORT=1},4,3,{{"184 Armor"},{"+8 Agility"},{"+9 Intellect"}})
equipment[3]=shoulders
local skeletal=item("INVTYPE_SHOULDER",{},4,3,{{"199 Armor"},{"+6 Strength"},{"+15 Stamina"}})
skeletal.name="Skeletal Shoulders"
check(close(row(skeletal).percent,-45.45),"Reference shoulder downgrade floors negative percentages")
check(G:Read(shoulders.link).stats.ITEM_MOD_AGILITY_SHORT==8,"Native suffix attributes override faulty API")

-- Live screenshot: the equipped Frozen Wrath hat's short bonus line was
-- dropped, leaving only 0.225 armor score and a false +593.33% upgrade.
do
    reset("MAGE",40,{0,0,31})
    local frozen=item("INVTYPE_HEAD",{RESISTANCE0_NAME=45},4,1,
        {{"45 Armor"},{"+15 Frost Spell Damage"}})
    frozen.name="Regal Wizard Hat of Frozen Wrath"
    local wolf=item("INVTYPE_HEAD",{},4,1,{{"48 Armor"},{"+12 Agility"},{"+12 Spirit"}})
    wolf.name="Royal Headband of the Wolf"
    equipment[1]=frozen
    check(close(G.Score(G:Read(frozen.link),G:CurrentProfile(),1),14.475),"Short Frost suffix contributes to equipped score")
    check(close(row(wolf).percent,-89.23) and row(wolf).status=="down","Screenshot comparison matches reference Frost build and flooring")
    check(row(wolf).losses=="-15 Frost","Lost school damage is shown")
    equipment[1]=wolf
    check(row(frozen).status=="up","Short school damage also works on the candidate")
    for _,school in ipairs({"Frost","Fire","Shadow","Nature","Arcane","Holy"}) do
        local key="ITEM_MOD_"..school:upper().."_DAMAGE_SHORT"
        for _,apiAmount in ipairs({0,1,15}) do
            local suffix=item("INVTYPE_HEAD",{[key]=apiAmount},4,1,{{"45 Armor"},{"+15 "..school.." Spell Damage"}})
            check(G:Read(suffix.link).stats[key]==15,"Native school suffix replaces absent/incorrect API values without duplication")
        end
    end
    local enhanced=withEnchant(frozen,9999,{},{{"45 Armor"},{"+15 Frost Spell Damage"},{"+20 Frost Spell Damage"}})
    check(G:Read(enhanced.link).stats.ITEM_MOD_FROST_DAMAGE_SHORT==15,"Applied enchant excluded; intrinsic suffix retained")
    local conditional=item("INVTYPE_HEAD",{},4,1,{{"45 Armor"},{"Use: +40 Frost Spell Damage"},
        {"Chance on hit: +40 Frost Spell Damage"},{"(2) Set: +40 Frost Spell Damage"}})
    check(G:Read(conditional.link).stats.ITEM_MOD_FROST_DAMAGE_SHORT==nil,"Conditional effects are not short intrinsic stats")
end

local materialChecks=0
for class in pairs(A.Data.AdvisorGear) do
    for _,level in ipairs({1,39,40,50,60}) do
        reset(class,level)
        local p=G:CurrentProfile()
        local armor={{1,1},{2,2},{3,3},{4,4}}
        for oldType=1,4 do
            local old=item("INVTYPE_CHEST",{ITEM_MOD_STAMINA_SHORT=10,RESISTANCE0_NAME=100},4,oldType)
            if G.Allowed(G:Read(old.link),p) then
                equipment[5]=old
                for candidateType=1,4 do
                    local candidate=item("INVTYPE_ROBE",{ITEM_MOD_STAMINA_SHORT=10,RESISTANCE0_NAME=100},4,candidateType)
                    if G.Allowed(G:Read(candidate.link),p) then
                        check(row(candidate).percent==0,"No material penalty, bonus, or matching-subclass restriction")
                        materialChecks=materialChecks+1
                    else check(row(candidate).status=="unknown","Unequippable materials excluded") end
                end
            end
        end
    end
end
reset("WARRIOR",40)
local old=item("INVTYPE_HEAD",{ITEM_MOD_STRENGTH_SHORT=10})
local better=item("INVTYPE_HEAD",{ITEM_MOD_STRENGTH_SHORT=12})
local worse=item("INVTYPE_HEAD",{ITEM_MOD_STRENGTH_SHORT=8})
equipment[1]=old
check(row(better).text=="+20.00% Upgrade" and row(worse).text=="-20.00% Downgrade","Percentage and direction")
check(row(old).percent==0,"Identical items compare equally")
equipment[1]=item("INVTYPE_HEAD",{})
check(row(better).text=="No scored baseline" and row(better).percent==nil,"Zero baseline")
equipment[1]=nil
check(row(better).status=="up" and row(better).percent==nil,"Empty slot")
equipment[1]={id=old.id,link="item:999:0"}
check(row(better).status=="unknown","Stale baseline ID/link")
equipment[1]=old; old.loading=true
check(row(better).status=="unknown","Uncached baseline")
old.loading=nil; old.stats.ITEM_MOD_STRENGTH_SHORT=0/0
check(row(better).status=="unknown","Invalid API number")
old.stats.ITEM_MOD_STRENGTH_SHORT=10; better.required=55
check(row(better).status=="unknown","Level restriction")
better.required=1; better.lines={{"Requires Blacksmithing (300)",red=true}}
check(row(better).status=="unknown","Native equipment restrictions")
better.lines=nil
local ring=item("INVTYPE_FINGER",{ITEM_MOD_STRENGTH_SHORT=15})
equipment[11]=item("INVTYPE_FINGER",{ITEM_MOD_STRENGTH_SHORT=10})
equipment[12]=item("INVTYPE_FINGER",{ITEM_MOD_STRENGTH_SHORT=20})
check(close(row(ring,1).percent,50) and close(row(ring,2).percent,-25),"Both ring slots")
ring.lines={{"Unique"}}; equipment[12]=ring
check(row(ring,1).status=="unknown","Unique ring conflict")
equipment[16]=item("INVTYPE_WEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},2,7)
equipment[17]=item("INVTYPE_WEAPONOFFHAND",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=5},2,7)
local twohand=item("INVTYPE_2HWEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=30},2,8)
check(close(row(twohand).percent,100) and row(twohand).label=="Both hands","Two-handed replaces both weapons")
equipment[16]=twohand; equipment[17]=nil
local off=item("INVTYPE_WEAPONOFFHAND",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},2,7)
check(row(off).status=="unknown","Cannot equip offhand beside two-hander")
reset("DRUID",40,{0,31,0})
local staff=item("INVTYPE_2HWEAPON",{ITEM_MOD_STRENGTH_SHORT=5},2,10,{{"(10.0 damage per second)"}})
check(G:CurrentProfile().weights.meleeDPS>0 and G.Score(G:Read(staff.link),G:CurrentProfile(),16)>0,"Feral weapon scoring retains the selected profile DPS weight")

-- Live screenshots: native displayed DPS (not the higher-precision item API)
-- and the selected profile's DPS weight reproduce the item percentages.
reset("HUNTER",41,{31,1,0})
local rapier=item("INVTYPE_WEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=28.05555534362793},2,7,
    {{"(28.1 damage per second)"},{"+8 Agility"},{"+3 Stamina"}})
rapier.name="Speedsteel Rapier"
equipment[16]=rapier; equipment[17]=rapier
local zealot=item("INVTYPE_WEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=22.14285659790039},2,7,
    {{"(22.1 damage per second)"},{"+5 Intellect"},{"+6 Spirit"}})
zealot.name="Zealot Blade"
local jordan=item("INVTYPE_2HWEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=40.4054069519043},2,10,
    {{"(40.4 damage per second)"},{"+11 Intellect"},{"+11 Spirit"},
     {"Equip: Increases damage and healing done by magical spells and effects by up to 26."}})
jordan.name="Staff of Jordan"
check(G:Read(rapier.link).dps==28.1 and close(G.Score(G:Read(rapier.link),G:CurrentProfile(),16),76.94),"Equipped weapon uses displayed DPS and reference profile weight")
check(report(zealot).rows[1].percent==-18.07 and report(zealot).rows[2].percent==-18.07,"Zealot Blade screenshot matches both reference slot percentages")
local jordanReport=report(jordan)
check(jordanReport.rows[1].label=="Main hand" and jordanReport.rows[1].percent==51.75,"Staff of Jordan item percentage matches main-hand reference")
check(jordanReport.rows[2].label=="Both hands" and jordanReport.rows[2].percent==-24.13,"Separate setup comparison still accounts for losing the off hand")
local enchantedZealot=withEnchant(zealot,241,zealot.stats,{{"(22.8 damage per second)"},{"+5 Intellect"},{"+6 Spirit"},{"Weapon Damage +2"}})
check(report(enchantedZealot).rows[1].percent==-18.07,"Weapon enchant remains excluded from displayed intrinsic DPS")
for class,profiles in pairs(A.Data.AdvisorGear) do
    for id,source in ipairs(profiles) do
        local profile=G.Profile(class,40,nil,id)
        check(profile.weights.meleeDPS==profile.weights.rangedDPS and profile.weights.meleeDPS==profile.weights.wandDPS,
            "Selected weapon DPS weight is not overridden by class or slot")
        if source.stats.DAMAGE_PER_SECOND then check(profile.weights.meleeDPS==source.stats.DAMAGE_PER_SECOND,"Explicit reference DPS weight preserved") end
    end
end

reset("HUNTER",40,{31,0,0}); equipment[10]=kit; equipment[3]=shoulders
GameTooltip:SetHyperlink(scorpid.link)
local lineCount=GameTooltip:NumLines()
local state=GameTooltip.hardcoreBuddyGear
check(state and _G[GameTooltip.name.."TextLeft"..state.start]:GetText()==" ","Spacer before advisor")
local reads=#readLinks
G:Add(GameTooltip)
check(GameTooltip:NumLines()==lineCount and #readLinks==reads,"No duplicate rows or repeated scans")
equipment[10]=scorpid; MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",10)
check(GameTooltip:NumLines()==lineCount and GameTooltip.hardcoreBuddyGear.report.rows[1].percent==0,"Visible advice refreshes without new rows")
A.db.gearAdvisorEnabled=false; G:RefreshTooltips(); check(not GameTooltip:IsShown(),"Disable hides stale visible advice")
A.db.gearAdvisorEnabled=true
print("PASS: "..checks.." gear assertions; "..materialChecks.." cross-material comparisons; reference scores and native tooltip lifecycle.")
GEAR_FIXTURES={item=item,withEnchant=withEnchant,reset=reset,
    equip=function(slot,v) equipment[slot]=v end,alias=function(link,v) items[link]=v end}
if GEAR_RENDER then
    GEAR_PREVIEWS={}
    reset("HUNTER",40,{31,0,0}); equipment[10]=kit; equipment[3]=shoulders
    for i,v in ipairs({scorpid,skeletal}) do
        local tip=nativeTooltip(CreateFrame("GameTooltip","HardcoreBuddyGearPreview"..i,UIParent))
        G:RegisterTooltip(tip); tip:SetHyperlink(v.link); GEAR_PREVIEWS[i]=tip
    end
end
