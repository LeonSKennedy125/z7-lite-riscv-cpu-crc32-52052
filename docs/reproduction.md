# 从零复现

## 1. 硬件和工具

- Z7-LITE_ES1，AMD XC7Z010CLG400-1，50 MHz 时钟，供电和 USB-JTAG。具体引脚见 [硬件说明](hardware_setup.md)。
- Windows 10/11 x64、Python 3.12、Git。
- Vivado 2026.1，含 7-series 器件支持和有效许可。
- xPack 15.2.0-1 / GCC 15.2.0。`run.py toolchain` 自动安装固定包，或用 `CRC_DEMO_GCC_BIN` 指定已安装的 `bin/` 目录。

## 2. 获取并核对源码

按 [README](../README.md) 克隆工程并进入仓库根目录。首先运行：

```powershell
python -B -X utf8 skill/scripts/check_manifest.py --root . --manifest release_manifest.json
python -B -X utf8 scripts/verify_saved.py
```

清单校验面向尚未生成新构建文件的干净检出目录；Git 的 `.git/` 元数据不属于发布清单。`verify_saved.py` 独立核对正式实测、补充演示、仿真邮箱、BIT/LTX 及当前最终报告的哈希。

## 3. 打开已提供的工程或从源码构建

直接浏览和仿真现有固件：用 Vivado 2026.1 打开 `vivado_project/demo.xpr`，按 [工程使用说明](../vivado_project/README.md) 生成七个 IP。该入口使用已发布镜像，GCC 不是打开工程的前置条件；五项自检由 `scripts/portable_project.tcl -tclargs test` 运行。

重新编译 C 并完整重建：继续执行以下 `run.py` 流程，输出为另一个工程 `b/p/demo.xpr`。两个入口共用 CPU/CRC RTL 与约束，分别管理本机生成文件。


复制执行 README 的完整构建命令。先配置 `CRC_DEMO_VIVADO_BIN` 为本机 Vivado 的 `bin/` 目录。固定架构选项为 `-march=rv32i_zicsr -mabi=ilp32`，禁用链接松弛和小数据寻址，使用独立启动和链接脚本。

| 命令 | 通过标志 / 产物 |
|---|---|
| `run.py toolchain` | 已声明 GCC15.2.0，或下载包哈希核对通过 |
| `run.py firmware` | ELF、反汇编、MAP、ROM/RAM 镜像及固件检查记录 |
| `run.py project` | `PROJECT_CREATED_7010_50MHZ`，生成 `b/p/demo.xpr` 与七个 IP |
| `run.py unit` | CRC 自检的终止 PASS 标志及 `evidence/unit_result.json` |
| `run.py memory` | 64 KiB 边界、宽度、对齐、两拍读取检查结果 |
| `run.py simulate` | 三轮 CPU 固件执行及 `mailbox_sim_run_*.hex` |
| `run.py faults` | 超时和外设 ERROR 两类真实固件故障模型的准确预期 |
| `run.py controls` | 解析器和证据检查器的负对照 |
| `run.py implement` | 综合、布局布线、时序/结构审计及 `evidence/demo.bit`、`demo.ltx` |
| `run.py project` | 实现后刷新工程和 IP 输入登记 |
| `run.py report --source simulation` | `report/simulation/` 的仿真结果汇总 |

`standalone.json` 使构建仅使用当前源码树。脚本自动选择空闲短路径盘符，并核对实际映射；已生成 IP 的构建目录保持同一映射。新的 XPR、DCP 和工具缓存均在本地生成。

历史 `run.py verify/clean/hardware` 属于开发阶段门控流程；日常公开复现采用上表命令以及 `scripts/verify_saved.py`、`board/runtime/run_board.py`。每个命令的退出码和终止标志共同决定结果，历史记录不会替代新的运行结果。

## 4. 上板与结果核对

仓库 `board/runtime/demo.bit`、`demo.ltx` 是正式实测对应的下载产物。源码重新构建出的 BIT 位于本机 `evidence/demo.bit`，两者有独立的生成记录。正式 50 MHz 测量数值对应仓库提供的实测 BIT/LTX 和固件。

按 [板级运行说明](../board/runtime/README.md) 完成身份核对、preflight 和 capture；或者在确认相同板卡后使用：

```powershell
python -B -X utf8 report/demo/demo_console.py --demo --runs 3
```

每轮都有 RESTART、固件提交、两次 104 字扫描和 `ROUND_END ... MATCH`。最终出现 `DEMO_DONE 3`，随后主机列出三轮结果。新生成结果通过独立参考校验：

```powershell
python -B -X utf8 report/demo/show_evidence.py run
python -B -X utf8 report/demo/show_evidence.py verify
python -B -X utf8 report/demo/show_evidence.py test
```

## 5. 离线查看与原始材料

```powershell
python -B -X utf8 report/demo/demo_console.py --show report/demo/runs_20261104_120839
python -B -X utf8 skill/scripts/verify_mailbox.py --dump data/hardware/s05/run_0_scan_0.hex
```

以上命令复核已保存文件，结果保留采集时点。原始正式验收、最近一次演示和仿真数据的目录见 [验证材料说明](verification.md)。

最终报告：[design_report_official_template.pdf](../report/design_report_official_template.pdf)。
