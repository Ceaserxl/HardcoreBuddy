local _, A = ...
local G={tooltips=setmetatable({},{__mode="k"}),revision=0}; A.GearAdvisor=G
function G:IsEnabled() return A.db and A.db.gearAdvisorActive~=false end
function G:SetEnabled(enabled)
    A.db.gearAdvisorActive=not not enabled
    if A.GearBagAdvisor then A.GearBagAdvisor:Changed() end
    self:RefreshTooltips()
    if A.GearIndicators then A.GearIndicators:Invalidate() end
    if A.AuctionUpgrades then
        if not enabled and A.AuctionUpgrades.scan then A.AuctionUpgrades:Stop("Gear Advisor disabled.")
        else A.AuctionUpgrades:Refresh() end
    end
    if A.window and A.window:IsShown() then A:Refresh() end
end
local slots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_CHEST={5},INVTYPE_ROBE={5},
    INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16},
    INVTYPE_WEAPONMAINHAND={16},INVTYPE_2HWEAPON={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},
    INVTYPE_HOLDABLE={17},INVTYPE_RANGED={18},INVTYPE_RANGEDRIGHT={18},INVTYPE_THROWN={18}}
local slotNames={[1]="Head",[2]="Neck",[3]="Shoulders",[5]="Chest",[6]="Waist",[7]="Legs",[8]="Feet",
    [9]="Wrists",[10]="Hands",[11]="Ring 1",[12]="Ring 2",[13]="Trinket 1",[14]="Trinket 2",
    [15]="Back",[16]="Main hand",[17]="Off hand",[18]="Ranged"}
local weaponTypes={WARRIOR={0,1,2,3,4,5,6,7,8,10,13,15,16,18},PALADIN={0,1,4,5,6,7,8},
    HUNTER={0,1,2,3,6,7,8,10,13,15,16,18},ROGUE={2,3,4,7,13,15,16,18},
    SHAMAN={0,1,4,5,10,13,15},DRUID={4,5,10,13,15},MAGE={7,10,15,19},PRIEST={4,10,15,19},WARLOCK={7,10,15,19}}
-- Equip permission only: every lighter armor type is valid. Never require the
-- candidate to match equipped armor type or reward a class's heaviest type.
local armorMax={WARRIOR=3,PALADIN=3,HUNTER=2,ROGUE=2,SHAMAN=2,DRUID=2,MAGE=1,PRIEST=1,WARLOCK=1}
local statKeys={strength={"ITEM_MOD_STRENGTH_SHORT"},agility={"ITEM_MOD_AGILITY_SHORT"},
    stamina={"ITEM_MOD_STAMINA_SHORT"},intellect={"ITEM_MOD_INTELLECT_SHORT"},spirit={"ITEM_MOD_SPIRIT_SHORT"},
    armor={"RESISTANCE0_NAME","ITEM_MOD_ARMOR_SHORT"},health={"ITEM_MOD_HEALTH_SHORT"},mana={"ITEM_MOD_MANA_SHORT"},
    attackPower={"ITEM_MOD_ATTACK_POWER_SHORT"},rangedAttackPower={"ITEM_MOD_RANGED_ATTACK_POWER_SHORT"},
    spellPower={"ITEM_MOD_SPELL_POWER_SHORT","ITEM_MOD_SPELL_DAMAGE_DONE_SHORT"},
    healing={"ITEM_MOD_SPELL_HEALING_DONE_SHORT"},mp5={"ITEM_MOD_POWER_REGEN0_SHORT","ITEM_MOD_MANA_REGENERATION_SHORT"},
    hit={"ITEM_MOD_HIT_RATING_SHORT","ITEM_MOD_HIT_MELEE_RATING_SHORT"},crit={"ITEM_MOD_CRIT_RATING_SHORT","ITEM_MOD_CRIT_MELEE_RATING_SHORT"},
    spellHit={"ITEM_MOD_HIT_SPELL_RATING_SHORT"},spellCrit={"ITEM_MOD_CRIT_SPELL_RATING_SHORT"},
    defense={"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"},dodge={"ITEM_MOD_DODGE_RATING_SHORT"},
    parry={"ITEM_MOD_PARRY_RATING_SHORT"},block={"ITEM_MOD_BLOCK_RATING_SHORT"},blockValue={"ITEM_MOD_BLOCK_VALUE_SHORT"},
    frost={"ITEM_MOD_FROST_DAMAGE_SHORT"},fire={"ITEM_MOD_FIRE_DAMAGE_SHORT"},shadow={"ITEM_MOD_SHADOW_DAMAGE_SHORT"},
    nature={"ITEM_MOD_NATURE_DAMAGE_SHORT"},arcane={"ITEM_MOD_ARCANE_DAMAGE_SHORT"},holy={"ITEM_MOD_HOLY_DAMAGE_SHORT"}}
local colors={up={0.45,0.84,0.59},down={0.96,0.43,0.38},equal={0.67,0.69,0.72},unknown={0.96,0.72,0.37},gold={0.94,0.76,0.43}}
local function api(name) return C_Item and C_Item[name] or _G[name] end
local function number(value) return type(value)=="number" and value==value and value>=0 and value<math.huge end
local function itemID(link) return type(link)=="string" and tonumber(link:match("item:(%d+)")) end

local primaryStats={
    {"ITEM_MOD_STRENGTH_SHORT","ITEM_MOD_STRENGTH","Strength"},
    {"ITEM_MOD_AGILITY_SHORT","ITEM_MOD_AGILITY","Agility"},
    {"ITEM_MOD_STAMINA_SHORT","ITEM_MOD_STAMINA","Stamina"},
    {"ITEM_MOD_INTELLECT_SHORT","ITEM_MOD_INTELLECT","Intellect"},
    {"ITEM_MOD_SPIRIT_SHORT","ITEM_MOD_SPIRIT","Spirit"},
}
local function statPatterns()
    local patterns={}
    local english=not GetLocale or GetLocale()=="enUS" or GetLocale()=="enGB"
    local function add(key,template)
        if type(template)~="string" then return end
        -- Native primary-stat formats use %c%d (sign then amount). Armor
        -- uses %d. Escape the localized words, not the numeric capture.
        local pattern=template:gsub("%%c%%d","@NUMBER@"):gsub("%%d","@NUMBER@")
        if not pattern:find("@NUMBER@",1,true) then return end
        pattern=pattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1")
        pattern=pattern:gsub("@NUMBER@",function() return "([%+%-]?%d+)" end)
        patterns[#patterns+1]={key,"^"..pattern.."$"}
    end
    for _,entry in ipairs(primaryStats) do
        local label=_G[entry[1]] or (english and entry[3])
        add(entry[1],_G[entry[2]] or (label and ("%c%d "..label)))
    end
    local complete=#patterns==#primaryStats
    add("RESISTANCE0_NAME",ARMOR_TEMPLATE or (english and "%d Armor"))
    -- Random suffixes can display a short intrinsic bonus instead of an Equip
    -- sentence. GetItemStats may omit these or return the wrong suffix value.
    for _,school in ipairs({"Holy","Fire","Nature","Frost","Shadow","Arcane"}) do
        local key="ITEM_MOD_"..school:upper().."_DAMAGE_SHORT"
        local label=_G[key]
        if type(label)=="string" then add(key,"%c%d "..label) end
        if english then add(key,"%c%d "..school.." Spell Damage") end
    end
    return patterns,complete
end

local function parseBaseStats(text,patterns,stats)
    text=text:gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
    for _,entry in ipairs(patterns) do
        local value=tonumber(text:match(entry[2]))
        if value then stats[entry[1]]=(stats[entry[1]] or 0)+value; return true end
    end
end

-- Classic exposes many static Equip bonuses as spells rather than item stats.
-- Strict English fallbacks supplement, never add twice to, the native API.
-- Do not match chance-on-hit, Use, set bonuses, or conditional effects.
local equipPatterns={
    {"^Increases damage and healing done by magical spells and effects by up to (%d+)%.$","ITEM_MOD_SPELL_POWER_SHORT"},
    {"^Increases healing done by spells and effects by up to (%d+)%.$","ITEM_MOD_SPELL_HEALING_DONE_SHORT"},
    {"^Restores (%d+) mana per 5 sec%.$","ITEM_MOD_POWER_REGEN0_SHORT"},
    {"^Improves your chance to hit by (%d+)%%%.$","ITEM_MOD_HIT_RATING_SHORT"},
    {"^Improves your chance to get a critical strike by (%d+)%%%.$","ITEM_MOD_CRIT_RATING_SHORT"},
    {"^Improves your chance to hit with spells by (%d+)%%%.$","ITEM_MOD_HIT_SPELL_RATING_SHORT"},
    {"^Improves your chance to get a critical strike with spells by (%d+)%%%.$","ITEM_MOD_CRIT_SPELL_RATING_SHORT"},
    {"^Increased Defense %+(%d+)%.$","ITEM_MOD_DEFENSE_SKILL_RATING_SHORT"},
    {"^%+(%d+) Attack Power%.$","ITEM_MOD_ATTACK_POWER_SHORT"},
    {"^%+(%d+) ranged Attack Power%.$","ITEM_MOD_RANGED_ATTACK_POWER_SHORT"},
    {"^Increases your chance to dodge an attack by (%d+)%%%.$","ITEM_MOD_DODGE_RATING_SHORT"},
    {"^Increases your chance to parry an attack by (%d+)%%%.$","ITEM_MOD_PARRY_RATING_SHORT"},
    {"^Increases your chance to block attacks with a shield by (%d+)%%%.$","ITEM_MOD_BLOCK_RATING_SHORT"},
    {"^Increases the block value of your shield by (%d+)%.$","ITEM_MOD_BLOCK_VALUE_SHORT"},
}

function G.ParseEquip(text,stats)
    if type(text)~="string" or not text:match("^Equip: ") then return end
    text=text:sub(8)
    for _,entry in ipairs(equipPatterns) do
        local amount=tonumber(text:match(entry[1]))
        if amount then stats[entry[2]]=(stats[entry[2]] or 0)+amount; return true end
    end
    local school,amount=text:match("^Increases damage done by (%a+) spells and effects by up to (%d+)%.$")
    if school and ({Fire=true,Frost=true,Shadow=true,Nature=true,Arcane=true,Holy=true})[school] then
        local key="ITEM_MOD_"..school:upper().."_DAMAGE_SHORT"
        stats[key]=(stats[key] or 0)+tonumber(amount)
        return true
    end
end

-- A profile is a direct stat-weight sum, using the Classic reference tables.
-- Armor subclass affects permission to equip, never the value of the score.
local defaults={DRUID=2,HUNTER=1,MAGE=3,PALADIN=3,PRIEST=3,ROGUE=2,SHAMAN=2,WARLOCK=2,WARRIOR=1}
local weightNames={strength="STRENGTH",agility="AGILITY",stamina="STAMINA",intellect="INTELLECT",spirit="SPIRIT",
    armor="ARMOR",health="HEALTH",mana="MANA",attackPower="ATTACK_POWER",rangedAttackPower="RANGED_ATTACK_POWER",
    spellPower="SPELL_DAMAGE_DONE",healing="SPELL_HEALING_DONE",mp5="MANA_REGENERATION",hit="HIT",crit="CRIT",
    spellHit="HIT_SPELL",spellCrit="CRIT_SPELL",defense="DEFENSE_SKILL",dodge="DODGE",parry="PARRY",block="BLOCK",
    blockValue="BLOCK_VALUE",frost="SPELL_DAMAGE_DONE_FROST",fire="SPELL_DAMAGE_DONE_FIRE",shadow="SPELL_DAMAGE_DONE_SHADOW",
    nature="SPELL_DAMAGE_DONE_NATURE",arcane="SPELL_DAMAGE_DONE_ARCANE",holy="SPELL_DAMAGE_DONE_HOLY",
    healthRegen="HEALTH_REGENERATION",feralAttackPower="FERAL_ATTACK_POWER",spellPenetration="SPELL_PENETRATION"}
for _,school in ipairs({"FIRE","FROST","ARCANE","SHADOW","NATURE"}) do
    local key=school:lower().."Resistance"
    weightNames[key]=school.."_RESISTANCE"
    statKeys[key]={"RESISTANCE"..({FIRE=2,NATURE=3,FROST=4,SHADOW=5,ARCANE=6})[school].."_NAME", "ITEM_MOD_"..school.."_RESISTANCE_SHORT"}
end
statKeys.healthRegen={"ITEM_MOD_HEALTH_REGENERATION_SHORT"}
statKeys.feralAttackPower={"ITEM_MOD_FERAL_ATTACK_POWER_SHORT"}
statKeys.spellPenetration={"ITEM_MOD_SPELL_PENETRATION_SHORT"}
function G.Profile(class,level,tree,profileID)
    local profiles=A.Data.AdvisorGear[class]
    if not profiles or not number(level) or level<1 or level>60 then return end
    local id=profileID or (tree and (class=="DRUID" and tree==3 and 4 or tree)) or defaults[class]
    local source=profiles[id]
    if not source then return end
    local p={name=source.name,class=class,level=level,id=id,weights={}}
    local lowest
    for _,value in pairs(source.stats) do if value>0 then lowest=math.min(lowest or value,value) end end
    for key,name in pairs(weightNames) do p.weights[key]=source.stats[name] or 0 end
    p.weights.armor=source.stats.ARMOR or (lowest or 1)*0.1
    local dps=source.stats.DAMAGE_PER_SECOND or (lowest or 1)*0.1
    -- Apply the selected profile's weapon-DPS weight consistently. Silently
    -- zeroing it for a class or weapon slot changes the reference item score.
    p.weights.meleeDPS=dps
    p.weights.rangedDPS=dps
    p.weights.wandDPS=dps
    return p
end

function G:CurrentProfile()
    local _,class=UnitClass("player")
    local level=UnitLevel("player")
    if A.TalentAdvisor then
        local build,manual=A.TalentAdvisor:Build(class,level)
        if build then
            local profile=self.Profile(class,level,nil,build.profile)
            if profile then
                profile.buildID=build.id; profile.buildName=build.name
                profile.manual=manual; profile.fromBuild=true
                return self:ApplyWeights(profile)
            end
        end
    end
    local fallback=self.Profile(class,level)
    if fallback then fallback.fallback=true end
    return self:ApplyWeights(fallback)
end

-- Overrides belong to this character and scoring profile. Builds sharing a
-- profile share these edits; the bundled defaults remain untouched.
G.WeightFields={
    {"strength","Strength"},{"agility","Agility"},{"stamina","Stamina"},{"intellect","Intellect"},{"spirit","Spirit"},
    {"armor","Armor"},{"health","Health"},{"mana","Mana"},{"attackPower","Attack power"},{"rangedAttackPower","Ranged attack power"},
    {"meleeDPS","Melee weapon DPS"},{"rangedDPS","Ranged weapon DPS"},{"wandDPS","Wand DPS"},{"feralAttackPower","Feral attack power"},
    {"hit","Melee / ranged hit (%)"},{"crit","Melee / ranged crit (%)"},
    {"spellPower","Spell power"},{"healing","Healing power"},{"spellHit","Spell hit (%)"},{"spellCrit","Spell crit (%)"},
    {"mp5","Mana per 5 seconds"},{"healthRegen","Health regeneration"},{"spellPenetration","Spell penetration"},
    {"defense","Defense"},{"dodge","Dodge (%)"},{"parry","Parry (%)"},{"block","Block chance (%)"},{"blockValue","Block value"},
    {"frost","Frost damage"},{"fire","Fire damage"},{"shadow","Shadow damage"},{"nature","Nature damage"},{"arcane","Arcane damage"},{"holy","Holy damage"},
    {"fireResistance","Fire resistance"},{"frostResistance","Frost resistance"},{"shadowResistance","Shadow resistance"},
    {"natureResistance","Nature resistance"},{"arcaneResistance","Arcane resistance"},
}
function G:ApplyWeights(profile)
    if not profile then return end
    local saved=A.characterDB and A.characterDB.advisors
    local weights=saved and saved.statWeights and saved.statWeights[profile.class..":"..profile.id]
    if type(weights)=="table" then
        for key,value in pairs(weights) do
            if profile.weights[key]~=nil and number(value) and value<=1000000 then
                profile.weights[key]=value; profile.customWeights=true
            end
        end
    end
    return profile
end

function G:WeightsChanged()
    self.revision=self.revision+1
    if A.Readiness then A.Readiness:SuppliesChanged() end
    if A.GearBagAdvisor then A.GearBagAdvisor:Changed() end
    self:RefreshTooltips()
    if A.AuctionUpgrades then A.AuctionUpgrades:Invalidate() end
    if A.GearIndicators then A.GearIndicators:Invalidate() end
end

function G:SetWeight(profile,key,value)
    if not profile or not A.characterDB or not number(value) or value>1000000 then return false end
    local defaults=self.Profile(profile.class,profile.level,nil,profile.id)
    if not defaults or defaults.weights[key]==nil then return false end
    A.characterDB.advisors=A.characterDB.advisors or {}
    local saved=A.characterDB.advisors
    saved.statWeights=saved.statWeights or {}
    local id=profile.class..":"..profile.id
    local weights=saved.statWeights[id] or {}
    if value==defaults.weights[key] then weights[key]=nil else weights[key]=value end
    saved.statWeights[id]=next(weights) and weights or nil
    self:WeightsChanged()
    return true
end

function G:ResetWeights(profile)
    local saved=A.characterDB and A.characterDB.advisors
    if not profile or not saved or not saved.statWeights then return end
    saved.statWeights[profile.class..":"..profile.id]=nil
    self:WeightsChanged()
end

-- Private tooltip reads localized restriction colors and DPS when the API lacks it.
function G:Scan(link,inventorySlot,captureLines)
    if not self.scan then
        self.scan=CreateFrame("GameTooltip","HardcoreBuddyGearScan",UIParent,"GameTooltipTemplate")
    end
    local tip=self.scan
    tip:SetOwner(UIParent,"ANCHOR_NONE")
    tip:ClearLines()
    local ok
    if inventorySlot and tip.SetInventoryItem then ok=pcall(tip.SetInventoryItem,tip,"player",inventorySlot)
    else ok=pcall(tip.SetHyperlink,tip,link) end
    if not ok or tip:NumLines()==0 then tip:Hide(); return end
    if inventorySlot and tip.GetItem then
        local _,scannedLink=tip:GetItem()
        if itemID(scannedLink)~=itemID(link) then tip:Hide(); return end
    end
    local english=not GetLocale or GetLocale()=="enUS" or GetLocale()=="enGB"
    local result={stats={},baseStats={},spellEffectsComplete=english}
    local weaponLines={}
    local patterns,primaryComplete=statPatterns()
    local dpsTemplate=DPS_TEMPLATE
    local dpsPattern
    if type(dpsTemplate)=="string" then
        dpsPattern=dpsTemplate:gsub("%%[%d%.]*f","@NUMBER@"):gsub("%%d","@NUMBER@")
        dpsPattern="^"..dpsPattern:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])","%%%1"):gsub("@NUMBER@",function() return "([%d%.,]+)" end).."$"
    end
    for i=2,tip:NumLines() do
        for _,side in ipairs({"Left","Right"}) do
            local region=_G["HardcoreBuddyGearScanText"..side..i]
            if region and region:IsShown() then
                local r,g,b=region:GetTextColor()
                if r and g and b and r>0.8 and g<0.25 and b<0.25 and (region:GetText() or "")~="" then result.restricted=true end
            end
        end
        local line=_G["HardcoreBuddyGearScanTextLeft"..i]
        if line then
            local text=(line:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$")
            if text==RETRIEVING_ITEM_INFO or text==RETRIEVING_DATA then tip:Hide(); return end
            if parseBaseStats(text,patterns,result.baseStats) then result.baseParsed=primaryComplete end
            if english then
                local parsed=self.ParseEquip(text,result.stats)
                if text:match("^Equip:") and not parsed then result.spellEffectsComplete=false end
                if text:match("^Chance on hit:") then result.spellEffectsComplete=false end
                if text:match("^Use:") or text:match("^Set:") or text:match("^%(%d+%) Set:") then
                    result.useOrSetEffect=true
                end
            end
            local right=_G["HardcoreBuddyGearScanTextRight"..i]
            weaponLines[#weaponLines+1]={left=text,right=right and right:GetText() or ""}
            if text==ITEM_UNIQUE or text==ITEM_UNIQUE_EQUIPPABLE then result.unique=true end
            if dpsPattern then
                local value=text:match(dpsPattern)
                if value then result.dps=tonumber((value:gsub(",","."))) end
            end
        end
    end
    for _,line in ipairs(weaponLines) do
        local block=tonumber(line.left:match("^(%d+) Block$"))
        if block then result.shieldBaseBlock=block end
    end
    if captureLines then
        result.tooltipLines={}
        for i=1,tip:NumLines() do
            local row={}
            for _,side in ipairs({"Left","Right"}) do
                local region=_G["HardcoreBuddyGearScanText"..side..i]
                if region and region:IsShown() then
                    row[side:lower()]=region:GetText()
                    row[side:lower().."Color"]={region:GetTextColor()}
                end
            end
            result.tooltipLines[#result.tooltipLines+1]=row
        end
    end
    tip:Hide()
    return result
end

function G:Read(link,inventorySlot,allowUnscored)
    local id=itemID(link)
    local info,statsAPI=api("GetItemInfo"),api("GetItemStats")
    if not id or not info or not statsAPI then return nil,"Item data unavailable" end
    local name,_,_,_,required,_,_,_,equip,_,_,classID,subclassID=info(link)
    if not name or not equip or not classID or not subclassID then return nil,"Item data loading" end
    if (not slots[equip] and not (allowUnscored and equip=="INVTYPE_RELIC")) or (classID~=2 and classID~=4) then return nil,"unsupported" end
    -- Compare the items themselves. Armor kits occupy the same enhancement
    -- field as permanent enchants. Clear only that field, retaining random
    -- suffixes, unique IDs and every other part of the original item link.
    local scoreLink=link:gsub("(item:%d+:)%d+",function(prefix) return prefix.."0" end,1)
    local stats=statsAPI(scoreLink)
    if type(stats)~="table" then return nil,"Item stats loading" end
    -- An inventory tooltip would restore the applied enchant. Use the clean
    -- link instead when it differs; Equipped still validates the actual slot.
    local scanned=self:Scan(scoreLink,classID~=2 and scoreLink==link and inventorySlot or nil)
    if not scanned then return nil,"Item tooltip loading" end
    -- Copy the API table; callers or other addons may retain it.
    local merged={}
    for key,value in pairs(stats) do merged[key]=value end
    -- GetItemStats can omit or misreport Classic random-suffix attributes.
    -- Once the native stat block is readable, displayed primary values replace
    -- the API's primary values (including attributes absent from that block).
    if scanned.baseParsed then
        for _,entry in ipairs(primaryStats) do merged[entry[1]]=scanned.baseStats[entry[1]] or 0 end
    end
    -- Include school-damage suffixes as well as primary attributes. These are
    -- read from the enhancement-free item and replace, rather than add to, the
    -- corresponding API value.
    for key,value in pairs(scanned.baseStats) do merged[key]=value end
    if scanned.baseStats.RESISTANCE0_NAME~=nil then
        merged.RESISTANCE0_NAME=scanned.baseStats.RESISTANCE0_NAME
        merged.ITEM_MOD_ARMOR_SHORT=nil
    end
    for key,value in pairs(scanned.stats or {}) do
        -- Classic can return a different AP total from the displayed intrinsic
        -- Equip bonus (Assault Band: API 19, tooltip 20). Prefer that clean
        -- tooltip value for AP/RAP on both candidates and equipped items.
        if merged[key]==nil or key=="ITEM_MOD_ATTACK_POWER_SHORT" or key=="ITEM_MOD_RANGED_ATTACK_POWER_SHORT" then
            merged[key]=value
        end
    end
    local blockComplete
    if equip=="INVTYPE_SHIELD" then
        blockComplete=scanned.shieldBaseBlock~=nil and scanned.spellEffectsComplete
        if blockComplete then
            -- ItemStats may contain only the bonus, only the base, or neither.
            -- The clean tooltip gives the intrinsic base and explicit Equip bonus.
            merged.ITEM_MOD_BLOCK_VALUE_SHORT=scanned.shieldBaseBlock+(scanned.stats.ITEM_MOD_BLOCK_VALUE_SHORT or 0)
        end
    end
    return {id=id,link=link,name=name,required=required or 0,equip=equip,classID=classID,subclassID=subclassID,
        stats=merged,dps=scanned.dps or stats.ITEM_MOD_DAMAGE_PER_SECOND_SHORT,restricted=scanned.restricted,unique=scanned.unique,
        spellEffectsComplete=scanned.spellEffectsComplete,useOrSetEffect=scanned.useOrSetEffect,
        blockValueComplete=blockComplete}
end

function G.HighestArmorSubclass(p)
    local max=armorMax[p.class] or 1
    if p.level>=40 and (p.class=="WARRIOR" or p.class=="PALADIN" or p.class=="HUNTER" or p.class=="SHAMAN") then max=max+1 end
    return max
end

function G.Allowed(item,p)
    if item.required>p.level then return false,"Requires level "..item.required end
    if item.classID==2 then
        local allowed=false
        for _,id in ipairs(weaponTypes[p.class] or {}) do if id==item.subclassID then allowed=true end end
        if not allowed then return false,"Not usable by your class" end
    else
        local max=G.HighestArmorSubclass(p)
        if item.subclassID==6 then
            if p.class~="WARRIOR" and p.class~="PALADIN" and p.class~="SHAMAN" then return false,"Cannot use shields" end
        elseif item.subclassID>max then return false,"Armor type not available" end
    end
    if item.restricted then return false,"Requirements not met" end
    return true
end

-- Use the same normalized value for scoring and explaining stat tradeoffs.
function G.StatValue(item,p,key)
    if not item then return 0 end
    local value
    local function merge(amount)
        if amount~=nil then
            -- Some Classic items have real negative stats. Missing aliases
            -- must not zero those penalties, but NaN/infinity remain invalid.
            if type(amount)~="number" or amount~=amount or math.abs(amount)==math.huge then return false end
            value=value and math.max(value,amount) or amount
        end
        return true
    end
    for _,alias in ipairs(statKeys[key]) do
        if not merge(item.stats[alias]) then return nil end
    end
    if p.class=="HUNTER" and (key=="hit" or key=="crit") then
        local amount=item.stats[key=="hit" and "ITEM_MOD_HIT_RANGED_RATING_SHORT" or "ITEM_MOD_CRIT_RANGED_RATING_SHORT"]
        if not merge(amount) then return nil end
    end
    if key=="healing" then
        -- Generic Classic spell power also heals. Some clients return both
        -- keys for the same effect, so take the larger total rather than sum.
        for _,alias in ipairs(statKeys.spellPower) do
            if not merge(item.stats[alias]) then return nil end
        end
    end
    return value or 0
end

function G.Score(item,p,slot)
    if not item then return 0 end
    local score=0
    for key in pairs(statKeys) do
        local value=G.StatValue(item,p,key)
        if value==nil then return nil end
        score=score+value*(p.weights[key] or 0)
    end
    local dpsWeight=item.subclassID==19 and p.weights.wandDPS or slot==18 and p.weights.rangedDPS or p.weights.meleeDPS
    if item.classID==2 and (dpsWeight or 0)>0 then
        if not number(item.dps) then return nil end
        score=score+item.dps*dpsWeight
    end
    return score
end

local lossStats={
    {"strength","Str"},{"agility","Agi"},{"stamina","Sta"},{"intellect","Int"},{"spirit","Spi"},
    {"crit","Crit","%"},{"hit","Hit","%"},{"spellCrit","Spell crit","%"},{"spellHit","Spell hit","%"},
    {"attackPower","AP"},{"rangedAttackPower","RAP"},{"spellPower","Spell power"},{"healing","Healing"},
    {"mp5","MP5"},{"defense","Defense"},{"dodge","Dodge","%"},{"parry","Parry","%"},
    {"block","Block","%"},{"blockValue","Block value"},{"health","Health"},{"mana","Mana"},
    {"frost","Frost"},{"fire","Fire"},{"shadow","Shadow"},{"nature","Nature"},{"arcane","Arcane"},{"holy","Holy"},
    {"armor","Armor"},
}
local function statChangeSummary(item,p,replacedItems,allStats,compact,gains)
    local losses={}
    for i,entry in ipairs(lossStats) do
        local key=entry[1]
        if allStats or i<=5 or (p.weights[key] or 0)>0 then
            local candidate=G.StatValue(item,p,key)
            if candidate==nil then return end
            local previous=0
            for _,old in ipairs(replacedItems) do
                local amount=G.StatValue(old,p,key)
                if amount==nil then return end
                previous=previous+amount
            end
            local delta=candidate-previous
            if (gains and delta>0) or (not gains and delta<0) then
                losses[#losses+1]=string.format(gains and "+%g%s %s" or "%g%s %s",delta,entry[3] or "",entry[2])
            end
        end
    end
    if #losses>0 then
        if compact then
            local shown=math.min(3,#losses)
            while shown>1 and #table.concat(losses," / ",1,shown)>34 do shown=shown-1 end
            local text=table.concat(losses," / ",1,shown)
            return text..(shown<#losses and (" / +"..(#losses-shown).." more") or "")
        end
        return table.concat(losses," / ")
    end
end

function G:Equipped(slot)
    if not GetInventoryItemID or not GetInventoryItemLink then return nil,"Equipment data unavailable" end
    local id=GetInventoryItemID("player",slot)
    if not id or id==0 then return nil end
    local link=GetInventoryItemLink("player",slot)
    if itemID(link)~=id then return nil,"Equipped item data loading" end
    local item,reason=self:Read(link,slot)
    if GetInventoryItemLink("player",slot)~=link then return nil,"Equipped item data loading" end
    return item,reason
end

function G.CanDualWield(p)
    if p.cachedDualWield~=nil then return p.cachedDualWield end
    local dual=(p.class=="ROGUE" and p.level>=10) or ((p.class=="WARRIOR" or p.class=="HUNTER") and p.level>=20)
    if dual and IsSpellKnown then dual=IsSpellKnown(674) end
    return dual
end

function G.LossSummary(item,p,replacedItems,allStats,compact)
    return statChangeSummary(item,p,replacedItems,allStats,compact,false)
end

function G.GainSummary(item,p,replacedItems,allStats,compact)
    return statChangeSummary(item,p,replacedItems,allStats,compact,true)
end

function G:Comparisons(item,p,slotOnly,equipment)
    local function equippedAt(slot)
        if equipment then return equipment[slot] or nil end
        return self:Equipped(slot)
    end
    local candidates={}
    -- Slot, not armor subclass, chooses the baseline. Robes and chest armor
    -- both replace slot 5; stats decide the result across cloth/leather/mail/plate.
    for _,slot in ipairs(slots[item.equip]) do candidates[#candidates+1]=slot end
    local dual=self.CanDualWield(p)
    if item.equip=="INVTYPE_WEAPON" and dual then candidates[#candidates+1]=17 end
    local rows={}
    for _,slot in ipairs(candidates) do
        local row={label=slotNames[slot],slot=slot}
        rows[#rows+1]=row
        local equipped,reason=equippedAt(slot)
        local candidateScore=self.Score(item,p,slot)
        local oldScore=0
        if equipped then oldScore=self.Score(equipped,p,slot) end
        local replacedItems=equipped and {equipped} or {}
        if item.unique and #candidates==2 then
            local otherSlot=slot==candidates[1] and candidates[2] or candidates[1]
            local other,otherReason=equippedAt(otherSlot)
            reason=reason or otherReason
            if other and other.id==item.id then reason="Unique item in the other slot" end
        end
        if slot==17 then
            local main,mainReason=equippedAt(16)
            reason=reason or mainReason
            if main and main.equip=="INVTYPE_2HWEAPON" then reason="Needs a one-handed main hand" end
            if item.classID==2 and not dual then reason="Dual wield not available" end
        elseif item.equip=="INVTYPE_2HWEAPON" and not slotOnly then
            row.label="Both hands"
            local off,offReason=equippedAt(17)
            reason=reason or offReason
            if off then
                local offScore=self.Score(off,p,17)
                oldScore=oldScore and offScore and oldScore+offScore or nil
                replacedItems[#replacedItems+1]=off
            end
        end
        if reason or candidateScore==nil or oldScore==nil then
            row.text=reason or "Item stats incomplete"; row.status="unknown"
        elseif oldScore==0 then
            row.zeroBaseline=equipped~=nil
            row.status=candidateScore>0 and "up" or candidateScore<0 and "down" or "equal"
            row.text=candidateScore>0 and (not equipped and "Upgrade: empty slot" or "Upgrade: zero-score baseline")
                or candidateScore<0 and "Downgrade: zero-score baseline" or "No scored baseline"
        else
            -- Floor to two decimals, including negative changes, to match the
            -- reference display. This calculation has no external dependency.
            local delta=oldScore>0 and (candidateScore*100/oldScore-100) or ((candidateScore-oldScore)*100/math.abs(oldScore))
            row.percent=math.floor(delta*100)/100
            row.status=row.percent>0 and "up" or row.percent<0 and "down" or "equal"
            row.text=string.format(row.percent==0 and "%.2f%% Similar" or row.percent>0 and "+%.2f%% Upgrade" or "%.2f%% Downgrade",row.percent)
        end
        if row.status~="unknown" then
            row.losses=self.LossSummary(item,p,replacedItems,false,true)
            row.gains=self.GainSummary(item,p,replacedItems,false,true)
        end
    end
    return rows
end

function G:Report(link)
    local item,reason=self:Read(link)
    if reason=="unsupported" then return end
    local p=self:CurrentProfile()
    if not p then return end
    local rows
    if item then
        local allowed,why=self.Allowed(item,p)
        rows=allowed and self:Comparisons(item,p,true) or {{label="Unavailable",text=why,status="unknown"}}
        if allowed and item.equip=="INVTYPE_2HWEAPON" then
            local off,offReason=self:Equipped(17)
            if off or offReason then rows[2]=self:Comparisons(item,p)[1] end
        end
    else rows={{label="Comparison",text=reason,status="unknown"}} end
    return {profile=p,rows=rows,scoreModel="classic-weighted-v3"}
end

function G:Add(tip)
    if self.busy or not self:IsEnabled() or A.db.gearAdvisorEnabled==false or not tip.GetItem then return end
    local _,link=tip:GetItem()
    if not itemID(link) then return end
    self.busy=true
    local previous=tip.hardcoreBuddyGear
    local cached=previous and previous.link==link and previous.revision==self.revision and previous.report
    local ok,report=true,cached
    if not cached then ok,report=pcall(self.Report,self,link) end
    if not ok then
        self.busy=false
        if geterrorhandler then geterrorhandler()(report) end
        return
    end
    if report then
        local title="|TInterface\\AddOns\\HardcoreBuddy\\Media\\SurvivorShield.tga:16:16:0:0|t HardcoreBuddy  |  Gear Advisor"
        -- WoW collapses empty text; a space preserves the native blank line.
        local lines={{" ","",colors.equal},{title,"",colors.gold}}
        for _,row in ipairs(report.rows) do
            lines[#lines+1]={row.label,row.text,colors[row.status]}
            if row.gains then lines[#lines+1]={"Stats gained",row.gains,colors.up} end
            if row.losses then lines[#lines+1]={"Stats lost",row.losses,colors.down} end
            lines[#lines+1]={" ","",colors.equal}
        end
        local auctionLines=A.AuctionUpgrades and A.AuctionUpgrades:TooltipLines(tip,link)
        for _,line in ipairs(auctionLines or {}) do
            if line[1]~="" or line[2]~="" then lines[#lines+1]=line end
        end
        -- Separators belong between visible sections, never below the last row.
        while lines[#lines] and lines[#lines][1]==" " and lines[#lines][2]=="" do table.remove(lines) end
        local state=tip.hardcoreBuddyGear
        local name=tip.GetName and tip:GetName()
        local header=state and name and _G[name.."TextLeft"..(state.start+1)]
        local reuse=state and state.link==link and header and header:GetText()==title
        -- A structural change waits for the next native tooltip build. Never
        -- hide spare FontStrings or overwrite lines belonging to other addons.
        if reuse then
            if state.lineCount~=#lines then self.busy=false; return end
        end
        local changed=not reuse
        local start=reuse and state.start or tip:NumLines()+1
        for i,line in ipairs(lines) do
            local left=name and _G[name.."TextLeft"..(start+i-1)]
            local right=name and _G[name.."TextRight"..(start+i-1)]
            local color=line[3]
            local leftColor=line[2]~="" and colors.equal or color
            if reuse and left and right then
                if left:GetText()~=line[1] or (right:GetText() or "")~=line[2] then changed=true end
                left:SetText(line[1]); left:SetTextColor(unpack(leftColor)); left:Show()
                right:SetText(line[2]); right:SetTextColor(unpack(color)); right:SetShown(line[2]~="")
            elseif not reuse then
                if tip.AddDoubleLine then tip:AddDoubleLine(line[1],line[2],leftColor[1],leftColor[2],leftColor[3],color[1],color[2],color[3])
                else tip:AddLine(line[1]..(line[2]~="" and ("  "..line[2]) or ""),unpack(color)) end
            end
        end
        local cacheable=true
        for _,row in ipairs(report.rows) do if row.status=="unknown" then cacheable=false end end
        tip.hardcoreBuddyGear={link=link,start=start,revision=self.revision,report=cacheable and report or nil,
            lineCount=#lines}
        if changed and tip.Show then tip:Show() end
    end
    self.busy=false
end

function G:RefreshTooltips()
    for tip in pairs(self.tooltips) do
        if tip:IsShown() then
            if not self:IsEnabled() then
                -- Close the visible tooltip so disabled advice is not left on screen.
                if tip.hardcoreBuddyGear or tip.hardcoreBuddyAlt then tip:Hide() end
            elseif A.db.gearAdvisorEnabled==false then
                if tip.hardcoreBuddyGear then tip:Hide() end
            elseif tip.hardcoreBuddyGear then self:Add(tip) end
        end
    end
end

function G:RegisterTooltip(tip)
    if not tip or G.tooltips[tip] then return end
    G.tooltips[tip]=true
    if A.AltAdvisor then A.AltAdvisor.RegisterTooltip(tip) end
    if not tip.HasScript or tip:HasScript("OnTooltipSetItem") then
        tip:HookScript("OnTooltipSetItem",function(frame) frame.hardcoreBuddyGearPending=true end)
    end
    if hooksecurefunc then
        for _,method in ipairs({"SetBagItem","SetInventoryItem","SetHyperlink","SetMerchantItem","SetAuctionItem",
            "SetAuctionSellItem","SetLootItem","SetQuestItem","SetQuestLogItem","SetTradeSkillItem"}) do
            if type(tip[method])=="function" then hooksecurefunc(tip,method,function(frame)
                frame.hardcoreBuddyGearPending=nil; G:Add(frame)
            end) end
        end
    end
    tip:HookScript("OnUpdate",function(frame)
        if frame.hardcoreBuddyGearPending then frame.hardcoreBuddyGearPending=nil; G:Add(frame) end
    end)
    tip:HookScript("OnTooltipCleared",function(frame) frame.hardcoreBuddyGear=nil; frame.hardcoreBuddyGearPending=nil end)
    tip:HookScript("OnHide",function(frame) frame.hardcoreBuddyGearPending=nil end)
end
G:RegisterTooltip(GameTooltip); G:RegisterTooltip(ItemRefTooltip)
if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,function(tip)
        if G.tooltips[tip] then tip.hardcoreBuddyGearPending=true end
    end)
end
local events=CreateFrame("Frame"); G.events=events
for _,event in ipairs({"GET_ITEM_INFO_RECEIVED","PLAYER_EQUIPMENT_CHANGED","UNIT_LEVEL","UNIT_INVENTORY_CHANGED",
    "PLAYER_ENTERING_WORLD","CHARACTER_POINTS_CHANGED","PLAYER_TALENT_UPDATE","ACTIVE_TALENT_GROUP_CHANGED","SPELLS_CHANGED",
    "UPDATE_SHAPESHIFT_FORM","SKILL_LINES_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event,unit)
    if (event=="UNIT_LEVEL" or event=="UNIT_INVENTORY_CHANGED") and unit~="player" then return end
    G.revision=G.revision+1
    G:RefreshTooltips()
end)
