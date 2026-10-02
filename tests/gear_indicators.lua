local A,F=TestAddon,GEAR_FIXTURES
local I,G=A.GearIndicators,A.GearAdvisor
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
local function drain()
    local count=0
    while I.worker:GetScript("OnUpdate") do
        I:Step(); count=count+1; assert(count<100,"Indicator queue did not finish")
    end
end
local function marked(button)
    return button.hardcoreBuddyUpgrade and button.hardcoreBuddyUpgrade[1]:IsShown() or false
end
F.reset("HUNTER",40)
local old=F.item("INVTYPE_HEAD",{},4,3,{{"100 Armor"},{"+5 Agility"}})
local better=F.item("INVTYPE_HEAD",{},4,1,{{"20 Armor"},{"+20 Agility"}})
local worse=F.item("INVTYPE_HEAD",{},4,3,{{"100 Armor"},{"+1 Agility"}})
F.equip(1,old)
I:Invalidate()
check(I:IsUpgrade(better.link),"Lighter cloth upgrade is flagged for a Hunter")
check(not I:IsUpgrade(worse.link),"Downgrade is not flagged")
local zero=F.item("INVTYPE_HEAD",{},4,1,{})
F.equip(1,zero); I:Invalidate()
check(I:IsUpgrade(better.link) and not G:Comparisons(G:Read(better.link),G:CurrentProfile())[1].percent,
    "Positive score upgrades a zero-score item without inventing a percentage")
local penalty=F.item("INVTYPE_HEAD",{},4,1,{{"-5 Stamina"}})
F.equip(1,nil); I:Invalidate()
check(not I:IsUpgrade(penalty.link) and G:Comparisons(G:Read(penalty.link),G:CurrentProfile())[1].status=="down",
    "Negative-stat gear is not an upgrade over an empty slot")
F.equip(1,old); I:Invalidate()
local plate=F.item("INVTYPE_HEAD",{},4,4,{{"500 Armor"},{"+100 Agility"}})
check(not I:IsUpgrade(plate.link),"Unusable armor is not flagged")
better.loading=true; I:Invalidate()
check(not I:IsUpgrade(better.link),"Missing item cache never becomes an upgrade")
better.loading=false

-- Real native hooks run after Blizzard populates/reuses the item buttons.
local native=0
function ContainerFrame_Update() native=native+1 end
function ContainerFrame_GenerateFrame() native=native+1 end
function QuestInfo_ShowRewards() native=native+1 end
function hooksecurefunc(name,callback)
    local original=_G[name]
    _G[name]=function(...) original(...); callback(...) end
end
MOCK.FireAll("ADDON_LOADED","Blizzard_UIPanels_Game")
local bag=CreateFrame("Frame","ContainerFrame1",UIParent)
bag.size=8; bag.id=0; function bag:GetID() return self.id end
function bag:GetName() return self.name end
local links={}
C_Container=C_Container or {}
C_Container.GetContainerItemLink=function(id,slot) return id==0 and links[slot] end
for n=1,8 do
    local b=CreateFrame("Button","ContainerFrame1Item"..n,bag)
    b.id=n; function b:GetID() return self.id end
    function b:GetName() return self.name end
    b:SetSize(36,36); b:SetPoint("TOPLEFT",n*40,0)
    b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints()
    links[n]=better.link
end
local button=ContainerFrame1Item1
local click=function() native=native+100 end
button:SetScript("OnClick",click)
ContainerFrame_GenerateFrame(bag)
check(native==1 and #I.queue==8,"Bag opening discovers buttons without replacing Blizzard behavior")
I:Step(); check(#I.queue==4,"Large bags are processed in bounded batches")
drain(); check(marked(button) and #button.hardcoreBuddyUpgrade==10,"Upgrade has border and a three-part arrow")
for i=5,10 do
    local texture=button.hardcoreBuddyUpgrade[i]
    local _,relative,corner=texture:GetPoint(1)
    check(relative==button.icon and corner=="BOTTOMRIGHT","Arrow and its outline anchor inside the icon's bottom-right")
    check(texture.drawSubLevel==(i<=7 and 6 or 7),"Black arrow outline is below the green fill")
end
check(button:GetScript("OnClick")==click,"Item drag/click handlers remain untouched")
local read=G.Read; local reads=0
G.Read=function(self,...) reads=reads+1; return read(self,...) end
ContainerFrame_Update(bag); drain()
check(reads==0,"Repeated visible updates reuse scores")
G.Read=read
links[1]=worse.link; ContainerFrame_Update(bag)
check(not marked(button),"Recycled bag buttons clear their old highlight immediately")
links[1]=better.link; ContainerFrame_Update(bag); links[1]=nil; drain()
check(not marked(button),"Queued work reads the current slot, not the previous item")
links[1]=better.link; ContainerFrame_Update(bag); drain()
F.equip(1,better); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",1); drain()
check(not marked(button),"Equipping the upgrade removes obsolete bag markers")
F.equip(1,old); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",1); drain()
check(marked(button),"Equipment changes recompute scores")
button:Hide(); check(not marked(button),"Hidden/recycled buttons clear decorations")
button:Show(); drain(); check(marked(button),"Shown buttons are rescored")
A.db.gearUpgradeMarkers=false; I:Invalidate(); drain()
check(not marked(button),"Marker preference removes hints")
A.db.gearUpgradeMarkers=true; I:Invalidate(); drain()
check(marked(button),"Marker preference can be reenabled")

-- Replacement bags use native container-button setup without native frame names.
-- Discover the hook after load, then follow the live slot through pooled layouts.
local setups=0
function ContainerFrameItemButton_SetForceExtended() setups=setups+1 end
MOCK.FireAll("ADDON_LOADED","ReplacementBags")
MOCK.FireAll("ADDON_LOADED","UnrelatedAddon")
local customBag=CreateFrame("Frame",nil,UIParent)
customBag.id=0; function customBag:GetID() return self.id end
local custom=CreateFrame("Button",nil,customBag)
custom.id=1; function custom:GetID() return self.id end
function custom:GetName() return self.name end
custom.icon=custom:CreateTexture(nil,"ARTWORK"); custom.icon:SetAllPoints()
custom:SetScript("OnClick",click)
local watched=I.Watch; local watches=0
I.Watch=function(self,...) watches=watches+1; return watched(self,...) end
ContainerFrameItemButton_SetForceExtended(custom,false)
I.Watch=watched
check(setups==1 and watches==1,"Late-loaded native setup hook runs once and preserves original function")
drain()
check(marked(custom) and #custom.hardcoreBuddyUpgrade==10,"Unnamed replacement bag buttons get arrow and all border edges")
check(custom:GetScript("OnClick")==click,"Replacement bag clicks are preserved")
links[1]=worse.link; ContainerFrameItemButton_SetForceExtended(custom,false)
check(not marked(custom),"Sorting clears a previous item's marker before the queued pass")
drain(); check(not marked(custom),"Replacement bag downgrade stays unmarked")
links[1]=better.link; ContainerFrameItemButton_SetForceExtended(custom,false)
custom.id=2; links[2]=worse.link; drain()
check(not marked(custom),"Queued replacement bag work follows the final slot after sorting")
custom.id=1; ContainerFrameItemButton_SetForceExtended(custom,false); drain()
check(marked(custom),"Moving an upgrade into the button restores its marker")
local bank=CreateFrame("Frame",nil,UIParent)
function bank:GetID() return -1 end
custom:SetParent(bank); I:Invalidate(); drain()
check(not marked(custom),"Reparented buttons cannot score stale backpack slots while in the bank")
custom:SetParent(customBag); custom.id=0; ContainerFrameItemButton_SetForceExtended(custom,false); drain()
check(not marked(custom),"Unassigned pooled slots are not scored")
custom.id=1; ContainerFrameItemButton_SetForceExtended(custom,false); drain()
custom:Hide(); check(not marked(custom),"Releasing replacement bag buttons hides their decorations")
custom:Show(); drain(); check(marked(custom),"Reopening replacement bags restores markers")
better.loading=true; MOCK.FireAll("GET_ITEM_INFO_RECEIVED",better.id,false); drain()
check(not marked(custom),"Uncached replacement bag gear has no false marker")
better.loading=false; MOCK.FireAll("GET_ITEM_INFO_RECEIVED",better.id,true); drain()
check(marked(custom),"Late item data restores replacement bag markers")
A.db.gearUpgradeMarkers=false; I:Invalidate(); drain()
check(not marked(custom),"Marker toggle also applies to replacement bags")
A.db.gearUpgradeMarkers=true
F.equip(1,better); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",1); drain()
check(not marked(custom),"Equipping better gear refreshes replacement bag comparisons")
F.equip(1,old); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",1); drain()
check(marked(custom),"Equipment changes restore eligible replacement bag upgrades")
G:SetEnabled(false); drain()
check(not marked(custom) and not marked(button),"Gear master switch clears native and replacement bag markers")
check(A.db.gearUpgradeMarkers==true,"Master disable preserves marker preference")
G:SetEnabled(true); drain()
check(marked(custom) and marked(button),"Reenabling gear advice restores eligible bag markers")

local rewards=CreateFrame("Frame","QuestInfoRewardsFrame",UIParent); rewards.RewardButtons={}
QuestInfoFrame={rewardsFrame=rewards,questLog=false}
local choices={better.link,worse.link}
GetQuestItemLink=function(kind,index) assert(kind=="choice"); return choices[index] end
GetQuestLogItemLink=function(kind,index) assert(kind=="choice"); return choices[index] end
for n=1,2 do
    local b=CreateFrame("Button",nil,rewards); b.id=n
    function b:GetID() return self.id end
    function b:GetName() return self.name end
    b.type="choice"; b.objectType="item"
    b.Icon=b:CreateTexture(nil,"ARTWORK"); b.Icon:SetSize(36,36); b.Icon:SetPoint("LEFT",0,0)
    rewards.RewardButtons[n]=b
end
QuestInfo_ShowRewards(); drain()
check(marked(rewards.RewardButtons[1]) and not marked(rewards.RewardButtons[2]),"Quest choices use the same upgrade decisions as bags")
QuestInfoFrame.questLog=true; QuestInfo_ShowRewards(); drain()
check(marked(rewards.RewardButtons[1]),"Quest-log choices use quest-log links")
rewards.RewardButtons[1].objectType="currency"; QuestInfo_ShowRewards(); drain()
check(not marked(rewards.RewardButtons[1]),"Pooled reward buttons do not retain markers on currency")
rewards.RewardButtons[1].objectType="item"; choices[1]=nil; QuestInfo_ShowRewards(); drain()
check(not marked(rewards.RewardButtons[1]),"Missing quest reward link stays unmarked")
choices[1]=better.link; MOCK.FireAll("GET_ITEM_INFO_RECEIVED",better.id,true); drain()
check(marked(rewards.RewardButtons[1]),"Late quest item data refreshes hints")

local ring=F.item("INVTYPE_FINGER",{},4,0,{{"+10 Agility"},{"Unique"}})
F.equip(11,ring); F.equip(12,nil); I:Invalidate()
check(not I:IsUpgrade(ring.link),"Unique ring in the other slot cannot create an upgrade")
local main=F.item("INVTYPE_WEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},2,7,{{"+15 Agility"}})
local off=F.item("INVTYPE_WEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},2,7,{{"+15 Agility"}})
local two=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_DAMAGE_PER_SECOND_SHORT=10},2,10,{{"+20 Agility"}})
F.equip(16,main); F.equip(17,off); I:Invalidate()
check(G:Comparisons(G:Read(two.link),G:CurrentProfile(),true)[1].status=="up","Fixture beats only the main hand")
check(not I:IsUpgrade(two.link),"Two-handed marker includes both replaced hands")
F.equip(17,nil); I:Invalidate()
check(I:IsUpgrade(two.link),"Two-handed upgrade is shown when it beats the complete equipped setup")
F.reset("WARLOCK",40); A.db.profile.mode="live"
local stamina=F.item("INVTYPE_HEAD",{},4,1,{{"+17 Stamina"}})
local shadow=F.item("INVTYPE_HEAD",{},4,1,{{"+10 Shadow Spell Damage"}})
F.equip(1,stamina); links[1]=shadow.link
I:Invalidate(); ContainerFrame_Update(bag); drain()
check(not marked(button) and G:CurrentProfile().name=="Demonology","Default build sets the initial marker decision")
A:OpenSettings("Talent Advisor")
MOCK.Click(A.Settings.pages["Talent Advisor"].builds[2]); drain()
check(G:CurrentProfile().name=="Affliction" and marked(button),"Selecting a different build invalidates cached scores and repaints bags")
check(A.state.filter=="Talent Advisor" and A.Settings.pages["Talent Advisor"].builds[2].selected,
    "Selected build remains highlighted in Talent Advisor settings")
MOCK.Click(A.Settings.pages["Talent Advisor"].builds[1]); drain()
check(G:CurrentProfile().name=="Demonology" and not marked(button),"Automatic build restores the original score and removes the marker")
print("PASS: "..checks.." gear indicator checks; native/replacement bags, queued rendering, pooled buttons, cache invalidation, equipment and quest choices.")
