# 资源与时序判读

## 不混用阶段和范围

本工程历史报告的综合资源为LUT6284、FF7164；布线后为LUT6300、FF7865。二者不互相覆盖。顶层带ILA/debug hub、时钟与复位逻辑，资源不是纯CPU核。BRAM Tile88对应87个36K及2个18K块，不是88字节，也不是DTCM单独用量；DTCM结构审计另有64个RAMB36E1。DSP为0不能独立证明没有乘法能力，M是否接入须核对RTL和BD。

解析器使用表头及资源名，支持常见Slice/CLB名称。不认识的新格式、缺报告、缺必需字段返回null/INCOMPLETE，不能默认0。示例值来自原始rpt；未来运行以自己的输出为准。

## 片内时序的检查条件

- WNS/WHS/WPWS均非负，TNS/THS/TPWS及各失败端点数均0。
- `no_clock`、`unconstrained_internal_endpoints`均0，且有Routed状态及clock报告。
- 持续列出no_input_delay/no_output_delay，不用虚构延迟凑齐约束。
- 解析通过仍不等于完成DRC/methodology、CDC、reset recovery/removal、bus skew和BRAM控制扇入审计；这些必须查看独立报告。

本项目历史数据：WNS+0.132ns、TNS0、WHS+0.050ns、WPWS+2.357ns；CPU约束6.250ns，即160MHz。片内通过不代表已达到设计文档约1ns建立余量。输入35/输出71项延迟缺失，板级接口时序仍待确认。

## 时钟频率不是 Fmax 或实测频率

`clocks.rpt` 中有50MHz输入、160MHzCPU及调试时钟。脚本返回所有时钟，禁止默认取最大值作为CPU主频。新工程要根据时钟名称、MMCM接线和被分析路径选择目标。

`1000/period_ns` 是约束频率。没有逐档实现与时序闭环时，不声明最大稳定频率；没有示波器/计数测量时，不声明板上实测频率。不要简单以 `period-WNS` 推断已验证Fmax。

## 推荐统一证据字段

analysis.json保存资源/时序/时钟、报告来源与SHA256、原日期和工具、源绑定、约束缺口和检查状态。构建wrapper还保存输入前后清单、克隆修改说明、完整命令与工具日志。发布报告引用这些文件，区分历史结果、本轮解析、本轮构建和板级实测。

## 可复用的报告分析提示词

```text
请使用 vivado-automation 分析给定原始报告，不启动构建或修改设计。
输入：utilization=<路径>；timing_summary=<路径>；clocks=<路径>；源码清单=<路径/无>。
先识别工具、器件、报告日期和Design State，分别列LUT/FF/BRAM/DSP及WNS/TNS/WHS/THS/WPWS/TPWS。
确认CPU目标时钟，不把最大频率时钟直接当主频；列约束缺口和methodology/CDC/板级证据缺口。
缺失数据用null/未证明，不补零；源码不匹配则阻止当前源码通过声明。
只在证据支持的片内或系统范围给结论，附原文件与哈希。
```
