"""Exploratory policy audit. --strict fails on reported gaps; never edits runtime."""
from pathlib import Path
import argparse
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
from render_layout import boot

parser = argparse.ArgumentParser()
parser.add_argument("--strict", action="store_true")
parser.add_argument("--output", type=Path)
args = parser.parse_args()
lua, addon = boot()
lua.globals().ScenarioFixture = lua.execute((ROOT / "tests/rotation_scenario_fixture.lua").read_text(encoding="utf-8"))
audit = lua.execute((ROOT / "tests/rotation_scenario_audit.lua").read_text(encoding="utf-8"))

def rows(table):
    return [dict(table[i].items()) for i in range(1, len(table) + 1)]

report = {key: audit[key] for key in ("namedCount", "matrixCount", "matrixViolations", "cooldownMainCount")}
report["cases"] = rows(audit.cases)
report["findings"] = rows(audit.findings)
report["passed"] = report["namedCount"] - len(report["findings"])
print(f"AUDIT: {report['passed']}/{report['namedCount']} named expectations met; {report['matrixCount']} matrix combinations; {report['matrixViolations']} invariant violations")
for finding in report["findings"]:
    print(f"GAP [{finding.get('priority', 'review')}]: {finding['name']}\n  Expected: {finding['expected']}\n  Actual: {finding['actual']}")
if args.output:
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
if report["matrixViolations"] or args.strict and report["findings"]:
    sys.exit(1)
