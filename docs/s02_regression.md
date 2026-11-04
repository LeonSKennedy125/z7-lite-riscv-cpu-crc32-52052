# S02 功能回归与固件故障检查

仅在演示根目录执行。使用 Vivado 2026.1、已有 Z: 稳定映射和 xPack GCC 15.2.0-1。

```powershell
python -X utf8 run.py firmware
python -X utf8 run.py unit
python -X utf8 run.py memory
python -X utf8 run.py simulate
python -X utf8 run.py faults
python -X utf8 run.py controls
python -X utf8 run.py report --source simulation
```

`faults` 是新增 CLI 动作，先要求当前 firmware 和 simulate 回执通过，再依次运行两个隔离的 XSim 测试顶层。它保持生产 RTL、固件 ROM、独立 zlib 参考、TICKS 及固件实际超时阈值不变，仅在测试台中修改第二个任务（123456789）的 STATUS 读响应。

| 模型 | 注入 | 必须观察到的固件行为 | 正常主机解析 |
|---|---|---|---|
| timeout | 屏蔽 DONE 位 | 实际轮询至少 2^20 ticks，CPU 将 errors 写成 1，实际 ABORT，硬件调用返回 0；随后参考不匹配累计 errors=2；后续任务恢复 | 拒绝该104字邮箱 |
| error | STATUS 读响应置 ERROR 位 | DONE/CRC 保持实际值，CPU 实际执行错误计数分支，errors=1，返回正确CRC，后续任务恢复 | 拒绝该104字邮箱 |

测试台监视 CPU 对 ELF 符号 `errors` 地址的真实 RAM 写事务，不写邮箱、不写 CPU 状态。每个模型独立生成 Vivado 控制台日志及故障邮箱副本，索引为 `evidence/firmware_faults.json`。预期故障的验证通过只表示故障处理符合预期，不能作为正常功能通过。`controls` 保留原9项邮箱负对照，并再次拒绝这两份实际故障邮箱。

正常整机 `simulate` 验证三次仿真复位运行的全部12组 CRC、104字邮箱、BSS 逐字清零以及第13/14次调用的数据位修改/恢复。三个邮箱分别保存为 `mailbox_sim_run_0.hex` 至 `mailbox_sim_run_2.hex`；兼容入口 `mailbox_sim.hex` 等于首次采集。报告逐一验证三份数据，明确标记 `source=simulation`、`board_measured=false`。

固件构建审查实际 ELF 的全部可执行字编码、ILP32/RV32I+Zicsr 属性、GP 依赖、重定位、分配段与 ROM/RAM 边界、空初始化可写数据、BSS/栈边界，以及当前无递归调用关系下的静态栈帧。输出 `firmware/out/audit.json`；监视器地址由本次 ELF 的 `symbols.hex` 给出。独立参考仍由主机 zlib 生成。

S01 的验收结论保留为对应旧输入的历史结论；脚本及测试改变后，必须重新运行受影响门槛并绑定新输入。S02 不运行综合、布局布线、下载、干净重建或真实板级复位。全工程 `run.py verify` 在后续实现/重建/硬件门槛未完成时仍应阻断全工程 PASS。

S02曾观察到工具生成的仿真Tcl为0字节，退出0但没有执行测试；检查器拒绝缺少终止标记的结果。当前采用UG835支持的 `launch_simulation -scripts_only -noclean_dir`，执行Vivado生成的compile.bat/elaborate.bat以保留源顺序和IP库参数，再从生成的simulate.bat取得实际snapshot，通过UG900的`-tclbatch`使用源码内固定的`scripts/run_sim.tcl`运行。`-noclean_dir`保留之前有效的正常邮箱采集，避免故障仿真清理共享目录；脚本、编译、展开和实际仿真仍重新执行，正常采集须满足当前回执的生成时间与哈希检查。所有测试台都有有限watchdog和`$finish`；继续要求退出码、无错误和精确终止标记，不能只凭工具退出0。

另一次USF-XSim-11发生于工具的预编译IP库重映射函数，在删除/重写xsim.ini后再次打开文件时失败。当前按UG937的标准流程设置 `set_property sim.use_ip_compiled_libs 0 [current_project]`，本地编译本工程生成的IP仿真模型，绕开该预编译库重映射路径；读回设置并记入每次日志。仍使用2026.1生成模型和XSim标准原语库，不修改工具安装、IP功能参数或DUT期望。相关失败、英文文档检索及当前全回归证据分别保留。
