---
name: riscv-debug
description: 根据真实 RTL、Block Design 接线、日志和波形分析六级 RISC-V CPU 的数据通路与控制故障，定位前递、load-use、save、flush、CSR 和存储边界问题，并输出最小验证实验。
---

# RISC-V CPU 架构分析与故障排查

用途：以实际接口与最早分歧为依据缩小故障范围。适用于架构核对、仿真失败定位和设计说明审查；输入不足时输出待验证假设，不自动修改CPU设计。

## 输入

工程根目录和XPR、相关RTL/BD版本、程序/独立期望、最早错误日志，必要时提供带时间与采样边沿的信号表或波形。其他CPU需先建立自己的接口/阶段映射，不能套用本核层次名。

## 工作流

1. 用 `scripts/inspect_project.py --project-root <root> --out <new-dir>` 提取XPR文件集、真实BD组件/网络和RTL定义，核对文件是否接入主顶层。读 [architecture_analysis.md](architecture_analysis.md) 建立本核阶段图。
2. 从第一个失败的PC/周期/副作用倒查，不从最终错误寄存器猜因。按 [hazard_debugging.md](hazard_debugging.md) 检查前递、暂停、保存、冲刷及memory/CSR边界。
3. 把观察事实、独立期望、推断和缺失证据分开。每个假设至少给一个能区分它与其他假设的最小实验；保持正确golden、原RTL/XDC/TB不变。
4. 按 [prompt_templates.md](prompt_templates.md) 输出原因排序、源码位置、信号链、最小复现与后续授权边界。没有真实波形时不编造逐周期表。

## 输出

静态检查生成 `inventory.json/inventory.md`，包含路径、SHA256、文件集、模块定义和完整BD nets。诊断输出首个分歧、具体证据、候选原因和验证计划，尚未运行的实验明确标记。

参数：`--project-root` 和 `--out` 必填；`--xpr` 默认RISCV_5pipeline.xpr，可指定其他XPR。输出必须是新目录；0表示清单提取完成，2表示参数/解析失败。缺失引用列在输出中；生成物和手写源分别标注，不能据此自动修复路径或断言可编译。

限制：静态正则仅辅助定位module定义，不替代HDL解析/展开。M译码、预测器文件、CSR单元IRQ注入不能证明已接入主核；本Skill不宣称Cache/AXI/DMA、完整非法指令异常或板级通过。
