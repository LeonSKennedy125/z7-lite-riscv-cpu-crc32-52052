"""只读提取 XPR、BD 接线和 RTL 定义；静态清单不等于展开/综合结果。"""
import argparse
from datetime import datetime, timezone, timedelta
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET


def inspect(root, xpr):
    tree = ET.parse(xpr).getroot()
    aliases = {"$PPRDIR": root, "$PSRCDIR": root / (xpr.stem + ".srcs"),
               "$PGENDIR": root / (xpr.stem + ".gen"), "$PIPUSERFILESDIR": root / (xpr.stem + ".ip_user_files")}
    def resolve(raw):
        for key, value in aliases.items():
            raw = raw.replace(key, value.as_posix())
        p = Path(raw)
        return (p if p.is_absolute() else root / p).resolve()
    result = {"project": str(xpr), "saved_project_path": tree.get("Path"), "filesets": {}, "bd": {},
              "module_definitions": {}, "input_sha256": {}, "scope": "static_inventory_not_elaboration"}
    result["project_options"] = {o.get("Name"): o.get("Val") for o in tree.findall("./Configuration/Option")
                                 if o.get("Name") in ("Part", "BoardPart", "TargetLanguage", "TargetSimulator")}
    paths = {xpr}
    for fs in tree.findall(".//FileSet"):
        data = {"options": {o.get("Name"): o.get("Val") for o in fs.findall("./Config/Option")}, "files": []}
        for f in fs.findall("./File"):
            raw = f.get("Path", "")
            path = resolve(raw)
            generated = any(x in raw for x in ("$PGENDIR", "$PIPUSERFILESDIR"))
            data["files"].append({"reference": raw, "path": str(path), "exists": path.is_file(),
                                 "generated": generated, "attributes": [x.attrib for x in f.findall(".//Attr")]})
            if path.is_file() and path.suffix in (".v", ".sv", ".vh", ".svh", ".bd", ".xdc", ".xci"):
                paths.add(path)
        result["filesets"][fs.get("Name")] = data
    for p in sorted(paths):
        key = p.relative_to(root).as_posix() if p.is_relative_to(root) else str(p)
        result["input_sha256"][key] = hashlib.sha256(p.read_bytes()).hexdigest()
        if p.suffix in (".v", ".sv"):
            text = p.read_text(encoding="utf-8", errors="replace")
            text = re.sub(r"/\*.*?\*/|//[^\n]*", "", text, flags=re.S)
            for name in re.findall(r"\bmodule\s+(\w+)", text):
                result["module_definitions"].setdefault(name, []).append(key)
        elif p.suffix == ".bd":
            design = json.loads(p.read_text(encoding="utf-8-sig"))["design"]
            result["bd"][p.stem] = {"info": design.get("design_info"), "ports": design.get("ports"),
                "components": {n: {"vlnv": c.get("vlnv"), "reference": c.get("reference_info"), "parameters": c.get("parameters")}
                               for n, c in design.get("components", {}).items()}, "nets": design.get("nets")}
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--project-root", type=Path, required=True)
    p.add_argument("--xpr", default="RISCV_5pipeline.xpr", help="相对工程根目录的 XPR")
    p.add_argument("--out", type=Path, required=True, help="新的不存在目录")
    a = p.parse_args()
    if a.out.exists():
        p.error("输出目录已存在")
    root = a.project_root.resolve()
    try:
        result = inspect(root, (root / a.xpr).resolve())
    except (ValueError, OSError, ET.ParseError) as exc:
        print(str(exc))
        return 2
    result["timestamp"] = datetime.now(timezone(timedelta(hours=8))).isoformat()
    a.out.mkdir(parents=True)
    (a.out / "inventory.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    rows = []
    for name, bd in result["bd"].items():
        rows.append(f"\n## {name}\n\n| 实例 | VLNV | RTL 模块 |\n| --- | --- | --- |")
        rows.extend(f"| {n} | {c['vlnv']} | {(c['reference'] or {}).get('ref_name', 'IP')} |" for n, c in bd["components"].items())
    (a.out / "inventory.md").write_text("# 工程静态清单\n\n不能用文件存在证明功能已接入。缺失生成物不等同于缺失手写源文件。\n" + "\n".join(rows) + "\n", encoding="utf-8")
    missing = [x["reference"] for fs in result["filesets"].values() for x in fs["files"] if not x["exists"]]
    print(json.dumps({"part": result["project_options"].get("Part"), "bd": list(result["bd"]),
                      "module_definitions": len(result["module_definitions"]), "missing_references": missing}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
