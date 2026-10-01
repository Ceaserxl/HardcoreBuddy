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
assert(U.results.twoHand[1].components[1].link==SavedAuctionData.scan.results.twoHand[1].components[1].link)
assert(U.savedScanAt==SavedAuctionData.scan.recordedAt)
U.results[1][1].buyout=999999999
assert(SavedAuctionData.scan.results[1][1].buyout~=999999999)
''')
print('PASS: Saved scan and weapon setups round-trip through a fresh Lua runtime; unknown equipment stays stale.')
