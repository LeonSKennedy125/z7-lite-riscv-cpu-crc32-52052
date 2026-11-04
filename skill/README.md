# Skill：同步 valid/ready MMIO 加速器的证据化验证与复现

> 本 Skill 从本队“自研六级 RV32I＋Zicsr CPU + CRC32 MMIO 加速器”的实际失败与测量中提炼。它不是作品宣传页，也不依赖本队目录；拿走 `skill/` 目录即可用于另一颗软核、另一块板或另一个 MMIO 外设。**不申报 PYNQ Skill 加分**：本作品未使用 PYNQ。

---

## 1. 适用范围

适用：

- 单发射、顺序执行软核（或 MCU）通过**同步 valid/ready MMIO** 驱动一个加速器/外设；
- 外设有明确的寄存器契约、完成握手、错误/中止路径；
- 需要比较“软件实现 vs 硬件完整调用”的性能，并保留短输入不加速等真实结果；
- 需要从源码包独立重建、在真实板卡上采集、并让第三方复算。

不适用（需要另行适配）：

- AXI/AHB 多笔未完成事务、乱序响应、独立地址/数据通道；
- Cache 一致性、多核、乱序执行、TLB/MMU；
- 需要 DMA 大块搬运才能体现收益的加速器（本 Skill 的计费方法仍可用，但“CPU-fed”假设不成立）；
- PYNQ Overlay/PS 侧 Python 工作流（本 Skill 未覆盖）。

参考实现环境：Windows 10/11、Vivado 2026.1、Python 3.12、xPack GCC 15.2.0-1、XC7Z010。其他版本可按同样方法使用，但必须重新记录工具版本与哈希。

---

## 2. 使用前准备

| 输入 | 要求 |
|---|---|
| 外设契约 | 每个寄存器的地址、方向、位宽、读写副作用、完成/错误/中止条件 |
| 独立参考 | 算法黄金模型（如 CRC 用 `zlib.crc32`），不得由 DUT 反推 |
| 自检测试台 | 能观察握手、背压、撤回、复位、长度 0、尾部、非法访问 |
| 主机解析器 | 固定记录长度、magic/version、错误计数；能拒绝截断/多余/最后一项错误 |
| 构建入口 | 从源码包重建，不使用旧 DCP/cache/旧 PASS |
| 证据目录 | 命令、退出码、stdout/stderr、输入哈希、失败 attempt 分开保存 |

---

## 3. 方法（七步）

### 步骤 1：先写契约表，再写 RTL/测试

为每个寄存器写出“谁能写、什么时候生效、什么情况报错”。至少覆盖：

- 副作用发生的唯一时刻（如 `resetn & valid & ready` 的上升沿）；
- `ready` 是否只依赖寄存状态，是否可能经 CPU 控制路径形成组合环；
- BUSY 时写配置、重复 START、ABORT 与 START 同周期、长度 0、尾部不足 4 字节；
- 未完成请求撤回、复位/中止放弃任务、COMMIT 后写入；
- 非法地址/方向/字节使能是否完成握手并置 ERROR。

> 提示词模板见 [`templates/interface_contract_prompt.md`](templates/interface_contract_prompt.md)。

### 步骤 2：固定算法参数与独立参考

以 CRC32 为例，必须写清：多项式、是否反射、初值、最终异或、字节序。用 `zlib.crc32` 或标准向量生成 golden；**不要把 DUT 输出当 golden**。把 12 组向量（含空输入、ASCII、不同长度、边界）固定到 JSON，测试与主机解析器共用。

### 步骤 3：自检测试台 + 错误注入

测试台要能：

- 在握手完成沿检查副作用，而不是只看波形；
- 注入背压（`ready=0`）、撤回 `valid`、复位/中止、非法访问；
- 对 Load-use/两拍读等微架构特性做定向测试；
- 把“预期错误注入通过”与“正常功能通过”分开记录，不混为一个 PASS。

### 步骤 4：主机解析器负对照

解析器至少拒绝：

1. 少一个字/多一个字；
2. 最后一项错误；
3. 未知 magic/version/配置；
4. 非零错误计数；
5. 零周期/负周期/会话周期大于完整周期；
6. 重复 case id；
7. 非十六进制/空行；
8. 截断的 HEX；
9. 错误字节序。

> 本队实际用 9 类负对照；脚本示例见 [`scripts/verify_mailbox.py`](scripts/verify_mailbox.py) 的 `--self-test`。

### 步骤 5：三种计时口径，主要加速比只用完整调用

| 口径 | 起止 | 用途 |
|---|---|---|
| 软件周期 | 包围软件函数调用 | 基线 |
| 硬件完整调用 | 配置 + 搬运 + 轮询 + 状态/结果读取 + 调用开销 | **主要加速比分母** |
| 引擎会话 | START 接受到最后字节 | 解释引擎吞吐，不替代完整调用 |

保留每一轮、每一个 case；不选最快轮、不删短输入低于 1× 的结果、不把引擎会话当完整调用。

### 步骤 6：资源对照要披露“控制变体”

如果基线是“去掉加速器/改用软件回退”的控制变体，必须写清：

- 移除了哪些寄存器/逻辑/错误路径；
- 固件改了哪一行；
- 基线是否功能等价（通常不是）；
- 报告的是**全 SoC 净差**，不是纯加速器面积；
- 基线固件是否上板（通常没有，不能拿它的周期算加速比）。

### 步骤 7：证据门控与独立重建

每个门槛记录：输入哈希、工具版本、实际 argv/workdir、退出码、stdout/stderr 哈希、终止标记。失败 attempt 保留。最后从源码 ZIP 解压到新目录，重新编译/生成 IP/仿真/实现；不要用旧 DCP 或旧 PASS。执行自检与独立验收分开。

---

## 4. 提示词模板

- [`templates/interface_contract_prompt.md`](templates/interface_contract_prompt.md)：从接口描述生成契约表、定向测试和负对照。
- [`templates/evidence_gate_checklist.md`](templates/evidence_gate_checklist.md)：阶段证据门控清单（路径、输入、命令、失败保留、独立验收）。

模板是“让下一个题目直接套用”的骨架，不是本队作品的宣传文案。使用时替换外设名、寄存器、参考模型和板卡信息。

---

## 5. 校验脚本

### 5.1 `scripts/verify_mailbox.py`

用途：解析固定长度的邮箱 HEX，独立重算 CRC，检查 header、case 字段、周期字段；自带负对照自测。

```powershell
# 自测：生成 12 例、合成邮箱、4 类负向变异
python -B -X utf8 skill/scripts/verify_mailbox.py --self-test

# 校验真实邮箱（可一次给多份）
python -B -X utf8 skill/scripts/verify_mailbox.py `
  --dump run_0_scan_0.hex --dump run_0_scan_1.hex `
  --cases skill/examples/z7_crc_cases.json `
  --json out.json
```

- `--dump` 可重复；每份必须恰好 104 字（默认 v1 布局）。
- `--cases` 指向 case 定义；示例 [`examples/z7_crc_cases.json`](examples/z7_crc_cases.json) 用 xorshift32/ASCII 生成数据，并用 `zlib.crc32` 重算。
- 退出码：0 全部通过；1 有失败；2 参数/文件错误。
- 输出 JSON 包含每份 dump、每个 case 的期望/软件/硬件 CRC、周期、通过/失败原因。

### 5.2 `scripts/check_manifest.py`

用途：校验发布 manifest 的 SHA-256、缺失/多余文件、路径穿越、manifest 自排除。

```powershell
python -B -X utf8 skill/scripts/check_manifest.py `
  --root path/to/package --manifest path/to/package/release_manifest.json --json out.json
```

退出码：0 通过；1 哈希/文件不符；2 参数错误。

---

## 6. 失败条件与边界

- **没有独立参考**：只比较 DUT 的软件/硬件两路，不能证明 CRC 正确；必须用 `zlib` 或标准向量。
- **只测引擎会话**：短输入会严重高估收益；主要加速比必须用完整调用。
- **把主机脚本错误当 DUT 失败**：VIO/ILA 探针格式、HEX 宽度、USB 序列号、探针 UUID 先校验，再复位/扫描。
- **工具退出 0 就当通过**：Vivado/XSim 可能生成 0 字节 Tcl、未执行测试；必须查终止标记、日志和输入哈希。
- **基线功能不等价**：控制变体的资源差不是纯加速器面积；必须披露。
- **仿真/虚拟目标替代板卡**：XSim 只能证明模型；板级必须有真实会话、BIT/LTX 绑定和用户观察。
- **Windows 长路径**：调试核临时路径可能 146 字符限制；用稳定短 SUBST 盘符，退出后保留映射。
- **预编译 IP 库**：`xsim.ini` 重映射失败时设置 `sim.use_ip_compiled_libs=0`，本地编译 IP 模型。
- **迁移到 AXI/多核**：需要独立地址/数据通道、outstanding 事务、内存顺序/一致性处理；本 Skill 不提供这些保证。

---

## 7. 经验来源（真实失败）

| 失败/观察 | 提炼出的规则 | 证据 |
|---|---|---|
| S03 `write_bitstream` 打印成功后不返回，两次超时 240 s | 工具打印成功 ≠ 交付完成；先定位遥测/许可证/日志，再重跑；保留原失败 | `evidence/agent_steps/step_03/report.md`；`rework_r1/before/` |
| S05 `Designutils 20-1474`：7 位 `read_index` 写单字符 `0` | 探针 HEX 宽度先校验；失败发生在复位前，不能归因 DUT | `evidence/agent_steps/step_05/report.md` |
| `Chipscope16-302`：149 字符 > 146 字符 | Windows 调试核路径限制；用短 SUBST 盘符 | `docs/ai_collaboration.md` |
| `USF-XSim-11`：`xsim.ini` 读取失败 | 预编译 IP 库重映射问题；用本地 IP 模型 | `docs/s02_regression.md` |
| 自动生成仿真 Tcl 为 0 字节，退出 0 | 检查终止标记/日志/输入哈希；不信任退出码 | `docs/s02_regression.md` |
| 资源基线移除 CRC 逻辑、固件改软件回退 | 报告全 SoC 净差；披露控制变体；不冒充纯加速器面积 | `evidence/agent_steps/step_06/report.md` |
| 0/1/2/3 字节低于 1× | 保留全部数据；短输入固定开销主导 | `evidence/agent_steps/step_06/performance/results.json` |
| 硬件 HEX 与仿真 HEX 相同 | 确定性固件的预期结果；真实性靠会话日志/事件时序/用户观察 | `evidence/agent_steps/step_05/acceptance_20261102/report.md` |

---

## 8. 已验证效果（本队当前证据）

以下结果对应冻结版本 `crc50-s06-60bd9a8688114c57`，不是通用保证：

- CRC 单元：12 组独立 zlib 参考 + 39 项检查通过；9 类解析器负对照拒收（S02）。
- 整机：三次仿真复位、36 例 CRC、104 字邮箱、1025 个 BSS 字清零（S02）。
- 故障模型：timeout 与 STATUS.ERROR 两个实际固件故障模型符合预期（S02）。
- 实现：XC7Z010、50 MHz，WNS +2.824 ns、WHS +0.044 ns、WPWS +7.000 ns；LUT 6560、FF 7892、BRAM 20、DSP 0（S03/S04）。
- 干净重建：102 项源码包、9 项门槛、9 份镜像、136 项登记输入一致（S04）。
- 真实上板：三次 VIO 辅助复位、六次 104 字扫描、36/36 CRC、失败 0、LED 观察（S05 独立验收）。
- 性能：12 组 × 3 轮；4096 字节 6.765712×；短输入低于 1× 保留（S06）。
- 资源：全 SoC +430 LUT/+198 FF，BRAM/DSP 不变；基线差异已披露（S06）。
- Skill 脚本自测：`verify_mailbox.py --self-test`；六份真实 HEX 逐份校验；`check_manifest.py` 校验发布 manifest。S07 日志见 `evidence/agent_steps/step_07/`。

---

## 9. 可迁移示例

### 9.1 换算法：CRC32 → AES/SHA/校验和

- 保留 valid/ready、长度、DATA、RESULT、STATUS、COMMIT/邮箱结构；
- 把 `step_byte` 换成 AES/SHA 的状态机；`result` 可能需要多字（用邮箱/多寄存器）；
- 独立参考换成 Python `hashlib`/`cryptography`（或标准向量）；
- 重新定义“完整调用”的结束条件（最后一个 block + 结果读取）；
- 重新测短输入/长输入；保留低于 1× 的结果。

### 9.2 换外设：SPI/I2C/UART

- 契约表增加 FIFO 深度、半满/满、超时、错误标志；
- `ready` 仍只依赖寄存状态；不要让它组合依赖 `valid`；
- 主机解析器增加“部分传输/超时/错误标志”负对照；
- 板级采集可用 ILA/VIO 或逻辑分析仪；不要把仿真当板级。

### 9.3 换板卡：7010 → 其他 AMD FPGA

- 保留同一 RTL/固件；只改 XDC、时钟、复位、IP 配置；
- 重新跑综合/实现/时序/资源；不要用旧板卡的 BIT/时序；
- 重新做板级身份核验（器件、IDCODE、USB 序列号、配置电压）；
- 记录新板卡的实际电压/引脚依据；不要套用旧板。

### 9.4 换总线：MMIO → AXI4-Lite

- 增加独立地址/数据通道、AW/W/B/AR/R 握手、outstanding 限制；
- `ready` 语义改为 `AWREADY/WREADY/ARREADY`，并处理 B/R 响应；
- 增加“多笔未完成/乱序响应/错误响应”的测试；
- 本 Skill 的“完整调用计费”仍适用，但“CPU-fed 单笔”假设不再成立。

---

## 10. 文件清单

```text
skill/
├── README.md
├── scripts/
│   ├── verify_mailbox.py
│   └── check_manifest.py
├── templates/
│   ├── interface_contract_prompt.md
│   └── evidence_gate_checklist.md
└── examples/
    ├── z7_crc_cases.json
    └── README.md
```

---

## 11. 许可与第三方

- 本 Skill 的文本与脚本由本队编写，随作品采用 **MIT** 发布（见 [`license/license.txt`](../license/license.txt)）。
- 示例中的 CRC 参数与 `zlib.crc32` 参考来自公开标准；Python 标准库 `zlib` 不随本 Skill 分发。
- 不包含 AMD Vivado 安装包、IP 源码、厂商原理图或用户提供的设计文档。
- 不把 AMD 生成文件（如 `demo_cpu.v`）或厂商资料纳入本 Skill 的许可证范围。

---

## 12. 最小使用示例

```powershell
# 1) 自测脚本（不需要本队工程）
python -B -X utf8 skill/scripts/verify_mailbox.py --self-test

# 2) 校验一组真实邮箱
python -B -X utf8 skill/scripts/verify_mailbox.py `
  --dump path/to/run_0_scan_0.hex `
  --cases skill/examples/z7_crc_cases.json `
  --json out.json

# 3) 校验发布包
python -B -X utf8 skill/scripts/check_manifest.py `
  --root path/to/package `
  --manifest path/to/package/release_manifest.json
```

把 `path/to/...` 换成你的工程路径；脚本不依赖本队绝对目录。
