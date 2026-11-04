# 验证故障清单

| 触发/现象 | 首先核查 | 最小定位/处理 |
| --- | --- | --- |
| 工具返回0但TB有失败 | SUMMARY failures、FAIL/FATAL、检查数量 | 本包严格判定；不把 `$finish` 等同成功，不改原断言 |
| load-use后另一源错误 | ID_EX retain_en/data、save、MEM_WB Forward_valid/Wen_out | 用两源分别来自load和即将离开WB的短程序；检查保留值及恰好一次提交 |
| trace缺/多一条 | wb_en、rd是否x0、flush/cancel、drain、重复save | 先比PC/rd/值和顺序，不只比最终RF；非写回指令另看周期事件 |
| 测试历史报告能过，新目录失败 | 工具bin、XPR路径、COE/MIF、当前RTL哈希 | 不复用旧快照PASS；在隔离副本生成编译输入，保留错误日志 |
| legacy复位测试失败 | 原断言是否要求立即内部清零 | 保留历史失败分类，使用R1新契约测试；不把旧测试改成新期望 |
| Icarus不支持某SV语法 | 编译第一处报错，不先改DUT | 改用XSim；当前四套测试已在两后端运行，未来版本仍需复核 |
| 找不到XSim/库 | --vivado-bin和所选工具版本 | 显式指定当前bin，不改全局PATH或许可证；先用不含IP的模块套件 |
| I_ROM程序不对 | XCI Coe_File、生成MIF、程序hash、PC索引 | 默认工程COE是phase07程序，不等同全核case程序；R1 run用case MIF，在副本运行 |
| RAM测试地址读回0 | 完整有效地址、ram_hit、字节选通、两拍延迟 | 先查0x80100000..0x8013ffff，不添加旧地址别名；非对齐访问不在支持范围 |
| CSR/IRQ通过但板级没反应 | 主BD的sys_exception是否接线 | 单元注入和层次force只证明模型路径；补实际顶层接口与板级验证需另行授权 |

每次只保留证据支持的假设。若缺少波形或独立golden，输出具体缺口；不能以降低严重级别、删除失败用例或修改正确期望闭环。
