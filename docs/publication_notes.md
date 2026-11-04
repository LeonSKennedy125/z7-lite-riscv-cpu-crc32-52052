# 公开版本对应说明

日期：2026-11-04。团队编号 52052。公开工程基于此前完整重建的 `crc50-s08-20261103-review2`，保留其六级 RV32I + Zicsr、50 MHz、16 KiB ROM、64 KiB RAM、CRC/MMIO 和复位契约。

本次归档采用用户明确确认的 `report/design_report_official_template.pdf`。正式实测 BIT/LTX、S05 原始采集与结果回执、最近一次完整三轮演示、已有仿真输出、资源/时序、AI 和 Skill 一并收录。

构建相关 CPU/CRC RTL、C/启动/链接、约束、七 IP 配置和测试台的原字节保持。主机侧适配包括控制台从 `board/runtime/` 取下载文件、runtime 从仓库根定位校验器，以及清单扫描跳过 `.git/` 元数据。查看脚本的子校验失败传递为非零退出码。这些调整不改变 FPGA 逻辑或已有原始结果。

正式实测与 2026-11-04 补充演示保留各自日志和原字节。已有仿真/实现属于其原始构建时点；本次发布复查的命令和范围见 `evidence/publication/verification_summary.json`，并与旧记录区分。

历史阶段文档和 AI 引用中的旧 Word、旧目录、当时 PENDING 状态保留原时点。当前使用入口是根 README，当前最终报告是所收录 PDF，精确文件集合由 `release_manifest.json` 固定。

用户已通过官网独立窗口提交演示视频；按用户选择，仓库不包含视频。旧工作区、完整工具安装、缓存、厂商原资料和备份未纳入公开目录。

## 2026-11-04 完整主工程 Skill 补齐

首次公开版本只收录 CRC 子工程技能包，遗漏了主工程根目录的三个原生 Skill。本次从原 `skill/` 按原字节补入源码、工作流、案例和验证记录；原总说明保留为 `skill/cpu_skill_guide.md`，CRC 总说明保留为 `skill/crc_mmio_guide.md`，新的 `skill/README.md` 提供统一入口。原包自行忽略的 artifacts 缓存目录保持不进入源码仓库。CPU、固件、约束、PDF 及实测原始数据不变。

## 2026-11-04 可直接打开的 Vivado 工程

新增 `vivado_project/demo.xpr`、七个 XCI、同目录 COE 及 GUI/命令行操作说明，采用 7010 / 50 MHz 演示配置。原生成盘符不可用时，在另一目录重新打开、生成全部 IP；39 项 CRC 单元检查、64 KiB RAM 边界检查、三轮 CPU 固件和两类准确预期的故障注入均通过。依赖审计没有工程外部输入，原 CPU/固件/XDC、67 个 Skill 文件、最终 PDF 和已有上板记录保持原字节。新增验证记录见 `evidence/portable_project_release/summary.json`。本次未重新布局布线或上板，历史数值保留原构建时点。
