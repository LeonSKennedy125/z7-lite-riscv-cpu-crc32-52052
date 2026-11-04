# 示例：Z7 CRC 邮箱 v1

`z7_crc_cases.json` 是本队 Z7-LITE 7010 演示使用的 12 例定义，用来演示 `verify_mailbox.py` 的用法，不是要求其他项目照搬 CRC 参数。

## 数据生成

- case 0：空输入。
- case 1：ASCII `123456789`（CRC 标准检查值 `cbf43926`）。
- case 2—11：xorshift32，种子 `0x13579BDF`，每例从同一种子重新开始；每步
  `x ^= x << 13; x ^= x >> 17; x ^= x << 5`，取低 8 位，所有操作为 32 位无符号。
- 参考 CRC：Python `zlib.crc32(payload) & 0xFFFFFFFF`；JSON 中的 `expected_crc` 只作交叉检查。

## 邮箱布局

- 前 8 字：magic `0x43524331`、version 1、clock 50,000,000、RAM 65,536、case_count 12、
  error_count 0、total_words 104、executed_checks 7。
- 之后每例 8 字：case_id、length、expected_crc、table_software_crc、hardware_crc、
  software_cycles、hardware_full_call_cycles、engine_session_cycles。

## 换成你的项目

1. 复制 JSON，修改 `header`（magic/version/clock/RAM/case_count/total_words/checks）。
2. 修改 `cases`：`kind` 支持 `zeros`、`ascii`、`hex`、`xorshift32`；也可以扩展脚本。
3. 修改 `verify_mailbox.py` 的 `payload()` 以支持你的数据生成器。
4. 保持“先独立重算 CRC，再比较邮箱”的顺序；不要把 DUT 的软件/硬件 CRC 互相当参考。
5. 负对照自测仍应通过；如果新布局改变了记录长度，更新 `header_words()` 和 `validate()`。

## 注意

- 示例不包含任何厂商原理图、AMD IP 源码或用户设计文档。
- 示例中的 CRC 参数是公开标准；`zlib` 是 Python 标准库，不随本目录分发。
