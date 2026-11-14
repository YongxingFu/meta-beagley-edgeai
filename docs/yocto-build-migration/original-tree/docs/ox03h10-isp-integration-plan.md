# OX03H10 接入 ISP 方案评估

本文是最初的接入评估。当前已经落地的 DCC、固定 2A、零拷贝 VISS、H.264/RTP
和 PC GStreamer 显示方案，见
[OX03H10 ISP 与网络推流实现](./ox03h10-isp-streaming.md)。

## 1. 当前结论

推荐使用 TI J722S/AM67A 的硬件 ISP：

```text
OX03H10 RAW12
    -> 4-lane CSI-2
    -> /dev/video3
    -> dmabuf
    -> TIOVX tiovxisp
    -> VPAC VISS1
    -> NV12
    -> tiovxmultiscaler / display / encoder / AI
```

不建议把 CPU `bayer2rgb` 或 OpenCV 作为正式视频通路。它们适合离线检查，
不适合持续处理 1920x1536 RAW12 或后续 AI 视频流。

该结论来自板端实际状态：

- GStreamer 已安装 `tiovxisp`。
- `tiovxisp` 提供 `VPAC_VISS1` target。
- DCC 文件已安装：
  - `/opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin`
  - `/opt/imaging/ox03h10/wdr/dcc_2a_wdr_304.bin`
- 运行库已包含 `SENSOR_OX03H10` 和 DCC ID 304。
- TIOVX 共享内存 heap 已初始化，`tiovxisp` 能创建 VISS graph。

最初使用板端原始 DCC 文件时，最小 pipeline 在 TI 2A 的 AWB 处理处每帧
返回错误：

```text
AWB_TI_process returned error 0xffffffff
TI_AWB_do Returned error 1
Unable to process TI 2A wrapper
```

2026-11-10 复核后已经定位到直接触发因素：两个 DCC 文件末尾各附加了 4 字节
文件级 CRC-32，但 TI DCC parser 不支持这种全局 trailer。仅在测试目录中去掉
末尾 4 字节后，同样的 `tiovxisp` pipeline 在默认 AE/AWB 模式下完成 300/300
帧，未再出现 `Invalid Desc Id`、`AWB_TI_process` 或 TI 2A 错误。详细分析见
第 7 节。

这说明 NV12/ISP 主通路已经能够工作。当前仍需修正 DCC 资产发布方式、补齐
RGB2RGB 的 20-region 存储容量，并继续验证实际帧率和图像质量。原
`/opt/imaging/ox03h10/wdr/*.bin` 尚未被覆盖。

## 2. 方案比较

| 方案 | 性能 | 集成工作量 | 图像质量 | 结论 |
|---|---|---|---|---|
| TI TIOVX VPAC VISS | 硬件加速，适合 60 fps | 中高 | 支持 DCC 调优 | 推荐主方案 |
| CPU bayer2rgb/OpenCV | 很低 | 初期低 | 无完整 ISP | 只用于离线验证 |
| 依赖 OX03H10 内部 ISP | 无法直接输出 RGB/YUV | 文档不足 | 受 sensor 输出模式限制 | 不作为主方案 |
| 自研软件 ISP | 难以实时 | 很高 | 需要完整算法链 | 不推荐 |

## 3. TI VISS 方案的任务拆分

### 阶段 0：先绕过 TI 2A，拿到第一帧 NV12

当前 `gsttiovxisp.c` 强制要求 `dcc-2a-file`，并且在每一帧后无条件调用
`TI_2A_wrapper_process()`。即使 AE/AWB 设置为 disabled，也不会跳过 DCC 2A。

第一轮应增加一个测试选项，例如：

```text
bypass-2a=true
```

启用时：

1. 仍然使用 `dcc-isp-file` 初始化 VISS。
2. 不创建 TI 2A wrapper。
3. 不处理 H3A statistics。
4. 不通过 V4L2 写 sensor exposure/gain。
5. 直接输出 VISS NV12。

建议先使用固定 sensor exposure/gain，验证硬件 ISP 通路：

```text
v4l2src io-mode=dmabuf
    -> video/x-bayer,format=bggr12,width=1920,height=1536,framerate=60/1
    -> tiovxisp
         sensor-name=SENSOR_OX03H10
         dcc-isp-file=/opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin
         format-msb=11
         wdr-enabled=true
         bypass-2a=true
    -> video/x-raw,format=NV12,width=1920,height=1536
    -> fakesink
```

`format-msb=11` 对应当前 RAW12 数据右侧有效 12 bit。

第一帧验收：

- TIOVX graph 创建成功。
- 连续输出 NV12，而不是 raw。
- 60 帧和 300 帧均能完成。
- 无 VISS kernel error。

### 阶段 1：确认 WDR 模式和 DCC 匹配

OX03H10 当前在 sensor 内部将多次曝光合成为 PWL RAW12。后端收到的是一个
12-bit 合并图像，`num-exposures` 初期应使用 1。

DCC 文件名包含 WDR，但 sensor 已经完成 HDR combine。需要分别测试：

- `wdr-enabled=true`
- `wdr-enabled=false`

使用同一 DCC 304 文件和同一 sensor 模式，仅比较输出：

- 画面灰度、颜色和过曝情况。
- VISS H3A 统计是否合理。
- 是否触发 2A 或 DCC 错误。

原始 DCC 文件在两种模式下都失败，原因是文件级 CRC trailer 与 DCC 内容格式
无关。使用去掉 trailer 的 DCC 后，`wdr-enabled=true` 已能完成 300 帧；后续
仍需用相同曝光和场景分别采集 true/false 输出，判断 VISS WDR 参数是否匹配。

### 阶段 2：增加 sensor V4L2 controls

当前 OX03H10 driver 没有 V4L2 controls。TI 2A 自动曝光需要调用：

- `V4L2_CID_EXPOSURE`
- `V4L2_CID_ANALOGUE_GAIN`

建议实现：

- 手动曝光控件。
- 模拟增益控件。
- 必要时增加 digital gain、VBLANK/VTS 控件。

OX03H10 的曝光单位为 double-row time：

```text
1 double-row = 20.4 us
```

因此微秒到寄存器的基本换算是：

```text
exposure_units = exposure_us / 20.4
```

曝光寄存器：

- DCG：`0x3501/0x3502`
- SPD/LOFIC：`0x3541/0x3542`

模拟增益是 4.4-bit 格式：

- HCG：`0x3508/0x3509`
- SPD：`0x3548/0x3549`
- LCG：`0x3588/0x3589`
- LOFIC：`0x35C8/0x35C9`

VTS 位于 `0x380e/0x380f`。曝光变化必须满足手册约束：

```text
max(exposure) < VTS - 12
```

### 阶段 3：补齐 tiovxisp 的 OX03H10 2A 支持

即使 DCC 2A 恢复正常，当前 `gsttiovxisp.c` 也需要：

- 在支持列表中公开 `SENSOR_OX03H10`。
- 增加 OX03H10 的 exposure-time 到 sensor row-time 转换。
- 增加 TI gain 到 OX03H10 4.4-bit gain 的转换。
- 增加 OX03H10 的 2A dynamic parameters。

如果 sensor 输出的是内部合成 WDR，建议先只运行单帧 AE/AWB 结果，不要立即
写四个 exposure channel。等 sensor 的 HDR channel 策略确认后再启用多曝光控制。

### 阶段 4：下游数据流

VISS 输出 NV12 后使用 `tiovxmultiscaler`：

```text
tiovxisp
    -> NV12 1920x1536
    -> tee
       -> 1920x1080 display
       -> 1280x720 preview
       -> 640x640 AI input
       -> encoder
```

目标：

- 显示和 AI 使用共享内存，避免 CPU memcpy。
- 不把完整 raw/NV12 帧写用户空间作为性能测试。
- 使用 yavta 或 GStreamer `fpsdisplaysink` 检查帧率。

## 4. 优先修复顺序

1. 将 DCC 文件规范化为不含文件级 CRC trailer 的格式，或让加载层验证 CRC 后
   只把有效长度传给 TI parser。
2. 将 RGB2RGB 的实例容量从 10 扩到 20，并增加容量检查。
3. 使用无 trailer 的 DCC 304 和固定曝光获得第一帧 NV12。
4. 验证 VISS 300 帧、连续启停和实际吞吐；当前自动 2A 路径尚未达到 60 fps。
5. 确认 `wdr-enabled` 与 OX03H10 内部 HDR combine 的组合。
6. 给 sensor driver 增加 exposure/gain controls。
7. 如果需要绕过 TI 2A，再给 `tiovxisp` 增加 `bypass-2a` 测试路径。
8. 将 OX03H10 加入 `gsttiovxisp` 的 sensor-specific 2A 映射。
9. 增加 multiscaler、显示、编码和 AI 输出。
10. 做 DCC 图像质量调优。

## 5. 验收标准

### 最小可用 ISP

- 1920x1536 BGGR12 输入。
- 输出 NV12。
- `tiovxisp` 不产生 kernel/TI2A 错误。
- 300/300 帧完成。
- 稳态约 60 fps。
- 保存的 NV12 转 RGB 预览内容正常。

### 可产品化 ISP

- 连续 30 分钟无 VISS graph、DMA 或共享内存错误。
- 60 fps 输入输出无持续掉帧。
- AE 和 AWB 能在正常室内外光照下收敛。
- 曝光/增益更新不造成 sensor 或 CSI 超时。
- 启停 20 次稳定。
- 多路输出不影响主视频流。

## 6. 当前风险

- `dcc_2a_wdr_304.bin` 与当前 sensor HDR 合并模式可能不完全匹配。
- 原始 DCC 文件带 TI parser 不认识的 4 字节文件级 CRC trailer。
- 20-region 解析只放大了通用 region 表，RGB2RGB 参数数组仍只有 10 项。
- sensor driver 没有 exposure/gain controls，自动 2A 暂不可用。
- `gsttiovxisp.c` 的 OX03H10 sensor-specific 映射尚未实现。
- 当前自动 2A 路径处理 300 帧约需 20 秒；VPAC VISS 原始吞吐仍需单独测量。
- 板端部分 `/opt` 源码副本可能落后于实际二进制包，调试时要区分源码与运行库。

硬件能力、插件和 DCC 资产已经存在，当前主要工作是完成软件接口和 2A/DCC
集成，而不是重新选择 ISP 硬件。

## 7. DCC 304 文件与 parser 核查

### 7.1 文件格式

板端文件不是单个 component，而是 TI 标准的多 component 容器：

| 文件 | 大小 | component |
|---|---:|---|
| `dcc_2a_wdr_304.bin` | 37,880 | 2 个：AWB desc 40、H3A desc 3 |
| `dcc_viss_wdr_304.bin` | 73,803 | 9 个：LSC、H3A、H3A MUX、RGB2RGB、BLC、YEE、NSF4、RFE、GLBCE |

每个 component 开头是 80 字节 header，`total_file_sz` 等于该 component 的完整
长度。末尾 CRC 前，各 component 长度之和恰好等于文件主体长度：

```text
2A:   37,707 + 169 = 37,876; 37,876 + 4 = 37,880
VISS: 73,799       = 73,799; 73,799 + 4 = 73,803
```

末尾 4 字节是前面全部内容的标准 CRC-32（IEEE/zlib），按大端存储：

```text
dcc_2a_wdr_304.bin:  f6 f9 e6 c7
dcc_viss_wdr_304.bin: 59 04 dd 79
```

复算方法：

```sh
python3 - <<'PY'
import pathlib, zlib
for name in ("dcc_2a_wdr_304.bin", "dcc_viss_wdr_304.bin"):
    data = pathlib.Path(name).read_bytes()
    print(name, f"{zlib.crc32(data[:-4]) & 0xffffffff:08x}", data[-4:].hex())
PY
```

这是其他项目增加的文件级完整性校验，不是 TI component header 里的
`crc_checksum`。后者仍由各 component 自己保存，TI parser 会检查它；文件末尾
的全局 CRC 没有任何 TI DCC 字段声明或引用。

### 7.2 CRC trailer 为什么会破坏 ISP 2A

正常命中 component 时，parser 使用 header 里的 `total_file_sz` 跳转，因此不会
把 trailer 当成参数数据。但 `dcc_update()` 会依次查找多个 descriptor。查找
2A 文件中不存在的 descriptor 时，流程是：

```text
处理最后一个真实 component
    -> 指针移动到文件末尾
    -> 无 trailer：pointer == buffer_end，返回 NO_SUCH_DCC，继续查下一模块
    -> 有 trailer：pointer < buffer_end，尝试把 CRC 当 80-byte header 解析
       -> 得到非法 camera/descriptor，返回 INVALID_DESC_ID/INVALID_CAMERA_ID
       -> dcc_update 提前 break
```

实际日志已经直接复现：

```text
Invalid Desc Id 2
...
AWB_TI_process returned error 0xffffffff
TI_AWB_do Returned error 1
```

2A 文件只有 desc 40 和 desc 3，没有 desc 2。保留 trailer 时，查找 desc 2 在
尾部 CRC 处失败并提前结束，后面的 AWB desc 40 没有机会被解析。只去掉 4 字节
trailer 后：

```text
默认 AE/AWB，wdr-enabled=true
300/300 帧完成
无 Invalid Desc Id
无 AWB_TI_process/TI_2A 错误
```

因此 `ae-mode=disabled` 不能绕过该问题：GStreamer 仍会进入 TI 2A process，
而 DCC 加载阶段已经被 trailer 截断。

### 7.3 A/B 复现命令

不要覆盖 `/opt` 原文件，只在 `/tmp` 生成测试副本：

```sh
cp /opt/imaging/ox03h10/wdr/dcc_2a_wdr_304.bin /tmp/dcc_2a_nocrc.bin
cp /opt/imaging/ox03h10/wdr/dcc_viss_wdr_304.bin /tmp/dcc_viss_nocrc.bin
truncate -s -4 /tmp/dcc_2a_nocrc.bin
truncate -s -4 /tmp/dcc_viss_nocrc.bin
```

然后只替换 DCC 路径：

```sh
gst-launch-1.0 -q \
  v4l2src device=/dev/video3 io-mode=dmabuf num-buffers=300 ! \
  video/x-bayer,format=bggr12,width=1920,height=1536,framerate=60/1 ! \
  tiovxisp sensor-name=SENSOR_OX03H10 format-msb=11 num-exposures=1 \
    wdr-enabled=true \
    dcc-isp-file=/tmp/dcc_viss_nocrc.bin \
    sink_0::dcc-2a-file=/tmp/dcc_2a_nocrc.bin ! \
  video/x-raw,format=NV12,width=1920,height=1536,framerate=60/1 ! \
  fakesink sync=false num-buffers=300
```

验收时同时检查：

- 命令返回 0，且 300/300 帧完成。
- 日志没有 `Invalid Desc Id`。
- 日志没有 `AWB_TI_process returned error`。
- 日志没有 `TI_AWB_do Returned error`。
- 保存首帧、中间帧和尾帧，确认画面不是固定彩条、全黑或明显颜色异常。

### 7.4 20-region 修改的真实影响

DCC 304 的 RGB2RGB component（desc 10）确实有 20 个 photospace region：

```text
component offset: 0x3693
photospace dims:  3（CT、ET、AG）
regions/classes:  20 / 20
```

TI 默认 `DCC_MAX_PHOTO_SPACE_INST=10` 会在 `find_parpack()` 中拒绝第 11 个
region，所以把上限扩到 20 是支持这份 DCC 的必要条件。板端当前
`vx_app_rtos_linux_mcu2_0.out` 的 SHA-256 为：

```text
0f9c1eb4d9d303ab944423c15ee48e5ecdcc90fdc981d8e6390a5e35c38a7b8c
```

它与 `build-adi` 中已应用 20-region patch 的产物一致；反汇编
`find_parpack()` 可见上限比较和初始化循环均为 20。因此当前 MCU2 不是仍停在
10 的旧固件。

但现有 patch 只修改：

```c
#define DCC_MAX_PHOTO_SPACE_INST (20U)
```

同一头文件中的 RGB2RGB 专用容量仍为 10：

```c
#define DCC_RGB2RGB1_MAX_PHOTO_SPACE_INST (10U)
```

`ipipe_rgb2rgb_dcc_bin_parse()` 按 `num_regions=20` 解析并写入
`ipipeRgb2Rgb1Cfg[]`，而该数组只有 10 项；`phPrmsRgb2Rgb1` 也按 10 项拷贝，
但 `ipipeNumRgb2Rgb1Inst` 被设置成 20。结果是数组越界、相邻 DCC 字段被覆盖，
后续 `dcc_interp_CCM()` 还可能读取不属于 RGB2RGB 的数据。

这不是 TI API 参数变化，而是 parser 内部结构体容量不一致。只把
`DCC_MAX_PHOTO_SPACE_INST` 从 10 改成 20 不完整，必须同步修改：

```diff
-#define DCC_RGB2RGB1_MAX_PHOTO_SPACE_INST (10U)
+#define DCC_RGB2RGB1_MAX_PHOTO_SPACE_INST (20U)
```

`calc_dcc_outbuf_size()` 使用该宏计算 RGB2RGB 输出大小，因此会随宏变化从
300 字节变为 600 字节。还建议在 `find_parpack()` 或各 component parser 中增加
“region 数不得超过目标数组容量”的显式检查，避免以后换 DCC 时再次静默越界。

当前即使未修该容量，短测仍可能因选中前面的 region 而看起来正常；这不能证明
高增益、低色温等落在后 10 个 region 时也正确。接入正式 2A/图像调优前应把它
修完。

### 7.5 推荐发布方式

优先在镜像 recipe 中把 DCC 规范化为 TI parser 可接受的文件：

1. 验证末尾 CRC。
2. 删除末尾 4 字节。
3. 将有效 DCC 安装到 `/opt/imaging/...`。
4. 将 CRC 放到单独 sidecar 文件，或在加载器中校验后按 `size - 4` 传入 parser。

如果必须保留内嵌 trailer，则加载器应先识别并验证它，再只把前面的有效长度传给
`dcc_update()`。不要只依赖 `ae-mode=disabled` 或关闭 AWB 来规避。
