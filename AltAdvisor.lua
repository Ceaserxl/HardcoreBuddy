local _,A=...
local G=A.GearAdvisor
local Alt={}; A.AltAdvisor=Alt
local slots={1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18}
local function copy(t)
    if type(t)~="table" then return t end
    local out={}; for k,v in pairs(t) do out[k]=copy(v) end; return out
end
function Alt:Capture()
    if not A.db or not UnitGUID or not GetRealmName then return end
    local guid=UnitGUID("player"); local profile=G:CurrentProfile()
    if not guid or not profile then return end
    local equipment={}
    for _,slot in ipairs(slots) do
        local item,reason=G:Equipped(slot)
        if reason and reason~="unsupported" then return end
        equipment[slot]=item and copy(item) or false
    end
    profile=copy(profile); profile.cachedDualWield=G.CanDualWield(profile)
    A.db.altEquipment=A.db.altEquipment or {}
    A.db.altEquipment[guid]={schema=1,name=UnitName("player"),realm=GetRealmName(),
        faction=UnitFactionGroup("player"),profile=profile,equipment=equipment,
        updated=time and time() or 0}
    return true
end
local function clean(text) return (text or ""):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r",""):match("^%s*(.-)%s*$") end
function Alt:Transferable(tip,link)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    local bind=info and select(14,info(link))
    if bind~=0 and bind~=2 then return false end
    local name=tip.GetName and tip:GetName()
    if not name then return false end
    for i=1,tip:NumLines() do
        local region=_G[name.."TextLeft"..i]
        local text=region and clean(region:GetText())
        if text and (text==ITEM_SOULBOUND or text==ITEM_BIND_ON_PICKUP or text==ITEM_BIND_QUEST
            or text==ITEM_ACCOUNTBOUND or text==ITEM_BNETACCOUNTBOUND) then return false end
    end
    return true
end
-- Restriction colors describe the logged-in bank character. Ignore only its
-- class/weapon type and minimum-level colors; unknown requirements stay excluded.
function Alt:Candidate(link)
    local item=G:Read(link)
    if not item then return end
    local scan=G:Scan(link,nil,true)
    if not scan then return end
    local levelPattern=(ITEM_MIN_LEVEL or "Requires Level %d"):gsub("%%d","%%d+")
    -- Do not assume an offline character satisfies extra profession, reputation,
    -- race or class-list restrictions just because the bank character does.
    for _,line in ipairs(scan.tooltipLines or {}) do
        local text=clean(line.left)
        if (text:match("^Requires ") and not text:match("^"..levelPattern.."$"))
            or text:match("^Classes:") or text:match("^Races:") then return end
        for _,key in ipairs({"ITEM_REQ_SKILL","ITEM_REQ_REPUTATION","ITEM_CLASSES_ALLOWED","ITEM_RACES_ALLOWED"}) do
            local template=_G[key]
            local prefix=type(template)=="string" and template:match("^(.-)%%")
            if prefix and prefix~="" and text:sub(1,#prefix)==prefix
                and not text:match("^"..levelPattern.."$") then return end
        end
    end
    if item.restricted then
        local info=C_Item and C_Item.GetItemInfo or GetItemInfo
        local _,_,_,_,_,kind,subtype=info(link)
        for _,line in ipairs(scan and scan.tooltipLines or {}) do
            for _,side in ipairs({"left","right"}) do
                local color=line[side.."Color"]; local text=clean(line[side])
                if color and color[1]>.8 and color[2]<.25 and color[3]<.25 and text~=""
                    and text~=kind and text~=subtype and not text:match("^"..levelPattern.."$") then return end
            end
        end
        if not scan then return end
        item=copy(item); item.restricted=nil
    end
    return item
end
function Alt:Upgrades(item)
    local result={}
    local guid=UnitGUID and UnitGUID("player")
    local realm=GetRealmName and GetRealmName()
    local faction=UnitFactionGroup and UnitFactionGroup("player")
    for id,character in pairs(A.db.altEquipment or {}) do
        if id~=guid and character.schema==1 and character.realm==realm and character.faction==faction
            and G.Allowed(item,character.profile) then
            local best
            for _,row in ipairs(G:Comparisons(item,character.profile,nil,character.equipment)) do
                if row.status=="up" and (not best or (row.percent or math.huge)>(best.percent or math.huge)) then best=row end
            end
            if best then result[#result+1]={character=character,row=best} end
        end
    end
    table.sort(result,function(a,b)
        local ap,bp=a.row.percent or -math.huge,b.row.percent or -math.huge
        if ap~=bp then return ap>bp end
        return a.character.name<b.character.name
    end)
    return result
end
function Alt:IsStoredItem(tip,link)
    local location=tip.hardcoreBuddyAltLocation
    if not location then return false end
    if location.inventory then
        return GetInventoryItemLink and GetInventoryItemLink("player",location.inventory)==link
    end
    local bag=location.bag
    if type(bag)~="number" or (bag~=-1 and (bag<0 or bag>(NUM_BAG_SLOTS or 4)+(NUM_BANKBAGSLOTS or 7))) then return false end
    local getLink=C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
    if not getLink or getLink(bag,location.slot)~=link then return false end
    local info=C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerItemInfo(bag,location.slot)
    if info and info.isBound then return false end
    return true
end
function Alt:Add(tip)
    if self.busy or not A.db or A.db.altAdvisorEnabled==false or not G:IsEnabled() or tip.hardcoreBuddyAlt or not tip.GetItem then return end
    local _,link=tip:GetItem()
    if not link or not self:IsStoredItem(tip,link) or not self:Transferable(tip,link) then return end
    self.busy=true
    local ok,err=pcall(function()
        local item=self:Candidate(link); if not item then return end
        local upgrades=self:Upgrades(item); if #upgrades==0 then return end
        local lines={{"|TInterface\\AddOns\\HardcoreBuddy\\Media\\SurvivorShield.tga:16:16:0:0|t HardcoreBuddy  |  Alt Advisor","",{1,.8,.3}}}
        for _,entry in ipairs(upgrades) do
            local c,row=entry.character,entry.row
            lines[#lines+1]={c.name.." - Level "..c.profile.level,
                row.percent and string.format("+%.2f%%",row.percent) or (row.zeroBaseline and "Zero baseline" or "Empty slot"),{1,.82,.4},{.38,.84,.6}}
            lines[#lines+1]={row.label.." | "..c.profile.name,"",{.65,.65,.65}}
            lines[#lines+1]={" ","",{.65,.65,.65}}
        end
        G:Add(tip)
        if not tip.hardcoreBuddyGear then tip:AddLine(" ") end
        for _,line in ipairs(lines) do
            local leftColor,rightColor=line[3],line[4] or line[3]
            tip:AddDoubleLine(line[1],line[2],leftColor[1],leftColor[2],leftColor[3],rightColor[1],rightColor[2],rightColor[3])
        end
        tip.hardcoreBuddyAlt=true; tip:Show()
    end)
    self.busy=false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
function Alt:SetEnabled(enabled)
    A.db.altAdvisorEnabled=enabled
    for tip in pairs(G.tooltips) do if tip.hardcoreBuddyAlt then tip:Hide() end end
end
local function register(tip)
    if not tip or tip.hardcoreBuddyAltHook then return end
    tip.hardcoreBuddyAltHook=true
    if hooksecurefunc then
        if type(tip.SetBagItem)=="function" then
            hooksecurefunc(tip,"SetBagItem",function(t,bag,slot)
                t.hardcoreBuddyAltLocation={bag=bag,slot=slot}
                Alt:Add(t)
            end)
        end
        if type(tip.SetInventoryItem)=="function" then
            hooksecurefunc(tip,"SetInventoryItem",function(t,unit,slot)
                if unit~="player" or not BankButtonIDToInvSlotID then return end
                for index=1,(NUM_BANKGENERIC_SLOTS or 28) do
                    if BankButtonIDToInvSlotID(index)==slot then
                        t.hardcoreBuddyAltLocation={inventory=slot}
                        Alt:Add(t); return
                    end
                end
            end)
        end
    end
    tip:HookScript("OnTooltipCleared",function(t)
        t.hardcoreBuddyAlt=nil; t.hardcoreBuddyAltLocation=nil
    end)
    tip:HookScript("OnHide",function(t) t.hardcoreBuddyAltLocation=nil end)
end
Alt.RegisterTooltip=register
for tip in pairs(G.tooltips) do register(tip) end
local events=CreateFrame("Frame"); Alt.events=events
for _,event in ipairs({"PLAYER_ENTERING_WORLD","PLAYER_EQUIPMENT_CHANGED","PLAYER_LEVEL_UP","PLAYER_TALENT_UPDATE",
    "CHARACTER_POINTS_CHANGED","SPELLS_CHANGED","PLAYER_LOGOUT","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGOUT" then Alt:Capture(); return end
    if event~="GET_ITEM_INFO_RECEIVED" or Alt.pending then Alt.pending=.5; Alt.attempts=0 end
end)
events:SetScript("OnUpdate",function(_,elapsed)
    if not Alt.pending then return end
    Alt.pending=Alt.pending-elapsed; if Alt.pending>0 then return end
    Alt.pending=nil; Alt.attempts=(Alt.attempts or 0)+1
    if not Alt:Capture() and Alt.attempts<10 then Alt.pending=1 end
end)
