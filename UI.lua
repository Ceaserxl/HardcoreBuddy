local _, addon = ...
local P, C, Skin = addon.Planner, addon.Companion, addon.Skin
local GOLD, WHITE, MUTED = Skin.colors.gold, Skin.colors.white, Skin.colors.muted
local STOCK_COLORS={ready={0.42,0.83,0.60},low={1,0.76,0.32},missing={0.96,0.48,0.39},unknown=MUTED,choose=GOLD,off=MUTED}

function addon:InsertUserItemLink(link)
    local entry=self.window and self.window.userEntry
    if not entry or not entry:IsVisible() or not entry.input:HasFocus() then return end
    if type(link)~="string" or not link:match("item:%d+") then return end
    entry.input:SetText(link)
end

if type(hooksecurefunc)=="function" and type(ChatEdit_InsertLink)=="function" then
    hooksecurefunc("ChatEdit_InsertLink",function(link) addon:InsertUserItemLink(link) end)
end
local function font(parent, size, color)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT, size, "")
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetWordWrap(true)
    f:SetTextColor(unpack(color or WHITE))
    f:SetShadowColor(0,0,0,0.95); f:SetShadowOffset(1,-1)
    return f
end
local function backdrop(frame, r, g, b)
    frame:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=1})
    frame:SetBackdropColor(r, g, b, 0.98)
    frame:SetBackdropBorderColor(0.29, 0.26, 0.20, 1)
end
local function button(parent, label, width, callback)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 28)
    b.label = font(b, 12, GOLD); b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE"); b.label:SetText(label)
    Skin.Button(b,"utility")
    b:SetScript("OnClick", callback)
    b:SetScript("OnEnter", function(self) self.hovered=true; Skin.ButtonState(self,self.active,true,false) end)
    b:SetScript("OnLeave", function(self) self.hovered=false; Skin.ButtonState(self,self.active,false,false) end)
    b:SetScript("OnMouseDown", function(self) Skin.ButtonState(self,self.active,self.hovered,true) end)
    b:SetScript("OnMouseUp", function(self) Skin.ButtonState(self,self.active,self.hovered,false) end)
    return b
end
local function enabled(frame, value)
    frame:SetEnabled(value); frame:SetAlpha(value and 1 or 0.45)
    if frame.label then Skin.ButtonState(frame,frame.active,frame.hovered,false) end
end
local function active(frame,value)
    value=not not value
    frame.active=value; Skin.ButtonState(frame,value,frame.hovered,false)
end
local function measure(label, text, width, x, y)
    label:ClearAllPoints(); label:SetPoint("TOPLEFT", x, -y); label:SetWidth(math.max(20, width))
    -- Pooled supply labels have fixed heights. Release those bounds before
    -- measuring a new row, especially multi-line reference notes.
    label:SetHeight(0); label:SetWordWrap(true)
    label:SetText(text or "")
    local height=text and text ~= "" and math.ceil(label:GetStringHeight()) or 0
    label:SetHeight(height)
    return height
end
local function showNativeTooltip(block)
    if block.recommendation and block.action then
        GameTooltip:AddLine("Click to Apply Talent",0.83,0.69,0.43,true)
    end
    GameTooltip:Show()
end
local function tooltip(self)
    local block = self.block
    if not block then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    if block.talentTooltip and GameTooltip.SetTalent then
        local talent=block.talentTooltip
        local ok=pcall(GameTooltip.SetTalent,GameTooltip,talent.tree,talent.index,false,false)
        if ok and GameTooltip:NumLines()>0 then showNativeTooltip(block); return end
        GameTooltip:ClearLines()
    end
    if block.spellId then
        local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,"spell:"..block.spellId)
        if ok and GameTooltip:NumLines()>0 then showNativeTooltip(block); return end
        GameTooltip:ClearLines()
    end
    if block.itemId then
        local ok=pcall(GameTooltip.SetHyperlink,GameTooltip,"item:"..block.itemId)
        if ok and GameTooltip:NumLines()>0 then GameTooltip:Show(); return end
        GameTooltip:ClearLines()
    end
    GameTooltip:SetText(block.title or "Reference", 0.83, 0.69, 0.43, 1, true)
    if block.recommendation then
        GameTooltip:AddLine(block.recommendation.name,0.94,0.92,0.87,true)
        GameTooltip:AddLine(block.recommendation.detail,0.72,0.73,0.75,true)
    elseif block.body then GameTooltip:AddLine(block.body, 0.94, 0.92, 0.87, true) end
    if block.meta then GameTooltip:AddLine(block.meta, 0.72, 0.73, 0.75, true) end
    if block.supply then
        GameTooltip:AddLine(block.autoRank and "The best learned recipe is selected automatically from your character's profession skill. Materials are not checked."
            or block.groupSupply and "Bag count includes all listed ranks. Open to choose the rank you use."
            or "Counts include carried bags only. Carry targets are editable suggestions; they do not check profession or recipe requirements.",0.72,0.73,0.75,true)
    end
    if block.action then GameTooltip:AddLine(block.recommendation and "Click to Apply Talent" or "Click for details", 0.83, 0.69, 0.43, true) end
    GameTooltip:Show()
end
local function newBlock(parent)
    local frame = CreateFrame("Button", nil, parent,"BackdropTemplate")
    frame:SetScript("OnClick", function(self) if self.block and self.block.action then addon:Activate(self.block.action) end end)
    frame.title, frame.body, frame.meta = font(frame, 14, WHITE), font(frame, 11, MUTED), font(frame, 11, GOLD)
    frame.icon = frame:CreateTexture(nil, "ARTWORK"); frame.icon:SetSize(34, 34); frame.icon:SetPoint("TOPLEFT", 8, -8)
    frame.icon:SetTexCoord(0.07,0.93,0.07,0.93)
    Skin.Unsnap(frame.icon)
    frame.iconBorder=Skin.IconBorder(frame,frame.icon)
    frame.rule=Skin.Divider(frame); frame.rule:SetPoint("BOTTOMLEFT",8,0); frame.rule:SetPoint("BOTTOMRIGHT",-8,0)
    frame.statusBorder={}
    for _,edge in ipairs({{"TOPLEFT","TOPRIGHT",true},{"BOTTOMLEFT","BOTTOMRIGHT",true},
        {"TOPLEFT","BOTTOMLEFT",false},{"TOPRIGHT","BOTTOMRIGHT",false}}) do
        local line=frame:CreateTexture(nil,"ARTWORK",nil,1)
        line:SetTexture("Interface\\Buttons\\WHITE8x8")
        Skin.Unsnap(line)
        line:SetPoint(edge[1],frame,edge[1],0,0); line:SetPoint(edge[2],frame,edge[2],0,0)
        if edge[3] then line:SetHeight(1) else line:SetWidth(1) end
        frame.statusBorder[#frame.statusBorder+1]=line
    end
    frame.chevron=font(frame,17,GOLD); frame.chevron:SetSize(15,22); frame.chevron:SetPoint("RIGHT",-10,0); frame.chevron:SetText(">")
    frame.iconHit = CreateFrame("Button", nil, frame); frame.iconHit:SetAllPoints(frame.icon); frame.iconHit:EnableMouse(true)
    frame.iconHit:SetScript("OnClick", function() if frame.block and frame.block.action then addon:Activate(frame.block.action) end end)
    frame.iconHit:SetScript("OnEnter", function(self)
        tooltip(frame)
    end)
    frame.iconHit:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame:EnableMouse(true)
    frame:SetScript("OnEnter",function(self)
        tooltip(self)
    end)
    frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
    frame.columns = {}
    frame.fields = {}
    frame.count=font(frame,14,WHITE); frame.count:SetJustifyH("CENTER")
    frame.stock=font(frame,12,MUTED)
    frame.priority=font(frame,10,MUTED)
    frame.stockTrack=frame:CreateTexture(nil,"ARTWORK",nil,-1); frame.stockTrack:SetTexture("Interface\\Buttons\\WHITE8x8")
    frame.stockTrack:SetVertexColor(0.06,0.07,0.055,1); frame.stockTrack:SetSize(60,3)
    frame.stockFill=frame:CreateTexture(nil,"ARTWORK"); frame.stockFill:SetTexture("Interface\\Buttons\\WHITE8x8"); frame.stockFill:SetHeight(3)
    frame.choose=button(frame,"Use",74,function()
        addon:CommitInputs(); addon:SelectSupplyRank(frame.block.rankFamily,frame.block.itemId)
    end)
    frame.quantity=CreateFrame("EditBox",nil,frame,"BackdropTemplate")
    local edit=frame.quantity
    Skin.Paint(edit,"edit"); edit:SetFont(STANDARD_TEXT_FONT,14,""); edit:SetTextColor(unpack(WHITE))
    edit:SetAutoFocus(false); edit:SetNumeric(true); edit:SetMaxLetters(5); edit:SetJustifyH("CENTER")
    edit:SetScript("OnEditFocusLost",function(self)
        if not self.cancelCommit then addon:SetCarryTarget(self.targetKey,self:GetText()) end
    end)
    edit:SetScript("OnEnterPressed",function(self) self:ClearFocus(); addon:Refresh() end)
    edit:SetScript("OnEscapePressed",function(self)
        self.cancelCommit=true; self:ClearFocus(); self.cancelCommit=nil; addon:Refresh()
    end)
    edit:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Carry target",0.83,0.69,0.43,1,true)
        GameTooltip:AddLine("Type a quantity and press Enter. Use 0 to skip restocking; clear the box to restore the suggested amount.",0.94,0.92,0.87,true); GameTooltip:Show()
    end)
    edit:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return frame
end
local renderBlocks
local npcColumnStarts={0,0.10,0.55,0.80}
local npcColumnEnds={0.09,0.54,0.79,1}
local talentColumnStarts={0,0.08,0.53,0.64,0.83}
local talentColumnEnds={0.07,0.52,0.63,0.82,1}
local spellColumnStarts={0,0.43,0.55,0.70}
local spellColumnEnds={0.42,0.54,0.69,1}
local function placeSpellCell(label,text,index,width,y,header)
    local usable=width-24
    local inset=index==1 and not header and 32 or 0
    measure(label,text,usable*(spellColumnEnds[index]-spellColumnStarts[index])-inset,
        12+usable*spellColumnStarts[index]+inset,y)
    label:SetWordWrap(false); label:SetHeight(18)
end
local function placeTalentCell(label,text,index,width,y,header)
    local usable=width-24
    local inset=index==2 and not header and 32 or 0
    measure(label,text,usable*(talentColumnEnds[index]-talentColumnStarts[index])-inset,
        12+usable*talentColumnStarts[index]+inset,y)
    label:SetWordWrap(false); label:SetHeight(18)
end
local function placeNPCCell(label,text,index,width,y)
    local usable=width-40
    measure(label,text,usable*(npcColumnEnds[index]-npcColumnStarts[index]),12+usable*npcColumnStarts[index],y)
    label:SetWordWrap(false); label:SetHeight(18)
end
local function renderBlock(frame, block, width)
    frame.block = block; frame:SetWidth(width); frame:Show()
    frame.priority:SetShown(block.supply and block.priority~=nil)
    frame.title:SetFont(STANDARD_TEXT_FONT,block.supply and 14 or 15,"")
    frame.meta:SetFont(STANDARD_TEXT_FONT,11,"")
    frame.icon:SetSize(34,34)
    frame.body:SetFont(STANDARD_TEXT_FONT,block.supply and 11 or 12,"")
    frame.title:SetWordWrap(true); frame.body:SetWordWrap(true)
    frame.count:SetFont(STANDARD_TEXT_FONT,14,"")
    frame.body:SetTextColor(unpack(block.guideTone and WHITE or MUTED))
    frame.body:SetJustifyH("LEFT")
    frame.stock:SetJustifyH("LEFT")
    if frame.recommendationName then frame.recommendationName:Hide(); frame.recommendationDetail:Hide() end
    if frame.carryLabel then frame.carryLabel:Hide() end
    for _,cell in ipairs(frame.npcCells or {}) do cell:Hide() end
    for _,cell in ipairs(frame.talentCells or {}) do cell:Hide() end
    for _,cell in ipairs(frame.spellCells or {}) do cell:Hide() end
    if frame.quantity:HasFocus() and (frame.quantity.targetKey~=block.targetKey
        or not block.quantityEditor) then frame.quantity:ClearFocus() end
    frame.count:Hide(); frame.stock:SetShown(block.supply and not block.pickRank); frame.quantity:SetShown(block.quantityEditor==true)
    frame.choose:SetShown(block.supply and block.pickRank)
    local paintedRow=block.supply or (block.action and not block.columns)
    Skin.Paint(frame,(block.plain or block.quantityEditor) and "note" or block.supply and "row" or not block.columns and "card" or "note")
    frame.rule:Hide()
    for _,edge in ipairs(frame.statusBorder) do edge:SetShown(block.supply) end
    frame.chevron:SetShown(block.action and not block.supply and not block.columns)
    frame.stockTrack:SetShown(block.supply and not block.pickRank)
    frame.stockFill:Hide()
    frame.title:SetTextColor(unpack(block.action and GOLD or WHITE))
    Skin.Hover(frame,block.action~=nil)
    Skin.Hover(frame.iconHit,block.action~=nil)
    if block.action then frame.iconHit:GetHighlightTexture():SetAllPoints(frame) end
    for _, col in ipairs(frame.columns) do col:Hide() end
    for _, field in ipairs(frame.fields) do field:Hide() end
    if block.spellColumns then
        frame.title:Hide(); frame.body:Hide(); frame.meta:Hide(); frame.chevron:Hide()
        frame.spellCells=frame.spellCells or {}
        Skin.Paint(frame,"note"); Skin.Hover(frame,true)
        frame.icon:Show(); frame.iconHit:Show(); frame.iconBorder:Show()
        local texture=type(block.icon)=="string" and block.icon:match("([^/]+)%.%w+$")
        frame.icon:SetTexture(texture and ("Interface\\Icons\\"..texture) or block.icon or 134400)
        frame.icon:SetSize(24,24); frame.icon:ClearAllPoints(); frame.icon:SetPoint("TOPLEFT",12,-4)
        for i,value in ipairs(block.spellColumns) do
            local cell=frame.spellCells[i]
            if not cell then cell=font(frame,12,i==1 and WHITE or MUTED); frame.spellCells[i]=cell end
            cell:Show(); placeSpellCell(cell,value,i,width,7)
        end
        frame:SetHeight(32); return 32
    end
    if block.talentColumns then
        frame.title:Hide(); frame.body:Hide(); frame.meta:Hide(); frame.chevron:Hide()
        frame.talentCells=frame.talentCells or {}
        Skin.Paint(frame,"note"); Skin.Hover(frame,true)
        frame.icon:Show(); frame.iconHit:Show(); frame.iconBorder:Show()
        frame.icon:SetTexture(block.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        frame.icon:SetSize(24,24); frame.icon:ClearAllPoints()
        frame.icon:SetPoint("TOPLEFT",12+(width-24)*talentColumnStarts[2],-4)
        for i,value in ipairs(block.talentColumns) do
            local cell=frame.talentCells[i]
            if not cell then cell=font(frame,12,i==2 and WHITE or MUTED); frame.talentCells[i]=cell end
            cell:Show(); placeTalentCell(cell,value,i,width,7)
        end
        frame:SetHeight(32)
        return 32
    end
    if block.quantityEditor then
        frame.title:Show(); frame.body:Hide(); frame.meta:Hide()
        frame.icon:Hide(); frame.iconHit:Hide(); frame.iconBorder:Hide()
        frame.title:SetFont(STANDARD_TEXT_FONT,12,"")
        measure(frame.title,"Keep on hand",110,0,8)
        frame.quantity.targetKey=block.targetKey
        if not frame.quantity:HasFocus() then frame.quantity:SetText(tostring(block.target or "")) end
        frame.quantity:ClearAllPoints(); frame.quantity:SetPoint("TOPLEFT",120,0); frame.quantity:SetSize(48,28)
        frame:SetHeight(28); return 28
    end
    if block.npcColumns then
        frame.title:Hide(); frame.body:Hide(); frame.meta:Hide()
        frame.icon:Hide(); frame.iconHit:Hide(); frame.iconBorder:Hide()
        frame.npcCells=frame.npcCells or {}
        Skin.Paint(frame,"note")
        for i,value in ipairs(block.npcColumns) do
            local cell=frame.npcCells[i]
            if not cell then cell=font(frame,i==2 and 13 or 12,i==2 and WHITE or MUTED); frame.npcCells[i]=cell end
            cell:Show(); placeNPCCell(cell,value,i,width,9)
        end
        frame:SetHeight(36)
        return 36
    end
    if block.columns then
        frame.title:Hide(); frame.body:Hide(); frame.meta:Hide(); frame.icon:Hide(); frame.iconHit:Hide(); frame.iconBorder:Hide()
        local count = width >= 570 and #block.columns or 1
        local colWidth = (width - (count - 1) * 14) / count
        local y, rowHeight = 0, 0
        for index, entries in ipairs(block.columns) do
            local column = frame.columns[index]
            if not column then column=CreateFrame("Frame", nil, frame); column.blocks={}; frame.columns[index]=column end
            column:Show(); column:ClearAllPoints(); column:SetPoint("TOPLEFT", ((index - 1) % count) * (colWidth + 14), -y)
            column:SetWidth(colWidth)
            local height = renderBlocks(column, entries, colWidth)
            column:SetHeight(height); rowHeight=math.max(rowHeight, height)
            if index % count == 0 or index == #block.columns then
                -- Keep paired guide tiles the same height despite wrapped text.
                for previous=math.floor((index-1)/count)*count+1,index do
                    local columnFrame=frame.columns[previous]
                    local entriesHere=block.columns[previous]
                    if #entriesHere==1 and entriesHere[1].guideTone=="link" then
                        columnFrame:SetHeight(rowHeight)
                        columnFrame.blocks[1]:SetHeight(rowHeight)
                    end
                end
                y=y+rowHeight; rowHeight=0
            end
        end
        frame:SetHeight(y); return y
    end
    frame.title:Show(); frame.body:Show(); frame.meta:Show()
    local icon = block.itemId ~= nil or block.icon ~= nil
    frame.icon:SetShown(icon); frame.iconHit:SetShown(icon); frame.iconBorder:SetShown(icon)
    if icon then
        local texture = type(block.icon)=="string" and block.icon:match("([^/]+)%.%w+$")
        local native=type(block.icon)=="number" and block.icon or nil
        local getIcon=C_Item and C_Item.GetItemIconByID or GetItemIcon
        if getIcon and block.itemId then local ok,value=pcall(getIcon,block.itemId); if ok then native=value end end
        native=native or (texture and ("Interface\\Icons\\" .. texture)) or "Interface\\Icons\\INV_Misc_QuestionMark"
        if not frame.icon:SetTexture(native) then frame.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
    end
    local x = block.textInset or (icon and 52 or 12) + (block.child and 8 or 0)
    local available, y = width-x-(block.supply and 210 or block.action and 32 or 14), block.supply and 8 or 12
    frame.title:SetTextColor(unpack(block.titleColor or (block.supply and WHITE or GOLD)))
    local height
    if block.supply then
        local nameWidth=math.floor(available*0.42)
        local titleHeight=measure(frame.title,block.title,nameWidth,x,y)
        local bodyHeight=measure(frame.body,block.body,available-nameWidth-16,x+nameWidth+16,y)
        y=y+math.max(titleHeight,bodyHeight)+3
    else
        height=measure(frame.title, block.title, available, x, y); if height>0 then y=y+height+3 end
        height=measure(frame.body, block.body, available, x, y); if height>0 then y=y+height+3 end
    end
    height=measure(frame.meta, block.meta, available, x, y); if height>0 then y=y+height+2 end
    if block.fields then
        local gap, fieldWidth, column, rowHeight = 20, (width-44)/2, 0, 0
        y=y+4
        for index, data in ipairs(block.fields) do
            local field=frame.fields[index]
            if not field then
                field=CreateFrame("Frame",nil,frame)
                field.label=font(field,11,GOLD); field.value=font(field,12,WHITE)
                field:SetScript("OnEnter",tooltip)
                field:SetScript("OnLeave",function() GameTooltip:Hide() end)
                frame.fields[index]=field
            end
            local wide=block.singleFieldColumn or data.wide or data.label=="Effect" or data.label=="Materials" or data.label=="Notes"
            if wide and column>0 then y=y+rowHeight+14; column=0; rowHeight=0 end
            local cellWidth=wide and width-24 or fieldWidth
            field:Show(); field:ClearAllPoints(); field:SetPoint("TOPLEFT",12+column*(fieldWidth+gap),-y)
            field:SetWidth(cellWidth)
            field.block={title=data.label,body=data.value,itemId=data.itemId}
            field:EnableMouse(data.itemId~=nil)
            local fieldHeight=measure(field.label,data.label,cellWidth,0,0)+4
            fieldHeight=fieldHeight+measure(field.value,data.value,cellWidth,0,fieldHeight)
            field:SetHeight(fieldHeight)
            rowHeight=math.max(rowHeight,fieldHeight); column=column+1
            if wide or column==2 then y=y+rowHeight+14; column=0; rowHeight=0 end
        end
        if column>0 then y=y+rowHeight+14 end
    end
    if block.supply then
        local color=STOCK_COLORS[block.count==0 and "missing" or block.status] or MUTED
        frame.count:ClearAllPoints(); frame.count:SetPoint("TOPLEFT",width-204,-12); frame.count:SetSize(52,22)
        frame.count:SetTextColor(unpack(block.count and block.count>0 and WHITE or MUTED))
        frame.count:SetText(block.count~=nil and tostring(block.count) or "?")
        frame.quantity:ClearAllPoints(); frame.quantity:SetPoint("TOPLEFT",width-142,-8); frame.quantity:SetSize(42,28)
        frame.quantity.targetKey=block.targetKey
        if not frame.quantity:HasFocus() then frame.quantity:SetText(tostring(block.target or "")) end
        local label=block.count==nil and "Unknown" or block.count==0 and "Missing"
            or ("("..block.count.."/"..(block.target or "?")..")")
        frame.stock:SetTextColor(unpack(color)); measure(frame.stock,label,84,width-88,9)
        for _,edge in ipairs(frame.statusBorder) do edge:SetVertexColor(color[1],color[2],color[3],0.7) end
        frame.stockTrack:ClearAllPoints(); frame.stockTrack:SetPoint("TOPLEFT",width-88,-29)
        if block.count==0 and not block.pickRank then
            frame.stockFill:Show(); frame.stockFill:ClearAllPoints(); frame.stockFill:SetPoint("TOPLEFT",frame.stockTrack,"TOPLEFT",0,0)
            frame.stockFill:SetWidth(60); frame.stockFill:SetVertexColor(0.9,0.12,0.12,1)
        elseif block.target and block.target>0 and block.count and block.count>0 and not block.readOnlyTarget then
            frame.stockFill:Show(); frame.stockFill:ClearAllPoints(); frame.stockFill:SetPoint("TOPLEFT",frame.stockTrack,"TOPLEFT",0,0)
            frame.stockFill:SetWidth(60*math.min(1,block.count/block.target)); frame.stockFill:SetVertexColor(color[1],color[2],color[3],0.9)
        end
        frame.choose:ClearAllPoints(); frame.choose:SetPoint("TOPLEFT",width-86,-8)
    end
    y=block.supply and 46 or (math.max(block.action and 40 or icon and 42 or 0, y)+(block.plain and -3 or 9))
    frame:SetHeight(y)
    frame.icon:ClearAllPoints()
    if block.supply then
        frame.title:SetHeight(math.min(frame.title:GetHeight(),y-4))
        frame.body:SetHeight(math.min(frame.body:GetHeight(),y-4))
        frame.stock:SetHeight(math.min(frame.stock:GetHeight(),y-10))
        frame.icon:SetPoint("LEFT",frame,"LEFT",6,0)
        local function center(element,left,offset)
            element:ClearAllPoints(); element:SetPoint("LEFT",frame,"LEFT",left,offset or 0)
        end
        center(frame.title,x,block.priority and 7 or 0)
        if block.priority then
            frame.title:SetHeight(20)
            frame.priority:SetSize(math.floor(available*0.42),14)
            center(frame.priority,x,-11); frame.priority:SetText(block.priority)
        end
        center(frame.body,x+math.floor(available*0.42)+16)
        center(frame.count,width-204)
        center(frame.quantity,width-142)
        center(frame.choose,width-86)
        center(frame.stock,width-88,frame.stockTrack:IsShown() and 3.5 or 0)
        frame.stockTrack:ClearAllPoints(); frame.stockTrack:SetPoint("TOPLEFT",frame.stock,"BOTTOMLEFT",0,-4)
    else
        frame.icon:SetPoint("TOPLEFT",8,-8)
    end
    -- Pooled rows may retain the same size, so OnSizeChanged is not guaranteed.
    -- Lay out the artwork only after the row's final height and anchors settle.
    if paintedRow then Skin.RowArtwork(frame) end
    if block.supply then
        -- Classification and stock share a right-hand column. Quantity editing
        -- is available only after opening the item or its rank details.
        frame:SetHeight(56); y=56
        frame.title:SetFont(STANDARD_TEXT_FONT,14,"")
        measure(frame.title,block.title,width-150,52,8); frame.title:SetHeight(18); frame.title:SetWordWrap(false)
        frame.body:SetFont(STANDARD_TEXT_FONT,12,"")
        measure(frame.body,block.body,width-150,52,30); frame.body:SetHeight(16); frame.body:SetWordWrap(false)
        frame.icon:ClearAllPoints(); frame.icon:SetPoint("TOPLEFT",8,-11)
        frame.priority:SetFont(STANDARD_TEXT_FONT,11,"")
        frame.priority:ClearAllPoints(); frame.priority:SetPoint("TOPRIGHT",-8,-5); frame.priority:SetSize(84,16); frame.priority:SetJustifyH("RIGHT")
        frame.stock:ClearAllPoints(); frame.stock:SetPoint("TOPRIGHT",-8,-26); frame.stock:SetSize(84,16); frame.stock:SetJustifyH("RIGHT")
        frame.choose:ClearAllPoints(); frame.choose:SetPoint("TOPRIGHT",-8,-30)
        frame.stockTrack:ClearAllPoints(); frame.stockTrack:SetPoint("BOTTOMRIGHT",-8,7)
        Skin.RowArtwork(frame)
    elseif frame.carryLabel then frame.carryLabel:Hide() end
    if block.recommendation then
        local rec=block.recommendation
        if not frame.recommendationName then
            frame.recommendationName=font(frame,14,WHITE)
            frame.recommendationDetail=font(frame,12,MUTED)
        end
        frame.recommendationName:SetText(rec.name)
        frame.recommendationDetail:SetText(rec.detail)
        local detailWidth=math.min(math.max(frame.recommendationName:GetStringWidth(),frame.recommendationDetail:GetStringWidth())+2,math.floor(width*0.56)-72)
        local talentX=width-72-detailWidth
        measure(frame.title,block.title,talentX-24,12,10)
        frame.body:SetFont(STANDARD_TEXT_FONT,11,"")
        local headerBottom=10+frame.title:GetHeight()+3
        local summaryHeight=measure(frame.body,rec.summary,talentX-24,12,headerBottom)
        local talentY=10
        frame.recommendationName:Show(); frame.recommendationDetail:Show()
        local nameHeight=measure(frame.recommendationName,rec.name,detailWidth,talentX+42,talentY)
        local detailHeight=measure(frame.recommendationDetail,rec.detail,detailWidth,talentX+42,talentY+nameHeight+4)
        frame.icon:ClearAllPoints(); frame.icon:SetPoint("TOPLEFT",talentX,-talentY)
        frame.meta:Hide()
        y=math.max(headerBottom+summaryHeight,talentY+math.max(34,nameHeight+4+detailHeight))+10
        frame:SetHeight(y)
    end
    if block.guideTone then
        local tone=block.guideTone
        local color=tone=="danger" and {0.96,0.55,0.40} or tone=="tool" and {0.48,0.78,0.73} or GOLD
        frame.title:SetTextColor(unpack(color))
        if tone~="plain" and tone~="link" then
            frame:SetBackdropColor(tone=="danger" and 0.115 or 0.045,tone=="danger" and 0.055 or 0.075,tone=="danger" and 0.04 or 0.085,1)
            for i,edge in ipairs(frame.statusBorder) do
                edge:Show(); edge:SetVertexColor(color[1],color[2],color[3],0.3)
            end
        end
    end
    return y
end
renderBlocks = function(parent, blocks, width)
    local y=0
    local pending
    for index, block in ipairs(blocks) do
        local frame=parent.blocks[index]
        if not frame then frame=newBlock(parent); parent.blocks[index]=frame end
        local paired=parent.gridStart and index>=parent.gridStart and (not block.supply or parent.supplyGrid) and not block.columns and not block.fields
        if pending and not paired then y=y+pending:GetHeight()+12; pending=nil end
        local cellWidth=paired and (width-12)/2 or width
        frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",pending and cellWidth+12 or 0,-y)
        frame.supplyTile=block.supply and paired
        local height=renderBlock(frame,block,cellWidth)
        if pending then
            height=math.max(height,pending:GetHeight()); pending:SetHeight(height); frame:SetHeight(height)
            y=y+height+12; pending=nil
        elseif paired and index<#blocks then pending=frame
        else y=y+height+((block.talentColumns or block.spellColumns) and 1 or (block.supply and not paired or block.npcColumns) and 4 or 12) end
        if block.supply then
            local shade=index%2==0 and 0.075 or 0.045
            frame:SetBackdropColor(shade,shade+0.009,shade+0.014,1)
        elseif block.npcColumns or block.talentColumns or block.spellColumns then
            local shade=index%2==0 and 0.06 or 0.035
            frame:SetBackdropColor(shade,shade+0.008,shade+0.012,1)
        end
    end
    for index=#blocks+1,#parent.blocks do parent.blocks[index]:Hide() end
    return math.max(1,y-(blocks[#blocks] and ((blocks[#blocks].talentColumns or blocks[#blocks].spellColumns) and 1 or (blocks[#blocks].supply and not parent.supplyGrid or blocks[#blocks].npcColumns) and 4 or 12) or 0))
end
local function renderCard(frame, data, width)
    frame:Show(); frame:SetWidth(width)
    if frame.detailQuantity and not data.quantityRecord then
        frame.detailQuantity.quantity:ClearFocus(); frame.detailQuantity:Hide()
    end
    if frame.defaultChoice then frame.defaultChoice:Hide() end
    if frame.itemHeading then frame.itemHeading:Hide() end
    Skin.Paint(frame,"note")
    frame.title:SetFont(STANDARD_TEXT_FONT,frame.firstCard and not data.supplyTable and 22 or 15,"")
    frame.title:Show(); frame.note:Show()
    local y=(frame.firstCard or data.spellTable) and 0 or 14
    local headerTextWidth=0
    if data.headerText and not frame.headerText then frame.headerText=font(frame,14,GOLD) end
    if frame.headerText then
        frame.headerText:SetShown(data.headerText~=nil)
        if data.headerText then
            frame.headerText:SetText(data.headerText)
            headerTextWidth=math.min(math.ceil(frame.headerText:GetStringWidth())+4,width*0.55)
            frame.headerText:ClearAllPoints(); frame.headerText:SetPoint("TOPRIGHT",-14,-y-5)
            frame.headerText:SetSize(headerTextWidth,20); frame.headerText:SetJustifyH("RIGHT"); frame.headerText:SetWordWrap(false)
        end
    end
    if data.headerAction and not frame.headerButton then
        frame.headerButton=button(frame,"",112,function(self) addon:Activate(self.action) end)
    end
    if frame.headerButton then
        frame.headerButton:SetShown(data.headerAction~=nil)
        if data.headerAction then
            frame.headerButton.action=data.headerAction.action
            frame.headerButton.label:SetText(data.headerAction.label)
            frame.headerButton:ClearAllPoints(); frame.headerButton:SetPoint("TOPRIGHT",-14,-y)
        end
    end
    if data.itemLayout then
        frame.title:Hide(); frame.note:Hide()
    else
        local extraHeaderWidth=data.zoneRangeToggle and addon.window.atLevel:GetWidth()+8 or 0
        y=y+math.max(data.headerAction and 24 or 0,measure(frame.title, data.title, width-(data.headerAction and 140 or headerTextWidth>0 and headerTextWidth+30 or 12)-extraHeaderWidth, 0, y))+5
        y=y+measure(frame.note, data.note, width-12, 0, y)+(data.spellTable and 3 or 12)
    end
    for _,control in ipairs(frame.npcFilters or {}) do control:Hide() end
    for _,label in ipairs(frame.npcHeaders or {}) do label:Hide() end
    for _,label in ipairs(frame.talentHeaders or {}) do label:Hide() end
    for _,label in ipairs(frame.spellHeaders or {}) do label:Hide() end
    if data.spellTable then
        frame.spellHeaders=frame.spellHeaders or {}
        for i,text in ipairs({"SPELL","RANK","COST","TRAINING"}) do
            local label=frame.spellHeaders[i]
            if not label then label=font(frame,10,MUTED); frame.spellHeaders[i]=label end
            label:Show(); placeSpellCell(label,text,i,width-12,y,true)
        end
        y=y+22
    end
    if data.talentTable then
        frame.talentHeaders=frame.talentHeaders or {}
        for i,text in ipairs({"LEVEL","TALENT","RANK","TREE","STATUS"}) do
            local label=frame.talentHeaders[i]
            if not label then label=font(frame,10,MUTED); frame.talentHeaders[i]=label end
            label:Show(); placeTalentCell(label,text,i,width-12,y,true)
        end
        y=y+26
    end
    if data.npcTable then
        frame.npcFilters=frame.npcFilters or {}; frame.npcHeaders=frame.npcHeaders or {}
        local filters={{"All","all"},{"Rares","rare"},{"Elites","elite"},{"World bosses","boss"},{"Dangerous","danger"}}
        local buttonWidth=(width-12-24)/5
        for i,filter in ipairs(filters) do
            local control=frame.npcFilters[i]
            if not control then
                control=button(frame,filter[1],buttonWidth,function(self)
                    addon:Activate({kind="mapAdvisor",command="filter",id=self.category})
                end)
                Skin.Button(control,"category"); frame.npcFilters[i]=control
            end
            control.category=filter[2]; control:Show(); control:SetWidth(buttonWidth)
            control:ClearAllPoints(); control:SetPoint("TOPLEFT",(i-1)*(buttonWidth+6),-y)
            active(control,(addon.state.zoneNPCFilter or "all")==filter[2])
        end
        y=y+42
        for i,text in ipairs({"LEVEL","NPC","TYPE","LOCATION"}) do
            local label=frame.npcHeaders[i]
            if not label then label=font(frame,10,MUTED); frame.npcHeaders[i]=label end
            label:Show(); placeNPCCell(label,text,i,width-12,y)
        end
        y=y+24
    end
    frame.content:ClearAllPoints(); frame.content:SetPoint("TOPLEFT",0,-y); frame.content:SetWidth(width-12)
    frame.content.supplyGrid=data.supplyTable
    frame.content.gridStart=data.supplyTable and 1 or frame.gridStart
    if data.fullWidth then frame.content.gridStart=nil end
    if data.itemLayout then
        -- Keep the item, its quantity and alternatives together on the left;
        -- the labeled reference details get their own column on the right.
        local contentWidth=width-12
        local leftWidth=math.floor((contentWidth-16)/2)
        local rightWidth=contentWidth-leftWidth-16
        local leftHeight,rightHeight=0,0
        if data.itemSectionTitle then
            if not frame.itemHeading then frame.itemHeading=font(frame.content,15,GOLD) end
            frame.itemHeading:Show()
            leftHeight=measure(frame.itemHeading,data.itemSectionTitle,leftWidth,0,0)+8
        end
        for i,block in ipairs(data.blocks) do
            local row=frame.content.blocks[i]
            if not row then row=newBlock(frame.content); frame.content.blocks[i]=row end
            local details=block.fields~=nil
            row.supplyTile=false; row:ClearAllPoints()
            row:SetPoint("TOPLEFT",details and leftWidth+16 or 0,-(details and rightHeight or leftHeight))
            local height=renderBlock(row,block,details and rightWidth or leftWidth)
            if details then rightHeight=rightHeight+height+12 else leftHeight=leftHeight+height+(block.plain and 6 or 12) end
            if i==1 and data.quantityRecord then
                if not frame.detailQuantity then frame.detailQuantity=newBlock(addon.window) end
                local editor=frame.detailQuantity
                renderBlock(editor,data.quantityRecord,168)
            end
            if i==1 and data.defaultItem then
                if not frame.defaultChoice then
                    frame.defaultChoice=button(addon.window,"",130,function(self)
                        addon:Activate({kind="supplyDefault",item=self.item})
                    end)
                end
                local choice=frame.defaultChoice
                choice.item=data.defaultItem; choice.label:SetText("Set as default")
                choice:SetEnabled(not data.isDefault); choice:SetShown(not data.isDefault); choice:ClearAllPoints()
                choice:SetPoint("TOPLEFT",addon.window.back,"TOPRIGHT",8,0)
            end
            if i==1 and data.quantityRecord then
                frame.detailQuantity:ClearAllPoints()
                frame.detailQuantity:SetPoint("TOPRIGHT",addon.window.priorityChoice,"TOPLEFT",-8,0)
            end
        end
        for i=#data.blocks+1,#frame.content.blocks do frame.content.blocks[i]:Hide() end
        local height=math.max(leftHeight,rightHeight)-12
        frame.content:SetHeight(height); y=y+height+8; frame:SetHeight(y)
        return y
    end
    local height=renderBlocks(frame.content, data.blocks, width-12)
    frame.content:SetHeight(height); y=y+height+(data.spellTable and 4 or 8); frame:SetHeight(y)
    return y
end

function addon:SaveWindow()
    if not self.window or not self.db then return end
    local f, w = self.window, self.db.window
    w.width, w.height = f:GetWidth(), f:GetHeight()
    local x, y = f:GetCenter(); local cx, cy = UIParent:GetCenter()
    local scale=f:GetEffectiveScale()/UIParent:GetEffectiveScale()
    if x and cx then w.x, w.y = x*scale-cx, y*scale-cy end
end
function addon:RestoreWindow()
    local f, w = self.window, self.db.window
    if not f then return end
    local function finite(n, fallback) return type(n)=="number" and n==n and math.abs(n)<100000 and n or fallback end
    local scale=math.max(0.1,math.min(1,(UIParent:GetWidth()-24)/Skin.windowWidth,(UIParent:GetHeight()-24)/Skin.windowHeight))
    f:SetScale(scale); f:SetSize(Skin.windowWidth,Skin.windowHeight)
    w.width,w.height=Skin.windowWidth,Skin.windowHeight
    f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", finite(w.x,0)/scale, finite(w.y,0)/scale)
end
function addon:CreateWindow()
    if self.window then return end
    local f=CreateFrame("Frame", "HardcoreBuddyWindow", UIParent, "BackdropTemplate")
    self.window=f
    f:Hide(); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(20); f:SetClampedToScreen(true); f:SetMovable(true); f:SetResizable(false); f:EnableMouse(true)
    Skin.Paint(f,"window"); f.chrome=Skin.DecorateWindow(f)
    f.title=font(f, 26, GOLD); f.title:SetText("HardcoreBuddy |cffa6a68fv"..addon.version.."|r")
    f.author=font(f,11,MUTED); f.author:SetText("Author: CeaserXL (CXL)")
    f.subtitle=font(f, 12, WHITE)
    f.motto=font(f,10,MUTED); f.motto:SetText("ONE LIFE. STAY PREPARED.")
    local drag=CreateFrame("Frame",nil,f); f.drag=drag; drag:SetPoint("TOPLEFT"); drag:SetSize(1,57)
    drag:EnableMouse(true); drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart",function() f:StartMoving() end)
    drag:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SaveWindow() end)
    f.close=button(f,"X",26,function() f:Hide() end); f.close:SetPoint("TOPRIGHT",-17,-17)
    f.mode=button(f,"Edit Character",184,function() self:TogglePreview() end)
    f.mode.label:SetWordWrap(false)
    f.class=button(f,"Hunter",104,function() f.classMenu:SetShown(not f.classMenu:IsShown()) end)
    f.classLabel=font(f.class,12,GOLD); f.classLabel:SetText("Class")
    f.classLabel:SetSize(104,16); f.classLabel:SetPoint("BOTTOM",f.class,"TOP",0,3); f.classLabel:SetJustifyH("CENTER")
    f.levelGroup=CreateFrame("Frame",nil,f); f.levelGroup:SetSize(142,26)
    f.levelLabel=font(f.levelGroup,12,GOLD); f.levelLabel:SetSize(44,16); f.levelLabel:SetWordWrap(false); f.levelLabel:SetJustifyH("CENTER"); f.levelLabel:SetText("Level")
    f.minus=button(f.levelGroup,"-",25,function() self:CommitInputs(); self:SetLevel(self.db.profile.level-1) end); f.minus:SetPoint("TOPLEFT",36,0)
    f.plus=button(f.levelGroup,"+",25,function() self:CommitInputs(); self:SetLevel(self.db.profile.level+1) end); f.plus:SetPoint("TOPLEFT",117,0)
    f.level=CreateFrame("EditBox",nil,f.levelGroup,"BackdropTemplate"); f.level:SetSize(38,28); f.level:SetPoint("TOPLEFT",70,0); f.level:SetAutoFocus(false)
    f.levelLabel:SetPoint("BOTTOM",f.level,"TOP",0,3)
    Skin.Paint(f.level,"edit"); f.level:SetFont(STANDARD_TEXT_FONT,13,""); f.level:SetTextColor(unpack(WHITE))
    f.level:SetNumeric(true); f.level:SetMaxLetters(3); f.level:SetJustifyH("CENTER")
    local function commit(edit)
        if self.db.profile.mode == "preview" then self:SetLevel(edit:GetText()) end
    end
    f.level:SetScript("OnEnterPressed",function(edit) commit(edit); edit:ClearFocus() end)
    f.level:SetScript("OnEditFocusLost",commit)
    f.level:SetScript("OnEscapePressed",function(edit) edit:SetText(tostring(self:GetContext().level)); edit:ClearFocus() end)
    f.level:SetScript("OnArrowPressed",function(_,key)
        if self.db.profile.mode == "preview" and (key=="UP" or key=="DOWN") then commit(f.level); self:SetLevel(self.db.profile.level+(key=="UP" and 1 or -1)) end
    end)
    f.tabs={}
    for _,tab in ipairs({{"supplies","Supplies",100},{"training","Companion",100},{"deaths","Death Journal",122},{"instances","Dungeons & Raids",154},{"settings","Settings",100}}) do
        local id=tab[1]
        local b=button(f,tab[2],tab[3],function() self:Navigate(id) end); b.view=id; Skin.Button(b,"tab"); f.tabs[#f.tabs+1]=b
    end
    f.back=button(f,"< Back",80,function() self:Back() end)
    f.currentInstance=button(f,"",500,function() self:OpenCurrentInstance() end)
    f.currentInstance.label:Hide()
    f.currentInstance.heading=font(f.currentInstance,11,GOLD)
    f.currentInstance.heading:SetPoint("TOPLEFT",14,-7)
    f.currentInstance.name=font(f.currentInstance,15,WHITE)
    f.currentInstance.name:SetPoint("TOPLEFT",14,-23)
    f.currentInstance.hint=font(f.currentInstance,12,GOLD)
    f.currentInstance.hint:SetPoint("RIGHT",-14,0)
    f.currentInstance.hint:SetSize(146,18); f.currentInstance.hint:SetJustifyH("RIGHT")
    f.currentInstance:Hide()
    f.filters={}
    f.sidebar=CreateFrame("Frame",nil,f,"BackdropTemplate"); Skin.Paint(f.sidebar,"card")
    f.sidebarTitle=font(f.sidebar,11,GOLD); f.sidebarTitle:SetPoint("TOPLEFT",12,-12); f.sidebarTitle:SetSize(120,18)
    f.sidebarNote=font(f.sidebar,11,MUTED); f.sidebarNote:SetPoint("BOTTOMLEFT",12,14); f.sidebarNote:SetPoint("BOTTOMRIGHT",-12,14); f.sidebarNote:SetHeight(48)
    f.searchLabel=font(f,12,MUTED); f.searchLabel:SetText("Search")
    f.searchLabel:SetWordWrap(false); f.searchLabel:SetJustifyV("MIDDLE")
    f.search=CreateFrame("EditBox",nil,f,"BackdropTemplate"); f.search:SetAutoFocus(false); f.search:SetMaxLetters(100)
    Skin.Paint(f.search,"edit"); f.search:SetFont(STANDARD_TEXT_FONT,12,""); f.search:SetTextColor(unpack(WHITE)); f.search:SetTextInsets(8,8,0,0)
    f.search:SetScript("OnTextChanged",function(edit,userInput)
        if userInput then self.state.query=edit:GetText(); self.state.page=1; self:Refresh(true) end
    end)
    f.search:SetScript("OnEscapePressed",function(edit) edit:ClearFocus() end)
    f.clear=button(f,"Clear",54,function() self.state.query=""; f.search:SetText(""); self.state.page=1; self:Refresh(true) end)
    f.atLevel=button(f,"Any level",112,function()
        if self.state.view=="instances" then self.state.showAllInstances=not self.state.showAllInstances
        elseif self.state.view=="training" and self.document.zoneRecommendations then self.state.showAllZones=not self.state.showAllZones
        elseif self.state.view=="training" and self.state.filter=="Spells" then self.state.showAllFutureSpells=not self.state.showAllFutureSpells
        else self.state.atLevel=not self.state.atLevel end
        self.state.page=1; self:Refresh(true)
    end)

    f.classMenu=CreateFrame("Frame",nil,f,"BackdropTemplate"); f.classMenu:SetSize(132,9*30+12)
    f.classMenu:SetPoint("TOPLEFT",f.class,"BOTTOMLEFT",0,-2); f.classMenu:SetFrameStrata("FULLSCREEN_DIALOG"); f.classMenu:SetFrameLevel(100); Skin.Paint(f.classMenu,"menu"); f.classMenu:Hide()
    for index,class in ipairs(P.classes) do
        local b=button(f.classMenu,class,120,function() f.classMenu:Hide(); self:SetProfile("characterClass",class) end)
        b:SetPoint("TOPLEFT",6,-6-(index-1)*30)
    end
    f.context=font(f,12,WHITE)
    f.scroll=CreateFrame("ScrollFrame", "HardcoreBuddyScrollFrame", f,"UIPanelScrollFrameTemplate")
    f.scroll:EnableMouseWheel(true)
    f.scroll:SetScript("OnMouseWheel",function(scroll,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(scroll:GetVerticalScrollRange(),scroll:GetVerticalScroll()-delta*65)))
    end)
    f.content=CreateFrame("Frame",nil,f.scroll); f.content:SetSize(1,1); f.scroll:SetScrollChild(f.content); f.cards={}
    f.userEntry=CreateFrame("Frame",nil,f); f.userEntry:SetHeight(30)
    local entry=f.userEntry
    entry.input=CreateFrame("EditBox",nil,entry,"BackdropTemplate")
    entry.input:SetSize(300,28); entry.input:SetPoint("TOPLEFT",0,0)
    Skin.Paint(entry.input,"edit"); entry.input:SetFont(STANDARD_TEXT_FONT,13,"")
    entry.input:SetAutoFocus(false); entry.input:SetMaxLetters(512); entry.input:SetTextInsets(8,8,0,0)
    entry.hint=font(entry,12,MUTED); entry.hint:SetPoint("TOPLEFT",0,-4); entry.hint:SetWidth(680)
    local dropHint="Drag an item from your bags anywhere onto this page to add it."
    entry.hint:SetText(dropHint)
    local function receiveItem(box)
        if not entry:IsVisible() or type(GetCursorInfo)~="function" then return end
        local kind,id,link=GetCursorInfo()
        if kind~="item" or not self:UserItemID(id) then return end
        box:SetText(type(link)=="string" and self:UserItemID(link)==id and link or tostring(id))
        box:SetFocus()
        ClearCursor()
    end
    entry.input:EnableMouse(true)
    entry.input:SetScript("OnReceiveDrag",receiveItem)
    entry.input:SetScript("OnMouseDown",receiveItem)
    local function editUser(remove)
        local ok,message=self:EditUserItem(entry.input:GetText(),remove)
        entry.hint:SetText(ok and dropHint or message)
        if ok then entry.input:SetText(""); entry.input:ClearFocus() end
    end
    entry.add=button(entry,"Add item",100,function() editUser(false) end)
    entry.add:SetPoint("TOPLEFT",entry.input,"TOPRIGHT",8,0)
    entry.input:Hide(); entry.add:Hide()
    -- Cover the entire content page only while carrying an item. Ordinary row
    -- clicks, scrolling and Carry edits continue to reach their normal frames.
    local drop=CreateFrame("Frame",nil,f)
    f.userDrop=drop; drop:SetFrameLevel(f:GetFrameLevel()+100); drop:EnableMouse(true); drop:Hide()
    local function acceptDrop()
        if not entry:IsVisible() or type(GetCursorInfo)~="function" then return end
        local kind,id=GetCursorInfo()
        if kind~="item" or not self:UserItemID(id) then return end
        local ok,message=self:EditUserItem(tostring(id),false)
        ClearCursor(); drop:Hide()
        entry.hint:SetText(ok and dropHint or message)
    end
    drop:SetScript("OnReceiveDrag",acceptDrop)
    drop:SetScript("OnMouseDown",acceptDrop)
    f.userRemove=button(f,"Remove item",110,function()
        local item=self.state and self.state.detail and self.state.detail.item
        if item and item.userItem then
            self:EditUserItem(tostring(item.itemId),true)
            self.state={view="supplies",filter="User",page=1}; self.history={}; self:Refresh(true)
        end
    end)
    f.priorityChoice=button(f,"",190,function() self:CyclePriority(f.priorityChoice.item) end)
    f.ammoChoice=button(f,"",200,function()
        local values={"arrows","bullets","thrown","none"}
        for i,value in ipairs(values) do if (self.characterDB.previewAmmo or "arrows")==value then
            self.characterDB.previewAmmo=values[i%#values+1]; break
        end end
        self:Refresh(true)
    end)
    entry.input:SetScript("OnEnterPressed",function() editUser(false) end)
    entry.input:SetScript("OnEscapePressed",function(box) box:ClearFocus() end)
    entry:SetScript("OnHide",function() entry.input:ClearFocus() end)
    f:HookScript("OnSizeChanged",function() if self.db then self.needsLayout=true end end)
    f:SetScript("OnUpdate",function(_,elapsed)
        if f.refreshScrollGeometry then
            f.refreshScrollGeometry=nil
            f.scroll:UpdateScrollChildRect()
        end
        local cursorKind=type(GetCursorInfo)=="function" and GetCursorInfo() or nil
        drop:SetShown(entry:IsVisible() and cursorKind=="item")
        if self.needsRefresh then self.needsRefresh=false; self:Refresh() end
        if self.needsLayout then
            self.layoutElapsed=(self.layoutElapsed or 0)+elapsed
            if self.layoutElapsed>=0.08 then self.layoutElapsed=0; self.needsLayout=false; self:Layout() end
        end
    end)
    f:SetScript("OnHide",function()
        if self.db then self.db.window.visible=false; self:SaveWindow() end
        self:CommitInputs(); f.search:ClearFocus(); f.classMenu:Hide(); GameTooltip:Hide()
    end)
    f:SetScript("OnShow",function() if self.db then self.db.window.visible=true; self:Refresh() end end)
    UISpecialFrames[#UISpecialFrames+1]="HardcoreBuddyWindow"
    self:RestoreWindow()
end
function addon:ToggleWindow()
    self:CreateWindow(); self.window:SetShown(not self.window:IsShown())
end
function addon:CommitInputs()
    local f=self.window
    if not f then return end
    if self.Settings then self.Settings:CommitInputs() end
    f.level:ClearFocus()
    for _,c in ipairs(f.cards or {}) do
        for _,block in ipairs(c.content.blocks or {}) do if block.quantity then block.quantity:ClearFocus() end end
        if c.detailQuantity then c.detailQuantity.quantity:ClearFocus() end
    end
end
function addon:OpenDeaths(section, record)
    if section=="Options" or section=="Appearance" then
        self:OpenSettings(section=="Appearance" and "Death Banner" or "Death Alerts"); return
    end
    self:CreateWindow()
    self:CommitInputs()
    self.state={view="deaths",filter=(section=="Options" or section=="Appearance") and section or "Reports",deathRecord=record,page=1}
    self.history={}
    self.window.classMenu:Hide()
    self.window:Show()
    self:Refresh(true)
end
function addon:Navigate(view)
    if view=="alerts" then self:OpenSettings("Low Health"); return end
    self:CommitInputs()
    self.state={view=view=="now" and "supplies" or view,filter=(view=="supplies" or view=="now") and "All" or nil,page=1}; self.history={}
    if view=="advisors" then self.state.view="training"; self.state.filter="Gear" end
    if view=="dungeons" or view=="raids" then
        self.state.view="instances"; self.state.filter=view=="raids" and "Raids" or "Dungeons"
    end
    self.window.classMenu:Hide()
    self.window.search:ClearFocus(); self:Refresh(true)
end
function addon:OpenCurrentInstance()
    local current=self.Instances.Current()
    if not current then return end
    self:CommitInputs(); self.window.classMenu:Hide(); self.window.search:ClearFocus()
    self.history=self.history or {}; self.history[#self.history+1]=self.state
    if #current.guides==1 then
        self.state={view="instances",instance=current.guides[1].id,page=1}
    else
        self.state={view="instances",currentMap=current.map,currentName=current.name,
            unknownInstance=#current.guides==0,filter=current.view=="raids" and "Raids" or "Dungeons",page=1}
    end
    self:Refresh(true)
end
function addon:Activate(action)
    if action.kind=="supplyDefault" then
        self:CommitInputs()
        if self.Supplies.DefaultGroup(self:GetContext(),action.item) or self.Supplies.CanDefaultBandage(self:GetContext(),action.item) then
            self.characterDB.supplyDefaults=self.characterDB.supplyDefaults or {}
            self.characterDB.supplyDefaults[action.item.family]=action.item.itemId
            if self.Readiness then self.Readiness:SuppliesChanged() end
            self:Refresh()
        end
        return
    end
    if action.kind=="bandageRanks" then
        self:CommitInputs(); self.state.showAllBandages=not self.state.showAllBandages; self:Refresh(true); return
    end
    if action.kind=="mapAdvisor" then self.MapAdvisor:Activate(action); return end
    if action.kind=="advisor" and self.TalentAdvisor then self.TalentAdvisor:Activate(action); return end
    self:CommitInputs(); self.window.classMenu:Hide()
    self.history=self.history or {}; self.history[#self.history+1]=self.state
    if action.kind=="instance" then
        local g=self.Instances.byId[action.id]
        if not g then table.remove(self.history); return end
        self.state={view="instances",instance=g.id,filter=self.state.filter,showAllInstances=self.state.showAllInstances,page=1}
    elseif action.view then self.state={view=action.view,filter=action.filter,query=action.query,page=1}
    else self.state={view=self.state.view,filter=self.state.filter,query=self.state.query,detail=action,page=1} end
    self.window.search:ClearFocus(); self:Refresh(true)
end
function addon:Back()
    self:CommitInputs(); self.window.classMenu:Hide()
    if self.state.view=="settings" and self.state.gearPage then self.Settings:OpenGearPage(nil)
    elseif self.state.view=="settings" and self.state.mapIconKind then
        self.state.mapIconKind=nil; self.Settings.scroll:SetVerticalScroll(0); self:Refresh(true)
    elseif self.state.view=="deaths" and self.state.deathRecord then self:OpenDeaths("Reports")
    elseif self.state.view=="training" and self.state.filter=="Zone Advisor" and self.state.mapNPCs then
        self.state=table.remove(self.history or {}) or {view="training",filter="Zone Advisor"}; self:Refresh(true)
    elseif self.state.view=="training" and self.state.filter=="Zone Advisor" and self.state.mapZonePicker then
        self.state.mapZonePicker=nil; self:Refresh(true)
    elseif self.history and #self.history>0 then self.state=table.remove(self.history); self:Refresh(true)
    elseif self.state.view=="petguide" then self:Navigate("training") end
end
function addon:CanGoBack()
    local s=self.state or {}
    return (self.history and #self.history>0) or s.view=="petguide"
        or (s.view=="settings" and s.gearPage~=nil)
        or (s.view=="settings" and s.mapIconKind~=nil)
        or (s.view=="deaths" and s.deathRecord~=nil)
        or (s.view=="training" and s.filter=="Zone Advisor" and (s.mapZonePicker or s.mapNPCs)) or false
end
function addon:Refresh(resetScroll)
    if not self.window then return end
    local context=self:GetContext()
    if self.state and self.state.view=="advisors" then self.state.view="training"; self.state.filter=self.state.filter or "Gear" end
    if self.lastClass and self.lastClass~=context.characterClass and not (self.state and
        (self.state.view=="deaths" or self.state.view=="settings" or self.state.view=="instances"
            or self.state.view=="training" and (self.state.filter=="Gear" or self.state.filter=="Talents"))) then self.state=nil; self.history={} end
    self.lastClass=context.characterClass
    self.state=self.state or {view="supplies",filter="All",page=1}; self.history=self.history or {}
    if self.state.view=="training" and self.state.filter=="Zones" then self.state.filter="Zone Advisor" end
    if self.state.view=="settings" then self.state.filter=self.Settings:Section(self.state.filter) end
    -- Supplies has no hidden search or shortage filter after its controls were
    -- removed. Back navigation and old in-memory state must show the full kit.
    if self.state.view=="supplies" or self.state.view=="now" then self.state.query=nil; self.state.stock=nil end
    self.document=(self.state.view=="deaths" or self.state.view=="settings") and {context=context,view=self.state.view,cards={}} or C.Build(context,self.state)
    self:Layout()
    if resetScroll then self.window.scroll:SetVerticalScroll(0) end
end
local FILTER_ICONS={
    General="Trade_Engineering",["Gear Advisor"]="INV_Chest_Chain",["Auction House"]="INV_Misc_Coin_01",
    ["Death Journal"]="INV_Misc_Book_09",["NPC Alerts"]="Ability_Warrior_BattleShout",
    Gear="INV_Chest_Chain",Talents="Ability_Marksmanship",Map="INV_Misc_Map_01",["Talent Advisor"]="INV_Misc_Book_11",
    Essentials="INV_Misc_Bag_08",Preparation="INV_Misc_Note_01",Appearance="INV_Misc_Book_09",
    ["Low Health"]="Spell_Holy_SealOfSacrifice",Rares="Spell_Nature_FarSight",Elites="Ability_Warrior_BattleShout",
    ["Reports"]="INV_Misc_Book_09",Options="Trade_Engineering",["All"]="INV_Misc_Bag_08",["Food & Drink"]="INV_Misc_Food_11",Buffs="INV_Potion_27",
    Emergency="INV_Misc_Bandage_12",Potions="INV_Potion_54",Class="INV_Misc_Rune_01",Optional="INV_Misc_PocketWatch_01",User="INV_Misc_Note_01",Scrolls="INV_Scroll_03",Families="Ability_Hunter_BeastTaming",
    Abilities="Ability_Hunter_BeastCall",Pets="Ability_Hunter_Pet_Bear",Care="Ability_Hunter_MendPet",
    ["Pet Guide"]="Ability_Hunter_Pet_Bear",
    Overview="INV_Misc_Book_09",["Zone Advisor"]="INV_Misc_Map_01",Spells="INV_Misc_Book_07",["First Aid"]="INV_Misc_Bandage_12",Engineering="Trade_Engineering",Cooking="INV_Misc_Food_15",
}
function addon:Layout()
    local f,doc=self.window,self.document
    if not f or not doc then return end
    -- Zone recommendations place this control alongside their scrolling title.
    -- Restore the normal toolbar parent before laying out any other page.
    f.atLevel:SetParent(f); f.atLevel:SetFrameLevel(f.clear:GetFrameLevel())
    for i,card in ipairs(f.cards or {}) do
        local data=doc.cards[i]
        if card.detailQuantity and not (data and data.quantityRecord) then
            card.detailQuantity.quantity:ClearFocus(); card.detailQuantity:Hide()
        end
        if card.defaultChoice and not (data and data.defaultItem) then card.defaultChoice:Hide() end
    end
    local context,width,height=doc.context,f:GetWidth(),f:GetHeight()
    local compact=width<740 or height<500
    local short=height<500
    f.headerHeight=compact and 96 or 106
    if context.mode=="preview" then f.headerHeight=math.max(96,f.headerHeight) end
    Skin.LayoutWindow(f,width,height,compact)
    local titleX=compact and 94 or 122
    f.title:ClearAllPoints(); f.title:SetPoint("TOPLEFT",titleX,compact and -16 or -20)
    f.title:SetFont(STANDARD_TEXT_FONT,compact and 21 or 27,"")
    f.title:SetWordWrap(false); f.title:SetSize(math.max(140,width-titleX-60),short and 27 or 32)
    f.author:ClearAllPoints(); f.author:SetPoint("TOPLEFT",titleX,compact and -46 or -54); f.author:SetSize(260,14)
    f.subtitle:ClearAllPoints(); f.subtitle:SetPoint("TOPLEFT",titleX,compact and -65 or -72)
    f.subtitle:SetWordWrap(false); f.subtitle:SetSize(width-titleX-24,18)
    f.subtitle:SetText(context.characterClass.."  |  Level "..context.level
        ..(context.faction and ("  |  "..context.faction) or "  |  Faction unknown")
        ..(context.mode=="preview" and "  |  Planning" or "")
        ..(context.characterClass=="Hunter" and (context.petLevel and ((context.mode=="preview" and "  |  Planned pet " or "  |  Pet ")..context.petLevel) or "  |  No pet") or ""))
    f.motto:SetShown(not compact); f.motto:ClearAllPoints(); f.motto:SetPoint("TOPLEFT",titleX+2,-92); f.motto:SetSize(240,12)
    f.drag:SetHeight(f.headerHeight-6)
    local preview=context.mode=="preview"
    f.mode.label:SetText(preview and "Return" or "Edit Character")
    local modeWidth=math.max(154,math.ceil(f.mode.label:GetStringWidth())+22)
    f.mode:SetSize(modeWidth,28)
    f.mode:ClearAllPoints(); f.mode:SetPoint("RIGHT",f.close,"LEFT",-8,0)
    f.mode:SetFrameLevel(f.drag:GetFrameLevel()+2)
    f.drag:SetWidth(math.max(1,width-modeWidth-59))
    f.title:SetWidth(math.max(140,width-titleX-modeWidth-67))
    local x,y=22,f.headerHeight+4
    local right=width-22
    local tabWidth=(right-x-6*(#f.tabs-1))/#f.tabs
    for _,b in ipairs(f.tabs) do
        b:Show()
        if b:IsShown() then
            b:SetSize(tabWidth,30); b:ClearAllPoints(); b:SetPoint("TOPLEFT",x,-y)
            x=x+b:GetWidth()+6; active(b,doc.view==b.view or (b.view=="training" and doc.view=="petguide"))
        end
    end
    y=y+36
    f.class:SetShown(preview); f.levelGroup:SetShown(preview)
    f.class.label:SetText(context.characterClass)
    f.class:SetWidth(math.max(compact and 88 or 104,math.ceil(f.class.label:GetStringWidth())+22))
    local levelLabelWidth=math.max(42,math.ceil(f.levelLabel:GetStringWidth())+8)
    f.levelLabel:SetSize(levelLabelWidth,20)
    f.classLabel:SetWidth(f.class:GetWidth())
    local minusX=0
    local levelX=minusX+31
    local plusX=levelX+44
    f.levelGroup:SetSize(plusX+25,28)
    f.minus:ClearAllPoints(); f.minus:SetPoint("TOPLEFT",minusX,0)
    f.level:ClearAllPoints(); f.level:SetPoint("TOPLEFT",levelX,0)
    f.plus:ClearAllPoints(); f.plus:SetPoint("TOPLEFT",plusX,0)
    if preview then
        f.levelGroup:ClearAllPoints()
        f.levelGroup:SetPoint("TOPRIGHT",f,"TOPRIGHT",-22,-f.headerHeight+36)
        f.class:ClearAllPoints()
        f.class:SetPoint("RIGHT",f.levelGroup,"LEFT",-8,0)
        f.class:SetFrameLevel(f.drag:GetFrameLevel()+2)
        f.levelGroup:SetFrameLevel(f.drag:GetFrameLevel()+2)
        -- Keep the subtitle clear of the planning controls in compact windows.
        local textWidth=width-titleX-22-f.class:GetWidth()-8-f.levelGroup:GetWidth()-12
        f.subtitle:SetWidth(math.max(1,textWidth))
    end
    f.back:SetShown(self:CanGoBack())
    if not f.level:HasFocus() then f.level:SetText(tostring(context.level)) end
    enabled(f.class,preview); enabled(f.minus,preview and context.level>1); enabled(f.plus,preview and context.level<60)
    f.level:EnableMouse(preview); f.level:EnableKeyboard(preview)
    if not preview then f.classMenu:Hide() end
    local notice=context.liveUnavailable and "Character details unavailable; showing your saved plan." or nil
    if context.factionUnknown then
        notice=(notice and (notice.."\n") or "").."Faction unavailable; faction-specific recommendations are hidden."
    end
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID~=WOW_PROJECT_CLASSIC then notice="Classic Era / Hardcore reference." end
    f.context:SetShown(notice~=nil)
    if notice then y=y+measure(f.context,notice,width-44,22,y)+8 end
    local current=self.Instances.Current()
    f.currentInstance:SetShown(current~=nil)
    if current then
        local strip=f.currentInstance
        strip:ClearAllPoints(); strip:SetPoint("TOPLEFT",22,-y); strip:SetSize(width-44,48)
        strip.heading:SetText(current.view=="raids" and "CURRENT RAID" or "CURRENT DUNGEON")
        strip.heading:SetSize(width-220,14)
        strip.name:SetText(current.name); strip.name:SetSize(width-220,20); strip.name:SetWordWrap(false)
        strip.hint:SetText(#current.guides>1 and "Choose your wing  >" or "Items to bring  >")
        y=y+56
    end
    local instancePage=doc.view=="instances"
    local navigation=instancePage and self.Instances.Navigation(self.state)
        or doc.view=="settings" and self.Settings.sections or doc.view=="deaths" and {}
        or doc.view=="training" and C.Tabs(context)
        or doc.view=="petguide" and {"Families","Abilities","Pets","Care"}
        or addon.Supplies.filters
    local sidebar=doc.view~="deaths"
    local left=sidebar and 184 or 22
    local bodyWidth=width-left-40
    f.sidebar:SetShown(sidebar)
    if sidebar then
        f.sidebar:ClearAllPoints(); f.sidebar:SetPoint("TOPLEFT",20,-y); f.sidebar:SetPoint("BOTTOMLEFT",20,18); f.sidebar:SetWidth(148)
        f.sidebarTitle:SetText(doc.view=="settings" and "SETTINGS" or instancePage and "INSTANCES" or doc.view=="deaths" and "DEATH JOURNAL" or doc.view=="petguide" and "PET JOURNAL" or doc.view=="training" and "COMPANION" or "FIELD KIT")
        f.sidebarNote:SetText(doc.view=="settings" and "Your preferences.\nOne place." or instancePage and "Levels and\nitems to bring." or doc.view=="deaths" and "Every journey\nleaves a story." or doc.view=="petguide" and "Find a companion.\nLearn its strengths." or "Pack with purpose.\nEvery slot matters.")
        f.sidebarNote:SetShown(height-y-18>35+#navigation*41+70)
    end
    x=22
    local filterY=y
    for i,label in ipairs(navigation) do
        local b=f.filters[i]
        if not b then
            b=button(f,label,78,function(self)
                addon:CommitInputs(); addon.window.classMenu:Hide()
                addon.state.detail=nil; addon.state.deathRecord=nil; addon.state.gearPage=nil; addon.state.mapIconKind=nil; addon.state.talentPath=nil; addon.history={}; addon.state.page=1
                if addon.state.view=="instances" then
                    addon.state.filter=self.filter
                    addon.state.currentMap=nil; addon.state.currentName=nil; addon.state.unknownInstance=nil
                    addon.state.instance=nil
                    addon.state.query=nil
                    addon:Refresh(true); return
                end
                if addon.state.view=="training" then
                    if self.filter=="Pet Guide" then addon:Navigate("petguide"); return end
                    addon.state.filter=(self.filter=="Zone Advisor" or self.filter=="Pet Training" or self.filter=="Spells" or self.filter=="Gear" or self.filter=="Talents" or self.filter=="First Aid" or self.filter=="Cooking") and self.filter or nil
                    addon.state.query=nil; addon.state.mapNPCs=nil; addon.state.mapZonePicker=nil; addon.state.mapZone=nil; addon.state.mapCurrent=nil
                    local family=({Engineering="dummy"})[self.filter]
                    if family then addon:Activate({kind="profession",family=family}); return end
                else
                    addon.state.filter=self.filter
                end
                addon:Refresh(true)
            end)
            Skin.Button(b,"category")
            b.navIcon=b:CreateTexture(nil,"ARTWORK"); b.navIcon:SetSize(18,18); b.navIcon:SetPoint("LEFT",9,0)
            b.navIcon:SetTexCoord(0.08,0.92,0.08,0.92)
            f.filters[i]=b
        end
        local tabWidth=label=="Food & Drink" and 98 or label=="Emergency" and 94 or label=="All" and 44 or label=="Buffs" and 62 or 74
        b.filter=label; b.label:SetText(label); b.label:SetFont(STANDARD_TEXT_FONT,instancePage and 11 or 12,""); b:Show(); b:ClearAllPoints()
        local iconPath=FILTER_ICONS[label] or "INV_Misc_Book_09"
        if not iconPath:find("\\",1,true) then iconPath="Interface\\Icons\\"..iconPath end
        b.navIcon:SetTexture(iconPath); b.navIcon:SetShown(sidebar)
        b.label:ClearAllPoints()
        if sidebar then
            local step=math.min(41,math.floor((height-filterY-58)/math.max(1,#navigation)))
            b:SetSize(132,math.min(36,step-4)); b:SetPoint("TOPLEFT",28,-filterY-35-(i-1)*step)
            b.label:SetPoint("TOPLEFT",32,0); b.label:SetPoint("BOTTOMRIGHT",-5,0); b.label:SetJustifyH("LEFT")
        else
            if x+tabWidth>width-20 then x=22; y=y+32 end
            b:SetSize(tabWidth,27); b:SetPoint("TOPLEFT",x,-y); x=x+tabWidth+5
            b.label:SetAllPoints(); b.label:SetJustifyH("CENTER")
        end
        local selected=self.state.filter or (doc.view=="petguide" and "Families" or navigation[1])
        if doc.view=="training" then
            local family=self.state.detail and self.state.detail.family
            selected=family=="bandage" and "First Aid" or family=="antivenom" and "First Aid"
                or family=="dummy" and "Engineering" or family=="cooking" and "Cooking" or self.state.filter or "Overview"
        end
        active(b,selected==label)
    end
    for i=#navigation+1,#f.filters do f.filters[i]:Hide() end
    if doc.filters and not sidebar then y=y+34 end
    Skin.PlaceBackButton(f.back,f,y,left)
    local toolbarY=y
    -- Every page reserves navigation space, even when Back is hidden.
    local toolbarHeight=bodyWidth<620 and 68 or 34
    local backRow=self:CanGoBack()
    local customDetail=doc.isDetail and self.state.detail and self.state.detail.item and self.state.detail.item.userItem
    local priorityItem=doc.isDetail and self.state.detail and self.state.detail.item
    if doc.isDetail and self.state.detail and self.state.detail.kind=="supplyFamily" then
        local id=self.Supplies.Selection(context,self.state.detail.family)
        for _,item in ipairs(self.Data.Items.items) do if item.itemId==id then priorityItem=item; break end end
    end
    f.priorityChoice:SetShown(priorityItem and true or false)
    local toolbarWrap=false
    if priorityItem then
        f.priorityChoice.item=priorityItem
        f.priorityChoice.label:SetText("Priority: "..self.Supplies.Priority(context,priorityItem))
        local inset=doc.cards[1] and doc.cards[1].itemLayout and 12 or 0
        local data=doc.cards[1]
        local controlsWidth=190+(data and data.quantityRecord and 176 or 0)
        local leftControls=customDetail and 230 or backRow and f.back:GetWidth()+8 or 0
        if data and data.defaultItem and not data.isDefault then leftControls=leftControls+138 end
        toolbarWrap=bodyWidth-inset<controlsWidth+leftControls
        f.priorityChoice:ClearAllPoints(); f.priorityChoice:SetPoint("TOPRIGHT",-40-inset,-y-(toolbarWrap and 34 or 0))
    end
    f.userRemove:SetShown(customDetail and true or false)
    if customDetail then
        f.userRemove:ClearAllPoints(); f.userRemove:SetPoint("TOPLEFT",left+108,-y)
    end
    y=y+toolbarHeight
    local userPage=doc.view=="supplies" and self.state.filter=="User" and not doc.isDetail
    f.userEntry:SetShown(userPage)
    if userPage then
        f.userDrop:ClearAllPoints(); f.userDrop:SetPoint("TOPLEFT",left,-y); f.userDrop:SetPoint("BOTTOMRIGHT",-40,18)
    else
        f.userDrop:Hide()
    end
    local ammoPreview=doc.view=="supplies" and self.state.filter=="Class" and not doc.isDetail and context.mode=="preview"
        and (context.characterClass=="Hunter" or context.characterClass=="Warrior" or context.characterClass=="Rogue")
    f.ammoChoice:SetShown(ammoPreview and true or false)
    if ammoPreview then
        f.ammoChoice.label:SetText("Plan ammo: "..(context.previewAmmo or "arrows"))
        f.ammoChoice:ClearAllPoints(); f.ammoChoice:SetPoint("TOPLEFT",left+108,-toolbarY)
    end
    local zonePage=doc.zoneRecommendations
    local spellPage=doc.view=="training" and self.state.filter=="Spells"
    local rangePage=instancePage or zonePage
    local showAll=zonePage and self.state.showAllZones or instancePage and self.state.showAllInstances or spellPage and self.state.showAllFutureSpells
    local searchable=(doc.view=="petguide" or rangePage or spellPage) and doc.searchable
    f.search:SetShown(searchable); f.searchLabel:SetShown(searchable); f.clear:SetShown(searchable)
    f.atLevel:SetShown(searchable and doc.levelFilter)
    if searchable then
        local extra=doc.levelFilter
        f.atLevel.label:SetText(spellPage and (showAll and "Hide future spells" or "Show all future spells") or rangePage and (showAll and "Near my level" or zonePage and "Show All" or "Show all") or (self.state.atLevel and "Within my level" or "Any level"))
        local extraButton=f.atLevel
        if extra then extraButton:SetWidth(math.max(112,math.ceil(extraButton.label:GetStringWidth())+22)) end
        local labelWidth=math.ceil(f.searchLabel:GetStringWidth())+6
        local rowHeight=math.max(28,math.ceil(f.searchLabel:GetStringHeight())+8)
        local extraWidth=extra and not zonePage and extraButton:GetWidth()+6 or 0
        local searchLeft=left+(zonePage and (backRow and 108 or 0) or 108)
        local rightInset=zonePage and 54 or 40
        local searchWidth=width-rightInset-searchLeft-labelWidth-8-f.clear:GetWidth()-6-extraWidth
        local wrapExtra=extra and not zonePage and searchWidth<80
        if wrapExtra then searchWidth=searchWidth+extraWidth; extraWidth=0 end
        f.searchLabel:ClearAllPoints(); f.searchLabel:SetPoint("TOPLEFT",searchLeft,-toolbarY)
        f.searchLabel:SetSize(labelWidth,rowHeight)
        f.search:ClearAllPoints(); f.search:SetPoint("TOPLEFT",searchLeft+labelWidth+8,-toolbarY)
        f.search:SetSize(math.max(50,searchWidth),rowHeight)
        if f.search:GetText()~=(self.state.query or "") then f.search:SetText(self.state.query or "") end
        f.clear:ClearAllPoints(); f.clear:SetPoint("TOPRIGHT",-rightInset-extraWidth,-toolbarY)
        f.clear:SetHeight(rowHeight)
        f.atLevel:ClearAllPoints(); f.atLevel:SetPoint("TOPRIGHT",-40,-toolbarY-(wrapExtra and rowHeight+6 or 0))
        active(f.atLevel,(rangePage or spellPage) and not not showAll or not (rangePage or spellPage) and self.state.atLevel)
    end
    y=y+self.MapAdvisor:LayoutControls(f,left,y,bodyWidth,doc.view=="training" and self.state.filter=="Zone Advisor")
    local deathPage=doc.view=="deaths"
    f.scroll:SetShown(not deathPage and doc.view~="settings")
    if self.Deaths and self.Deaths.host then
        local deathSettings=doc.view=="settings" and self.Settings:Section(self.state.filter)=="Death Journal"
        self.Deaths.host:SetShown(deathPage or deathSettings)
        if deathPage then self.Deaths:LayoutPage(f,left,y,bodyWidth,height-y-18,self.state) end
    end
    self.Settings:Layout(f,left,y,bodyWidth,height-y-18,self.state.filter,doc.view=="settings")
    f.scroll:ClearAllPoints(); f.scroll:SetPoint("TOPLEFT",left,-y); f.scroll:SetPoint("BOTTOMRIGHT",-40,18)
    local contentWidth=math.max(250,bodyWidth); f.content:SetWidth(contentWidth)
    local top=self.MapAdvisor:LayoutViewer(f.content,contentWidth,doc.view=="training" and self.state.filter=="Zone Advisor",f.scroll:GetHeight())
    for index,data in ipairs(doc.cards) do
        local c=f.cards[index]
        if not c then
            c=CreateFrame("Frame",nil,f.content,"BackdropTemplate"); Skin.Paint(c,"card")
            c.title=font(c,17,GOLD); c.note=font(c,12,MUTED)
            c.content=CreateFrame("Frame",nil,c); c.content.blocks={}; f.cards[index]=c
        end
        c:ClearAllPoints(); c:SetPoint("TOPLEFT",0,-top)
        c.firstCard=index==1
        c.gridStart=not doc.isDetail and (doc.view=="training" and (self.state.filter=="Spells" or self.document.zoneRecommendations) and 1
            or doc.view=="training" and (not self.state.filter or self.state.filter=="Overview") and index==1 and 3
            or doc.view=="training" and self.state.filter=="Zone Advisor" and not self.state.mapNPCs and (self.state.mapZonePicker or index==1) and (self.state.mapZonePicker and 2 or 1)
            or doc.advisor and not self.state.talentPath and 1
            or doc.professionPage and index>1 and #data.blocks>1 and 1) or nil
        top=top+renderCard(c,data,contentWidth)+(data.spellTable and 8 or 10)
        if data.zoneRangeToggle then
            f.atLevel:SetParent(c); f.atLevel:SetFrameLevel(c.headerButton:GetFrameLevel())
            f.atLevel:ClearAllPoints(); f.atLevel:SetPoint("RIGHT",c.headerButton,"LEFT",-8,0)
        end
        if userPage and index==1 then
            -- Keep drag feedback in the subtitle, inside the scrolling page.
            f.userEntry:SetParent(c); f.userEntry:ClearAllPoints(); f.userEntry:SetAllPoints(c.note)
            f.userEntry.hint:ClearAllPoints(); f.userEntry.hint:SetAllPoints(f.userEntry)
            c.note:Hide()
        end
    end
    for i=#doc.cards+1,#f.cards do f.cards[i]:Hide() end
    f.content:SetHeight(math.max(1,top)); f.scroll:UpdateScrollChildRect()
    f.scroll:SetVerticalScroll(math.min(f.scroll:GetVerticalScroll(),math.max(0,top-f.scroll:GetHeight())))
    -- WoW resolves nested texture/frame anchors after this layout pass. Refresh
    -- the scroll child's cached geometry next frame, as scrolling would do.
    f.refreshScrollGeometry=true
end
