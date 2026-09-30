"""Check release classification and reject accidental prerelease tags."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from prepare_ci_release import release_name

assert release_name('0.2.0', 'tag', 'v0.2.0') == 'HardcoreBuddy-v0.2.0'
assert release_name('0.3.0', 'tag', 'v0.3.0') == 'HardcoreBuddy-v0.3.0'
assert release_name('0.99.99', 'tag', 'v0.99.99') == 'HardcoreBuddy-v0.99.99'
assert release_name('1.0.0', 'tag', 'v1.0.0') == 'HardcoreBuddy-v1.0.0'
assert release_name('2.0.0', 'tag', 'v2.0.0') == 'HardcoreBuddy-v2.0.0'
assert release_name('0.1.0-beta.1', 'branch', 'main') == 'HardcoreBuddy-build'
for version, tag in [('0.2.0', 'v0.2.0-beta'), ('0.2.0', 'v0.3.0'),
                     ('0.2.0', 'v00.2.0'), ('0.2.0', 'bad-tag')]:
    try:
        release_name(version, 'tag', tag)
    except ValueError:
        pass
    else:
        raise AssertionError(f'Accepted invalid release: {tag}')
print('PASS: Numeric release labels, build naming and tag validation.')
