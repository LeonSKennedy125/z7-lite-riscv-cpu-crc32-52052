# 验证流程与脚本使用

## 分层选择证据

| 层级 | 本包入口 | 能证明什么 | 不能证明什么 |
| --- | --- | --- | --- |
| 模块 | run_units.py | 真实 RTL 的指定组合/时序契约 | 全核每条指令、真实 BRAM 实现、板级 |
| 写回 | compare_trace.py | 完整有序寄存器写回序列相等 | 非写回指令、额外 store、控制副作用、仿真是否正常结束 |
| 全核记录复核 | recheck_existing.py | 当前独立模型与已有周期记录一致 | 新 RTL 已重新仿真、板级 IRQ/外设接通 |
| 新全核仿真 | 原 R1 入口在隔离副本 build/run | 程序、WB、RAM、MMIO、CSR、PC、终止/drain 与模型匹配 | 官方 compliance、实际器件或不同平台通过 |

## 短时模块回归

```powershell
python -B -X utf8 skill/riscv-verification/scripts/run_units.py --project-root . --backend iverilog --suite all --out skill/artifacts/unit_run_02
```

`--project-root` 指完整工程；比赛目录布局下默认从脚本定位工程，安装后应显式传入。`--backend` 为 `iverilog`（默认）或 `xsim`；后者必须给 `--vivado-bin <bin目录>`。`--suite` 为 `all/contract/forward/csr/reset`，默认 all。`--out` 为不存在的新目录，`--timeout` 为单个工具超时秒数，默认90。返回0为本次所选模块全部通过，1为工具/断言/输入保持失败，参数错误返回2。

| 套件 | 来源 | 核心断言 |
| --- | --- | --- |
| contract | 新增 examples/skill_contract_tb.sv + 工程 RTL | ALU 边界与全部移位量；寄存器 x0/双读口/写回旁路；译码字段；BTFNT/JALR纠错；RAM地址、store strobe、MMIO ready/cancel |
| forward | 原 verification/phase04_unit_tb.sv 原样复制 | EX>MEM>WB 两个操作数的优先级，生产者有效与x0门控，load-use，save、stall、flush和恰好一次WB |
| csr | 原 verification/phase05_unit_tb.sv 原样复制 | 六条CSR操作、零源抑制、uimm、ECALL/EBREAK/MRET、注入IRQ、计数器和复位 |
| reset | 原 verification/phase10_r1_reset_sources_tb.sv 原样复制 | 外部复位/失锁/控制器请求相位、重叠和停钟捕获；不是模拟物理亚稳态 |

原 TB 某些失败通过 `$display("FAIL ...")` 报告后 `$finish`，进程仍可能返回0。因此汇总解析同时要求工具成功、唯一 `checks>0 failures=0`、无失败标记；复位用唯一完成标记。每项保存全部工具日志。先看最早失败，不依据日志末尾的 PASS 单词裁决。

## 指令用例设计

本核支持的范围由 RTL 和实际 BD 决定。新增用例放在技能包或新的验证副本中，禁止改原程序/golden。优先复用 `verification/make_phase09_programs.py`、`phase09_reference.py`、`phase09_core_tb.sv`、`check_phase09.py`；生成器会写文件，只能在隔离副本执行。现有 `phase06_hazards_program` 也包含程序、写回/存储期望和重叠地址标签。

1. 写出假设与终止 PC、最大周期和 drain 条件。RAM 使用 `0x80100000..0x8013ffff`，非对齐或非法编码归入边界/负对照，不作为支持功能。
2. 算术覆盖 0、全1、`0x80000000`、`0x7fffffff`、进位/借位、shift 0..31及高移位位忽略；SLT 和 SLTU 分开。
3. 寄存器覆盖 x0 不变、同拍写回旁路、rd==rs1/rs2、禁止写回和双源同时相关。
4. 对实际指令分别覆盖 R/I、U、六种B条件的 taken/not-taken、JAL link、JALR bit0清除、load符号/零扩展及store字节选通；CSR覆盖六种读改写和零源规则。
5. 数据冒险用“生产者→立即消费者”、间隔1/2条、两源来自不同阶段、load→运算/分支/store地址/store数据、连续相同rd写入等序列。观察EX0操作数，不只看最终RF。
6. 控制冒险在错误路径放置可检测的寄存器写和RAM/MMIO store；叠加 load等待、save、CSR redirect，确认错误路径没有副作用。IRQ仅限明确的注入模型。
7. 独立参考模型从程序语义生成期望，不能从 DUT 的WB/波形反填。全核检查器还比对store、MMIO握手、CSR、PC、最终RF和终止后的100周期尾部；缺任何必需记录应失败。

当前寄存器 trace 不是 `minstret`；原 `minstret/minstreth` 是占位值。IPC必须说明周期窗口和退休定义，不能把寄存器写次数当退休条数。历史自建程序的IPC也不能代替原竞赛/官方随机基准。

## 通用写回序列比较

```powershell
python -B -X utf8 skill/riscv-verification/scripts/compare_trace.py --expected skill/riscv-verification/examples/expected.trace --actual skill/riscv-verification/examples/hazards_simulation.log --actual-format wb-log
```

`--expected/--actual` 必填；各自 `--expected-format/--actual-format` 可为 triples（默认，`PC rd data`，可有首行记录数）、canonical（`PC(80000000)|x1(80100000)`）、wb-log（仅提取 `WRITE | PC=80000000 x1=80100000`）。PC/数据按十六进制，rd按十进制。空序列、X/Z、损坏写回行、错误声明计数均拒绝；缺少、重复、额外写回均失败。返回0相等，1首个分歧，2输入错误。此命令本身不检查仿真退出状态或完成标记。

## 复核已有全核周期记录

```powershell
python -B -X utf8 skill/riscv-verification/scripts/recheck_existing.py --project-root . --run-dir repair_records/phase10/rework_R1/runs/isa_s1_d0_20261021_130046_048067_bba90a --out skill/artifacts/recheck_02
```

三个参数均必填。输入运行目录必须有 `reference.json/static_reference.jsonl/program.hex/cycles.csv/simulation.log/final_rf.hex`。脚本先复制这些文件到新目录，再从所选工程导入当前比对器和模型，在副本生成 `metrics.json`、`retired.jsonl`、`expected_events.jsonl` 和 `recheck.json`。原始证据与两个Python输入均记录哈希并检查未改变。0通过，1比对失败，2参数/输入错误。

复核模型与日志的依赖是显式的：若单独分发 Skill，需要用户提供对应完整工程验证目录。缺原始证据时不能用一份 PASS 摘要代替。真正重新运行全核时，在隔离工程内执行R1 build后再run；先取得长时运行许可，不在原目录直接调用。
