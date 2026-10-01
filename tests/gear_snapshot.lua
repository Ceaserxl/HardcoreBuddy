local A,F=TestAddon,GEAR_FIXTURES
local S,G=A.GearSnapshot,A.GearAdvisor
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
local function close(a,b) return a and math.abs(a-b)<0.00001 end

-- The snapshot subpage needs no Character window and opens from Gear settings.
local function openSnapshot()
    A:OpenSettings("Gear Advisor")
    MOCK.Click(A.Settings.pages["Gear Advisor"].openSnapshot)
end
check(not S.panel,"Loading the addon does not require CharacterFrame")
CharacterFrame=nil
openSnapshot()
local panel=S.panel
check(panel and panel.parent==A.Settings.pages["Gear Snapshot"],"Snapshot panel belongs to Gear Advisor settings")
check(A.state.view=="settings" and A.state.filter=="Gear Advisor" and panel:IsVisible(),"Gear settings display snapshot controls")
check(not panel.scroll and not HardcoreBuddyCharacterTab,"No Character tab or nested snapshot scroll frame")
check(not A.characterDB.gearSnapshot,"Opening settings never captures automatically")
local emptyHeight=A.Settings.content:GetHeight()
A:OpenSettings("General")
check(not panel:IsVisible(),"Leaving Gear settings hides the snapshot section")
openSnapshot()
check(S.panel==panel,"Returning to settings reuses the snapshot controls")
CharacterFrame=CreateFrame("Frame","CharacterFrame",UIParent)
CharacterFrame:SetSize(384,512); CharacterFrame:SetPoint("TOPLEFT",50,-100)
local nativeCalls=0
CharacterFrame_ShowSubFrame=function() nativeCalls=nativeCalls+1 end
CharacterFrameTab_OnClick=function() nativeCalls=nativeCalls+1 end
ToggleCharacter=function() nativeCalls=nativeCalls+1 end
openSnapshot()
check(nativeCalls==0 and not S.tab and not S.chrome,"Settings never change native Character navigation or artwork")

F.reset("HUNTER",40,{31,0,0})
A.db.gearAdvisorEnabled=false
A.db.profile.mode="preview"; A.db.profile.characterClass="Mage"; A.db.profile.level=60
GetBuildInfo=function() return "1.15.9","12345","Sep 30 2026",11509 end
GetNumTalents=function() return 2 end
local originalTalents={talentID=123,name="Fixture talent",rank=5,maxRank=5,tier=1,column=1}
C_SpecializationInfo={
    GetSpecializationInfo=function(index,inspect,pet)
        assert(inspect==false and pet==false)
        return index,"Tree "..index,"description",123,"DAMAGER",2,index==1 and 31 or 0
    end,
    GetTalentInfo=function(query)
        assert(query.isPet==false and query.isInspect==false)
        return query.specializationIndex==1 and query.talentIndex==1 and originalTalents or {name="Unspent talent",rank=0,maxRank=5}
    end,
}
local gloves=F.item("INVTYPE_HAND",{RESISTANCE0_NAME=171,ITEM_MOD_CRIT_RATING_SHORT=1},4,3,
    {{"Hands","Mail"},{"171 Armor"},{"+7 Stamina"},{"+6 Spirit"},{"Equip: Improves your chance to get a critical strike by 1%."}})
gloves.name="Dragonscale Gauntlets"
local enchanted=F.withEnchant(gloves,1843,{RESISTANCE0_NAME=211,ITEM_MOD_CRIT_RATING_SHORT=1},
    {{"Hands","Mail"},{"171 Armor"},{"+7 Stamina"},{"+6 Spirit"},{"Reinforced Armor +40"},{"Equip: Improves your chance to get a critical strike by 1%."}})
local suffix=F.item("INVTYPE_SHOULDER",{ITEM_MOD_AGILITY_SHORT=1},4,3,{{"184 Armor"},{"+8 Agility"},{"+9 Intellect"}})
suffix.name="Brigade Pauldrons of the Falcon"
F.equip(10,enchanted); F.equip(3,suffix)
F.equip(4,F.item("INVTYPE_BODY",{},4,0,{{"Shirt"}}))
local ammo=F.item("INVTYPE_AMMO",{},6,2,{{"Ammo"}})
F.equip(0,ammo)
MOCK.Click(panel.capture)
local snapshot=A.characterDB.gearSnapshot
check(snapshot and snapshot.schema==2 and snapshot==HardcoreBuddyCharacterDB.gearSnapshot,"Button stores snapshot in per-character SavedVariables")
check(snapshot.complete and snapshot.savedCount==4 and snapshot.emptyCount==16 and snapshot.unavailableCount==0,"All 20 slots represented, including ammo/shirt and empty slots")
check(snapshot.character.class=="HUNTER" and snapshot.character.level==40 and snapshot.profile.name=="Beast Mastery","Live character captured despite preview profile and disabled advisor")
check(snapshot.character.name=="Tester" and snapshot.character.realm=="Realm" and snapshot.client.interface==11509,"Capture includes identity, build, locale and timestamp context")
check(snapshot.slots[10].link==enchanted.link and snapshot.slots[10].enchantID==1843,"Original enchanted item link preserved")
check(snapshot.slots[10].apiStats.RESISTANCE0_NAME==211 and snapshot.slots[10].advisor.stats.RESISTANCE0_NAME==171,"Raw API and enchant-free advisor values kept separately")
check(close(snapshot.slots[10].score,11.155) and close(snapshot.slots[3].score,16.12),"Offline item scores reproduce exact source fixtures")
check(snapshot.slots[10].scoreModel=="classic-weighted-v3","Saved item scores identify the same stat model as the compact advisor")
check(snapshot.slots[3].advisor.stats.ITEM_MOD_AGILITY_SHORT==8 and snapshot.slots[3].link:find(":-15:",1,true),"Random suffix identity and corrected native stats preserved")
check(snapshot.slots[10].tooltipLines[2].right=="Mail" and snapshot.slots[10].tooltipLines[6].left=="Reinforced Armor +40","Both original tooltip columns and applied enchant text preserved")
check(snapshot.slots[4].advisorReason=="unsupported" and snapshot.slots[4].score==nil,"Unscored cosmetic item saved without a fabricated score")
check(snapshot.talents[1].points==31 and snapshot.talents[1].talents[1].rank==5,"Talent points and individual ranks preserved")
check(panel.rows[10].snapshotRow==snapshot.slots[10],"Page shows saved data")
panel.rows[10].scripts.OnEnter(panel.rows[10])
check(GameTooltip.lines[6][1]=="Reinforced Armor +40","Hover uses captured tooltip instead of reading current gear")
local before=snapshot.slots[10].advisor.stats.ITEM_MOD_STAMINA_SHORT
enchanted.stats.RESISTANCE0_NAME=9999; originalTalents.rank=0; gloves.lines[3][1]="+99 Stamina"
F.equip(10,nil); MOCK.FireAll("PLAYER_EQUIPMENT_CHANGED",10)
check(snapshot.slots[10].apiStats.RESISTANCE0_NAME==211 and snapshot.slots[10].advisor.stats.ITEM_MOD_STAMINA_SHORT==before and snapshot.talents[1].talents[1].rank==5,"Saved values never mutate with live APIs, equipment or talent changes")
check(A.characterDB.gearSnapshot==snapshot,"Gear changes do not overwrite a manual snapshot")

-- Save a trusted Lua fixture for a fresh runtime with no WoW APIs at all.
local function literal(v)
    if type(v)=="table" then
        local out={"{"}
        for k,value in pairs(v) do out[#out+1]="["..literal(k).."]="..literal(value).."," end
        out[#out+1]="}"; return table.concat(out)
    elseif type(v)=="string" then return string.format("%q",v)
    else return tostring(v) end
end
SNAPSHOT_SAVED_FIXTURE="HardcoreBuddyCharacterDB="..literal(A.characterDB)

-- Live Classic snapshot: slot 0 supplies an item ID but no hyperlink. Only
-- ammunition may use an ID fallback; suffix-bearing gear must retain links.
F.alias("item:"..ammo.id,ammo)
local inventoryLink=GetInventoryItemLink
GetInventoryItemLink=function(unit,slot)
    if slot~=0 then return inventoryLink(unit,slot) end
end
local originalCount=C_Item.GetItemCount
C_Item.GetItemCount=function(id,bank,charges)
    assert(id==ammo.id and bank==false and charges==false,"Ammo count excludes bank and charges")
    return 600
end
local withAmmo=S:Capture()
check(withAmmo.slots[0].availableCount==600,"Snapshot captures ammunition available in bags")
C_Item.GetItemCount=function() return 0 end
check(S:Capture().slots[0].availableCount==0,"Known empty ammo supply is preserved")
C_Item.GetItemCount=function() error("Unavailable") end
check(S:Capture().slots[0].countUnavailable and S:Capture().slots[0].availableCount==nil,"Failed ammunition API never becomes zero ammo")
C_Item.GetItemCount=originalCount
check(withAmmo.complete and withAmmo.slots[0].state=="saved" and withAmmo.slots[0].linkSource=="itemID","Ammo ID without a native link no longer makes snapshots incomplete")
check(withAmmo.slots[0].link=="item:"..ammo.id and withAmmo.slots[0].score==nil and withAmmo.slots[0].tooltipLines[2].left=="Ammo","Ammo ID fallback saves tooltip without inventing a gear score")
GetInventoryItemLink=function(unit,slot)
    if slot~=0 and slot~=3 then return inventoryLink(unit,slot) end
end
check(S:Capture().slots[3].reason=="Item link loading","Other equipment never substitutes a bare ID for a missing suffix link")
GetInventoryItemLink=function(unit,slot)
    if slot~=0 then return inventoryLink(unit,slot) end
end
ammo.loading=true
check(not S:Capture().complete and A.characterDB.gearSnapshot.slots[0].state=="unavailable","Uncached ammo remains explicitly unavailable")
ammo.loading=false
local realInfo=C_Item.GetItemInfo
C_Item.GetItemInfo=function(link)
    if link=="item:"..ammo.id then F.equip(0,nil) end
    return realInfo(link)
end
local ammoChanged=S:Capture()
check(not ammoChanged.complete and ammoChanged.slots[0].reason:find("changed during capture",1,true),"Ammo change during fallback read is still detected")
C_Item.GetItemInfo=realInfo; GetInventoryItemLink=inventoryLink; F.equip(0,ammo)

-- Missing cache data stays explicitly partial; a later click replaces it.
suffix.loading=true
local partial=S:Capture()
check(not partial.complete and partial.unavailableCount==1 and partial.slots[3].state=="unavailable","Uncached item marked incomplete instead of silently dropped")
check(partial~=snapshot and close(snapshot.slots[10].score,11.155),"A new capture replaces the saved record without modifying prior snapshot data")
suffix.loading=false
local complete=S:Capture()
check(complete.complete and complete.slots[10].state=="empty","Manual recapture reflects newly empty equipment slots")
F.equip(18,F.item("INVTYPE_RANGED",{},2,2,{{"Ranged weapon"}}))
local missingDPS=S:Capture()
check(not missingDPS.complete and missingDPS.slots[18].advisorReason=="Item stats incomplete" and missingDPS.slots[18].score==nil,"Missing weapon DPS stays explicitly unavailable in saved scoring data")
F.equip(18,nil); A.characterDB.gearSnapshot=complete
local savedLinkAPI=GetInventoryItemLink
GetInventoryItemLink=nil
check(S:Capture()==nil and A.characterDB.gearSnapshot==complete,"Missing inventory APIs cannot erase previous snapshot")
GetInventoryItemLink=savedLinkAPI
local originalGetInfo=C_Item.GetItemInfo
C_Item.GetItemInfo=function(link)
    if link==suffix.link then F.equip(3,nil) end
    return originalGetInfo(link)
end
local changed=S:Capture()
check(not changed.complete and changed.slots[3].reason:find("changed during capture",1,true),"Mid-capture gear changes produce a partial snapshot")
C_Item.GetItemInfo=originalGetInfo

-- Profile or character changes must not leak another character's snapshot.
local characterDB=A.characterDB
A.characterDB={}; S:Refresh()
check(panel.status:GetText()=="No gear snapshot saved yet." and not panel.rows[10]:IsShown(),"Characters without a snapshot do not see another character's gear")
A.characterDB=characterDB; A.characterDB.gearSnapshot=snapshot; S.message=nil; S:Refresh()
openSnapshot()
local scroll=A.Settings.scroll
check(A.Settings.range>0 and A.Settings.content:GetHeight()>emptyHeight,"Saved equipment extends the settings scroll instead of adding a separate menu")
scroll:SetVerticalScroll(A.Settings.range)
local _,lastY,_,lastH=panel.rows[19]:GetRect()
local _,scrollY,_,scrollH=scroll:GetRect()
check(lastY>=scrollY and lastY+lastH<=scrollY+scrollH,"Last equipment row reachable without paging")
scroll:SetVerticalScroll(0)
print("PASS: "..checks.." snapshot checks; manual capture, unenchanted scores, immutable raw data, Gear settings integration, partial data and continuous scrolling.")
