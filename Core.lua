local addonName, addon = ...

addon.name = addonName
addon.version = "0.6.5"
local P = addon.Planner
local classNames = {}
for _, name in ipairs(P.classes) do classNames[name:upper()] = name end
local function validLevel(level)
    return type(level) == "number" and level >= 1 and level <= 60 and level == math.floor(level)
end

function addon:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd69b46HardcoreBuddy:|r " .. tostring(message))
end

function addon:ShowKitUpdate(level, changes)
    if self.db.kitNotifications==false then return end
    local summary=table.concat(changes, ", ")
    self:Print("Field Kit updated for level "..level..": "..summary..". Open /hcb to review.")
    if not self.kitAlert then
        local frame=CreateFrame("Button",nil,UIParent)
        self.Skin.Hover(frame)
        frame:SetSize(350,48)
        frame:SetPoint("TOPRIGHT",UIParent,"TOPRIGHT",-48,-260)
        frame:SetFrameStrata("HIGH")
        frame:SetClampedToScreen(true)
        local function label(size,y,height)
            local text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlight")
            text:SetFont(STANDARD_TEXT_FONT,size,"")
            text:SetPoint("TOPLEFT",0,y); text:SetSize(350,height)
            text:SetJustifyH("LEFT")
            text:SetShadowColor(0,0,0,1); text:SetShadowOffset(1,-1)
            return text
        end
        frame.title=label(13,-4,19)
        frame.title:SetTextColor(unpack(self.Skin.colors.gold))
        frame.summary=label(11,-25,18)
        frame:SetScript("OnClick",function()
            self.db.profile.mode="live"
            self.state={view="supplies",filter="All",page=1}; self.history={}
            self:CreateWindow(); self.window:Show(); self:Refresh(true)
            frame:Hide()
        end)
        frame:SetScript("OnUpdate",function(_,elapsed)
            frame.elapsed=frame.elapsed+elapsed
            if frame.elapsed>=4.5 then frame:Hide()
            elseif frame.elapsed>4 then frame:SetAlpha(1-(frame.elapsed-4)/0.5) end
        end)
        self.kitAlert=frame
    end
    local frame=self.kitAlert
    frame.title:SetText("HardcoreBuddy: supply upgrades available")
    frame.summary:SetText("Level "..level.."  |  Click to review your field kit")
    frame.elapsed=0; frame:SetAlpha(1); frame:Show()
end

function addon:CheckLevelKit(level)
    if not validLevel(level) then return end
    local previous=self.kitLevel
    self.kitLevel=level
    if not validLevel(previous) or level<=previous then return end
    local context=self:GetContext()
    local _,token=UnitClass("player")
    if not classNames[token] then return end
    context.characterClass=classNames[token]; context.mode="live"
    context.level=previous; context.characterLevel=previous
    local before={}
    for _,row in ipairs(self.Supplies.Build(context)) do before[row.itemId]=true end
    context.level=level; context.characterLevel=level
    local changes={}
    for _,row in ipairs(self.Supplies.Build(context)) do
        if not before[row.itemId] then changes[#changes+1]=row.name end
    end
    if #changes>0 then self:ShowKitUpdate(level,changes) end
end

function addon:HandleSlashCommand(message)
    local text = (message or ""):match("^%s*(.-)%s*$")
    local command = text:lower()
    if command == "" then
        self:ToggleWindow()
    elseif command == "auction debug" then
        self.AuctionDiagnostics:Show()
    elseif command == "settings" then
        self:OpenSettings()
    elseif command == "health" then
        self:OpenSettings("Low Health")
    elseif command == "deaths" or command:match("^deaths%s") then
        if self.Deaths and self.Deaths.db then self.Deaths:Slash(text:match("^%S+%s*(.*)$")) end
    elseif command == "talents" or command == "advisor" or command == "gear" then
        self:CreateWindow(); self.window:Show(); self:Navigate("training")
        self.state.filter=command=="talents" and "Talents" or "Gear"; self:Refresh(true)
    elseif command == "gear on" or command == "gear off" then
        self.db.gearAdvisorEnabled=command=="gear on"
        self.GearAdvisor:SetEnabled(command=="gear on")
        self:Print("Gear advisor: "..(self.GearAdvisor:IsEnabled() and "on" or "off")..". /hcb gear on | /hcb gear off")
    elseif command == "help" then
        self:Print("/hcb: open guide | /hcb settings: all settings | /hcb reset: center window | /hcb health: low health settings | /hcb deaths: death journal | /hcb deaths settings: death settings | /hcb gear: gear advisor | /hcb talents: talent advisor")
        self:Print("/hcb auction debug: view and copy the latest skipped-listing report")
    elseif command == "reset" then
        self.db.window = {visible=true}
        self:CreateWindow()
        self:RestoreWindow()
        self.window:Show()
        self:Refresh(true)
    else
        self:Print("Use /hcb help for commands.")
    end
end

function addon:UserItemID(text)
    local value=tostring(text or ""):match("item:(%d+)") or tostring(text or ""):match("^%s*(%d+)%s*$")
    local id=tonumber(value)
    return id and id>=1 and id<=2147483647 and id or nil
end

function addon:UpdateUserItem(item)
    local getInfo=C_Item and C_Item.GetItemInfo or GetItemInfo
    if not getInfo then return end
    local name,_,_,_,level=getInfo(item.itemId)
    if name then item.name=name; item.level=level or 1; item.short="Custom item" end
end

function addon:EditUserItem(text,remove)
    local id=self:UserItemID(text)
    if not id then return false,"Enter an item ID or paste an item link." end
    local items=self.characterDB.userItems
    for index,item in ipairs(items) do
        if item.itemId==id then
            if remove then table.remove(items,index); self:Refresh(); return true,"Item removed." end
            return false,"That item is already in your User list."
        end
    end
    if remove then return false,"That item is not in your User list." end
    local item={itemId=id,id="user-"..id,name="Item #"..id,level=1,family="user-"..id,
        group="User",classes={"All"},ease=0,userItem=true,short="Custom item",route="Added to your personal supply list."}
    self:UpdateUserItem(item)
    items[#items+1]=item
    self:Refresh()
    return true,"Item added. Set its Carry quantity below."
end

function addon:GetContext()
    local profile = self.db.profile
    local context = {characterClass=profile.characterClass, level=profile.level,
        detailed=profile.detailed, mode=profile.mode}
    local maxHealth=UnitHealthMax and UnitHealthMax("player")
    if type(maxHealth)=="number" and maxHealth>0 and maxHealth<math.huge then context.maxHealth=maxHealth end
    local characterLevel=self.levelOverride or UnitLevel("player")
    if validLevel(characterLevel) then context.characterLevel=characterLevel end
    local faction=type(UnitFactionGroup)=="function" and UnitFactionGroup("player") or nil
    context.faction=(faction=="Alliance" or faction=="Horde") and faction or nil
    context.factionUnknown=context.faction==nil
    if profile.mode == "live" then
        local _, token = UnitClass("player")
        local level = self.levelOverride or UnitLevel("player")
        if classNames[token] and validLevel(level) then
            context.characterClass, context.level = classNames[token], level
            if UnitExists("pet") then
                local petLevel = UnitLevel("pet")
                if validLevel(petLevel) then context.petLevel = petLevel end
            end
        else
            context.liveUnavailable = true
        end
    else
        -- Reference preview only. The UI explicitly labels this assumption.
        context.petLevel = profile.level
    end
    context.inventory = self.inventory or {available=false, counts={}}
    context.professions = self.professions
    context.targets = self.characterDB and self.characterDB.targets or {}
    context.refillThresholds = self.characterDB and self.characterDB.refillThresholds or {}
    context.ranks = self.characterDB and self.characterDB.ranks or {}
    context.userItems = self.characterDB and self.characterDB.userItems or {}
    context.priorities = self.characterDB and self.characterDB.priorities or {}
    context.supplyDefaults = self.characterDB and self.characterDB.supplyDefaults or {}
    context.previewAmmo = self.characterDB and self.characterDB.previewAmmo or "arrows"
    return context
end

function addon:TogglePreview()
    if self.CommitInputs then self:CommitInputs() end
    local profile=self.db.profile
    if profile.mode=="live" then
        if not self.db.previewInitialized then
            local context=self:GetContext()
            profile.characterClass,profile.level=context.characterClass,context.level
        end
        self.db.previewInitialized=true
        self:SetProfile("mode","preview")
    else self:SetProfile("mode","live") end
end

function addon:SetCarryTarget(itemId,value)
    if not self.characterDB or type(itemId)~="number" then return end
    if value=="" or value==nil then self.characterDB.targets[itemId]=nil
    else
        local n=tonumber(value)
        if not n or n~=n or math.abs(n)==math.huge then return end
        local limit=self.Ammunition and self.Ammunition.items[itemId] and 10000 or 200
        self.characterDB.targets[itemId]=self.Supplies.NormalizeTarget(n,limit)
    end
    self.characterDB.targets[tostring(itemId)]=nil
    for _,item in ipairs(self.Data.Items.items) do
        if item.itemId==itemId and P.grouped[item.family] and not self.Professions.autoFamilies[item.family] then
            self.characterDB.ranks[item.family]=itemId; break
        end
    end
    self.needsRefresh=true
    if self.Readiness then self.Readiness:SuppliesChanged() end
end

function addon:SetRefillThreshold(itemId,value)
    if not self.characterDB or type(itemId)~="number" then return end
    local limit=self.Ammunition and self.Ammunition.items[itemId] and 10000 or 200
    local number=value~="" and value~=nil and self.Supplies.NormalizeTarget(value,limit) or nil
    if value~="" and value~=nil and number==nil then return end
    self.characterDB.refillThresholds[itemId]=number
    self.characterDB.refillThresholds[tostring(itemId)]=nil
    self.needsRefresh=true
    if self.Readiness then self.Readiness:SuppliesChanged() end
end

function addon:CyclePriority(item)
    if not item then return end
    local values=self.Supplies.priorities
    local current=self.Supplies.Priority(self:GetContext(),item)
    -- Tier upgrades retain the family's preference; custom items have unique families.
    local key=item.family or item.itemId
    for i,value in ipairs(values) do
        if current==value then self.characterDB.priorities[key]=values[i%#values+1]; break end
    end
    if self.Readiness then self.Readiness:SuppliesChanged() end
    self:Refresh()
end

function addon:SelectSupplyRank(family,itemId)
    if P.grouped[family] and not self.Professions.autoFamilies[family] then self.characterDB.ranks[family]=itemId; self:Refresh() end
end

function addon:SetProfile(key, value)
    self.db.profile[key] = value
    self.db.profile = P.NormalizeProfile(self.db.profile)
    self:Refresh(true)
end

function addon:SetLevel(value)
    local level = tonumber(value)
    if not level or level ~= level then level = 1 end
    level = math.max(1, math.min(60, math.floor(level)))
    if self.window then self.window.level:SetText(tostring(level)) end
    self:SetProfile("level", level)
end

function addon:ConfirmReset()
    StaticPopupDialogs.HARDCOREBUDDY_RESET={
        text="Reset HardcoreBuddy? This deletes all account-wide settings and cached data, plus this character's saved data, and reloads the UI. Other characters' character-specific data cannot be cleared from this character.",
        button1="Reset & Reload",button2=CANCEL or "Cancel",timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function()
            -- Detach the saved roots. Logout callbacks retain only the old,
            -- unsaved tables, so they cannot restore caches during ReloadUI.
            -- Keep ReloadUI in this click callback, not a timer or OnUpdate.
            HardcoreBuddyDB=nil; HardcoreBuddyCharacterDB=nil
            ReloadUI()
        end,
    }
    StaticPopup_Show("HARDCOREBUDDY_RESET")
end

function addon:Initialize()
    if type(HardcoreBuddyDB) ~= "table" then
        HardcoreBuddyDB = {}
    end
    self.db = HardcoreBuddyDB
    if self.db.gearAdvisorEnabled==nil then self.db.gearAdvisorEnabled=true end
    if self.db.gearAdvisorActive==nil then self.db.gearAdvisorActive=true end
    if self.db.gearBagNotify==nil then self.db.gearBagNotify=false end
    if self.db.gearAutoEquip==nil then self.db.gearAutoEquip=false end
    if self.db.talentAdvisorEnabled==nil then self.db.talentAdvisorEnabled=true end
    if type(HardcoreBuddyCharacterDB)~="table" then HardcoreBuddyCharacterDB={} end
    self.characterDB=HardcoreBuddyCharacterDB
    if self.characterDB.enchantMode~="max" then self.characterDB.enchantMode="level" end
    if self.characterDB.auctionHighestArmorOnly==nil then self.characterDB.auctionHighestArmorOnly=true end
    if self.characterDB.auctionLevelRange==nil then self.characterDB.auctionLevelRange=10 end
    if self.characterDB.debugAutoReload==nil then self.characterDB.debugAutoReload=false end
    if type(self.characterDB.targets)~="table" then self.characterDB.targets={} end
    if type(self.characterDB.refillThresholds)~="table" then self.characterDB.refillThresholds={} end
    if type(self.characterDB.ranks)~="table" then self.characterDB.ranks={} end
    if type(self.characterDB.userItems)~="table" then self.characterDB.userItems={} end
    if type(self.characterDB.priorities)~="table" then self.characterDB.priorities={} end
    if type(self.characterDB.supplyDefaults)~="table" then self.characterDB.supplyDefaults={} end
    for _,item in ipairs(self.characterDB.userItems) do self:UpdateUserItem(item) end
    self.db.profile = P.NormalizeProfile(self.db.profile)
    -- Preserve saved preview choices before the first click or schema migration.
    if self.db.previewInitialized==nil then
        self.db.previewInitialized=self.db.profile.mode=="preview"
            or self.db.profile.characterClass~="Hunter" or self.db.profile.level~=1
    end
    -- Move existing installations off the old reference-preview default once.
    if self.db.schema ~= 2 then self.db.profile.mode = "live" end
    if type(self.db.window) ~= "table" then self.db.window = {} end
    self.db.schema = 2
    if self.db.companionUI ~= 5 then
        self.db.window.width, self.db.window.height = self.Skin.windowWidth, self.Skin.windowHeight
        self.db.companionUI = 5
    end
    self.inventory=self.Inventory.Read()
    self.professions=self.Professions.Read()
    self.kitLevel=UnitLevel("player")
    self:CreateMinimapButton()
    self.Settings:RegisterBlizzardOptions()

    SLASH_HARDCOREBUDDY1 = "/hcb"
    SLASH_HARDCOREBUDDY2 = "/hardcorebuddy"
    SlashCmdList.HARDCOREBUDDY = function(message)
        self:HandleSlashCommand(message)
    end
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE", "UNIT_PET", "UNIT_LEVEL", "UNIT_FACTION", "BAG_UPDATE_DELAYED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
        "PLAYER_EQUIPMENT_CHANGED", "UNIT_MAXHEALTH", "UNIT_INVENTORY_CHANGED", "PET_BAR_UPDATE", "SKILL_LINES_CHANGED", "SPELLS_CHANGED", "TRADE_SKILL_UPDATE", "TRADE_SKILL_SHOW", "GET_ITEM_INFO_RECEIVED"}) do
        self.events:RegisterEvent(event)
    end
    if self.db.window.visible then self:CreateWindow(); self.window:Show(); self:Refresh() end
end

local events = CreateFrame("Frame")
addon.events = events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg, success)
    if event == "ADDON_LOADED" and arg == addonName then
        self:UnregisterEvent("ADDON_LOADED")
        addon:Initialize()
    elseif addon.db then
        if event=="PLAYER_ENTERING_WORLD" or event=="BAG_UPDATE_DELAYED" or event=="PLAYER_EQUIPMENT_CHANGED"
            or event=="GET_ITEM_INFO_RECEIVED" or event=="UNIT_INVENTORY_CHANGED" and arg=="player" then
            addon.Ammunition.RefreshCapacity()
        end
        if event=="GET_ITEM_INFO_RECEIVED" then
            addon.needsRefresh=true
            for _,item in ipairs(addon.characterDB.userItems) do
                if item.itemId==arg then
                    if success==false then item.short="Item information unavailable. Check the item ID."
                    else addon:UpdateUserItem(item) end
                    addon.needsRefresh=true
                end
            end
            return
        end
        if event=="SKILL_LINES_CHANGED" and addon.Professions.reading then return end
        local professionEvent=event=="SKILL_LINES_CHANGED" or event=="SPELLS_CHANGED"
            or event=="TRADE_SKILL_UPDATE" or event=="TRADE_SKILL_SHOW"
        if professionEvent or event=="PLAYER_ENTERING_WORLD" then addon.professions=addon.Professions.Read() end
        if event=="BAG_UPDATE_DELAYED" or event=="PLAYER_ENTERING_WORLD" then addon.inventory=addon.Inventory.Read() end
        if event == "UNIT_PET" and arg ~= "player" then return end
        if event == "UNIT_LEVEL" and arg ~= "pet" and arg ~= "player" then return end
        if event == "UNIT_FACTION" and arg ~= "player" then return end
        if event == "UNIT_INVENTORY_CHANGED" and arg ~= "player" then return end
        if event == "UNIT_MAXHEALTH" and arg ~= "player" then return end
        if event == "PLAYER_XP_UPDATE" and arg ~= "player" then return end
        if event == "PLAYER_LEVEL_UP" and validLevel(arg) then
            addon.levelOverride = arg
            addon:CheckLevelKit(arg)
        end
        if event == "PLAYER_ENTERING_WORLD" then addon.kitLevel=UnitLevel("player") end
        if event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_XP_UPDATE" and UnitLevel("player") >= (addon.levelOverride or 0)) then addon.levelOverride = nil end
        if (event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") and addon.window then addon:RestoreWindow() end
        if addon.minimap and (event == "PLAYER_ENTERING_WORLD" or event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") then addon:PositionMinimapButton() end
        if addon.window and addon.window:IsShown() and (addon.db.profile.mode == "live" or event=="UNIT_MAXHEALTH" or event=="BAG_UPDATE_DELAYED" or professionEvent or event=="PLAYER_ENTERING_WORLD" or event=="ZONE_CHANGED_NEW_AREA" or event=="UNIT_FACTION"
            or event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED") then addon:Refresh() end
    end
end)
