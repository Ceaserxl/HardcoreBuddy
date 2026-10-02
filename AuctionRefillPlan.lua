-- Minimum total copper for a bounded set of whole auction stacks.
-- Cap quantity states at the target; retain actual quantity for overbuy tie-breaks.
local _,A=...
local E=A.AuctionEssentials
function E:RefillPlan(offers,need,ceiling,yieldWork)
    need=math.max(0,math.ceil(need or 0))
    local floorPrice
    for _,offer in ipairs(offers) do
        local price=offer.buyout/offer.count
        floorPrice=math.min(floorPrice or price,price)
    end
    -- Conservative listing-relative guard. Carry the original ceiling through
    -- a purchase batch so disappearing cheap stacks cannot raise its budget.
    ceiling=math.min(ceiling or math.huge,(floorPrice or 0)*5)
    local states,work={[0]={cost=0,units=0}},0
    local excluded=0
    for _,offer in ipairs(offers) do
        if offer.buyout/offer.count>ceiling then excluded=excluded+1
        elseif need>0 then
            local keys={}
            for q in pairs(states) do if q<need then keys[#keys+1]=q end end
            table.sort(keys,function(a,b) return a>b end)
            for _,q in ipairs(keys) do
                local old=states[q]
                local units,cost=old.units+offer.count,old.cost+offer.buyout
                local target=math.min(need,units)
                local best=states[target]
                if not best or cost<best.cost or cost==best.cost and units<best.units then
                    states[target]={cost=cost,units=units,previous=old,offer=offer}
                end
                work=work+1
                if yieldWork and work%512==0 then coroutine.yield() end
            end
        end
    end
    local best=states[need]
    if not best then
        local highest=0
        for q in pairs(states) do if q>highest then highest=q end end
        best=states[highest]
    end
    local plan={cost=best.cost,units=best.units,need=need,offers={},ceiling=ceiling,excluded=excluded}
    while best.offer do table.insert(plan.offers,1,best.offer); best=best.previous end
    table.sort(plan.offers,function(a,b)
        if a.buyout*b.count~=b.buyout*a.count then return a.buyout*b.count<b.buyout*a.count end
        return a.buyout<b.buyout
    end)
    return plan
end
