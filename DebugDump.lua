-- Manual incremental diagnostics: only HardcoreBuddy data and player APIs.
local _,A=...
local D={schema=1}; A.DebugDump=D
local Skin=A.Skin
local function call(fn,...)
    if type(fn)~="function" then return {unavailable="API unavailable"} end
    local function pack(...) return {n=select("#",...),...} end
    local values=pack(pcall(fn,...))
    if not values[1] then return {unavailable=tostring(values[2])} end
    local result={n=values.n-1}; for i=2,values.n do result[i-1]=values[i] end
    return result
end
local function api(name) return C_Container and C_Container[name] or _G[name] end
local function label(parent,text,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,12,""); f:SetPoint("TOPLEFT",x,-y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,x,y,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetSize(140,28); b:SetPoint("TOPLEFT",x,-y)
    b.label=label(b,text,0,0,140); b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    Skin.Button(b,"utility"); b:SetScript("OnClick",callback)
    return b
end

function D:Serialize(value,path,seen,depth)
    self.nodes=self.nodes+1
    if self.nodes%128==0 then coroutine.yield() end
    local kind=type(value)
    if kind=="string" then return string.format("%q",value) end
    if kind=="boolean" then return tostring(value) end
    if kind=="number" and value==value and math.abs(value)<math.huge then return tostring(value) end
    if kind~="table" then return string.format("%q","<"..kind..">") end
    if value==self then return '"<dump worker>"' end
    if type(value.GetObjectType)=="function" or type(value.SetScript)=="function" then return '"<UI object>"' end
    if seen[value] then return '{["$ref"]='..string.format("%q",seen[value])..'}' end
    if depth>64 then self.omitted=self.omitted+1; return '"<depth limit>"' end
    seen[value]=path
    local keys={}
    for k in pairs(value) do
        if type(k)=="string" or type(k)=="number" then
            if not (value==A.characterDB and k=="debugDump") then keys[#keys+1]=k end
        else self.omitted=self.omitted+1 end
        self.nodes=self.nodes+1; if self.nodes%128==0 then coroutine.yield() end
    end
    table.sort(keys,function(a,b) if type(a)==type(b) then return a<b end; return type(a)<type(b) end)
    local parts={"{"}
    for _,key in ipairs(keys) do
        local keyText=type(key)=="number" and tostring(key) or string.format("%q",key)
        parts[#parts+1]="["..keyText.."]="..self:Serialize(value[key],path.."["..keyText.."]",seen,depth+1)..",\n"
    end
    parts[#parts+1]="}"; return table.concat(parts)
end

function D:Collect()
    local out={schema=self.schema,version=A.version,capturedAt=GetServerTime and GetServerTime() or time(),
        scope="HardcoreBuddy saved data, runtime state, reference data and available player APIs",
        notes="Collected over several frames. Unavailable APIs are marked. UI objects/functions are described, not traversed. Previous dump text is excluded. Bank contents require the bank to be open. No other addon data is read.",
        client=call(GetBuildInfo),locale=call(GetLocale),project=WOW_PROJECT_ID}
    self.phase="Reading character and equipment"; self.progress=0.05; coroutine.yield()
    out.context=call(A.GetContext,A)
    out.equipment=call(A.GearSnapshot.Capture,A.GearSnapshot,true)
    out.pet=call(A.HunterTraining.Read)
    out.position={map=call(C_Map and C_Map.GetBestMapForUnit,"player"),zone=call(GetZoneText),subzone=call(GetSubZoneText),instance=call(GetInstanceInfo)}
    out.player={guid=call(UnitGUID,"player"),name=call(UnitName,"player"),realm=call(GetRealmName),class=call(UnitClass,"player"),race=call(UnitRace,"player"),level=call(UnitLevel,"player"),health=call(UnitHealth,"player"),maxHealth=call(UnitHealthMax,"player"),power=call(UnitPower,"player"),maxPower=call(UnitPowerMax,"player"),money=call(GetMoney)}
    out.stats={attributes={},resistances={},spellCrit={},armor=call(UnitArmor,"player"),damage=call(UnitDamage,"player"),
        rangedDamage=call(UnitRangedDamage,"player"),attackPower=call(UnitAttackPower,"player"),rangedAttackPower=call(UnitRangedAttackPower,"player"),
        crit=call(GetCritChance),rangedCrit=call(GetRangedCritChance),dodge=call(GetDodgeChance),parry=call(GetParryChance),block=call(GetBlockChance)}
    for i=1,5 do out.stats.attributes[i]=call(UnitStat,"player",i) end
    for i=0,6 do out.stats.resistances[i]=call(UnitResistance,"player",i) end
    for i=1,7 do out.stats.spellCrit[i]=call(GetSpellCritChance,i) end
    out.professions=call(A.Professions.Read)
    self.phase="Reading bags and quests"; self.progress=0.15; coroutine.yield()
    out.bags={}
    for bag=-2,(NUM_BAG_SLOTS or 4)+(NUM_BANKBAGSLOTS or 7) do
        local count=call(api("GetContainerNumSlots"),bag)
        local slots={count=count,items={}}; out.bags[bag]=slots
        if type(count[1])=="number" then for slot=1,count[1] do
            slots.items[slot]={info=call(api("GetContainerItemInfo"),bag,slot),link=call(api("GetContainerItemLink"),bag,slot)}
            if slot%8==0 then coroutine.yield() end
        end end
    end
    out.quests={}
    local count=call(GetNumQuestLogEntries); out.quests.entries=count
    for i=1,type(count[1])=="number" and count[1] or 0 do
        local q={title=call(GetQuestLogTitle,i),objectives={}}; out.quests[i]=q
        local objectives=call(GetNumQuestLeaderBoards,i)
        for j=1,type(objectives[1])=="number" and objectives[1] or 0 do q.objectives[j]=call(GetQuestLogLeaderBoard,j,i) end
        coroutine.yield()
    end
    self.phase="Reading skills, spells and auras"; self.progress=0.25; coroutine.yield()
    out.skills={}; count=call(GetNumSkillLines); out.skills.entries=count
    for i=1,type(count[1])=="number" and count[1] or 0 do out.skills[i]=call(GetSkillLineInfo,i); coroutine.yield() end
    out.spells={}; count=call(GetNumSpellTabs); out.spells.tabs=count
    for i=1,type(count[1])=="number" and count[1] or 0 do
        local tab=call(GetSpellTabInfo,i); local spells={}; out.spells[i]={tab=tab,spells=spells}
        if type(tab[3])=="number" and type(tab[4])=="number" then for slot=tab[3]+1,tab[3]+tab[4] do
            spells[slot]={name=call(GetSpellBookItemName,slot,BOOKTYPE_SPELL or "spell"),info=call(GetSpellBookItemInfo,slot,BOOKTYPE_SPELL or "spell")}
            if slot%8==0 then coroutine.yield() end
        end end
    end
    out.auras={}
    for _,unit in ipairs({"player","pet"}) do
        out.auras[unit]={}
        for _,filter in ipairs({"HELPFUL","HARMFUL"}) do
            local list={}; out.auras[unit][filter]=list
            local fn=C_UnitAuras and C_UnitAuras.GetAuraDataByIndex or UnitAura
            if not fn then list.unavailable="Aura API unavailable" else
                for i=1,40 do local aura=call(fn,unit,i,filter); if not aura[1] then break end; list[i]=aura; if i%8==0 then coroutine.yield() end end
            end
        end
    end
    self.phase="Serializing diagnostic data"; self.progress=0.35; coroutine.yield()
    local sections={{"capture",out},{"account",A.db},{"character",A.characterDB},{"referenceData",A.Data},{"runtime",A}}
    local chunks={"-- HardcoreBuddy diagnostic dump v1\nreturn {\n"}; local seen={}
    for i,section in ipairs(sections) do
        self.phase="Writing "..section[1]; self.progress=0.35+(i-1)/#sections*0.6
        chunks[#chunks+1]='['..string.format("%q",section[1])..']='..self:Serialize(section[2],section[1],seen,0)..',\n'
        coroutine.yield()
    end
    chunks[#chunks+1]='["serialization"]={nodes='..self.nodes..',omitted='..self.omitted..'},\n}\n'
    self.phase="Finishing dump"; self.progress=0.98; coroutine.yield()
    return {schema=self.schema,capturedAt=out.capturedAt,text=table.concat(chunks)}
end

function D:Start()
    if self.job or not A.characterDB then return end
    self.nodes=0; self.omitted=0; self.progress=0; self.displayProgress=0; self.phase="Starting dump"; self.error=nil
    self.job=coroutine.create(function() return self:Collect() end)
    if not self.worker then self.worker=CreateFrame("Frame"); self.worker:SetScript("OnUpdate",function(_,elapsed) self:Step(elapsed) end) end
    self.worker:Show(); self:Refresh()
end

function D:Step(elapsed)
    if not self.job then self.worker:Hide(); return end
    local started=debugprofilestop and debugprofilestop()
    for _=1,8 do
        local ok,result=coroutine.resume(self.job)
        if not ok then
            self.error=tostring(result); self.job=nil; self.phase="Dump failed; previous cached dump retained."; break
        elseif coroutine.status(self.job)=="dead" then
            A.characterDB.debugDump=result; self.job=nil; self.progress=1; self.phase="Dump complete and cached. /reload saves it to disk."; break
        end
        if started and debugprofilestop()-started>=3 then break end
    end
    self.displayProgress=math.min(self.progress,self.displayProgress+math.max(0.002,(self.progress-self.displayProgress)*math.min(1,elapsed*8)))
    self.animationTime=(self.animationTime or 0)+elapsed
    if not self.job then self.displayProgress=self.progress end
    self:Refresh()
end

function D:Refresh()
    local p=self.page; if not p then return end
    local saved=A.characterDB and A.characterDB.debugDump
    p.dump:SetEnabled(not self.job)
    p.dump.label:SetText(self.job and "Dumping..." or "Dump Data")
    p.cached:SetText(saved and ((date and date("%b %d %H:%M",saved.capturedAt) or tostring(saved.capturedAt)).." | "..math.ceil(#saved.text/1024).." KB cached") or "")
    p.status:SetText(self.error and (self.phase.." "..self.error) or self.phase or (saved and "Cached full dump restored. Select text in the box to copy." or "No dump cached yet."))
    p.fill:SetWidth(math.max(1,700*(self.displayProgress or (saved and 1 or 0))))
    p.percent:SetText(math.floor((self.displayProgress or (saved and 1 or 0))*100).."%")
    p.sheen:SetShown(self.job~=nil)
    p.sheen:ClearAllPoints(); p.sheen:SetPoint("TOPLEFT",p.track,"TOPLEFT",((self.animationTime or 0)*220)%660,0)
    if saved and p.shownDump~=saved then
        p.shownDump=saved
        local _,lines=saved.text:gsub("\n","\n")
        p.edit:SetHeight(math.max(250,(lines+1)*14))
        p.edit:SetText(saved.text); p.edit:SetCursorPosition(0); p.scroll:SetVerticalScroll(0)
        p.scroll:UpdateScrollChildRect()
    end
end

function D:Create(page)
    if self.page then return end
    self.page=page
    Skin.SectionBackdrop(page,62,144).title:SetText("Capture data")
    Skin.SectionBackdrop(page,218,298).title:SetText("Dump output")
    label(page,"Capture all HardcoreBuddy data and available character details for offline review.",0,34,700)
    page.dump=button(page,"Dump Data",28,104,function() self:Start() end)
    page.copyHint=label(page,"Ctrl + C to copy",188,104,530)
    page.cached=label(page,"",188,126,530)
    page.status=label(page,"",28,146,700); page.status:SetHeight(30)
    local track=CreateFrame("Frame",nil,page,"BackdropTemplate"); page.track=track
    track:SetPoint("TOPLEFT",28,-178); track:SetSize(700,18); Skin.Paint(track,"edit")
    page.fill=track:CreateTexture(nil,"ARTWORK"); page.fill:SetTexture("Interface\\Buttons\\WHITE8x8"); page.fill:SetVertexColor(0.25,0.7,0.42,1)
    page.fill:SetPoint("TOPLEFT"); page.fill:SetHeight(18)
    page.sheen=track:CreateTexture(nil,"OVERLAY"); page.sheen:SetTexture("Interface\\Buttons\\WHITE8x8")
    page.sheen:SetSize(40,18); page.sheen:SetVertexColor(1,1,1,0.22)
    page.percent=label(track,"",0,0,700); page.percent:SetHeight(18); page.percent:SetJustifyH("CENTER")
    local border=CreateFrame("Frame",nil,page,"BackdropTemplate"); Skin.Paint(border,"edit")
    border:SetPoint("TOPLEFT",26,-256); border:SetSize(704,254)
    local scroll=CreateFrame("ScrollFrame","HardcoreBuddyDebugTextScroll",page,"UIPanelScrollFrameTemplate"); page.scroll=scroll
    scroll:SetFrameLevel(border:GetFrameLevel()+1)
    scroll:SetPoint("TOPLEFT",28,-258); scroll:SetSize(680,250)
    local edit=CreateFrame("EditBox",nil,scroll); page.edit=edit
    edit:SetMultiLine(true); edit:SetAutoFocus(false); edit:SetFontObject(ChatFontNormal); edit:SetWidth(670); edit:SetHeight(250); edit:SetMaxLetters(0)
    if edit.SetMaxBytes then edit:SetMaxBytes(0) end
    if edit.SetCountInvisibleLetters then edit:SetCountInvisibleLetters(true) end
    scroll:SetScrollChild(edit)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel",function(_,delta)
        scroll:SetVerticalScroll(math.max(0,math.min(edit:GetHeight()-250,scroll:GetVerticalScroll()-delta*42)))
    end)
    edit:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
    edit:SetScript("OnTextChanged",function(_,user)
        if user then page.textDirtyAt=GetTime()+0.2 end
    end)
    edit:SetScript("OnUpdate",function(e)
        if page.textDirtyAt and GetTime()>=page.textDirtyAt then
            page.textDirtyAt=nil
            local _,lines=e:GetText():gsub("\n","\n")
            e:SetHeight(math.max(250,(lines+1)*14)); scroll:UpdateScrollChildRect()
        end
    end)
    edit:SetScript("OnCursorChanged",function(_,_,y,_,height)
        if not y or page.scrolling then return end
        page.scrolling=true
        local top=-y; local current=scroll:GetVerticalScroll()
        local wanted=current
        if top<current then wanted=top
        elseif top+height>current+scroll:GetHeight() then wanted=top+height-scroll:GetHeight() end
        wanted=math.max(0,math.min(math.max(0,edit:GetHeight()-scroll:GetHeight()),wanted))
        if math.abs(wanted-current)>0.5 then scroll:SetVerticalScroll(wanted) end
        page.scrolling=nil
    end)
    label(page,"Full editable dump. Select text manually (Ctrl + A for all), then Ctrl + C. The original dump stays cached.",12,532,700)
    page:SetScript("OnHide",function() edit:ClearFocus() end)
    page.contentHeight=566; self:Refresh()
end
