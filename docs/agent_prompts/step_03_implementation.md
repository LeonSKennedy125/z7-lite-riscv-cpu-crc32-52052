请执行提交步骤S03：完成XC7Z010的50MHz实现与下载文件，只执行本步。

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

先读取docs/agent_prompts/common.md；确认S02已独立验收通过。

本步任务：
1. 依据当前源码和IP配置执行Vivado2026.1综合、优化、布局、布线及bitstream生成。禁止使用旧主工程DCP、增量参考或历史结果作为此次完成证据。
2. 重点确认此前valid/ready组合环真正消除。遇到LUTLP-1须定位并修复逻辑；不得使用ALLOW_COMBINATORIAL_LOOPS、降级DRC或粗放false path掩盖。
3. 核查50MHz主时钟、MMCM派生关系、时钟锁定/复位释放、异步请求及内部同步路径。板级引脚依据现有厂商R11资料，实际PCB尚未确认时只说明“适用于R11”，不能宣称已核对实物。
4. 输出setup/hold/pulse width、TNS/THS、check_timing、未约束路径、时钟、DRC及methodology报告。内部有效端点不能遗漏约束；按实际语义解释LED和异步按键的例外，不要求所有厂商提示机械清零。
5. 检查BRAM Tile总数不超过48；数据RAM为16384×32，16个RAMB36E1的DOA_REG均为1，保留两拍读及64KiB完整地址判断。
6. 生成evidence/demo.bit和demo.ltx，记录对应源码、固件、约束、IP、工具版本及文件哈希。若为修复实现问题改动RTL，重跑S02受影响功能检查并标记前序证据更新。

验收出口：
- 布局布线后所有所需内部时序检查满足，无阻断bitgen的DRC，无未解决的内部组合环或遗漏时钟/端点。
- 下载文件、结构检查和报告实际存在且来自本次输入；不能用Kintex-7的160MHz结果替代。
- 归档所有剩余警告的影响及依据，按共同要求交付step_03后停止，不下载板卡。

