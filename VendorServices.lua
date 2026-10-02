-- Local vendor guidance and purchases verified against the open merchant.
local addonName,A=...
local V={}; A.VendorServices=V
-- Standard Classic thrown weapons sold by general goods / weapon vendors.
-- Deliberately exclude limited-stock greens, recipes and reputation rewards.
local unlimitedThrown={[2947]=true,[2946]=true,[3107]=true,[3108]=true,[15327]=true,
    [3111]=true,[3131]=true,[3135]=true,[3137]=true,[15326]=true}
function V:UnlimitedSource(link)
    local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
    if not id then return end
    if unlimitedThrown[id] then return "General goods and thrown-weapon vendors" end
    local faction=UnitFactionGroup and UnitFactionGroup("player")
    local friendly=faction=="Alliance" and "A" or faction=="Horde" and "H"
    for _,vendor in pairs(A.characterDB and A.characterDB.vendorVisits or {}) do
        if (vendor.faction==friendly or vendor.faction=="AH") and vendor.unlimited and vendor.unlimited[id] then
            return vendor.name
        end
    end
end
local function money(amount)
    return GetCoinTextureString and GetCoinTextureString(amount) or tostring(amount).." copper"
end
local function position()
    local map=C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local point=map and C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map,"player")
    local x,y
    if point then x,y=point:GetXY() end
    return map,x and x*100,y and y*100
end
function V:FindVendor(itemID)
    local map,x,y=position()
    if not map then return end
    local faction=UnitFactionGroup and UnitFactionGroup("player")
    local friendly=faction=="Alliance" and "A" or faction=="Horde" and "H"
    local best,nearest,bestRank
    local function consider(v,id,observed)
        if not v or not (v.faction=="AH" or v.faction==friendly) then return end
        local canonical=A.Data.SupplyVendors[id]
        local movement=canonical and canonical.movement or v.movement or "unknown"
        local rank=movement=="stationary" and 0 or movement=="roaming" and 2 or 1
        -- Prefer catalog coordinates to the player's location recorded at a shop.
        local locations=canonical and canonical.locations or v.locations
        for _,xy in ipairs(locations and locations[map] or {}) do
            local distance=x and y and ((x-xy[1])^2+(y-xy[2])^2) or math.huge
            if not best or rank<bestRank or rank==bestRank and distance<nearest then
                best={name=v.name,faction=v.faction,movement=movement,map=map,x=xy[1],y=xy[2],id=id,observed=observed}
                nearest,bestRank=distance,rank
                best.distance,best.movementRank=distance,rank
            end
        end
    end
    for _,id in ipairs(A.Data.SupplySoldBy[itemID] or {}) do consider(A.Data.SupplyVendors[id],id) end
    for id,v in pairs(A.characterDB.vendorVisits or {}) do if v.items and v.items[itemID] then consider(v,id,true) end end
    return best
end
-- Exact-item sources first; plain vendor recovery food can use an explicitly
-- named equivalent. Never substitute buff food, recipes or reputation rewards.
function V:FindSupplyVendor(itemID,count)
    local exact=self:FindVendor(itemID)
    if exact then return exact end
    if type(count)~="number" or not (count>=0 and count<5) then return end
    local source
    for _,item in ipairs(A.Data.Items.items) do if item.itemId==itemID then source=item; break end end
    if not source or not source.vendorFood then return end
    local best
    for _,item in ipairs(A.Data.Items.items) do
        if item.vendorFood and item.family==source.family and item.level==source.level and item.itemId~=itemID then
            local vendor=self:FindVendor(item.itemId)
            if vendor and (not best or vendor.movementRank<best.movementRank
                or vendor.movementRank==best.movementRank and vendor.distance<best.distance) then
                best=vendor; best.alternativeName=item.name; best.alternativeID=item.itemId
            end
        end
    end
    return best
end
function V:Stock()
    local list={}
    if not self.open or not GetMerchantNumItems or not GetMerchantItemInfo or not GetMerchantItemLink then return list end
    for i=1,GetMerchantNumItems() do
        local link=GetMerchantItemLink(i)
        local id=type(link)=="string" and tonumber(link:match("item:(%d+)"))
        local name,_,price,bundle,available,purchasable,_,extended=GetMerchantItemInfo(i)
        if id and name and type(price)=="number" and price>=0 and type(bundle)=="number" and bundle>=1 then
            list[#list+1]={index=i,id=id,name=name,price=price,bundle=bundle,available=available,
                purchasable=purchasable~=false and not extended}
        end
    end
    return list
end
function V:LearnVendor(stock)
    local name=UnitName and UnitName("npc")
    local guid=UnitGUID and UnitGUID("npc")
    local id=guid and tonumber(guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
    local map,x,y=position()
    if not name or not id or not map or not x or not y then return end
    local visits=A.characterDB.vendorVisits or {}; A.characterDB.vendorVisits=visits
    local faction=UnitFactionGroup and UnitFactionGroup("player")
    local record=visits[id] or {name=name,faction=faction=="Horde" and "H" or "A",items={},locations={}}
    record.name=name; record.locations[map]={{x,y}}
    record.unlimited=record.unlimited or {}
    for _,item in ipairs(stock) do
        record.items[item.id]=true
        -- -1 is unlimited; zero means sold out, never unlimited. Old boolean
        -- visit records carry no stock evidence and are intentionally ignored.
        record.unlimited[item.id]=item.available==-1 and item.purchasable or nil
    end
    visits[id]=record
end
function V:Capacity(id,maxStack)
    local C=C_Container
    if not C or not C.GetContainerNumFreeSlots or not C.GetContainerNumSlots or not C.GetContainerItemInfo then return 0 end
    local getFamily=(C_Item and C_Item.GetItemFamily) or GetItemFamily
    local family=getFamily and getFamily(id) or 0
    local capacity=0
    for bag=0,4 do
        local free,bagFamily=C.GetContainerNumFreeSlots(bag)
        if type(free)=="number" and (bagFamily==0 or bagFamily and bit and bit.band(bagFamily,family)~=0) then capacity=capacity+free*maxStack end
        for slot=1,C.GetContainerNumSlots(bag) do
            local item=C.GetContainerItemInfo(bag,slot)
            if item and item.itemID==id and not item.isLocked then capacity=capacity+math.max(0,maxStack-item.stackCount) end
        end
    end
    return capacity
end
function V:Plan()
    local plan,total={},0
    local context=A.Readiness:LiveContext()
    if not context or not context.inventory.available then return plan,total end
    local needed={}
    for _,item in ipairs(A.Readiness:Missing(context,true)) do
        if item.refillNeeded~=false or self.refilling and self.refilling[item.itemId] then
            needed[item.itemId]=math.max(needed[item.itemId] or 0,item.missing)
        end
    end
    local budget=GetMoney and GetMoney() or 0
    local stock=self:Stock(); self:LearnVendor(stock)
    for _,item in ipairs(stock) do
        local missing=needed[item.id]
        if missing and missing>0 and item.purchasable and type(item.available)=="number" and item.available~=0 then
            local maxStack=GetMerchantItemMaxStack and GetMerchantItemMaxStack(item.index) or item.bundle
            maxStack=type(maxStack)=="number" and math.max(item.bundle,maxStack) or item.bundle
            local qty=math.min(missing,self:Capacity(item.id,maxStack),item.available<0 and missing or item.available)
            if item.price>0 then qty=math.min(qty,math.floor(budget/item.price)*item.bundle) end
            qty=math.floor(qty/item.bundle)*item.bundle
            if qty>0 then
                item.quantity=qty; item.maxStack=maxStack; item.cost=math.ceil(qty/item.bundle*item.price)
                budget=budget-item.cost; total=total+item.cost; needed[item.id]=nil
                plan[#plan+1]=item
            end
        end
    end
    return plan,total
end
function V:Stop()
    self.running=nil; self.pending=nil; self.refilling=nil
    if self.prompt then self.prompt:Hide() end
end
function V:Buy(automatic)
    if not self.open or InCombatLockdown() then return end
    self.decided=true; self.automatic=automatic==true; self.running=true; self.refilling={}
    if self.prompt then self.prompt:Hide() end
    self.nextAt=GetTime()
end
function V:Tick()
    if not self.open or InCombatLockdown() then self:Stop(); return end
    local now=GetTime()
    if self.pending then
        local p=self.pending; local inventory=A.Inventory.Read()
        local gained=inventory.available and (inventory.counts[p.id] or 0)-p.before or 0
        if gained>0 then
            A:Print((self.automatic and "Auto bought " or "Bought ")..math.min(gained,p.quantity).." x "..p.name.." for "..money(math.min(gained,p.quantity)/p.bundle*p.price)..".")
            self.pending=nil; self.nextAt=now+0.2; A.Readiness:SuppliesChanged()
        elseif now>=p.deadline then
            self:Stop(); A:Print("Purchase was not confirmed. Check vendor stock, bag space and money before trying again.")
        end
        return
    end
    if self.decided and not self.running then return end
    if now<(self.nextAt or 0) then return end
    self.nextAt=now+0.2
    local plan,total=self:Plan()
    if self.running then
        if #plan==0 then self:Stop(); return end
        local item=plan[1]
        local qty=math.floor(math.min(item.quantity,item.maxStack)/item.bundle)*item.bundle
        if qty<1 or not BuyMerchantItem then self:Stop(); return end
        local inv=A.Inventory.Read(); if not inv.available then self:Stop(); return end
        self.refilling[item.id]=true
        self.pending={id=item.id,name=item.name,quantity=qty,before=inv.counts[item.id] or 0,
            bundle=item.bundle,price=item.price,deadline=now+3}
        local ok=pcall(BuyMerchantItem,item.index,qty)
        if not ok then self:Stop(); A:Print("Unable to buy this supply.") end
    elseif not self.decided and #plan>0 then
        if self.settings.autoBuy then self:Buy(true) else self:ShowPrompt(plan,total) end
    elseif self.prompt then
        self.prompt:Hide()
    end
end
function V:Repair()
    if not self.settings.autoRepair or not CanMerchantRepair or not CanMerchantRepair() or not GetRepairAllCost or not RepairAllItems then return end
    local cost,needed=GetRepairAllCost()
    if needed and type(cost)=="number" and cost>0 and GetMoney and GetMoney()>=cost and not InCombatLockdown() then
        RepairAllItems(false)
    end
end
function V:ShowPrompt(plan,total)
    if not self.prompt then
        local f=CreateFrame("Frame",nil,UIParent,"BackdropTemplate"); self.prompt=f
        A.Skin.Paint(f,"card"); f:SetFrameStrata("DIALOG"); f:SetSize(440,220); f:SetPoint("CENTER"); f:SetClampedToScreen(true)
        local function label(value,y,role)
            local t=f:CreateFontString(nil,"OVERLAY","GameFontHighlight"); A.Skin.TextStyle(t,role or "subtitle")
            t:SetPoint("TOPLEFT",16,-y); t:SetWidth(408); t:SetText(value); return t
        end
        f.title=label("Missing essentials",16,"section")
        f.question=label("Would you like to buy missing essentials?",42)
        f.items=label("",66)
        f.auto=CreateFrame("CheckButton",nil,f,"BackdropTemplate"); f.auto:SetSize(24,24); A.Skin.Paint(f.auto,"edit")
        f.auto.mark=f.auto:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f.auto.mark:SetAllPoints()
        f.auto.caption=label("Auto Buy Next Time?",0); f.auto.caption:ClearAllPoints(); f.auto.caption:SetPoint("LEFT",f.auto,"RIGHT",8,0)
        f.auto.caption:SetWidth(360)
        f.auto:SetScript("OnClick",function(b) b.mark:SetText(b:GetChecked() and "X" or "") end)
        local function button(text,x,click)
            local b=CreateFrame("Button",nil,f,"BackdropTemplate"); b:SetSize(196,28); b:SetPoint("BOTTOMLEFT",x,16)
            b.label=b:CreateFontString(nil,"OVERLAY","GameFontHighlight"); b.label:SetAllPoints(); b.label:SetText(text)
            A.Skin.Button(b,"utility"); b:SetScript("OnClick",click); return b
        end
        f.buy=button("Buy missing supplies",16,function()
            self.settings.autoBuy=not not f.auto:GetChecked(); self:Buy(false)
        end)
        f.cancel=button("Not now",228,function() self.decided=true; f:Hide() end)
    end
    local f=self.prompt; local lines={}
    for _,item in ipairs(plan) do lines[#lines+1]=item.name.." x "..item.quantity.."  -  "..money(item.cost) end
    lines[#lines+1]="Total: "..money(total)
    f.items:SetText(table.concat(lines,"\n")); f.items:SetHeight(0)
    local bottom=66+f.items:GetStringHeight()+8
    f.auto:ClearAllPoints(); f.auto:SetPoint("TOPLEFT",16,-bottom)
    f:SetHeight(bottom+76); f:SetScale(math.min(1,(UIParent:GetHeight()-32)/f:GetHeight()))
    f:Show()
end
local events=CreateFrame("Frame"); V.events=events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        if name~=addonName then return end
        A.db.vendorServices=type(A.db.vendorServices)=="table" and A.db.vendorServices or {}
        V.settings=A.db.vendorServices
        if V.settings.autoBuy==nil then V.settings.autoBuy=false end
        if V.settings.autoRepair==nil then V.settings.autoRepair=false end
        for _,e in ipairs({"MERCHANT_SHOW","MERCHANT_CLOSED","MERCHANT_UPDATE","PLAYER_REGEN_DISABLED"}) do events:RegisterEvent(e) end
        events:UnregisterEvent("ADDON_LOADED")
    elseif event=="MERCHANT_SHOW" then
        V:Stop(); V.open=true; V.decided=nil; V.nextAt=GetTime()+0.2
        if V.prompt then V.prompt.auto:SetChecked(false); V.prompt.auto.mark:SetText("") end
        V:Repair()
    elseif event=="MERCHANT_CLOSED" or event=="PLAYER_REGEN_DISABLED" then V.open=false; V:Stop()
    elseif event=="MERCHANT_UPDATE" then V.nextAt=GetTime()+0.1 end
end)
events:SetScript("OnUpdate",function() if V.open then V:Tick() end end)
