"""Essentials filtering, matching AH bounds, native searches and tab isolation."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, ROOT

lua, addon = boot()
lua.execute((ROOT / 'tests/gear_advisor.lua').read_text())
lua.execute((ROOT / 'tests/auction_upgrades.lua').read_text())
lua.execute('''
local A=TestAddon; local E=A.AuctionEssentials; local U=A.AuctionUpgrades
local original=A.Supplies.Build
local function record(id,name,missing,extra)
    local item={itemId=id,name=name}; for k,v in pairs(extra or {}) do item[k]=v end
    return {itemId=id,name=name,item=item,count=20-missing,target=20,missing=missing,tracking=true}
end
A.Supplies.Build=function(_,state)
    assert(state.filter=="Essentials")
    return {record(117,"Vendor food",20),record(2512,"Vendor arrows",20),
        record(10513,"Crafted ammo",200),record(999901,"User item",0),
        record(999902,"Limited stock potion",4),record(999903,"Bound item",4,{binding=true})}
end
local rows=E:Items({})
assert(#rows==3 and rows[1].name=="Crafted ammo" and rows[3].name=="User item")
E:Attach(); E.open=true
AuctionFrameTab_OnClick(E.tab)
assert(E.panel:IsShown() and not U.panel:IsShown(),"Tabs are exclusive")
assert(E.panel:GetWidth()==U.panel:GetWidth() and E.panel:GetHeight()==U.panel:GetHeight(),"Same dimensions")
assert(E.rows[1].record.itemId==10513)
BrowseName=CreateFrame("EditBox"); BrowseMinLevel=CreateFrame("EditBox"); BrowseMaxLevel=CreateFrame("EditBox")
local calls=0
QueryAuctionItems=function(name,minimum,maximum,page,usable,quality,all,exact,filters)
    calls=calls+1
    assert(name=="Crafted ammo" and not minimum and not maximum and page==0 and not usable and exact and not filters)
end
CanSendAuctionQuery=function() return false end
E:Search(rows[1]); assert(calls==0 and E.panel:IsShown(),"Throttled searches stay in menu")
CanSendAuctionQuery=function() return true end
E:Search(rows[1]); assert(calls==1 and not E.panel:IsShown() and AuctionFrameBrowse:IsShown())
assert(BrowseName:GetText()=="Crafted ammo")
AuctionFrameTab_OnClick(E.tab); AuctionFrame:SetSize(900,500); U:Layout(); E:Refresh()
assert(E.panel:GetWidth()==U.panel:GetWidth() and E.panel:GetHeight()==U.panel:GetHeight())
AuctionFrameTab_OnClick(U.tab); assert(not E.panel:IsShown() and U.panel:IsShown())
E.open=false; E:Search(rows[1]); assert(calls==1,"Closed AH cannot query")
A.Supplies.Build=original
print("PASS: Essentials vendor filtering, tradeable items, sorting, tab isolation, geometry, throttling and exact native searches")
''')
