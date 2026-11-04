"""Recompute all published mailbox data and check its artifact/log bindings."""
from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    spec = importlib.util.spec_from_file_location("mailbox_reference", ROOT / "skill/scripts/verify_mailbox.py")
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    cases = checker.load_cases(checker.DEFAULT_CASES)
    s05 = ROOT / "data/hardware/s05"
    recent = ROOT / "report/demo/runs_20261104_120839"
    simulation = ROOT / "sim/results"
    checked = []
    for directory in (s05, recent):
        for run in range(3):
            left = directory / f"run_{run}_scan_0.hex"
            right = directory / f"run_{run}_scan_1.hex"
            for path in (left, right):
                checker.check_dump(path, cases)
                checked.append(path)
            require(left.read_bytes() == right.read_bytes(), f"scan instability: {directory.name} round {run}")
    for run in range(3):
        path = simulation / f"mailbox_sim_run_{run}.hex"
        checker.check_dump(path, cases)
        checked.append(path)

    log = (recent / "vivado.log").read_text(encoding="utf-8", errors="replace")
    require(re.search(r"^TARGET .*210241793374\s*$", log, re.M), "unexpected recorded JTAG target")
    require(re.search(r"^DEVICE xc7z010 IDCODE ", log, re.M), "missing recorded FPGA identity")
    require(re.search(r"^PROGRAM_END\s*$", log, re.M), "missing recorded programming completion")
    require(re.findall(r"^RESTART_RELEASED (\d+)\s*$", log, re.M) == ["0", "1", "2"], "recorded resets mismatch")
    require(re.findall(r"^ROUND_END (\d+) MATCH\s*$", log, re.M) == ["0", "1", "2"], "recorded completed rounds mismatch")
    require(re.findall(r"^DEMO_DONE (\d+)\s*$", log, re.M) == ["3"], "recorded session did not complete")
    for run in range(3):
        for scan in range(2):
            observed = {int(index): int(word, 16) for index, word in re.findall(
                rf"^PROGRESS {run} {scan} (\d+) ([0-9a-fA-F]{{8}})\s*$", log, re.M)}
            words = checker.read_dump(recent / f"run_{run}_scan_{scan}.hex")
            require(len(observed) == 104 and all(observed.get(i) == value for i, value in enumerate(words)),
                    f"HEX/log mismatch in round {run}, scan {scan}")

    binding = json.loads((ROOT / "evidence/publication/source_binding.json").read_text(encoding="utf-8"))
    for extension in ("bit", "ltx"):
        require(sha(ROOT / "board/runtime" / f"demo.{extension}") == binding[f"measured_{extension}_sha256"],
                f"measured {extension} hash mismatch")
    pdf = binding["final_pdf"]
    require(sha(ROOT / pdf["path"]) == pdf["sha256"], "final report PDF hash mismatch")
    for path in checked:
        print("VERIFY_PASS", path.relative_to(ROOT).as_posix(), "12 cases; 104 words")
    print("SAVED_EVIDENCE_PASS: 12 hardware scans in two dated three-round sessions; "
          "3 simulation mailboxes; CRC, stable pairs, recorded log words, BIT/LTX and final PDF")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, KeyError) as error:
        print("SAVED_EVIDENCE_FAIL:", error, file=sys.stderr)
        raise SystemExit(1)
