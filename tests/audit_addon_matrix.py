"""Independent audit observations, not golden-output regression assertions.

Writes JSON evidence for review. An observation is not automatically a defect:
future browsing, profession guidance and deliberate UI exceptions need triage.
"""
import argparse
import json
from pathlib import Path
import random
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_layout import boot, font, plain, ROOT, wrapped


def convert(value):
    if hasattr(value, "items"):
        keys = list(value.keys())
        if keys and all(isinstance(key, (int, float)) for key in keys):
            return [convert(value[i]) for i in sorted(keys)]
        return {key: convert(child) for key, child in value.items()}
    return value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".release/audit-matrix")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    lua, addon = boot()
    result = lua.execute(r'''
local A=TestAddon
local out={counts={},observations={}}
local function count(key,n) out.counts[key]=(out.counts[key] or 0)+(n or 1) end
local function note(key,value)
    local group=out.observations[key] or {count=0,samples={}}; out.observations[key]=group
    group.count=group.count+1
    if #group.samples<12 then group.samples[#group.samples+1]=value end
end
local allItems,ids={},{}
for _,catalog in ipairs({A.Data.Items.items,A.Data.Scrolls.items,A.Data.ArmorKits.items}) do
    for _,item in ipairs(catalog) do
        count('catalogRows'); allItems[#allItems+1]=item
        if ids[item.itemId] then note('duplicateCatalogID',{id=item.itemId,name=item.name,other=ids[item.itemId].name}) end
        ids[item.itemId]=item
        if not item.icon or item.icon=='' then note('missingCatalogIcon',{id=item.itemId,name=item.name}) end
        local info=A.Crafting.GetInfo(item,{characterClass='Mage',level=60})
        local blocks=A.Crafting.MaterialBlocks(item,{characterClass='Mage',level=60})
        if info.craftable and #blocks==0 then note('craftableWithoutMaterials',{id=item.itemId,name=item.name}) end
    end
end
for _,class in ipairs(A.Planner.classes) do
 for _,faction in ipairs({'Alliance','Horde'}) do
  for level=1,60 do
   for _,skill in ipairs({0,300}) do
    count('supplyContexts')
    local prof={available=true,skills={bandage=skill,dummy=skill,cooking=skill},baseSkills={},known={}}
    for _,recipes in pairs(A.Professions.recipes) do for _,r in ipairs(recipes) do prof.known[r.spellId]=skill>=r.craftSkill end end
    local ctx={mode='preview',characterClass=class,level=level,faction=faction,professions=prof,
        maxHealth=level*55,inventory={available=true,counts={}},targets={},supplyDefaults={}}
    local seen={}
    for _,record in ipairs(A.Supplies.Build(ctx,{})) do
      count('supplyRecords')
      local item=record.item
      local sample={class=class,faction=faction,level=level,skill=skill,id=item.itemId,name=item.name}
      if seen[item.itemId] then note('duplicateRootItem',sample) end; seen[item.itemId]=true
      if item.classes and not A.Planner.MatchesClass(item,class) then note('wrongClassRoot',sample) end
      if item.level and item.level>level then note('aboveUseLevelRoot',sample) end
      if (class=='Rogue' or class=='Warrior') and item.family=='drink' then note('noManaDrinkRoot',sample) end
      if item.family and not item.armorKit and not item.enchantMaterial then
        local page=A.Companion.Detail(ctx,{kind='item',item=item})
        count('supplyDetailPages')
        if not page.blocks[1] or page.blocks[1].itemId~=item.itemId then note('selectedItemMismatch',sample) end
        local section,seenRows,nextID=nil,{},nil
        for _,b in ipairs(page.blocks) do
          if b.plain and not b.itemId and (b.title=='Next' or b.title=='Alternatives') then section=b.title end
          if b.rightColumn and b.itemId then
            if section=='Next' then nextID=b.itemId end
            if seenRows[b.itemId] then
              note('duplicateRightColumnItem',{class=class,level=level,id=item.itemId,name=item.name,duplicate=b.itemId})
            end
            seenRows[b.itemId]=true
          end
        end
        local nextItem=A.Guide.NextSupply(item,ctx)
        if nextItem then
          local a,b=A.Data.ConsumableBuffs.items[item.itemId],A.Data.ConsumableBuffs.items[nextItem.itemId]
          if a and b and a.group==b.group and b.power<a.power then
            note('nextLowerBuffPower',{class=class,level=level,id=item.itemId,name=item.name,next=nextItem.name,power=a.power,nextPower=b.power})
          end
        end
        if item.family=='bandage' and A.Supplies.Selection(ctx,'bandage')==item.itemId and skill<(item.useSkill and item.useSkill.value or 0) then
          note('recommendedBandageUnusable',sample)
        end
      end
    end
   end
  end
 end
end
-- Changing a scoring weight should be visible to ranking/recommendation systems.
local original=A.Enchants.Profile
local weightSets={{stamina=100,spirit=100,mp5=0},{stamina=0,spirit=0,mp5=100}}
out.buffFoodProfiles={}
for _,weights in ipairs(weightSets) do
 A.Enchants.Profile=function() return {weights=weights} end
 local ctx={mode='preview',characterClass='Mage',level=40,faction='Alliance'}
 local foods={}
 for _,r in ipairs(A.Planner.BuildList('Mage',40,'Alliance').rows) do
  if r.family=='wellfed' or r.family=='manafood' then foods[#foods+1]=r end
 end
 A.Guide.SortSupplyItems(foods,ctx)
 local row={weights=weights,foods={}}
 for _,item in ipairs(foods) do row.foods[#row.foods+1]={name=item.name,priority=A.Supplies.Priority(ctx,item)} end
 out.buffFoodProfiles[#out.buffFoodProfiles+1]=row
end
A.Enchants.Profile=original
-- Unknown enchant IDs must remain inspectable without a catalog recipe.
local oldScan=A.Enchants.Scan
A.Enchants.Scan=function() return {{slotId=8,name='Feet',kind='Boots',status='enchanted',enchantId=99999,itemId=1,
  itemLevel=60,equipLoc='INVTYPE_FEET',profile=A.Enchants.Profile({characterClass='Mage',level=60})}} end
local ok,err=pcall(A.Enchants.Card,{characterClass='Mage',level=60})
out.unknownEnchantCard={ok=ok,error=not ok and tostring(err) or nil}
A.Enchants.Scan=oldScan
-- Scope / item compatibility and missing-stat handling have their own tests.
return out
''')
    report = convert(result)
    (args.output / "matrix-models.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Model matrix complete; checking refill arithmetic and text fit.", flush=True)
    # Independent brute-force oracle: all bounded subsets, then minimize actual
    # copper and overshoot. Exclude the same explicitly documented price ceiling.
    rng = random.Random(20261002)
    planner = addon.AuctionEssentials.RefillPlan
    failures = []
    for case in range(1200):
        offers = [{"buyout": rng.randint(1, 250), "count": rng.randint(1, 20), "index": i}
                  for i in range(rng.randint(1, 9))]
        need = rng.randint(0, 45)
        ceiling = min(x["buyout"] / x["count"] for x in offers) * 5
        valid = [o for o in offers if o["buyout"] / o["count"] <= ceiling]
        subsets = []
        for mask in range(1 << len(valid)):
            chosen = [o for i, o in enumerate(valid) if mask & (1 << i)]
            subsets.append((sum(o["count"] for o in chosen), sum(o["buyout"] for o in chosen)))
        covered = [x for x in subsets if x[0] >= need]
        expected = min(covered, key=lambda x: (x[1], x[0])) if covered else min(subsets, key=lambda x: (-x[0], x[1]))
        actual = planner(addon.AuctionEssentials, lua.table_from([lua.table_from(o) for o in offers]), need)
        if (actual.units, actual.cost) != expected:
            failures.append({"case": case, "need": need, "offers": offers,
                             "expected": expected, "actual": [actual.units, actual.cost]})
    report["refillOracle"] = {"cases": 1200, "failures": failures}

    # Approximate font-fit evidence supplements fixed-height tests. Measure
    # actual render tree regions. It does not emulate Blizzard font truncation.
    samples, unique = [], set()
    for catalog in (addon.Data.Items["items"], addon.Data.Scrolls["items"]):
        for _, item in catalog.items():
            addon.state = lua.table_from({"view": "supplies", "filter": "All",
                "detail": lua.table_from({"kind": "item", "item": item})})
            addon.Refresh(addon, True)
            for _, card in addon.window.cards.items():
                if not card.IsShown(card):
                    continue
                for _, row in card.content.blocks.items():
                    if not row.IsShown(row) or not row.block:
                        continue
                    b = row.block
                    if not (b.supplyDetail or b.supply or b.enchantRow or b.compactRow) or b.supplyColumns:
                        continue
                    for key in ("title", "body"):
                        region = row[key]
                        if not region or not region.IsShown(region):
                            continue
                        text = region.GetText(region)
                        if not text:
                            continue
                        path, size, _ = region.GetFont(region)
                        _, _, width, height = region.GetRect(region)
                        lines = wrapped(text, width, size, path, region.wordWrap is not False)
                        too_wide = max(font(size, path).getlength(plain(line)) for line in lines) > width + 1
                        # Two 12px lines fit the allotted 28px at a 14px line pitch.
                        too_tall = len(lines) * (size + 2) > height + 1
                        ident = (str(text), key, round(width), round(height))
                        if (too_wide or too_tall) and ident not in unique:
                            unique.add(ident)
                            samples.append({"item": item.name, "row": b.title, "region": key,
                                            "text": text, "width": width, "height": height,
                                            "fontSize": size, "estimatedLines": len(lines),
                                            "tooWide": too_wide, "tooTall": too_tall})
    report["approximateTextFit"] = {"uniqueRegions": len(samples), "samples": samples}
    (args.output / "matrix.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key not in ("approximateTextFit",)}, indent=2))
    print(f"Font-fit candidates: {len(samples)}; report: {args.output / 'matrix.json'}")
    if failures:
        raise SystemExit('Refill oracle disagreements; inspect matrix.json')


if __name__ == "__main__":
    main()
