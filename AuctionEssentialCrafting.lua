-- Learned recipes only; saved bank contents never include another character.
local _,A=...
local E=A.AuctionEssentials
local baseItems=E.Items
E.craftChoices={}; E.craftManual={}; E.materialOverrides={}; E.autoMaterials={}
local function id(link) return type(link)=="string" and tonumber(link:match("item:(%d+)")) end
local function db() return A.characterDB end
function E:CaptureRecipes()
    if not db() or not GetNumTradeSkills or not GetTradeSkillItemLink or not GetTradeSkillReagentItemLink then return end
    local saved=db().auctionRecipes or {}; db().auctionRecipes=saved
    for i=1,GetNumTradeSkills() do
        local itemID=id(GetTradeSkillItemLink(i))
        local link=GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
        local spell=link and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)"))
        local output=GetTradeSkillNumMade and GetTradeSkillNumMade(i)
        if itemID and spell and output and output>0 then
            local recipe={spellId=spell,output=output,reagents={}}
            local complete=true
            for j=1,GetTradeSkillNumReagents(i) do
                local reagent=id(GetTradeSkillReagentItemLink(i,j))
                local name,_,quantity=GetTradeSkillReagentInfo(i,j)
                if not reagent or not quantity or quantity<=0 then complete=false; break end
                recipe.reagents[#recipe.reagents+1]={reagent,quantity,name}
            end
            if complete and #recipe.reagents>0 then saved[itemID]=recipe end
        end
    end
end
function E:Recipe(itemID)
    local recipe=db() and db().auctionRecipes and db().auctionRecipes[itemID] or A.Data.AuctionRecipes[itemID]
    if not recipe then return end
    local known=C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not known then return end
    local ok,value=pcall(known,recipe.spellId)
    if ok and value==true then return recipe end
end
function E:CaptureBank()
    if not self.bankOpen or not db() or not C_Container then return end
    local counts={}
    for _,bag in ipairs({-1,5,6,7,8,9,10,11}) do
        local size=C_Container.GetContainerNumSlots(bag)
        if type(size)~="number" or size<0 or bag==-1 and size==0 then return end
        for slot=1,size do
            local info=C_Container.GetContainerItemInfo(bag,slot)
            if info then
                if not info.itemID or not info.stackCount then return end
                counts[info.itemID]=(counts[info.itemID] or 0)+info.stackCount
            end
        end
    end
    self.bankDraft={counts=counts,at=time and time() or 0}
end
local function materialName(pair)
    local info=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name=info and info(pair[1])
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(pair[1]) end
    return name or pair[3],name~=nil or pair[3]~=nil
end
function E:Items(context)
    local parents=baseItems(self,context)
    local out,demands,stockUsed={}, {}, {}
    local inventory=context.inventory or {}
    local bank=db() and db().auctionBank
    for _,parent in ipairs(parents) do
        local recipe=self:Recipe(parent.itemId)
        parent.craftable=recipe~=nil; parent.children={}
        parent.crafting=recipe and self.craftChoices[parent.itemId]==true
        out[#out+1]=parent
        if recipe and (parent.missing or 0)>0 then
            local crafts=math.ceil(parent.missing/recipe.output)
            for _,pair in ipairs(recipe.reagents) do
                local mid,required=pair[1],pair[2]*crafts
                local bags=inventory.available and (inventory.counts[mid] or 0) or nil
                local banks=bank and (bank.counts[mid] or 0) or 0
                local mail=self:MailCount(mid)
                local used=parent.crafting and (stockUsed[mid] or 0) or 0
                local have=bags and math.max(0,bags+banks+mail-used)
                local fromBags=bags and math.min(required,math.max(0,bags-used)) or 0
                local fromBank=have and math.min(required-fromBags,math.max(0,banks-math.max(0,used-bags))) or 0
                local fromMail=have and math.min(required-fromBags-fromBank,math.max(0,mail-math.max(0,used-bags-banks))) or 0
                local missing=have and math.max(0,required-have)
                local name,ready=materialName(pair)
                local child={itemId=mid,name=name or ("Item "..mid),nameReady=ready,craftParent=parent.itemId,
                    craftActive=parent.crafting,
                    item={itemId=mid},target=required,count=have,missing=missing,bagUsed=fromBags,bankUsed=fromBank,mailUsed=fromMail,
                    bankCount=banks,mailCount=mail,
                    bankKnown=bank~=nil,tracking=true}
                parent.children[#parent.children+1]=child
                if missing==nil or missing>0 then out[#out+1]=child end
                if parent.crafting then
                    stockUsed[mid]=used+required
                    local demand=demands[mid]
                    if not demand then
                        demand={itemId=mid,name=child.name,nameReady=ready,item=child.item,count=bags and bags+banks+mail,
                            target=0,missing=0,tracking=true,material=true}
                        demands[mid]=demand
                    end
                    demand.target=demand.target+required
                    demand.missing=demand.count and math.max(0,demand.target-demand.count) or nil
                end
            end
        end
    end
    for mid in pairs(self.autoMaterials) do if not demands[mid] then self.selected[mid]=nil end end
    self.autoMaterials={}; self.materialRecords=demands
    for mid,r in pairs(demands) do
        self.autoMaterials[mid]=true
        self.selected[mid]=(r.missing or 0)>0 and self.materialOverrides[mid]~=false or nil
    end
    return out
end
function E:ToggleCraft(record)
    if not record or not record.craftable or self.scan or self.batch or self.confirmation or self.awaitingBuy then return end
    self.craftManual[record.itemId]=true
    local enabled=not self.craftChoices[record.itemId]
    self.craftChoices[record.itemId]=enabled
    self.selected[record.itemId]=nil
    for _,child in ipairs(record.children) do self.materialOverrides[child.itemId]=nil end
    self:Refresh()
end
local toggle=E.Toggle
function E:Toggle(record)
    if not record or self.scan or self.batch or self.confirmation or self.awaitingBuy then return end
    if record.craftParent then
        if not record.craftActive or not record.missing or record.missing<=0 then return end
        self.materialOverrides[record.itemId]=not self.selected[record.itemId]
        self:Refresh()
    else
        if record.craftable then self.craftManual[record.itemId]=true end
        if record.craftable and not self.selected[record.itemId] then self.craftChoices[record.itemId]=false end
        toggle(self,record)
    end
end
function E:PurchaseRecords()
    local out,seen={},{}
    for _,r in ipairs(self.items or {}) do
        if not r.craftParent then
            local material=self.materialRecords and self.materialRecords[r.itemId]
            if material then
                local copy={}; for k,v in pairs(material) do copy[k]=v end
                if not r.crafting and self.selected[r.itemId] then
                    copy.target=copy.target+r.target
                    copy.missing=copy.count and math.max(0,copy.target-copy.count)
                end
                out[#out+1]=copy
            else out[#out+1]=r end
            seen[r.itemId]=true
        end
    end
    for mid,r in pairs(self.materialRecords or {}) do if not seen[mid] then out[#out+1]=r end end
    return out
end
function E:ScanItems()
    self.items=self:Items(A:GetContext())
    local out,seen,candidates={},{},{}
    for _,r in ipairs(self.items) do
        candidates[#candidates+1]=r
        -- Hidden, owned reagents can still be shared by several recipes. Keep
        -- their prices available when the combined crafting demand exceeds stock.
        for _,child in ipairs(r.children or {}) do candidates[#candidates+1]=child end
    end
    for _,r in ipairs(candidates) do
        if not seen[r.itemId] then
            if r.nameReady==false then return nil,"Waiting for material names. Try Scan again." end
            seen[r.itemId]=true; out[#out+1]=r
        end
    end
    return out
end
function E:PlanNeeds(itemID)
    local needs,seen={},{}
    for _,list in ipairs({self.items or {},self:PurchaseRecords()}) do
        for _,r in ipairs(list) do
            if r.itemId==itemID and r.missing~=nil and not seen[r.missing] then
                seen[r.missing]=true; needs[#needs+1]=r.missing
            end
        end
    end
    return needs
end
function E:CraftCost(parent)
    local cost=0
    for _,child in ipairs(parent.children or {}) do
        if child.missing==nil then return end
        if child.missing>0 then
            local result=self.results[child.itemId]
            local plan=result and result.plans and result.plans[child.missing]
            if not plan or plan.units<child.missing then return end
            cost=cost+plan.cost
        end
    end
    return cost
end
-- Runs in the scan coroutine so larger whole-stack plans can yield.
function E:SelectCheaperCrafts()
    local context=A:GetContext()
    for id in pairs(self.craftChoices) do if not self.craftManual[id] then self.craftChoices[id]=nil end end
    local function plan(id,need)
        local result=self.results[id]
        if not result then return end
        result.plans=result.plans or {}
        if not result.plans[need] then result.plans[need]=self:RefillPlan(result.offers or {},need,nil,true) end
        return result.plans[need]
    end
    self.items=self:Items(context)
    local candidates={}
    for _,r in ipairs(self.items) do
        if r.craftable and not self.craftManual[r.itemId] and not self.selected[r.itemId] and (r.missing or 0)>0 then candidates[#candidates+1]=r.itemId end
    end
    for _,id in ipairs(candidates) do
        self.craftChoices[id]=true
        self.items=self:Items(context)
        local parent
        for _,r in ipairs(self.items) do if r.itemId==id and not r.craftParent then parent=r; break end end
        if parent then
            local buy=plan(id,parent.missing)
            for _,child in ipairs(parent.children) do if child.missing and child.missing>0 then plan(child.itemId,child.missing) end end
            local cost=self:CraftCost(parent)
            if not buy or buy.units<parent.missing or not cost or cost>=buy.cost then self.craftChoices[id]=nil end
        else self.craftChoices[id]=nil end
    end
    self.items=self:Items(context)
    for _,r in ipairs(self:PurchaseRecords()) do if r.missing and r.missing>0 then plan(r.itemId,r.missing) end end
end
function E:CraftNotice()
    local bags,bank,mail,craftable=false,false,false,false
    local children={}
    for _,parent in ipairs(self.items or {}) do
        craftable=craftable or parent.craftable
        for _,child in ipairs(parent.children or {}) do children[#children+1]=child end
    end
    for _,r in ipairs(children) do
        local demand=r.craftParent and self.materialRecords[r.itemId]
        local result=demand and self.results[r.itemId]
        local plan=result and result.plans and result.plans[demand.missing]
        if r.craftActive and self.selected[r.itemId] and plan and plan.units>=demand.missing and plan.units<demand.target then
            bags=bags or r.bagUsed>0; bank=bank or r.bankUsed>0; mail=mail or r.mailUsed>0
        end
    end
    if bags or bank or mail then
        local locations={}; if bags then locations[#locations+1]="bags" end; if bank then locations[#locations+1]="bank" end; if mail then locations[#locations+1]="mail" end
        local location=#locations==3 and "bags, bank and mail" or table.concat(locations," and ")
        local text="Material purchases cover the shortfall. Combine them with materials in your "..location.."."
        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffcd52HardcoreBuddy:|r "..text) end
        return " "..text
    end
    if craftable and not (db() and db().auctionBank) then return " Open and close your bank once to save stored materials." end
    return ""
end
local events=CreateFrame("Frame")
E.craftingEvents=events
for _,event in ipairs({"TRADE_SKILL_SHOW","TRADE_SKILL_UPDATE","BANKFRAME_OPENED","BANKFRAME_CLOSED","PLAYERBANKSLOTS_CHANGED","BAG_UPDATE_DELAYED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="BANKFRAME_OPENED" then E.bankOpen=true; E.bankDraft=nil
    elseif event=="BANKFRAME_CLOSED" then
        E:CaptureBank()
        if db() and E.bankDraft then db().auctionBank=E.bankDraft end
        E.bankOpen=false; E.bankDraft=nil
    elseif event=="TRADE_SKILL_SHOW" or event=="TRADE_SKILL_UPDATE" then E:CaptureRecipes()
    else E:CaptureBank() end
end)
