"""Offline Essentials table previews; native artwork and fonts are approximations."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
lua, addon = boot()
for name in ('gear_advisor.lua', 'auction_upgrades.lua', 'auction_essentials_fixture.lua'):
    lua.execute((ROOT / 'tests' / name).read_text(encoding='utf-8'))
lua.execute(r'''
local A,E,F=TestAddon,TestAddon.AuctionEssentials,ESSENTIAL_FIXTURE
F.stock={
 [10513]={name='Mithril Gyro-Shot',target=3200,count=200},
 [4596]={name='Discolored Healing Potion',target=5,count=1},
 [6451]={name='Heavy Silk Bandage',target=20,count=4},
 [3387]={name='Limited Invulnerability Potion',target=5,count=0},
 [5631]={name='Rage Potion',target=5,count=0},
}
C_SpellBook={IsSpellKnown=function(id) return id==7929 end}
A.Data.AuctionRecipes[6451]={spellId=7929,output=1,reagents={{4306,2,'Silk Cloth'}}}
C_Item.GetItemInfo=function() return 'Silk Cloth' end
F.bags={[4306]=7}
F.auctions={
 [10513]={[0]={{count=3000,price=45678}}},
 [4596]={[0]={{count=4,price=2049}}},
 [6451]={[0]={{count=20,price=12980}}},
 [3387]={[0]={{count=5,price=87500}}},
 [5631]={[0]={{count=5,price=3197}}},
 [4306]={name='Silk Cloth',[0]={{count=25,price=23895}}},
}
AuctionFrame:SetSize(780,480); A.AuctionUpgrades:Layout()
E:Start(); F.finish(); GameTooltip:Hide(); E.panel:Show(); E:Refresh()
''')
output = ROOT / '.release/essentials-row-buy'
output.mkdir(parents=True, exist_ok=True)
for name, action in (
    ('buy', ''),
    ('craft', 'E:SetPreferCraft(true); ESSENTIAL_FIXTURE.finish(); E.message=nil; E:Refresh()'),
    ('compact-craft', 'AuctionFrame:SetSize(750,420); E:Refresh()'),
):
    lua.execute('local E=TestAddon.AuctionEssentials; ' + action)
    composite(lua.globals().MOCK.frames, addon.AuctionEssentials.panel).save(output / (name + '.png'))
print(f'PASS: Essentials layout simulations: {output}')
