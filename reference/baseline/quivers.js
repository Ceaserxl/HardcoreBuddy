export const quiverTiers = [
  {level:1,ids:[5439,5441],route:'Ammo / general-goods vendors'},
  {level:10,ids:[11362,11363],route:'Ammo / general-goods vendors · storage upgrade; same firing speed'},
  {level:30,ids:[7371,7372],route:'Leatherworker or Auction House · self-found: craft with Leatherworking'},
  {level:40,ids:[8217,8218],route:'Leatherworker or Auction House · self-found: craft with Leatherworking'},
];
export function quiverPlan(level) {
  return {current:quiverTiers.filter(tier=>tier.level<=level).at(-1),next:quiverTiers.find(tier=>tier.level>level)||null};
}
