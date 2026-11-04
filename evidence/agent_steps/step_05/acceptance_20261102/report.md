# S05 独立验收报告

日期：2026-11-02，Asia/Shanghai。

**结论：S05 独立验收通过（PASS）。** 验收对象为 ES1 配置修正后的新构建、真实 JTAG 下载与三次 VIO 辅助硬件复位采集。未执行 S06—S08，未修改主工程，未重写历史执行记录。

## 验收对象

| 项目 | 值 |
|---|---|
| 当前指针 | `migration/current.json`，SHA-256 `d7dba293dc1b088890c194c84bd745c69b85684a10ad420f44e9be65b4038a9c`，`workflow=S05_ES1_R4` |
| 封存 | `evidence/agent_steps/step_05/rework_r4/seal.json`，SHA-256 `a9ba2f5f7dfbf09a74dffe1d77919c1332b215b47e3cfba9e5cedf4fe1aa7a91` |
| 构建 | `local_builds/s05_es1_20261102_173954_d834d5` |
| 源码包 | `delivery/source_candidate_20261102_173954_d834d5.zip`，SHA-256 `29215665782df967c53d64461876c67d26d44efa4bf25f409011f893b9b47635` |
| 下载文件 | BIT `717bd8cfddeecf7753c8adcff68e0ec0072c0b9ca283c28613c2ac0dd3788d5b`；LTX `facc5a5a95599c155598321dcd21d34b5d32f14b810fd7b6ef086fb8416ce6ba` |
| 真实采集 | `evidence/agent_steps/step_05/rework_r4/attempts/capture_20261102_183416_de2cae60` |
| 硬件结果/回执 | `report/hardware/capture_20261102_183416_de2cae60/report_387fc78b/results.json` / `capture_receipt.json`（SHA-256 `9342136b…` / `5278450b…`） |
| 执行记录 | `evidence/agent_steps/step_05/result.json`（SHA-256 `107b02c6…`）、`report.md`、`inputs.json`、`logs_index.json`、`progress_update.json` |

## 独立复核方法

独立验收没有直接采信执行自检结论，也没有导入 `s05.py`。验收脚本 `run_acceptance.py` 独立解析封存、构建回执、源码 ZIP、BIT/LTX、preflight/capture 事件流、六份邮箱 HEX、结果与回执，并用独立生成的 zlib 参考重算 12 例 CRC。另有四路只读复核代理分别检查构建来源、硬件取证、记录边界与对抗性缺陷。

```powershell
cd "D:\vivado2026.1_project\160MHZ CPURISCV\board\z7_lite_7010_crc"
python -B -X utf8 evidence/agent_steps/step_05/acceptance_20261102/run_acceptance.py
```

实际结果：

```text
S05_INDEPENDENT_ACCEPTANCE_PASS 833 checks; 0 failures; 36 zlib CRC; 3 VIO resets; 6 stable scans; user LEDs; no S06
```

完整逐项检查见 [`checks.json`](checks.json)；实际命令、退出码与双流日志见 [`attempt_03/`](attempt_03/)。首次和第二次验收运行因验收脚本自身的正则/排序缺陷失败，日志保留在 [`attempt_01/`](attempt_01/) 与 [`attempt_02/`](attempt_02/)，不计作 DUT 失败。

## 主要独立结果

| 维度 | 独立结果 |
|---|---|
| 配置修正 | 合并后的 XDC 恰有一条 `CFGBVS VCCO`、一条 `CONFIG_VOLTAGE 3.3`；器件 `xc7z010clg400-1`；N18/P16/P15/U12 与 20ns 时钟正确 |
| 源码差异 | 相对已验收 S04 源码包：96 项相同、6 项修改、3 项新增、0 删除；无 `src/`、`firmware/`、`sim/` 或 `scripts/build.tcl` 改动；XDC 有效行仅两项配置属性不同 |
| 构建门槛 | 10 条重建命令退出 0，9 项离线门槛 PASS，9 份冻结镜像、136 项登记输入、依赖审计与构建回执一致 |
| BIT 来源 | 新 BIT 为 2026-11-02 17:57:02 的实际 bitgen 产物；其 fabric 负载与旧 BIT 相同，文件头时间不同（见下节限定） |
| LTX/VIO | 恰有一个 VIO 核心 `vio`，5 个探针方向/端口/宽度与运行期事件完全一致，UUID `1BE27D511A4C50DC974F3E22D2C609B9` |
| 真实链路 | 唯一目标 `Digilent/210241793374`，唯一 `xc7z010_1`，IDCODE `0x13722093` |
| 下载与探针 | 实际 Vivado2026.1 批处理退出 0；PROGRAM/VIO/UUID/5 个 PROBE 均记录；stdout/vivado.log 无 ERROR/FATAL |
| 三次重跑 | 三次 `RESET_LOW→RESET_ASSERTED→RESET_RELEASED→RUN_END`，复位时 `committed=0`，扫描边界 `committed=1`，所有 `failed=0` |
| CRC | 6 次扫描 × 104 字；12 例 × 3 次运行 = 36/36 与独立 zlib 一致；失败计数 `[0,0,0]` |
| 邮箱冻结 | 同一运行两次扫描逐字相同，三次运行邮箱完全相同，双扫描间隔 ≥1s |
| 周期字段 | `software_cycles`、`hardware_total_cycles`、`engine_session_cycles` 三次运行完全相同 |
| 仿真对照 | 六份硬件 HEX 与 `mailbox_sim_run_0/1/2.hex` 逐字节相同 |
| 回执 | `capture_receipt.json` 的 BIT/LTX、attempt、tool_run、events、六份 HEX、report 哈希全部匹配；用户观察记录绑定同一 attempt |
| 失败保留 | r3 首次采集失败 attempt 完整保留：tool_run FAIL、`Designutils 20-1474`、无任何复位/扫描；r3 三次构建失败与 r1 早期 preflight 失败亦保留 |
| 记录与边界 | `result.json`/`inputs.json`/`logs_index.json`/`progress_update.json` 全部重算匹配；123 项主工程保护文件不变；S04 历史验收不变；无 S06—S08 |

## 需要限定或纠正的既有表述

1. **BIT 变更表述**：执行报告称“BIT 已因配置属性修正而变化”，这不准确。`CFGBVS`/`CONFIG_VOLTAGE` 是项目/DRC 属性，不是 fabric 配置位；新旧 BIT 在同步字 `0xAA995566` 之后的负载完全相同，文件差异仅为头部构建时间（新 `2026/11/02 17:57:02`）。新 BIT 是新的 bitgen 产物、且来自修正后的项目配置，因此旧 BIT 不应作为本次下载对象；但不得据此声称编程后的 fabric 设计发生变化。本次实际下载的是新封存 BIT。
2. **`board_identity.json`** 是 2026-11-02 完整授权前的只读快照（GND/1.8、BLOCKED）。它保留为历史，不代表最终构建状态；当前权威状态是 `result.json`、`report/hardware/status.json` 与本报告。
3. **`physical_identity.json` 的文字引用**把 r3 preflight `20261102_182844_a4546e6e` 标为 r4 workflow；实际 r4 preflight 是 `20261102_183328_87bceaaa`，capture 的 `--preflight` 与 tool_run 均指向后者。该文字错误不影响采集数据；attempt 内字节因回执绑定而保持原样。
4. **`results.json` 的 `all_capture_attempts`** 只枚举 `rework_r4/attempts`，不包含 r3 失败采集。r3 attempt 已在阶段 `result.json`、`inputs.json`、`capture_receipt` 的 `prior_attempt_analysis` 与 `logs_index` 中保留和绑定；该字段应理解为 r4 范围。
5. **`logs_index.json`** 未索引 r3 preflight 与 r3 controls 日志；它们存在且被 r3 seal/身份文件引用，哈希列于 [`supplemental_history.json`](supplemental_history.json)。
6. **`validated_binding.json`/`accepted_inputs.json` 的 `hardware_live_verified=false`** 是采集前源绑定字段，不是采集结果；实际硬件证据由 capture events、tool_run、HEX 与回执构成。
7. **`latest_capture.json` 的 `CLI_exit_code=3`** 指向未含观察的预报告；最终报告 CLI 为 `cli_calls/20261102_184606_report_a269de`，退出 0，结果目录 `report_387fc78b`。
8. **r4 seal 日期早于采集**：seal 绑定构建、下载与主机脚本；采集回执与 `report/hardware/status.json` 另行绑定实际采集。seal 不应被误读为采集回执。
9. **硬件 HEX 与仿真 HEX 完全相同**：确定性固件下这是预期结果，也证明功能一致；但 HEX 本身不含硬件独有熵，不能单独证明来源。真实性依赖 Vivado2026.1 会话日志、约 18ms/字的真实事件时序、封存采集脚本与用户指示灯观察。
10. **实物与供电**：板卡丝印、器件、电源和 LED 状态为用户声明 + 客服配套资料 + JTAG 识别；未提供实物照片，供电轨未实测，`power_rails_measured=false`。本验收不把这些描述为仪器实测。
11. **源码包的主机工具变更**：新包相对 S04 还修改了 `run.py`（阻断旧 hardware 入口）、`scripts/evidence.py`（独立 stdio 管道）及 README/manifest/release 清单，新增 ES1 证据文件。它们不是 CPU/RTL/固件/约束改动；受影响门槛已在 r3 重建中全部重跑。r4 `change_manifest.json` 只描述采集脚本修正，不覆盖这些工具变更。

## 验收标准

| S05 出口要求 | 结论 |
|---|---|
| PCB 依据、唯一正确器件、真实采集来源及三次独立重跑证据齐全 | 满足；实物依据为用户确认 + 配套资料 + JTAG；唯一目标/器件；三次真实复位 |
| CRC 全部匹配，失败数为 0，采集文件及报告可由命令重算 | 满足；36/36、`[0,0,0]`、833 项独立复算 0 失败 |
| 不得用仿真 HEX 冒充；读不到/超时/错误/探针歧义均失败 | 满足；实际 Vivado 会话与事件链完整，失败 attempt 保留并解释，43 项主机控制覆盖负向模型 |
| 无板卡/资料时明确待外部条件，绝不标通过 | 不适用（板卡与资料已具备）；实物测量限制已列明 |
| 按共同要求交付 step_05 后停止 | 满足；未进入 S06—S08 |

## 状态与边界

- 独立验收结论为 **PASS**；执行自检 `result.json` 按项目惯例保留 `independent_acceptance=PENDING`，验收结论以本报告、`acceptance.json` 与 `checks.json` 为准。
- 本次验收只读取已保存证据，未重新下载或操作硬件；不改变 BIT/LTX、RTL/固件/约束或历史记录。
- 未执行 S06—S08，也未开展性能优化、发布或赛事提交。

## 验收交付物

- [`acceptance.json`](acceptance.json)：验收结论、对象哈希、标准、限制与产物哈希。
- [`checks.json`](checks.json)：833 项独立检查及证据。
- [`run_acceptance.py`](run_acceptance.py)：可重复运行的独立复算入口。
- [`supplemental_history.json`](supplemental_history.json)：r3/r1 失败与历史文件哈希。
- [`workflow_verdicts.json`](workflow_verdicts.json)：四路独立复核结论与发现。
- [`progress_update.json`](progress_update.json)：`docs/agent_progress.md` 验收登记前后哈希；原稿见 [`progress_before.md`](progress_before.md)。
