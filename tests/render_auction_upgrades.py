"""Offline layout previews; native artwork and fonts are approximated."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT

lua, addon = boot()
for suite in ('gear_advisor.lua', 'auction_upgrades.lua'):
    lua.execute((ROOT / 'tests' / suite).read_text(encoding='utf-8'))
lua.execute('''
local U,F,G=TestAddon.AuctionUpgrades,GEAR_FIXTURES,TestAddon.GearAdvisor
F.reset("HUNTER",41,{31,1,0})
U.profile=G:CurrentProfile(); U.results={}; U.slot=nil; U.setup=nil; U.weaponsOnly=false; U.offset=0
U.complete=true; U.progress=1; U.message="Scan complete | 2217 auctions checked"
for _,slot in ipairs({1,2,3,5,6,7,8,9,10,11,12,13,14,15,18}) do U.checkedSlots[slot]=true end
local entries={
 {1,"INVTYPE_HEAD","Tracker's Headband of the Monkey",12.56,223499},
 {5,"INVTYPE_CHEST","Brigade Breastplate of the Monkey",8.42,145000},
 {6,"INVTYPE_WAIST","Bonelink Belt of the Wolf",3.66,20000},
 {7,"INVTYPE_LEGS","Bonelink Legplates of the Wolf",42.04,121812},
 {11,"INVTYPE_FINGER","Assault Band",29.54,349599},
 {11,"INVTYPE_FINGER","Marsh Ring of the Monkey",14.25,0},
 {12,"INVTYPE_FINGER","Assault Band",31.53,349599},
}
for _,v in ipairs(entries) do
 local it=F.item(v[2],{ITEM_MOD_AGILITY_SHORT=15},4,1); it.name=v[3]
 U:Add(G:Read(it.link),{{slot=v[1],status="up",percent=v[4],label="Ring"}},it.link,134400,v[5],22000,1)
end
local old=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=5},2,7,{{"(15.0 damage per second)"}})
old.name="Equipped sword"
local main=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=12},2,7,{{"(21.0 damage per second)"}})
main.name="Speedsteel Rapier"
local off=F.item("INVTYPE_WEAPON",{ITEM_MOD_AGILITY_SHORT=10},2,15,{{"(23.0 damage per second)"}})
off.name="Sacrificial Kris of the Monkey"
local two=F.item("INVTYPE_2HWEAPON",{ITEM_MOD_AGILITY_SHORT=25},2,8,{{"(39.0 damage per second)"}})
two.name="Executioner's Sword of the Monkey"
F.equip(16,old); F.equip(17,old)
local w=TestAddon.WeaponSetAdvisor.New(U.profile,{[16]=G:Read(old.link),[17]=G:Read(old.link)})
w:Add(G:Read(main.link),134400,550000,100,1)
w:Add(G:Read(off.link),134400,180000,100,1)
w:Add(G:Read(two.link),134400,425000,100,1)
local co=coroutine.create(function() return w:Build() end)
local result
repeat local ok,value=coroutine.resume(co); assert(ok,value); result=value until coroutine.status(co)=="dead"
U.results.twoHand=result.twoHand; U.results.paired=result.paired; U.weaponBaseline=w.baseline
GameTooltip:Hide(); U.panel:Show(); U:Refresh()
''')
output = ROOT / '.release/auction-redesign'
output.mkdir(parents=True, exist_ok=True)
for name, action in (
    ('overview', ''),
    ('slot', 'U:SelectSlot(11)'),
    ('weapons', 'U.slot=nil; U.weaponsOnly=true; U:Refresh()'),
    ('components', 'U.slot="paired"; U.setup=U.results.paired[1]; U:Refresh()'),
    ('empty', 'U.profile=nil; U.results={}; U.slot=nil; U.setup=nil; U.weaponsOnly=false; U.progress=0; U.complete=false; U.message=nil; U:Refresh()'),
):
    lua.execute('local U=TestAddon.AuctionUpgrades; ' + action)
    composite(lua.globals().MOCK.frames, addon.AuctionUpgrades.panel).save(output / (name + '.png'))
print(f'PASS: Auction layout simulations: {output}')
