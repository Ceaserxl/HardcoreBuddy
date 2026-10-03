"""Focused audit reproductions and representative offline UI previews."""
import argparse
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, composite, ROOT
from audit_addon_matrix import convert


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".release/audit-edges")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    lua, addon = boot()
    result = lua.execute(r'''
local A=TestAddon
local result={}
local ctx={mode='preview',characterClass='Mage',level=60,faction='Alliance',inventory={available=true,counts={}},
    professions={available=true,skills={bandage=300,dummy=300,cooking=300},known={}},supplyDefaults={},priorities={}}
local items={}
for _,item in ipairs(A.Data.Items.items) do items[item.itemId]=item end
result.catalog={items=#A.Data.Items.items,scrolls=#A.Data.Scrolls.items,enchants=#A.Data.Enchants.recipes,
  armorKits=#A.Data.ArmorKits.items,missing={},elixirs={}}
for _,id in ipairs({13452,13454,21546,13445,3386,9030,6048,6049,6050,6051,6052,13457,13456,13458,13459,13461,13928,19300,21023}) do
 result.catalog.missing[#result.catalog.missing+1]={id=id,inSupplies=items[id]~=nil,
    crafting=A.Data.Crafting.items[id]~=nil,auctionRecipe=A.Data.AuctionRecipes[id]~=nil,
    buffIdentity=A.Data.ConsumableBuffs.items[id]~=nil}
end
for _,item in ipairs(A.Data.Items.items) do
 if A.Supplies.Category(item)=='Elixirs' then result.catalog.elixirs[#result.catalog.elixirs+1]=item.name end
end
-- Every editable weight should affect the same stat in enchant and gear scores.
local p=A.GearAdvisor.Profile('MAGE',60,nil,3)
p.weights.armor=0; p.weights.fireResistance=100
local gear={id=1,required=1,classID=4,subclassID=1,equip='INVTYPE_CLOAK',stats={RESISTANCE2_NAME=10}}
local old={id=3,required=1,classID=4,subclassID=1,equip='INVTYPE_CLOAK',stats={RESISTANCE2_NAME=20}}
result.resistance={gear=A.GearAdvisor.Score(gear,p,15),enchant=A.Enchants.Score({effect='Fire Resistance +10'},p),
    losses=A.GearAdvisor.LossSummary(gear,p,{old},true,false) or false,
    gains=A.GearAdvisor.GainSummary(old,p,{gear},true,false) or false}
-- Scroll alternatives have no default control even when the saved default is set.
local scroll
for _,candidate in ipairs(A.Data.Scrolls.items) do if candidate.itemId==955 then scroll=candidate end end
ctx.supplyDefaults[scroll.family]=scroll.itemId
local page=A.Companion.Detail(ctx,{kind='item',item=scroll})
local root
for _,record in ipairs(A.Supplies.Build(ctx,{filter='Scrolls'})) do if record.family==scroll.family then root=record.name end end
result.scrollDefault={selected=scroll.name,defaultControl=page.defaultItem~=nil,root=root,heading=page.itemSectionTitle}
-- Custom item duplicates are allowed by the editor, then silently lose their
-- classification on All/Essentials because built-in records win by item ID.
local item=items[5997]
local user={}; for k,v in pairs(item) do user[k]=v end
user.userItem=true; user.group='User'; user.family='user-'..user.itemId
ctx.level=1; ctx.userItems={user}; ctx.priorities[user.family]='Essentials'
result.customDuplicate={userRows=#A.Supplies.Build(ctx,{filter='User'}),all={},essentials={}}
for _,filter in ipairs({'All','Essentials'}) do
 for _,r in ipairs(A.Supplies.Build(ctx,{filter=filter})) do if r.itemId==user.itemId then
  result.customDuplicate[filter:lower()]={category=r.category,priority=r.priority,family=r.family}
 end end
end
-- Empty-slot evaluation versus unsupported restrictions for cached alts.
local axe={id=2,required=1,classID=2,subclassID=1,equip='INVTYPE_2HWEAPON',stats={},dps=10}
result.shamanTwoHand={}
for _,level in ipairs({1,10,19,20,60}) do
 local profile=A.GearAdvisor.Profile('SHAMAN',level,nil,1)
 result.shamanTwoHand[#result.shamanTwoHand+1]={level=level,allowed=A.GearAdvisor.Allowed(axe,profile)}
end
-- A relative-only price guard cannot identify an overpriced one-listing market.
local plan=A.AuctionEssentials:RefillPlan({{buyout=100000000,count=1}},1)
result.singleExpensiveAuction={cost=plan.cost,units=plan.units,excluded=plan.excluded,ceiling=plan.ceiling}
-- Fallback effects and data paths absent from the same recipe material system.
result.crafting={}
for _,item in ipairs(A.Data.Items.items) do
 local info=A.Crafting.GetInfo(item,ctx)
 if info.craftable then
  local blocks,note=A.Crafting.MaterialBlocks(item,ctx)
  if #blocks==0 then result.crafting[#result.crafting+1]={name=item.name,id=item.itemId,note=note,kind=info.craftKind} end
 end
end
-- Exhaust every learned/unlearned subset for profession families and every
-- skill 0..300; the independent oracle is the maximum learned eligible recipe.
result.professionOracle={cases=0,failures=0}
for family,recipes in pairs(A.Professions.recipes) do
 for mask=0,2^#recipes-1 do
  for skill=0,300 do
   local snap={skills={bandage=skill,dummy=skill},known={}}
   local expected
   for i,r in ipairs(recipes) do
    local learned=math.floor(mask/2^(i-1))%2==1
    snap.known[r.spellId]=learned
    if learned and skill>=r.craftSkill and skill>0 then expected=r.itemId end
   end
   local actual=A.Professions.Best(snap,family)
   result.professionOracle.cases=result.professionOracle.cases+1
   if actual.itemId~=expected then result.professionOracle.failures=result.professionOracle.failures+1 end
  end
 end
end
-- The same row has two layout builders; capture their actual rendering flags.
ctx.characterClass='Hunter'; ctx.level=32; ctx.maxHealth=700; ctx.professions.skills.bandage=80
local direct=A.Companion.Detail(ctx,{kind='item',item=items[8544]})
local family=A.Companion.Build(ctx,{view='supplies',detail={kind='supplyFamily',family='bandage'}}).cards[1]
result.bandageLayouts={direct={},family={}}
for name,page in pairs({direct=direct,family=family}) do
 for _,b in ipairs(page.blocks) do if b.itemId and b.rightColumn then
  result.bandageLayouts[name][#result.bandageLayouts[name]+1]={id=b.itemId,supply=b.supply or false,
      status=b.status or '',body=b.body or ''}
 end end
end
result.unmakeableBandage=family.blocks[1].body
-- Preference edits must invalidate the separately rendered Missing Essentials
-- panel; a main-window refresh alone does not redraw that panel.
local refreshes,invalidations=0,0
local oldRefresh,oldChanged=A.Readiness.Refresh,A.Readiness.SuppliesChanged
A.Readiness.Refresh=function() refreshes=refreshes+1 end
A.Readiness.SuppliesChanged=function() invalidations=invalidations+1 end
local added=A:EditUserItem('999998',false)
local removed=A:EditUserItem('999998',true)
A.Readiness.Refresh,A.Readiness.SuppliesChanged=oldRefresh,oldChanged
result.userItemInvalidation={added=added,removed=removed,refreshes=refreshes,invalidations=invalidations}
return result
''')
    report = convert(result)
    # Source-driven named pages, avoiding generated data edits.
    pages = {
        "supplies-all": 'A:Navigate("supplies")',
        "elixirs": 'A:Navigate("supplies"); A.state.filter="Elixirs"; A:Refresh(true)',
        "scroll-detail": 'A:Navigate("supplies"); A:Activate({kind="item",item=A.Data.Scrolls.items[1]})',
        "bandages": 'A:Navigate("supplies"); A:Activate({kind="supplyFamily",family="bandage"})',
        "spells": 'A:Navigate("training"); A.state.filter="Spells"; A:Refresh(true)',
        "talents": 'A:HandleSlashCommand("talents")',
        "gear": 'A:HandleSlashCommand("gear")',
        "instances": 'A:Navigate("instances")',
        "journal": 'A:OpenDeaths()',
    }
    for _, section in addon.Settings.sections.items():
        pages["settings-" + section.lower().replace(" ", "-")] = 'A:OpenSettings(' + json.dumps(section) + ')'
    report["pages"] = []
    for name, command in pages.items():
        lua.execute("local A=TestAddon; " + command)
        composite(lua.globals().MOCK.frames, addon.window).save(args.output / (name + ".png"))
        report["pages"].append(name)
    lua.execute('''
local A=TestAddon
A.GetContext=function() return {mode='live',characterClass='Hunter',level=32,faction='Alliance',maxHealth=700,
  inventory={available=true,counts={}},professions={available=true,skills={bandage=80,dummy=0},known={}}} end
A:Navigate('supplies'); A:Activate({kind='supplyFamily',family='bandage'})
''')
    composite(lua.globals().MOCK.frames, addon.window).save(args.output / "unmakeable-bandage.png")
    report["pages"].append("unmakeable-bandage")
    # Inventory the exact controls lacking hover, to distinguish a stale blanket
    # style test from a genuinely inconsistent clickable widget.
    hover, a = boot()
    hover.execute((ROOT / "tests/map_advisor.lua").read_text(encoding="utf-8"))
    missing = hover.execute(r'''
local A=TestAddon
for _,section in ipairs(A.Settings.sections) do A:OpenSettings(section) end
local result={}
for _,b in ipairs(MOCK.frames) do
 local block=b.block or b.parent and b.parent.block
 if (b.kind=='Button' or b.kind=='CheckButton') and b.scripts.OnClick
   and (not block or block.action) and not b.skinButton and not b.highlight then
  local function path(f)
   local out={}; local depth=0
   while f and depth<5 do
    out[#out+1]=f.name or f.label and f.label:GetText() or f.caption and f.caption:GetText() or f.kind
    f=f.parent; depth=depth+1
   end
   return table.concat(out,' / ')
  end
  result[#result+1]={path=path(b),template=b.template,shown=b:IsVisible(),width=b:GetWidth(),height=b:GetHeight()}
 end
end
return result
''')
    report["missingHoverCandidates"] = convert(missing)
    report["npcLevelSentinels"] = convert(hover.execute(r'''
local A=TestAddon
local result={}
for id,npc in pairs(A.Data.MapNPCs) do
 if npc.min and npc.min>100 or npc.max and npc.max>100 then
  local probe={cluster={records={{id=id,npc=npc}}}}
  A.MapAdvisor:Tooltip(probe)
  local tooltip={}; for i,line in ipairs(GameTooltip.lines) do tooltip[i]=line end
  local mapID=next(npc.locations)
  local tableLevel=false
  if mapID then
   local doc=A.MapAdvisor:Document(A:GetContext(),{mapZone=mapID})
   for _,b in ipairs(doc.cards[1].blocks) do
    if b.action and b.action.id==id then tableLevel=b.npcColumns[1] end
   end
  end
  result[#result+1]={id=id,name=npc.name,min=npc.min,max=npc.max,
    tooltip=tooltip,tableLevel=tableLevel}
 end
end
table.sort(result,function(a,b) return a.id<b.id end)
return result
'''))
    (args.output / "edges.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if report['professionOracle']['failures']:
        raise SystemExit('Profession oracle disagreements; inspect edges.json')


if __name__ == "__main__":
    main()
