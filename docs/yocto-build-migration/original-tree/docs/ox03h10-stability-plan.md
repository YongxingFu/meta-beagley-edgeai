# OX03H10 出图不稳定问题解决计划

本文保留当时的诊断假设与实验计划，不代表当前基线配置。最终修复与验收见
[调试案例](ox03h10-gmsl-debug-case-study.md) 和
[当前驱动基线](ox03h10-isp-streaming.md#12-当前驱动基线2026-11-10)。

## 1. 文档结论

依据：

- `raw/beagle_ai_sensor_serdes_config_seq.txt`
- `raw/sensor_x3h/OX03H10_a_CSP_DS_1_21_1.md`
- `raw/serdes_md/MAX96716/max96716a.md`
- `raw/serdes_md/MAX96717A/MAX96717A.md`

当前最需要修正的是 MAX96716A 的 CSI TX PHY/DPLL 配置，而不是先修改 sensor 模拟配置。

### 1.1 带宽要求

OX03H10 数据手册规定，1920x1536、60 fps、RAW12 的 MIPI 最低速率约为
1400 Mbps/lane，常用工作范围为 1350-1500 Mbps/lane。

MAX96716A `BACKTOP25 (0x0320)` 的最低 5 bit 是 activity PHY 的频率预定义值，
单位为 100 Mbps/lane：

- `0x0c`：1200 Mbps/lane
- `0x0e`：1400 Mbps/lane
- `0x0f`：1500 Mbps/lane
- bit5 置 1 时启用预定义频率，因此 1500 Mbps/lane 的寄存器值是 `0x2f`

现有参考初始化表和当前老驱动使用 `0x0320=0x2c`，即 1200 Mbps/lane，
低于 sensor 手册列出的 60 fps 最低带宽。这是当前不稳定问题的第一嫌疑。

### 1.2 DPLL 修改顺序

文档明确要求：修改 `phy*_csi_tx_dpll_predef_freq` 前，必须先复位对应的
CSI TX DPLL。MAX96716A link 0 当前使用硬件 PHY1，对应：

- DPLL 控制：`0x1d00` 的 `config_soft_rst_n`，bit0
- 频率配置：`0x0320`

正确顺序应为：

1. 清除 `0x1d00[0]`
2. 写入 `0x0320=0x2f`
3. 置位 `0x1d00[0]`
4. 等待 DPLL 稳定并检查相关 video lock

此前只写 `0x0320`、不复位 DPLL 的实验不能作为有效 A/B 结果。

### 1.3 推流顺序

参考实现要求：

1. DES `0x0313=0x02`
2. SENSOR `0x0100=0x01`
3. SER `0x0002=0x43`
4. 轮询 DES video lock：`0x01fc[0]` 和 `0x021c[0]`，100 ms 一次，最多 10 次

停止顺序相反：先停 sensor，再停 serializer，最后停 deserializer。

当前 Linux media graph 由下层到上层传播流状态，实际顺序与参考实现不一致；
需要把顺序和 lock 轮询显式落实到驱动中。

## 2. 诊断优先顺序

### 阶段 A：区分“sensor 少出帧”和“接收端少交帧”

在真实图像、RAW12、4-buffer mmap 且不写整帧到用户空间的条件下：

1. 连续采集 300 帧。
2. 在 1 秒和后续多个时间点读取 OX03H10 frame counter：
   - `0x483e`：frame count high
   - `0x483f`：frame count low
3. 同时记录：
   - DES link lock `0x0013[3]`
   - DES video lock `0x01fc[0]`、`0x021c[0]`
   - DES loss/overflow flags，包括 `0x5013`
   - SER `pclkdet`、`0x0112` 的 drift/overflow/FIFO warning

判定：

- sensor counter 接近 60/s，而 host 只有约 1/s：问题在 SerDes/CSI 或启停状态。
- sensor counter 本身约 1/s：问题在 sensor 模式、帧时序或 sensor 复位/初始化。

### 阶段 B：用 sensor 内部图案隔离模拟输入

启用 OX03H10 ISP 后级数字测试图案，不使用 rolling 或 transparent 模式：

- HCG `0x5240[0]=1`
- LCG/SPD/LOFIC 对应 `0x5440/0x5640/0x5840`

先测试单一稳定色条，再执行 300 帧采集。该图案仍经过 sensor ISP、RAW12
打包、MIPI、GMSL 和 CSI，可区分模拟像素/曝光问题与数字输出问题。

## 3. 修改顺序

### 修改 1：正确设置 1500 Mbps/lane CSI TX DPLL

只修改 MAX96716A 的 DPLL 复位和 `0x0320` 配置，不改 sensor：

1. 清 `0x1d00[0]`
2. 写 `0x0320=0x2f`
3. 置 `0x1d00[0]`
4. 确认 readback 为 `0x2f`
5. 执行三次 300 帧测试

验收：

- 300/300 帧完成
- 平均帧率不低于 59.5 fps
- sensor frame counter 与实际接收帧数差异不超过 2 帧
- link/video lock 在运行期间无丢失

### 修改 2：对齐参考实现的启停顺序

在驱动中显式执行：

1. DES output on
2. Sensor stream on
3. SER forward enable
4. 轮询 video lock

停止时反向执行。超时时打印 lock、error、FIFO/overflow 和关键 PHY 寄存器。

验收：重复启停 20 次，每次都完成 300 帧，不需要 I2C 脚本补救。

### 修改 3：对齐初始化时序和错误检查

按参考实现增加：

- DES link lock 轮询：`0x0013[3]`，50 ms 间隔，最多 1 秒
- SER ID 校验：`0x000d == 0xbf`
- SER 初始化后等待 500 ms
- 每次 stream start 后 video lock 轮询

同时记录并检查：

- DES `0x001d`：EOM/FEC/retry/packet/watermark error
- DES `0x001f`：line CRC/PRBS/pixel CRC
- DES `0x5013`：video memory overflow/loss of lock
- SER `0x0112`：drift/overflow/FIFO warning

### 修改 4：统一设备树和驱动的 CSI 速率

当前驱动日志仍显示 `link frequency 400 MHz`，但功能链路需要使用与
1500 Mbps/lane 对应的参数。需要确认：

- sensor endpoint：750 MHz link frequency
- MAX96716A CSI output：active PHY 为 1500 Mbps/lane
- 驱动不再忽略设备树值，或明确记录固定表的实际速率

避免继续把 overlay 名称或 DT 数值当作实际硬件速率。

## 4. 测试矩阵

| 测试 | Desired CSI TX | 启停顺序 | Sensor 图案 | 目标 |
|---|---:|---|---|---|
| A | 1200 Mbps | 当前 | 真实图像 | 复现基线 |
| B | 1500 Mbps，正确 DPLL reset | 当前 | 真实图像 | 验证带宽/复位假设 |
| C | 1500 Mbps，正确 DPLL reset | 参考顺序 | 真实图像 | 验证启停顺序 |
| D | 1500 Mbps，正确 DPLL reset | 参考顺序 | Sensor color bar | 隔离模拟输入 |
| E | 1400 Mbps，正确 DPLL reset | 参考顺序 | 真实图像 | 确认 1500 是否属于边界问题 |

每组至少运行三次 300 帧，并保存：

- 帧率序列和超时状态
- sensor frame counter 首尾值
- lock/error/overflow 寄存器
- SER/DES 完整关键寄存器快照
- 后段 10 帧原始数据及预览

## 5. 最终验收

硬件与用户空间解耦后，连续三次 300 帧均满足：

- 完成 300/300 帧
- 稳定约 59.5-60.5 fps
- 无 link/video lock 丢失
- 无 FIFO overflow、packet retry 激增或 pixel/line CRC 错误
- sensor frame counter 与接收帧数一致
- 启停 20 次可重复
- 不再依赖手工 I2C 寄存器修补

若 A-E 仍不能通过，再转向检查 AEQ/SSC、PoC 电源质量、同轴链路和 J722S CSI RX
误码计数；在此之前不应继续扩大修改范围。

## 6. 执行结果（2026-11-10）

### 6.1 阶段 A：出帧位置

在原始 400 MHz overlay 和 `0x0320=0x2c` 下运行 600 帧：

- host 完成 600/600 帧，启动后约 60 fps。
- OX03H10 frame counter 在采样区间内以约 60.8-62 fps 增长。
- DES link lock、video lock 全程保持。
- DES `0x5013` 为 0，pixel CRC 计数 `0x55c-0x55f` 为 0。

因此 sensor 本身持续出帧，问题在接收端的流启动顺序和视频输出状态。

### 6.2 1400/1500 Mbps/lane 实验

按完整 DPLL reset 顺序测试：

- 750 MHz overlay、`0x0320=0x2f`（1500 Mbps/lane）：sensor counter 仍约 60 fps，
  但 host 收到 0 帧。
- 750 MHz overlay、`0x0320=0x2e`（1400 Mbps/lane）：host 同样收到 0 帧。
- 恢复 400 MHz overlay 和 `0x0320=0x2c` 后恢复正常。

结论：当前 sensor 配置文件的真实输出与该板的 1200 Mbps/lane DES 输出配置匹配。
文档中的 1350-1500 Mbps 要求不能在没有同步调整 sensor PLL、`0x4837` 和 CSI RX
PHY 的情况下单独套用。当前保留 `0x0320=0x2c`。

### 6.3 根因和代码修改

根因是启动顺序。原驱动先启动 SER CSI 输出，再启动 sensor；参考实现要求：

1. DES output on
2. sensor stream on
3. SER video output on

修改 `max96717_enable_streams()`：

- 先启动上游 sensor，再置 SER `0x0002=0x43`。
- 启动失败时回滚 sensor 和 CSI 输出。

修改 `max96717_disable_streams()`：

- 先停 sensor，再停 SER CSI。
- 只有上游停止成功后才更新 `enabled_source_streams`。

修改 `max96716a`：

- probe 阶段轮询 GMSL link lock。
- stream-on 后轮询 pipe Y/Z video lock。
- video lock 超时时停止上游并关闭 DES CSI 输出。

### 6.4 最终验证

- 600 帧：600/600，启动后稳定 60.02 fps。
- 三次 yavta 300 帧：
  - 60.056 fps
  - 59.992 fps
  - 60.028 fps
- 20 次连续启停，每次 300 帧：20/20 通过，共 6000 帧。
- 真实图像预览：`backups/adi-camera-test/final-lock-fix-frame10.png`。
- `git diff --check` 通过。
- `scripts/checkpatch.pl`：0 errors，0 warnings。
- 两个模块 vermagic 均为 `6.12.57-ti`。

`v4l2-ctl` 的 300 帧滚动统计会受到进程启动和 frame-skip 处理影响，曾显示约
52-56 fps；`yavta` 的 buffer 时间戳显示实际 60 fps，因此最终帧率判断以 yavta
和 sensor frame counter 为准。
