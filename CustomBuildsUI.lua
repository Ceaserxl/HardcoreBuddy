local _,A=...
local B,S=A.CustomBuilds,A.Skin
local U={}; A.CustomBuildsUI=U
local function label(parent,text,x,y,width,size)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetFont(STANDARD_TEXT_FONT,size or 12,""); f:SetPoint("TOPLEFT",x,-y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetText(text); return f
end
local function button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate")
    b:SetPoint("TOPLEFT",x,-y); b:SetSize(width,28)
    b.label=label(b,text,4,0,width-8); b.label:SetHeight(28); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    S.Button(b,"utility"); b:SetScript("OnClick",fn); return b
end
local function edit(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent,"BackdropTemplate")
    S.Paint(e,"edit"); e:SetPoint("TOPLEFT",x,-y); e:SetSize(width,28)
    e:SetFont(STANDARD_TEXT_FONT,12,""); e:SetTextInsets(6,6,0,0); e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end); return e
end
function U:Open()
    A:CommitInputs(); self.mode="library"; self.draft=nil; self.message=nil; self.deleteID=nil
    A:OpenSettings("Talent Advisor"); A.state.customBuildPage=true; A:Refresh(true)
end
function U:Back()
    if self.mode~="library" then self.mode="library"; self.draft=nil; self.message=nil
    else A.state.customBuildPage=nil end
    A:Refresh(true)
end
function U:Edit(build,id)
    self.draft=B.Copy(build); self.editID=id; self.mode="edit"; self.message=nil; self.clearArmed=nil
    self.editor.name:SetText(self.draft.name)
    for _,field in ipairs(A.GearAdvisor.WeightFields) do self.editor.weights[field[1]]:SetText(tostring(self.draft.weights[field[1]] or 0)) end
    A:Refresh(true)
end
function U:ReadDraft()
    local d=B.Copy(self.draft); d.name=self.editor.name:GetText()
    for _,field in ipairs(A.GearAdvisor.WeightFields) do d.weights[field[1]]=tonumber(self.editor.weights[field[1]]:GetText()) end
    return d
end
function U:Transfer(build)
    self.mode="transfer"; self.message=nil; self.preview=nil
    local text,err
    if build then text,err=B:Export(build) end
    self.transfer.code:SetText(text or ""); self.message=err
    self.transfer.target:SetText(""); A:Refresh(true)
end
function U:Review(text,sender)
    self:Open(); self.mode="transfer"; self.transfer.code:SetText(text)
    self.preview,self.message=B:Decode(text)
    if self.preview then self.message="Shared by "..sender..". Review, then Import as New." end
    A:Refresh(true)
end
function U:Create(page)
    self.page=page
    page.subtitle=label(page,"Talent paths and stat weights are saved and shared together. Available to all your characters.",0,30,720)
    self.messageText=label(page,"",0,54,720); self.messageText:SetTextColor(1,0.7,0.25)
    local list=CreateFrame("Frame",nil,page); list:SetPoint("TOPLEFT",0,-82); self.list=list; list.rows={}
    list.new=button(list,"Create Build",0,0,150,function()
        self:Edit(B:Draft(self.class,A.TalentAdvisor:Build(self.class,A:GetContext().level)))
    end)
    list.import=button(list,"Import Build",158,0,150,function() self:Transfer() end)
    list.hint=label(list,"Create a copy of your selected path, then edit its talents and weights. Importing never applies talents.",0,36,720)
    local editor=CreateFrame("Frame",nil,page); editor:SetPoint("TOPLEFT",0,-82); self.editor=editor
    label(editor,"Build name",0,6,90); editor.name=edit(editor,94,0,310); editor.name:SetMaxLetters(60)
    editor.save=button(editor,"Save Build",412,0,140,function()
        local saved,err=B:Save(self:ReadDraft(),self.editID)
        if saved then self.mode="library"; self.message="Saved "..saved.name.." ("..saved.class.."). Choose Use to select it."
        else self.message=err end
        A:Refresh()
    end)
    editor.cancel=button(editor,"Cancel",560,0,120,function() self:Back() end)
    editor.profile=button(editor,"",0,36,260,function()
        self.draft.profile=self.draft.profile%#A.Data.AdvisorGear[self.draft.class]+1; A:Refresh()
    end)
    editor.current=button(editor,"Use Current Talents",268,36,180,function()
        local d,err=B:FromCurrent(self.draft.class,self.draft.profile)
        if d then self.draft.steps=d.steps; self.message="Current ranks copied in a legal leveling order. Review the path below."
        else self.message=err end; A:Refresh()
    end)
    editor.undo=button(editor,"Undo Point",456,36,108,function() table.remove(self.draft.steps); A:Refresh() end)
    editor.clear=button(editor,"Clear Path",572,36,108,function()
        if self.clearArmed then self.draft.steps={}; self.clearArmed=nil else self.clearArmed=true end; A:Refresh()
    end)
    editor.hint=label(editor,"",0,72,720)
    editor.nodes={}; editor.trees={}; editor.weights={}; editor.weightLabels={}; editor.pathRows={}
    for tree=1,3 do editor.trees[tree]=label(editor,"",0,98,220,15) end
    editor.weightTitle=label(editor,"Stat Weights",0,480,340,15); editor.pathTitle=label(editor,"Point-by-point Path",370,480,340,15)
    editor.reset=button(editor,"Reset Weights",196,472,146,function()
        local p=A.GearAdvisor.Profile(self.draft.class,60,nil,self.draft.profile)
        for key,e in pairs(editor.weights) do e:SetText(tostring(p.weights[key] or 0)) end
    end)
    editor.pathHelp=label(editor,"Click a point to remove it and all following points.",370,504,340)
    for i,field in ipairs(A.GearAdvisor.WeightFields) do
        local y=516+(i-1)*32
        editor.weightLabels[i]=label(editor,field[2],0,y+6,228)
        local e=edit(editor,234,y,108); e:SetMaxLetters(20); editor.weights[field[1]]=e
    end
    local transfer=CreateFrame("Frame",nil,page); transfer:SetPoint("TOPLEFT",0,-82); self.transfer=transfer
    label(transfer,"Export: Ctrl+A, Ctrl+C. Import: paste a build code, then click Review.",0,0,720)
    local scroll=CreateFrame("ScrollFrame",nil,transfer,"UIPanelScrollFrameTemplate"); scroll:SetPoint("TOPLEFT",0,-28); scroll:SetSize(688,136)
    local code=CreateFrame("EditBox",nil,scroll,"BackdropTemplate"); transfer.code=code
    code:SetMultiLine(true); code:SetFont(STANDARD_TEXT_FONT,12,""); code:SetAutoFocus(false); code:SetMaxLetters(B.maxText)
    code:SetJustifyV("TOP")
    code:SetWidth(664); code:SetHeight(136); code:SetTextInsets(6,6,6,6); S.Paint(code,"edit"); scroll:SetScrollChild(code)
    code:SetScript("OnTextChanged",function() self.preview=nil; if transfer.import then transfer.import:SetEnabled(false) end end)
    code:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
    transfer.review=button(transfer,"Review",0,174,130,function()
        self.preview,self.message=B:Decode(code:GetText()); if self.preview then self.message="Ready to import a new copy." end; A:Refresh()
    end)
    transfer.import=button(transfer,"Import as New",138,174,160,function()
        local decoded,err=B:Decode(code:GetText())
        local saved
        if decoded then saved,err=B:Save(decoded) end
        self.message=saved and ("Imported "..saved.name.." for "..saved.class..". Select it in Talent Advisor to use it.") or err
        A:Refresh()
    end)
    label(transfer,"Share to player",0,216,120); transfer.target=edit(transfer,128,210,250); transfer.target:SetMaxLetters(100)
    transfer.send=button(transfer,"Send Build Link",386,210,174,function()
        local build,err=B:Decode(code:GetText())
        local ok
        if build then ok,err=B:Share(build,transfer.target:GetText()) end
        self.message=ok and "Sending build link. The recipient needs HardcoreBuddy with custom-build support." or err; A:Refresh()
    end)
    transfer.details=label(transfer,"",0,252,704)
end
function U:Layout(width)
    local class=A:GetContext().characterClass:upper(); self.class=class
    self.page.title:SetText("Custom Builds & Stat Weights")
    self.page.subtitle:SetText("Talent paths and stat weights are saved and shared together. Available to all your characters.")
    self.messageText:SetText(self.message or "")
    local start=self.message and (54+self.messageText:GetStringHeight()+8) or 54
    for _,frame in ipairs({self.list,self.editor,self.transfer}) do
        frame:ClearAllPoints(); frame:SetPoint("TOPLEFT",0,-start)
    end
    self.list:SetShown(self.mode=="library" or not self.mode); self.editor:SetShown(self.mode=="edit"); self.transfer:SetShown(self.mode=="transfer")
    self.list:SetWidth(width); self.editor:SetWidth(width); self.transfer:SetWidth(width)
    -- Each mode is a child frame inside the Settings scroll child. Size the
    -- active container as well as the outer content; zero-height containers
    -- can be culled by the client even when their children have valid anchors.
    if self.mode=="edit" then
        local d,e=self.draft,self.editor
        e.profile.label:SetText("Scoring: "..A.Data.AdvisorGear[d.class][d.profile].name.."  >")
        local _,actual=UnitClass("player"); e.current:SetEnabled(actual==d.class and A:GetContext().mode~="preview")
        e.clear.label:SetText(self.clearArmed and "Confirm Clear" or "Clear Path")
        e.hint:SetText(d.class.." | "..#d.steps.." / 51 points. Click talents to add points in leveling order. Saving does not spend points.")
        for _,b in pairs(e.nodes) do b:Hide() end
        local ranks,trees={}, {0,0,0}
        for _,key in ipairs(d.steps) do ranks[key]=(ranks[key] or 0)+1; local t=A.Data.AdvisorTalents[d.class][key]; trees[t.tree]=trees[t.tree]+1 end
        for key,node in pairs(A.Data.AdvisorTalents[d.class]) do
            local id=d.class..":"..key; local b=e.nodes[id]
            if not b then
                b=button(e,"",0,0,44,function() if B:CanAdd(self.draft,key) then self.draft.steps[#self.draft.steps+1]=key; self.clearArmed=nil; A:Refresh() end end)
                b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetSize(30,30); b.icon:SetPoint("TOP",0,-2)
                b.label:ClearAllPoints(); b.label:SetPoint("BOTTOM",0,0); b.label:SetHeight(16)
                b:SetScript("OnEnter",function()
                    GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink("spell:"..node.spellID)
                    local rank=0; for _,k in ipairs(self.draft.steps) do if k==key then rank=rank+1 end end
                    GameTooltip:AddLine(node.name.." | "..rank.." / "..node.maxRank,1,0.8,0.4)
                    GameTooltip:AddLine("Click to add the next point. Requires tier and prerequisite talents.",1,1,1,true); GameTooltip:Show()
                end)
                b:SetScript("OnLeave",function() GameTooltip:Hide() end); e.nodes[id]=b
            end
            local cell=(width-20)/12
            b:ClearAllPoints(); b:SetPoint("TOPLEFT",((node.tree-1)*4+node.column-1)*cell,-124-(node.tier-1)*49); b:SetSize(cell-6,46); b:Show()
            local texture=C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(node.spellID)
                or GetSpellTexture and GetSpellTexture(node.spellID)
            b.icon:SetTexture(texture or 134400)
            b.icon:SetAlpha(B:CanAdd(d,key) and 1 or .4); b.label:SetText((ranks[key] or 0).."/"..node.maxRank)
            e.trees[node.tree]:SetText(node.treeName.." ("..trees[node.tree]..")"); e.trees[node.tree]:ClearAllPoints()
            e.trees[node.tree]:SetPoint("TOPLEFT",(node.tree-1)*(width-20)/3,-100)
        end
        local counted={}
        for i,key in ipairs(d.steps) do
            local b=e.pathRows[i]
            if not b then b=button(e,"",370,530+(i-1)*30,334,function() for n=#self.draft.steps,i,-1 do self.draft.steps[n]=nil end; A:Refresh() end); e.pathRows[i]=b end
            counted[key]=(counted[key] or 0)+1
            b.label:SetText((i+9).."  |  "..A.Data.AdvisorTalents[d.class][key].name.." "..counted[key]); b.label:SetJustifyH("LEFT"); b:Show()
        end
        for i=#d.steps+1,#e.pathRows do e.pathRows[i]:Hide() end
        e:SetHeight(550+math.max(#A.GearAdvisor.WeightFields*32,#d.steps*30))
        return start+e:GetHeight()
    elseif self.mode=="transfer" then
        self.transfer.import:SetEnabled(self.preview~=nil)
        local p=self.preview; local text="Review the build code before importing. Import creates a separate copy and does not select or apply it. Selecting or editing custom builds disables automatic talent spending until you enable it again."
        if p then
            local rows={p.name.." | "..p.class.." | "..#p.steps.." points","Scoring: "..A.Data.AdvisorGear[p.class][p.profile].name,"","Talent path:"}
            for i,key in ipairs(p.steps) do rows[#rows+1]=(i+9)..": "..A.Data.AdvisorTalents[p.class][key].name end
            rows[#rows+1]=""; rows[#rows+1]="Stat weights:"
            for _,f in ipairs(A.GearAdvisor.WeightFields) do rows[#rows+1]=f[2]..": "..p.weights[f[1]] end
            text=table.concat(rows,"\n")
        end
        self.transfer.details:SetText(text)
        self.transfer:SetHeight(278+(p and (#p.steps+#A.GearAdvisor.WeightFields+7)*16 or 40))
        return start+self.transfer:GetHeight()
    end
    local builds=B:List(class)
    self.list.hint:SetText(class.." | "..#builds.." custom builds. Create copies or import talent paths with their stat weights.")
    for i,build in ipairs(builds) do
        local r=self.list.rows[i]
        if not r then
            r=CreateFrame("Frame",nil,self.list,"BackdropTemplate"); self.list.rows[i]=r; S.Paint(r,"card"); r:SetSize(width-12,72)
            r.title=label(r,"",10,6,680,14)
            r.use=button(r,"Use",10,34,100,function() A.TalentAdvisor:Activate({command="build",class=r.build.class,id=r.build.id}) end)
            r.edit=button(r,"Edit",118,34,100,function() self:Edit(r.build,r.build.id) end)
            r.share=button(r,"Share / Export",226,34,150,function() self:Transfer(r.build) end)
            r.delete=button(r,"Delete",384,34,140,function()
                if self.deleteID==r.build.id then B:Delete(r.build.id); self.deleteID=nil else self.deleteID=r.build.id end; A:Refresh()
            end)
        end
        r.build=build; r:SetPoint("TOPLEFT",0,-60-(i-1)*80); r:Show(); r:SetWidth(width-12)
        r.use:SetEnabled(A.TalentAdvisor:IsEnabled())
        local selected=A.TalentAdvisor:Build(class,A:GetContext().level)
        r.title:SetText(build.name.." | "..#build.steps.." points"..(selected and selected.id==build.id and " | Selected" or ""))
        r.delete.label:SetText(self.deleteID==build.id and "Confirm Delete" or "Delete")
    end
    for i=#builds+1,#self.list.rows do self.list.rows[i]:Hide() end
    self.list:SetHeight(68+#builds*80)
    return start+self.list:GetHeight()
end
