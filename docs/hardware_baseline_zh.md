# Z7-LITE_ES1 hardware baseline

用户确认的实物为 Z7-LITE_ES1 / H251800347，XC7Z010CLG400-1，板载 50 MHz 时钟，FT232HL USB-JTAG 序列号 210241793374。当前约束 CFGBVS=VCCO、CONFIG_VOLTAGE=3.3；约束文件的历史文件名 board_r11.xdc 不改变 ES1 身份。

硬件权威是用户提供的配套 ES1 资料包，SHA-256 cd1611dd4299dff40965edf87c3ab441481701ae405264aa0664ed0e9d722f8b。厂商资料和原图未获得公开再分发授权，故不进入公开候选；本地审阅包保留资料及检查记录。不能以 R11 或其他板卡资料代替。

实际三次 VIO 辅助复位、六份 104 字稳定扫描、36/36 zlib 匹配、失败数 0，S05 独立验收 PASS。新的使用者须核对自己的实物、供电和匹配资料后再下载。
