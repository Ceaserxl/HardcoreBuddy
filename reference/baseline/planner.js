export const CLASSES = ['Druid', 'Hunter', 'Mage', 'Paladin', 'Priest', 'Rogue', 'Shaman', 'Warlock', 'Warrior'];
export const EASE = ['Vendor', 'Simple craft', 'Recipe / travel', 'Farm / limited', 'Special access'];
export const CLASS_NOTES = {
  Druid: 'Stamina food is the safe all-round choice. Feral builds can use Agility or Strength food; Balance and Restoration can favor mana regeneration. Keep water for healing between pulls.',
  Hunter: 'Stamina food is dependable while leveling; mana food reduces downtime and Grilled Squid supports damage later. Carry separate food your pet accepts—pet diet and level matter, and pet feeding does not grant food stat buffs.',
  Mage: 'Conjure your own food and water when the trained rank is sufficient; the vendor tiers below are dependable alternatives. Stamina food adds a buffer, while mana food helps longer sessions.',
  Paladin: 'Stamina food suits general leveling and tanking. Use mana food for healing or mana-heavy play, and Strength food for Retribution. Hardcore disables Divine Shield plus Hearthstone escape.',
  Priest: 'Stamina food adds a health buffer; Sagefish and Nightfin are useful mana alternatives. Bandages can conserve mana even when you can heal yourself.',
  Rogue: 'Stamina food supports safe leveling; Grilled Squid is a seasonal damage alternative. Keep Thistle Tea and the reagents for your trained escape abilities.',
  Shaman: 'Stamina food is a useful baseline. Enhancement can use Strength food; Elemental and Restoration often value mana regeneration. Match your elixir stat to your build.',
  Warlock: 'Stamina food supports a larger health buffer; mana food can reduce downtime. Create your Healthstone before leaving safety. The listed stone follows your creation-spell level.',
  Warrior: 'Stamina food gives a dependable safety buffer. Strength food helps melee damage later; Grilled Squid is another damage alternative. Bandages and escape tools are especially valuable without self-healing.',
};
export const matchesClass = (item, characterClass) => item.classes.includes('All') || item.classes.includes(characterClass);
export const availableAt = item => item.recommendLevel ?? item.level;
export const byEase = (a, b) => a.ease - b.ease || a.name.localeCompare(b.name);
const byStrength = (a, b) => (b.power ?? b.level) - (a.power ?? a.level) || a.ease - b.ease || (a.preference ?? 0) - (b.preference ?? 0) || byEase(a, b);
const groupedFamilies = new Set(['bandage', 'dummy', 'antivenom']);
export function buildList(items, characterClass, level) {
  const eligible = items.filter(item => matchesClass(item, characterClass) && availableAt(item) <= level);
  const families = [...new Set(eligible.filter(item => !item.alternative).map(item => item.family))];
  const rows = families.map(family => {
    const options = eligible.filter(item => item.family === family).sort(byEase);
    let candidates = options.filter(item => !item.alternative);
    if (family === 'wellfed' || family === 'manafood') candidates = candidates.filter(item => item.ease <= 2);
    const item = groupedFamilies.has(family) ? [...candidates].sort((a, b) => a.power - b.power)[0] : [...candidates].sort(byStrength)[0];
    const progression = items.filter(other => other.family === family && matchesClass(other, characterClass)).sort((a, b) => availableAt(a) - availableAt(b) || (a.power ?? 0) - (b.power ?? 0));
    return { ...item, displayName: family === 'bandage' ? 'Bandages' : family === 'dummy' ? 'Target dummies' : family === 'antivenom' ? 'Anti-venom' : item.name,
      short: family === 'bandage' ? 'Strongest rank your First Aid allows' : family === 'dummy' ? 'Choose one rank for your Engineering' : family === 'antivenom' ? 'Match the poison level, not your level' : item.short,
      options: options.filter(other => other.id !== item.id && (!['recovery','drink','wellfed'].includes(family) || other.level >= item.level || other.power >= item.power)),
      progression,
      next: progression.find(other => availableAt(other) > level),
    };
  }).sort(byEase);
  const specialist = eligible.filter(item => item.alternative && item.family.startsWith('specialfood-')).sort(byEase);
  const backups = eligible.filter(item => item.group === 'Route-specific backups').sort(byEase);
  const advanced = eligible.filter(item => item.alternative && item.group === 'Emergency supplies').sort(byEase);
  return { rows, specialist, backups, advanced };
}
export const PROFILE_COOKIE = 'cxl-hcclassic-v3';
const defaults = () => ({ characterClass: 'Hunter', level: 1, detailed: false });
const cookieValue = header => header.split(';').map(part => part.trim()).find(part => part.startsWith(`${PROFILE_COOKIE}=`))?.slice(PROFILE_COOKIE.length + 1);
export function readProfile(cookieHeader = '', legacyStorage = null) {
  try {
    const saved = cookieValue(cookieHeader);
    const parsed = JSON.parse(saved !== undefined ? decodeURIComponent(saved) :
      legacyStorage?.getItem('cxl-hcclassic-v2') || legacyStorage?.getItem('cxl-hcclassic-v1') || 'null');
    if (!parsed) return defaults();
    return { characterClass: CLASSES.includes(parsed.characterClass) ? parsed.characterClass : 'Hunter',
      level: Number.isInteger(parsed.level) && parsed.level >= 1 && parsed.level <= 60 ? parsed.level : 1,
      detailed: parsed.detailed === true };
  } catch { return defaults(); }
}
export function saveProfile(document, profile, secure = false) {
  try {
    const value = encodeURIComponent(JSON.stringify(profile));
    document.cookie = `${PROFILE_COOKIE}=${value}; Max-Age=31536000; Path=/hcclassic; SameSite=Lax${secure ? '; Secure' : ''}`;
    return cookieValue(document.cookie) === value;
  } catch { return false; }
}
