# 故障分析提示词模板

## RTL/BD架构核对

```text
请使用 riscv-debug Skill，工程根目录=<填写>，允许新增输出目录=<填写>。
先运行只读静态检查，读取XPR顶层、主BD实例与nets，再读对应RTL。
请给出真正的流水阶段、级间寄存器、前递源、暂停/冲刷路径、存储延迟、CSR/IO边界。
对每个功能标记：主路径接入/仅有独立文件/只有模型验证/缺证据，并列源码位置。
本工程不能从5pipeline文件名推断级数，也不能由M译码或rv32_m.bd存在推断RV32M已启用。
只分析与新增报告，不修改RTL/XDC/XPR/原TB/已有报告。
```

## load-use / 两源前递 / save问题

```text
请使用 riscv-debug 定位以下故障：<填写现象>。
输入：程序=<填写>；RTL/BD版本及hash=<填写>；期望=<填写独立来源>；实际日志/波形=<填写>。
本核IF-ID-EX0-EX1-MEM-WB，实际操作数旁路在EX0，DTCM有primitive输出寄存。
围绕首个分歧列“周期、各级PC/valid、生产者rd、消费者rs1/rs2、EX/MEM/WB选择、
stall_Load/load_over/flush3、retain_en/data、save、Forward_valid、Wen_out”的证据表。
仅填输入中确实可观测的数据；没有波形就说明不能填。
重点区分：年轻生产者优先级错、load尚未就绪、等待中另一源丢失、save重复提交。
输出最多三个可区分假设、每个最小实验及预期差异；不先改golden或CPU。
```

## 分支/CSR与副作用

```text
请分析PC首次偏离参考的原因。输入：<程序、expected next PC、实际trace、RTL/BD、采样边沿>。
先查BTFNT预测方向、比较条件、JAL/JALR目标与link，再查Branch_Ctrl.Exception门控，
pc_judge仲裁、npc.replay_redirect、IBROM fetched_valid以及前段flush。
若与load/save/IRQ重叠，检查valid/irq_safe/CSR redirect和错误路径WB/RAM/MMIO是否取消。
请区分寄存器写回匹配与完整事件验证，不以最终RF一致排除多写一次store。
输出首个因果分歧与待补信号；没有实际顶层IRQ接线证据时不要宣称硬件中断正确。
```

## 一次错误日志的最小行动

```text
请根据以下真实错误日志排查：<完整错误及前后文>。
工具版本=<填写>；入口命令/cwd=<填写>；输入hash/顶层=<填写>。
先判定是工具/路径/生成物问题还是RTL行为问题，查第一处错误，不只看最终退出行。
给出只读核查步骤和一个可在新目录运行的最小复现实验，说明预期结果与停止条件。
不要自动执行历史修复脚本、删缓存、重置run、升级IP、改许可证或烧录FPGA。
```
