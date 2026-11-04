"""通过 Vivado MCP 执行固定只读查询；不提供任意 Tcl 执行入口。"""
import argparse
from datetime import datetime, timezone, timedelta
import json
from pathlib import Path
import urllib.request

QUERY = ("list version [version -short] project [current_project] "
         "directory [get_property DIRECTORY [current_project]] "
         "part [get_property PART [current_project]] top [get_property TOP [current_fileset]] "
         "simulation_top [get_property TOP [get_filesets sim_1]] "
         "synthesis_files [llength [get_files -compile_order sources -used_in synthesis]] "
         "synth_status [get_property STATUS [get_runs synth_1]] "
         "impl_status [get_property STATUS [get_runs impl_1]]")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--url", default="http://127.0.0.1:18090/mcp")
    p.add_argument("--session", help="来自 vivado_list_sessions 的 session_id；省略时仅列会话")
    p.add_argument("--out", type=Path, required=True, help="新的不存在目录")
    p.add_argument("--timeout", type=int, default=30)
    a = p.parse_args()
    if a.out.exists():
        p.error("输出目录已存在")
    headers = {"Content-Type": "application/json", "Accept": "application/json, text/event-stream"}
    identifier, transcript = 0, []
    def rpc(method, params=None, notification=False):
        nonlocal identifier
        identifier += 1
        body = {"jsonrpc": "2.0", "method": method}
        if not notification:
            body["id"] = identifier
        if params is not None:
            body["params"] = params
        request = urllib.request.Request(a.url, json.dumps(body).encode("utf-8"), headers)
        with urllib.request.urlopen(request, timeout=a.timeout) as response:
            sid = response.headers.get("Mcp-Session-Id")
            if sid:
                headers["Mcp-Session-Id"] = sid
            text = response.read().decode("utf-8")
        if text.startswith("event:") or text.startswith("data:"):
            data = [line[5:].strip() for line in text.splitlines() if line.startswith("data:")]
            parsed = next((json.loads(line) for line in reversed(data) if line), None)
        else:
            parsed = json.loads(text) if text else None
        transcript.append({"request": body, "response": parsed})
        if parsed and ("error" in parsed or parsed.get("result", {}).get("isError")):
            raise RuntimeError(str(parsed))
        return parsed
    result = {"pass": False, "scope": "live_readonly_mcp_query", "timestamp": datetime.now(timezone(timedelta(hours=8))).isoformat()}
    try:
        initialized = rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "riscv-skill-inspector", "version": "1.0"}})
        headers["MCP-Protocol-Version"] = initialized["result"]["protocolVersion"]
        rpc("notifications/initialized", notification=True)
        result["sessions"] = rpc("tools/call", {"name": "vivado_list_sessions", "arguments": {}})
        if a.session:
            # Inspect real runtime schema before constructing the fixed query call.
            catalog = rpc("tools/list", {})
            names = [x["name"] for x in catalog["result"]["tools"]]
            if "vivado_execute" not in names:
                raise RuntimeError("服务没有提供 vivado_execute")
            response = rpc("tools/call", {"name": "vivado_execute", "arguments": {
                "session_id": a.session, "command": QUERY, "mode": "webserver", "capture_log": False}})
            blocks = response["result"].get("content", [])
            payloads = [json.loads(b["text"]) for b in blocks if b.get("type") == "text"]
            if not payloads or any(x.get("exit_code", 1) != 0 for x in payloads):
                raise RuntimeError("Vivado 查询未成功")
            result["query"] = payloads
        result["pass"] = True
    except Exception as exc:
        result["error"] = str(exc)
    a.out.mkdir(parents=True)
    (a.out / "mcp.json").write_text(json.dumps({**result, "transcript": transcript}, ensure_ascii=False, indent=2), encoding="utf-8")
    (a.out / "query.tcl").write_text(QUERY + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
