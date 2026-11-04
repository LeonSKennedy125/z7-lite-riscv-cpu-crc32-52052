---
name: vivado-automation
description: 通过只读 MCP 查询核对 Vivado 工程，在隔离副本复用 R1 仿真与综合实现流程，并从原始报告提取资源、时钟和时序指标。适用于需要可追溯构建与证据边界的 AMD FPGA 工程。
---

# AMD Vivado 自动化构建与资源分析

用途：建立“实际输入→工具命令→原始报告→统一摘要”的链条。适用当前 RISC-V 工程构建及兼容格式报告分析；不包含烧录、许可证修改、原工程清理或自动RTL优化。

## 输入与条件

工程根目录、Vivado bin、新输出目录、执行阶段。MCP检查还需服务地址和当前session；报告解析需真实 utilization、timing_summary、clocks 报告，建议提供相对路径SHA256清单。

构建适配器复用本项目 `verification/implement_phase10_r1.tcl` 和 `phase10_r1_core.py`，目前限 Windows、Vivado 2026.1、`xc7k325tffg676-2`。通用报告解析器使用Python标准库，不依赖MCP或这颗CPU。其他工程必须替换专用适配器并重新验证。

## 执行步骤

1. 读 [workflow.md](workflow.md)，用 `scripts/mcp_inspect.py` 或XPR核对顶层/器件/版本。MCP中“没有会话”与“服务可用”是不同状态；手工GUI需开启Tcl webserver并连接后查询。
2. 先运行 `scripts/build.py` 生成计划，检查源目录、工具、阶段和输出。默认不调用Vivado。完整仿真/综合/实现可能较长，先说明耗时并取得用户同意。
3. 获准后加 `--execute` 并使用新目录；仅在副本更新路径、工具配置和历史utils引用，记录输入哈希。不能在当前GUI工程运行生成/综合命令或覆盖历史报告。
4. 用 `scripts/analyze_reports.py` 提取真实指标。按 [resource_timing.md](resource_timing.md) 区分综合/布线、约束频率/Fmax/实测频率、片内/IO约束范围。
5. 检查退出码、完成标记、缺失字段、源码绑定和原输入不变；按 [troubleshooting.md](troubleshooting.md) 整理错误，不降低DRC级别或虚构约束。

## 输出与限制

计划：plan.json与输入清单。执行：副本、逐阶段日志、result.json、原始报告。分析：analysis.json和report.md，缺失字段为null并返回INCOMPLETE。源绑定未知时明确UNVERIFIED；历史报告仍保留原日期，不冒充新构建。

WNS/TNS满足仅对已分析路径有效；报告正余量不能证明未约束IO、完整methodology/CDC/复位结构、板级电气或硬件运行正确。本轮重构建仅计划验证，不宣称综合/实现成功。
