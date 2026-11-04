# RISC-V CPU 与 CRC32：完整 Skill 技能包

本目录包含主工程原有的 **3 个原生 Skill**，以及 CRC 子工程的校验工具、提示词和示例。两套内容分别保留，脚本原字节不改；原主工程技能总说明见 [cpu_skill_guide.md](cpu_skill_guide.md)，CRC 工具总说明见 [crc_mmio_guide.md](crc_mmio_guide.md)。

| 内容 | 实际入口 | 能做什么 |
|---|---|---|
| CPU 架构与故障排查 | [riscv-debug/SKILL.md](riscv-debug/SKILL.md) | XPR/BD/RTL 清单，前递、暂停、保存、冲刷与 CSR 排查，诊断提示词 |
| CPU 自动验证 | [riscv-verification/SKILL.md](riscv-verification/SKILL.md) | 模块测试适配器，严格写回序列比对，历史全核记录复核与故障检查 |
| Vivado 自动化 | [vivado-automation/SKILL.md](vivado-automation/SKILL.md) | 构建计划、隔离执行适配器、只读 MCP 查询、资源和时序报告提取 |
| CRC/MMIO 校验工具 | [crc_mmio_guide.md](crc_mmio_guide.md) | CRC 邮箱独立核对、文件 manifest 校验、接口契约和证据清单模板 |

## 原有内容在哪里

- 三个 Skill 的 `SKILL.md`、workflow、故障分析和 Python 脚本：上表三个目录。
- [scripts/validate_package.py](scripts/validate_package.py)：原技能包结构、引用、脚本帮助和判定器正负对照。
- [evidence/validation.json](evidence/validation.json)：原技能包的验证记录，连同模块仿真日志和历史复核数据保留。
- [riscv-verification/examples/](riscv-verification/examples/)：模块契约 TB、56 条写回期望、实际日志及来源记录。
- [project_analysis.md](project_analysis.md)、[collaboration_record.md](collaboration_record.md)、[competition_mapping.md](competition_mapping.md)、[report_excerpt.md](report_excerpt.md)：原分析、协作、赛事映射和报告说明。
- [references/](references/)：原指南节选和来源哈希，原文权利归原发布者。
- [scripts/](scripts/)、[templates/](templates/)、[examples/](examples/)：同时保留 CRC 工具的两个脚本、两个提示词/清单及示例。

原包 `artifacts/` 是其 `.gitignore` 明确忽略的本机运行目录，含 XSim 编译缓存、波形、工具依赖和重复运行；源码、示例与选定原验证记录均已收录。本次精确收录清单和逐文件来源哈希见 [source_inventory.json](source_inventory.json)。

## 立即运行

从仓库根执行，包检查的输出必须是尚不存在的新目录：

```powershell
python -B -X utf8 skill/scripts/validate_package.py --out skill/artifacts/my_package_check
python -B -X utf8 skill/riscv-verification/scripts/compare_trace.py --expected skill/riscv-verification/examples/expected.trace --actual skill/riscv-verification/examples/hazards_simulation.log --actual-format wb-log
python -B -X utf8 skill/scripts/verify_mailbox.py --self-test
```

第一条核查三个原生 Skill 及判定器正负对照；第二条对原样例的 56 条写回记录作新比对；第三条运行 CRC 校验器自测。旧实测数据的完整复算为 `python -B -X utf8 scripts/verify_saved.py`。

## 适配范围

原主工程 Skill 的分析基线为 Kintex-7 六级 CPU。其模块测试、完整构建和历史周期复核适配器需要原说明中列出的 XPR、验证目录与接口；调用时显式传入相应 `--project-root`。通用写回比较器和 Vivado 报告解析器可直接单独使用。当前公开的 7010/50 MHz CPU+CRC 工程按 [仓库复现指南](../docs/reproduction.md) 构建，不把旧 Kintex-7 适配器直接视为本配置的构建入口。

三个原生入口沿用标准文件名 `SKILL.md`，保持原包可被 Agent 识别；源码和说明的其余英文路径保持。原始历史说明保留其日期，发布后的当前入口以本页为准。

团队自研 Skill 内容采用 [MIT](../license.txt)；指南节选保留原来源，详见 [第三方说明](../third_party_notices.md)。

## 本次补齐后的检查

本次恢复来源、逐文件哈希和检查结果见 [publication_recheck_20261104.json](evidence/publication_recheck_20261104.json)。原包的 57 个非缓存文件逐字节收录，三个原生 Skill 入口有效；37 项包/判定器控制、56 条真实历史写回比对和 7010 已有报告解析通过。原主工程 Skill 与 CRC 工具的适配范围分别保留，未新跑全核仿真或上板。
