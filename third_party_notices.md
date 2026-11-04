# 第三方与生成文件说明

本队自研 CPU/CRC、固件、测试、脚本、文档与 Skill 使用 [MIT](license.txt)。该许可不覆盖以下 AMD 内容，也不授予 Vivado 软件或 IP 的工具使用权。

| 内容 | 来源及处理 |
|---|---|
| `src/core/demo_cpu.v` | Vivado 生成并经工程连接适配的结构化 HDL；保留 AMD/Xilinx 原版权头，作为 AMD 器件设计的连接文件提供，不改标为团队 MIT 原创 |
| 七个 AMD IP | 由复现者的 Vivado 2026.1 安装及 `scripts/build.tcl` 重新生成；使用者需有适用工具/IP 许可 |
| `board/runtime/demo.bit`、`demo.ltx` | 采用 AMD 工具/IP 的已测 FPGA 下载和调试产物；用于本说明指定的 AMD XC7Z010 设计，不作为本队开源 IP 重新授权 |
| Vivado RPT/日志 | 工具产生的测量和验证记录，原声明保留 |

AMD 官方 [Design Tools EULA](https://www.xilinx.com/content/dam/xilinx/licenses/ip/end-user-license-agreement.pdf) 第 3(a)(3) 节区分可修改组件、设计元素及分发形式；源码形式组件的接收者应具有适用的软件许可，机器可执行形式适用其对应条件。工具内 Included IP 的许可说明参见 [UG896](https://docs.amd.com/r/en-US/ug896-vivado-ip/Using-Fee-Based-Licensed-IP)。本项目保留供应商声明，AMD 部分按其适用条款使用；团队 MIT 不替代这些条款。

Vivado、GCC、Python 安装包，以及厂商原理图、客服硬件包、赛事指南原文和原始 CPU 设计文档不随仓库分发。硬件资料只保留事实摘要和来源哈希；所用第三方软件由使用者从各自官方渠道安装。

补充 Skill 的 `skill/references/track_requirements_excerpt.md` 为用户提供的赛事指南第 3.3 节原文节选，原来源和 SHA-256 保留；该引用原文的权利归原发布者，不作为团队 MIT 原创重新授权。
