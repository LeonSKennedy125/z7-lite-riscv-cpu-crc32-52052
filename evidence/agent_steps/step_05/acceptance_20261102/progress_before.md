# 2026-11-01 CRC迁移接续状态

唯一CRC接续根为 `D:/vivado2026.1_project/160MHZ CPURISCV/board/z7_lite_7010_crc`；旧来源只读。当前构建为 `local_builds/relocated_20261031`，由 `migration/current.json` 与seal指定，不使用复制的旧生成工程写入。

更新日期：2026-11-01。S01—S04独立验收保留原输入历史范围；迁移后构建另有自检封存。S05 R2新目录核查通过，真实上板仍待实物资料/JTAG，未通过；S06—S08未执行。

最新只读preflight目标数为0、CLI退出3，没有下载、请求复位或真实采集，S05仍为PENDING_HARDWARE、0/3、独立验收待进行；S06—S08未执行。当前R1入口已绑定新构建。完整报告与命令见 `migration/report_zh.md`，主工程迁移记录见 `repair_records/crc_relocation_20261031`，交接见主工程 `handoff/guide_zh.md`。

以下各段保留其历史日期和原输入状态，不能将旧路径段落当作当前写入授权。

---

# 提交步骤进度

更新日期：2026-10-31。S01—S04已独立验收通过；S05已执行离线核查与只读识别，待实物资料/JTAG，未通过；S06—S08未执行。当前验证对象是S04源码候选及其独立构建目录。历史CPU修复阶段的通过结论不自动转换为下表通过结论。

| 步骤 | 执行状态 | 独立验收 | 交付入口 |
|---|---|---|---|
| S01 当前输入与验收入口 | 自检通过；当前系统门槛仍待执行 | 独立验收通过（2026-10-29） | evidence/agent_steps/step_01/acceptance_20261029/report.md |
| S02 功能回归与错误路径 | 功能及错误路径自检通过 | 独立验收通过（2026-10-29） | evidence/agent_steps/step_02/acceptance_20261029/report.md |
| S03 50MHz实现 | R1新源码实现及独立静态复查通过 | 独立验收通过（2026-10-30） | evidence/agent_steps/step_03/acceptance_20261030/report.md |
| S04 独立干净重建 | 实际ZIP、独立重建及新解压固件入口复查通过 | 独立验收通过（2026-10-30） | evidence/agent_steps/step_04/acceptance_20261030/report.md |
| S05 真实上板 | R2新目录7项主机核查及32项离线控制通过；最新目标0；真实采集0/3 | 待独立验收，未通过 | evidence/agent_steps/step_05/rework_r2/report.md |
| S06 性能与资源 | 待执行 | 未验收 | evidence/agent_steps/step_06/ |
| S07 文档与许可 | 待执行 | 未验收 | evidence/agent_steps/step_07/ |
| S08 最终交付 | 待执行 | 未验收 | evidence/agent_steps/step_08/ |

外部发布：未授权、未发布。决赛海报：仅入围并取得官方模板后执行。

S04交付（2026-10-30）：实际候选为 delivery/source_candidate_20261030_162300_d25c1c 及同名 ZIP；显式选择 100 项，连同独立模式标记和 manifest 共 102 个初始文件，按包解压至 clean_builds/20261030_162300_d25c1c。36 个 HDL、2 个头文件、固件/参考/测试/XDC/IP Tcl 及全部产品脚本均受发布哈希覆盖。原 46 项冻结 CPU 文件与 362 项生产保护文件未改变；start.S 更名为 start.s 后字节不变，显式保留汇编预处理语义。未接入 M/TAGE 等 10 个模块未进入候选，构建不依赖它们。

本轮新 C 编译、七个 IP 生成、39 项 CRC 单元检查、64KiB 存储、三次完整整机仿真（36 组、错误数 0）、两项真实固件故障模型、9 类解析器负对照及17项证据控制通过。新的50MHz实现 WNS +2.824ns、WHS +0.044ns、WPWS +7.000ns，TNS/THS/TPWS 均0；LUT6560、FF7892、BRAM20、DSP0，与S03一致。16个数据RAM原语 DOA_REG全1，128个BRAM控制引脚异步寄存器来源0；71份新运行文件含Hub子综合日志保全。9份镜像逐字节相同，6份生成MIF逐字一致；136项登记输入及实际编译路径核查通过。

源码包显式禁用祖先工程发现和回退，实际父XPR存在及缺少冻结文件的负对照通过；独立模式原工程保护标为NOT_APPLICABLE/pass=null，父演示上下文另外实查保护文件。只在本机验证，不声称另一台无父工程机器已验证。构建日志改用独立stdout/stderr句柄，错误内容和两流哈希均检查；旧失败和初期不充分的诊断保留。实现后的工程刷新曾在Tcl执行前原生异常退出3221225477，未改包，在新clean尝试内重试剩余刷新/报告/审计并逐项重新核验当前输入；原FAIL另存attempt_08，当前clean_result为新PASS。

当前验证对象为上述候选和独立构建；S02/S03旧独立结论保留原版本，新候选已完成相应离线重验。父目录旧生成工程回执因脚本输入改变而转为历史，父run.py verify实际退出3、无FAIL、clean为PASS；完整当前离线组合结论见step_04/release_verification.json。S04独立验收仍待执行。实物/R11确认、真实采集与测量、最终报告/AI/Skill定稿、权利与许可、开源及赛事提交仍待后续明确步骤。本次停止S04，不执行S05。

执行规则和验收提示词见agent_execution_plan.md；共同要求见agent_prompts/common.md。状态更新须指向真实证据，不删除旧失败，也不把自检等同独立验收。

S01：原 46 项 CPU 来源清单及冻结源码保留，另建立完整当前输入清单；旧单元／整机 PASS、组合环失败、IP 锁定及生成工程重建记录均单列为历史。验收脚本加入运行开始作废、命令与退出码、超时、终止标记、输入及日志哈希校验。检查器故障控制有真实命令与完整日志；其中合成的工具输出只证明检查器行为。`python -X utf8 run.py verify` 当前返回 3（PENDING_EXECUTION），硬件单列 PENDING_HARDWARE，不声称系统通过。未运行 CPU 功能回归、综合、实现、干净重建或真实硬件测试。停在 S01，独立验收通过前不进入 S02。

S01独立验收：已实际重跑15项检查器故障控制，复核91项当前输入、11项交付证据、47项历史文件、46项冻结CPU文件及362项受保护文件，全部符合本步要求；实际CLI verify返回3且pass=false。验收输入版本为0e495363d20b4d65b70a5a7fea2ea760f254211ddb6d1416559d4f65a2392e2f。详见evidence/agent_steps/step_01/acceptance_20261029/report.md及checks.json。原自检报告和result.json保留其提交时的PENDING状态，由独立验收记录补充结论。本次只更新进度与验收证据，未修改RTL或执行S02；下一步可由用户指定S02。

S02交付与独立验收（2026-10-29）：固件、项目、CRC单元、存储、整机、固件故障、解析器控制及仿真报告8项门槛与当前输入对应。独立验收重新编译/展开/运行CRC单元，39项检查与12组向量通过；重跑15项检查器控制通过；对照独立zlib核验三次CPU运行共36组结果。CPU超时及STATUS.ERROR故障的实际错误计数写入、超时ABORT和主机拒收证据匹配。46项冻结CPU文件及362项生产文件保持；正常RTL、固件源码、ROM/RAM镜像及golden未改变。

S02验收输入版本为2b832231f306f5dcc6c1559ce2da224f6ce1e4867194f8814376a4ac5ef03625。独立结论和日志见evidence/agent_steps/step_02/acceptance_20261029/report.md；原自检报告及result.json保留提交时状态。本次验收修正了进度表S02段的问号乱码和过期状态，原文保存在独立验收目录progress_before.md，前后哈希见progress_update.json；没有修改可执行输入。

当前全工程仍为PENDING_EXECUTION、pass=false：implement及clean待执行，hardware待真实板卡。S02通过范围仅为行为仿真与相关验证，不代表50MHz时序、下载文件、独立干净重建或真实上板已通过。下一入口为用户指定S03；本次没有执行S03。

S03交付（2026-10-29）：已从当前100项输入新执行XC7Z010/50MHz综合、优化、布局和布线；独立静态审计退出0，WNS +2.824ns、WHS +0.044ns、WPWS +7.000ns，TNS/THS/TPWS全0，内部未约束端点及组合环0。BRAM 20 Tile，数据RAM 16384×32，16个RAMB36E1的DOA_REG均1，128个控制引脚的异步寄存器源0。

原S03交付整体自检未通过（以下为历史状态，当前结论见R1段）：write_bitstream写出BIT并打印bitgen成功后未正常返回；输出重试仍失败，两次独立导出超时240秒。evidence/demo.bit及demo.ltx仅作为未验收候选归档，accepted=false，implement回执保持FAIL，全工程verify实际退出1。原嵌套调试Hub子综合日志未在reset清理前单独保全，另列证据完整性缺口；不能声称已逐条归档其警告。该次失败交付、警告依据、日志及哈希见evidence/agent_steps/step_03/rework_r1/before/report.md、result.json和logs_index.json。

当前输入哈希仍为2b832231f306f5dcc6c1559ce2da224f6ce1e4867194f8814376a4ac5ef03625；RTL、固件、镜像、golden、XDC和XCI参数均未改变，S02功能证据保持输入匹配。本次仅刷新了生成工程的project回执，原回执按既有协议归档，不自行重写S02独立验收结论。厂商IP原有CDC豁免保留，没有新增用户豁免或放宽内部时序。实物PCB未确认，仅适用于R11。用户GUI保留；只停止本次batch进程，没有下载板卡、执行S04或进入下一步。

S03 R1返工交付（2026-10-30；实现运行2026-10-29）：采样定位write_bitstream的遥测收集热点，在确认GOLD许可证后仅设置本次进程内debug.enable_data_collection=0；对照调用正常返回，再从源码重跑综合/优化/布局/物理优化/布线/BIT生成，主工具退出0、implement回执PASS。新审计WNS +2.824ns、WHS +0.044ns、WPWS +7.000ns，TNS/THS/TPWS均0；20 BRAM Tile、16个数据RAM原语DOA_REG全1、内部未约束端点和组合环0。71份新运行文件含完整Hub子综合日志，关闭旧子日志缺失造成的本轮证据缺口，不伪造已丢失旧日志。

100项功能输入仍为2b832231f306f5dcc6c1559ce2da224f6ce1e4867194f8814376a4ac5ef03625，S02功能验收输入不变；project回执已按新生成工程状态正常刷新。BIT/LTX及哈希、全部当前报告、自检和独立验收入口见step_03/report.md、result.json、downloads.json、logs_index.json及rework_r1/verification.json。独立验收保持PENDING；全工程verify退出3，仅clean和hardware待后续步骤。原失败/超时交付保存在rework_r1/before与原日志中。仅完成S03，未执行S04、未下载板卡，PCB仍只声明适用于R11。

S03独立验收（2026-10-30）：已在新Vivado2026.1 Tcl会话只读打开本次routed.dcp，独立生成时序、check_timing、DRC、methodology、CDC（忽略豁免）、bus-skew、布线和BRAM结构报告。WNS +2.824ns、WHS +0.044ns、WPWS +7.000ns，负裕量及内部未约束端点/组合环均0；20块BRAM、16块DTCM的DOA_REG全1。独立重新导出的LTX与交付JSON相同，BIT头/负载及哈希匹配。507项封存产物、75份日志、100项功能输入和362项保护文件通过核验；进度文档提交时原稿另存独立验收目录，封存清单不改写。

原自检报告及result.json保留其提交时PENDING；本条与evidence/agent_steps/step_03/acceptance_20261030/report.md、checks.json补充独立通过结论。没有修改RTL、固件、golden、XDC、IP或下载文件，没有重跑综合/bitgen或执行S04。4项厂商Hub LUTAR-1及其他已说明警告保留，真实JTAG/板卡仍待S05，R11实物版本未确认。S04须把本机验证过的R1构建入口及会话设置纳入独立重建流程；不能仅复制BIT或旧DCP。全工程仍为PENDING_EXECUTION，仅clean待执行及hardware待实际板卡；下一步由用户指定S04。

S04独立验收（2026-10-30）：核对实际ZIP的102项文件、候选manifest、962项封存文件及本轮独立构建的9项当前离线回执，全部符合要求；独立核对136项登记输入、62条编译引用、6份MIF完整字值及新Hub子综合日志。另从同一ZIP新解压，实际执行独立入口及GCC固件构建，9份生成镜像与冻结输入一致；缺少alu.v的反例直接失败，没有祖先源码回退。362项生产保护文件未变。仅新增验收记录与进度登记，原报告和result.json保留提交时状态；提交时进度原稿另存acceptance_20261030/progress_before.md。

本次验收对象为delivery/source_candidate_20261030_162300_d25c1c.zip及clean_builds/20261030_162300_d25c1c；该独立目录的当前输入为d335349aecb17f93d9c492519ac0eea66abbda5154e8154da22090072b85fe87。其50MHz实现WNS +2.824ns、WHS +0.044ns、WPWS +7.000ns，LUT/FF/BRAM/DSP为6560/7892/20/0。恢复阶段只重跑了同包同输入下的项目刷新及剩余核查，原失败和新PASS均保留，没有使用解压前的旧DCP/cache。

下一步由用户指定S05。上板应使用clean_builds/20261030_162300_d25c1c/run.py及该目录evidence/demo.bit、demo.ltx，不把父目录旧生成工程或旧下载文件当作当前对象。PCB/R11确认和真实JTAG采集仍未完成。当前只完成同机独立重建验收，不宣称另一台机器、真实上板、开源发布或赛事提交已完成；本次没有执行S05。

S05交付（2026-10-31）：已复核S04独立验收及指定clean_builds/20261030_162300_d25c1c下载对象，1031项离线检查通过。Vivado2026.1/hw_server2026.1实际只读preflight退出0，但TARGET_COUNT=0；PARTS仅代表工具器件支持。PCB丝印、完整器件型号、供电及USB-JTAG/驱动可用性尚未确认，已请求用户信息。未下载、未发起硬件复位、未采集邮箱，真实重跑0/3。现有采集脚本在运行时探针/设备核验、failed、提交稳定性、心跳观察、周期比较及保留全部尝试方面的待补项已记录。当前输入与BIT/LTX保持S04验收版本，362项生产文件未改；没有用仿真HEX冒充实测，没有生成真实capture_receipt或硬件测量报告。report/hardware仅含待硬件说明。S05状态PENDING_HARDWARE、pass=false、独立验收PENDING；本轮停止S05，未执行S06—S08。记录及重算入口见evidence/agent_steps/step_05/report.md、result.json、inputs.json、logs_index.json和audit_offline.py。

S05 R1 历史交付（2026-10-31）：原目录的主机采集返工完成32项离线控制，当时JTAG目标数0，真实采集0/3，S05未通过，独立验收PENDING。当前新增维护绑定使用迁移 seal，不能把原R1报告、结果和旧路径校验器当作新目录的通过证据。本段依据原R1记录补写复制进度中乱码段的事实摘要；乱码原字节保存在R2的before进度原稿，原R1报告和结果不改写。

S05 R2 迁移后返工（2026-11-01）：当前接续根为活动工程内 board/z7_lite_7010_crc，旧目录只读。已有新位置完整构建及迁移 seal 经本轮只读核对，9项离线门槛、9份镜像、8份MIF、136项登记文件及123项主工程保护文件匹配；原S01—S04独立验收仍为原输入历史。维护的R1 s05.py绑定 local_builds/relocated_20261031，新BIT哈希以本轮R2输入记录为准。七项主机核查全部符合各自预期，32项离线控制通过；旧hardware/report入口和缺真实采集报告均被拒收。最新真实Vivado2026.1只读preflight目标数0，主机CLI退出3为PENDING_HARDWARE。没有下载、真实复位或真实采集，仍为0/3，无实测回执。新增R2验证器适配当前目录，旧R1报告/校验保留其历史范围；重复封存保护拒绝覆盖既有seal，失败日志保留。PCB/芯片丝印、匹配资料、供电与USB-JTAG/驱动仍待确认，真实LED和邮箱验证未完成。S05未通过，独立验收PENDING；未开展S06—S08。入口：evidence/agent_steps/step_05/rework_r2/report.md、verify_delivery.py。

S05 实物及官方资料补充（2026-11-01）：用户文字报告 PCB 为 Z7-LITE_ES1，贴纸 H251800347，芯片丝印 XC7Z010 / CLG400ABX2229，实物速度等级未知；本次未附照片原件，未声称已独立看图确认。随后收到官方通用手册及R11图纸链接，已取得中英文手册和PDF并保存哈希，官方PDF与工程保存件相同。当前器件参考、N18/50MHz、P16/PL_KEY1、P15/U12低有效LED、LVCMOS33及R11配置电压接法相符；手册标准型号的-1不等于ES1实物等级已确认。K1/SYS_RESET_N与K3/PL_KEY1须区分；R11 FT232HL与用户报告FT2232HL待核对。尚无ES1/R11明确对应依据，供电和JTAG连接亦经用户说明为尚未验证，下载继续阻断。最新只读preflight目标0、CLI退出3；未下载、未发起VIO复位、未采集真实邮箱，无实测回执。旧R2控制保持原范围。入口：evidence/agent_steps/step_05/physical_es1_20261101/report.md、checks.json、verify_update.py；S05未通过，未进入S06。

S05 只读链路检查（2026-11-01 23:01）：用户确认JTAG口数据线已接、电源灯持续亮，并更正FTDI丝印为FT232HL；明确本轮不下载、不复位、不改RTL/XDC。Windows实际枚举USB Serial Converter，VID0403/PID6014、序列号210241793374，设备OK/问题0，FTDIBUS及FTDI2.12.36.20签名驱动。新Vivado2026.1只读preflight识别唯一Digilent/210241793374目标，链上arm_dap_0与唯一xc7z010_1，FPGA IDCODE0x13722093；先前目标0记录保留。只读链路识别自检通过，实际供电轨未测，速度等级及ES1/R11对应仍未知。本轮无下载、VIO/板级复位或邮箱采集，三次真实重跑仍0/3，S05独立验收PENDING；未进入S06。当前入口为step_05/readonly_link_20261101_230114_24249f/report.md、checks.json、verify_link.py。

S05 只读资料接续（2026-11-02）：实际执行保存证据复核，确认2026-11-01 23:01的FTDI/JTAG/FPGA识别记录可重算；本轮未新扫硬件。查阅用户提供的微相官方仓库master树，快照SHA5b9554929e45310dd49b5297bb5f85ca34a21e69，未发现ES1命名资料；此结论仅限本次所查树及手册正文。新增docs/es1_board_confirmation_zh.md，列出本演示所用器件、四个PL端口、Bank/配置接法及实际速度等级的厂商确认清单和询证草稿；未联系厂商，未视作已确认。操作限制仍为只读，无下载、复位、RTL/XDC修改或真实邮箱采集。S05未通过，独立验收PENDING，未进入S06。

S05 固定硬件基准登记（2026-11-02）：用户确认 ES1 / H251800347 为 XC7Z010 CLG400 -1，并明确客服提供的 02_Z7-Lite硬件资料.zip 适用于该板。已读取 D:/Downloads 原包，归档六份文件、清单和哈希；包内14页原理图与先前公开R11 PDF逐字节相同，不能因此把实物标签改成R11。核图纠正此前错误：VCCO_0/K6=3.3V，VCCBATT_0/F11=1.8V，CFGBVS/M6直接接3.3V；R47上拉PROGRAM_B/L6。原XDC确有PL_KEY2和PL_LED2独立名称，同时又有GPIO别名，分别重复T12/U12，须只选一套；厂家XDC没有create_clock，当前CRC已有20ns时钟约束。当前器件和四个演示端口匹配，但当前封存构建仍为CFGBVS=GND、CONFIG_VOLTAGE=1.8，配置核对不通过，现有BIT不具备下载条件。旧“R11配置相符”结论由本次纠正取代；原报告、验收、seal和错误证据均保留。固定基准见docs/hardware_baseline_zh.md，本轮只更新文档与状态，未修改RTL/XDC、未构建、未重新连接硬件、未下载或复位。速度等级依据用户确认，未宣称JTAG读出了等级。S05保持未通过，三次真实运行0/3，独立验收PENDING，等待用户明确授权后再修正演示约束及重做受影响S03/S04检查；未进入S06。

S05 授权返工与真实上板（2026-11-02）：用户明确授权完整 S05 后，仅将 CRC 演示 XDC 的 CFGBVS/CONFIG_VOLTAGE 修正为 VCCO/3.3，并从新源码包 delivery/source_candidate_20261102_173954_d834d5.zip 在 local_builds/s05_es1_20261102_173954_d834d5 重建。10 条门槛命令退出 0、9 项离线门槛 PASS，136 项登记输入、9 份冻结镜像和独立依赖审计一致；新 BIT 为 717bd8cf…、LTX 为 facc5a5a…（LTX 未变因调试网表不变），旧 BIT 保留为历史。重建期间的项目生成 stdout 通道、日志器控制和 xsim.ini 失败均保留，并在独立句柄/本地 IP 库映射下通过，未删除失败或放宽门槛；重建封存为 rework_r3/seal.json。

首次真实采集 capture_20261102_182943_15e90a91 已完成下载和 VIO 映射核验，但 Vivado 在 7 位 HEX read_index 初值处拒绝单字符 0；失败发生在任何复位/扫描之前，该 attempt 与日志保留。修正只涉及主机采集脚本（初值写为 [format %02x 0]），另建 rework_r4 并重新封存，43 项主机控制通过。

r4 真实 preflight 识别唯一 Digilent/210241793374 目标与唯一 xc7z010_1（IDCODE 0x13722093）。实际采集 capture_20261102_183416_de2cae60 下载新 BIT/LTX，核验 VIO 实例/UUID/5 个探针后，执行三次 VIO 辅助硬件复位（非按键、非断电），每次运行做两次间隔≥1s 的 104 字邮箱扫描，共 6 次。12 例 CRC × 3 次运行与独立 zlib 全部一致（36/36），失败计数 [0,0,0]，邮箱提交后冻结且六份 HEX 内容一致，三次运行的周期字段完全相同；用户确认成功灯点亮、心跳灯持续闪烁。结果与 capture_receipt 见 report/hardware/capture_20261102_183416_de2cae60/report_387fc78b/。

S05 执行自检为 SELF_CHECK_PASS，独立验收保持 PENDING；未进入 S06—S08。重算入口 evidence/agent_steps/step_05/rework_r4/verify_delivery.py；阶段报告 evidence/agent_steps/step_05/report.md。
