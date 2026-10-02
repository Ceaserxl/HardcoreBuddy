local _, addon = ...
local H = addon.Deaths
local GOLD, MUTED = {0.80, 0.66, 0.42}, {0.64, 0.66, 0.70}
local function Text(parent, size, point, x, y, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    local face, _, flags = fs:GetFont()
    fs:SetFont(face, size, flags)
    fs:SetPoint(point, parent, point, x, y)
    fs:SetJustifyH("LEFT")
    if width then fs:SetWidth(width); fs:SetWordWrap(false) end
    return fs
end
local function Panel(name, width, height)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(width, height)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = {left=3,right=3,top=3,bottom=3} })
    f:SetBackdropColor(0.045, 0.043, 0.047, 0.98)
    f:SetBackdropBorderColor(0.43, 0.34, 0.23)
    f:Hide()
    return f
end
local function Button(parent, label, width, x, y, action)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 28); b:SetPoint("TOPLEFT", x, y)
    b.label=Text(b,12,"CENTER",0,0,width-12)
    b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    b.label:SetText(label)
    addon.Skin.Button(b,"utility")
    b:SetScript("OnClick",action)
    b:SetScript("OnEnter",function() addon.Skin.ButtonState(b,false,true,false) end)
    b:SetScript("OnLeave",function() addon.Skin.ButtonState(b,false,false,false) end)
    b:SetScript("OnMouseDown",function() addon.Skin.ButtonState(b,false,true,true) end)
    b:SetScript("OnMouseUp",function() addon.Skin.ButtonState(b,false,true,false) end)
    return b
end
local function Edit(parent,width,x,y,numeric)
    local edit=CreateFrame("EditBox",nil,parent,"BackdropTemplate")
    edit:SetSize(width,28); edit:SetPoint("TOPLEFT",x,y); edit:SetAutoFocus(false)
    addon.Skin.Paint(edit,"edit")
    edit:SetFont(STANDARD_TEXT_FONT,13,""); edit:SetTextColor(0.94,0.90,0.79)
    edit:SetTextInsets(9,9,0,0)
    if numeric then edit:SetNumeric(true); edit:SetMaxLetters(2); edit:SetJustifyH("CENTER") end
    edit:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    return edit
end
local function Drag(frame, key, height)
    local handle = CreateFrame("Frame", nil, frame)
    frame.dragHandle=handle
    handle:SetPoint("TOPLEFT", 8, -8)
    handle:SetPoint("TOPRIGHT", -36, -8)
    handle:SetHeight(height)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:SetScript("OnDragStart", function()
        if not H.db.settings.locked then frame:StartMoving() end
    end)
    handle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local point, _, relative, x, y = frame:GetPoint()
        H.db.positions = H.db.positions or {}
        H.db.positions[key] = { point, relative, x, y }
    end)
end
local function Background(parent, texture, x, y, width, height, alpha)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(texture)
    t:SetSize(width, height)
    t:SetPoint("TOPLEFT", x, y)
    t:SetAlpha(alpha or 1)
    return t
end

function H:ShowDetails(record)
    local f = self.details
    f.record = record
    f.title:SetText(record.name)
    local class = self:ClassText(record)
    f.body:SetText(table.concat({
        "Level: " .. (record.level or "--") .. "    Class: " .. class,
        "Realm: " .. (record.realm or "--"),
        "Guild: " .. ((record.guild and record.guild ~= "") and record.guild or "--"),
        "Location: " .. (record.zone or "Not reported"),
        "Cause: " .. self:Cause(record),
        "Received: " .. date("%Y-%m-%d %H:%M", record.date),
        "Source: " .. record.source .. (record.source == "Community" and " (unverified)" or ""),
        "", record.message or "",
    }, "\n"))
    f.content:SetHeight(math.max(230, f.body:GetStringHeight() + 8))
    f.scroll:SetVerticalScroll(0)
    local filter=addon.state and addon.state.view=="deaths" and addon.state.filter
    addon:OpenDeaths(filter~="Options" and filter or "Reports",record)
end
function H:JournalColumns(width)
    local extra=math.max(0,(width-816)/3)
    return {{"LEVEL",6,36,"level"},{"ADVENTURER",52,140+extra,"name"},
        {"LOCATION",202+extra,170+extra,"zone"},{"CAUSE",382+extra*2,208+extra,"cause"},
        {"SOURCE",600+extra*3,96,"source"},{"WHEN",width-108,70,"age"}}
end
function H:MakeRow(parent, index, y, mini)
    local row = CreateFrame("Button", nil, parent,"BackdropTemplate")
    row:SetPoint("TOPLEFT", mini and 8 or 12, y)
    row:SetPoint("TOPRIGHT", mini and -8 or -12, y)
    row:SetHeight(mini and 20 or 30)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.04 or 0)
    addon.Skin.Hover(row)
    row:RegisterForClicks("LeftButtonUp")
    if mini then
        row.level = Text(row, 14, "LEFT", 4, 0, 30)
        row.level:SetJustifyH("CENTER")
        row.level:SetTextColor(unpack(GOLD))
        row.name = Text(row, 13, "LEFT", 42, 0, 100)
        row.age = Text(row, 10, "LEFT", 290, 0, 50)
        row.zone = Text(row, 11, "LEFT", 150, 0, 132)
    else
        addon.Skin.Paint(row,"row")
        row.level=Text(row,14,"LEFT",6,0,36); row.level:SetJustifyH("CENTER"); row.level:SetTextColor(unpack(GOLD))
        row.name=Text(row,13,"LEFT",52,0,140)
        row.zone=Text(row,12,"LEFT",202,0,170)
        row.cause=Text(row,12,"LEFT",382,0,208)
        row.source=Text(row,11,"LEFT",600,0,96)
        row.age=Text(row,11,"RIGHT",-14,0,70); row.age:SetJustifyH("RIGHT")
    end
    row:SetScript("OnClick", function(_, button)
        if not row.record then return end
        if button == "LeftButton" then H:ShowDetails(row.record) end
    end)
    row:SetScript("OnEnter", function()
        if not row.record then return end
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        GameTooltip:SetText(row.record.name, GOLD[1], GOLD[2], GOLD[3], 1, true)
        GameTooltip:AddLine(H:Cause(row.record), 1, 1, 1, true)
        GameTooltip:AddLine(row.record.source == "Community" and "Community report (unverified)" or row.record.source .. " report", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Click: details", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end
function H:PaintRow(row, record, mini)
    row.record = record
    row:SetShown(record ~= nil)
    if not record then return end
    row.name:SetText(record.name)
    if mini then row.level:SetText(record.level or "?") end
    local _, token = self:ClassText(record)
    local color = token and RAID_CLASS_COLORS[token]
    row.name:SetTextColor(color and color.r or 0.93, color and color.g or 0.88, color and color.b or 0.77)
    row.age:SetText(self:Age(record.date))
    row.age:SetTextColor(unpack(MUTED))
    row.zone:SetText(record.zone or "Location not reported")
    row.zone:SetTextColor(unpack(MUTED))
    if not mini then
        row.level:SetText(record.level or "--")
        row.cause:SetText(self:Cause(record))
        row.source:SetText(record.source)
        row.source:SetTextColor(record.source == "Community" and 0.9 or 0.60, 0.65, 0.50)
    end
end
-- Keep a small row pool while the scrollbar spans the entire filtered history.
function H:RefreshJournalRows()
    local f=self.window
    if not f or not f.listScroll then return end
    local records=self.filtered or {}
    local offset=f.listScroll:GetVerticalScroll()
    local first=math.floor(offset/32)+1
    local count=math.max(0,math.min(#records-first+1,math.ceil((offset%32+f.listScroll:GetHeight())/32)))
    for i=1,count do
        local index=first+i-1
        local row=f.rows[i]
        if not row then row=self:MakeRow(f.listContent,i,0,false); f.rows[i]=row end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",12,-(index-1)*32)
        row:SetPoint("TOPRIGHT",-12,-(index-1)*32)
        row.bg:SetColorTexture(1,1,1,index%2==0 and 0.04 or 0)
        for _,column in ipairs(self:JournalColumns(f.listContent:GetWidth())) do
            local label=row[column[4]]
            label:ClearAllPoints(); label:SetPoint("LEFT",column[2],0); label:SetWidth(column[3])
        end
        self:PaintRow(row,records[index],false)
    end
    for i=count+1,#f.rows do self:PaintRow(f.rows[i],nil,false) end
end
function H:Refresh()
    if not self.window then return end
    local all = self.Filter(self.db.records, "", "all", 0, self.realm)
    local filtered = self.Filter(self.db.records, self.query or "", "all", self.minLevel or 0, self.realm)
    self.filtered = filtered
    local stats = self.Stats(filtered)
    self.window.count:SetText(tostring(stats.count))
    self.window.average:SetText(stats.average and string.format("%.1f",stats.average) or "--")
    self.window.highest:SetText(stats.highest>0 and tostring(stats.highest) or "--")
    self.window.hotspot:SetText(stats.zone)
    self.window.realm:SetText(self.realm.."  |  Received death reports")
    local scroll=self.window.listScroll
    self.window.listContent:SetWidth(scroll:GetWidth())
    self.window.listContent:SetHeight(math.max(1,#filtered*32-2))
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(math.min(scroll:GetVerticalScroll(),math.max(0,self.window.listContent:GetHeight()-scroll:GetHeight())))
    self:RefreshJournalRows()
    self.window.empty:SetShown(#filtered == 0)
    self.window.empty:SetText(#self.db.records == 0 and "No reports yet.\nListening for Hardcore deaths while you play." or "No reports match these filters.")
    for i, row in ipairs(self.mini.rows) do self:PaintRow(row, all[i], true) end
    self.mini.empty:SetShown(#all == 0)
    self.mini.status:SetText(self.nativeSupported == false and "Feed unavailable"
        or (self.db.settings.community and "Official + community" or "Official death feed"))
    self.mini.indicator:SetColorTexture(self.nativeSupported==false and 0.85 or 0.42,
        self.nativeSupported==false and 0.40 or 0.72,0.30,1)
    self.mini.empty:SetText(self.nativeSupported==false and "Official feed unavailable.\nSaved reports are in the journal."
        or "No deaths received yet.\nListening while you play.")
end
function H:ApplySettings()
    local s = self.db.settings
    if not s.alerts and self.alert.positioning and self.FinishPositioning then
        self:FinishPositioning(); return
    end
    if self.ApplyAppearance then self:ApplyAppearance() end
    s.alertDuration=self.NormalizeAlertDuration(s.alertDuration)
    self.db.positions = self.db.positions or {}
    for key, f in pairs({ mini=self.mini, alert=self.alert }) do
        local scale=s.scale
        if key=="alert" then scale=math.min(scale,math.max(0.1,(UIParent:GetWidth()-24)/f:GetWidth())) end
        f:SetScale(scale)
        f:ClearAllPoints()
        local p = self.db.positions[key]
        if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
        elseif key == "mini" then f:SetPoint("RIGHT", UIParent, "RIGHT", -40, 60)
        elseif key == "alert" and RaidWarningFrame then f:SetPoint("TOP", RaidWarningFrame, "TOP", 0, 0)
        elseif key == "alert" then f:SetPoint("TOP", UIParent, "TOP", 0, -180)
        else f:SetPoint("CENTER") end
    end
    self.mini:SetShown(s.mini)
    if self.options.checks then
        for key, checkbox in pairs(self.options.checks) do checkbox:SetChecked(s[key]); checkbox.mark:SetText(s[key] and "X" or "") end
    end
    self.options.scaleText:SetText(string.format("Overlay scale: %.1f", s.scale))
    local volume=tonumber(s.volume)
    s.volume=volume and volume==volume and math.max(0,math.min(100,math.floor(volume/10+0.5)*10)) or 70
    self.options.volume:SetValue(s.volume)
    self.options.volumeLabel:SetText("Alert volume")
    local sound,index=self.NormalizeAlertSound(s.alertSound)
    s.alertSound=sound
    self.options.soundChoice.label:SetText(self.soundChoices[index].name)
    self.options.volume:Show()
    if (not s.sound or not s.alerts or s.volume==0) and self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
    self.options.alertLevel:SetText(tostring(s.minAlertLevel))
    if not self.options.duration:HasFocus() then self.options.duration:SetText(tostring(s.alertDuration)) end
    self:UpdateAnnouncementReplacement()
    if not s.alerts and not self.alert.positioning then
        self.alert:Hide()
    end
    self:Refresh()
    if addon.Settings then addon.Settings:SyncDependencies() end
end
function H:ShowAlert(record, preview)
    local a = self.alert
    if a.positioning and not preview then return end
    if self.ApplyAppearance then self:ApplyAppearance() end
    a.name:SetText(record.name .. "  |  Level " .. (record.level or "?"))
    a.description:SetText(self:Cause(record).."  |  "..(record.zone or "Location not reported"))
    for _,entry in ipairs({{a.name,a.nameSize or 28,a.nameMinimum or 22},{a.description,a.detailSize or 16,12}}) do
        local label,size,minimum=unpack(entry)
        label:SetFont(STANDARD_TEXT_FONT,size,"")
        while size>minimum and label:GetStringWidth()>label:GetWidth() do
            size=size-1; label:SetFont(STANDARD_TEXT_FONT,size,"")
        end
    end
    -- Keep the banner artwork undistorted. Long text uses the available
    -- center width without repeating the name and level from the line above.
    if not self.ApplyAppearance then a:SetHeight(80) end
    a.record = record
    a.elapsed = 0
    a.holdDuration=self.NormalizeAlertDuration(self.db.settings.alertDuration)
    a:SetAlpha(1)
    a:Show()
    if not a.positioning then self:PlayAlertSound() end
end
function H:LayoutPage(parent,left,top,width,height,state)
    self.host:SetParent(parent)
    if addon.Skin.Rebase then addon.Skin.Rebase(self.host,parent:GetFrameLevel()+2) end
    self.host:ClearAllPoints()
    self.host:SetPoint("TOPLEFT",parent,"TOPLEFT",left,-top)
    self.host:SetSize(width,height)
    -- The journal scrolls its rows/body beneath fixed headings, but its scrollbar
    -- uses the same full-page top edge as the other HardcoreBuddy pages.
    for _,scroll in ipairs({self.window.listScroll,self.details.scroll}) do
        local name=scroll.GetName and scroll:GetName()
        local bar=scroll.ScrollBar or (name and _G[name.."ScrollBar"])
        if bar then
            bar:ClearAllPoints()
            bar:SetPoint("TOPLEFT",self.host,"TOPRIGHT",4,-16)
            bar:SetPoint("BOTTOMLEFT",self.host,"BOTTOMRIGHT",4,16)
        end
    end
    addon.Skin.LayoutSections(self.window,width)
    addon.Skin.SettingsHeader(self.window,width,self.window.title,self.window.realm,self.window.settings)
    addon.Skin.SettingsHeader(self.details,width,self.details.title)
    for i,stat in ipairs(self.window.stats) do
        local cell=(width-12-24)/4
        stat:ClearAllPoints(); stat:SetPoint("TOPLEFT",(i-1)*(cell+8),-54); stat:SetWidth(cell)
        stat.label:SetWidth(cell-24); stat.value:SetWidth(cell-24)
    end
    -- Filters belong to the shared navigation toolbar, above the page heading.
    local journal=self.window
    journal.clear:ClearAllPoints(); journal.clear:SetPoint("TOPRIGHT",-12,34); journal.clear:SetWidth(130)
    journal.minimum:ClearAllPoints(); journal.minimum:SetPoint("TOPRIGHT",journal.clear,"TOPLEFT",-8,0)
    journal.minimumLabel:ClearAllPoints(); journal.minimumLabel:SetPoint("RIGHT",journal.minimum,"LEFT",-8,0)
    journal.minimumLabel:SetWidth(94)
    journal.search:ClearAllPoints(); journal.search:SetPoint("TOPLEFT",0,34)
    journal.search:SetWidth(width-12-130-44-94-24)
    local columns=self:JournalColumns(width)
    for i,label in ipairs(self.window.columnLabels) do
        label:ClearAllPoints(); label:SetPoint("TOPLEFT",columns[i][2]+12,-118); label:SetWidth(columns[i][3])
    end
    self.window.tableCard:SetHeight(math.max(40,height-118))
    addon.Skin.LayoutSections(self.details,width)
    self.details.bodyCard:SetHeight(math.max(40,height-42))
    addon.Skin.LayoutSections(self.options,width)
    if self.appearance then addon.Skin.LayoutSections(self.appearance,width) end
    self.mode="all"
    if self.lastFilter~=state.filter then self.window.listScroll:SetVerticalScroll(0); self.lastFilter=state.filter end
    local combined=state.filter=="Settings"
    self.window:SetShown(not combined and state.filter~="Options" and state.filter~="Appearance" and not state.deathRecord)
    self.options:ClearAllPoints()
    if combined then self.options:SetPoint("TOPLEFT",self.host,"TOPLEFT",0,0); self.options:SetSize(width,450)
    else self.options:SetAllPoints(self.host) end
    self.options:SetShown((combined or state.filter=="Options") and not state.deathRecord)
    local options=self.options
    addon.Skin.SettingsHeader(options,width,options.title,options.subtitle,options.preview)
    for _,box in ipairs({options.duration,options.alertLevel}) do
        box:ClearAllPoints(); box:SetPoint("TOPRIGHT",-16,box==options.duration and -84 or -126)
    end
    options.scaleDown:ClearAllPoints(); options.scaleDown:SetPoint("TOPRIGHT",-54,-116)
    options.scaleUp:ClearAllPoints(); options.scaleUp:SetPoint("TOPRIGHT",-16,-116)
    options.volume:SetWidth(options.display:GetWidth()-142)
    options.soundChoice:SetWidth(options.display:GetWidth()-104)
    options.soundNext:ClearAllPoints(); options.soundNext:SetPoint("TOPRIGHT",-16,-86)
    options.retention:ClearAllPoints(); options.retention:SetPoint("TOPRIGHT",-16,-80)
    for _,control in ipairs({options.import,options.resetPositions}) do control:SetWidth(control:GetParent():GetWidth()-32) end
    for _,checkbox in pairs(options.checks) do checkbox.label:SetWidth(checkbox:GetParent():GetWidth()-66) end
    options.retentionHint:SetWidth(options.history:GetWidth()-32)
    options.importHint:SetWidth(options.history:GetWidth()-32)

    if self.appearance then
        self.appearance:ClearAllPoints()
        if combined then self.appearance:SetPoint("TOPLEFT",self.host,"TOPLEFT",0,-458); self.appearance:SetSize(width,196)
        else self.appearance:SetAllPoints(self.host) end
        self:LayoutAppearance(width,combined)
        self.appearance:SetShown((combined or state.filter=="Appearance") and not state.deathRecord)
    end
    self.details:SetShown(state.deathRecord~=nil)
    self.details.body:SetWidth(width-44)
    self.details.content:SetWidth(width-44)
    self.details.content:SetHeight(math.max(1,self.details.body:GetStringHeight()+8))
    self:Refresh()
end
local function Page(parent)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetAllPoints(parent)
    addon.Skin.Paint(f,"card")
    f:Hide()
    return f
end
function H:BuildUI()
    local host=CreateFrame("Frame",nil,UIParent)
    host:SetSize(816,468)
    host:Hide()
    self.host=host
    local f=Page(host)
    self.window=f
    addon.Skin.Paint(f,"note")
    local title=Text(f,22,"TOPLEFT",0,0,500); f.title=title
    title:SetText("Death Journal"); title:SetTextColor(unpack(GOLD))
    f.realm=Text(f,12,"TOPLEFT",0,-42,650); f.realm:SetTextColor(unpack(MUTED))
    f.tableCard=addon.Skin.SectionBackdrop(f,110,318)
    f.stats={}
    for i,entry in ipairs({{"count","REPORTS"},{"average","AVERAGE LEVEL"},{"highest","HIGHEST LEVEL"},{"hotspot","MOST REPORTED"}}) do
        local stat=CreateFrame("Frame",nil,f,"BackdropTemplate")
        f.stats[i]=stat
        stat:SetSize(246,48); stat:SetPoint("TOPLEFT",16+(i-1)*258,-64)
        addon.Skin.Paint(stat,"card")
        local label=Text(stat,10,"TOPLEFT",12,-7,210); label:SetText(entry[2]); label:SetTextColor(unpack(MUTED))
        local value=Text(stat,entry[1]=="hotspot" and 12 or 18,"TOPLEFT",12,-23,210)
        f[entry[1]]=value; value:SetTextColor(unpack(GOLD)); stat.label=label; stat.value=value
        if entry[1]=="hotspot" then value:SetWordWrap(true); value:SetHeight(24) end
    end
    local search=Edit(f,340,0,-122)
    f.search=search
    search:SetMaxLetters(80)
    search.placeholder = Text(search,12,"LEFT",10,0,310)
    search.placeholder:SetText("Search reports...")
    search.placeholder:SetTextColor(unpack(MUTED))
    search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    search:SetScript("OnTextChanged", function(box)
        self.query=box:GetText(); box.placeholder:SetShown(self.query==""); self.window.listScroll:SetVerticalScroll(0); self:Refresh()
    end)
    search:SetScript("OnEnter", function()
        GameTooltip:SetOwner(search,"ANCHOR_RIGHT"); GameTooltip:SetText("Search name, location, cause, guild or message",1,1,1,1,true); GameTooltip:Show()
    end)
    search:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.minimumLabel=Text(f,12,"TOPLEFT",374,-129,94); f.minimumLabel:SetText("Minimum level")
    local minimum=Edit(f,44,476,-122,true)
    f.minimum=minimum
    minimum:SetText("0")
    minimum:SetScript("OnTextChanged", function(box) self.minLevel=math.max(0,math.min(60,tonumber(box:GetText()) or 0));self.window.listScroll:SetVerticalScroll(0);self:Refresh() end)
    minimum:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    f.clear=Button(f,"Clear reports",160,600,-122,function(button)
        if button.confirmUntil and GetTime()<button.confirmUntil then
            button.confirmUntil=nil; button.label:SetText("Clear reports"); self:ClearReports()
        else button.confirmUntil=GetTime()+5; button.label:SetText("Confirm clear") end
    end)
    f.clear:SetScript("OnUpdate",function(button)
        if button.confirmUntil and GetTime()>=button.confirmUntil then button.confirmUntil=nil; button.label:SetText("Clear reports") end
    end)
    f.settings=Button(f,"Settings",110,0,0,function() addon:OpenSettings("Death Journal") end)
    f.settings:ClearAllPoints(); f.settings:SetPoint("TOPRIGHT",-16,0)
    f.columnLabels={}
    for _,c in ipairs(self:JournalColumns(816)) do local label=Text(f,10,"TOPLEFT",c[2]+12,-163,c[3]); label:SetText(c[1]); label:SetTextColor(unpack(MUTED)); f.columnLabels[#f.columnLabels+1]=label end
    f.rows = {}
    f.listScroll=CreateFrame("ScrollFrame","HardcoreBuddyDeathJournalScrollFrame",f,"UIPanelScrollFrameTemplate")
    f.listScroll:SetPoint("TOPLEFT",0,-140); f.listScroll:SetPoint("BOTTOMRIGHT",0,10)
    f.listScroll:EnableMouseWheel(true)
    f.listScroll:SetScript("OnMouseWheel",function(scroll,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*96)))
    end)
    f.listScroll:HookScript("OnVerticalScroll",function() self:RefreshJournalRows() end)
    f.listContent=CreateFrame("Frame",nil,f.listScroll)
    f.listContent:SetSize(816,1); f.listScroll:SetScrollChild(f.listContent)
    f.empty=Text(f.listScroll,15,"CENTER",0,0,650);f.empty:SetJustifyH("CENTER");f.empty:SetWordWrap(true)

    local mini=Panel("HardcoreBuddyDeathsFeed",360,218);self.mini=mini
    addon.Skin.Paint(mini,"menu")
    local feedTitle=Text(mini,15,"TOPLEFT",14,-16,290)
    feedTitle:SetText("Death Journal"); feedTitle:SetTextColor(unpack(GOLD))
    Drag(mini,"mini",27)
    mini.hide=Button(mini,"-",22,326,-12,function() self.db.settings.mini=false;self:ApplySettings() end)
    mini.hide:SetHeight(22)
    mini.rows={}
    for _,column in ipairs({{"LVL",12,30},{"NAME",50,100},{"LOCATION",158,132},{"WHEN",298,50}}) do
        local label=Text(mini,9,"TOPLEFT",column[2],-44,column[3])
        label:SetText(column[1]); label:SetTextColor(unpack(MUTED))
    end
    for i=1,6 do mini.rows[i]=self:MakeRow(mini,i,-58-(i-1)*21,true) end
    mini.empty=Text(mini,12,"CENTER",0,0,252);mini.empty:SetJustifyH("CENTER");mini.empty:SetWordWrap(true)
    mini.empty:SetTextColor(unpack(MUTED))
    mini.indicator=mini:CreateTexture(nil,"ARTWORK")
    mini.indicator:SetSize(6,6);mini.indicator:SetPoint("BOTTOMLEFT",13,17)
    mini.status=Text(mini,10,"BOTTOMLEFT",25,13,164);mini.status:SetTextColor(unpack(MUTED))
    local journalButton=Button(mini,"Open journal",96,0,0,function() addon:OpenDeaths() end)
    mini.journal=journalButton
    journalButton:ClearAllPoints()
    journalButton:SetPoint("BOTTOMRIGHT",mini,"BOTTOMRIGHT",-10,10)
    journalButton:SetHeight(22)

    local detail=Page(host); self.details=detail
    addon.Skin.Paint(detail,"note")
    detail.bodyCard=addon.Skin.SectionBackdrop(detail,34,374)
    detail.title=Text(detail,22,"TOPLEFT",0,0,390);detail.title:SetTextColor(unpack(GOLD))
    detail.scroll=CreateFrame("ScrollFrame",nil,detail,"UIPanelScrollFrameTemplate")
    detail.scroll:SetPoint("TOPLEFT",16,-50);detail.scroll:SetPoint("BOTTOMRIGHT",detail,"BOTTOMRIGHT",-28,24)
    detail.content=CreateFrame("Frame",nil,detail.scroll);detail.content:SetSize(375,230)
    detail.scroll:SetScrollChild(detail.content)
    detail.body=Text(detail.content,12,"TOPLEFT",0,0,370);detail.body:SetWordWrap(true)
    detail.body:SetJustifyV("TOP")

    local alert=Panel("HardcoreBuddyDeathsAlert",896,80);self.alert=alert
    alert:SetFrameStrata("HIGH")
    alert:SetScript("OnUpdate",function(banner,elapsed)
        if banner.positioning then return end
        banner.elapsed = (banner.elapsed or 0) + elapsed
        local duration=banner.holdDuration or 3
        if banner.elapsed >= duration+0.5 then
            banner:Hide()
        elseif banner.elapsed > duration then
            banner:SetAlpha(1 - (banner.elapsed - duration) / 0.5)
        end
    end)
    alert:SetBackdrop(nil)
    -- Equal end caps preserve the mirrored ornaments and leave the full
    -- center of the new artwork available for centered text.
    local capWidth=41
    alert.artParts={}
    for i,slice in ipairs({{0,0.08,0,capWidth},
        {0.08,0.92,capWidth,896-2*capWidth},
        {0.92,1,896-capWidth,capWidth}}) do
        local art=Background(alert,self.MEDIA.."AlertBannerIron",slice[3],0,slice[4],80,1)
        art:SetTexCoord(slice[1],slice[2],0,1)
        alert.artParts[i]=art
    end
    alert.art=alert.artParts[1]
    alert.cornerMask=alert:CreateMaskTexture()
    alert.cornerMask:SetTexture(self.MEDIA.."AlertRoundedMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
    alert.cornerMask:SetAllPoints(alert)
    for _,art in ipairs(alert.artParts) do art:AddMaskTexture(alert.cornerMask) end
    alert.name=Text(alert,28,"TOPLEFT",80,-12,736)
    alert.name:SetTextColor(0.98,0.93,0.82)
    alert.description=Text(alert,16,"TOPLEFT",80,-49,736)
    alert.description:SetTextColor(0.88,0.86,0.79)
    alert.rule=alert:CreateTexture(nil,"ARTWORK")
    alert.rule:SetColorTexture(0.65,0.48,0.25,0.45)
    alert.rule:SetSize(676,1); alert.rule:SetPoint("TOPLEFT",110,-45)
    alert.description:SetWordWrap(false)
    alert.description:SetJustifyV("TOP")
    for _,label in ipairs({alert.name,alert.description}) do
        label:SetJustifyH("CENTER")
        label:SetShadowColor(0,0,0,1); label:SetShadowOffset(1,-1)
    end
    Drag(alert,"alert",64)
    if self.BuildAppearance then self:BuildAppearance(host) end

    local options=Page(host); self.options=options
    addon.Skin.Paint(options,"note")
    local history=addon.Skin.Section(options,"Journal reports",54,210,1); options.history=history
    local overlays=addon.Skin.Section(options,"Live feed & overlays",54,210,2); options.overlays=overlays
    local reports=addon.Skin.Section(options,"Death alerts",272,178,1); options.reports=reports
    local display=addon.Skin.Section(options,"Alert sound",272,178,2); options.display=display
    local optionsTitle=Text(options,22,"TOPLEFT",0,0,700); options.title=optionsTitle
    optionsTitle:SetText("Death Journal"); optionsTitle:SetTextColor(unpack(addon.Skin.colors.gold))
    local intro=Text(options,12,"TOPLEFT",0,-34,720); options.subtitle=intro
    intro:SetText("Manage saved reports, the live feed and death notifications."); intro:SetTextColor(unpack(MUTED))
    options.checks={}
    local checks={
        {"mini","Show compact live feed",overlays,44},{"alerts","Show death alerts",reports,44},
        {"sound","Play alert sound",display,44},{"locked","Lock overlay positions",overlays,80},
        {"community","Community reports (unverified)",history,44},
    }
    for i,entry in ipairs(checks) do
        local key,label=entry[1],entry[2]
        local checkbox=CreateFrame("CheckButton",nil,entry[3],"BackdropTemplate")
        checkbox:SetSize(24,24); checkbox:SetPoint("TOPLEFT",16,-entry[4])
        addon.Skin.Paint(checkbox,"edit")
        checkbox.mark=Text(checkbox,13,"CENTER",0,0,20); checkbox.mark:SetJustifyH("CENTER")
        checkbox.mark:SetTextColor(unpack(GOLD))
        local text=Text(checkbox,12,"LEFT",34,0,300); text:SetWordWrap(true); text:SetText(label); checkbox.label=text
        checkbox:SetScript("OnClick",function(box)
            self.db.settings[key]=box:GetChecked() and true or false
            self:ApplySettings()
            if key=="community" then self:JoinCommunity() end
        end)
        options.checks[key]=checkbox
    end
    options.alertCaptions={Text(reports,12,"TOPLEFT",16,-91,230)}
    options.alertCaptions[1]:SetText("Duration (1-30 seconds)")
    local duration=Edit(reports,56,0,0,true); options.duration=duration
    local function commitDuration(box)
        self.db.settings.alertDuration=self.NormalizeAlertDuration(tonumber(box:GetText()) or self.db.settings.alertDuration)
        box:SetText(tostring(self.db.settings.alertDuration))
    end
    duration:SetScript("OnEnterPressed",function(box) commitDuration(box); box:ClearFocus() end)
    duration:SetScript("OnEditFocusLost",commitDuration)
    duration:SetScript("OnEscapePressed",function(box) box:SetText(tostring(self.db.settings.alertDuration)); box:ClearFocus() end)
    options.alertCaptions[2]=Text(reports,12,"TOPLEFT",16,-133,230)
    options.alertCaptions[2]:SetText("Minimum reported level")
    local alertLevel=Edit(reports,56,0,0,true); options.alertLevel=alertLevel
    alertLevel:SetText(tostring(self.db.settings.minAlertLevel))
    alertLevel:SetScript("OnTextChanged",function(box)self.db.settings.minAlertLevel=math.max(1,math.min(60,tonumber(box:GetText()) or 1))end)
    options.scaleText=Text(overlays,12,"TOPLEFT",16,-123,200)
    options.scaleDown=Button(overlays,"-",30,0,0,function()self.db.settings.scale=math.max(0.7,self.db.settings.scale-0.1);self:ApplySettings()end)
    options.scaleUp=Button(overlays,"+",30,0,0,function()self.db.settings.scale=math.min(1.5,self.db.settings.scale+0.1);self:ApplySettings()end)
    options.soundLabel=display.title
    local function changeSound(step)
        local _,index=self.NormalizeAlertSound(self.db.settings.alertSound)
        index=(index-1+step)%#self.soundChoices+1
        self.db.settings.alertSound=self.soundChoices[index].id
        self:ApplySettings(); self:PlayAlertSound()
    end
    options.soundPrev=Button(display,"<",28,16,-86,function() changeSound(-1) end)
    options.soundChoice=Button(display,"",248,52,-86,function() self:PlayAlertSound() end)
    options.soundNext=Button(display,">",28,0,-86,function() changeSound(1) end)
    options.volumeLabel=Text(display,12,"TOPLEFT",16,-139,104)
    local volume=CreateFrame("Slider",nil,display,"BackdropTemplate"); options.volume=volume
    volume:SetPoint("TOPLEFT",126,-136); volume:SetSize(230,18); volume:SetOrientation("HORIZONTAL")
    addon.Skin.Paint(volume,"edit"); volume:SetMinMaxValues(0,100); volume:SetValueStep(10); volume:SetObeyStepOnDrag(true)
    volume:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    volume:GetThumbTexture():SetSize(12,22); volume:GetThumbTexture():SetVertexColor(unpack(GOLD))
    volume:SetScript("OnValueChanged",function(_,value)
        self.db.settings.volume=math.max(0,math.min(100,math.floor(value/10+0.5)*10))
        options.volumeLabel:SetText("Alert volume")
        if self.soundHandle and StopSound then StopSound(self.soundHandle); self.soundHandle=nil end
    end)
    addon.Skin.InlineSlider(volume,"%",10)
    options.preview=Button(options,"Preview alert",140,0,0,function() duration:ClearFocus(); self:Slash("test") end)
    local reset=Button(overlays,"Reset overlay positions",184,16,-160,function()self:Slash("resetposition")end)
    options.resetPositions=reset
    options.import=Button(history,"Import Deathlog history",240,16,-148,function() self:ImportLegacy() end)
    options.importHint=Text(history,11,"TOPLEFT",16,-183,330)
    options.importHint:SetText("Uses Deathlog history loaded on this character."); options.importHint:SetTextColor(unpack(MUTED))
    options.retentionTitle=Text(history,12,"TOPLEFT",16,-87,240); options.retentionTitle:SetText("Keep reports (days)")
    local retention=Edit(history,64,0,0,true); options.retention=retention
    retention:SetMaxLetters(4)
    retention:SetText(tostring(self.db.settings.retentionDays or 30))
    options.retentionHint=Text(history,11,"TOPLEFT",16,-116,290); options.retentionHint:SetText("0 = Keep forever. Otherwise, 1-3650 days."); options.retentionHint:SetTextColor(unpack(MUTED))
    local function saveRetention(box)
        self.db.settings.retentionDays=tonumber(box:GetText()) or self.db.settings.retentionDays
        self:PruneReports(); box:SetText(tostring(self.db.settings.retentionDays)); self:Refresh()
    end
    retention:SetScript("OnEditFocusLost",saveRetention)
    retention:SetScript("OnEnterPressed",function(box) box:ClearFocus() end)
    retention:SetScript("OnEscapePressed",function(box) box:SetText(tostring(self.db.settings.retentionDays)); box:ClearFocus() end)
    host:SetScript("OnHide",function()
        search:ClearFocus(); minimum:ClearFocus(); alertLevel:ClearFocus(); duration:ClearFocus(); GameTooltip:Hide()
    end)
end
