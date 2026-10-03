"""Build a self-contained release ZIP from an explicit shipping manifest."""
import argparse
import hashlib
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def manifest():
    toc = (ROOT / 'HardcoreBuddy.toc').read_text()
    version = re.search(r'^## Version: (.+)$', toc, re.M).group(1).strip()
    assert re.fullmatch(r'[0-9A-Za-z.-]+', version)
    assert f'addon.version = "{version}"' in (ROOT / 'Core.lua').read_text()
    files = {'HardcoreBuddy.toc', 'README.md', 'RELEASE_NOTES.md'}
    for line in toc.splitlines():
        if line.strip() and not line.startswith('#'):
            files.add(line.strip().replace('\\', '/'))
    files.update({
        'Media/JourneyBanner.tga', 'Media/SurvivorShield.tga',
        'Media/Deaths/icon.tga', 'Media/Deaths/AlertBannerIron.tga',
        'Media/Deaths/AlertRoundedMask.tga',
        'Media/CreatureSounds/AUDIO.md', 'Media/Health/ATTRIBUTION.md',
        'Media/Deaths/Deathlog/README.md', 'Media/Deaths/Deathlog/LICENSE.txt',
        'Media/Deaths/Deathlog/sources.json',
        'scripts/import_deathlog_sounds.py',
        'Media/Deaths/Original/README.md', 'Media/Deaths/Original/RaidWarning.ogg',
        'scripts/import_raid_warning_sound.py',
        'docs/PROVENANCE.md', 'docs/advisors.md', 'docs/ADVISOR_DATA_LICENSE.txt',
        'docs/map-data.md', 'docs/map-data-audit.json', 'docs/leveling-zones.md',
        'docs/vendor-services.md', 'docs/rotation-helper.md', 'docs/consumable-buffs.md',
        'docs/enchants.md', 'docs/supply-catalog.md',
        'docs/class-spells.md', 'docs/WHATS_TRAINING_LICENSE.txt',
    })
    for volume in range(10, 101, 10):
        files.add(f'Media/Deaths/Original/RaidWarning{volume}.ogg')
        files.add(f'Media/Deaths/DeathBell{volume}.wav')
        files.add(f'Media/Health/AirHorn{volume}.wav')
        for kind in ('NeutralRareVoiceV1', 'HostileRareVoiceV1', 'EliteSirenV2'):
            files.add(f'Media/CreatureSounds/{kind}{volume}.wav')
        for kind in ('HeroFallen', 'Arugal', 'Dread_Hunger', 'hunger_games', 'golfclap'):
            files.add(f'Media/Deaths/Deathlog/{kind}{volume}.ogg')
            # Include the original licensed clips and rebuild script alongside derivatives.
            files.add(f'Media/Deaths/Deathlog/{kind}.ogg')
    for name in files:
        path = (ROOT / name).resolve()
        assert path.is_relative_to(ROOT) and path.is_file(), f'Missing file: {name}'
    return version, sorted(files)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path.home() / 'Downloads' / 'HardcoreBuddy-Releases')
    args = parser.parse_args()
    version, files = manifest()
    args.output.mkdir(parents=True, exist_ok=True)
    target = args.output / f'HardcoreBuddy-{version}.zip'
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in files:
            archive.write(ROOT / name, f'HardcoreBuddy/{name}')
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        assert set(archive.namelist()) == {f'HardcoreBuddy/{name}' for name in files}
        for name in files:
            assert archive.read(f'HardcoreBuddy/{name}') == (ROOT / name).read_bytes()
    digest = hashlib.sha256(target.read_bytes()).hexdigest()
    target.with_suffix('.zip.sha256').write_text(f'{digest}  {target.name}\n')
    print(f'PASS: {len(files)} files; TOC paths, version, ZIP CRC and byte-for-byte contents verified.')
    print(f'{target} ({target.stat().st_size / 1024 / 1024:.2f} MiB)')


if __name__ == '__main__':
    main()
