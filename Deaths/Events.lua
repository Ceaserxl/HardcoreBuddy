local addonName = ...
local _, addon = ...
local H = addon.Deaths
local frame = CreateFrame("Frame")
H.events = frame
local lastDamage, lastDamageTime, lastWords, lastWordsTime
local senderTimes = {}
-- The official chat feed is independent of the player's raid-warning filter.
local deathChannels = {
    enUS = "HardcoreDeaths", enGB = "HardcoreDeaths", ptBR = "MortesHardcore",
    esMX = "MuertesEnExtremo", esES = "MuertesHardcore", deDE = "HardcoreTode",
    frFR = "Morts", ruRU = "ГероическиеСмерти", koKR = "하드코어",
    zhCN = "专家死亡", zhTW = "專家模式玩家死亡",
}
local officialChannel = deathChannels[GetLocale and GetLocale() or "enUS"] or deathChannels.enUS
local function receive(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... == "HardcoreDeaths" then
            if H.db then H:MigrateStandalone() end
            return
        end
        if ... ~= addonName then return end
        if not addon.db then addon:Initialize() end
        H:Initialize()
        H.nativeSupported = pcall(frame.RegisterEvent, frame, "HARDCORE_DEATHS")
        if not H.nativeSupported then H:Print("This client does not expose the Hardcore death event.") end
        H:UpdateAnnouncementReplacement()
        H:Refresh()
        return
    end
    if not H.db then return end
    if event == "PLAYER_ENTERING_WORLD" then
        H:UpdateAnnouncementReplacement()
        H:ApplySettings()
        C_Timer.After(5, function() H:JoinCommunity() end)
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        H:ApplySettings()
    elseif event == "HARDCORE_DEATHS" then
        local message = ...
        if type(message) == "string" then H:Add(H.ParseOfficial(message, H.realm, time()), false, true) end
    elseif event == "CHAT_MSG_CHANNEL" then
        local message, sender = ...
        local channel = select(9, ...)
        if type(channel) == "string" and channel:lower() == officialChannel:lower() then
            -- Record everyone received in chat without creating additional alerts.
            if type(message) == "string" then H:Add(H.ParseOfficial(message, H.realm, time()), true) end
            return
        end
        if not H.db.settings.community then return end
        if type(channel) ~= "string" or channel:lower() ~= H.channel then return end
        if type(sender) ~= "string" then return end
        local now = GetTime()
        if senderTimes[sender] and now - senderTimes[sender] < 1 then return end
        local record = H.ParseCommunity(message, sender, H.realm, time())
        if record then senderTimes[sender] = now; H:Add(record) end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, kind, _, _, source, _, _, destination, _, _, _, environment = CombatLogGetCurrentEventInfo()
        if destination ~= UnitGUID("player") then return end
        if kind == "SWING_DAMAGE" or kind == "SPELL_DAMAGE" or kind == "RANGE_DAMAGE"
            or kind == "SPELL_PERIODIC_DAMAGE" then
            lastDamage, lastDamageTime = H.Clean(source), GetTime()
        elseif kind == "ENVIRONMENTAL_DAMAGE" then
            lastDamage, lastDamageTime = H.Clean(environment), GetTime()
        end
    elseif event == "CHAT_MSG_SAY" then
        local message, sender = ...
        if H.ShortName(sender) == UnitName("player") then lastWords, lastWordsTime = H.Clean(message, 400), GetTime() end
    elseif event == "PLAYER_DEAD" then
        if not (C_ClassicHardcore and C_ClassicHardcore.IsHardcoreSelf and C_ClassicHardcore.IsHardcoreSelf()) then return end
        local _, _, classID = UnitClass("player")
        H:Add({
            name = UnitName("player"), realm = H.realm, level = UnitLevel("player"),
            guild = H.Clean(GetGuildInfo("player"), 80), classID = classID,
            zone = H.Clean(GetRealZoneText()), date = time(), source = "Self",
            cause = lastDamageTime and GetTime() - lastDamageTime <= 30 and lastDamage or nil,
            message = lastWordsTime and GetTime() - lastWordsTime <= 120 and ("Last words: " .. lastWords) or "",
        })
    elseif event == "PLAYER_ALIVE" then
        lastDamage, lastDamageTime = nil, nil
    end
end
frame:SetScript("OnEvent", receive)
for _, event in ipairs({
    "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "CHAT_MSG_CHANNEL",
    "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_DEAD", "PLAYER_ALIVE", "CHAT_MSG_SAY",
    "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
}) do frame:RegisterEvent(event) end
local elapsedTotal = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    if elapsedTotal < 15 then return end
    elapsedTotal = 0
    for sender, stamp in pairs(senderTimes) do
        if GetTime() - stamp > 60 then senderTimes[sender] = nil end
    end
    if H.db and (H.host:IsVisible() or H.mini:IsVisible()) then H:Refresh() end
end)
SLASH_HARDCOREDEATHS1 = "/hd"
SLASH_HARDCOREDEATHS2 = "/hardcoredeaths"
SlashCmdList.HARDCOREDEATHS = function(message) if H.db then H:Slash(message) end end
