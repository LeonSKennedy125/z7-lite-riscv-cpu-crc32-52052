#!/usr/bin/env python3
"""One-click evidence viewer for the CRC demo video.

Examples:
  python -B -X utf8 report/demo/show_evidence.py          # open all + verify latest
  python -B -X utf8 report/demo/show_evidence.py dis      # firmware.dis only
  python -B -X utf8 report/demo/show_evidence.py map
  python -B -X utf8 report/demo/show_evidence.py rom
  python -B -X utf8 report/demo/show_evidence.py run      # latest mailbox header
  python -B -X utf8 report/demo/show_evidence.py verify   # verify latest three runs
  python -B -X utf8 report/demo/show_evidence.py test     # verifier negative controls
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CASES = ROOT / "skill" / "scripts" / "verify_mailbox.py"
RUNS = ROOT / "report" / "demo"


def code_cmd() -> str | None:
    found = shutil.which("code")
    if found:
        return found
    fallback = Path(r"D:\VS Code\bin\code.cmd")
    return str(fallback) if fallback.is_file() else None


def open_at(rel: str, needle: str | None = None, line: int = 1) -> None:
    path = ROOT / rel
    if not path.is_file():
        print(f"缺少文件: {path}")
        return
    if needle:
        for number, text in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if needle in text:
                line = number
                break
    editor = code_cmd()
    if editor:
        subprocess.Popen(f'"{editor}" -g "{path}:{line}"', shell=True, cwd=str(ROOT))
        print(f"打开 {rel}:{line}")
    else:
        subprocess.Popen(["notepad.exe", str(path)])
        print(f"打开 {rel}（记事本，无法定位行号）")


def latest_run() -> Path | None:
    dirs = [p for p in RUNS.glob("runs_*") if (p / "run_0_scan_0.hex").is_file()]
    return max(dirs, key=lambda p: p.stat().st_mtime) if dirs else None


def show_run() -> None:
    run = latest_run()
    if not run:
        print("没有找到成功的 runs_* 目录。")
        return
    print(f"\n最新采集: {run.relative_to(ROOT)}", flush=True)
    lines = (run / "run_0_scan_0.hex").read_text(encoding="utf-8").splitlines()
    labels = [
        "magic",
        "version",
        "clock_hz",
        "ram_bytes",
        "case_count",
        "errors",
        "total_words",
        "executed_checks",
    ]
    for label, word in zip(labels, lines[:8]):
        print(f"  {label:16s} {word}", flush=True)
    words = [int(x, 16) for x in lines]
    row = words[8 + 11 * 8 : 8 + 12 * 8]
    print(f"  4096 B: {row[5]} / {row[6]} cycles = {row[5] / row[6]:.6f}x", flush=True)


def verify() -> None:
    run = latest_run()
    if not run:
        print("没有找到成功的 runs_* 目录。")
        return
    print(f"\n独立校验: {run.relative_to(ROOT)}", flush=True)
    for hex_path in sorted(run.glob("run_*_scan_0.hex")):
        subprocess.run(
            [sys.executable, "-B", "-X", "utf8", str(CASES), "--dump", str(hex_path)],
            cwd=str(ROOT),
            check=True,
        )


def self_test() -> None:
    print("\n校验器负对照:", flush=True)
    subprocess.run(
        [sys.executable, "-B", "-X", "utf8", str(CASES), "--self-test"],
        cwd=str(ROOT),
        check=True,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="一键查看 CRC 演示证据")
    parser.add_argument(
        "what",
        nargs="?",
        default="all",
        choices=["all", "dis", "map", "rom", "run", "verify", "test"],
    )
    args = parser.parse_args()

    if args.what in ("all", "dis"):
        open_at("firmware/out/firmware.dis", "<_start>")
    if args.what in ("all", "map"):
        open_at("firmware/out/firmware.map", ".text")
    if args.what in ("all", "rom"):
        open_at("firmware/out/rom.hex", line=1)
    if args.what in ("all", "run"):
        show_run()
    if args.what in ("all", "verify"):
        verify()
    if args.what in ("all", "test"):
        self_test()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
