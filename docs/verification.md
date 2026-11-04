# 验证结果与原始数据

## 正式板级数据

[data/hardware/s05/](../data/hardware/s05/) 保存 2026-11-02 正式验收对应的六份原始 HEX、Vivado/stdout 日志、事件流、设备身份、LED 观察、结果 CSV/JSON 与采集回执。原始文件按原字节复制；其中的绝对路径和状态字段保留各自记录时点，当前验收结论以 [S05 独立验收报告](../evidence/agent_steps/step_05/acceptance_20261102/report.md) 为准。

三轮 × 12 例 = 36 例 CRC 全部匹配，每轮两次 104 字扫描逐字相同。独立参考由 Python `zlib.crc32` 计算。空输入、`123456789` 以及 1、2、3、4、7、16、64、256、1024、4096 字节的确定性向量全部保留。

## 补充重复性记录

[report/demo/runs_20261104_120839/](../report/demo/runs_20261104_120839/) 是另一批已保存的三轮演示，含六份 HEX 与 Vivado2026.1 日志。日志记录目标、器件、PROGRAM_END、三次复位和 `DEMO_DONE 3`。它是独立时点的补充记录，不修改正式验收的原范围。

## 仿真与实现

[sim/results/](../sim/results/) 收录此前从独立源码包解压重建得到的 CRC、存储、整机、故障与检查器回执，以及三份整机仿真邮箱。回执含其原始构建输入和日志标识；本次开源整理未将这些结果改写为新仿真。

- [资源与时序目录](../evidence/agent_steps/step_06/resources/)：基线和加速配置原始报告。
- [完整性能 CSV](../evidence/agent_steps/step_06/performance/results.csv)：三轮全部用例。
- [汇总性能页面](../evidence/agent_steps/step_06/performance/index.html)：周期、加速比、资源图表。
- [源码与实测绑定](../evidence/publication/source_binding.json)：固件、下载文件、最终报告与发布变化范围。

## 复算

```powershell
python -B -X utf8 scripts/verify_saved.py
python -B -X utf8 skill/scripts/verify_mailbox.py --self-test
```

第一个脚本核对全部已收录实测/演示/仿真邮箱、双扫描一致性、补充演示日志与数据对应关系，以及下载文件和最终报告哈希。第二个脚本检查正确样本和四类人为坏样本。新运行会产生独立结果，不能凭已有 PASS 文件判定新运行成功。
