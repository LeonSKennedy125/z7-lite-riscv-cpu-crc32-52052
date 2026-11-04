# 真实工程分析与证据边界

分析日期：2026-11-03（Asia/Shanghai）。以 Vivado MCP 当前会话和实际文件为准，未修改现有设计。旧 `AGENTS.md`、`toolchain.json` 中的 D 盘位置属于历史迁移记录；本次用户明确选择的已打开工程位于 `C:/Users/liyua/Downloads/160MHZ CPURISCV`。

## 确认的结构

| 项目 | 事实与文件依据 |
| --- | --- |
| 顶层 | XPR 的 `sources_1` 顶层 `design_1_wrapper`；主设计为 `RISCV_5pipeline.srcs/sources_1/bd/design_1/design_1.bd` |
| FPGA / 工具 | XPR、主 BD 和实时 MCP 均为 `xc7k325tffg676-2`；本机运行 Vivado 2026.1。XPR 中部分 simulator version 元数据仍为 2025.2，不能代表本机工具版本 |
| 流水线 | 六级 IF–ID–EX0–EX1–MEM–WB；由 `IF_ID`、`ID_EX`、`EX_pipe`、`EX_MEM`、`MEM_WB` 及其实际接线确定，不依据工程名猜测 |
| IF | `npc`、`pc_judge`、`IBROM`、`instr_minidecoder`；复位 PC `0x80000000`；BTFNT（向后预测跳转、向前预测不跳转），JAL 前端生成目标，JALR 在后端纠正 |
| ID | `Decoder`、`Ctrl`、`imm_gen`、`Regfile`；32×32 寄存器、x0 恒零和 WB→ID 旁路 |
| EX0 | `EX_Forward`/`MEM_Forward`/`WB_Forward`、`Forward_Ctrl`、`EX_MUX`；最近 EX 生产者优先，其次 MEM、WB；`ID_EX` 在暂停时可保留已到达的旁路操作数 |
| EX1 | `EX_pipe` 后的 ALU、Comp、Branch_Ctrl、Store_Load、csr_top；实际计算、分支修正、访存请求、系统重定向 |
| MEM / WB | EX_MEM 保存访存元数据；MEM_DTCM 完成 load 格式化；MEM_WB、WB_MUX 写回 ALU/load/PC+4/CSR/IO 结果 |
| 暂停/冲刷 | load-use 产生 `stall/flush3`，RAM load 经 `load_over` 解除等待；`save_Load_use` 驱动 MEM_WB 的 save，保留旁路有效载荷，`Wen_out` 与 `Forward_valid` 分离以避免重复提交 |
| 复位 | cpu_reset_sync 捕获外部复位/失锁/控制器请求；cpu_reset_control 再用 qualified 寄存器对 CPU 控制复位作时钟边沿限定；不得拿历史“立即内部清零”测试覆盖当前契约 |

## ISA 与存储/接口

`Ctrl.v`、`ALU.v`、`Comp.v`、`Branch_Ctrl.v` 和 CSR RTL 支持的主线执行范围：

- R 类：ADD、SUB、SLL、SLT、SLTU、XOR、SRL、SRA、OR、AND。
- I 算术：ADDI、SLTI、SLTIU、XORI、ORI、ANDI、SLLI、SRLI、SRAI。
- 其他：LUI、AUIPC、JAL、JALR；BEQ、BNE、BLT、BGE、BLTU、BGEU；LB、LH、LW、LBU、LHU；SB、SH、SW。
- CSR：CSRRW、CSRRS、CSRRC、CSRRWI、CSRRSI、CSRRCI；系统控制 ECALL、EBREAK、MRET。属于机器模式的项目契约子集，不是完整特权规范合规声明。

不支持/未证明：FENCE、非对齐访问支持、完整非法指令异常、完整 ISA compliance、操作系统运行。`Decoder.instr_valid` 仅排除零指令，不是完整合法性译码器；部分非法编码仍会落入默认控制，不能把所有非零指令都当合法。

`Ctrl` 中可见 M 译码且存在 `rv32_m.bd`、乘除接口文件；**主 design_1 无 rv32_m 实例，ALU 主路径也没有乘除运算实现**，因此不得声明 RV32M 已接入。TAGE/BHT 等文件存在，主 BD 未连接；当前分支预测依据实际 minidecoder/Branch_Ctrl。没有在主设计中确认 Cache、DMA、AXI。

I_ROM XCI：4096×32 位，即 16 KiB，primitive/core 输出寄存均为 false；`IBROM` 使用 `pc[13:2]` 索引，不能由此宣称完整地址保护。DTCM XCI：65536×32 位，即 256 KiB，primitive 输出寄存为 true。有效地址由 `CPU_MEMORY_MAP.vh` 和 Store_Load/MEM_DTCM 约束在 `0x80100000..0x8013ffff`，不接受旧地址别名；半字/字非对齐写的 byte-enable 为零。

CPU 侧 MMIO 是自定义 `io_valid/io_ready/io_write/io_addr/io_wdata/io_rdata/io_be` 接口，地址为 `0x80200020`、`0x80200040`、`0x80200050`；不是 AXI。主顶层未提供 IRQ 输入，CSR `sys_exception` 的主 BD 外部接线缺口与已有告警一致。TB 可在单元或层次内部注入 IRQ，这不证明板上中断已连通。

## 自动化调用关系与副作用

```text
verification/run_current.py
  build/run/acceptance/check/controls/verify -> phase10_core.py（较早入口）
  implement/clean/reports                  -> run_phase10.py
  其他已有目标                             -> phase10_inherited.py

当前 R1 精确入口（技能包隔离适配器复用）
  phase10_r1_core.py build -> build_phase10.tcl -> xvlog/xvhdl/xelab
  phase10_r1_core.py run   -> phase09_core_tb + 现有程序/参考输入 -> xsim
                          -> check_phase09.py -> phase09_reference.Reference
  run_phase10_r1.py implement -> implement_phase10_r1.tcl synth / route
  run_phase10_r1.py clean     -> 新建源码副本 -> implement
  ip_upgrade_20261021/run_existing_smoke.py -> R1 build + 3全核 + 3继承目标

独立板级 CRC 示例（不等于主核构建）
  board/z7_lite_7010_crc/run.py clean -> scripts.rebuild.main('clean')
    -> scripts.release.clean -> package/清单校验/新目录重建
  run.py unit/memory/simulate -> scripts/build.tcl 对应目标
  run.py controls -> scripts.test_report.main
  run.py verify -> scripts.verify.main（会更新证据摘要）
```

`toolchain.json.tool_bin` 仍指向旧 `D:/XILINX/...`，本机实际为 `E:/Vivado2026.1/2026.1/Vivado/bin`。原入口会更新固定 `latest*.json`、生成目录或报告，`run_phase10_r1.py` 还可能重写 XPR 的自身路径。技能包因此只在新副本改工具位置及 XPR 元数据，保留原源码，默认构建仅输出计划。不能直接把原 `run_current.py acceptance` 当成当前 R1 的无副作用命令。

## 报告与验证证据

历史报告目录 `repair_records/timing_recheck_20261028/run_20261028_223130` 的报告日期为 2026-10-28；复核摘要为 2026-10-29。`active_inputs_before.json` 的 **617/617 项**在本轮哈希核对中匹配，没有缺失或改变。

| 历史原始报告 | 提取结果 | 限定范围 |
| --- | --- | --- |
| utilization.rpt | LUT 6300、FF 7865、BRAM Tile 88（RAMB36=87、RAMB18=2）、DSP 0 | 包含顶层与调试 IP 的整个设计，不是纯 CPU 核 |
| synth_utilization.rpt | LUT 6284、FF 7164、BRAM Tile 88、DSP 0 | 综合阶段；不能与布线阶段混列 |
| timing_summary.rpt | WNS +0.132 ns，TNS 0；WHS +0.050 ns，THS 0；WPWS +2.357 ns，TPWS 0 | 已分析片内路径；并非约 1 ns 的建立余量 |
| clocks.rpt | 输入 50 MHz；CPU 生成时钟 6.250 ns / 160 MHz | 约束频率，不是板上实测或搜索得到的 Fmax |
| check_timing/summary | 内部未约束端点 0，no_clock 0；缺输入延迟35、输出延迟71 | IO 与板级时序仍有缺口 |

本机 MCP 当前 `synth_1/impl_1` 均为 Not started。本轮新证据是模块仿真、旧 trace 的新比对、旧报告的新解析、输入哈希与活会话查询，**没有新综合/实现/bitstream/上板**。具体完成项以 [validation.json](evidence/validation.json) 为准。

保留的历史 R1 功能/模型与负对照分类，不能把 55 项功能/模型、17 项预期控制相加后说成 72 项功能通过。旧复位契约测试的预期失败也不等于新契约失败。独立 CRC 板级示例的任何实测结论不能自动转移到当前 Kintex-7 主核。

## 可复用经验与待验证项

1. 先核对 BD 实例与顶层，再写架构/扩展声明，避免由文件名或孤立译码推断功能。
2. 同时检查退出码、汇总数量、失败标记和输入哈希，防止 TB `$finish` 返回 0 却内部有失败。
3. 写回 trace 只能验证写寄存器；完整检查还必须包含 store、MMIO、分支、trap、最终寄存器和终止/drain。
4. save 保留前递值与 WB 提交使能要分别观测；load 等待时另一个源操作数也可能失效。
5. 把旧路径、已有 PASS、历史 DCP 和生成目录与新运行分开，不把复制的报告当作新构建结果。
6. BRAM 输出寄存、复位控制扇入与 methodology 需要结构审计；只看正 WNS 不够。

仍缺：本机新全核仿真/综合/实现；真正不同机器/不同板卡的迁移验证；完整官方 compliance 与原 IPC 约0.67基准的复现；主核真实桥/外设/IRQ、板级引脚电气和实测；赛方最新评分细则与官方指南原件的一致性确认。以上缺口不通过更改 golden、降低 DRC 级别或新增假约束消除。
