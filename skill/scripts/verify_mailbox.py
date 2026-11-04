#!/usr/bin/env python3
"""Validate a fixed-layout MMIO accelerator mailbox dump against an independent CRC reference.

Design goals:
  * no third-party packages;
  * independent reference via zlib.crc32, never the DUT;
  * exact word count, header, case order, CRC equality and cycle sanity;
  * useful negative controls via --self-test;
  * reusable on another project by replacing the cases JSON and header.

Example:
  python -B -X utf8 verify_mailbox.py --dump run_0.hex --cases cases.json --json out.json
  python -B -X utf8 verify_mailbox.py --self-test
"""
from __future__ import annotations

import argparse
import json
import sys
import zlib
from pathlib import Path

SCHEMA = 1
DEFAULT_CASES = Path(__file__).resolve().parents[1] / "examples" / "z7_crc_cases.json"
MAX_CYCLES = 10_000_000


def parse_hex_word(line: str) -> int:
    text = line.strip()
    if not text:
        raise ValueError("empty line")
    if text.lower().startswith("0x"):
        text = text[2:]
    if not text or len(text) > 8:
        raise ValueError(f"not a 32-bit hex word: {line!r}")
    value = int(text, 16)
    if value < 0 or value > 0xFFFFFFFF:
        raise ValueError(f"word out of 32-bit range: {line!r}")
    return value


def read_dump(path: Path) -> list[int]:
    words: list[int] = []
    for number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip():
            continue
        try:
            words.append(parse_hex_word(line))
        except ValueError as error:
            raise ValueError(f"{path}:{number}: {error}") from None
    return words


def xorshift32(seed: int, length: int) -> bytes:
    value = seed & 0xFFFFFFFF
    out = bytearray()
    for _ in range(length):
        value ^= (value << 13) & 0xFFFFFFFF
        value &= 0xFFFFFFFF
        value ^= value >> 17
        value ^= (value << 5) & 0xFFFFFFFF
        value &= 0xFFFFFFFF
        out.append(value & 0xFF)
    return bytes(out)


def payload(case: dict) -> bytes:
    kind = case.get("kind", "xorshift32")
    length = int(case["length"])
    if kind == "zeros":
        return b"\x00" * length
    if kind == "ascii":
        data = str(case.get("data", "")).encode("ascii")
        if len(data) != length:
            raise ValueError(f"case {case.get('id')}: ascii length mismatch")
        return data
    if kind == "hex":
        data = bytes.fromhex(str(case["data_hex"]))
        if len(data) != length:
            raise ValueError(f"case {case.get('id')}: hex length mismatch")
        return data
    if kind == "xorshift32":
        return xorshift32(int(case.get("seed", "13579bdf"), 16), length)
    raise ValueError(f"case {case.get('id')}: unknown kind {kind!r}")


def load_cases(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if data.get("schema") != SCHEMA:
        raise ValueError(f"unsupported cases schema: {data.get('schema')!r}")
    header = data["header"]
    cases = data["cases"]
    if int(header["case_count"]) != len(cases):
        raise ValueError("header case_count does not match cases list")
    for index, case in enumerate(cases):
        if int(case["id"]) != index:
            raise ValueError(f"case ids must be 0..N-1 in order; got {case['id']} at {index}")
        reference = zlib.crc32(payload(case)) & 0xFFFFFFFF
        expected = int(str(case["expected_crc"]), 16)
        if reference != expected:
            raise ValueError(
                f"case {case['id']}: independent reference {reference:08x} != expected {expected:08x}"
            )
    return data


def header_words(header: dict) -> list[int]:
    return [
        int(str(header["magic"]), 16),
        int(header["version"]),
        int(header["clock_hz"]),
        int(header["ram_bytes"]),
        int(header["case_count"]),
        int(header.get("error_count", 0)),
        int(header["total_words"]),
        int(header["executed_checks"]),
    ]


def validate(words: list[int], cases_data: dict) -> dict:
    header = cases_data["header"]
    cases = cases_data["cases"]
    total_words = int(header["total_words"])
    if len(words) != total_words:
        raise ValueError(f"mailbox must contain exactly {total_words} words; got {len(words)}")
    expected_header = header_words(header)
    actual_header = words[:8]
    if actual_header != expected_header:
        raise ValueError(
            "invalid mailbox header: expected "
            + " ".join(f"{value:08x}" for value in expected_header)
            + " got "
            + " ".join(f"{value:08x}" for value in actual_header)
        )
    rows = []
    for case in cases:
        case_id = int(case["id"])
        start = 8 + 8 * case_id
        record = words[start : start + 8]
        reference = zlib.crc32(payload(case)) & 0xFFFFFFFF
        expected = int(str(case["expected_crc"]), 16)
        labels = [
            "case_id",
            "length",
            "expected_crc",
            "software_crc",
            "hardware_crc",
            "software_cycles",
            "hardware_total_cycles",
            "engine_session_cycles",
        ]
        wanted = [
            case_id,
            int(case["length"]),
            expected,
            reference,
            reference,
        ]
        for label, wall, want in zip(labels[:5], record[:5], wanted):
            if wall != want:
                raise ValueError(
                    f"case {case_id}: {label} mismatch: got {wall:08x}, want {want:08x}"
                )
        software, hardware, engine = record[5], record[6], record[7]
        if not (0 < software < MAX_CYCLES):
            raise ValueError(f"case {case_id}: invalid software_cycles {software}")
        if not (0 < hardware < MAX_CYCLES):
            raise ValueError(f"case {case_id}: invalid hardware_total_cycles {hardware}")
        if not (0 <= engine <= hardware):
            raise ValueError(
                f"case {case_id}: engine_session_cycles {engine} not in 0..{hardware}"
            )
        rows.append(
            {
                "case": case_id,
                "bytes": int(case["length"]),
                "expected_crc": f"{expected:08x}",
                "software_crc": f"{record[3]:08x}",
                "hardware_crc": f"{record[4]:08x}",
                "software_cycles": software,
                "hardware_total_cycles": hardware,
                "engine_session_cycles": engine,
                "speedup": software / hardware,
            }
        )
    return {"header": [f"{value:08x}" for value in actual_header], "rows": rows}


def check_dump(path: Path, cases_data: dict) -> dict:
    words = read_dump(path)
    result = validate(words, cases_data)
    result["dump"] = str(path)
    result["words"] = len(words)
    result["pass"] = True
    return result


def self_test() -> int:
    cases_data = load_cases(DEFAULT_CASES)
    header = cases_data["header"]
    cases = cases_data["cases"]
    words = header_words(header)
    for case in cases:
        reference = zlib.crc32(payload(case)) & 0xFFFFFFFF
        length = int(case["length"])
        software = max(21, 17 + 17 * length)
        hardware = max(55, 55 + 3 * length)
        engine = max(0, hardware - 50)
        words.extend(
            [int(case["id"]), length, reference, reference, reference, software, hardware, engine]
        )
    base = validate(words, cases_data)
    print(f"SELFTEST base PASS: {len(base['rows'])} cases, {len(words)} words")

    mutations = {
        "truncated": words[:-1],
        "bad_magic": [0x43524330] + words[1:],
        "bad_hardware_crc": words[:],
        "zero_cycles": words[:],
    }
    mutations["bad_hardware_crc"][8 + 8 * 2 + 4] ^= 1
    mutations["zero_cycles"][8 + 8 * 2 + 6] = 0
    failures = 0
    for name, mutated in mutations.items():
        try:
            validate(mutated, cases_data)
        except ValueError as error:
            print(f"SELFTEST negative {name}: PASS ({error})")
        else:
            failures += 1
            print(f"SELFTEST negative {name}: FAIL (accepted)", file=sys.stderr)
    if failures:
        print(f"SELFTEST FAIL: {failures} negative control(s) accepted", file=sys.stderr)
        return 1
    print("SELFTEST PASS: base + 4 negative controls")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", action="append", default=[], help="mailbox HEX file; repeatable")
    parser.add_argument("--cases", type=Path, default=DEFAULT_CASES, help="case/header JSON")
    parser.add_argument("--json", type=Path, help="write summary JSON")
    parser.add_argument("--self-test", action="store_true", help="run built-in positive/negative tests")
    args = parser.parse_args()

    if args.self_test:
        return self_test()
    if not args.dump:
        parser.error("--dump is required unless --self-test is used")

    try:
        cases_data = load_cases(args.cases)
        reports = [check_dump(Path(path), cases_data) for path in args.dump]
    except (OSError, ValueError, KeyError) as error:
        print(f"VERIFY_FAIL: {error}", file=sys.stderr)
        return 1

    summary = {
        "schema": SCHEMA,
        "cases": str(args.cases),
        "dumps": reports,
        "pass": True,
        "case_count": len(cases_data["cases"]),
        "dump_count": len(reports),
    }
    if args.json:
        args.json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for report in reports:
        print(
            f"VERIFY_PASS {report['dump']}: {len(report['rows'])} cases, "
            f"{report['words']} words, CRC equality checked"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
