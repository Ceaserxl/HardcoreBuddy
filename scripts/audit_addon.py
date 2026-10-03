"""Run the offline audit in an isolated copy; never publish or touch live saved data.

Usage: python scripts/audit_addon.py --output .release/full-audit
Requires the same Python/Lupa/Pillow environment as tests/render_layout.py.
The snapshot contains current tracked working files, not just committed versions.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".release/full-audit")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    output = args.output.resolve()
    snapshot = output / "snapshot"
    if snapshot.exists():
        parser.error("Use a new output directory; an existing snapshot is never overwritten.")
    output.mkdir(parents=True, exist_ok=True)
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    for name in filter(None, files):
        if name.endswith(".pyc") or "__pycache__" in name:
            continue
        source = ROOT / name
        if source.is_file():
            dest = snapshot / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, dest)
    (snapshot / ".release/audit").mkdir(parents=True, exist_ok=True)
    logs = output / "logs"
    logs.mkdir(exist_ok=True)
    env = dict(os.environ, PYTHONUTF8="1", PYTHONDONTWRITEBYTECODE="1")
    report = {
        "sourceCommit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
        "workingTree": subprocess.check_output(["git", "status", "--short"], cwd=ROOT).decode(),
        "python": sys.version,
        "scope": "Offline Lua 5.1 mocks; no live WoW or external services",
        "results": [],
    }

    def run(label, command):
        start = time.monotonic()
        try:
            result = subprocess.run([sys.executable, *command], cwd=snapshot, env=env,
                                    text=True, encoding="utf-8", errors="replace",
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600)
            code, text = result.returncode, result.stdout
        except subprocess.TimeoutExpired as exc:
            code = 124
            text = str(exc.stdout or "") + "\nAUDIT TIMEOUT: 600 seconds"
        (logs / (label + ".txt")).write_text(text, encoding="utf-8")
        record = {"name": label, "command": command, "exitCode": code,
                  "seconds": round(time.monotonic() - start, 3), "output": text}
        print(f"{'PASS' if code == 0 else 'FAIL'} {label} ({record['seconds']}s)", flush=True)
        return record

    jobs = [(path.stem, [str(path.relative_to(snapshot))])
            for path in sorted((snapshot / "tests").glob("run*.py"))
            if path.name != "run_release.py"]
    jobs.append(("release_workflow", ["tests/release_workflow.py"]))
    for suite in ("cooldown", "hundred", "two_hundred", "clarity", "handoff", "prediction", "buffs"):
        jobs.append(("rotation_" + suite, ["tests/run_rotation_scenarios.py", "--strict", "--suite", suite]))
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = [pool.submit(run, name, command) for name, command in jobs]
        for future in as_completed(futures):
            report["results"].append(future.result())
    report["results"].append(run("package_release", ["scripts/package_release.py", "--output", ".release/audit/package"]))
    for archive in (snapshot / ".release/audit/package").glob("*.zip"):
        report["results"].append(run("run_release", ["tests/run_release.py", str(archive)]))
    report["results"].sort(key=lambda item: item["name"])
    report["passed"] = sum(item["exitCode"] == 0 for item in report["results"])
    report["failed"] = len(report["results"]) - report["passed"]
    (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"TOTAL: {report['passed']} passed, {report['failed']} failed. {output / 'results.json'}", flush=True)
    raise SystemExit(1 if report['failed'] else 0)


if __name__ == "__main__":
    main()
