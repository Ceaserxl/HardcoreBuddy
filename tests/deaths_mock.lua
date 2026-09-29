-- Extra native APIs used by the embedded death journal.
local extra = {}
local mt = getmetatable(UIParent)
local original = mt.__index
mt.__index = function(frame, key) return extra[key] or original(frame, key) end
function extra:GetFont() return STANDARD_TEXT_FONT, self.fontSize or 12, "" end
function extra:GetHighlightTexture()
    if not self.highlightRegion then self.highlightRegion = self:CreateTexture() end
    return self.highlightRegion
end
function extra:IsEventRegistered(event) return self.events and self.events[event] or false end
function extra:SetChecked(value) self.checked = value end
function extra:GetChecked() return self.checked end
function time() return 2000 end
date = os.date
tinsert = table.insert
RAID_CLASS_COLORS = {}
function GetRealmName() return "Realm" end
function GetChannelName() return 0 end
function JoinChannelByName() MOCK.joins = (MOCK.joins or 0) + 1 end
function UnitName() return "Tester" end
function UnitGUID() return "Player-1" end
function GetGuildInfo() return "Guild" end
function GetRealZoneText() return "Elwynn" end
C_ClassicHardcore = {IsHardcoreSelf=function() return true end}
C_Timer = {After=function(_, callback) callback() end}
RaidWarningFrame = CreateFrame("Frame", "RaidWarningFrame", UIParent)
RaidWarningFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
RaidWarningFrame:RegisterEvent("HARDCORE_DEATHS")
RaidWarningFrame:RegisterEvent("CHAT_MSG_RAID_WARNING")
function MOCK.FireAll(event, ...)
    local receivers = {}
    for _, frame in ipairs(MOCK.frames) do
        if frame:IsEventRegistered(event) and frame.scripts.OnEvent then receivers[#receivers+1] = frame end
    end
    for _, frame in ipairs(receivers) do frame.scripts.OnEvent(frame, event, ...) end
end

function extra:SetParent(parent)
    if self.parent==parent then return end
    if self.parent then
        for i,child in ipairs(self.parent.children) do
            if child==self then table.remove(self.parent.children,i); break end
        end
    end
    self.parent=parent
    if parent then parent.children[#parent.children+1]=self end
end
