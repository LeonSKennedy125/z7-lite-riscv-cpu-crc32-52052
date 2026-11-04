# Z7-LITE_ES1 下载与采集

本目录提供正式实测对应的 `demo.bit`、`demo.ltx`，以及原 S05 R4 采集 Tcl 和可移植 Python 入口。目标为 XC7Z010CLG400-1，50 MHz，CFGBVS=VCCO，CONFIG_VOLTAGE=3.3。下载产物的哈希见 `release_manifest.json`。

从仓库根执行：

```powershell
python -B -X utf8 board/runtime/run_board.py verify
python -B -X utf8 board/runtime/run_board.py preflight --vivado-bin D:/XILINX/2026.1/Vivado/bin
```

`verify` 只核对下载文件；`preflight` 只枚举目标并记录事件。核对实际供电、连接、PCB 和芯片后，根据本次 preflight 输出创建身份 JSON：

```json
{
  "pcb_revision": "Z7-LITE_ES1",
  "USB_serial": "210241793374",
  "device_idcode": "0x13722093",
  "device_did": "<本次 preflight 实际设备标识>",
  "target": "<本次 preflight 实际 target>",
  "physical_verified": true,
  "confirmed_for_this_capture": true,
  "power_and_JTAG_verified": true,
  "observed_at": "<本次核对的真实 ISO 时间>"
}
```

```powershell
python -B -X utf8 board/runtime/run_board.py capture --identity D:/work/board_identity.json --vivado-bin D:/XILINX/2026.1/Vivado/bin
```

采集入口校验目标、器件、VIO 端口及下载文件；执行三次辅助复位、六次邮箱扫描，并调用仓库 `skill/scripts/verify_mailbox.py` 独立核对 CRC。实际灯光观察单独记录。新结果保存在本目录 `captures/` 下。

控制台入口及已有数据回放见 [演示控制台](../../report/demo/README.md)。本目录 BIT/LTX 是原正式实测下载产物，保留 AMD 工具产物声明，参见 [第三方说明](../../third_party_notices.md)。
