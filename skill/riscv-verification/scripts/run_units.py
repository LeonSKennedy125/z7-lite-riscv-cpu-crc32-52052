"""隔离运行现有前递/CSR/复位 TB 与技能包契约 TB；无综合、无原工程写入。"""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
BASE = Path(__file__).resolve().parents[1]
SOURCES = {
    "contract": ("skill_contract_tb", ["ALU.v", "Comp.v", "Ctrl.v", "Decoder.v", "Regfile.v",
        "Branch_Ctrl.v", "instr_minidecoder.v", "Store.v"], [], "SKILL_CONTRACT_SUMMARY"),
    "forward": ("phase04_unit_tb", ["MEM_WB.v", "EX_MEM.v", "Forward.v", "MEM_Forward.v",
        "WB_Forward.v", "Forward_Ctrl.v", "save_Load_use.v"], [], "PHASE04_UNIT_SUMMARY"),
    "csr": ("phase05_unit_tb", ["Decoder.v"],
        ["csr_pkg.sv", "csr_decode.sv", "csr_regfile.sv", "csr_top.v"], "PHASE05_UNIT_SUMMARY"),
    "reset": ("phase10_r1_reset_sources_tb", ["cpu_reset_sync.v", "cpu_reset_control.v"], [], "R1_RESET_SOURCES=PASS"),
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check_transcript(text, marker):
    """判定实际仿真日志；供运行入口和负对照共用。"""
    checks = None
    if marker.endswith("SUMMARY"):
        matches = re.findall(re.escape(marker) + r"\s+checks=(\d+)\s+failures=(\d+)", text)
        if len(matches) != 1 or int(matches[0][0]) == 0 or int(matches[0][1]) != 0:
            raise RuntimeError("缺少唯一零失败汇总，或存在断言失败")
        checks = int(matches[0][0])
    elif text.count(marker) != 1:
        raise RuntimeError("缺少唯一完成标记")
    if re.search(r"(?im)^\s*(FAIL\s*\||FATAL\b|ERROR:|Fatal:)", text):
        raise RuntimeError("日志出现失败标记")
    return checks


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=BASE.parents[1])
    parser.add_argument("--out", type=Path, required=True, help="必须是不存在的新目录")
    parser.add_argument("--backend", choices=("iverilog", "xsim"), default="iverilog")
    parser.add_argument("--vivado-bin", type=Path, help="XSim 所在 bin 目录；不读取旧 toolchain.json")
    parser.add_argument("--suite", choices=("all", *SOURCES), default="all")
    parser.add_argument("--timeout", type=int, default=90, help="每个工具的超时秒数")
    args = parser.parse_args()
    root, out = args.project_root.resolve(), args.out.resolve()
    if args.timeout <= 0:
        parser.error("timeout 必须为正数")
    if out.exists():
        parser.error("输出目录已存在，请使用新的目录名")
    if not (root / "RISCV_5pipeline.xpr").is_file():
        parser.error("此 TB 适配器需要 RISCV_5pipeline.xpr 及对应源文件")
    def tool(name):
        if args.backend == "xsim":
            if not args.vivado_bin:
                raise ValueError("XSim 需要 --vivado-bin")
            path = args.vivado_bin.resolve() / (name + (".bat" if os.name == "nt" else ""))
        else:
            located = shutil.which(name)
            if not located:
                raise ValueError(f"PATH 中缺少 {name}")
            path = Path(located)
        if not path.is_file():
            raise ValueError(f"找不到工具 {path}")
        return str(path)
    try:
        tools = {n: tool(n) for n in (("xvlog", "xelab", "xsim") if args.backend == "xsim" else ("iverilog", "vvp"))}
    except ValueError as exc:
        parser.error(str(exc))
    out.mkdir(parents=True)
    report = {"timestamp": datetime.now(timezone(timedelta(hours=8))).isoformat(),
              "scope": "module_simulation", "backend": args.backend, "board_verified": False,
              "tools": tools, "tests": [], "pass": False}
    selected = list(SOURCES) if args.suite == "all" else [args.suite]
    for case in selected:
        top, rtl_names, csr_names, marker = SOURCES[case]
        directory = out / case
        directory.mkdir()
        hashes = {}
        entry = {"case": case, "top": top, "pass": False, "commands": []}
        try:
            inputs = [root / "RISCV_5pipeline.srcs/sources_1/new" / n for n in rtl_names]
            inputs = [root / "RISCV_5pipeline.srcs/sources_1/imports/vivado-file" / n for n in csr_names] + inputs
            tb = BASE / "examples/skill_contract_tb.sv" if case == "contract" else root / "verification" / (top + ".sv")
            inputs += [tb, root / "RISCV_5pipeline.srcs/sources_1/new/RISCV_DEFINE.vh",
                       root / "RISCV_5pipeline.srcs/sources_1/new/CPU_MEMORY_MAP.vh"]
            hashes = {str(p): sha(p) for p in inputs}
            for source in inputs:
                if (directory / source.name).exists():
                    raise ValueError("编译文件名冲突: " + source.name)
                shutil.copyfile(source, directory / source.name)
            code_files = [p.name for p in inputs if p.suffix in (".v", ".sv")]
            if args.backend == "xsim":
                snapshot = "skill_" + case
                (directory / "run.tcl").write_text("run all\nquit\n", encoding="ascii")
                commands = [[tools["xvlog"], "--sv", "-i", ".", *code_files],
                    [tools["xelab"], top, "-s", snapshot, "--debug", "typical"],
                    [tools["xsim"], snapshot, "-tclbatch", "run.tcl", "-log", "simulation.log"]]
            else:
                commands = [[tools["iverilog"], "-g2012", "-I", ".", "-s", top, "-o", "simulation.vvp", *code_files],
                            [tools["vvp"], "simulation.vvp"]]
            for index, command in enumerate(commands):
                rec = {"argv": command, "cwd": str(directory)}
                entry["commands"].append(rec)
                with (directory / f"tool_{index}.log").open("w", encoding="utf-8") as log:
                    proc = subprocess.Popen(command, cwd=directory, stdout=log, stderr=subprocess.STDOUT)
                    try:
                        rec["exit_code"] = proc.wait(args.timeout)
                    except subprocess.TimeoutExpired:
                        if os.name == "nt":
                            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
                        else:
                            proc.kill()
                        proc.wait()
                        raise RuntimeError("工具超时")
                if rec["exit_code"]:
                    raise RuntimeError(f"工具退出码 {rec['exit_code']}，见 tool_{index}.log")
            text = (directory / f"tool_{len(commands)-1}.log").read_text(encoding="utf-8", errors="replace")
            entry["checks"] = check_transcript(text, marker)
            entry["pass"] = True
        except Exception as exc:
            entry["error"] = str(exc)
        finally:
            entry["input_sha256"] = hashes
            entry["inputs_unchanged"] = bool(hashes) and all(Path(p).is_file() and sha(p) == h for p, h in hashes.items())
            entry["pass"] = entry["pass"] and entry["inputs_unchanged"]
            report["tests"].append(entry)
            (out / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        print(case, "PASS" if entry["pass"] else "FAIL", entry.get("checks", ""), entry.get("error", ""), flush=True)
    report["pass"] = all(x["pass"] for x in report["tests"])
    (out / "summary.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "report.md").write_text("# 模块验证报告\n\n范围：模块级仿真，不含全核/实际 IP 存储时序或板级验证。\n\n" +
        "\n".join(f"- {x['case']}: {'PASS' if x['pass'] else 'FAIL'}; checks={x.get('checks', '见日志')}; {x.get('error', '')}" for x in report["tests"]) + "\n", encoding="utf-8")
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
