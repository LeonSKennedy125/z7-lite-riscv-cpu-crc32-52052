# Vivado 2026.1 可直接打开的工程

工程入口：[demo.xpr](demo.xpr)。请下载或克隆**整个仓库**，保留相对目录，不单独下载 XPR。

本工程对应 Z7-LITE_ES1 / XC7Z010CLG400-1 的 50 MHz CPU+CRC 演示：六级 RV32I+Zicsr、16 KiB 指令 ROM、64 KiB 数据 RAM。综合顶层为 [`demo_top`](../src/demo_top.sv)，CPU 结构连接在 [`demo_cpu.v`](../src/core/demo_cpu.v)。工程采用 RTL 连接七个独立 IP。

## 在 Vivado 图形界面打开

1. 安装 Vivado **2026.1**，包含 7-series 器件支持及适用许可。把仓库克隆到较短的本地可写路径，例如 `D:\work\z7_crc32`。
2. 启动 Vivado → **Open Project** → 选择 `D:\work\z7_crc32\vivado_project\demo.xpr`。检查器件为 `xc7z010clg400-1`，Design Sources 顶层为 `demo_top`。
3. 在 Sources → **IP Sources** 中选择七个 IP，右键 **Generate Output Products**。XPR 和 XCI 已提供；模型、综合网表等输出由本机 Vivado 生成。首次打开提示生成目录尚不存在，可按此步骤生成。
4. 在 Design Sources 中展开 `demo_top`，查看 `demo_cpu`、`crc_mmio` 和 `vio_result`。约束使用 `constraints/board_r11.xdc`；该历史文件名对应的有效内容及板卡依据见 [硬件说明](../docs/hardware_setup.md)。
5. 如需新码流，依次 **Run Synthesis → Run Implementation → Generate Bitstream**。新结果写入 `vivado_project/demo.runs/impl_1/`；重新构建的结果由本次运行的报告判定。

## IP 与初始化数据

| 实例 | IP / 功能 |
|---|---|
| `DTCM` | Block Memory Generator 8.4，16384×32 RAM，字节写使能，BRAM 输出寄存器开启 |
| `I_ROM` | Block Memory Generator 8.4，4096×32 ROM，同步取指 |
| `clk50` | Clocking Wizard 6.0，50 MHz |
| `rstip` | Processor System Reset 5.0 |
| `invip`、`orip` | Utility Vector Logic 2.0，复位组合逻辑 |
| `vio_result` | VIO 3.0，结果读取与复位控制 |

`demo.srcs/sources_1/ip/` 保留七个 XCI 及 RAM/ROM 各自的 COE。COE 与 `data/frozen/ram.coe`、`rom.coe` 逐字节一致，并放在相应 XCI 同目录，由 Vivado 原生保存相对引用。代码、头文件、测试和 XDC 仍位于仓库各自目录，通过相对路径登记。

此入口使用已发布的固定固件镜像，打开和仿真无需先安装 GCC。重新编译裸机 C、替换程序和完成全流程重建时，请采用 [从零复现流程](../docs/reproduction.md) 的 `run.py firmware`、`run.py project` 等命令，其工程输出为独立的 `b/p/demo.xpr`。

## 重新生成 IP 与运行五项自检

关闭同一工程的 GUI 会话后，从仓库根目录执行。以下安装路径按本机调整：

```powershell
Set-Location -LiteralPath 'D:\work\z7_crc32'
$vivado = 'D:\XILINX\2026.1\Vivado\bin\vivado.bat'
& $vivado -mode batch -source scripts/portable_project.tcl -tclargs generate
if ($LASTEXITCODE -ne 0) { throw 'IP generation failed' }
& $vivado -mode batch -source scripts/portable_project.tcl -tclargs test
if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
```

`generate` 重新生成七个 IP，检查所有登记文件存在、依赖局限于本仓库及 Vivado 安装，检查两块存储器容量与输出寄存器配置。`test` 先执行同样检查，再依次执行：

| 测试顶层 | 检查 |
|---|---|
| `tb_crc` | 12 组 CRC、寄存器、等待/撤销、中止、复位、计数回绕及邮箱冻结 |
| `tb_memory` | 64 KiB RAM 首末地址、访问宽度、非对齐、越界及两拍读取 |
| `tb_cpu` | 三轮复位、真实固件执行及每轮 12 组结果 |
| `tb_cpu_fault_timeout` | 超时注入，固件报告预期的两个错误并中止任务 |
| `tb_cpu_fault_error` | 外设错误注入，固件报告预期的一个错误 |

每项须出现 `PORTABLE_SIMULATION_PASS <top>`，最终为 `PORTABLE_REGRESSION_PASS tests=5`。测试台均有 watchdog；正常终止须有明确 PASS。运行记录位于 `evidence/portable_project/`。其中故障用例按既定错误计数验收，原有正确 golden 保持。

`scripts/portable_project.tcl -tclargs create` 用于**没有本目录工程的新源码副本**重建同等 XPR；现有 XPR 存在时会拒绝覆盖。普通使用选择 `generate` 或 `test`。

## 归档与验证范围

仓库保存 XPR、XCI、初始化数据及自主源码；`.gen/`、`.runs/`、`.sim/`、缓存和本机 IP 输出不入库。采用 AMD [UG892 源文件工程管理方式](https://docs.amd.com/r/en-US/ug892-vivado-design-flows-overview/Source-based-Revision-Control-Methodology)；COE 放置依据 [UG896](https://docs.amd.com/r/2023.1-English/ug896-vivado-ip/Using-a-COE-File)。AMD 文件按 [第三方说明](../third_party_notices.md) 使用。

本次可移植性验证的目录、配置及测试结果见 [验证记录](../evidence/portable_project_release/summary.json)。这是新的工程打开、IP 再生成与行为仿真证据。正式上板 BIT/LTX、50 MHz 时序与实测数据继续保留各自构建时点和哈希，入口为 [board/runtime](../board/runtime/README.md)。
