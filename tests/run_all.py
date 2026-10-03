"""Required offline validation: python tests/run_all.py [--workers 4].

Research-coordinate provenance is optional when the ignored HTML cache is absent.
No publishing, live-client access, or changes to SavedVariables are performed.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workers', type=int, default=4)
    args = parser.parse_args()
    jobs = [(p.stem, [str(p.relative_to(ROOT))]) for p in sorted((ROOT / 'tests').glob('run*.py'))
            if p.name not in ('run_all.py', 'run_release.py')]
    jobs.append(('release_workflow', ['tests/release_workflow.py']))
    for suite in ('cooldown', 'hundred', 'two_hundred', 'clarity', 'handoff', 'prediction', 'buffs'):
        jobs.append(('rotation_' + suite, ['tests/run_rotation_scenarios.py', '--strict', '--suite', suite]))
    env = dict(os.environ, PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1')

    def run(job):
        name, command = job
        try:
            result = subprocess.run([sys.executable, *command], cwd=ROOT, env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, encoding='utf-8', errors='replace', timeout=600)
            return name, result.returncode, result.stdout
        except subprocess.TimeoutExpired:
            return name, 124, 'Timed out after 600 seconds'

    failed = []
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for future in as_completed([pool.submit(run, job) for job in jobs]):
            name, code, output = future.result()
            print(('FAIL ' if code else 'PASS ') + name, flush=True)
            if code or 'SKIP:' in output:
                print(output, flush=True)
            if code:
                failed.append(name)
    print(f'{len(jobs) - len(failed)}/{len(jobs)} suites passed; failed: {", ".join(sorted(failed)) or "none"}')
    return bool(failed)


if __name__ == '__main__':
    raise SystemExit(main())
