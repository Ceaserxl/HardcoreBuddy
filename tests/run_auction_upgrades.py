"""Native auction boundaries, standalone scoring, and continuous results UI."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text(encoding='utf-8'))
lua.execute((ROOT / 'tests/weapon_sets.lua').read_text(encoding='utf-8'))

# Round-trip the actual saved report in a fresh Lua 5.1 runtime without WoW APIs.
saved = lua.execute('''
local function serialize(value)
    if type(value)=="table" then
        local fields={}
        for k,v in pairs(value) do fields[#fields+1]="["..serialize(k).."]="..serialize(v) end
        return "{"..table.concat(fields,",").."}"
    elseif type(value)=="string" then return string.format("%q",value)
    elseif type(value)=="number" then assert(value==value and math.abs(value)<math.huge); return tostring(value)
    elseif type(value)=="boolean" then return tostring(value) end
    error("Unsupported saved diagnostic value: "..type(value))
end
return "return "..serialize({diagnostics=TestAddon.characterDB.auctionDiagnostics,scan=TestAddon.characterDB.auctionLastScan})
''')
from lupa.lua51 import LuaRuntime
offline = LuaRuntime(unpack_returned_tuples=True)
offline.globals().SavedAuctionData = offline.execute(saved)
offline.execute('OfflineAddon={characterDB={auctionDiagnostics=SavedAuctionData.diagnostics,auctionLastScan=SavedAuctionData.scan}}')
offline.execute((ROOT / 'AuctionDiagnostics.lua').read_text(encoding='utf-8'), 'HardcoreBuddy', offline.globals().OfflineAddon)
restored = offline.globals().OfflineAddon.AuctionDiagnostics
assert restored.Text(restored) == addon.AuctionDiagnostics.Text(addon.AuctionDiagnostics)
print('PASS: Saved auction diagnostics reloaded without live item, auction or tooltip APIs.')
offline.execute('OfflineAddon.GearAdvisor={CurrentProfile=function() return nil end}')
offline.execute((ROOT / 'AuctionCache.lua').read_text(encoding='utf-8'), 'HardcoreBuddy', offline.globals().OfflineAddon)
offline.execute('''
local U={}
assert(OfflineAddon.AuctionCache:Restore(U))
assert(U.cached and U.stale and not U.complete)
assert(U.results[1][1].link==SavedAuctionData.scan.results[1][1].link)
assert(U.results[1][1].listing.query.page==SavedAuctionData.scan.results[1][1].listing.query.page)
assert(U.results[1][1].listing.owner=='Seller')
assert(U.results.twoHand[1].components[1].link==SavedAuctionData.scan.results.twoHand[1].components[1].link)
assert(U.results.twoHand[1].components[1].listing.query.filters[1].classID==2)
assert(U.savedScanAt==SavedAuctionData.scan.recordedAt)
U.results[1][1].buyout=999999999
assert(SavedAuctionData.scan.results[1][1].buyout~=999999999)
''')
print('PASS: Saved scan and weapon setups round-trip through a fresh Lua runtime; unknown equipment stays stale.')

lua.execute('''
local A,F=TestAddon,GEAR_FIXTURES
local U,G=A.AuctionUpgrades,A.GearAdvisor
F.reset("MAGE",40,{0,0,31}); A.db.gearAdvisorActive=true; A.db.gearAdvisorEnabled=true
local candidate=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_INTELLECT_SHORT=11},2,10)
local item={link=candidate.link,weaponSet=true,percent=36.26,buyout=100000,bid=0,priceLabel="Buyout",count=1,
 components={{label="Main hand",name="Staff fixture"}}}
U.slot=nil; local row=U.rows[1]; row.entry={best=item}; U.panel:Show()
GameTooltip:HookScript("OnTooltipSetItem",function(tip) tip:AddLine("Other addon section",1,1,1) end)
row:GetScript("OnEnter")(row)
local function locate(text)
 for i=1,GameTooltip:NumLines() do
  local line=_G[GameTooltip:GetName().."TextLeft"..i]:GetText()
  if line and line:find(text,1,true) then return i end
 end
end
local header,summary,total,foreign=locate("HardcoreBuddy"),locate("Complete setup vs equipped"),locate("Total:"),locate("Other addon section")
assert(header and summary and total and foreign and foreign<header and header<summary and summary<total,
 "Advisor, setup and total stay together after native tooltip construction")
local count=GameTooltip:NumLines(); item.buyout=120000; G:Add(GameTooltip)
assert(GameTooltip:NumLines()==count and locate("Other addon section")==foreign,"Refresh preserves other addon lines")
assert(_G[GameTooltip:GetName().."TextLeft"..total]:GetText():find("12g",1,true),"Auction total updates in the same block")
local other=CreateFrame("Frame"); GameTooltip:SetOwner(other,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(candidate.link)
assert(not locate("Complete setup vs equipped"),"Auction summary cannot leak into another owner's tooltip")
print("PASS: Auction and Gear Advisor tooltip grouping, refresh and owner isolation.")
''')
