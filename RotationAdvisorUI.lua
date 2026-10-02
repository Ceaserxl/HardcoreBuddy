local _,A=...
local R,S=A.RotationAdvisor,A.Skin
local legend="|cffffd100Gold: Main|r   |cffcc40ffPurple: Offensive|r   |cffff2626Red: Defensive|r   |cff268cffBlue: Preparation|r"
local descriptions={}
for _,key in ipairs(R.categoryOrder) do descriptions[#descriptions+1]=R.categories[key].description end
local modeHelp=table.concat(descriptions,"\n")
local function text(parent,value,x,y,width,style)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    S.TextStyle(f,style or "subtitle"); f:SetPoint("TOPLEFT",x,-y); f:SetWidth(width)
    f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetText(value); return f
end
local function button(parent,label,width,callback)
    local b=CreateFrame("Button",nil,parent,"BackdropTemplate"); b:SetSize(width,28)
    b.label=text(b,label,4,0,width-8); b.label:SetAllPoints(); b.label:SetJustifyH("CENTER"); b.label:SetJustifyV("MIDDLE")
    S.Button(b,"utility"); b:SetScript("OnClick",callback); return b
end
local function pct(value) return value and math.floor(value+.5).."%" or "Unknown" end
function R:CreateSettings(page)
    self.settingsPage=page
    page.subtitle=text(page,"Mage combat | All-class consumables | Per character | Disabled by default",0,30,720)
    page.mode=S.Section(page,"Mode",60,114)
    page.buttons={}
    for i,key in ipairs({"assistant","disabled"}) do
        local b=button(page.mode,self.modes[key],220,function() self:SetMode(key) end)
        b:SetPoint("TOPLEFT",16+(i-1)*238,-38); page.buttons[key]=b
    end
    page.help=text(page.mode,modeHelp,16,78,704)
    page.damage=S.Section(page,"Mage Damage",182,100,1)
    page.damage.note=text(page.damage,"Gold shows the next action, including setup such as Nova before Frostbolt. The choice stays fixed during a cast unless urgent or invalid. Learned spells, talents, gear, range and readiness determine eligibility.",16,38,320)
    page.survival=S.Section(page,"Mage Survival",182,100,2)
    page.survival.note=text(page.survival,"Red: situational protection and interrupts. Purple: optional damage cooldowns. Blue: buffs and recovery, whether missing or expiring. An urgent response becomes the single gold Main action.",16,38,320)
end
function R:LayoutSettings(width)
    local page=self.settingsPage; if not page then return end
    local _,class=UnitClass("player"); local supported=A.ConsumableBuffs.classes[class]~=nil
    local first=S.SettingsHeader(page,width,page.title,page.subtitle)
    page.mode.sectionTop=first
    S.LayoutSections(page,width)
    local available=page.mode:GetWidth()-32; local cell=(available-8)/2
    for i,key in ipairs({"assistant","disabled"}) do
        local b=page.buttons[key]; b:ClearAllPoints(); b:SetPoint("TOPLEFT",16+(i-1)*(cell+8),-38); b:SetWidth(cell)
        b.selected=self:Mode()==key; S.ControlEnabled(b,key=="disabled" or key=="assistant" and supported); S.ButtonState(b,b.selected,nil,false)
    end
    page.help:SetText(self.supported[class] and modeHelp
        or modeHelp.."\nConsumable preparation supports all classes; combat advice currently supports Mage.")
    page.help:SetWidth(available); page.help:SetHeight(0)
    page.help:SetHeight(page.help:GetStringHeight())
    page.mode:SetHeight(78+page.help:GetHeight()+16)
    local height=0
    for _,panel in ipairs({page.damage,page.survival}) do
        panel.note:SetWidth(panel:GetWidth()-32); panel.note:SetHeight(0)
        panel.note:SetHeight(panel.note:GetStringHeight())
        panel.sectionTop=first+page.mode:GetHeight()+S.layout.sectionGap
        height=math.max(height,38+panel.note:GetHeight()+16)
    end
    page.damage:SetHeight(height); page.survival:SetHeight(height); S.LayoutSections(page,width)
    page.contentHeight=page.damage.sectionTop+height+S.layout.sectionGap
    return page.contentHeight
end
function R:CreateView(parent)
    local view=CreateFrame("Frame",nil,parent); self.view=view
    view.title=text(view,"Rotation Advisor",0,0,500,"page")
    view.subtitle=text(view,"",0,30,700)
    view.settings=button(view,"Settings",120,function() A:OpenSettings("Rotation Advisor") end)
    view.next=S.Section(view,"Next Spell",60,126)
    view.next.icon=view.next:CreateTexture(nil,"ARTWORK"); view.next.icon:SetSize(40,40); view.next.icon:SetPoint("TOPLEFT",16,-38)
    S.IconBorder(view.next,view.next.icon)
    view.next.name=text(view.next,"",64,38,600,"section")
    view.next.reason=text(view.next,"",64,60,600)
    view.next.bar=text(view.next,"",16,94,690)
    view.next:EnableMouse(true)
    view.next:SetScript("OnEnter",function(frame)
        if self.current then
            GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink((self.current.item and "item:" or "spell:")..self.current.id)
            local category=self.categories[self.current.category]
            if category then GameTooltip:AddLine(category.description,1,.8,.4,true) end
            if self.reason and self.reason~="" then GameTooltip:AddLine(self.reason,1,.8,.4,true) end
            GameTooltip:Show()
        end
    end)
    view.next:SetScript("OnLeave",function() GameTooltip:Hide() end)
    view.character=S.Section(view,"Character",182,118,1); view.target=S.Section(view,"Target",182,118,2)
    view.character.values=text(view.character,"",16,38,320)
    view.target.values=text(view.target,"",16,38,320)
end
function R:LayoutView(parent,width,visible)
    if not self.view and not visible then return 0 end
    if not self.view then self:CreateView(parent) end
    self.view:SetShown(visible); if not visible then return 0 end
    local view=self.view
    view:ClearAllPoints(); view:SetPoint("TOPLEFT",0,0); view:SetWidth(width)
    local first=S.SettingsHeader(view,width,view.title,view.subtitle,view.settings)
    view.next.sectionTop=first
    view.character.sectionTop=first+view.next:GetHeight()+S.layout.sectionGap
    view.target.sectionTop=view.character.sectionTop
    S.LayoutSections(view,width)
    view.next.name:SetWidth(width-92); view.next.reason:SetWidth(width-92); view.next.bar:SetWidth(width-36)
    view.character.values:SetWidth(view.character:GetWidth()-32); view.target.values:SetWidth(view.target:GetWidth()-32)
    view:SetHeight(view.character.sectionTop+view.character:GetHeight()+S.layout.sectionGap)
    self:PrepareHighlights(); self:Update(); self:RefreshView()
    return view:GetHeight()
end
function R:RefreshView()
    local view=self.view; if not view or not view:IsVisible() then return end
    local _,class=UnitClass("player"); local mode=self:Mode(); local s=self.snapshot or {}
    view.subtitle:SetText("Live "..(A.ConsumableBuffs.classes[class] or class or "character").." | "..self.modes[mode].." | Levels 1–60")
    local spell=self.current
    view.next.title:SetText(spell and self.categories[spell.category] and self.categories[spell.category].name or "Next Action")
    view.next.icon:SetTexture(spell and spell.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    view.next.icon:SetAlpha(spell and 1 or .35)
    view.next.name:SetText(spell and (spell.name..(spell.rank and spell.rank~="" and (" | "..spell.rank) or "")) or mode=="disabled" and "Disabled" or "Waiting")
    view.next.reason:SetText(self.reason or "")
    local currentCount=self.optional and self.optionalHighlightCount or self.primaryHighlightCount
    view.next.bar:SetText(mode=="assistant" and (spell and ((currentCount or 0)>0 and legend or "Place this action on a Blizzard action bar to see its highlight.") or "No spell highlighted.")
        or "Enable Assistant Mode in Settings to begin.")
    view.character.values:SetText(mode=="disabled" and "Live monitoring is off." or
        "Health: "..pct(s.playerHealth).."\nMana: "..pct(s.powerPercent)
        .."\nMoving: "..(s.moving and "Yes" or "No").."\nPlanning ahead: "..string.format("%.1fs",s.powerHorizon or self.lookahead))
    view.target.values:SetText(mode=="disabled" and "Live monitoring is off." or
        not s.validTarget and "Select a living enemy." or
        "Health: "..pct(s.targetHealth).." | Mana: "..(s.targetPowerType==0 and pct(s.targetMana) or "Not a mana user")
        .."\nVisible engaged enemies: "..(s.targets or 0).." | Close: "..(s.nearby or 0)
        .."\nSpell range: "..(spell and spell.range==true and "In range" or "Unknown")
        .."\nCounts only observed units; proximity may be unknown.")
end
