"""默认只生成构建计划；--execute 时仅在新副本复用项目 R1 仿真/构建入口。"""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True


def inputs(root):
    paths = [root / "RISCV_5pipeline.xpr"]
    for directory in ("RISCV_5pipeline.srcs", "verification"):
        paths += [p for p in (root / directory).rglob("*") if p.is_file() and "__pycache__" not in p.parts]
    return {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project-root", type=Path, required=True)
    p.add_argument("--vivado-bin", type=Path, required=True)
    p.add_argument("--stage", choices=("simulate", "synth", "implement"), default="synth")
    p.add_argument("--case", choices=("isa", "mixed", "irq"), default="isa")
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--delay", type=int, default=0)
    p.add_argument("--out", type=Path, required=True, help="新的不存在目录；Windows 执行时推荐短路径")
    p.add_argument("--execute", action="store_true", help="真正执行；运行前确认耗时许可，仅操作隔离副本")
    p.add_argument("--timeout", type=int, default=7200, help="每个子进程超时秒数")
    a = p.parse_args()
    root, out, binary = a.project_root.resolve(), a.out.resolve(), a.vivado_bin.resolve()
    if out.exists():
        p.error("输出目录已存在，不覆盖或清理已有内容")
    if os.name != "nt":
        p.error("当前隔离适配器复用 Windows .bat 脚本；Linux 需另写适配器，报告提取器不限平台")
    if a.timeout <= 0 or a.delay < 0:
        p.error("timeout 必须为正，delay 不得为负")
    needed = [root / "RISCV_5pipeline.xpr", binary / "vivado.bat", root / "verification/toolchain.json",
              root / "verification/implement_phase10_r1.tcl", root / "verification/phase10_r1_core.py"]
    if any(not f.is_file() for f in needed):
        p.error("缺少输入: " + str([str(f) for f in needed if not f.is_file()]))
    tree = ET.parse(root / "RISCV_5pipeline.xpr")
    opts = {x.get("Name"): x.get("Val") for x in tree.findall("./Configuration/Option")}
    if opts.get("Part") != "xc7k325tffg676-2":
        p.error("R1 构建 Tcl 绑定 xc7k325tffg676-2；其他工程需审查并替换适配器")
    before = inputs(root)
    clone, reports, cwd = out / "project", out / "reports", out / "process"
    stamp = datetime.now(timezone(timedelta(hours=8))).isoformat()
    commands = []
    if a.stage == "simulate":
        base = [sys.executable, "-B", "-X", "utf8", str(clone / "verification/phase10_r1_core.py")]
        commands = [(base + ["build"], "PHASE09_BUILD=PASS"),
                    (base + ["run", "--case", a.case, "--seed", str(a.seed), "--delay", str(a.delay)], "PHASE09_RUN=PASS")]
        fixture = root / "verification/phase09_programs" / f"{a.case}_s{a.seed}"
        if not (fixture / "reference.json").is_file():
            p.error("指定 seed 的程序不存在，先在隔离目录生成；不自动改写原测试输入")
    else:
        for stage in (["synth", "route"] if a.stage == "implement" else ["synth"]):
            commands.append(([str(binary / "vivado.bat"), "-mode", "batch", "-notrace", "-source",
                str(clone / "verification/implement_phase10_r1.tcl"), "-log", str(reports / (stage + ".log")),
                "-journal", str(reports / (stage + ".jou")), "-tclargs", stage, str(reports)], "PHASE10_" + stage.upper() + "=PASS"))
    out.mkdir(parents=True)
    plan = {"timestamp": stamp, "stage": a.stage, "execute_requested": a.execute,
            "source_project": str(root), "clone": str(clone), "tool_bin": str(binary),
            "required_vivado": "2026.1", "commands": [{"argv": c, "required_marker": m, "cwd": str(cwd)} for c, m in commands],
            "copy_changes": ["仅在副本更新 XPR 自身位置", "仅在副本去除 utils_1 历史 DCP/RQS 引用",
                             "仅在副本更新 toolchain.json 工具和工程位置"],
            "scope": "isolated_project_build", "board_verified": False}
    (out / "plan.json").write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "inputs_before.json").write_text(json.dumps(before, indent=2), encoding="utf-8")
    if not a.execute:
        print("PLAN_ONLY", out / "plan.json")
        return 0
    # There is no delete/reset/program/license action in this wrapper.
    result = {"pass": False, "stage": a.stage, "fresh_build": True, "board_verified": False, "commands": []}
    try:
        clone.mkdir()
        reports.mkdir()
        cwd.mkdir()
        for name in ("RISCV_5pipeline.srcs", "verification"):
            shutil.copytree(root / name, clone / name,
                ignore=shutil.ignore_patterns("__pycache__", "*.dcp", "*.rqs", "utils_1"))
        tree.getroot().set("Path", (clone / "RISCV_5pipeline.xpr").as_posix())
        for parent in tree.iter():
            for child in list(parent):
                if child.tag == "FileSet" and child.get("Name") == "utils_1":
                    parent.remove(child)
        tree.write(clone / "RISCV_5pipeline.xpr", encoding="UTF-8", xml_declaration=True)
        config_path = clone / "verification/toolchain.json"
        config = json.loads(config_path.read_text(encoding="utf-8"))
        config.update(tool_bin=binary.as_posix(), active_project_directory=clone.as_posix())
        if config["version"] != "2026.1":
            raise ValueError("R1 脚本需要工具配置版本 2026.1")
        config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2), encoding="utf-8")
        (clone / "repair_records/phase10/rework_R1").mkdir(parents=True)
        # Full record includes all copied input hashes before Vivado generation.
        (out / "clone_inputs.json").write_text(json.dumps(inputs(clone), indent=2), encoding="utf-8")
        env = os.environ.copy()
        env["PYTHONDONTWRITEBYTECODE"] = "1"
        for index, (command, marker) in enumerate(commands):
            log_path = out / f"stage_{index}.console.log"
            record = {"argv": command, "cwd": str(cwd), "log": str(log_path), "required_marker": marker}
            result["commands"].append(record)
            with log_path.open("w", encoding="utf-8") as log:
                proc = subprocess.Popen(command, cwd=cwd, env=env, stdout=log, stderr=subprocess.STDOUT)
                try:
                    record["exit_code"] = proc.wait(a.timeout)
                except subprocess.TimeoutExpired:
                    subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"], capture_output=True)
                    proc.wait()
                    raise RuntimeError("本脚本启动的构建进程超时，见日志")
            text = log_path.read_text(encoding="utf-8", errors="replace")
            if record["exit_code"] != 0 or marker not in text:
                raise RuntimeError("子流程失败或完成标记缺失")
        result["pass"] = True
        result["evidence_directory"] = str(reports if a.stage != "simulate" else clone / "repair_records/phase10/rework_R1")
        result["analysis_hint"] = "实现成功后对 reports 运行 analyze_reports.py；仅综合结果不能视为布线通过"
    except Exception as exc:
        result["error"] = str(exc)
    finally:
        after = inputs(root)
        result["original_inputs_unchanged"] = before == after
        result["pass"] = result["pass"] and result["original_inputs_unchanged"]
        (out / "inputs_after.json").write_text(json.dumps(after, indent=2), encoding="utf-8")
        (out / "result.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
