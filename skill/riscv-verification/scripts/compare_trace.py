"""严格比对寄存器写回序列；不据此宣称全部指令退休或板级通过。"""
import argparse
import json
from pathlib import Path
import re


def records(path, fmt):
    lines = Path(path).read_text(encoding="utf-8-sig").splitlines()
    result, declared = [], None
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if fmt == "triples" and declared is None and not result and re.fullmatch(r"\d+", line):
            declared = int(line)
            continue
        if fmt == "wb-log":
            if not line.startswith("WRITE"):
                continue
            match = re.fullmatch(r"WRITE\s*\|\s*PC=([0-9a-fA-F]{1,8})\s+x(\d+)=([0-9a-fA-F]{1,8})", line)
        elif fmt == "canonical":
            match = re.fullmatch(r"PC\(([0-9a-fA-F]{1,8})\)\|x(\d+)\(([0-9a-fA-F]{1,8})\)", line)
        else:
            match = re.fullmatch(r"([0-9a-fA-F]{1,8})\s+(\d+)\s+([0-9a-fA-F]{1,8})", line)
        if not match:
            raise ValueError(f"{path}:{number}: 格式错误或含 X/Z: {line}")
        pc, rd, value = match.groups()
        if not 1 <= int(rd) <= 31:
            raise ValueError(f"{path}:{number}: 写回记录只允许 x1..x31")
        result.append((int(pc, 16), int(rd), int(value, 16)))
    if not result:
        raise ValueError(f"{path}: 写回序列为空")
    if declared is not None and declared != len(result):
        raise ValueError(f"{path}: 声明 {declared} 条，实际 {len(result)} 条")
    return result


def compare(expected, actual):
    for index in range(max(len(expected), len(actual))):
        a = expected[index] if index < len(expected) else None
        b = actual[index] if index < len(actual) else None
        if a != b:
            return {"trace_equal": False, "first_mismatch": index + 1,
                    "expected": a, "actual": b,
                    "expected_count": len(expected), "actual_count": len(actual)}
    return {"trace_equal": True, "matched": len(expected), "scope": "register_writes_only"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected", type=Path, required=True)
    parser.add_argument("--actual", type=Path, required=True)
    for name in ("expected", "actual"):
        parser.add_argument(f"--{name}-format", choices=("triples", "canonical", "wb-log"), default="triples")
    args = parser.parse_args()
    try:
        result = compare(records(args.expected, args.expected_format), records(args.actual, args.actual_format))
    except (ValueError, OSError) as exc:
        print(json.dumps({"trace_equal": False, "error": str(exc)}, ensure_ascii=False))
        return 2
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["trace_equal"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
