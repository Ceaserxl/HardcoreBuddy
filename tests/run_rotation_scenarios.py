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
parser.add_argument("--suite", choices=("audit", "cooldown", "hundred"), default="audit")
parser.add_argument("--output", type=Path)
args = parser.parse_args()
lua, addon = boot()
lua.globals().ScenarioFixture = lua.execute((ROOT / "tests/rotation_scenario_fixture.lua").read_text(encoding="utf-8"))
def rows(table):
    return [dict(table[i].items()) for i in range(1, len(table) + 1)]

case_files = {
    "audit": ("rotation_scenario_audit.lua",),
    "cooldown": ("rotation_cooldown_scenarios.lua",),
    "hundred": ("rotation_cooldown_scenarios.lua", "rotation_extended_scenarios.lua"),
}[args.suite]
report = dict.fromkeys(("namedCount", "matrixCount", "matrixViolations", "cooldownMainCount"), 0)
report.update(suite=args.suite, cases=[], findings=[])
for case_file in case_files:
    audit = lua.execute((ROOT / "tests" / case_file).read_text(encoding="utf-8"))
    for key in ("namedCount", "matrixCount", "matrixViolations", "cooldownMainCount"):
        report[key] += audit[key] or 0
    report["cases"].extend(rows(audit.cases))
    report["findings"].extend(rows(audit.findings))
assert len({case["name"] for case in report["cases"]}) == report["namedCount"], "Scenario names must be unique"
if args.suite == "hundred":
    assert report["namedCount"] == 100, "The requested suite must execute exactly 100 scenarios"
report["passed"] = report["namedCount"] - len(report["findings"])
print(f"{args.suite.upper()}: {report['passed']}/{report['namedCount']} named expectations met")
if report["matrixCount"]:
    print(f"MATRIX: {report['matrixCount']} combinations; {report['matrixViolations']} invariant violations")
for finding in report["findings"]:
    print(f"GAP [{finding.get('priority', 'review')}]: {finding['name']}\n  Expected: {finding['expected']}\n  Actual: {finding['actual']}")
if args.output:
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
if report["matrixViolations"] or args.strict and report["findings"]:
    sys.exit(1)
