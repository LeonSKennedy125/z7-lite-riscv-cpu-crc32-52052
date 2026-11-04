# S06 性能与资源对比及功能冻结

日期：2026-11-02，Asia/Shanghai。**执行自检通过（SELF_CHECK_PASS），独立验收 PENDING。仅执行 S06；S07/S08 未执行。**

## 冻结对象与来源

- 冻结版本：`crc50-s06-60bd9a8688114c57`。
- 功能输入 SHA-256：`60bd9a8688114c575f2898e630e440668674bae615cb6b70aa85326f1d5e4b91`，算法为 `freeze.json.payload` 按 UTF-8、键排序、紧凑 JSON 编码后计算 SHA-256；不对包含自身的文件循环计算。
- 当前构建：`local_builds/s05_es1_20261102_173954_d834d5`，唯一从 `migration/current.json` 读取；原指针与 R4 seal 未修改。主工程标识为 `D:/vivado2026.1_project/160MHZ CPURISCV/RISCV_5pipeline.xpr`，未打开写入；123 项生产保护文件逐项不变。
- BIT SHA-256：`717bd8cfddeecf7753c8adcff68e0ec0072c0b9ca283c28613c2ac0dd3788d5b`；LTX SHA-256：`facc5a5a95599c155598321dcd21d34b5d32f14b810fd7b6ef086fb8416ce6ba`。S05 源码 ZIP SHA-256：`29215665782df967c53d64461876c67d26d44efa4bf25f409011f893b9b47635`。未把 BIT 时间戳变化解释为 fabric 功能变化。
- 实测来自 `evidence/agent_steps/step_05/rework_r4/attempts/capture_20261102_183416_de2cae60`，复核独立验收 PASS、R4 封存、真实 Vivado 采集事件、下载绑定、回执、6 份 104 字 HEX 与当前输入哈希；逐项独立 zlib 重算，36/36 匹配、失败计数 `[0,0,0]`。同次双扫描一致；本步没有新下载、复位或采集。
- 未修改已验收的 RTL、C 固件、测试、约束或构建脚本。77 项维护功能/构建/测试文件与当前封存构建相同；根目录与源码包的 `standalone.json` 因迁移元数据不同，分别记录哈希，均保持独立模式。

## 实测性能口径

软件基线为当前同一固件中的 **256 项查表 CRC**。主要加速比 = `software_cycles / hardware_total_cycles`；完整调用包含 ABORT/长度/START 配置、CPU 读内存及 MMIO 搬运、尾部拼装、轮询、状态检查和结果读取，也保留调用/返回与计数器采样开销。数据生成、逐位参考 CRC、邮箱写入、JTAG 扫描均在两者计时范围外。没有扣减开销或选最快轮。

引擎会话从 START 接受到末字节处理，包含 CPU 喂数间隙；不能当作独立引擎纯运算时间或用来替代主要加速比。完整调用和会话计时起止不同，二者之差不宣称为逐项精确的软件开销。时间按名义 50 MHz 换算：每周期 20 ns，`时间(μs)=周期/50`；未独立校准振荡器频率。

下表所有周期都按 **R1/R2/R3** 展示。三轮所有字段极差与相对首轮差值均为 0；时间列按软件/完整硬件/引擎会话排列，三轮相同。完整36行及每轮时间、均值、最小、最大、差值保留在 JSON/CSV/HTML 中。

| case | 字节 | 查表软件周期 R1/R2/R3 | 硬件完整周期 R1/R2/R3 | 会话周期 R1/R2/R3 | 时间 μs：SW/HW/会话 | 主要加速比 |
|---|---:|---|---|---|---|---:|
| 0 | 0 | 21/21/21 | 55/55/55 | 0/0/0 | 0.42/1.10/0.00 | 0.381818× |
| 1 | 9 | 174/174/174 | 79/79/79 | 39/39/39 | 3.48/1.58/0.78 | 2.202532× |
| 2 | 1 | 38/38/38 | 59/59/59 | 19/19/19 | 0.76/1.18/0.38 | 0.644068× |
| 3 | 2 | 55/55/55 | 64/64/64 | 24/24/24 | 1.10/1.28/0.48 | 0.859375× |
| 4 | 3 | 72/72/72 | 74/74/74 | 34/34/34 | 1.44/1.48/0.68 | 0.972973× |
| 5 | 4 | 89/89/89 | 65/65/65 | 20/20/20 | 1.78/1.30/0.40 | 1.369231× |
| 6 | 7 | 140/140/140 | 84/84/84 | 44/44/44 | 2.80/1.68/0.88 | 1.666667× |
| 7 | 16 | 293/293/293 | 95/95/95 | 50/50/50 | 5.86/1.90/1.00 | 3.084211× |
| 8 | 64 | 1109/1109/1109 | 215/215/215 | 170/170/170 | 22.18/4.30/3.40 | 5.158140× |
| 9 | 256 | 4373/4373/4373 | 695/695/695 | 650/650/650 | 87.46/13.90/13.00 | 6.292086× |
| 10 | 1024 | 17429/17429/17429 | 2615/2615/2615 | 2570/2570/2570 | 348.58/52.30/51.40 | 6.665010× |
| 11 | 4096 | 69653/69653/69653 | 10295/10295/10295 | 10250/10250/10250 | 1393.06/205.90/205.00 | 6.765712× |

case 1 为 ASCII `123456789`；其他为固定 xorshift32 数据（空输入也保留）。0/1/2/3 字节低于 1×：调用固定开销和尾部处理使短输入收益不足，均如实保留。4096 字节为 69653/10295 = **6.765711×**，查表软件 1393.06 μs、硬件完整调用 205.90 μs、引擎会话 205.00 μs。仅对本组固定数据、固件和本板三次确定性启动负责，不保证最低加速比，不把三轮零极差解释为全环境抖动上界。

性能入口：[HTML](performance/index.html)、[36行CSV](performance/results.csv)、[JSON与来源哈希](performance/results.json)、[三轮统计CSV](performance/summary.csv)。`performance/cases/case_00`—`case_11` 每组都有 JSON、CSV、HTML 和独立 PNG/SVG；另有周期、加速比、极差三张总图。

## 实际资源对照

两边均为 XC7Z010CLG400-1、20ns/50MHz、相同 CPU RTL、16KiB ROM、64KiB RAM、七个 IP 的相同功能参数、相同顶层、VIO 探针与 128×32 位邮箱尺寸。逐项比对实际生成的 XCI component parameters；除初始化文件引用允许位置不同外，没有功能参数差异。

加速版：复用 **S05 R4 2026-11-02 17:51:50—17:58:07 的真实综合/实现与静态审计**，重新核对当前输入、源码ZIP、实际日志、回执和 DCP/BIT/LTX 哈希。本步另开只读 checkpoint 审计，无再次综合/bitgen。不是使用历史160MHz主工程或R1迁移构建。

资源基线：本步从相同 S05 源码 ZIP 解压至隔离目录 `local_builds/s06_resource_20261102_205222`，没有复制 DCP/cache；新 GCC 编译、七 IP 生成、综合、布局布线、bitgen 均实际完成。所有命令及完整主/子进程日志在 `commands/` 与 `logs_index.json`。该目录只作资源对照，没有切换当前工程指针，也没有下载到板上。

| 指标 | 资源基线 | 加速版 | 加速版 − 基线 |
|---|---:|---:|---:|
| LUT | 6130 | 6560 | +430.000 |
| FF | 7694 | 7892 | +198.000 |
| BRAM36_equivalent | 20 | 20 | +0.000 |
| DSP | 0 | 0 | +0.000 |
| WNS_ns | 2.961 | 2.824 | -0.137 |
| WHS_ns | 0.037 | 0.044 | +0.007 |
| WPWS_ns | 7.0 | 7.0 | +0.000 |

两边 TNS/THS/TPWS 均为 0；内部未约束端点 0、组合环 0、布线错误 0。建立/保持/脉宽余量均正。16 个 DTCM RAMB36E1 的 DOA_REG 全为1，4个ROM RAMB36E1保留；流水级 IF_ID、ID_EX、EX_pipe、EX_MEM、MEM_WB、Regfile 与 CSR 都实际存在。两边 CPU FF 均为2287、RAMB36均20；VIO均221 LUT/448 FF，Hub均741 FF/24 LUTRAM。保留既有时钟/复位/debug约束，外部按键/LED未提供 I/O delay；本次不是完整板级接口时序或最高工作频率测量。DRC 既有 PDCN-1569、RTSTAT-10、ZPS7-1 警告保留，未增加豁免或降低严重程度。

### 必须披露的对照差异

1. 资源基线直接使用维护目录原有 `scripts/resource_baseline.sv` 替换隔离副本 `src/crc_mmio.sv`：移除 CRC 字节变换、CRC/长度/剩余量/缓冲/状态/结果/会话寄存器；`ready` 恒1；不再具有原 CRC 非法访问置错、忙状态、ABORT/START 和受忙状态约束的 COMMIT 检查。邮箱尺寸、提交后冻结、VIO `committed/failed` 和 TICKS/legacy 寄存器保留。它不是功能等价的完整 CRC 外设。
2. 隔离固件只把 `hardware_crc(p,n)` 函数体替换为 `return software_crc(p,n);`，避免等待不存在的引擎。原查表软件、逐位参考、12组向量、边界与修改/恢复检查、邮箱、启动和链接配置均保留。会话寄存器读值为0。该程序未上板，未把其周期当作同程序测量，也没有据此计算加速比；全部性能仍来自原R4固件。
3. 综合会因恒定 ready、MMIO 读数据范围、ROM内容变化而专化连接逻辑。实际 CPU LUT 为基线2923/加速2842，peripheral LUT为2535/3045、FF为4193/4391；Hub LUT为448/449，VIO完全相同。报告 **全SoC净增430 LUT、198 FF**，不是把它宣称为纯CRC计算数据通路的面积；层次差值不归一化，也不隐藏那1个Hub LUT差异。
4. ROM/RAM总容量固定，ROM固件内容按上条确有变化。`resource_control.diff` 给出全部两项源码差异；`resources/baseline_inputs.json`、实际XCI、MIF与ELF/镜像记录了派生输入。此对照没有宣称完成CRC基线功能回归或实物验收；它是已实现且结构核查通过的资源控制。

资源入口：[JSON](resources/results.json)、[CSV](resources/results.csv)、[独立图表](resources/resources.svg)；两边原始 utilization/hierarchy/timing/clocks/route/BRAM/debug 报告在 `resources/accelerated/` 与 `resources/baseline/`。

没有真实功耗测量，功耗及实测能效字段为 null，不使用工具估算冒充能效结论。

## 命令、失败与冻结规则

只在明确指定的 CRC 工作目录运行：

```powershell
Set-Location -LiteralPath 'D:\vivado2026.1_project\160MHZ CPURISCV\board\z7_lite_7010_crc'
python -B -X utf8 evidence/agent_steps/step_06/s06.py verify
```

生成阶段实际使用 `s06.py prepare`、`s06.py baseline`、只读 Vivado `resource_audit.tcl`，以及 `s06.py resources`、`s06.py measure`、`s06.py finalize`。实际完整 argv/workdir/environment、起止时间、退出码、stdout/stderr 哈希见 `commands/*/command.json`；加速版真实原命令保留原回执。本次全部成功最终命令退出0。

复算无需Vivado、不访问硬件、不覆盖封存；`verify`重新解析六份原始邮箱、重算全部36行数据和资源差值，并验证功能冻结与输入/产物/日志哈希。完整重建资源基线可按 `prepare.json` 指定源码ZIP、`resource_control.diff` 两项修改、`commands/baseline_firmware/command.json` 和 `commands/baseline_implement/command.json` 的原命令在新的CRC内隔离生成目录复做；不覆盖已完成目录或使用旧DCP。图表复生成需要本步局部安装的 matplotlib，具体版本在 `plot_dependencies.json`，不属于FPGA产品构建依赖。

初期失败均保留：准备器对 `standalone.json` 迁移元数据误作字节一致要求；误以为原源码ZIP包含资源stub；新Tcl审计脚本BOM/日志父目录问题；未使用原session设置/短路径时Tcl应用加载失败；新资源检查器误要求Hub LUT绝对相同。前两次没有启动构建，审计及报告失败没有修改已验收功能输入。修正的是新增S06工具，并未放宽CRC正确期望或重写旧PASS；失败命令与更正原因列在日志索引。

功能冻结清单为 `freeze.json`，`migration/functional_freeze.json` 为附加冻结入口，原 `migration/current.json` 不变。除必要缺陷修复外停止优化；**任何功能输入改变必须更新受影响回归、从源码的干净构建和匹配的新真实采集**，旧性能结论仅保留旧输入范围。S06没有改变产品功能输入，因此复用已匹配的S05回归/干净构建/实测证据，不新增一次无必要采集。

待办仅为 S06 独立验收；功耗未测且本步不要求补测。S07报告/许可定稿、S08最终打包、开源发布与比赛提交均未执行。本步已经形成供后续报告与打包使用的明确冻结版本，停止在S06。
