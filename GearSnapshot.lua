local addonName,A=...
local S={schema=2}; A.GearSnapshot=S
local G,Skin=A.GearAdvisor,A.Skin
local slotNames={[0]="Ammo","Head","Neck","Shoulders","Shirt","Chest","Waist","Legs","Feet",
    "Wrists","Hands","Ring 1","Ring 2","Trinket 1","Trinket 2","Back","Main hand","Off hand","Ranged","Tabard"}

-- SavedVariables must contain independent, serializable values, never native
-- frames or shared API tables that later item/talent updates can mutate.
local function copy(value)
    if type(value)=="table" then
        local result={}
        for k,v in pairs(value) do
            if type(k)=="number" or type(k)=="string" then result[k]=copy(v) end
        end
        return result
    elseif type(value)=="string" or type(value)=="boolean" then return value
    elseif type(value)=="number" and value==value and math.abs(value)<math.huge then return value end
end
local function api(name) return C_Item and C_Item[name] or _G[name] end
local function inCombat() return InCombatLockdown and InCombatLockdown() end

function S:ReadTalents()
    local trees={}
    for tab=1,3 do
        local tree={index=tab,talents={}}
        local modern=C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
        if modern then
            local id,name,_,_,_,_,points=modern(tab,false,false)
            tree.id,tree.name,tree.points=id,name,points
        elseif GetTalentTabInfo then
            local first,second,third,_,fifth=GetTalentTabInfo(tab,false,false)
            if type(first)=="string" then tree.name,tree.points=first,third
            else tree.id,tree.name,tree.points=first,second,fifth end
        end
        local count=GetNumTalents and GetNumTalents(tab,false,false)
        if type(count)=="number" then
            for index=1,math.min(count,50) do
                local info
                if C_SpecializationInfo and C_SpecializationInfo.GetTalentInfo then
                    info=C_SpecializationInfo.GetTalentInfo({specializationIndex=tab,talentIndex=index,isInspect=false,isPet=false})
                elseif GetTalentInfo then
                    local name,icon,tier,column,rank,maxRank=GetTalentInfo(tab,index,false,false)
                    if name then info={name=name,icon=icon,tier=tier,column=column,rank=rank,maxRank=maxRank} end
                end
                tree.talents[index]=copy(info) or {unavailable=true}
            end
        else tree.detailsUnavailable=true end
        trees[tab]=tree
    end
    return trees
end

function S:ReadSlot(slot,profile)
    local row={slot=slot,slotName=slotNames[slot]}
    row.itemID=GetInventoryItemID("player",slot)
    row.link=GetInventoryItemLink("player",slot)
    if not row.itemID or row.itemID==0 then
        row.state=row.link and "unavailable" or "empty"
        return row
    end
    -- Classic can expose selected ammunition through slot 0's item ID while
    -- GetInventoryItemLink returns nil. Ammo has no suffix/enchant variant;
    -- scan its item ID link rather than waiting for a nonexistent slot link.
    -- Keep every other slot strict so missing random-suffix links stay unknown.
    if slot==0 and not row.link then
        row.link="item:"..row.itemID; row.linkSource="itemID"
    end
    if not row.link or tonumber(row.link:match("item:(%d+)"))~=row.itemID then
        row.state,row.reason="unavailable","Item link loading"; return row
    end
    row.enchantID=tonumber(row.link:match("item:%d+:(%d+)")) or 0
    if slot==0 then
        local countAPI=api("GetItemCount")
        if countAPI then
            local ok,count=pcall(countAPI,row.itemID,false,false,false)
            if ok and type(count)=="number" and count==count and count>=0 and count<math.huge then
                row.availableCount=count
            else row.countUnavailable=true end
        else row.countUnavailable=true end
    end
    local info,statsAPI=api("GetItemInfo"),api("GetItemStats")
    if info then
        local name,_,quality,level,required,_,_,_,equip,icon,_,classID,subclassID=info(row.link)
        row.name,row.quality,row.itemLevel,row.requiredLevel=name,quality,level,required
        row.equipLoc,row.icon,row.classID,row.subclassID=equip,icon,classID,subclassID
    end
    row.apiStats=statsAPI and copy(statsAPI(row.link))
    local scanSlot=slot
    if row.linkSource=="itemID" then scanSlot=nil end
    local scan=G:Scan(row.link,scanSlot,true)
    row.tooltipLines=scan and copy(scan.tooltipLines)
    local item,reason
    if slot==0 then reason="unsupported" -- saved for review; ammo has no gear score
    else item,reason=G:Equipped(slot) end
    row.advisor=copy(item)
    row.advisorReason=reason
    row.score=item and profile and G.Score(item,profile,slot) or nil
    row.scoreModel=row.score~=nil and "classic-weighted-v3" or nil
    if item and profile and row.score==nil then
        reason="Item stats incomplete"; row.advisorReason=reason
    end
    if not row.name then row.state,row.reason="unavailable","Item data loading"
    elseif not scan then row.state,row.reason="unavailable","Item tooltip loading"
    elseif reason and reason~="unsupported" then
        row.state,row.reason="unavailable",reason
    else row.state="saved" end
    return row
end

function S:Capture(quiet)
    if not A.characterDB or not GetInventoryItemID or not GetInventoryItemLink then
        self.message="Equipment data is not ready. Try again after loading."
        self:Refresh(); return nil,self.message
    end
    local profile,profileReason=G:CurrentProfile()
    local _,class=UnitClass("player")
    local stamp=GetServerTime and GetServerTime() or time()
    local snapshot={schema=self.schema,capturedAt=stamp,addonVersion=A.version,
        character={name=UnitName("player"),realm=GetRealmName(),guid=UnitGUID("player"),
            class=class,level=UnitLevel("player"),faction=UnitFactionGroup("player")},
        locale=GetLocale and GetLocale(),projectID=WOW_PROJECT_ID,
        profile=copy(profile),profileReason=profileReason,talents=self:ReadTalents(),
        scoring={enchantsIncluded=false,method="Classic weighted item stats"},slots={}}
    if GetBuildInfo then
        local version,build,buildDate,interface=GetBuildInfo()
        snapshot.client={version=version,build=build,date=buildDate,interface=interface}
    end
    for slot=0,19 do snapshot.slots[slot]=self:ReadSlot(slot,profile) end
    snapshot.savedCount,snapshot.unavailableCount,snapshot.emptyCount=0,0,0
    for slot=0,19 do
        local row=snapshot.slots[slot]
        local currentLink=GetInventoryItemLink("player",slot)
        local linkChanged=currentLink~=row.link
        if row.linkSource=="itemID" then
            linkChanged=currentLink~=nil and tonumber(currentLink:match("item:(%d+)"))~=row.itemID
        end
        if linkChanged or GetInventoryItemID("player",slot)~=row.itemID then
            row.state,row.reason="unavailable","Equipment changed during capture; snapshot again"
            row.advisor,row.score,row.scoreModel=nil,nil,nil
        end
        local key=row.state=="saved" and "savedCount" or row.state=="empty" and "emptyCount" or "unavailableCount"
        snapshot[key]=snapshot[key]+1
    end
    snapshot.complete=snapshot.unavailableCount==0 and profile~=nil
    -- Keep only the most recent manual snapshot for this character.
    A.characterDB.gearSnapshot=snapshot
    self.message=nil
    self:Refresh()
    if not quiet then A:Print("Gear snapshot captured. Use /reload or log out to save it for offline review."
        ..(snapshot.complete and "" or " Some data is unavailable; wait for it to load and snapshot again."))
    end
    return snapshot
end

local function label(parent,size,color)
    local text=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    text:SetFont(STANDARD_TEXT_FONT,size,""); text:SetTextColor(unpack(color or Skin.colors.white))
    text:SetJustifyH("LEFT"); text:SetJustifyV("TOP"); text:SetWordWrap(true)
    return text
end
local function button(parent,text,width,callback,name)
    local b=CreateFrame("Button",name,parent,"BackdropTemplate"); b:SetSize(width,28)
    b.label=label(b,12); b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE"); b.label:SetText(text)
    Skin.Button(b,"tab"); b:SetScript("OnClick",callback)
    b:SetScript("OnEnter",function() Skin.ButtonState(b,b.active,true,false) end)
    b:SetScript("OnLeave",function() Skin.ButtonState(b,b.active,false,false) end)
    return b
end

function S:ShowSavedTooltip(button)
    local row=button.snapshotRow
    if not row then return end
    GameTooltip:SetOwner(button,"ANCHOR_RIGHT"); GameTooltip:ClearLines()
    for _,line in ipairs(row.tooltipLines or {}) do
        local l,r=line.leftColor or {1,1,1},line.rightColor or {1,1,1}
        GameTooltip:AddDoubleLine(line.left or "",line.right or "",l[1],l[2],l[3],r[1],r[2],r[3])
    end
    if not row.tooltipLines then GameTooltip:AddLine(row.name or row.slotName,1,0.8,0.4) end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Saved snapshot | "..(row.reason or (row.state=="empty" and "Empty slot" or "Captured item tooltip")),0.65,0.65,0.56,true)
    GameTooltip:Show()
end

function S:Refresh()
    if not self.panel then return end
    local f=self.panel
    local snapshot=A.characterDB and A.characterDB.gearSnapshot
    f.capture:SetEnabled(A.characterDB~=nil)
    Skin.ButtonState(f.capture,false,false,false)
    if snapshot then
        local who=snapshot.character or {}
        f.summary:SetText((who.name or "Character").." | Level "..(who.level or "?").."\n"
            ..(snapshot.profile and snapshot.profile.name or "Talent data unavailable"))
        local stamp=date and date("%b %d, %H:%M",snapshot.capturedAt) or tostring(snapshot.capturedAt)
        f.status:SetText(self.message or (stamp.." | "..snapshot.savedCount.." items saved"
            ..(snapshot.complete and "" or "\nIncomplete data - snapshot again after loading.")))
        f.status:SetTextColor(unpack(snapshot.complete and Skin.colors.green or Skin.colors.amber))
    else
        f.summary:SetText("Save your equipped gear for offline review.")
        f.status:SetText(self.message or "No gear snapshot saved yet.")
        f.status:SetTextColor(unpack(Skin.colors.muted))
    end
    for slot=0,19 do
        local row=snapshot and snapshot.slots[slot]
        local b=f.rows[slot]
        b.snapshotRow=row; b:SetShown(row~=nil)
        if row then
            b.slot:SetText(row.slotName)
            b.item:SetText(row.state=="empty" and "Empty" or row.name or (row.itemID and "Item "..row.itemID) or "Loading")
            b.item:SetTextColor(unpack(row.state=="saved" and Skin.colors.white or row.state=="empty" and Skin.colors.muted or Skin.colors.amber))
            b.icon:SetTexture(row.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            b.icon:SetShown(row.state~="empty")
        end
    end
end

function S:Show()
    if inCombat() then A:Print("Open Gear Snapshot after combat."); return end
    if not self:Attach() then return end
    -- Opened from Advisors; keep the Character window's native tabs unchanged.
    CharacterFrame_ShowSubFrame("HardcoreBuddyGearSnapshotPanel")
    for i=1,CharacterFrame.numTabs or 0 do
        local tab=_G["CharacterFrameTab"..i]
        if tab and PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    end
    self.panel:Show()
    self:Refresh()
end

function S:Attach()
    if self.panel then return true end
    if not CharacterFrame or not CharacterFrame_ShowSubFrame or not hooksecurefunc or inCombat() then return false end
    local f=CreateFrame("Frame","HardcoreBuddyGearSnapshotPanel",CharacterFrame,"BackdropTemplate")
    self.panel=f; f:Hide(); f:EnableMouse(true)
    f:SetPoint("TOPLEFT",CharacterFrame,"TOPLEFT",14,-64)
    f:SetPoint("BOTTOMRIGHT",CharacterFrame,"BOTTOMRIGHT",-34,86)
    Skin.Paint(f,"card")
    -- Classic keeps most window artwork on PaperDollFrame, which is hidden
    -- on this page. Draw a plain backing on the Character frame itself, below
    -- its existing portrait, name and close button.
    self.chrome={}
    local function chrome(width,height,point,relativePoint,x,y,color)
        local t=CharacterFrame:CreateTexture(nil,"BACKGROUND",nil,-1)
        t:SetTexture("Interface\\Buttons\\WHITE8x8"); t:SetVertexColor(unpack(color))
        t:SetSize(width,height); t:SetPoint(point,CharacterFrame,relativePoint,x,y)
        t:Hide(); self.chrome[#self.chrome+1]=t
        return t
    end
    chrome(350,438,"TOPLEFT","TOPLEFT",3,-3,{0.025,0.030,0.035,1})
    chrome(350,1,"TOPLEFT","TOPLEFT",3,-3,{0.48,0.37,0.19,1})
    chrome(350,1,"TOPLEFT","TOPLEFT",3,-440,{0.48,0.37,0.19,1})
    chrome(1,438,"TOPLEFT","TOPLEFT",3,-3,{0.48,0.37,0.19,1})
    chrome(1,438,"TOPLEFT","TOPLEFT",352,-3,{0.48,0.37,0.19,1})
    f.title=label(f,16,Skin.colors.gold); f.title:SetPoint("TOPLEFT",12,-12); f.title:SetText("Gear Snapshot")
    f.summary=label(f,11,Skin.colors.muted); f.summary:SetPoint("TOPLEFT",12,-37); f.summary:SetSize(304,32)
    f.capture=button(f,"Snapshot Current Gear",300,function() self:Capture() end)
    f.capture:SetPoint("TOPLEFT",12,-76)
    f.status=label(f,11); f.status:SetPoint("TOPLEFT",12,-111); f.status:SetSize(304,32)
    f.scroll=CreateFrame("ScrollFrame","HardcoreBuddySnapshotScroll",f,"UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT",12,-148); f.scroll:SetPoint("BOTTOMRIGHT",-30,54)
    f.content=CreateFrame("Frame",nil,f.scroll); f.content:SetSize(286,20*30)
    f.scroll:SetScrollChild(f.content); f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel",function(scroll,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*60)))
    end)
    f.rows={}
    for slot=0,19 do
        local row=CreateFrame("Button",nil,f.content,"BackdropTemplate"); f.rows[slot]=row
        row:SetSize(286,28); row:SetPoint("TOPLEFT",0,-slot*30)
        Skin.Paint(row,"row"); row:SetBackdropColor(slot%2==0 and 0.045 or 0.065,0.055,0.065,1)
        row.slot=label(row,10,Skin.colors.muted); row.slot:SetPoint("LEFT",4,0); row.slot:SetSize(67,24); row.slot:SetJustifyV("MIDDLE")
        row.icon=row:CreateTexture(nil,"ARTWORK"); row.icon:SetSize(24,24); row.icon:SetPoint("LEFT",74,0)
        row.item=label(row,11); row.item:SetPoint("LEFT",104,0); row.item:SetSize(178,24); row.item:SetJustifyV("MIDDLE"); row.item:SetWordWrap(false)
        row:SetScript("OnEnter",function() self:ShowSavedTooltip(row) end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    f.hint=label(f,11,Skin.colors.gold); f.hint:SetPoint("BOTTOMLEFT",12,12); f.hint:SetSize(300,32)
    f.hint:SetText("Use /reload or log out to write the snapshot to disk for offline review.")
    f:SetScript("OnShow",function()
        for _,part in ipairs(self.chrome) do part:Show() end
    end)
    f:SetScript("OnHide",function()
        for _,part in ipairs(self.chrome) do part:Hide() end
        GameTooltip:Hide()
    end)
    hooksecurefunc("CharacterFrame_ShowSubFrame",function(name)
        if name~="HardcoreBuddyGearSnapshotPanel" then f:Hide() end
    end)
    self:Refresh()
    return true
end
