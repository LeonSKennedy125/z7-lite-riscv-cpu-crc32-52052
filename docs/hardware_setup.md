# 板卡与连接

目标板卡为 Z7-LITE_ES1，用户核对的板卡标识 H251800347，器件 XC7Z010CLG400-1。设计由 PL 运行，USB-JTAG 为 FT232HL；正式记录中的目标序列号是 210241793374。

| 信号 | FPGA 引脚 | 配置 |
|---|---|---|
| 50 MHz 时钟 | N18 | 20 ns 时钟约束 |
| 复位按键 | P16 | 低有效 |
| 成功灯 PL_LED1 | P15 | 物理低有效，逻辑成功条件为 committed 且错误计数为 0 |
| 心跳灯 PL_LED2 | U12 | 物理低有效，分频计数指示时钟活动 |

电气标准 LVCMOS33；配置属性 `CFGBVS=VCCO`、`CONFIG_VOLTAGE=3.3`。依据用户确认的 ES1 配套硬件资料，摘要见 [es1_board.json](../evidence/vendor/es1_board.json)。`constraints/board_r11.xdc` 是沿用的源文件名，其有效配置按 ES1 验证记录确定。

1. 使用板卡规定的供电方式，核对电源指示。
2. 连接板载 USB-JTAG，确保 FTDI 驱动与 Vivado Hardware Manager 可识别目标。
3. 关闭其他 Hardware Manager 对同一 target 的连接，避免并发占用。
4. 核对 PCB 与完整芯片型号。不同版本板卡须先依据其资料核对引脚、电压和时钟。
5. 运行 [runtime preflight](../board/runtime/README.md) 记录设备身份，再执行下载和采集。

成功灯的逻辑条件来自固件提交与邮箱错误计数；心跳灯表示时钟计数器活动。完整 CPU 计算结果由邮箱 CRC 与参考比对确认。
