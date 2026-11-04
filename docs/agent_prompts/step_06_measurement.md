请执行提交步骤S06：性能与资源对比并冻结功能，只执行本步。

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

工作目录：
D:/vivado2026.1_project/160MHZ CPURISCV/board/z7_lite_7010_crc/

先读取docs/agent_prompts/common.md、docs/hardware_baseline_zh.md、migration/current.json和evidence/agent_steps/step_05/acceptance_20261102/report.md。S05已在2026-11-02独立验收通过；本步使用R4封存与真实采集，不回退R1或旧迁移构建。没有真实采集时只列前置缺口，不能以simulation生成实测结论。

本步任务：
1. 从S05真实邮箱生成全部12组JSON、CSV、HTML和独立图表，重新核对数据来源、BIT/LTX和当前输入哈希。显示三次结果及周期差异，不只选最快一轮。
2. 报告查表软件周期、硬件完整调用周期、引擎会话周期、50MHz换算时间和软件/硬件加速比。主要加速比包含配置、CPU搬运、轮询及结果读取；短数据低于1也完整保留。
3. 构建同一器件、时钟、CPU、ROM/RAM容量、VIO/邮箱配置下的资源对照。可在隔离生成目录使用已存在resource_baseline，但审查其实际移除了什么、固件作了什么调整，必须准确披露。
4. 基线和加速版本都实际综合/实现，报告LUT、FF、BRAM、DSP、时序及差值。核对CPU和存储不被优化消失；不把历史160MHz主工程当50MHz资源基线，不把基线程序改变后的时间冒充同程序测量。
5. 缺少真实功耗测量时不写实测能效；不保证最低加速倍数，不为了数字临时改范围。性能不理想可以据实分析调用开销。
6. 冻结功能输入并形成发布版本哈希。除必要缺陷修复外停止优化；任何功能输入改变均需更新回归、干净构建和真实采集证据。

验收出口：
- 实测性能表、资源对比与原始文件可复算且对应当前版本。
- 对照配置差异清楚，失败/低加速案例不隐藏。
- 按共同要求交付step_06后停止，留下明确冻结版本供报告与打包使用。

