"""复制已有全核周期证据，使用当前参考模型重新比对；不会启动仿真或改写原证据。"""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import importlib
import json
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
REQUIRED = ("reference.json", "static_reference.jsonl", "program.hex", "cycles.csv", "simulation.log", "final_rf.hex")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project-root", type=Path, required=True)
    p.add_argument("--run-dir", type=Path, required=True)
    p.add_argument("--out", type=Path, required=True, help="新的不存在目录")
    a = p.parse_args()
    root, original, out = a.project_root.resolve(), a.run_dir.resolve(), a.out.resolve()
    if out.exists():
        p.error("输出目录已存在")
    inputs = [original / n for n in REQUIRED] + [root / "verification" / n for n in ("check_phase09.py", "phase09_reference.py")]
    if any(not f.is_file() for f in inputs):
        p.error("缺少输入: " + str([str(f) for f in inputs if not f.is_file()]))
    hashes = {str(f): hashlib.sha256(f.read_bytes()).hexdigest() for f in inputs}
    out.mkdir(parents=True)
    report = {"pass": False, "scope": "historical_cycle_trace_recheck", "fresh_simulation": False,
              "board_verified": False, "origin": str(original), "input_sha256": hashes,
              "timestamp": datetime.now(timezone(timedelta(hours=8))).isoformat()}
    try:
        for name in REQUIRED:
            shutil.copyfile(original / name, out / name)
        sys.path.insert(0, str(root / "verification"))
        checker = importlib.import_module("check_phase09")
        report["metrics"] = checker.check(out)
        report["pass"] = True
    except Exception as exc:
        report["error"] = str(exc)
    report["original_inputs_unchanged"] = all(hashlib.sha256(Path(f).read_bytes()).hexdigest() == h for f, h in hashes.items())
    report["pass"] = report["pass"] and report["original_inputs_unchanged"]
    (out / "recheck.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if k != "input_sha256"}, ensure_ascii=False))
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
