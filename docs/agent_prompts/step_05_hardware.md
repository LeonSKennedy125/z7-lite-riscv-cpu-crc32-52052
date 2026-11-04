请执行用户本轮指定的S05重验或返工，只执行本步。

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

先读docs/agent_prompts/common.md、docs/hardware_baseline_zh.md、migration/current.json、当前S05报告和evidence/agent_steps/step_05/acceptance_20261102/report.md。已有S05已通过，不因旧提示词自动重复下载；本轮若未指定S05重验/返工，核对当前状态后报告正确下一入口。

本步按实际指定范围执行：
1. 用evidence/agent_steps/step_05/rework_r4/s05.py check核对当前R4指针、seal、源码包、BIT/LTX及主工程保护。硬件为xc7z010clg400-1，配置CFGBVS=VCCO、CONFIG_VOLTAGE=3.3，PCB仍记录Z7-LITE_ES1。
2. 已有授权见rework_r3/authorization.json及R4记录，不重复索取已有效授权。真实重采须属于本轮指定范围，先核对连接及授权USB序列号210241793374，不因已通过就跳过身份核验。
3. 核对唯一器件DID/IDCODE及五个VIO探针：read_data、committed、failed为输入，read_index、restart为输出；位宽/端口索引与当前LTX一致。邮箱完成标志committed不混用CRC STATUS.DONE。
4. 如本轮指定真实重采，按R4流程做三次VIO辅助复位，每次committed清零后再完成，每轮双份完整104字扫描、间隔至少一秒且逐字稳定。准确记录复位方法，不写成按键或断电。
5. 用独立zlib核对三轮36例CRC、错误数、配置和周期；保留周期差异、失败和部分采集，不挑选最快/最好的一轮。
6. 真实报告绑定对应attempt的LED观察、BIT/LTX、Vivado日志、事件和HEX。仿真/模拟控制不当实测；只复核既有证据时明确没有重做硬件操作。
7. 修复影响RTL/固件/IP/约束/工具时列差异，重跑受影响S02—S04，用新配套文件采集。保护已验收原件，不将旧seal重标新执行。

验收出口：
- 本次范围、实际执行与复用证据明确，路径/输入/下载/采集对应。
- 真实重采满足36例CRC、零失败、三轮稳定扫描及真实观察；只读复核不冒充新实测。
- 历史独立结论保持原范围，新返工自检与独立验收分开，不自动执行S06。
