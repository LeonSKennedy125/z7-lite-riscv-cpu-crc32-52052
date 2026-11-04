# 演示系统接口

所有新增寄存器使用字对齐32位访问；原CPU处理的非对齐非法store不产生总线事务。对实际到达外设的非法地址、方向和be请求，外设完成握手并置ERROR，不改变正在执行的配置。所有副作用仅在CPU时钟上升沿resetn、valid、ready同时为1发生。

| 地址 | 访问 | 定义 |
|---|---|---|
| 0x80200100 | W | CTRL bit0 START，bit1 ABORT；ABORT优先，清任务及CRC错误，不清自由运行计数器 |
| 0x80200104 | R | STATUS bit0 BUSY，bit1 DONE，bit2 ERROR |
| 0x80200108 | RW | 字节长度，BUSY时写入报错且不改变长度 |
| 0x8020010C | W | DATA低字节在先。BUSY且缓冲未空时ready=0；剩余不足4字节只处理有效尾部 |
| 0x80200110 | R | 最终CRC32；START和ABORT清为0 |
| 0x80200114 | R | 启动完成沿至最后字节处理沿的周期，含喂数间隙；空输入为0 |
| 0x80200118 | R | 32位自由运行TICKS，复位清零，差值按无符号模2^32计算 |
| 0x8020011C | W | COMMIT写1，在CRC空闲且未提交时冻结邮箱 |
| 0x80200200～0x802003FC | RW | 128字结果邮箱；提交后读取，后续写入报错且不改变内容 |

START接受非空长度时置BUSY；空长度立即DONE且RESULT=0。重复START报错但保留当前任务。闲置时写DATA立即握手并报错，不永久阻塞。复位、中止会放弃未完成任务。撤回valid的未完成数据请求不能更新外设。

ready只由寄存的缓冲占用状态决定，不依赖valid、地址或CPU控制信号，防止与主核等待链形成组合环。缓冲处理期间，其他寄存器访问同样可等待至缓冲排空，最多4周期。ABORT在实际完成握手时优先于START。

原0x80200020／40在本演示SoC中为按be更新的32位数码管／LED寄存器；0x80200050为只读计数器。这是本演示系统的明确约定，不等于竞业达实验箱的真实寄存器语义。

## 邮箱协议v1

前8字：magic=0x43524331、version=1、clock_hz=50000000、ram_bytes=65536、case_count=12、error_count、total_words=104、executed_checks=7。最后字段表示执行了边界、逐位CRC及数据修改／恢复检查；是否通过仍由error_count和主机独立比对判定。

之后每例8字：case_id、length、expected_crc、table_software_crc、hardware_crc、software_ticks、hardware_full_call_ticks、engine_session_ticks。主机固定读取104字，拒绝缺字、多字、最后一例错误、未知配置或非零错误数。未使用的24个邮箱字不作为有效记录读取。

12例为空输入、ASCII字符串123456789，以及长度1、2、3、4、7、16、64、256、1024、4096的确定性xorshift32数据。种子0x13579BDF，依次执行x^=x<<13、x^=x>>17、x^=x<<5，取结果低字节；所有操作为无符号32位。参考CRC由主机zlib独立计算。

## JTAG/VIO

输出read_index为7位，restart为1位；输入read_data为32位，committed及failed各1位。邮箱提交后保持稳定，主机设定索引、提交VIO、刷新输入并读取。restart经Processor System Reset的低有效辅助请求接口接入，时钟保持运行。端口名称是否与实现探针一致应核对生成的LTX，实物采集仍需真实板卡验收。
