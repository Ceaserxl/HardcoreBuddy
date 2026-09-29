// Execute the preserved website model, never the Lua port, to generate fixtures.
import {readFileSync, writeFileSync} from 'node:fs';
import {CLASSES, EASE, CLASS_NOTES, buildList} from '../reference/baseline/planner.js';
import {hunterPlan, warlockPlan, demonSources} from '../reference/baseline/companions.js';
import {quiverPlan, quiverTiers} from '../reference/baseline/quivers.js';
const read = name => JSON.parse(readFileSync(new URL('../reference/'+name,import.meta.url),'utf8'));
const items=read('recommendations.json').items, companions=read('companions.json');
const rows = list => list.map(item=>item.id);
const fixture={carry:[],hunter:[],warlock:[],quivers:[]};
for(const characterClass of CLASSES) for(let level=1;level<=60;level++) {
  const list=buildList(items,characterClass,level);
  fixture.carry.push({characterClass,level,rows:list.rows.map(row=>({id:row.id,displayName:row.displayName,short:row.short,
    options:rows(row.options),progression:rows(row.progression),next:row.next?.id||null})),
    specialist:rows(list.specialist),backups:rows(list.backups),advanced:rows(list.advanced)});
}
for(let level=1;level<=60;level++) {
  fixture.hunter.push(hunterPlan(companions,level));
  fixture.warlock.push(warlockPlan(level));
  fixture.quivers.push(quiverPlan(level));
}
writeFileSync(new URL('../tests/website-fixtures.json',import.meta.url), JSON.stringify(fixture)+'\n');
// Locale collation is not built into Lua; preserve the baseline's exact ordering.
const names=[...new Set(items.map(i=>i.name))].sort((a,b)=>a.localeCompare(b));
writeFileSync(new URL('../reference/presentation.json',import.meta.url),JSON.stringify({classes:CLASSES,ease:EASE,
  classNotes:CLASS_NOTES,nameOrder:names,quiverTiers,demonSources,warlockPlans:fixture.warlock},null,2)+'\n');
console.log('Generated website fixtures: 540 carry profiles; 60 Hunter, Warlock and quiver plans.');
