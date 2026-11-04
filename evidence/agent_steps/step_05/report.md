# S05：实物核对、JTAG 下载与三次真实重跑

2026-11-02，Asia/Shanghai。**执行自检通过（SELF_CHECK_PASS）；独立验收保持 PENDING。** 本轮完成 ES1 板级配置修正后的受影响 S03/S04 重建、真实 JTAG 下载、三次 VIO 辅助硬件复位和六次 104 字邮箱采集；12 例 CRC 在三次运行中全部匹配，失败计数为 0。未进入 S06—S08。

## 1. 实物与资料依据

- 实物：Z7-LITE_ES1，贴纸 H251800347，XC7Z010 CLG400 -1；依据为用户 2026-11-02 的明确确认及微相客服配套资料包 `02_Z7-Lite硬件资料.zip`（SHA-256 `cd1611dd4299dff40965edf87c3ab441481701ae405264aa0664ed0e9d722f8b`）。原理图为包内 `Z7-LITE_Rev1_1.pdf`，SHA-256 `7e6c992efc270e7884f4c9517f0966b43084a5621b0695bb6c37710de6d6e5ea`，与工程保存件逐字节一致。固定基准见 [docs/hardware_baseline_zh.md](../../../docs/hardware_baseline_zh.md)。
- 关键依据：VCCO_0/K6=3.3V，VCCBATT_0/F11=1.8V，CFGBVS_0/M6 直接接 3.3V；R47 上拉 PROGRAM_B_0/L6。对应设计属性必须为 `CFGBVS=VCCO`、`CONFIG_VOLTAGE=3.3`。未把 PCB 标签改写为 R11，也未盲填 `--pcb-revision R11`。
- 实际链路：本次新扫描为唯一目标 `localhost:3121/xilinx_tcf/Digilent/210241793374`；链上 `arm_dap_0` 与唯一 `xc7z010_1`，IDCODE `0x13722093`。Windows 同时枚举到 FTDI VID_0403/PID_6014、序列号 210241793374；当前驱动为 FTDI 2.12.36.20（已签名），只读快照见 `rework_r4/usb_driver_20261102.json`。
- 供应商资料中的 PL_KEY2/PL_LED2 与 GPIO1_17P/17N 为同一物理引脚的两套别名，演示只使用 N18、P16、P15、U12 四个顶层端口；时钟约束沿用 20ns 的 `sys_clk_50`，未重复添加。

## 2. 配置修正与受影响 S03/S04 重建

按用户完整 S05 授权（`rework_r3/authorization.json`）只修正 CRC 演示的两项配置属性，并从新源码包重建。`rework_r3/configuration_fix.diff` 记录了 XDC 变更：`CFGBVS VCCO`、`CONFIG_VOLTAGE 3.3`。

- 新源码包：`delivery/source_candidate_20261102_173954_d834d5.zip`，SHA-256 `29215665782df967c53d64461876c67d26d44efa4bf25f409011f893b9b47635`；构建 `local_builds/s05_es1_20261102_173954_d834d5`，初始 105 项文件逐字节复原，未复用旧 DCP/cache。
- 重建记录 `rework_r3/build_current.json`：firmware、project、unit、memory、simulate、faults、controls、implement、project、report 共 10 条命令退出 0；9 项离线门槛 PASS；独立依赖审计 PASS；冻结镜像 9 份一致。
- 新下载文件：BIT SHA-256 `717bd8cfddeecf7753c8adcff68e0ec0072c0b9ca283c28613c2ac0dd3788d5b`；LTX SHA-256 `facc5a5a95599c155598321dcd21d34b5d32f14b810fd7b6ef086fb8416ce6ba`。LTX 与旧版相同是因为调试探针网表未变；BIT 已因配置属性修正而变化，旧 BIT `5e47faab...` 不再作为下载对象。
- 重建前的失败现场均保留：首次项目生成 stdout 通道错误、日志器控制失败、xsim.ini 只写单字符等，见 `rework_r3/build_attempt_01/02/03.json`、`preserved_build_20261102_174120.json` 与 `stdio_diagnostic/`。未通过删除失败或放宽门槛取得 PASS。
- 封存：`rework_r3/seal.json`（SHA-256 `bfdeadd89057e580591fdfec9ea1fc51e48e57d37ac17fd514ffb906e6f50117`）绑定新构建与下载文件；`rework_r4/seal.json`（SHA-256 `a9ba2f5f7dfbf09a74dffe1d77919c1332b215b47e3cfba9e5cedf4fe1aa7a91`）叠加采集脚本修正。当前指针 `migration/current.json` 为 `workflow=S05_ES1_R4`、构建 `local_builds/s05_es1_20261102_173954_d834d5`。

## 3. 采集脚本修正与主机控制

首次真实采集 `rework_r3/attempts/capture_20261102_182943_15e90a91` 已成功完成下载并通过 VIO 实例/UUID/5 个探针映射核验，但在写入初始 `read_index` 值时失败：该 7 位探针在 HEX 进制下要求 2 个字符，脚本写了单字符 `0`（Vivado `Designutils 20-1474`）。失败发生在任何复位或扫描之前，原 attempt、日志和事件全部保留，未删除、未挑选。

该缺陷属于主机采集脚本，不涉及 RTL、固件、约束或下载文件。修正仅将初值写为 `[format %02x 0]`，见 `rework_r4/capture_fix.diff` 和 `change_manifest.json`。修正后的脚本在 `rework_r4` 通过 43 项主机控制（含错误 PCB、错误 USB 序列号、错误配置电压、探针歧义、部分读取、不稳定运行等负向模型；合成数据明确标记 `NOT_HARDWARE`），日志在 `rework_r4/controls.*`。

## 4. 真实下载与三次重跑

- 只读 preflight：`rework_r4/attempts/preflight_20261102_183328_87bceaaa`，唯一 Digilent/210241793374 目标、唯一 xc7z010_1、IDCODE `0x13722093`。
- 实际采集：`rework_r4/attempts/capture_20261102_183416_de2cae60`。Vivado 2026.1 批处理退出 0；下载 `demo.bit` 并加载配套 `demo.ltx`。运行期 VIO 实例 `vio`、UUID `1BE27D511A4C50DC974F3E22D2C609B9` 与 LTX 一致；5 个探针方向、端口、宽度全部匹配：`read_data`(IN/0/32)、`committed`(IN/1/1)、`failed`(IN/2/1)、`read_index`(OUT/0/7)、`restart`(OUT/1/1)。
- 三次重跑均由 VIO `restart` 输出发起的**辅助硬件复位请求**完成；没有声称为按键复位或断电重启。每次复位均观测到 `committed` 清零，随后固件重新完成 12 例 CRC。
- 每次运行做两次间隔 ≥1s 的 104 字邮箱扫描，共 6 次；每次都严格按索引 0—103 读取，扫描边界 `committed=1`、`failed=0`。六份 HEX 均 104 行，且三次运行的邮箱内容一致（六份文件哈希相同），证明邮箱提交后冻结。
- CRC：12 例 × 3 次运行 = 36 例，全部与 `s05.py` 内独立生成的 zlib 参考一致（软件 CRC、硬件 CRC、bitwise CRC 三路相同）；每次运行 `failed` 计数为 0；配置/固件字段一致（`0x43524331, 1, 50000000, 65536, 12, 0, 104, 7`）。
- 测量字段：三次运行的 `software_cycles`、`hardware_total_cycles`、`engine_session_cycles` 完全相同，`cycle_analysis_status=IDENTICAL_ACROSS_THREE_RUNS`。示例：4096 字节用例软件 69653 周期、硬件完整调用 10295 周期、引擎会话 10250 周期。
- 实物指示：用户在采集后确认 PL_LED1（P15，低电平点亮）保持点亮、PL_LED2（U12，心跳灯）持续闪烁；观察记录见 `rework_r4/observations_20261102.json`。

## 5. 交付物与重算入口

- 硬件结果：`report/hardware/capture_20261102_183416_de2cae60/report_387fc78b/results.json`（SHA-256 `9342136b78b44e019ae80e36b571d1ef36100212b087b4ceae9874635686b707`）及 `results.csv`。
- 回执：同目录 `capture_receipt.json`（SHA-256 `5278450b7aaa129b4ec27498064406b3574d0f574b19f473c694bc7329a80701`），绑定 attempt、BIT/LTX、六份 HEX、运行期目标/设备和用户观察。
- 总体自检重算：

```powershell
python -B -X utf8 evidence/agent_steps/step_05/rework_r4/verify_delivery.py
```

该命令只读重算封存绑定、三次复位事件顺序、624 个邮箱字、zlib 参考、回执与交付哈希，不访问硬件。

## 6. 范围与状态

- 未修改主工程 RTL/BD/IP/XDC/XPR；123 项主工程保护文件在重建与封存时均校验一致。
- 本轮下载只使用 `local_builds/s05_es1_20261102_173954_d834d5/evidence/demo.bit` 与配套 `demo.ltx`；没有用旧 BIT 配新报告。
- 历史 S01—S04 验收保持原输入范围；r3/r4 的构建、封存与失败记录均保留，不覆盖。
- 未执行 S06—S08，未开展性能优化或发布。独立验收保持 PENDING；真实采集自检通过不等于独立验收通过。
- 待外部独立验收：本报告、`result.json`、`inputs.json`、`logs_index.json`、`rework_r4/seal.json`、`validated_binding.json`、`capture_receipt.json` 及实际日志/HEX。
