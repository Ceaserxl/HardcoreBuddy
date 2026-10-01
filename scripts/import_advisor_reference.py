"""Import Classic stat tables and Hardcore talent paths from a local reference.

Developer-only: python scripts/import_advisor_reference.py PATH_TO_ZYGOR
Requires lupa. The shipped addon never loads or depends on Zygor.
Talent geometry is the small, pinned Classic reference in reference/advisor.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]


def lua(value):
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '{' + ','.join(map(lua, value)) + '}'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if value is None:
        return 'nil'
    return str(value)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    runtime = LuaRuntime(unpack_returned_tuples=True)
    runtime.execute('ZGV={ItemScore={},ZTA={},IsClassicHardcore=true}; ZygorGuidesViewer=ZGV; builds={}\n'
                    'function ZGV.ZTA:RegisterBuild(c,n,s,b,g,o) builds[#builds+1]={class=c,name=n,profile=s,text=b} end')
    inputs = ['Data-Classic/Item-Statweights.lua', 'Guides-Classic/TalentAdvisor-Builds.lua']
    hashes = {}
    for name in inputs:
        content = (args.source / name).read_text(encoding='utf-8-sig')
        hashes[name] = hashlib.sha256(content.encode()).hexdigest()
        runtime.execute(content)
    weights = {}
    # Exclude Season of Discovery healer/tank profiles, retain Era feral tank,
    # melee Hunter and Fury/Protection choices.
    for cls, profiles in sorted(runtime.globals().ZGV.ItemScore.rules.items()):
        weights[cls] = []
        for index, profile in sorted(profiles.items()):
            if index == 4 and cls in ('MAGE', 'ROGUE', 'WARLOCK'):
                continue
            stats = {str(k).upper(): v for k, v in sorted(profile.stats.items())}
            if 'HOLYSPELLDAMAGE' in stats:
                stats['SPELL_DAMAGE_DONE_HOLY'] = stats.pop('HOLYSPELLDAMAGE')
            weights[cls].append(dict(id=index, name=profile.name, stats=stats))
    talents = json.loads((ROOT / 'reference/advisor/talents.json').read_text())
    paths = {}
    for _, build in runtime.globals().builds.items():
        cls = build['class']
        lookup = {t['name'].lower(): key for key, t in talents[cls].items()}
        steps = []
        for line in build.text.splitlines():
            match = re.match(r'\s*(\d+)\s+(.+?)\s*(?:--.*)?$', line)
            if match:
                name = match[2].strip().lower()
                # Reference spelling: Classic's talent is Improved Hunter's Mark.
                key = lookup.get(name)
                if not key:
                    raise ValueError((cls, build.name, name))
                steps.extend([key] * int(match[1]))
        bracket = re.search(r'Leveling (\d+)-(\d+)', build.name)
        minimum, maximum = (max(10, int(bracket[1])), int(bracket[2])) if bracket else (10, 60)
        title = re.sub(r'\s*\[Hardcore\]', '', build.name).strip()
        entry = dict(id=len(paths.setdefault(cls, [])) + 1, name=title, profile=build.profile,
                     minLevel=minimum, maxLevel=maximum, steps=steps)
        paths[cls].append(entry)
    corrections = []
    for cls, builds in paths.items():
        for build in builds:
            counts, tree_points = {}, {1: 0, 2: 0, 3: 0}
            pending, ordered = list(build['steps']), []
            while pending:
                def legal(key):
                    t = talents[cls][key]
                    pre = t.get('prerequisite')
                    return (counts.get(key, 0) < t['maxRank'] and
                            tree_points[t['tree']] >= (t['tier'] - 1) * 5 and
                            (not pre or counts.get(pre, 0) == talents[cls][pre]['maxRank']))
                index = next((i for i, key in enumerate(pending) if legal(key)), None)
                assert index is not None, (cls, build['name'], 'No legal next step', pending)
                if index:
                    corrections.append(dict(className=cls, build=build['name'], point=len(ordered)+1,
                                            delayed=pending[0], selected=pending[index]))
                key = pending.pop(index)
                ordered.append(key)
                counts[key] = counts.get(key, 0) + 1
                tree_points[talents[cls][key]['tree']] += 1
            build['steps'] = ordered
            counts, tree_points = {}, {1: 0, 2: 0, 3: 0}
            for pos, key in enumerate(ordered, 1):
                t = talents[cls][key]
                count = counts.get(key, 0)
                assert count < t['maxRank'], (cls, build['name'], pos, 'rank', key)
                assert tree_points[t['tree']] >= (t['tier'] - 1) * 5, (cls, build['name'], pos, 'tier', key)
                if t.get('prerequisite'):
                    pre = talents[cls][t['prerequisite']]
                    assert counts.get(t['prerequisite'], 0) == pre['maxRank'], (cls, build['name'], pos, 'prerequisite', key)
                counts[key] = count + 1
                tree_points[t['tree']] += 1
            assert len(build['steps']) == build['maxLevel'] - 9, (cls, build['name'], len(build['steps']))
    heading = '-- Classic reference data; see docs/advisors.md for provenance and deliberate differences.\nlocal _,A=...\n'
    (ROOT / 'Data/AdvisorGear.lua').write_text(heading + 'A.Data.AdvisorGear=' + lua(weights) + '\n', encoding='utf-8')
    (ROOT / 'Data/AdvisorTalents.lua').write_text(heading + 'A.Data.AdvisorTalents=' + lua(talents) + '\nA.Data.AdvisorBuilds=' + lua(paths) + '\n', encoding='utf-8')
    (ROOT / 'reference/advisor/source.json').write_text(json.dumps(dict(inputs=hashes, classes=9,
        profiles=sum(map(len, weights.values())), builds=sum(map(len, paths.values())), corrections=corrections), indent=2) + '\n')
    print('Imported', sum(map(len, weights.values())), 'gear profiles and', sum(map(len, paths.values())), 'validated talent paths.')


if __name__ == '__main__':
    main()
