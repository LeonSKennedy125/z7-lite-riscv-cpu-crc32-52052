# 公开发布说明（2026-11-04）

本文件保留真实开发记录和纠错过程。记录中的旧版 Word 章节号属于原记录时点；当前最终报告见 [design_report_official_template.pdf](design_report_official_template.pdf)。本次发布整理及复查记录见 [publication_notes.md](../docs/publication_notes.md)。

---

# AI 协作与纠错记录（S07 定稿）

- 日期：2026-11-02（Asia/Shanghai）
- 范围：2026 嵌入式 FPGA 大赛 · FPGA 创新设计赛道 · AMD 平台 · 自选赛题（初级组）
- 作品：Z7-LITE 7010 六级 RV32I＋Zicsr CPU + CRC32 加速演示
- 记录性质：**可见交互摘录 + 工程事实 + 证据索引**，不是完整聊天导出，不含模型内部推理、系统提示词或未保存的隐藏对话。

---

## 0. 记录方法与边界

本工作区保存了各阶段的用户提示词、执行报告、验收报告、命令日志、哈希和失败记录，但**没有保存完整聊天记录**，也没有在阶段日志中系统记录模型名称/版本。因此本记录：

1. 只收录工程中可见、可定位的提示词文本和保存到文件的回答摘录。
2. 对每条摘录给出源文件；`s07_verify.py` 会检查摘录文本确实出现在源文件中。
3. 不补写“模型当时应该想什么”，不把报告文字反推成模型内部推理。
4. 不声称覆盖全部会话；未保存的部分留空，不伪造完整导出。
5. 模型名称/版本未在日志中固定，故本记录**不推断**具体模型；如提交要求声明模型，应由队伍按实际使用情况补充，不能由本记录猜测。

---

## 1. 用户提示词（可见、真实）

### 1.1 S07 阶段任务

> 请执行提交步骤S07：设计报告、AI协作记录、Skill与许可证整理，只执行本步。

来源：`docs/agent_prompts/step_07_materials.md` 第 1 行；`evidence/agent_steps/step_07/session_prompts.md` P1。

### 1.2 设计报告底稿要求（会话内追加）

> 设计报告你在"D:\vivado2026.1_project\160MHZ CPURISCV\RISCV_5pipeline.srcs\sources_1\CPU设计文档.docx"的基础上修改，删除没有真正接入的部分，再增添新写的东西，比如crc

来源：本会话用户消息（2026-11-02）；`evidence/agent_steps/step_07/session_prompts.md` P2。

### 1.3 赛事背景修正（会话内追加）

> 背景啥的改成本次嵌入式FPGA大赛 FPGA创新设计赛道amd平台，自选赛题初级组

来源：本会话用户消息（2026-11-02）；`evidence/agent_steps/step_07/session_prompts.md` P3。

### 1.4 共同范围约束

> 当前只执行用户指定的提交步骤，不自动执行下一步，不调用其他agent，除非用户另行明确授权。

来源：`docs/agent_prompts/common.md` 第 21 行。

### 1.5 阶段提示词摘录

| 阶段 | 可见提示词摘录 | 源文件 |
|---|---|---|
| S03 | “不能用Kintex-7的160MHz结果替代。” | `docs/agent_prompts/step_03_implementation.md` 第 29 行 |
| S05 | “准确记录复位方法，不写成按键或断电。” | `docs/agent_prompts/step_05_hardware.md` 第 27 行 |
| S06 | “没有真实采集时只列前置缺口，不能以simulation生成实测结论。” | `docs/agent_prompts/step_06_measurement.md` 第 17 行 |
| S07 | “许可证决策待用户时明确本项未完成，不悄悄选定。” | `docs/agent_prompts/step_07_materials.md` 第 29 行 |

这些提示词不是“事后总结的理想提示词”，而是工程中保存的、实际驱动阶段的文本。

---

## 2. 助手可见回答（保存到工程的摘录）

### 2.1 关于真实测量与功耗

> 没有真实功耗测量，功耗及实测能效字段为 null，不使用工具估算冒充能效结论。

来源：`evidence/agent_steps/step_06/report.md` 第 70 行。

### 2.2 关于资源对照口径

> 报告 **全SoC净增430 LUT、198 FF**，不是把它宣称为纯CRC计算数据通路的面积；层次差值不归一化，也不隐藏那1个Hub LUT差异。

来源：`evidence/agent_steps/step_06/report.md` 第 65 行。

### 2.3 关于硬件证据的真实性限制

> 硬件 HEX 与仿真 HEX 完全相同：确定性固件下这是预期结果，也证明功能一致；但 HEX 本身不含硬件独有熵，不能单独证明来源。真实性依赖 Vivado2026.1 会话日志、约 18ms/字的真实事件时序、封存采集脚本与用户指示灯观察。

来源：`evidence/agent_steps/step_05/acceptance_20261102/report.md` 第 67 行。

### 2.4 关于不把自检当验收

> 未运行 CPU 功能回归、综合、实现、干净重建或真实硬件测试。停在 S01，独立验收通过前不进入 S02。

来源：`docs/agent_progress.md` 第 52 行（S01 历史段）。

### 2.5 关于原文档中的 AI 说明

> 本作品使用AI的情景仅限于代码排障与文档优化，没有使用AI进行设计和直接生成文档。文档AI优化占比大约10%左右。

来源：`evidence/agent_steps/step_07/input_extract/cpu_design_text.txt` 第 378 行（原 CPU 设计文档的“AI使用说明”）。该说明属于原文档阶段，不代表本次 CRC 演示阶段的协作方式；本记录不沿用“10%”这一无法复核的比例。

---

## 3. 工具反馈与真实失败

| 编号 | 工具反馈/现象 | 发生位置 | 实际处理 | 证据 |
|---|---|---|---|---|
| T01 | `write_bitstream` 打印 bitgen 成功后不返回；两次独立导出超时 240 秒 | S03 原交付 | 定位遥测收集热点；仅本次进程 `debug.enable_data_collection=0`，从源码重跑综合/实现/bitgen；原失败保留 | `docs/agent_progress.md` S03 历史段；`step_03/rework_r1/before/` |
| T02 | `Designutils 20-1474`：7 位 `read_index` 在 HEX 下要求 2 字符，脚本写单字符 `0` | S05 首次真实采集 | 改为 `[format %02x 0]`；失败发生在任何复位/扫描之前；新建 r4 重新封存并采集 | `evidence/agent_steps/step_05/report.md` 第 24 行；`rework_r3/attempts/capture_20261102_182943_15e90a91/` |
| T03 | `Chipscope16-302`：临时路径 149 字符超过 146 字符限制 | 早期干净目录 dbg_hub 生成 | 复用稳定 SUBST 盘符；退出后保留映射；不把它误判为 RTL/许可证错误 | `docs/ai_collaboration.md` 第 27 行；`c3519/evidence/implement.console.log` |
| T04 | `USF-XSim-11`：读取 `xsim.ini` 失败 | S02 故障仿真 / 预编译 IP 库重映射 | 设置 `sim.use_ip_compiled_libs=0`，本地编译 IP 模型；保留原失败 | `docs/s02_regression.md` 第 32 行；S02 日志 |
| T05 | 自动生成仿真 Tcl 为 0 字节，工具退出 0 但未执行测试 | S02 | 检查器拒绝缺终止标记；改用 `launch_simulation -scripts_only` + 固定 `run_sim.tcl` | `docs/s02_regression.md` 第 30 行 |
| T06 | IP COE 读回变成相对路径 | 早期 project 检查 | 按 IP 目录解析相对路径；配置未丢失 | `docs/ai_collaboration.md` 第 24 行 |
| T07 | RAM 读回低半字 | 早期 memory 测试 | 测试台误用 ISA funct3 当内部 `Load_Ctrl`；改用 `LOAD_LW` 宏，保留正确期望 | `docs/ai_collaboration.md` 第 25 行；`riscv_define.vh` |
| T08 | 初始配置电压假定 3.3 V，后误判 GND/1.8 V | R11 原理图核对 | 逐页核对；ES1 配套资料确认 VCCO/3.3；旧 GND/1.8 构建作废，不再下载 | `docs/hardware_baseline_zh.md`；S05 验收报告 |
| T09 | 资源检查器误要求 Hub LUT 绝对相同 | S06 | 披露 1 LUT 差异，不隐藏；报告全 SoC 净差 | `evidence/agent_steps/step_06/report.md` 第 85 行 |
| T10 | 资源 HTML 标题/表头出现字面 `???` | S06 F01 | 独立验收列为非阻断展示缺陷；本报告用正确 Markdown/JSON；S08 修复/重生成 | `evidence/agent_steps/step_06/acceptance_20261102/report.md` F01 |

---

## 4. 自我纠错轨迹

### 4.1 S03：不把工具挂起当成 RTL 成功

- 观察：`write_bitstream` 打印成功后进程不返回，输出重试超时。
- 错误做法（已避免）：因工具打印成功就宣布交付完成。
- 修正：先定位遥测收集热点，确认 GOLD 许可证后仅在本进程设置 `debug.enable_data_collection=0`；从源码重跑综合/优化/布局/物理优化/布线/bitgen；主工具退出 0，implement 回执 PASS。
- 保留：原失败交付、超时日志和 `before/` 记录；没有删除失败或放宽门槛。
- 证据：`docs/agent_progress.md`（S03 历史段）、`step_03/rework_r1/`。

### 4.2 S05：主机脚本错误不等于 DUT 失败

- 观察：首次真实采集在写 `read_index` 初值时被 Vivado 拒绝（`Designutils 20-1474`），尚未复位/扫描。
- 错误做法（已避免）：把这次失败归因于 RTL/CRC/板卡，或直接换一个“好看”的 attempt。
- 修正：确认 7 位 HEX 探针要求 2 字符，改为 `[format %02x 0]`；r4 重新封存，43 项主机控制通过；真实采集 3 次复位、6 次扫描、36/36。
- 保留：r3 失败 attempt、tool_run、events、stdout/vivado.log；未删除。
- 证据：`evidence/agent_steps/step_05/report.md` 第 24–26 行；`rework_r3/attempts/`；`rework_r4/`。

### 4.3 S06：资源对照不能把“控制变体”说成“纯加速器面积”

- 观察：资源基线移除了 CRC 字节变换、状态/结果/会话寄存器、背压/错误逻辑；固件 `hardware_crc()` 改为软件回退；ROM 内容变化。
- 错误做法（已避免）：把 +430 LUT/+198 FF 直接写成“CRC 引擎面积”。
- 修正：报告全 SoC 净差，列出两处源码差异、CPU/peripheral/Hub 层次差值，明确基线不是功能等价外设、基线固件未上板。
- 证据：`evidence/agent_steps/step_06/report.md` §“必须披露的对照差异”；S06 验收报告。

### 4.4 S06：展示缺陷与数据正确性分开

- 观察：资源 HTML 出现 `???`；4096 字节正文舍入为 6.765711×，表格为 6.765712×。
- 修正：S06 独立验收列为 F01/F02 非阻断；本报告统一使用 6.765712×，资源口径用 Markdown/JSON；S08 应修复/重生成展示件。
- 证据：`evidence/agent_steps/step_06/acceptance_20261102/report.md`。

### 4.5 S07：按用户要求改写原设计文档

- 观察：原 CPU 设计文档包含未接入的 RV32M/TAGE/ITTAGE、未复现的官方/随机测试、OS/IPC 宣称；本次赛事背景与原文不同。
- 修正：以原文档为技术底稿，保留实际接入的六级流水线、前递、BRAM、CSR；删除未接入/未复现完成宣称；新增 CRC32、MMIO/JTAG、7010 50 MHz、实测/资源/复现；背景改为本次“嵌入式 FPGA 大赛 · FPGA 创新设计赛道 · AMD 平台 · 自选赛题（初级组）”。
- 证据：`report/design_report.docx` §1.4、§3.7、§7；本记录 P2/P3。

---

## 5. 智能体工作流设计

```text
用户阶段提示词 + common.md
        ↓
路径/输入核验（工作目录、主 XPR、CRC 根、migration/current.json）
        ↓
只执行本阶段 → 实际命令 → 退出码/双流日志/输入哈希
        ↓
执行自检（SELF_CHECK_*）→ 失败保留 → 修正工具/脚本（不改正确期望）
        ↓
独立验收（另建脚本/另存 run）→ PASS/FAIL → 进度登记
        ↓
下一阶段只在用户明确指定时启动
```

关键设计：

- **单步授权**：不自动进入下一步；S07 不调用子 agent。
- **证据门控**：没有当前输入对应的命令/日志/哈希，就不能沿用旧 PASS。
- **失败保留**：失败 attempt、超时、0 字节 Tcl、HEX 格式错误都保留，不删除、不挑选。
- **独立验收**：执行 agent 只写自检；独立验收另建脚本、另存 run、另行结论。
- **范围保护**：主工程 RTL/BD/IP/XDC/XPR 只读；CRC 只写 `board/z7_lite_7010_crc`。
- **诚实边界**：未测功耗、未复现官方测试、未上板的部分明确写未完成。

---

## 6. 从协作到 Skill

本工程的 Skill 不是“作品宣传页”，而是把上表失败提炼成可复用检查：

| 失败/观察 | Skill 规则 | 可迁移场景 |
|---|---|---|
| 工具退出 0 但 Tcl 为 0 字节 | 必须检查终止标记、日志和输入哈希，不能只看退出码 | 任何 Vivado/XSim 批处理 |
| `Designutils 20-1474` | 探针 HEX 宽度/格式先校验，再复位/扫描；主机失败不归因 DUT | 任何 VIO/ILA 采集 |
| `Chipscope16-302` | Windows 调试核路径限制；用稳定短 SUBST 盘符 | Vivado 调试核/长路径 |
| `USF-XSim-11` | 预编译 IP 库映射失败时用本地 IP 模型 | XSim + IP 仿真 |
| 资源基线差异 | 报告全 SoC 净差，披露控制变体，不冒充纯加速器面积 | 任何软硬件对照 |
| 短输入低于 1× | 保留全部数据，不选最快轮、不裁剪 | 任何加速器性能评估 |
| 仿真 HEX = 硬件 HEX | 不把 HEX 当硬件熵；用会话日志/事件时序/用户观察补强 | 任何确定性固件板级采集 |

完整 Skill 见 `skill/README.md`；校验脚本见 `skill/scripts/`；示例见 `skill/examples/`。边界：适用于同步 valid/ready MMIO、单发射顺序核、无 DMA/AXI；不适用于乱序/多核/Cache 一致性/AXI 多笔未完成事务；不申报 PYNQ Skill 加分。

---

## 7. 本记录不包含什么

- 不包含完整聊天导出、系统提示词、工具原始 JSON 全文或模型内部推理。
- 不包含未保存的会话内容；没有的对话不补造。
- 不包含模型名称/版本的推断；阶段日志未记录，故不声明。
- 不把报告中的“助手回答”说成模型逐字输出；它们是保存到工程的可见文本，可能经过编辑/汇总。
- 不把失败记录删除或改写；原始失败保留在原路径。

---

## 8. 证据索引

| 内容 | 路径 |
|---|---|
| 阶段提示词 | `docs/agent_prompts/step_01..08.md`；`docs/agent_prompts/common.md` |
| 本会话可见提示词 | `evidence/agent_steps/step_07/session_prompts.md` |
| S01 进度与失败保留 | `docs/agent_progress.md`；`evidence/agent_steps/step_01/` |
| S02 仿真/故障/负对照 | `evidence/agent_steps/step_02/`；`docs/s02_regression.md` |
| S03 bitstream 失败与 R1 | `evidence/agent_steps/step_03/`；`rework_r1/before/` |
| S04 干净重建 | `evidence/agent_steps/step_04/` |
| S05 真实采集与失败 attempt | `evidence/agent_steps/step_05/`；`report/hardware/` |
| S06 性能/资源/冻结/验收 | `evidence/agent_steps/step_06/` |
| S07 本记录与校验 | `evidence/agent_steps/step_07/`；`report/ai_quotes.json` |
| 原 CPU 设计文档 | 主工程 `RISCV_5pipeline.srcs/sources_1/CPU设计文档.docx`；副本 `evidence/provenance/cpu_design.docx` |
| 原文档文本摘录 | `evidence/agent_steps/step_07/input_extract/cpu_design_text.txt` |
