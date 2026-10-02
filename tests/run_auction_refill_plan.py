"""Whole-stack optimum versus exhaustive enumeration, including overbuy and outliers."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot
lua, addon = boot()
lua.execute('''
local E=TestAddon.AuctionEssentials
local function offer(n,c) return {count=n,buyout=c} end
local p=E:RefillPlan({offer(20,100),offer(6,40)},6)
assert(p.cost==40 and p.units==6,"Minimum unit price is not minimum refill cost")
p=E:RefillPlan({offer(6,100),offer(10,60)},6)
assert(p.cost==60 and p.units==10,"Overbuy when cheaper than exact")
p=E:RefillPlan({offer(4,20),offer(5,24),offer(10,55)},9)
assert(p.cost==44 and p.units==9,"Mixed stacks minimize total cost")
p=E:RefillPlan({offer(10,100),offer(1,10000),offer(12,150)},11)
assert(p.cost==150 and p.units==12 and p.excluded==1,"Reject extreme singleton and buy cheaper oversized stack")
p=E:RefillPlan({offer(10,100),offer(1,10000)},11)
assert(p.cost==100 and p.units==10,"Leave shortfall instead of buying outlier")
p=E:RefillPlan({offer(1,10000)},1,50)
assert(p.units==0,"Original batch ceiling cannot rise after cheap auctions disappear")
p=E:RefillPlan({offer(5,50),offer(6,50)},5)
assert(p.units==5,"Equal costs prefer exact quantity")
math.randomseed(34)
for trial=1,400 do
    local offers={}; local floorPrice=math.huge
    for i=1,9 do
        local o=offer(math.random(1,12),math.random(1,90)); offers[i]=o
        floorPrice=math.min(floorPrice,o.buyout/o.count)
    end
    local need=math.random(1,35)
    local best
    for mask=0,511 do
        local q,c,valid=0,0,true
        for i,o in ipairs(offers) do
            if math.floor(mask/2^(i-1))%2==1 then
                if o.buyout/o.count>floorPrice*5 then valid=false end
                q=q+o.count; c=c+o.buyout
            end
        end
        if valid then
            local coverage=math.min(q,need)
            if not best or coverage>best.coverage or coverage==best.coverage and
                (c<best.cost or c==best.cost and q<best.units) then best={coverage=coverage,cost=c,units=q} end
        end
    end
    local actual=E:RefillPlan(offers,need)
    assert(actual.cost==best.cost and actual.units==best.units,"Matches exhaustive stack selection")
end
local offers={}
for i=1,80 do offers[i]=offer(i,100+i) end
local co=coroutine.create(function() return E:RefillPlan(offers,1000,nil,true) end)
local ticks=0
while coroutine.status(co)~="dead" do local ok=coroutine.resume(co); assert(ok); ticks=ticks+1 end
assert(ticks>1,"Large refill planning yields between frames")
print("PASS: 400 exhaustive comparisons, exact/overbuy/tie/outlier/shortfall cases and cooperative planning")
''')
