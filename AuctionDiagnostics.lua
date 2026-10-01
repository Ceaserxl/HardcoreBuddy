local _,A=...
local D={limit=25}; A.AuctionDiagnostics=D
local G=A.GearAdvisor

local function plain(value)
    return tostring(value==nil and "<missing>" or value):gsub("|c%x%x%x%x%x%x%x%x",""):gsub("|r","")
        :gsub("|H(.-)|h.-|h","%1"):gsub("|","/")
end
local function scalars(values)
    local result,count={},0
    for key,value in pairs(type(values)=="table" and values or {}) do
        if type(key)=="string" and (type(value)=="number" or type(value)=="string" or type(value)=="boolean") then
            count=count+1; if count>80 then break end
            result[key]=type(value)=="number" and value==value and math.abs(value)<math.huge and value or plain(value):sub(1,256)
        end
    end
    return result
end
local function snapshot(link,item)
    local result={link=plain(link),parsed=item and scalars(item) or nil,stats=item and scalars(item.stats) or nil}
    if link then
        local api=C_Item and C_Item.GetItemStats or GetItemStats
        if api then
            local ok,stats=pcall(api,link)
            result.apiStats=ok and scalars(stats) or {error=plain(stats)}
        end
        local ok,scan=pcall(G.Scan,G,link,nil,true)
        if ok and scan then
            result.tooltip={}
            for i,line in ipairs(scan.tooltipLines or {}) do
                if i>40 then break end
                result.tooltip[#result.tooltip+1]=plain(line.left)..(line.right and line.right~="" and (" | "..plain(line.right)) or "")
            end
        else result.tooltipError=ok and "Tooltip still unavailable" or plain(scan) end
    end
    return result
end

function D:Record(scan,detail)
    local report=scan.diagnostics
    if not report then
        local p=A.AuctionUpgrades.profile
        report={schema=1,limit=self.limit,version=A.version,recordedAt=date and date("%Y-%m-%d %H:%M:%S") or "Unknown time",
            profile=p and (p.class.." / "..p.name.." / level "..p.level),weights=p and scalars(p.weights),
            highestArmor=scan.highestArmor or "All usable armor",outcome="Scan in progress",entries={}}
        if GetBuildInfo then local version,build,_,interface=GetBuildInfo(); report.client=version.." / "..build.." / "..interface end
        scan.diagnostics=report
    end
    report.skipped=scan.skipped; report.checked=scan.seen
    if #report.entries<self.limit then
        detail=detail or {stage="unknown",reason="No failure detail returned"}
        local entry={stage=detail.stage,reason=detail.reason,firstReason=scan.firstReason,
            name=detail.name,search=scan.queue[scan.search].name,page=scan.page+1,index=scan.index,
            attempts=scan.itemAttempts,waitSeconds=math.floor((GetTime()-scan.itemSince)*10)/10,
            comparisonSlot=detail.comparisonSlot,auction=scalars(detail.auction),
            candidate=snapshot(detail.link,detail.item),equipped={}}
        if detail.comparisonSlot or detail.stage=="weapon score" then
            local slots=detail.comparisonSlot and {detail.comparisonSlot} or {16,17}
            if detail.item and detail.item.equip=="INVTYPE_2HWEAPON" then slots={16,17} end
            for _,slot in ipairs(slots) do
                local item,reason=G:Equipped(slot)
                local data=snapshot(GetInventoryItemLink and GetInventoryItemLink("player",slot),item)
                data.slot=slot; data.reason=reason; entry.equipped[#entry.equipped+1]=data
            end
        end
        report.entries[#report.entries+1]=entry
    end
    if A.characterDB then A.characterDB.auctionDiagnostics=report end
end

function D:Finish(scan,message)
    if scan and scan.diagnostics then
        scan.diagnostics.checked=scan.seen; scan.diagnostics.outcome=message
    end
end

function D:Text()
    local report=A.characterDB and A.characterDB.auctionDiagnostics
    if not report then return "No skipped-listing report saved yet.\nRun an upgrade scan. Any skipped listings will be recorded automatically." end
    local lines={"HardcoreBuddy auction diagnostics v1", "Addon: "..plain(report.version),
        "Captured: "..plain(report.recordedAt),"Client: "..plain(report.client),"Profile: "..plain(report.profile),
        "Armor filter: "..plain(report.highestArmor),"Skipped listings: "..plain(report.skipped),
        "Auctions checked: "..plain(report.checked),"Outcome: "..plain(report.outcome)}
    local function fields(title,values)
        lines[#lines+1]=title
        local keys={}; for key in pairs(values or {}) do keys[#keys+1]=key end; table.sort(keys)
        for _,key in ipairs(keys) do lines[#lines+1]="  "..key.." = "..plain(values[key]) end
    end
    local function item(title,data)
        lines[#lines+1]=title..": "..plain(data.link)
        if data.reason then lines[#lines+1]="  Read result: "..plain(data.reason) end
        fields("  Parsed item:",data.parsed); fields("  Scoring stats:",data.stats); fields("  API stats:",data.apiStats)
        lines[#lines+1]="  Native tooltip:"
        for _,line in ipairs(data.tooltip or {}) do lines[#lines+1]="    "..line end
        if data.tooltipError then lines[#lines+1]="    "..plain(data.tooltipError) end
    end
    fields("Profile weights:",report.weights)
    for i,entry in ipairs(report.entries or {}) do
        lines[#lines+1]="\nListing "..i..": "..plain(entry.name)
        lines[#lines+1]="Search: "..entry.search.." | page "..entry.page.." | row "..entry.index
        lines[#lines+1]="Failure stage: "..plain(entry.stage).." | "..plain(entry.reason)
        lines[#lines+1]="First failure: "..plain(entry.firstReason)
        lines[#lines+1]="Waited "..plain(entry.waitSeconds).." seconds; "..plain(entry.attempts).." read attempts"
        if entry.comparisonSlot then lines[#lines+1]="Comparison equipment slot: "..entry.comparisonSlot end
        fields("Auction fields:",entry.auction); item("Candidate",entry.candidate)
        for _,data in ipairs(entry.equipped or {}) do item("Equipped slot "..data.slot,data) end
    end
    if (report.skipped or 0)>#report.entries then lines[#lines+1]="\nReport limited to the first "..(report.limit or self.limit).." skipped listings." end
    return table.concat(lines,"\n")
end

function D:Show()
    if not self.window then
        local f=CreateFrame("Frame","HardcoreBuddyAuctionDiagnostics",UIParent,"BackdropTemplate"); self.window=f
        f:SetSize(680,450); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:EnableMouse(true)
        f:SetClampedToScreen(true); A.Skin.Paint(f,"card")
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",16,-14)
        title:SetSize(640,22); title:SetJustifyH("LEFT")
        title:SetText("Auction scan diagnostics")
        local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("TOPLEFT",16,-40)
        hint:SetSize(640,20); hint:SetJustifyH("LEFT")
        hint:SetText("Latest scan with skipped listings. Select report, then Ctrl+C to copy.")
        local scroll=CreateFrame("ScrollFrame","HardcoreBuddyAuctionDiagnosticsScroll",f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",16,-68); scroll:SetSize(620,325); f.scroll=scroll
        local edit=CreateFrame("EditBox",nil,scroll); f.edit=edit
        edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal)
        edit:SetSize(610,325); edit:SetMaxLetters(0); scroll:SetScrollChild(edit)
        edit:SetScript("OnEscapePressed",function() f:Hide() end)
        f:SetScript("OnHide",function() edit:ClearFocus() end)
        local function button(caption,width)
            local b=CreateFrame("Button",nil,f,"BackdropTemplate"); b:SetSize(width,26)
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(caption)
            A.Skin.Button(b,"utility"); return b
        end
        local selectAll=button("Select report",140); f.selectAll=selectAll
        selectAll:SetPoint("BOTTOMLEFT",16,14)
        selectAll:SetScript("OnClick",function() edit:SetFocus(); edit:HighlightText() end)
        local close=button("Close",90)
        close:SetPoint("BOTTOMRIGHT",-16,14)
        close:SetScript("OnClick",function() f:Hide() end)
        UISpecialFrames[#UISpecialFrames+1]="HardcoreBuddyAuctionDiagnostics"
    end
    local f=self.window; local text=self:Text()
    local rows=0; for line in (text.."\n"):gmatch("(.-)\n") do rows=rows+math.max(1,math.ceil(#line/70)) end
    f.edit:SetHeight(math.max(325,rows*16)); f.edit:SetText(text); f.edit:SetCursorPosition(0)
    f.scroll:SetVerticalScroll(0); f:Show()
end
