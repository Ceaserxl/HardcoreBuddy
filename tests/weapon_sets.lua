local A,F=TestAddon,GEAR_FIXTURES
local W,G=A.WeaponSetAdvisor,A.GearAdvisor
local checks=0
local function check(ok,why) checks=checks+1; assert(ok,why) end
local function read(item) return G:Read(item.link) end
local function gear(equip,amount,class,subclass)
    return F.item(equip,{ITEM_MOD_INTELLECT_SHORT=amount},class or 2,subclass or 10,{{"(10.0 damage per second)"}})
end
local function build(w)
    local worker=coroutine.create(function() return w:Build() end)
    local resumes=0
    while true do
        local ok,result=coroutine.resume(worker); check(ok,tostring(result)); resumes=resumes+1
        if coroutine.status(worker)=="dead" then return result,resumes end
        assert(resumes<10000,"Weapon comparison stalled")
    end
end
local function top(list)
    table.sort(list,function(a,b) return a.score>b.score end)
    return list[1]
end
local function auction(w,item,buyout,bid)
    check(w:Add(read(item),123,buyout or 100,bid or 10,1),"Candidate loaded")
end
F.reset("MAGE",40,{0,0,31})
local profile=G:CurrentProfile()
local staff=gear("INVTYPE_2HWEAPON",20)
local sword=gear("INVTYPE_WEAPON",14,2,7)
local frill=gear("INVTYPE_HOLDABLE",10,4,0)
local nextStaff=gear("INVTYPE_2HWEAPON",22)
F.equip(16,staff)
local w=W.New(profile,{[16]=read(staff)})
auction(w,sword); auction(w,frill); auction(w,nextStaff)
local result=build(w); local pair=top(result.paired); local two=top(result.twoHand)
check(pair and #pair.components==2,"Caster sword and off hand form a complete setup while wearing a staff")
check(pair.score>two.score and pair.percent>two.percent,"Combined 1H/off-hand beats the individually better two-hander")
check(pair.percent==math.floor((pair.score*100/w.baseline-100)*100)/100,"Both styles use the same total equipped baseline and rounding")
check(G:Comparisons(read(sword),profile)[1].percent<0,"Single sword is a downgrade, but its full setup is retained")
check(pair.buyout==200,"Pair price includes both purchases")
check(#result.twoHand==2,"Current two-hander remains available beside upgrades")

local shield=gear("INVTYPE_SHIELD",500,4,6)
local invalid=gear("INVTYPE_WEAPONOFFHAND",500,2,7)
auction(w,shield); auction(w,invalid)
result=build(w)
check(top(result.paired).score==pair.score,"Mage cannot pair a shield or off-hand weapon")

F.equip(16,sword); F.equip(17,frill)
local w2=W.New(profile,{[16]=read(sword),[17]=read(frill)})
local upgradeSword=gear("INVTYPE_WEAPON",16,2,7)
local upgradeFrill=gear("INVTYPE_HOLDABLE",12,4,0)
auction(w2,upgradeSword); auction(w2,upgradeFrill)
local setups=build(w2).paired
local keptMain,keptOff,both,current=false,false,false,false
for _,row in ipairs(setups) do
    if #row.components==2 then
        local m,o=row.components[1],row.components[2]
        keptMain=keptMain or (m.owned and not o.owned)
        keptOff=keptOff or (not m.owned and o.owned)
        both=both or (not m.owned and not o.owned)
        current=current or (m.owned and o.owned and row.percent==0)
    end
end
check(keptMain and keptOff and both and current,"Can upgrade either hand, both hands, or keep current gear")

F.reset("HUNTER",40,{31,0,0}); profile=G:CurrentProfile()
local blade=gear("INVTYPE_WEAPON",20,2,7)
local dw=W.New(profile,{})
auction(dw,blade,100)
local one=build(dw)
check(not top(one.paired).components[2],"One auction listing cannot supply two copies")
auction(dw,blade,350)
local duplicate=top(build(dw).paired)
check(#duplicate.components==2 and duplicate.buyout==450,"Two actual listings allow dual wield, charging their distinct prices")
local ownedPlusBuy=W.New(profile,{[16]=read(blade)})
auction(ownedPlusBuy,blade,70)
local ownedPair=top(build(ownedPlusBuy).paired)
check(#ownedPair.components==2 and ownedPair.buyout==70,"Equipped copy plus one auction copy is a legal pair")
local unique=gear("INVTYPE_WEAPON",40,2,7); unique.lines[#unique.lines+1]={"Unique"}
local uniq=W.New(profile,{})
auction(uniq,unique); auction(uniq,unique)
check(not top(build(uniq).paired).components[2],"Unique items cannot be paired with another copy")
local known=IsSpellKnown; IsSpellKnown=function() return false end
local untrained=W.New(profile,{})
auction(untrained,blade); auction(untrained,blade)
check(not top(build(untrained).paired).components[2],"Dual wield requires the learned ability")
IsSpellKnown=known
F.reset("HUNTER",19,{10,0,0})
local low=W.New(G:CurrentProfile(),{})
auction(low,blade); auction(low,blade)
check(not top(build(low).paired).components[2],"Dual-wield level requirement enforced")

F.reset("WARRIOR",40,{31,0,0}); profile=G:CurrentProfile()
local tank=W.New(profile,{})
local mainOnly=gear("INVTYPE_WEAPONMAINHAND",20,2,7)
auction(tank,mainOnly); auction(tank,shield)
local tankSet=top(build(tank).paired)
check(tankSet.components[2].item.equip=="INVTYPE_SHIELD","One hand plus shield supported")
local pairOnly=W.New(profile,{})
auction(pairOnly,mainOnly); auction(pairOnly,mainOnly)
check(not top(build(pairOnly).paired).components[2],"Main-hand-only weapons cannot fill off hand")

F.reset("MAGE",40,{0,0,31}); profile=G:CurrentProfile()
local many=W.New(profile,{[16]=read(staff)})
for i=1,90 do auction(many,gear("INVTYPE_WEAPON",i,2,7)); auction(many,gear("INVTYPE_HOLDABLE",i,4,0)) end
local big,resumes=build(many)
check(resumes>1 and #big.paired<=180,"Large searches yield between frames and keep a linear-sized list of best partners")
local none=W.New(profile,{})
auction(none,frill)
check(#build(none).paired==0,"An off hand alone never masquerades as a complete replacement setup")
local zeroStaff=gear("INVTYPE_2HWEAPON",0)
zeroStaff.lines={{"(0.0 damage per second)"}}
local zero=W.New(profile,{[16]=read(zeroStaff)})
auction(zero,sword); auction(zero,frill)
local noPercent=top(build(zero).paired)
check(noPercent.percent==nil and not noPercent.emptyBaseline,"Zero-score equipped baseline does not invent a percentage")
print("PASS: "..checks.." weapon setup assertions")
