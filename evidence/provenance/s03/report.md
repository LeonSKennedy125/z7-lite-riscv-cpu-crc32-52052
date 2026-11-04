# S03 R1独立验收

日期：2026-10-30，Asia/Shanghai。

结论：**S03通过独立验收，可以由用户指定S04。** 本结论覆盖XC7Z010/50MHz本次源代码实现的交付完整性、布线后静态检查和BIT/LTX来源，不代表完整干净重建或真实板卡已通过。本轮未执行S04、下载或硬件复位。

## 实际复查

先运行原交付的只读check_delivery.py：退出0，核对507项封存产物、75份日志记录及100项功能输入。随后在独立Vivado2026.1 Build6511674 Tcl会话中，只读打开当前evidence/routed.dcp，实际重新生成静态报告与LTX。未修改约束、参数、网表或原下载文件，未重新综合/布局布线/bitgen。

| 检查 | 独立结果 |
|---|---|
| 器件与时钟 | xc7z010clg400-1；输入和CPU周期均20ns，MMCM为20倍/20分频 |
| Setup WNS/TNS | +2.824ns / 0，失败端点0 |
| Hold WHS/THS | +0.044ns / 0，失败端点0 |
| Pulse width WPWS/TPWS | +7.000ns / 0，失败端点0 |
| 时钟与约束覆盖 | no_clock、constant_clock、内部未约束端点、multiple_clock、generated_clocks、loops及latch_loops均0 |
| 布线 | 12,901条可布线网络全部完成，路由错误0 |
| BRAM | 20 Tile；16个DTCM RAMB36E1的DOA_REG全部为1 |
| 握手反馈 | ready扇入起点仅为3个buffered寄存器，没有CPU valid等组合反馈 |
| Bus skew | 4项均满足，最差+18.936ns |
| CDC（忽略全部豁免） | CDC-3 Info 10项、CDC-9 Info 3项，没有Warning/Critical项；范围受report_cdc本身能力限制 |
| 端口/配置 | N18/P16/P15/U12，CFGBVS=GND，CONFIG_VOLTAGE=1.8；仅核对R11配置，不声称核对实物 |
| LTX | 从本次DCP独立重新导出，JSON与交付demo.ltx完全一致 |
| BIT | 目标7z010clg400，BIT头、同步字及完整负载长度通过核验，来源为正常退出的R1新实现 |
| 功能与保护 | S02八项功能证据和implement回执均保持当前有效；100项功能输入未变，362项受保护文件匹配 |

输入版本仍为2b832231f306f5dcc6c1559ce2da224f6ce1e4867194f8814376a4ac5ef03625。

BIT：cf66a03ac107090383b76defd0fa4a88a19b4614ca8334c09ac0ebb1ad0ea9d2，2,083,939字节。

LTX：facc5a5a95599c155598321dcd21d34b5d32f14b810fd7b6ef086fb8416ce6ba，11,485字节。

## 警告与实现来源

新DRC复现PDCN-1569三项、RTSTAT-10一项及ZPS7-1一项，均为Warning，无阻断项。methodology仍有4项LUTAR-1，位置全部在厂商dbg_hub FIFO复位逻辑，不在CPU/CRC或数据RAM控制中。没有降级严重程度、新建用户waiver或允许组合环。异步按键和两路LED的原有端口例外已逐项核对，未用其隐藏内部路径。

这些Hub警告保留，静态检查不能证明其异步复位绝无毛刺，也不能代替真实JTAG稳定性；该边界留给S05。详细说明见同目录methodology_resolution_report.md及原remaining_warnings.md。

核查R1实际源代码构建入口、正常退出的implement回执、write_bitstream成功结束及完整新Hub子综合日志。原开启遥测时的超时、失败交付和一次project刷新错误均保留；没有把失败日志当作当前成功命令。75份日志记录中含已说明的失败尝试，不能宣称所有归档日志都无错误。

R1使用本机GOLD/Vivado2026.1下已实测的进程内debug.enable_data_collection绕过；该参数不在公开参数列表，不宣称其为跨版本通用修复。本次独立静态会话未设置该参数。S04必须把R1构建入口、会话设置及其环境限制加入真实独立重建验证，不能只复用本次BIT/DCP。

## 证据与复查

独立会话：vivado-20261030-105250-1e338d21，Tcl模式，使用本目录为工作目录；只停止该会话，未停止用户GUI。

- independent_static.tcl：实际执行的只读检查命令。
- timing_summary.rpt、check_timing.rpt、methodology.json、drc.rpt、cdc_no_waiver.rpt、bus_skew.rpt、structure.tsv等：本轮新报告。
- independent.ltx：本轮导出的探针文件。
- checks.json、acceptance.json：独立判定与哈希。
- .vivado-ai/：独立会话日志，记录打开的DCP和实际命令。

从演示根目录复查已保存报告和当前文件：

```powershell
python -X utf8 evidence/agent_steps/step_03/acceptance_20261030/check_acceptance.py
```

需要重新运行静态工具时，在Vivado2026.1中只读打开evidence/routed.dcp，再source本目录independent_static.tcl，并导出本目录independent.ltx；原S03构建命令仍见原报告。重新跑实现不是本验收复查的前提。

本次仅更新docs/agent_progress.md的验收登记，提交时原字节保存在progress_before.md，前后哈希见progress_update.json。原自检的507项封存清单仍记录提交时版本，其中进度文档已合法更新；独立检查器使用保存原稿核对该项，其余506项仍核对原路径。原check_delivery.py在登记前已完整通过；登记后使用本独立入口核验，不改写原报告或封存清单。

全工程仍为PENDING_EXECUTION：仅clean待S04、hardware待实际板卡。实物PCB版本未确认，当前实现只声明适用于厂商R11资料。
