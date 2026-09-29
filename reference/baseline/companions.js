// Pet-level eligibility and source tame-level eligibility are separate.
export function trainingLevel(rank, routineOnly = true) {
  if (rank.trainer) return Math.max(10, rank.petLevel);
  const sources = rank.sources.filter(source => !routineOnly || source.routine);
  return sources.length ? Math.max(10, rank.petLevel, Math.min(...sources.map(source => source.minLevel))) : null;
}
export function hunterAbility(ability, level) {
  const current = level < 10 ? null : ability.ranks.filter(rank => {
    const unlock = trainingLevel(rank);
    return unlock !== null && unlock <= level;
  }).at(-1) || null;
  const next = ability.ranks.find(rank => {
    const unlock = trainingLevel(rank);
    return unlock !== null && unlock > level && (!current || rank.rank > current.rank);
  }) || null;
  const restricted = ability.ranks.filter(rank => !rank.trainer && !rank.sources.some(source => source.routine));
  return {...ability, current, next, restricted, sources:current?.sources.filter(source => source.routine && source.minLevel <= level) || []};
}
export function hunterPetCategories(data, level) {
  const sources = [...data.starters, ...data.abilities.flatMap(ability=>ability.ranks.flatMap(rank=>rank.sources))];
  const definitions = [
    {name:'Offensive',role:'Offense',pick:'Cat / Owl',text:'Cat for single-target damage; owl for Screech utility. Keep Growl supplied with focus.',names:[level>=32?'Stranglethorn Tiger':'Durotar Tiger',level>=48?'Ironbeak Owl':'Strigid Hunter']},
    {name:'General',role:'General',pick:level>=16?'Carrion bird / Wolf':'Wolf',text:level>=16?'Carrion bird for balanced stats and Screech; wolf is another balanced option.':'A wolf is a common early balanced choice. Carrion birds become a practical Screech option at 16.',names:[level>=32?'Salt Flats Vulture':level>=16?'Greater Fleshripper':'Prairie Wolf']},
    {name:'Defensive',role:'Defense',pick:'Boar / Bear',text:'Boar for Charge and flexible feeding; bear for extra health and a broad diet. Lower damage can mean slower kills.',names:['Elder Mottled Boar','Scarred Crag Boar']},
  ];
  return definitions.map(category=>({...category,
    families:data.families.filter(family=>family.role===category.role),
    pets:level<10?[]:category.names.map(name=>sources.find(source=>source.name===name&&source.routine&&source.minLevel<=level)).filter(Boolean),
  }));
}
export function hunterPlan(data, level) {
  const abilities = Object.fromEntries(data.abilities.map(ability => [ability.id,hunterAbility(ability,level)]));
  const names = level < 16 ? ['Strigid Hunter','Durotar Tiger','Flatland Cougar','Moonstalker Runt']
    : level < 32 ? ['Greater Fleshripper'] : level < 48 ? ['Salt Flats Vulture'] : ['Ironbeak Owl'];
  return {unlocked:level >= 10,abilities,categories:hunterPetCategories(data,level), pets:data.starters.filter(pet=>names.includes(pet.name)&&pet.minLevel<=level)};
}
export const demonSources = {
  guide:'https://www.wowhead.com/classic/guide/wow-classic-warlock-demon-pets',
  leveling:'https://www.wowhead.com/classic/guide/classes/warlock/leveling-tips',
  hardcore:'https://www.wowhead.com/classic/guide/classes/warlock/hardcore-leveling-tips',
  spellLock:'https://www.wowhead.com/classic/item=16388',
  sacrifice:'https://www.wowhead.com/classic/item=16351',
};
const rankAt = (levels, level) => levels.filter(minimum => minimum <= level).length;
export function warlockPlan(level) {
  return {
    primary:level < 10 ? 'Imp' : 'Voidwalker',
    reason:level < 10 ? 'Early questing damage. Complete your starting Imp quest; the summon needs no Soul Shard.'
      : 'Cautious solo leveling: let Torment establish threat before applying heavy damage. Your damage can still pull aggro.',
    next:level < 10 ? 'Level 10 · Voidwalker class quest' : level < 20 ? 'Level 20 · Succubus / Incubus class quest'
      : level < 30 ? 'Level 30 · Felhunter class quest' : level < 36 ? 'Level 36 · Spell Lock grimoire' : null,
    alternatives:[
      ...(level >= 20 ? [{name:'Succubus / Incubus',role:'Faster single-target leveling',text:'Higher damage for an Affliction / drain-tanking playstyle where you can take the hits. Keep Voidwalker for harder pulls and its shield.'}] : []),
      ...(level >= 30 ? [{name:'Felhunter',role:level >= 36 ? 'Caster control / magic dispel' : 'Magic dispel',text:level >= 36 ? 'Use Devour Magic for dispellable magic and manually interrupt dangerous casts with trained Spell Lock.' : 'Devour Magic is available; Spell Lock does not unlock until level 36.'}] : []),
      ...(level >= 10 ? [{name:'Imp',role:'Group stamina / ranged damage',text:'Use Blood Pact when your group benefits. Keep it passive when only the buff is needed; manage its position and attacks.'}] : []),
    ],
    skills:[
      {name:'Firebolt',demon:'Imp',rank:rankAt([1,8,18,28,38,48,58],level)},
      {name:'Blood Pact',demon:'Imp',rank:rankAt([4,14,26,38,50],level)},
      {name:'Torment',demon:'Voidwalker',rank:rankAt([10,20,30,40,50,60],level)},
      {name:'Sacrifice',demon:'Voidwalker',rank:rankAt([16,24,32,40,48,56],level)},
    ].filter(skill=>skill.rank>0),
    sacrifice:level>=16,
    seduction:level>=26,
    spellLock:level>=36,
  };
}
