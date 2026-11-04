#!/usr/bin/env python3
"""Check a release manifest against a directory tree.

Manifest formats accepted:
  {"files": {"relative/path": "<sha256>", ...}, ...}
  {"files": [{"path": "relative/path", "sha256": "<sha256>"}, ...], ...}

Checks: path safety, missing files, hash mismatch, unexpected extra files.
The manifest file itself is ignored when comparing the tree.

Exit codes: 0 pass, 1 mismatch, 2 argument/manifest error.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def load_manifest(path: Path) -> dict[str, str]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    files = data.get("files")
    if isinstance(files, dict):
        entries = files.items()
    elif isinstance(files, list):
        entries = [(item["path"], item["sha256"]) for item in files]
    else:
        raise ValueError("manifest must contain a 'files' object or list")
    out: dict[str, str] = {}
    for name, digest in entries:
        name = str(name).replace("\\", "/")
        if not name or name.startswith("/") or ".." in Path(name).parts:
            raise ValueError(f"unsafe manifest path: {name!r}")
        if not isinstance(digest, str) or len(digest) != 64:
            raise ValueError(f"invalid SHA-256 for {name!r}")
        if name in out:
            raise ValueError(f"duplicate manifest entry: {name!r}")
        out[name] = digest.lower()
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--allow-extra", action="store_true", help="do not fail on files not in manifest")
    parser.add_argument("--json", type=Path)
    args = parser.parse_args()

    root = args.root.resolve()
    manifest_path = args.manifest.resolve()
    if not root.is_dir():
        print(f"MANIFEST_FAIL: root is not a directory: {root}", file=sys.stderr)
        return 2
    if not manifest_path.is_file():
        print(f"MANIFEST_FAIL: manifest not found: {manifest_path}", file=sys.stderr)
        return 2

    try:
        expected = load_manifest(manifest_path)
    except (OSError, ValueError, KeyError) as error:
        print(f"MANIFEST_FAIL: {error}", file=sys.stderr)
        return 2

    missing: list[str] = []
    mismatch: list[str] = []
    for name, digest in sorted(expected.items()):
        target = (root / name).resolve()
        if not target.is_relative_to(root) or not target.is_file():
            missing.append(name)
            continue
        actual = sha256(target)
        if actual != digest:
            mismatch.append(f"{name}: expected {digest}, got {actual}")

    actual_files = {
        path.relative_to(root).as_posix()
        for path in root.rglob("*")
        if path.is_file() and ".git" not in path.relative_to(root).parts
    }
    manifest_relative = manifest_path.relative_to(root).as_posix() if manifest_path.is_relative_to(root) else None
    expected_names = set(expected)
    extra = sorted(actual_files - expected_names - ({manifest_relative} if manifest_relative else set()))

    passed = not missing and not mismatch and (args.allow_extra or not extra)
    summary = {
        "root": str(root),
        "manifest": str(manifest_path),
        "expected_files": len(expected),
        "actual_files": len(actual_files),
        "missing": missing,
        "mismatch": mismatch,
        "extra": extra,
        "allow_extra": bool(args.allow_extra),
        "pass": passed,
    }
    if args.json:
        args.json.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if passed:
        print(f"MANIFEST_PASS: {len(expected)} files, missing 0, mismatch 0, extra {len(extra)}")
        return 0
    print(
        f"MANIFEST_FAIL: missing {len(missing)}, mismatch {len(mismatch)}, extra {len(extra)}",
        file=sys.stderr,
    )
    for item in missing:
        print(f"  missing: {item}", file=sys.stderr)
    for item in mismatch:
        print(f"  mismatch: {item}", file=sys.stderr)
    for item in extra:
        print(f"  extra: {item}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
