local A,F=TestAddon,GEAR_FIXTURES
local G,I=A.GearAdvisor,A.GearIndicators
local count=0
local function check(value,why) count=count+1; assert(value,why) end
F.reset("HUNTER",40); A.db.profile.mode="live"
local original=G:CurrentProfile()
local keys={}
for _,entry in ipairs(G.WeightFields) do
    check(not keys[entry[1]] and original.weights[entry[1]]~=nil,"Editor exposes a valid, unique weight")
    keys[entry[1]]=true
end
for key in pairs(original.weights) do check(keys[key],"Every scoring weight can be edited") end
local old=F.item("INVTYPE_HEAD",{},4,1,{{"+20 Stamina"}})
local candidate=F.item("INVTYPE_HEAD",{},4,1,{{"+20 Agility"}})
F.equip(1,old); I:Invalidate()
check(I:IsUpgrade(candidate.link),"Candidate begins as an upgrade")
local signature=A.AuctionCache:Signature(original)
function GameTooltip:GetOwner() return self.owner end
A.AuctionUpgrades.profile=original
A:OpenSettings("Gear Advisor")
local gear=A.Settings.pages["Gear Advisor"]
MOCK.Click(gear.openWeights)
local fields={}; for _,edit in ipairs(gear.weights) do fields[edit.weightKey]=edit end
check(gear.profile:GetText()=="Scoring: Beast Mastery","Scoring line has no build label")
local _,scoringY=gear.profile:GetRect()
local _,controlsY=gear.enabled:GetRect()
check(scoringY<controlsY,"Scoring appears above description controls")
local edit=fields.agility
local revision=G.revision
edit:SetFocus(); edit:SetText("0"); edit.scripts.OnEnterPressed(edit)
check(G:CurrentProfile().weights.agility==0 and G.revision>revision,"Enter saves a zero weight and invalidates scores")
check(not I:IsUpgrade(candidate.link) and G:Report(candidate.link).rows[1].status=="down","Markers and tooltip use the edited score")
check(A.AuctionCache:Signature(G:CurrentProfile())~=signature and A.AuctionUpgrades.stale,"Auction results become stale after weight changes")
check(G.Profile("HUNTER",40,nil,original.id).weights.agility==original.weights.agility,"Bundled defaults remain unchanged")
edit:SetFocus(); edit:SetText("1.375"); edit.scripts.OnEnterPressed(edit)
check(G:CurrentProfile().weights.agility==1.375,"Decimal weights are retained")
for _,bad in ipairs({"-1","bad","1000001",""}) do
    edit:SetFocus(); edit:SetText(bad); edit.scripts.OnEnterPressed(edit)
    check(G:CurrentProfile().weights.agility==1.375 and edit:GetText()=="1.375","Invalid input restores the saved value")
end
check(not G:SetWeight(original,"agility",math.huge) and not G:SetWeight(original,"agility",0/0),"Non-finite weights are rejected")
check(not G:SetWeight(original,"notAStat",2),"Unknown weight keys are rejected")
edit:SetFocus(); edit:SetText("20"); edit.scripts.OnEscapePressed(edit)
check(G:CurrentProfile().weights.agility==1.375,"Escape cancels a pending edit")
fields.stamina:SetFocus(); fields.stamina:SetText("0.75")
MOCK.Click(A.window.back)
check(G:CurrentProfile().weights.stamina==0.75 and not A.state.gearPage,"Back commits pending edits and returns to Gear Advisor")

local other=G.Profile("WARLOCK",40,nil,1)
G:SetWeight(other,"shadow",0.123)
check(G:CurrentProfile().weights.agility==1.375 and G:ApplyWeights(G.Profile("WARLOCK",40,nil,1)).weights.shadow==0.123,
    "Profiles have separate overrides")
check(G:ApplyWeights(G.Profile("WARLOCK",40,nil,2)).weights.shadow~=0.123,"Other builds' scoring profiles retain defaults")
local saved=A.characterDB
A.characterDB={}
check(G:CurrentProfile().weights.agility==original.weights.agility,"Overrides do not leak into another character")
A.characterDB=saved
A:OpenSettings("Gear Advisor")
MOCK.Click(gear.openWeights)
edit:SetFocus(); edit:SetText("99"); MOCK.Click(gear.restore)
check(G:CurrentProfile().weights.agility==original.weights.agility and G:CurrentProfile().weights.stamina==original.weights.stamina,
    "Restore Defaults clears all active-profile edits, including a pending edit")
check(not G:CurrentProfile().customWeights and I:IsUpgrade(candidate.link),"Reset refreshes upgrade markers")
check(G:ApplyWeights(G.Profile("WARLOCK",40,nil,1)).weights.shadow==0.123,"Reset preserves other profiles' overrides")
G:SetWeight(original,"agility",original.weights.agility)
check(not A.characterDB.advisors.statWeights["HUNTER:"..original.id],"Entering a default removes its override")
G:SetWeight(original,"agility",1.375)
local function literal(value)
    if type(value)=="table" then
        local parts={"{"}
        for key,v in pairs(value) do parts[#parts+1]="["..literal(key).."]="..literal(v).."," end
        parts[#parts+1]="}"; return table.concat(parts)
    elseif type(value)=="string" then return string.format("%q",value)
    else return tostring(value) end
end
WEIGHT_SAVED_FIXTURE=literal(A.characterDB.advisors.statWeights)
G:ResetWeights(original)
print("PASS: "..count.." stat-weight checks; complete editor, decimals, invalid input, scoring/marker/cache updates, profile isolation and defaults.")
