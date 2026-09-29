"""Stage only shipping files and choose display names, without publishing."""
import os
import re
import shutil
from pathlib import Path

from package_release import ROOT, manifest


def release_name(version, ref_type, ref_name):
    if ref_type != 'tag':
        return 'HardcoreBuddy-build'
    match = re.fullmatch(r'v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', ref_name)
    if not match:
        raise ValueError('Release tags must be numeric, such as v0.2.0 or v1.0.0.')
    if ref_name[1:] != version:
        raise ValueError('Tag must match the versions in HardcoreBuddy.toc and Core.lua.')
    suffix = '-Beta' if match[1] == '0' else ''
    return f'HardcoreBuddy-{ref_name}{suffix}'


def main():
    version, files = manifest()
    name = release_name(version, os.environ.get('GITHUB_REF_TYPE', ''),
                        os.environ.get('GITHUB_REF_NAME', ''))
    stage = ROOT / '.release' / 'HardcoreBuddy'
    # Refuse a stale staging directory rather than silently shipping old assets.
    stage.mkdir(parents=True, exist_ok=False)
    for relative in files:
        target = stage / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / relative, target)
    output = os.environ.get('GITHUB_OUTPUT')
    if output:
        with Path(output).open('a', encoding='utf-8') as stream:
            stream.write(f'name={name}\n')
    print(f'Staged {len(files)} shipping files: {name}')


if __name__ == '__main__':
    main()
