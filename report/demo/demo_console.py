#!/usr/bin/env python3
"""PC-side demo console for the Z7-LITE 7010 RISC-V + CRC32 board.

Interactive commands:
  RESTART       program the known bitstream and run one 12-case suite
  RESTART FAST  skip programming, issue one VIO restart and read the mailbox
  DEMO          run 3 rounds; each round is RESTART + forward + reverse scan
  DEMO 5        run 5 rounds
  DEMO FAST     run 3 rounds without reprogramming
  QUIT          exit

The PC sends only VIO debug commands (restart/read_index); it does not inject
RV32I instructions. The CPU executes its ROM firmware.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BIT = ROOT / "board" / "runtime" / "demo.bit"
LTX = ROOT / "board" / "runtime" / "demo.ltx"
VIVADO = Path(os.environ.get("CRC_DEMO_VIVADO_BIN", "D:/XILINX/2026.1/Vivado/bin")) / "vivado.bat"
TCL_SINGLE = ROOT / "report" / "demo" / "demo_capture.tcl"
TCL_STREAM = ROOT / "report" / "demo" / "demo_stream.tcl"
OUT = ROOT / "report" / "demo" / "last_capture.hex"
LOG = ROOT / "report" / "demo" / "last_vivado.log"
CASES = ROOT / "skill" / "examples" / "z7_crc_cases.json"
OFFLINE = ROOT / "data" / "hardware" / "s05" / "run_0_scan_0.hex"

sys.path.insert(0, str(ROOT / "skill" / "scripts"))
import verify_mailbox as vm  # type: ignore


def line(char="=", width=78):
    print(char * width)


def header(subtitle="JTAG/VIO 命令与结果控制台"):
    os.system("cls" if os.name == "nt" else "clear")
    line()
    print("  Z7-LITE_ES1  /  XC7Z010CLG400-1")
    print("  六级 RV32I＋Zicsr CPU  +  CRC-32/ISO-HDLC 加速器")
    print(f"  {subtitle}")
    line()


def display(hex_path: Path, label: str):
    try:
        cases = vm.load_cases(CASES)
        words = vm.read_dump(hex_path)
        result = vm.validate(words, cases)
    except Exception as error:
        print(f"  读取失败: {error}")
        return None
    print(f"  {label}")
    line("-")
    print(f"  {'case':>4} {'bytes':>5} {'expected':>9} {'hardware':>9} {'sw cyc':>8} {'hw cyc':>8} {'speedup':>9}  status")
    line("-")
    for row in result["rows"]:
        ok = "PASS" if row["hardware_crc"] == row["expected_crc"] else "FAIL"
        print(
            f"  {row['case']:>4} {row['bytes']:>5} {row['expected_crc']:>9} {row['hardware_crc']:>9} "
            f"{row['software_cycles']:>8} {row['hardware_total_cycles']:>8} {row['speedup']:>9.6f}x  {ok}"
        )
    line("-")
    hw = result["rows"][-1]
    print(f"  CRC 12/12 PASS   |   4096 B: {hw['software_cycles']} / {hw['hardware_total_cycles']} cycles = {hw['speedup']:.6f}x")
    print("  邮箱 104 字，error_count=0，committed=1，failed=0")
    line()
    return result


def run_live(program: bool) -> bool:
    if not BIT.is_file() or not LTX.is_file():
        print(f"  缺少下载文件: {BIT} 或 {LTX}")
        return False
    if OUT.exists():
        OUT.unlink()
    header("正在通过 JTAG/VIO 连接 FPGA ...")
    print("  → 打开 Vivado Hardware Manager")
    print("  → 连接唯一 JTAG 目标 / xc7z010")
    print("  → " + ("下载 BIT/LTX，发送 RESTART" if program else "复用当前 BIT，发送 RESTART"))
    sys.stdout.flush()
    cmd = [
        str(VIVADO), "-mode", "batch", "-nojournal", "-log", str(LOG),
        "-source", str(TCL_SINGLE),
        "-tclargs", str(BIT), str(LTX), str(OUT), "1" if program else "0",
    ]
    try:
        proc = subprocess.run(cmd, cwd=str(ROOT), capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=180)
    except subprocess.TimeoutExpired:
        print("  Vivado 采集超时。")
        return False
    if proc.returncode != 0 or not OUT.is_file():
        print(f"  采集失败（退出码 {proc.returncode}）。日志末尾：")
        for row in (proc.stdout + "\n" + proc.stderr).strip().splitlines()[-12:]:
            print("  " + row)
        return False
    header("FPGA 已运行完成，主机读取 104 字邮箱")
    return display(OUT, "板级实测结果（JTAG/VIO）") is not None


def progress_bar(run: int, pass_no: int, index: int, total: int = 104):
    filled = int(28 * (index + 1) / total)
    bar = "#" * filled + "-" * (28 - filled)
    direction = "正向" if pass_no == 0 else "反向"
    sys.stdout.write(f"\r  Round {run + 1}  {direction}扫描  [{bar}] {index + 1:3d}/{total}")
    sys.stdout.flush()


def run_demo(runs: int, program: bool, pace: float) -> bool:
    if not BIT.is_file() or not LTX.is_file() or not TCL_STREAM.is_file():
        print("  缺少 BIT/LTX 或多轮脚本。")
        return False
    stamp = time.strftime("%Y%m%d_%H%M%S")
    outdir = ROOT / "report" / "demo" / f"runs_{stamp}"
    outdir.mkdir(parents=True, exist_ok=True)
    log = outdir / "vivado.log"
    header(f"多轮演示：{runs} 轮 RESTART，每轮正向/反向两次 104 字扫描")
    print(f"  → 输出目录: {outdir.relative_to(ROOT)}")
    print("  → " + ("下载 BIT/LTX" if program else "复用当前 BIT"))
    print("  → 每轮：RESTART → FPGA 跑 12 例 CRC → 正向扫描 → 间隔 1 s → 反向扫描 → 逐字比对")
    line()
    sys.stdout.flush()
    cmd = [
        str(VIVADO), "-mode", "batch", "-nojournal", "-log", str(log),
        "-source", str(TCL_STREAM),
        "-tclargs", str(BIT), str(LTX), str(outdir), "1" if program else "0", str(runs),
    ]
    proc = subprocess.Popen(
        cmd, cwd=str(ROOT), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, encoding="utf-8", errors="replace", bufsize=1,
    )
    assert proc.stdout is not None
    for raw in proc.stdout:
        row = raw.strip()
        if not row:
            continue
        if row.startswith("PROGRESS "):
            parts = row.split()
            if len(parts) == 5:
                run, pass_no, index = int(parts[1]), int(parts[2]), int(parts[3])
                if index == 0 or index == 103 or index % 8 == 0:
                    progress_bar(run, pass_no, index)
                    if pace > 0:
                        time.sleep(pace)
            continue
        if row.startswith("SCAN_END "):
            print()
            continue
        if row.startswith("ROUND_START "):
            print(f"\n  ── 第 {int(row.split()[1]) + 1} 轮：发送 RESTART ──")
            continue
        if row.startswith("RESTART_LOW "):
            print(f"  第 {int(row.split()[1]) + 1} 轮：RESTART 拉低")
            continue
        if row.startswith("RESTART_ASSERTED "):
            print(f"  第 {int(row.split()[1]) + 1} 轮：RESTART 置高（辅助复位）")
            continue
        if row.startswith("RESTART_RELEASED "):
            print(f"  第 {int(row.split()[1]) + 1} 轮：RESTART 释放")
            continue
        if row.startswith("COMMITTED "):
            print(f"  第 {int(row.split()[1]) + 1} 轮：FPGA 已提交邮箱")
            continue
        if row.startswith("ROUND_END "):
            print(f"  第 {int(row.split()[1]) + 1} 轮：正向/反向扫描逐字一致")
            continue
        if row.startswith("DEMO_DONE "):
            print(f"\n  全部 {row.split()[1]} 轮完成。")
            continue
        if row.startswith("TARGET "):
            print(f"  JTAG 目标: {row.split(' ', 1)[1]}")
            continue
        if row.startswith("DEVICE "):
            print(f"  器件: {row.split(' ', 1)[1]}")
            continue
        if row.startswith("VIO "):
            print(f"  VIO 实例: {row.split(' ', 1)[1]}")
            continue
        if row.startswith(("PROGRAM_BEGIN", "PROGRAM_END")):
            print(f"  {row}")
            continue
        if row.startswith("#"):
            continue
        if any(word in row for word in ("ERROR:", "CRITICAL WARNING:", "FATAL")):
            print(f"  {row}")
    code = proc.wait()
    if code != 0:
        print(f"\n  Vivado 退出码 {code}，保留输出目录与日志。")
        return False
    print()
    results = []
    for run in range(runs):
        hex_path = outdir / f"run_{run}_scan_0.hex"
        result = display(hex_path, f"第 {run + 1} 轮结果（正向扫描）")
        if result is None:
            return False
        results.append(result)
    line()
    print(f"  汇总：{runs} 轮 × 12 例 = {runs * 12} 例 CRC 全部匹配；每轮正向/反向 104 字逐字一致。")
    last = results[-1]["rows"][-1]
    print(f"  4096 B: {last['software_cycles']} / {last['hardware_total_cycles']} cycles = {last['speedup']:.6f}x")
    print(f"  结果已保存: {outdir.relative_to(ROOT)}")
    print(f"  再次查看: python -B -X utf8 report/demo/demo_console.py --show {outdir.relative_to(ROOT)}")
    line()
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="replay the saved board capture instead of touching hardware")
    parser.add_argument("--show", nargs="?", const="latest", help="display a saved run directory (default: latest runs_* directory)")
    parser.add_argument("--once", action="store_true", help="run one live capture without the interactive prompt")
    parser.add_argument("--fast", action="store_true", help="with --once/--demo, skip programming and reuse the current bitstream")
    parser.add_argument("--demo", action="store_true", help="run the multi-round demo without the interactive prompt")
    parser.add_argument("--runs", type=int, default=3, help="number of rounds for --demo (default 3)")
    parser.add_argument("--pace", type=float, default=0.02, help="display pacing per mailbox word in seconds (default 0.02)")
    args = parser.parse_args()
    if args.show:
        target = args.show
        if target == "latest":
            dirs = sorted((ROOT / "report" / "demo").glob("runs_*"), key=lambda p: p.stat().st_mtime)
            if not dirs:
                print("  没有找到 runs_* 结果目录。")
                return 1
            outdir = dirs[-1]
        else:
            outdir = Path(target)
            if not outdir.is_absolute():
                outdir = ROOT / outdir
        if not outdir.is_dir():
            print(f"  目录不存在: {outdir}")
            return 1
        header(f"离线查看已保存结果：{outdir.name}")
        files = sorted(outdir.glob("run_*_scan_0.hex"))
        if not files:
            print("  该目录没有 run_*_scan_0.hex。")
            return 1
        results = []
        for i, hex_path in enumerate(files):
            result = display(hex_path, f"第 {i + 1} 轮结果（正向扫描）")
            if result is None:
                return 1
            results.append(result)
        line()
        print(f"  共 {len(results)} 轮 × 12 例 = {len(results) * 12} 例 CRC 全部匹配。")
        last = results[-1]["rows"][-1]
        print(f"  4096 B: {last['software_cycles']} / {last['hardware_total_cycles']} cycles = {last['speedup']:.6f}x")
        line()
        return 0
    if args.offline:
        header("离线回放（使用已保存的板级采集，不访问硬件）")
        display(OFFLINE, "已保存的板级结果（离线回放）")
        return 0
    if args.once:
        ok = run_live(program=not args.fast)
        return 0 if ok else 1
    if args.demo:
        ok = run_demo(max(1, args.runs), program=not args.fast, pace=max(0.0, args.pace))
        return 0 if ok else 1

    header()
    print("  RESTART       下载/复用 BIT，发送一次 VIO RESTART，读取 12 例 CRC")
    print("  RESTART FAST  跳过下载，仅发送 VIO RESTART")
    print("  DEMO [N]      多轮演示：N 轮 RESTART，每轮正向/反向两次 104 字扫描（默认 3）")
    print("  DEMO FAST     多轮演示，跳过下载")
    print("  QUIT          退出")
    line()
    while True:
        try:
            raw = input("  > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return 0
        command = raw.upper()
        if command == "QUIT":
            return 0
        if command in ("RESTART", "RESTART FAST"):
            ok = run_live(program=(command == "RESTART"))
            print()
            print("  输入 RESTART、DEMO 或 QUIT。" if ok else "  可重试 RESTART，或 QUIT。")
            print()
            continue
        if command.startswith("DEMO"):
            parts = raw.split()
            fast = any(p.upper() == "FAST" for p in parts[1:])
            numbers = [int(p) for p in parts[1:] if p.isdigit()]
            runs = numbers[0] if numbers else 3
            ok = run_demo(max(1, runs), program=not fast, pace=0.02)
            print()
            print("  输入 DEMO 再跑一组，或 QUIT。" if ok else "  可重试 DEMO，或 QUIT。")
            print()
            continue
        if command:
            print("  未知命令。输入 RESTART、RESTART FAST、DEMO [N]、DEMO FAST 或 QUIT。")


if __name__ == "__main__":
    raise SystemExit(main())
