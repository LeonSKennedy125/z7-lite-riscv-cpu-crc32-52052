# 构建入口与实现报告

完整步骤见 [README](../README.md) 和 [复现指南](../docs/reproduction.md)。

- `../run.py`：工具链、固件、工程、仿真和实现的统一 CLI。
- `../scripts/build.tcl`：七个 IP 的配置、RTL/约束加载、XSim 及实现命令。
- `../scripts/rtl_files.txt`：实际参与构建的 RTL 清单。
- `../constraints/board_r11.xdc`：已验收的 ES1 有效引脚、时钟及电气约束。
- [已有资源/时序报告](../evidence/agent_steps/step_06/resources/)。

新的 Vivado 工程由脚本生成在 `b/p/demo.xpr`；工具安装及缓存由复现者在本机准备。
