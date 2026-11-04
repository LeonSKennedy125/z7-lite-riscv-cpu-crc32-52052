# 从第一个分歧定位故障

## 先固定采样边沿

原 `write_trace_checker.sv` 在posedge读取写回进入Regfile前的旧状态；SV非阻塞赋值在稍后更新。对齐PC/rd/data时必须标出“边沿前/边沿后”。波形截图缺少时钟与有效信号时，先请求缺失信息，不能编造周期。

最小观测集：clock/reset、各级PC与valid、rs1/rs2/rd、ALU控制和操作数、EX/MEM/WB匹配使能与选择、stall_Load/load_over/load-use、save、flush/CSR redirect、Wen_out/Forward_valid、RAM ena/wea/地址/数据、IO valid/ready/be。完整层次前缀随TB改变，不硬编码旧截图路径。

## 数据冒险：先查生产者，再查消费者

1. 在消费者EX0查源寄存器号与原值，列同时在EX1/MEM/WB中的匹配生产者，确认各自有效写回且rd非0。
2. 同一寄存器连续生产时，确认Forward_Ctrl按EX>MEM>WB选择年轻者；分别检查rs1与rs2，避免只验证第一源。
3. 对load-use：EX_Forward的stall/flush3、Store_Load.stall_Load、EX_pipe.load_over要一起看。load结果尚未就绪时，不能把EX阶段地址或旧data当load值。
4. 消费者等待期间，另一个较早生产者可能已经离开WB。检查ID_EX retain_en/data是否保留已到达旁路值，save_Load_use是否保留MEM_WB载荷。
5. save/stall时Forward_valid可保持，但Wen_out应禁止提交；释放后恰好一次。用周期记录统计重复WB，不能因最终RF相同就忽略重复提交。

最小复现来自真实 `verification/phase06_hazards_program/program.S` 与 `overlap_targets.txt`，包含load两源重叠、load→store、立即消费者等。复现时复制用例到新目录，不改原预期。

## 控制冒险与PC

前端BTFNT按分支立即数符号选方向；后端Branch_Ctrl用真实目标与EX PC的差值推断原预测。先分别检查offset符号、taken条件和纠正目标，再看flush到IBROM/IF_ID/ID_EX/EX_pipe的实际连线。

JAL由前端预判，JALR在EX1纠正并清目标bit0。不存在完整非对齐异常证明，保留bit1不等于支持半字对齐指令。检查link写回PC+4，不能只看PC跳走。

CSR重定向与load等待叠加时，观察npc.replay_redirect及IBROM.fetched_valid。代码在stall时可保存right_pc-4再重放，不能只截某一周期认定目标算错。错误路径需同时验证WB、RAM写和MMIO握手被取消；load等待不应制造重复外部事务。

## ALU、寄存器、存储与CSR

| 现象 | 区分原因所需证据 | 最小实验 |
| --- | --- | --- |
| 算术值错 | EX0最终操作数、EX_pipe值、ALU控制、Comp结果 | 先运行contract套件；SLT/SLTU、负数SRA、shift31独立检查 |
| load/store地址错 | 完整A+B、Store_Load地址、ram_hit和低地址位 | 用base与非零offset，验证0x80100000和0x8013fffc；边界外/非对齐作负对照 |
| load符号错 | BRAM返回word、mem_addr低位、Load_Ctrl | 0x80/0x8000与LBU/LHU对照；等待真实两拍数据 |
| store字节错 | D2、Store_Ctrl、byte-enable、packed data | SB四lane、SH两合法lane、SW对齐；错路径store检查零事务 |
| 寄存器读旧值 | 实际WB wen/rd/data、WB→ID旁路、阶段匹配 | 同拍读写、x0、禁写、两源相关；区分旁路值和数组旧值 |
| CSR相邻项被改 | csr_addr、wen、rs1/uimm、old value和edge后值 | 原phase05_unit用不同sentinel查地址隔离；零rs1编号与内容为零不同 |
| IRQ丢失/重复 | sys_exception注入、mip/mie/mstatus、valid/irq_safe/stall | 单元模型检查短脉冲叠加等待和恢复；不据此声称主顶层硬件IRQ已接入 |
| reset后RAM出错 | request、qualified、io_resetn、BRAM使能与每次写 | 当前允许受控内部清零延迟；保留grace-window已接受写，不套旧契约 |

## 工具与日志

遇到“找不到层次/模块”先检查活动源版本、展开顶层、IP生成和库顺序；遇到X/Z先检查复位和未连接输入。原仿真中sys_exception未接线警告要与实际TB注入方式一起分析，不能全局忽略。

推荐诊断结论格式：事实→首个分歧→候选原因与源码位置→最小区分实验→尚未验证项。修复RTL、改约束或重新实现须遵循用户授权，本Skill默认只诊断和新增复现材料。
