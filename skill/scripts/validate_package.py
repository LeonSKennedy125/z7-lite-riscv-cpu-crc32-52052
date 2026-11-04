"""检查技能包结构/引用/脚本，并实际运行判定器正负对照；不运行综合或修改原工程。"""
import argparse
import ast
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="新的不存在目录")
    a = parser.parse_args()
    if a.out.exists():
        parser.error("输出目录已存在")
    a.out.mkdir(parents=True)
    output = a.out.resolve()
    results, structure = [], []
    def record(name, operation):
        try:
            operation()
            results.append({"case": name, "pass": True, "scope": "synthetic_checker_control_only"})
        except Exception as exc:
            results.append({"case": name, "pass": False, "error": str(exc)})
    def require(value, message="判定不符合预期"):
        if not value:
            raise AssertionError(message)
    skills = sorted(ROOT.glob("*/SKILL.md"))
    names = []
    for skill in skills:
        text = skill.read_text(encoding="utf-8")
        front = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
        name = re.search(r"^name:\s*([a-z0-9-]+)\s*$", front[1], re.M) if front else None
        valid = bool(name and name[1] == skill.parent.name and re.search(r"^description:\s*\S", front[1], re.M))
        structure.append({"path": str(skill.relative_to(ROOT)), "pass": valid})
        if name:
            names.append(name[1])
    structure.append({"check": "three_unique_skills", "pass": len(skills) == 3 and len(set(names)) == 3})
    sources = [p for p in ROOT.rglob("*") if p.is_file() and "artifacts" not in p.relative_to(ROOT).parts
               and "__pycache__" not in p.parts]
    for path in sources:
        if path.stat().st_size == 0:
            structure.append({"path": str(path.relative_to(ROOT)), "pass": False, "error": "EMPTY_FILE"})
        if path.suffix == ".py":
            try:
                ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            except SyntaxError as exc:
                structure.append({"path": str(path), "pass": False, "error": str(exc)})
        if path.suffix == ".md":
            for link in re.findall(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", path.read_text(encoding="utf-8")):
                if re.match(r"^(https?://|mailto:|#)", link):
                    continue
                target = (path.parent / link.split("#")[0].strip("<>")).resolve()
                structure.append({"from": str(path.relative_to(ROOT)), "link": link, "pass": target.exists()})
    trace = load("skill_trace", ROOT / "riscv-verification/scripts/compare_trace.py")
    units = load("skill_units", ROOT / "riscv-verification/scripts/run_units.py")
    reports = load("skill_reports", ROOT / "vivado-automation/scripts/analyze_reports.py")
    fixture = output / "fixtures"
    fixture.mkdir()
    expected = [(0x80000000, 1, 5), (0x80000004, 2, 9)]
    record("trace_equal", lambda: require(trace.compare(expected, expected)["trace_equal"]))
    for label, actual in (("wrong_value", [(0x80000000, 1, 6), expected[1]]),
                          ("wrong_pc", [(0x80000008, 1, 5), expected[1]]),
                          ("wrong_rd", [(0x80000000, 3, 5), expected[1]]),
                          ("missing_write", expected[:1]), ("extra_write", expected + expected[:1])):
        record("trace_reject_" + label, lambda actual=actual: require(not trace.compare(expected, actual)["trace_equal"]))
    def rejects(call):
        try:
            call()
        except (ValueError, RuntimeError):
            return
        raise AssertionError("错误输入被接受")
    for label, content in (("empty", ""), ("xz", "80000000 1 xxxxxxxx\n"),
                           ("truncated_count", "2\n80000000 1 00000005\n"),
                           ("invalid_rd", "80000000 32 00000005\n"),
                           ("malformed", "80000000 1 00000005 junk\n")):
        f = fixture / (label + ".trace")
        f.write_text(content, encoding="ascii")
        record("trace_input_" + label, lambda f=f: rejects(lambda: trace.records(f, "triples")))
    marker = "SKILL_CONTRACT_SUMMARY"
    good = marker + " checks=175 failures=0\n"
    record("log_valid", lambda: require(units.check_transcript(good, marker) == 175))
    for label, content in (("bare_pass", "PASS\n"), ("zero_checks", marker + " checks=0 failures=0\n"),
                           ("nonzero_failures", marker + " checks=175 failures=1\n"),
                           ("duplicate_summary", good + good), ("hidden_fail", "FAIL | injected\n" + good),
                           ("fatal_then_summary", "FATAL: injected\n" + good)):
        record("log_reject_" + label, lambda content=content: rejects(lambda: units.check_transcript(content, marker)))
    record("reset_duplicate_marker", lambda: rejects(lambda: units.check_transcript("R1_RESET_SOURCES=PASS\n" * 2, "R1_RESET_SOURCES=PASS")))
    util = "\n".join(f"| {name} | {n} | 0 |" for name, n in (("Slice LUTs", 10), ("Slice Registers", 20),
        ("Block RAM Tile", 1), ("RAMB36/FIFO", 1), ("RAMB18", 0), ("DSPs", 0)))
    header = "Design State : Routed\nWNS(ns) TNS(ns) TNS Fails WHS(ns) THS(ns) Hold Total WPWS(ns) TPWS(ns) Pulse Total\n"
    values = "0.100 0.000 0 100 0.050 0.000 0 100 1.000 0.000 0 100\n"
    coverage = "\n".join(f"checking {name} (0)" for name in ("no_clock", "unconstrained_internal_endpoints", "no_input_delay", "no_output_delay"))
    clocks = "cpu_clock 6.250 {0.000 3.125} P,G,A {clk}\n"
    good_report = header + values + coverage
    record("report_valid_fixture", lambda: require(reports.analyze(util, good_report, clocks)["on_chip_timing_pass"]))
    record("report_missing", lambda: require(reports.analyze("", "", "")["status"] == "INCOMPLETE"))
    record("report_negative_wns", lambda: require(not reports.analyze(util, good_report.replace("0.100", "-0.100"), clocks)["on_chip_timing_pass"]))
    record("report_unconstrained", lambda: require(not reports.analyze(util, good_report.replace("endpoints (0)", "endpoints (1)"), clocks)["on_chip_timing_pass"]))
    record("report_not_routed", lambda: require(reports.analyze(util, good_report.replace("Routed", "Synthesized"), clocks)["status"] == "INCOMPLETE"))
    def cli(name, script, arguments, expected_code):
        command = [sys.executable, "-B", "-X", "utf8", str(ROOT / script), *map(str, arguments)]
        done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=30)
        (output / (name + ".log")).write_text(done.stdout + done.stderr, encoding="utf-8")
        require(done.returncode == expected_code, f"退出码 {done.returncode} != {expected_code}: {done.stdout} {done.stderr}")
    common = "80000000 1 00000005\n80000004 2 00000009\n"
    (fixture / "expected.trace").write_text(common, encoding="ascii")
    (fixture / "wrong.trace").write_text(common.replace("00000009", "00000008"), encoding="ascii")
    record("cli_trace_mismatch", lambda: cli("trace_mismatch", "riscv-verification/scripts/compare_trace.py",
        ["--expected", fixture / "expected.trace", "--actual", fixture / "wrong.trace"], 1))
    record("cli_trace_unknown", lambda: cli("trace_unknown", "riscv-verification/scripts/compare_trace.py",
        ["--expected", fixture / "expected.trace", "--actual", fixture / "xz.trace"], 2))
    record("cli_missing_reports", lambda: cli("missing_reports", "vivado-automation/scripts/analyze_reports.py",
        ["--report-dir", fixture, "--out", output / "missing_report_output"], 2))
    record("cli_refuse_existing_output", lambda: cli("refuse_output", "riscv-verification/scripts/run_units.py", ["--out", fixture], 2))
    for path in sorted(ROOT.rglob("*.py")):
        if "artifacts" not in path.relative_to(ROOT).parts and path != Path(__file__).resolve():
            record("help_" + str(path.relative_to(ROOT)), lambda path=path: cli("help_" + path.stem,
                path.relative_to(ROOT), ["--help"], 0))
    passed = all(r["pass"] for r in results) and all(r["pass"] for r in structure)
    summary = {"pass": passed, "skill_count": len(skills), "files_checked": len(sources),
               "structure_checks": structure, "checker_controls": results,
               "checker_controls_passed": sum(r["pass"] for r in results),
               "scope": "package_and_synthetic_checker_controls_not_cpu_functional_tests"}
    (output / "validation.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in summary.items() if k not in ("structure_checks", "checker_controls")}, ensure_ascii=False))
    for r in results + structure:
        if not r["pass"]:
            print(json.dumps(r, ensure_ascii=False))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
