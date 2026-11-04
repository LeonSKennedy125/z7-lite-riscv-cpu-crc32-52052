# 构建工作流和参数

## 1. 工程与 MCP 检查

`mcp_inspect.py --out <new-dir>` 只列会话。`--url` 默认 `http://127.0.0.1:18090/mcp`；`--session <id>` 启用固定只读Tcl查询；`--timeout` 默认30秒。它执行initialize、tools/list、会话查询及固定的get_property/get_files，不提供任意Tcl参数，不创建/停止Vivado会话。结果写 `mcp.json/query.tcl`，返回0成功，1连接或查询失败，2参数错误。

```powershell
python -B -X utf8 skill/vivado-automation/scripts/mcp_inspect.py --out skill/artifacts/my_sessions
```

从响应复制当前session_id，再运行带 `--session` 的命令。不能复制旧文档中的会话ID假定永久有效。服务存在但无session时，在用户当前GUI的Tcl Console执行 `webserver -start -port 8088 -key none`，再用工具的真实 `vivado_connect` schema连接；新连接后只读确认工程/器件。此连接操作应由具备MCP工具的Agent执行，本脚本只检查已连接会话。

检查XPR、BD、顶层、COE/MIF、约束和工具路径。XPR保存位置或历史记录可能带旧盘符；以实际选择和实时查询为准。`synth_1` 的旧状态与 `repair_records/` 中手工non-project流程记录并非同一证据。

## 2. 生成计划

```powershell
python -B -X utf8 skill/vivado-automation/scripts/build.py --project-root . --vivado-bin E:/Vivado2026.1/2026.1/Vivado/bin --stage simulate --case mixed --seed 17 --delay 5 --out skill/artifacts/my_sim_plan
```

| 参数 | 行为 |
| --- | --- |
| --project-root | 必填，含XPR、srcs和verification；输入只读 |
| --vivado-bin | 必填，当前Vivado2026.1 bin，不修改原toolchain.json或全局PATH |
| --stage | simulate/synth/implement；默认synth。implement为新综合后布局布线 |
| --case / --seed / --delay | simulate使用，默认isa/1/0；case可选isa/mixed/irq，fixture必须已存在 |
| --out | 必填，不存在的新目录；保存计划、哈希、执行证据及副本 |
| --execute | 显式启动重流程；省略只生成计划，不启动Vivado |
| --timeout | 每个子进程超时秒数，默认7200；仅终止本脚本启动的进程树 |

计划模式也创建证据目录；实际执行要换一个新 `--out`。`plan.json`列出完整argv、工作目录和要求的完成标记，不将“计划生成成功”写成“构建成功”。

## 3. 获准后在隔离副本执行

向用户说明完整仿真可能需数分钟，综合/实现可能更久；本机当前任务没有获准运行这些重流程。确认后加 `--execute`，推荐新的短路径 `C:/fpga_skill_runs/cpu_01`。不要删除/重置用户已有目录以重用输出名。

副本仅复制 `RISCV_5pipeline.srcs/`、`verification/`、XPR，排除__pycache__、历史DCP/RQS和utils_1。副本XPR自身位置及toolchain路径被更新，utils_1历史引用从副本移除。没有复制原 `.gen/.runs/.cache/.sim` 或已有通过的build索引。函数性RTL/XDC/TB/COE不改。

- simulate：先 `phase10_r1_core.py build`（导出仿真脚本、重新编译/展开），再run指定case。原 `check_phase09.py` 完成严格独立模型比较，输出在副本 `repair_records/phase10/rework_R1/`。
- synth：复用 `implement_phase10_r1.tcl synth`，在副本刷新模块/IP输出后执行 `synth_design`，检查DTCM64个RAMB36E1及DOA_REG=1、意外latch，生成新综合DCP与资源报告。
- implement：上述synth后，独立工具进程执行route阶段的opt/place/phys_opt/route及原报告流程。保留脚本已有的DTCM寄存器结构保护，不新增例外、不降DRC级别。

wrapper每阶段要求退出码0且有对应完成标记；出现异常保留副本和日志，原输入再次计算哈希。它不调用write_bitstream/program_hw_devices，不运行旧CRC release或verify。返回0执行成功，1失败，2输入/参数错误。

**限制**：当前只验证过计划分支，真实重建分支尚未在本机跑通；其可靠性仍需首次获准重建确认。即使使用已有成熟Tcl，也不能把静态检查当工具执行成功。

## 4. 提取报告与整理日志

`analyze_reports.py --report-dir <reports> --out <new-dir>` 使用同目录的 `utilization.rpt/timing_summary.rpt/clocks.rpt`。可用 `--utilization/--timing/--clocks` 指定文件名。`--log <path>` 可重复，记录ERROR/FATAL/CRITICAL WARNING；ERROR/FATAL/缺失日志使检查失败，Critical Warning保留供进一步分类。

`--source-manifest <json> --project-root <root>` 校验相对路径到SHA256的非空清单，拒绝越界/缺失/不一致。该绑定只证明列出输入匹配，不自行证明清单覆盖全部依赖；新构建还必须保留真实编译清单、工具版本和来源。

`--require-io-delays` 将no_input_delay/no_output_delay非零纳入当前失败。不指定时只给片内时序结论，仍显式列系统待验证。返回0为所选检查范围满足，1为时序/绑定/日志/IO门槛失败，2为证据不完整或参数错误。

输出保留原报告日期、工具版本、Design State、各文件哈希、所有时钟约束与缺失字段。综合报告可解析资源，但未证明Routed会返回INCOMPLETE，不能签发布线通过。更多判断见 [resource_timing.md](resource_timing.md)。
