# AI 协作记录（入口）

本文件原为早期阶段的 AI 协作摘要。S07 已把完整、可核对的记录移到：

- **[report/ai_collaboration.md](../report/ai_collaboration.md)**：真实提示词、保存到工程的回答摘录、工具失败、纠错轨迹、工作流设计、记录边界。
- **[report/ai_quotes.json](../report/ai_quotes.json)**：上述摘录的源文件清单；`evidence/agent_steps/step_07/s07_verify.py` 会检查每条摘录确实出现在源文件中。
- **[evidence/agent_steps/step_07/session_prompts.md](../evidence/agent_steps/step_07/session_prompts.md)**：本会话可见提示词的逐字摘录（S07 任务、设计报告底稿要求、赛事背景修正）。

## 保留的早期纠错摘要

| 观察/失败 | 原因和修正 | 证据 |
|---|---|---|
| 指定包 15.2.0-1.1 的官方标签返回 404 | 发布包为 15.2.0-1，GCC 仍 15.2.0；征得用户明确选择后固定官方 SHA-256 | `evidence/toolchain.json` |
| Windows 文本模式重复展开源文件换行 | 改为按 UTF-8 字节写冻结副本，只修正生成器自己产生且可精确识别的换行差异 | `scripts/` 与 `source_manifest.json` |
| CRC 背压测试在改地址后立即读取 `ready` | 测试台尚未经过组合逻辑 delta 周期；增加 1 ns 采样等待，不改 CRC 参考或取消背压检查 | 最早失败 unit 日志及后续通过日志 |
| IP COE 文件读回变成相对路径 | 配置并未丢失，读回校验应对 IP 目录解析相对路径 | 最早 project 失败日志及 IP 配置通过日志 |
| RAM 读回低半字而期望整字 | 测试台错用 ISA funct3 值作为主核内部 `Load_Ctrl`；改用原有 `LOAD_LW` 等宏，保留原期望 | memory 失败日志、`riscv_define.vh` 及后续通过日志 |
| 初始配置电压假定 3.3 V | 逐页核对厂商 R11 原理图，页 4 显示配置 Bank 为 1.8 V 且 CFGBVS 接地；后续 ES1 资料又确认 VCCO/3.3，旧 GND/1.8 构建作废 | `evidence/vendor` 原理图、`docs/hardware_baseline_zh.md`、S05 验收 |
| 干净目录下 dbg_hub 生成失败 | Chipscope16-302 指出临时路径 149 字符超过 146 字符限制；复用稳定 SUBST 盘符，退出后保留 | `c3519/evidence/implement.console.log`；S01 报告 |

完整的 S03/S05/S06/S07 纠错见 `report/ai_collaboration.md`。本文件不再单独维护完整记录，避免与 `report/` 版本不一致。
