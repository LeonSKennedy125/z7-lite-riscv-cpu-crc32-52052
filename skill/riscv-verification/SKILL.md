---
name: riscv-verification
description: 对六级 RV32I/Zicsr CPU 执行隔离模块仿真、严格写回比对及已有全核周期证据复核，区分功能测试、模型验证和负对照。适用于本项目及接口适配后的处理器验证。
---

# RISC-V CPU 自动化验证与测试

用途：把可重跑的刺激、独立期望、严格完成判定和输入版本绑定成验证证据。适用 ALU/寄存器/分支、前递与 load-use、CSR、复位和全核 trace 问题；不授予 RTL 修复、综合或上板权限。

## 输入

- 工程根目录、所选测试范围和独立新输出目录。
- 真实 RTL 与原 TB；模块测试需要 Icarus 或 XSim。历史周期复核还需要 `verification/check_phase09.py`、`phase09_reference.py` 及六个原始运行文件。
- 修改过 ISA、CSR、复位、访存延迟或层次路径时，先提供新的接口契约，不能直接沿用本项目预期。

## 执行

1. 读 [workflow.md](workflow.md)，选择模块仿真、寄存器 trace 或全核周期复核。先确认主线为 IF–ID–EX0–EX1–MEM–WB；RV32M/TAGE 文件存在不代表主核接入。
2. 用 `scripts/run_units.py --project-root <root> --out <new-dir>` 执行短时测试。只在新目录复制输入并编译；先确认依赖。对单个问题用 `--suite` 缩小范围。
3. 写回序列用 `scripts/compare_trace.py`，要求顺序、数量、PC、rd、值全部匹配。不能据此宣称 store、分支或所有指令退休通过。
4. 对已有全核记录用 `scripts/recheck_existing.py`。结果标为“历史周期 trace 重新比对”，不能标为新仿真。开发新用例时先写独立期望，再看 DUT；完整重跑应在隔离工程副本进行并说明耗时。
5. 读取汇总与日志，检查工具退出码、唯一完成汇总、非零检查数量、零失败和原输入哈希不变。故障按 [troubleshooting.md](troubleshooting.md) 定位，不修改原 TB/golden 使其通过。

## 输出与限制

输出 `summary.json/report.md` 或 `recheck.json`，附工具命令、输入 SHA256、原始日志、失败项和证据层级。`PASS` 必须带范围：模块仿真、CPU 侧模型、历史重比对或新全核仿真；板级结论需要独立实测。

本包新增契约 TB 不实例化实际 DTCM IP；原 CSR TB 的 IRQ 注入不代表主顶层中断已接通。原 `audit_unit_tb` 中 M/历史地址等断言具有范围/缺陷探针用途，不能直接并入正向功能总数。

编写测试和交给 Agent 的输入格式见 [prompt_templates.md](prompt_templates.md)；实际样例说明见 [examples/README.md](examples/README.md)。
