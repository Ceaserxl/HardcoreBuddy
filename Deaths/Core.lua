local _, addon = ...
local H = addon.Deaths
H.MEDIA = "Interface\\AddOns\\HardcoreBuddy\\Media\\Deaths\\"
H.channel = "hcdeathalertschannel"
H.channelPassword = "hcdeathalertschannelpw"
H.defaults = {
    scale = 1, mini = true, alerts = true, sound = true, locked = false,
    community = false, minAlertLevel = 1, alertDuration = 3, volume = 70, alertSound = "RaidWarning",
}
H.soundChoices={
    {id="RaidWarning",name="Original (Deathlog default)"},
    {id="DeathBell",name="Custom bell"},
    {id="HeroFallen",name="Hero Fallen"},
    {id="Arugal",name="Arugal"},
    {id="Dread_Hunger",name="Dread Hunger"},
    {id="hunger_games",name="Hunger Games"},
    {id="golfclap",name="Golf Clap"},
}
function H.NormalizeAlertSound(value)
    for index,entry in ipairs(H.soundChoices) do if value==entry.id then return entry.id,index end end
    return "RaidWarning",1
end
function H:PlayAlertSound()
    if self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
    local s=self.db.settings
    if not s.sound then return end
    local sound=self.NormalizeAlertSound(s.alertSound)
    if sound=="RaidWarning" then
        -- The original native sound is also Deathlog's default (kit 8959).
        -- Native sound kits use WoW's channel volume, not our file gain slider.
        if PlaySound then
            local _,handle=PlaySound((SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959,"Master")
            self.soundHandle=handle
        end
        return
    end
    if s.volume<=0 or not PlaySoundFile then return end
    local path=sound=="DeathBell" and (self.MEDIA.."DeathBell"..s.volume..".wav")
        or (self.MEDIA.."Deathlog\\"..sound..s.volume..".ogg")
    local _,handle=PlaySoundFile(path,"Master")
    self.soundHandle=handle
end
function H.NormalizeAlertDuration(value)
    local seconds=tonumber(value)
    if not seconds or seconds~=seconds or math.abs(seconds)==math.huge then seconds=3 end
    return math.max(1,math.min(30,math.floor(seconds)))
end
function H:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffc9a76aHardcoreBuddy|r: " .. tostring(message))
end
function H:UpdateAnnouncementReplacement()
    local frame = RaidWarningFrame
    if not frame or not self.db then return end
    if self.db.settings.alerts and self.nativeSupported then
        -- Only take over this one event. Do not hide the shared frame, clear
        -- its text slots, or intercept raid warnings and boss emotes.
        if frame:IsEventRegistered("HARDCORE_DEATHS") then
            self.originalDeathFrame = frame
            frame:UnregisterEvent("HARDCORE_DEATHS")
        end
    elseif self.originalDeathFrame then
        self.originalDeathFrame:RegisterEvent("HARDCORE_DEATHS")
        self.originalDeathFrame = nil
    end
end
function H:Initialize()
    if self.db then return end
    self.useLegacySettings = type(addon.db.deaths) ~= "table"
    addon.db.deaths = type(addon.db.deaths) == "table" and addon.db.deaths or {}
    self.db = addon.db.deaths
    self.db.records = self.db.records or {}
    self.db.watch = nil -- Retire saved player-watching preferences.
    self.db.settings = self.db.settings or {}
    -- Replace the mistaken bell default once, preserving later explicit choices.
    if self.db.settings.soundVersion~=3 then
        local settings=self.db.settings
        if settings.alertSound=="DeathBell" or
            (settings.alertSound=="HeroFallen" and settings.soundVersion~=2) then
            settings.alertSound="RaidWarning"
        end
        settings.soundVersion=3
    end
    for key, value in pairs(self.defaults) do
        if self.db.settings[key] == nil then self.db.settings[key] = value end
    end
    self.db.settings.scale = math.max(0.7, math.min(1.5, tonumber(self.db.settings.scale) or 1))
    self.db.version = 1
    self.realm = GetRealmName()
    self:BuildUI()
    self:ApplySettings()
    self:Refresh()
    self:MigrateStandalone()
    if addon.window then addon:Refresh() end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
function H:MigrateStandalone()
    local legacy = HardcoreDeathsDB
    if not self.db or self.db.importedHardcoreDeaths or type(legacy) ~= "table" then return end
    if self.useLegacySettings then
        for key in pairs(self.defaults) do
            if type(legacy.settings) == "table" and legacy.settings[key] ~= nil then
                self.db.settings[key] = copy(legacy.settings[key])
            end
        end
        if type(legacy.positions) == "table" then self.db.positions = copy(legacy.positions) end
        self.db.settings.scale = math.max(0.7, math.min(1.5, tonumber(self.db.settings.scale) or 1))
    end
    for _, record in ipairs(type(legacy.records) == "table" and legacy.records or {}) do
        if type(record) == "table" and type(record.date) == "number" then
            self.Insert(self.db.records, copy(record), self.MAX_RECORDS)
        end
    end
    self.db.importedHardcoreDeaths = true
    self.useLegacySettings = false
    self:ApplySettings()
    self:Print("HardcoreDeaths history imported. Death features now run in HardcoreBuddy.")
end
function H:Add(record, silent, nativeAlert)
    if not self.db then return end
    local added, current = self.Insert(self.db.records, record, self.MAX_RECORDS)
    self:Refresh()
    -- A chat report can precede its native warning. Deduplicate storage and
    -- alert delivery separately so the native warning still gets one alert.
    self.alertedRecords = self.alertedRecords or setmetatable({}, { __mode = "k" })
    if current and (added or nativeAlert) and not self.alertedRecords[current]
        and not silent and self.db.settings.alerts
        and (current.level or 0) >= self.db.settings.minAlertLevel then
        self.alertedRecords[current] = true
        self:ShowAlert(current)
    end
    return added, current
end
function H:ClassText(record)
    if record.classID and GetClassInfo then
        local name, token = GetClassInfo(record.classID)
        return name or "--", token
    end
    return "--"
end
function H:Cause(record)
    local environment = { [-2]="Drowning", [-3]="Falling", [-4]="Fatigue", [-5]="Fire", [-6]="Lava", [-7]="Slime" }
    local cause = record.cause or environment[record.npcID]
        or (record.npcID and record.npcID > 0 and ("NPC #" .. record.npcID)) or "Not reported"
    return (cause:gsub("^[Aa]n?%s+", ""))
end
function H:Age(timestamp)
    local seconds = math.max(0, time() - timestamp)
    if seconds < 60 then return "Now"
    elseif seconds < 3600 then return math.floor(seconds / 60) .. "m ago"
    elseif seconds < 86400 then return math.floor(seconds / 3600) .. "h ago"
    else return math.floor(seconds / 86400) .. "d ago" end
end
function H:JoinCommunity()
    if not self.db.settings.community then return end
    if GetChannelName(self.channel) == 0 then
        JoinChannelByName(self.channel, self.channelPassword)
    end
end
function H:ImportLegacy()
    if self.importing then self:Print("Import already in progress."); return end
    if type(deathlog_data) ~= "table" then
        self:Print("No loaded Deathlog history. Enable Deathlog alongside HardcoreBuddy for one login, then /hcb deaths import.")
        return
    end
    self.importing = true
    local count, checked = 0, 0
    local worker = coroutine.create(function()
        local staged = {}
        for realm, records in pairs(deathlog_data) do
            if type(records) == "table" and type(realm) == "string" then
                for _, old in pairs(records) do
                    if type(old) == "table" and type(old.name) == "string" and tonumber(old.date) then
                        local zone = old.map_id and _G.id_to_area and _G.id_to_area[old.map_id]
                        local cause = old.source_id and _G.id_to_npc and _G.id_to_npc[old.source_id]
                        staged[#staged + 1] = {
                            name = self.Clean(old.name, 80), realm = self.Clean(realm, 80),
                            date = tonumber(old.date), level = tonumber(old.level),
                            classID = tonumber(old.class_id), npcID = tonumber(old.source_id),
                            guild = self.Clean(old.guild, 80), zone = zone and self.Clean(zone),
                            cause = cause and self.Clean(cause), source = "Imported",
                            message = self.Clean(old.last_words, 600),
                        }
                    end
                    checked = checked + 1
                    if checked % 1000 == 0 then
                        table.sort(staged, function(a,b) return a.date > b.date end)
                        for i = #staged, self.MAX_RECORDS + 1, -1 do staged[i] = nil end
                    end
                    if checked % 100 == 0 then coroutine.yield() end
                end
            end
        end
        table.sort(staged, function(a,b) return a.date < b.date end)
        for i = math.max(1, #staged - self.MAX_RECORDS + 1), #staged do
            if self.Insert(self.db.records, staged[i], self.MAX_RECORDS) then count = count + 1 end
            if i % 5 == 0 then coroutine.yield() end
        end
        table.sort(self.db.records, function(a,b) return a.date < b.date end)
    end)
    local function step()
        local ok, err = coroutine.resume(worker)
        if not ok then self.importing = false; self:Print("Import stopped: " .. tostring(err)); return end
        if coroutine.status(worker) == "dead" then
            self.importing = false
            self:Refresh()
            self:Print("Imported " .. count .. " reports. History is now saved in HardcoreBuddyDB; Deathlog may be disabled.")
        else C_Timer.After(0.05, step) end
    end
    step()
end
function H:PreviewAlert()
    -- History is chronological. Prefer the newest report for the current realm,
    -- then any saved report, and use an example only when history is empty.
    local record = self.db.records[#self.db.records]
    for i = #self.db.records, 1, -1 do
        if self.db.records[i].realm == self.realm then record = self.db.records[i]; break end
    end
    self:ShowAlert(record or { name = "Preview Adventurer", level = 42, zone = "Preview only",
        cause = "Example encounter", realm = self.realm, date = time(), source = "Preview" }, true)
end
function H:Slash(message)
    local command = (message or ""):match("^(%S*)")
    command = command:lower()
    if command == "settings" then addon:OpenDeaths("Options")
    elseif command == "mini" then self.db.settings.mini = not self.db.settings.mini; self:ApplySettings()
    elseif command == "lock" then self.db.settings.locked = not self.db.settings.locked; self:ApplySettings()
    elseif command == "import" then self:ImportLegacy()
    elseif command == "test" then self:PreviewAlert()
    elseif command == "resetposition" then
        self.db.positions = {}; self:ApplySettings()
    elseif command == "" then addon:OpenDeaths()
    else self:Print("/hcb deaths | settings | mini | lock | import | test | resetposition") end
end
