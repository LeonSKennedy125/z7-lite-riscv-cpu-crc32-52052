# S07 独立验收报告

日期：2026-11-03，Asia/Shanghai。

**结论：S07 独立验收 PASS（48 项检查，0 失败）。** 验收对象为提交 Word 设计报告、AI 协作记录、Skill、许可证/第三方范围、S07 staging 候选及执行自检。本次验收未执行 S08；S08 已有另行本地审阅记录，见 `docs/agent_progress.md` 顶部；本次不修改 S08 结论。未公开发布，未提交赛事系统。

## 验收对象

| 项目 | 值 |
|---|---|
| 主工程 | `D:/vivado2026.1_project/160MHZ CPURISCV/RISCV_5pipeline.xpr` |
| CRC 根 | `D:/vivado2026.1_project/160MHZ CPURISCV/board/z7_lite_7010_crc` |
| 当前构建 | `local_builds/s05_es1_20261102_173954_d834d5`（`migration/current.json`） |
| Word 报告 | `report/design_report.docx`，SHA-256 `302cf7ce48ae2487919edb75605281f33c9ccea26b97d62ef54b23bfa9b8398e` |
| AI 记录 | `report/ai_collaboration.md`、`report/ai_quotes.json`、`evidence/agent_steps/step_07/session_prompts.md` |
| Skill | `skill/README.md`、`skill/scripts/verify_mailbox.py`、`skill/scripts/check_manifest.py`、模板/示例 |
| 许可 | `license/license.txt`（MIT）、`license/license.md`、`license/scope.json`、`third_party_notices.md`、`docs/third_party.md` |
| staging | `delivery/source_candidate_s07_20261102` |
| 执行自检 | `evidence/agent_steps/step_07/result.json`（保持提交时 PENDING） |

## 独立复核方法

验收脚本 `run_acceptance.py` 不导入 `s07_verify.py`，而是独立读取 Word 正文/表格、AI 引文、Skill 脚本、许可 JSON、staging manifest 与 S06 已验收数据；随后把执行自检 `s07_verify.py` 作为**一项输入**运行，不作为验收权威。实际命令：

```powershell
Set-Location -LiteralPath 'D:\vivado2026.1_project\160MHZ CPURISCV\board\z7_lite_7010_crc'
python -B -X utf8 evidence/agent_steps/step_07/acceptance_20261103/run_acceptance.py
```

实际结果：

```text
S07_INDEPENDENT_ACCEPTANCE_PASS 48 checks; 0 failures; word=302cf7ce48ae
```

进度更新：`docs/agent_progress.md` 已把 S07 独立验收改为 PASS；S08 记录只补记“S07 阻断已消除”，不改 S08 总验收结论。before/after 哈希见 `progress_update.json`，pre-S08 的 S07 PENDING 快照见 `progress_before.md`。

首次运行 `attempt_01` 有两项**验收脚本自身**的字符串假设失败：Word 检查要求 `12/12`（实际报告写 `12 组`/`36/36`），Skill 检查要求 `不使用 PYNQ`（实际写 `未使用 PYNQ`）。两项均不是 DUT 或提交材料失败；已保留 `attempt_01/`，修正验收脚本后重跑 PASS。

## 主要独立结果

| 维度 | 独立结果 |
|---|---|
| S06 前置 | 独立验收 PASS；S05 PASS |
| Word 结构 | 201 段、17 表、4 图；第 1—10 章 + 附录 A/B/C |
| Word 内容 | 必含：2026 嵌入式 FPGA 大赛、CRC-32/ISO-HDLC、0xEDB88320、6.765712、36/36、12 组、69653、10295、6130、6560、7694、7892、2.824、2.961、50 MHz、16 KiB、64 KiB、MIT、单枪匹马、范文轩、李元宏 |
| Word 洁净度 | 无 S01—S08、原设计/原CPU/原文档、160MHz、删除/新增、验收/冻结/哈希/evidence/candidate/staging/F01/F02/PENDING 等内部痕迹 |
| 路径洁净度 | 无 `C:/`、`D:/` 等盘符路径；复现命令用 `<Vivado 安装目录>/bin` 等占位 |
| 数值一致性 | 4096 字节 69653/10295/6.765712 与 S06 性能 JSON 一致；资源 6130/6560/7694/7892/2.961/2.824 与 S06 资源 JSON 一致 |
| 版面 | 表格总宽 ≤ 可用页宽（6.536"）；4 张图宽 5.8" ≤ 可用页宽 |
| AI 记录 | 19 条引文源文件存在、原文匹配；记录明确“无完整聊天导出、无模型内部推理” |
| Skill | `--self-test` PASS；六份真实硬件 HEX 全部 `VERIFY_PASS`；staged manifest `MANIFEST_PASS`；不申报 PYNQ 加分 |
| 许可 | MIT 生效文本含“单枪匹马（范文轩、李元宏）”；`SELECTED_MIT`；公开范围已确认但 `NOT_PUBLISHED`；赛事 `NOT_SUBMITTED` |
| AMD/第三方 | `src/core/demo_cpu.v` 保留 AMD 版权头，未纳入团队 MIT；厂商/用户资料列入排除清单 |
| staging | 128 文件；127 项 manifest；76 个功能文件与封存候选逐字节一致；无 `report/design_report.md`、`report/evidence_trace.json`、`evidence/agent_steps/step_07` |
| 执行自检 | `s07_verify.py` 34 项 PASS（作为输入复核） |

## 非阻断项

1. **A01 渲染**：本机未安装 Microsoft Word/LibreOffice，未做逐页 PDF 渲染；已做正文/表格/图片/页宽/关键词与数值检查。用户在 Word 中目视确认分页、表格换行和图片位置即可。
2. **A02 公开包清理**：staging 仍保留厂商/用户资料作本地证据；`license/scope.json` 与 `release_manifest.json` 已标记其不得进入公开仓库。S08 必须在公开包中物理排除，或取得书面许可。
3. **A03 原始 docx**：主工程 `CPU设计文档.docx` 是 S05/S06 保护输入，未被覆盖；提交 Word 是独立的 `report/design_report.docx`。如用户要求覆盖原路径，需另行授权并更新保护记录。

## 验收标准对照

| S07 出口 | 结论 |
|---|---|
| 报告每项结果可追溯到冻结版本和真实证据 | 满足：Word 数值与 S06 性能/资源 JSON 一致；内部追溯在 working 目录，不进入提交包 |
| AI 记录真实 | 满足：19 条引文源文件存在且匹配；不伪造完整导出 |
| Skill 可直接复用且描述边界 | 满足：README、脚本、模板、示例；self-test/真实 HEX/manifest 通过 |
| 许可选择、适用范围及第三方来源落实 | 满足：MIT 已选；AMD/厂商/用户资料排除；公开范围已确认但未发布 |
| 按共同要求交付 step_07 后停止 | 满足：本次验收未执行 S08；S08 另有记录，本次不修改其结论；未公开发布或提交赛事系统 |

## 结论与下一步

S07 独立验收 **PASS**。原执行自检 `result.json` 保持提交时 PENDING；本报告、`acceptance.json`、`checks.json` 为独立结论。S08 已有另行本地审阅包，总验收仍 PENDING；本次未进入 S08 新执行。
