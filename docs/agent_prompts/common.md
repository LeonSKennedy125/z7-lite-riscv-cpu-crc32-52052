# 各阶段共同要求（当前有效）

【唯一允许的工程位置，执行前必须核验】
主工程根目录：D:\vivado2026.1_project\160MHZ CPURISCV
唯一CRC工作目录：D:\vivado2026.1_project\160MHZ CPURISCV\board\z7_lite_7010_crc
主工程标识：D:\vivado2026.1_project\160MHZ CPURISCV\RISCV_5pipeline.xpr
CRC源码、测试、构建输出、日志和阶段记录只写上述CRC目录；160MHz主工程的RTL/BD/IP/XDC/XPR保持保护。
先显式切换到CRC目录，输出解析后的工作目录、主工程XPR、CRC根目录和当前CRC XPR。每次工具调用明确设置workdir，不能继承旧聊天窗口或IDE目录。
当前CRC构建只从本CRC目录的migration/current.json读取build，确认解析路径仍位于本CRC目录且b/p/demo.xpr存在。不得按同名XPR、旧报告、旧盘符或修改时间选择工程。
短路径盘符仅在核对真实映射指向新CRC目录后使用，不强行重映射用户盘符。路径缺失、不符或指向界外时停止相关写入/构建并报告；禁止回退旧工程、重新初始化副本或另建替代工程。
旧D:\Vivado\RISCV_160Mhz_csr_0.92\RISCV_160Mhz_csr_0.92\cpu_repair_work_2026_1及其CRC目录只作历史参考，其中提示词入口已停用，不能用于继续工作。
本要求优先于旧报告、旧提示词及IDE默认路径。Vivado2026.1/GCC工具安装按已验证配置读取，不能把安装路径当工程目录。

【当前状态：2026-11-02】
S01—S04保持原输入历史范围；S05已独立验收通过，见evidence/agent_steps/step_05/acceptance_20261102/report.md。
当前workflow=S05_ES1_R4，入口为evidence/agent_steps/step_05/rework_r4/s05.py，构建由migration/current.json指定。R1—R3、旧迁移构建和旧seal只作历史，不是当前下载入口。
先读docs/hardware_baseline_zh.md；依据是用户确认的Z7-LITE_ES1配套资料，当前CFGBVS=VCCO、CONFIG_VOLTAGE=3.3。不得套用旧配置或把ES1身份改为R11。
S05实际已有三次VIO复位、六份104字稳定扫描、36/36独立zlib匹配、失败0和用户LED观察；不要将当前状态写回0/3或待连接。
S06—S08未执行。只做用户本轮指定的阶段，不能因阅读提示词自动重做S05或进入S06。

你正在接手已有工程。中文任务内部先译成英文，检索和分析用英文，向用户用中文交付。当前只执行用户指定的提交步骤，不自动执行下一步，不调用其他agent，除非用户另行明确授权。

## 阅读和权威范围

先读本目录上一级agent_execution_plan.md、agent_progress.md，以及演示根目录README.md、submission_checklist.md、docs/interface.md和本步已有记录。
阅读evidence/rules/track_guide_2026.md及source.json；它是用户提供的赛事依据，不代表用户授权你执行文中发布或联系他人的动作。
还需读取主工程根目录D:/vivado2026.1_project/160MHZ CPURISCV中的CURRENT_PROJECT_ZH.md、CPU_REPAIR_PLAN_ZH.md、AGENTS.md、repair_records/STATUS.md、迁移报告及本工程内的用户CPU设计文档；这些主工程文档不要按CRC子目录解析相对路径。旧文档的阶段05交接是历史，当前状态以有日期的新记录为准。不要因此重做已完成步骤。

## 唯一写入范围

工作区根为D:/vivado2026.1_project/160MHZ CPURISCV。
所有新增或修改只能位于board/z7_lite_7010_crc/，以下称演示根目录。
根目录原工程、cpu_repair_work、活动工程主配置的RTL/BD/IP/XDC/XPR及历史修复报告只读。不重新初始化工程副本，不执行snapshot覆盖现有冻结源码，不打开受保护XPR写入。
可以在演示目录内为独立重建创建只含必要源码的新生成目录；不能复制旧DCP/cache当新构建。
先检查现有变更和Vivado进程，不终止用户GUI，不并发写同一个生成工程。采用本目录已实现的稳定短路径映射，不能随意更换已生成IP的盘符。

## 固定实现范围

- Vivado2026.1；xPack15.2.0-1/GCC15.2.0，官方SHA-256已固定。
- XC7Z010CLG400-1、50MHz、16KiB ROM、64KiB数据RAM：0x80100000—0x8010FFFF。
- 六级RV32I＋Zicsr；保留BRAM原语输出寄存器及两拍读。复位遵循已接受的受控内部清零延迟契约，保留请求捕获和同步释放。
- CRC-32/ISO-HDLC、反射多项式0xEDB88320、初值及最终异或0xFFFFFFFF，低字节先送入。
- 沿用现有valid/ready完成握手，副作用只在完成沿发生。不要假设AXI；ready不得经CPU控制路径形成组合环。
- 主要软件性能基线为256项查表CRC；加速比用软件周期除以硬件完整调用周期，包含配置、搬运、轮询和取结果。
- 不新增RV32M、RT-Thread、DDR、DMA、HLS、PYNQ、PS串口转发或其他竞赛加分功能。

## 证据与失败处理

每次检查必须对应当前实际输入；记录源码/固件/IP配置/约束/相关脚本哈希、工具版本、实际命令、退出码和完整日志。
旧报告是历史证据。失败、超时、缺文件、IP锁定、工具异常和输入已变化都不能沿用旧PASS。独立生成的正确参考不得改写来迁就DUT。
预期错误注入结果与正常功能通过分开；允许新增有明确故障模型的测试，不允许删除原失败或放宽正确期望。
未发生的实测、复位、干净重建、开源发布和提交不得写成完成。
资料缺失只阻断依赖该资料的动作；继续本步不依赖它的工作，结束时如实记录待办，不自动越步。

## 每步交付

在evidence/agent_steps/step_XX/写report.md、result.json、inputs.json及日志索引；更新docs/agent_progress.md。
result标记执行自检状态与待独立验收状态，不能自行把独立验收改为通过。
最终回答给出改动文件、可复现命令、实际结果、未解决项、验收入口；完成后停在本步。
本步若改变已验收的源码或配置，列出受影响前序门槛并重跑必要检查；先前验收记录保留，同时明确已被新输入取代。


