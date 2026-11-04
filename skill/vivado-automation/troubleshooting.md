# Vivado 故障与边界

| 真实观察/触发条件 | 排查步骤 | 可复用处理与停止条件 |
| --- | --- | --- |
| 已开GUI但MCP无活动session | 区分服务18090与Vivado控制端口8088；核对进程和Tcl webserver | 对既有GUI连接后先只读查工程，不另起一个工程冒充已控制该窗口 |
| toolchain仍指旧D盘 | 对比实时版本、可执行文件与toolchain.json | CLI显式指定bin；只在隔离副本重定位，不改全局许可证/PATH |
| 旧snapshot/最新索引误用 | 核对compile inputs、sources.json和实际文件hash | 新输出无旧生成目录/DCP；缺清单或改变时停止复用已有PASS |
| Windows深路径/带空格 | 查工具第一处文件打开错误和完整argv | 使用新短输出目录；保留argv列表与日志，不手工拼接含shell替换的命令 |
| BRAM输出寄存变化 | synth/opt/route分别查64个DTCM RAMB36E1的DOA_REG | 历史曾有综合64/64、物理阶段34/64，故不能只查综合；改变结构保护前需另行授权 |
| REQP-1839 / 异步控制扇入 | 查BRAM控制锥、复位来源、qualified寄存及真实原语 | 参考R1结构审计记录；不全局false_path，不降低DRC严重级别掩盖风险 |
| LUTAR-1 | 区分CPU复位同步器与生成调试核，查来源扇入 | 按层次定位并保留原规则，不凭一个总计把所有告警归CPU |
| NSTD-1 / UCIO-1 / CFGBVS-1 | 查真实板卡引脚、电气和配置电压资料 | 主工程资料不全时列系统待验证；不猜pin、电压或添加豁免 |
| 综合成功但WNS为负 | 确认阶段、目标clock、critical path起终点、组合逻辑/布线占比 | 先出瓶颈报告；RTL/约束优化不是本Skill默认授权动作 |
| 导入IP过时/模块引用没刷新 | 对照IP状态、主BD接线、生成wrapper和编译顺序 | 只在构建副本刷新；不能编辑.gen生成文件作为永久修复 |
| 仿真xvlog/xvhdl/xelab失败 | 从第一条错误定位库顺序、include、MIF和工具版本 | 复用R1导出的库顺序；不要拿Icarus模块通过替代实际IP全核仿真 |

典型记录来源：主工程 `repair_records/phase10/rework_R1/`、`repair_records/ip_upgrade_20261021/`、`repair_records/timing_recheck_20261028/` 与本轮MCP实际连接。历史错误只说明发生过该问题；当前是否存在必须读当前源码和当前证据，不重复执行历史修复脚本。
