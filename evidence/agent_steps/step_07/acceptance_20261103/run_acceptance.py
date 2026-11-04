"""Independent acceptance for S07.

This script does not import the S07 execution self-check. It reads the Word
report, AI record, Skill scripts, license/third-party scope, staged candidate
and the accepted S06 evidence, then runs the executor self-check as one input.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
STEP = ROOT / "evidence" / "agent_steps" / "step_07"
ACC = STEP / "acceptance_20261103"
LOGS = ACC / "logs"
MAIN_XPR = ROOT.parents[1] / "RISCV_5pipeline.xpr"
CURRENT = ROOT / "migration" / "current.json"
WORD = ROOT / "report" / "design_report.docx"
AI_MD = ROOT / "report" / "ai_collaboration.md"
AI_QUOTES = ROOT / "report" / "ai_quotes.json"
SKILL = ROOT / "skill"
LICENSE_TXT = ROOT / "license" / "license.txt"
LICENSE_MD = ROOT / "license" / "license.md"
SCOPE = ROOT / "license" / "scope.json"
STAGED = ROOT / "delivery" / "source_candidate_s07_20261102"
SEALED = ROOT / "delivery" / "source_candidate_20261102_173954_d834d5"
S06_ACC = ROOT / "evidence" / "agent_steps" / "step_06" / "acceptance_20261102" / "acceptance.json"

CHECKS: list[dict] = []


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def check(name: str, ok: bool, detail: str = "") -> None:
    CHECKS.append({"name": name, "pass": bool(ok), "detail": detail})


def run(argv: list[str], log_name: str, timeout: int = 300) -> dict:
    LOGS.mkdir(parents=True, exist_ok=True)
    log = LOGS / log_name
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    env["PYTHONIOENCODING"] = "utf-8"
    try:
        proc = subprocess.run(argv, cwd=ROOT, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=timeout)
        code, out, err = proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as error:
        code = 124
        out = (error.stdout or "") if isinstance(error.stdout, str) else ""
        err = f"TIMEOUT {timeout}s\n" + ((error.stderr or "") if isinstance(error.stderr, str) else "")
    log.write_text(
        json.dumps({"argv": argv, "cwd": str(ROOT), "exit_code": code, "stdout": out, "stderr": err}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return {"code": code, "stdout": out, "stderr": err, "log": log.relative_to(ROOT).as_posix(), "sha256": sha256(log)}


def word_text() -> str:
    from docx import Document

    doc = Document(WORD)
    parts = [p.text for p in doc.paragraphs]
    for table in doc.tables:
        for row in table.rows:
            for cell in row.cells:
                parts.append(cell.text)
    return "\n".join(parts)


def compact(text: str) -> str:
    return re.sub(r"[\s*`]+", "", text)


def main() -> int:
    ACC.mkdir(parents=True, exist_ok=True)
    LOGS.mkdir(parents=True, exist_ok=True)

    # A. Path and prior-stage binding.
    try:
        check("workdir", Path.cwd().resolve() == ROOT.resolve(), f"cwd={Path.cwd()}")
        check("main_xpr", MAIN_XPR.is_file(), str(MAIN_XPR))
        current = load_json(CURRENT)
        build = (ROOT / current["build"]).resolve()
        check("current_build_inside_root", build.is_relative_to(ROOT.resolve()), str(build))
        check("current_demo_xpr", (build / "b" / "p" / "demo.xpr").is_file(), str(build / "b" / "p" / "demo.xpr"))
        s06 = load_json(S06_ACC)
        check("s06_independent_acceptance", s06.get("independent_acceptance") == "PASS", str(s06.get("independent_acceptance")))
        s07_result = load_json(STEP / "result.json")
        check("s07_execution_self_check", s07_result.get("status") == "SELF_CHECK_PASS", str(s07_result.get("status")))
        check("s07_self_check_keeps_pending", s07_result.get("independent_acceptance") == "PENDING", str(s07_result.get("independent_acceptance")))
    except Exception as error:
        check("path_binding", False, f"{type(error).__name__}: {error}")

    # B. Word report: structure, required content, no internal traces, numeric consistency.
    try:
        from docx import Document

        doc = Document(WORD)
        text = word_text()
        check("word_exists", WORD.is_file(), str(WORD))
        check("word_shape", len(doc.paragraphs) >= 150 and len(doc.tables) >= 10 and len(doc.inline_shapes) >= 3,
              f"paragraphs={len(doc.paragraphs)} tables={len(doc.tables)} images={len(doc.inline_shapes)}")
        headings = ["第1章", "第2章", "第3章", "第4章", "第5章", "第6章", "第7章", "第8章", "第9章", "第10章", "附录 A", "附录 B", "附录 C"]
        missing_headings = [h for h in headings if h not in text]
        check("word_sections", not missing_headings, f"missing={missing_headings}")
        required = ["2026 嵌入式 FPGA 大赛", "CRC-32/ISO-HDLC", "0xEDB88320", "0xFFFFFFFF", "6.765712",
                    "36/36", "12 组", "69653", "10295", "6130", "6560", "7694", "7892", "2.824", "2.961",
                    "50 MHz", "16 KiB", "64 KiB", "MIT", "单枪匹马", "范文轩", "李元宏"]
        missing = [s for s in required if s not in text]
        check("word_required_values", not missing, f"missing={missing}")
        forbidden = ["S01", "S02", "S03", "S04", "S05", "S06", "S07", "S08", "原设计", "原CPU", "原文档",
                     "160MHz", "160 MHz", "删除", "新增", "验收", "冻结", "哈希", "SHA-256", "evidence",
                     "candidate", "staging", "F01", "F02", "PENDING", "独立验收", "rework", "seal",
                     "source_candidate", "protected"]
        present = [s for s in forbidden if s in text]
        check("word_no_internal_traces", not present, f"present={present}")
        drive_hits = re.findall(r"[A-Za-z]:[\\/]", text)
        check("word_no_drive_paths", not drive_hits, f"hits={len(drive_hits)}")
        check("word_crc_scope", "CRC 用于差错检测" in text, "error-detection statement")

        perf = load_json(ROOT / "evidence/agent_steps/step_06/performance/results.json")
        row = next(r for r in perf["rows"] if r["run"] == 1 and r["case"] == 11)
        check("word_perf_4096_sw", "69653" in text and row["software_cycles"] == 69653, str(row["software_cycles"]))
        check("word_perf_4096_hw", "10295" in text and row["hardware_total_cycles"] == 10295, str(row["hardware_total_cycles"]))
        check("word_perf_speedup", "6.765712" in text and abs(row["speedup"] - 6.765711510441962) < 1e-12, f"{row['speedup']}")
        res = load_json(ROOT / "evidence/agent_steps/step_06/resources/results.json")
        for label, key in (("lut_base", ("baseline", "LUT")), ("lut_acc", ("accelerated", "LUT")),
                            ("ff_base", ("baseline", "FF")), ("ff_acc", ("accelerated", "FF")),
                            ("wns_base", ("baseline", "WNS_ns")), ("wns_acc", ("accelerated", "WNS_ns"))):
            value = res[key[0]][key[1]]
            check(f"word_res_{label}", str(value) in text, f"value={value}")
        # Layout fit.
        usable = doc.sections[0].page_width.inches - doc.sections[0].left_margin.inches - doc.sections[0].right_margin.inches
        bad_tables = []
        for i, table in enumerate(doc.tables):
            total = sum((c.width.inches if c.width else 0) for c in table.rows[0].cells)
            if total > usable + 0.05:
                bad_tables.append((i, total))
        bad_images = [(i, s.width.inches) for i, s in enumerate(doc.inline_shapes) if s.width.inches > usable + 0.05]
        check("word_layout_fit", not bad_tables and not bad_images, f"usable={usable:.3f}; tables={bad_tables}; images={bad_images}")
    except Exception as error:
        check("word_report", False, f"{type(error).__name__}: {error}")

    # C. AI record.
    try:
        quotes = load_json(AI_QUOTES)["quotes"]
        failures = []
        for quote in quotes:
            source = ROOT / quote["source"]
            if not source.is_file():
                failures.append(f"{quote['id']}: missing {source}")
                continue
            haystack = compact(source.read_text(encoding="utf-8", errors="replace"))
            if compact(quote["text"]) not in haystack:
                failures.append(f"{quote['id']}: not found in {quote['source']}")
        ai_text = AI_MD.read_text(encoding="utf-8")
        check("ai_quotes", not failures, f"{len(quotes)} quotes; failures={failures[:8]}")
        check("ai_record_files", AI_MD.is_file() and (STEP / "session_prompts.md").is_file(), "record and session prompts exist")
        check("ai_record_boundaries", "完整聊天导出" in ai_text and "模型内部推理" in ai_text, "states no full export/no internal reasoning")
        check("ai_session_prompts", all(s in (STEP / "session_prompts.md").read_text(encoding="utf-8") for s in ["P1", "P2", "P3"]), "P1-P3 present")
    except Exception as error:
        check("ai_record", False, f"{type(error).__name__}: {error}")

    # D. Skill.
    try:
        skill_text = (SKILL / "README.md").read_text(encoding="utf-8")
        check("skill_sections", all(s in skill_text for s in ["适用范围", "方法", "失败条件", "已验证效果", "可迁移"]), "scope/method/failure/effect/examples")
        self_test = run([sys.executable, "-B", "-X", "utf8", "skill/scripts/verify_mailbox.py", "--self-test"], "skill_self_test.log", 120)
        check("skill_self_test", self_test["code"] == 0 and "SELFTEST PASS" in self_test["stdout"], f"exit={self_test['code']}")
        capture = ROOT / "evidence/agent_steps/step_05/rework_r4/attempts/capture_20261102_183416_de2cae60"
        dumps = sorted(capture.glob("run_*_scan_*.hex"))
        argv = [sys.executable, "-B", "-X", "utf8", "skill/scripts/verify_mailbox.py"]
        for dump in dumps:
            argv.extend(["--dump", str(dump)])
        argv.extend(["--cases", "skill/examples/z7_crc_cases.json", "--json", str(ACC / "mailbox_verify.json")])
        real = run(argv, "skill_real_dumps.log", 120)
        check("skill_six_dumps", len(dumps) == 6 and real["code"] == 0 and real["stdout"].count("VERIFY_PASS") == 6, f"dumps={len(dumps)} exit={real['code']}")
        manifest = run([sys.executable, "-B", "-X", "utf8", "skill/scripts/check_manifest.py", "--root", str(STAGED), "--manifest", str(STAGED / "release_manifest.json"), "--json", str(ACC / "manifest_verify.json")], "skill_staged_manifest.log", 120)
        check("skill_staged_manifest", manifest["code"] == 0 and "MANIFEST_PASS" in manifest["stdout"], f"exit={manifest['code']}")
        check("skill_no_pynq_claim", ("未使用 PYNQ" in skill_text or "不使用 PYNQ" in skill_text) and "申报 PYNQ Skill 加分" not in skill_text.replace("不申报 PYNQ Skill 加分", ""), "PYNQ not claimed")
    except Exception as error:
        check("skill", False, f"{type(error).__name__}: {error}")

    # E. License and third-party scope.
    try:
        mit = LICENSE_TXT.read_text(encoding="utf-8")
        license_md = LICENSE_MD.read_text(encoding="utf-8")
        scope = load_json(SCOPE)
        check("license_mit_text", "MIT License" in mit and "单枪匹马" in mit and "范文轩" in mit and "李元宏" in mit, "MIT holder")
        check("license_decision", scope.get("decision_status") == "SELECTED_MIT" and scope.get("license_selected") == "MIT", str(scope.get("decision_status")))
        check("license_publication", scope.get("verification", {}).get("public_release_status") == "NOT_PUBLISHED"
              and scope.get("verification", {}).get("competition_submission_status") == "NOT_SUBMITTED", "not published/submitted")
        demo = ROOT / "src/core/demo_cpu.v"
        header = demo.read_text(encoding="utf-8", errors="replace")[:300]
        check("amd_header", "Advanced Micro Devices" in header and "Copyright" in header, header.splitlines()[:2])
        team = set(scope["team_owned"]["files"])
        amd = {item["path"] for item in scope["amd_generated_include_with_notice"]["files"] if isinstance(item, dict)}
        check("license_amd_not_team", "src/core/demo_cpu.v" not in team and "src/core/demo_cpu.v" in amd, "AMD file excluded from team license")
        vendor = scope["vendor_or_user_exclude"]["files"]
        check("license_vendor_excluded", len(vendor) >= 5, f"entries={len(vendor)}")
        check("license_no_root_file", not (ROOT / "LICENSE").is_file(), "root LICENSE is not a file")
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        check("readme_license_status", "Team-authored files: MIT" in readme and "has **not** been published" in readme, "README license/publication status")
    except Exception as error:
        check("license", False, f"{type(error).__name__}: {error}")

    # F. Staged candidate and functional unchanged.
    try:
        merge = load_json(STAGED / "s07_merge_manifest.json")
        manifest = load_json(STAGED / "release_manifest.json")
        check("stage_manifest_license", manifest.get("licensing_status") == "SELECTED_MIT" and manifest.get("functional_inputs_unchanged") is True, str(manifest.get("licensing_status")))
        check("stage_no_internal_docs", not (STAGED / "report/design_report.md").exists() and not (STAGED / "report/evidence_trace.json").exists() and not (STAGED / "evidence/agent_steps/step_07").exists(), "no internal report/trace in package")
        check("stage_word_present", (STAGED / "report/design_report.docx").is_file(), "design_report.docx")
        prefixes = ("src/", "firmware/", "sim/", "constraints/", "data/", "scripts/")
        sealed = {p.relative_to(SEALED).as_posix(): sha256(p) for p in SEALED.rglob("*") if p.is_file() and p.relative_to(SEALED).as_posix().startswith(prefixes)}
        staged = {p.relative_to(STAGED).as_posix(): sha256(p) for p in STAGED.rglob("*") if p.is_file() and p.relative_to(STAGED).as_posix().startswith(prefixes)}
        changed = sorted(n for n, h in sealed.items() if staged.get(n) != h)
        check("stage_functional_identical", not changed and len(sealed) == 76, f"files={len(sealed)} changed={changed[:8]}")
        check("stage_manifest_exists", (STAGED / "release_manifest.json").is_file() and merge.get("functional_inputs_unchanged") is True, "manifest")
    except Exception as error:
        check("staging", False, f"{type(error).__name__}: {error}")

    # G. Executor self-check as one input (not the acceptance authority).
    executor = run([sys.executable, "-B", "-X", "utf8", "evidence/agent_steps/step_07/s07_verify.py"], "s07_verify.log", 300)
    check("executor_self_check", executor["code"] == 0 and "S07_SELF_CHECK_PASS" in executor["stdout"], f"exit={executor['code']}")
    # H. Publication boundary in progress.
    progress = (ROOT / "docs/agent_progress.md").read_text(encoding="utf-8")
    check("publication_not_done", "未发布" in progress or "NOT_PUBLISHED" in progress, "progress says not published")

    failed = [c for c in CHECKS if not c["pass"]]
    status = "PASS" if not failed else "FAIL"
    acceptance = {
        "step": "S07",
        "date": "2026-11-03",
        "timezone": "Asia/Shanghai",
        "independent_acceptance": status,
        "blocking_findings": [c for c in failed],
        "nonblocking_findings": [
            {"id": "A01", "scope": "rendering", "description": "Word/LibreOffice is not installed; page-level visual rendering was not checked. Structural text/table/image checks passed."},
            {"id": "A02", "scope": "release-package", "description": "The S07 staging candidate still contains vendor/user documents for local evidence; license/scope and the staged manifest mark them excluded from public release. S08 must physically exclude them from the public package or obtain permission."},
            {"id": "A03", "scope": "protected-original", "description": "The main-project CPU design docx was not overwritten (protected S05/S06 input). The submission Word report is a separate clean document at report/design_report.docx."},
        ],
        "checks": {"total": len(CHECKS), "failed": len(failed)},
        "artifacts": {
            "word": "report/design_report.docx",
            "word_sha256": sha256(WORD),
            "ai_record": "report/ai_collaboration.md",
            "skill": "skill/README.md",
            "license": "license/license.txt",
            "staged": "delivery/source_candidate_s07_20261102",
            "executor_self_check": "evidence/agent_steps/step_07/s07_verify.py",
            "progress_update": "evidence/agent_steps/step_07/acceptance_20261103/progress_update.json",
            "progress_before": "evidence/agent_steps/step_07/acceptance_20261103/progress_before.md",
        },
        "acceptance_script": "evidence/agent_steps/step_07/acceptance_20261103/run_acceptance.py",
        "original_execution_result": "evidence/agent_steps/step_07/result.json",
        "S08_executed_by_this_acceptance": False,
        "S08_existing_record": "evidence/agent_steps/step_08/report.md",
    }
    (ACC / "checks.json").write_text(json.dumps({"checks": CHECKS}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (ACC / "acceptance.json").write_text(json.dumps(acceptance, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"S07_INDEPENDENT_ACCEPTANCE_{status} {len(CHECKS)} checks; {len(failed)} failures; word={sha256(WORD)[:12]}")
    for item in failed:
        print(f"FAIL {item['name']}: {item['detail']}")
    return 0 if not failed else 1


if __name__ == "__main__":
    raise SystemExit(main())
