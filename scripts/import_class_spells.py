"""Import licensed Vanilla trainer tables from a local What's Training? checkout.

Offline only. Requires lupa; no other addon is consulted at runtime.
"""
import argparse
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def encode(value):
    if hasattr(value, 'items'):
        pairs = sorted(value.items(), key=lambda pair: (isinstance(pair[0], str), pair[0]))
        return '{' + ','.join('[' + encode(k) + ']=' + encode(v) for k, v in pairs) + '}'
    if isinstance(value, str):
        return '"' + value.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    return str(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    lines = ["-- Vanilla trainer spell data derived from What's Training? 10.0.0 (Sveng).",
             '-- MIT license: docs/WHATS_TRAINING_LICENSE.txt; see docs/class-spells.md.',
             'local _,A=...', 'A.Data.ClassSpells={']
    count = 0
    for name in ('Druid', 'Hunter', 'Mage', 'Paladin', 'Priest', 'Rogue', 'Shaman', 'Warlock', 'Warrior'):
        lua = LuaRuntime()
        source = lua.eval('''function(class)
            return {currentClass=class, FactionFilter=function(t) return t end,
                RaceFilter=function(t) return t end, AddOverriddenSpells=function() end}
        end''')(name.upper())
        lua.execute((args.source / 'Classes' / 'Vanilla' / (name + '.lua')).read_text(), 'OfflineImport', source)
        if name == 'Hunter':
            lua.execute((args.source / 'Classes' / 'Vanilla' / 'HunterPets.lua').read_text(), 'OfflineImport', source)
        lines.append('    ["' + name + '"]={')
        for level, entries in sorted(source.SpellsByLevel.items()):
            assert 1 <= level <= 60
            lines.append('        [' + str(level) + ']={')
            for _, entry in sorted(entries.items()):
                assert entry.id > 0 and entry.cost >= 0
                # The source records Hemorrhage's prior ranks but omits its talent flag.
                if name == 'Rogue' and entry.id in (17347, 17348):
                    entry.requiredTalentId = 16511
                if name == 'Hunter' and source.PetAbilityIds[entry.id]:
                    entry.pet = True
                lines.append('            ' + encode(entry) + ',')
                count += 1
            lines.append('        },')
        lines.append('    },')
    lines.append('}')
    source = lua.table_from({'currentClass': 'WARLOCK'})
    lua.execute((args.source / 'Classes' / 'Vanilla' / 'WarlockTomes.lua').read_text(), 'OfflineImport', source)
    lines.append('A.Data.DemonGrimoires={')
    tomes = 0
    for level, entries in sorted(source.TomesByLevel.items()):
        unique = {}
        for _, entry in sorted(entries.items()):
            if entry.itemId not in unique:
                unique[entry.itemId] = lua.table_from({'itemId': entry.itemId,
                    'id': source.TomeTaughtSpells[entry.itemId], 'cost': entry.cost,
                    'family': entry.family})
            else:
                unique[entry.itemId].family += ' / ' + entry.family
        lines.append('    [' + str(level) + ']={')
        for item, entry in sorted(unique.items()):
            assert entry.id and entry.id > 0
            lines.append('        ' + encode(entry) + ',')
            tomes += 1
        lines.append('    },')
    lines.append('}')
    (ROOT / 'Data' / 'ClassSpells.lua').write_text('\n'.join(lines) + '\n', encoding='utf-8')
    (ROOT / 'docs' / 'WHATS_TRAINING_LICENSE.txt').write_bytes((args.source / 'LICENSE').read_bytes())
    print(f'Imported {count} trainer spells across 9 Vanilla classes and {tomes} demon grimoires.')


if __name__ == '__main__':
    main()
