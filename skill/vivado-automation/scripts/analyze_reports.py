"""从 Vivado 原始报告提取真实资源和时序，缺失数据返回 INCOMPLETE。"""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import re


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def resource_values(text):
    aliases = {"lut": ("Slice LUTs", "CLB LUTs"), "ff": ("Slice Registers", "CLB Registers"),
               "bram_tile": ("Block RAM Tile",), "ramb36": ("RAMB36/FIFO", "RAMB36"),
               "ramb18": ("RAMB18",), "dsp": ("DSPs", "DSP48E1", "DSP48E2")}
    rows = {}
    for line in text.splitlines():
        columns = [v.strip() for v in line.split("|")]
        if len(columns) >= 4:
            key = columns[1].replace("*", "").strip()
            try:
                rows.setdefault(key, float(columns[2].replace(",", "")))
            except ValueError:
                pass
    return {name: next((rows[label] for label in labels if label in rows), None) for name, labels in aliases.items()}


def timing_values(text):
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if "WNS(ns)" in line and "TNS(ns)" in line and "WHS(ns)" in line:
            for row in lines[index+1:index+9]:
                values = row.split()
                if len(values) == 12 and all(re.fullmatch(r"-?\d+(?:\.\d+)?", v) for v in values):
                    keys = ("wns_ns", "tns_ns", "setup_failing", "setup_total", "whs_ns", "ths_ns", "hold_failing",
                            "hold_total", "wpws_ns", "tpws_ns", "pulse_failing", "pulse_total")
                    return dict(zip(keys, map(float, values)))
    return {}


def clock_values(text):
    result = []
    for row in text.splitlines():
        m = re.match(r"^\s*(\S+)\s+(\d+\.\d+)\s+\{[\d. ]+\}", row)
        if m and float(m[2]) > 0:
            result.append({"name": m[1], "period_ns": float(m[2]), "constraint_frequency_mhz": 1000 / float(m[2])})
    return result


def analyze(utilization, timing, clocks="", coverage=""):
    resources = resource_values(utilization)
    timing_result = timing_values(timing)
    counts = {key: int(value) for key, value in re.findall(r"checking\s+(\w+)\s+\((\d+)\)", coverage or timing)}
    issues = []
    if any(v is None for v in resources.values()):
        issues.append("RESOURCE_FIELDS_MISSING")
    if not timing_result:
        issues.append("TIMING_SUMMARY_MISSING")
    if any(k not in counts for k in ("no_clock", "unconstrained_internal_endpoints", "no_input_delay", "no_output_delay")):
        issues.append("CONSTRAINT_COVERAGE_MISSING")
    state = re.search(r"Design State\s*:\s*([^\r\n]+)", timing)
    if not state or state[1].strip() != "Routed":
        issues.append("ROUTED_STATE_NOT_PROVEN")
    clock_list = clock_values(clocks)
    if not clock_list:
        issues.append("CLOCK_REPORT_MISSING")
    passed = bool(timing_result) and all(timing_result[k] >= 0 for k in ("wns_ns", "whs_ns", "wpws_ns")) and all(
        timing_result[k] == 0 for k in ("tns_ns", "ths_ns", "tpws_ns", "setup_failing", "hold_failing", "pulse_failing"))
    passed = passed and counts.get("no_clock") == 0 and counts.get("unconstrained_internal_endpoints") == 0
    return {"resources": resources, "timing": timing_result, "constraint_coverage": counts, "clocks": clock_list,
            "design_state": state[1].strip() if state else None, "missing_evidence": issues,
            "on_chip_timing_pass": passed and not issues,
            "status": "INCOMPLETE" if issues else "ON_CHIP_TIMING_PASS" if passed else "TIMING_FAIL",
            "board_verified": False, "frequency_note": "Clock report gives constrained frequency, not measured board frequency or proven Fmax."}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--report-dir", type=Path, required=True)
    p.add_argument("--utilization", default="utilization.rpt", help="相对报告目录的文件名；可选 synth_utilization.rpt")
    p.add_argument("--timing", default="timing_summary.rpt")
    p.add_argument("--clocks", default="clocks.rpt")
    p.add_argument("--source-manifest", type=Path, help="可选：相对工程根的 path -> SHA256 清单")
    p.add_argument("--project-root", type=Path)
    p.add_argument("--require-io-delays", action="store_true", help="将缺失 IO delay 作为当前检查失败")
    p.add_argument("--log", type=Path, action="append", default=[], help="额外检查的构建日志，可多次指定")
    p.add_argument("--out", type=Path, required=True, help="必须是不存在的新目录")
    a = p.parse_args()
    if a.out.exists():
        p.error("输出目录已存在")
    if a.source_manifest and not a.project_root:
        p.error("--source-manifest 需要 --project-root")
    a.out.mkdir(parents=True)
    report = {"timestamp": datetime.now(timezone(timedelta(hours=8))).isoformat(), "fresh_build": False,
              "scope": "existing_report_analysis", "source_binding": "UNVERIFIED", "artifacts": {}}
    texts = {}
    for key, filename in (("utilization", a.utilization), ("timing", a.timing), ("clocks", a.clocks)):
        path = a.report_dir / filename
        texts[key] = path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""
        report["artifacts"][key] = {"path": str(path.resolve()), "sha256": digest(path) if path.is_file() else None}
    report.update(analyze(texts["utilization"], texts["timing"], texts["clocks"]))
    report["report_metadata"] = {key: (m[1].strip() if (m := re.search(re.escape(key) + r"\s*:\s*([^\r\n]+)", texts["timing"])) else None)
                                 for key in ("Tool Version", "Date", "Design", "Device")}
    if a.source_manifest:
        try:
            manifest = json.loads(a.source_manifest.read_text(encoding="utf-8-sig"))
            if not isinstance(manifest, dict) or not manifest:
                raise ValueError("哈希清单必须是非空对象")
            root, failures = a.project_root.resolve(), []
            for name, expected in manifest.items():
                f = (root / name).resolve()
                if not f.is_relative_to(root) or not f.is_file() or digest(f) != expected:
                    failures.append(name)
            report["source_binding"] = "MATCHED" if not failures else "MISMATCH"
            report["source_manifest"] = {"sha256": digest(a.source_manifest), "entries": len(manifest), "failures": failures}
        except (ValueError, OSError) as exc:
            report["source_binding"] = "MISMATCH"
            report["source_manifest_error"] = str(exc)
    report["log_findings"] = []
    for path in a.log:
        if not path.is_file():
            report["log_findings"].append({"path": str(path), "error": "MISSING_LOG"})
        else:
            for number, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if re.match(r"\s*(ERROR:|FATAL|CRITICAL WARNING:)", line):
                    report["log_findings"].append({"path": str(path), "line": number, "text": line})
    log_errors = any("error" in f or re.match(r"\s*(ERROR:|FATAL)", f.get("text", "")) for f in report["log_findings"])
    io_failure = a.require_io_delays and any(report["constraint_coverage"].get(k, 1) for k in ("no_input_delay", "no_output_delay"))
    report["check_pass"] = report["on_chip_timing_pass"] and report["source_binding"] != "MISMATCH" and not log_errors and not io_failure
    report["system_pending"] = {"missing_input_delays": report["constraint_coverage"].get("no_input_delay"),
        "missing_output_delays": report["constraint_coverage"].get("no_output_delay"),
        "board_pins_electrical_bridge_hardware": "not evaluated by this parser"}
    (a.out / "analysis.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    table = "\n".join(f"| {key} | {value if value is not None else 'MISSING'} |" for key, value in report["resources"].items())
    (a.out / "report.md").write_text("# 已有 Vivado 报告分析\n\n" +
        f"状态：{report['status']}；输入绑定：{report['source_binding']}；新构建：否；板级验证：否。\n\n" +
        "| 资源 | 数值 |\n| --- | --- |\n" + table + "\n\n时序：`" + json.dumps(report["timing"]) + "`\n\n" +
        "时钟：`" + json.dumps(report["clocks"]) + "`\n\n" +
        "频率来自约束，不是板上测量或 Fmax。IO 延迟及物理系统待验证项见 analysis.json。\n", encoding="utf-8")
    print(json.dumps({k: report[k] for k in ("status", "check_pass", "resources", "timing", "source_binding", "system_pending")}, ensure_ascii=False))
    return 0 if report["check_pass"] else 2 if report["status"] == "INCOMPLETE" else 1


if __name__ == "__main__":
    raise SystemExit(main())
