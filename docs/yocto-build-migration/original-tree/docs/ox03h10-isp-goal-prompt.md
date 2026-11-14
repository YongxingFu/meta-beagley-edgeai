# OX03H10 ISP 端到端 Goal 提示词

下面内容可直接作为 Goal 使用。

---

目标：在当前工作区
`/home/fyx/work/ti/am67a/yocto/yocto-build` 中，完成并验收 OX03H10 从
GMSL RAW12 采集、TI VPAC VISS1 ISP 处理、NV12 输出、wave5 硬件 H.264
编码、RTP/UDP 推流，到 PC GStreamer 实时显示的端到端链路。请持续自主执行，
直到功能、图像有效性、长期稳定性、连续启停、性能和文档验收全部闭环；不要
停留在方案设计、单元测试或只完成其中一段。

当前环境：

- 板端：`root@10.42.0.247`，TI Linux 6.12.57，老架构。
- PC：自动探测与板端同一网段的有线 IPv4 地址和可用网卡，不写死 IP。
- sensor 链路：
  `OX03H10 -> MAX96717 -> MAX96716A -> J722S CSIRX -> /dev/video3`。
- raw 基线：`SBGGR12_1X12 1920x1536@60`，400 MHz overlay，
  MAX96716A `0x0320=0x2c`。
- ISP：`tiovxisp`，`VPAC_VISS1`，输入 BGGR12，输出 NV12。
- 编码：`v4l2h264enc`/wave5；只有硬件 H.264 不可用时才评估其他硬件编码，
  正式主通路不得退化为 OpenCV、CPU bayer2rgb 或 videoconvert 转码。

当前基线与本 Goal 的起点：

- raw 60 fps 已验证，必须保留。
- DCC 原始文件尾部有 4 字节 zlib/IEEE CRC-32 trailer。安装阶段必须生成
  可直接交给 TI parser 的文件，同时保留 `.orig` 和 CRC sidecar，并自动校验
  DCC header 中 component `total_file_sz` 之和。
- OX03H10 DCC 304 的 RGB2RGB 有 20 个 photospace region。通用
  `DCC_MAX_PHOTO_SPACE_INST` 和 `DCC_RGB2RGB1_MAX_PHOTO_SPACE_INST` 都必须
  支持 20，增加越界检查后同时重建 RTOS firmware 与 Linux 用户态，并在板端
  核对实际部署 hash 和二进制行为。
- 固定 2A 基线应使用 AE/AWB disabled，并完全跳过无意义的 TI 2A
  postprocess。若 sensor 缺少 exposure/gain controls，必须明确报告自动
  AE/AWB 尚缺哪些接口，不能把固定增益伪装成自动曝光。
- RAW12 dmabuf 应直接导入 TIOVX，避免每帧约 5.9 MB 的 CPU memcpy。
  非 dmabuf 路径可以保留 copy fallback，但正式链路必须证明工作在零拷贝路径。
- 已有 PC 实时显示、一键推流和接收脚本；应继续完善和复验，不要重复实现一套
  无法维护的临时命令。

必须完成的工作：

1. 从干净冷启动开始验证 GMSL 枚举、`/dev/video3`、sensor 格式和 raw
   300 帧基线。记录启动顺序、I2C 错误、CSI 错误和 raw 帧率。
2. 验证 RAW12 -> VPAC_VISS1 -> NV12 至少 300/300 和 600/600 帧完成。
   日志不得出现 `Invalid Desc Id`、`AWB_TI_process`、`TI_2A_wrapper_process`、
   `too many regions`、VISS kernel create 失败或持续 DMA/shared-memory 错误。
3. 保存 ISP 输出的首帧、中间帧和尾帧 NV12，转换为可查看图片，并用尺寸、
   亮度、颜色分布、帧间差异或哈希检查排除全黑、全绿、固定彩条、冻结和明显
   颜色异常。不能只凭“进程返回 0”或“文件非空”判定图像有效。
4. 自动探测 PC IP、网卡、板端视频节点、H.264/H.265 编码能力和支持的格式。
   默认采用低延迟 H.264/RTP/UDP，提供板端一键推流、PC 一键显示、无 GUI
   stats/snapshot 模式和明确的 jitter buffer、端口、码率、关键帧间隔默认值。
5. PC 端必须持续显示真实、非冻结的 ISP 处理画面。至少运行 10 分钟，记录：
   - 板端采集/ISP 处理帧率；
   - 编码帧率和编码码率；
   - 实际网络发送/接收码率；
   - PC rendered/dropped/current/average FPS；
   - 板端 CPU、内存和 DMA/TIOVX 错误计数；
   - 运行结束前后的 kernel/VISS/encoder/RTP 错误差异。
   端到端最低稳定 30 fps，目标 50-60 fps。
6. 完成连续启停推流至少 10 次。每次先启动 PC receiver，再启动 sender，使用
   有限帧数让 sender 正常处理 EOS 并退出；每轮都必须取得 PC rendered 计数
   增长或有效 JPEG，不能只看 sender 退出码。记录每轮启动耗时、首帧耗时、
   帧数和失败原因。优先使用仓库中的 `ox03h10-restart-test.sh`，并检查最终的
   `PASS=10/10`。
7. 每次只改变一个关键变量。修改前后记录代码 hash、执行命令、帧数、耗时、
   FPS、CPU、内存和错误计数。不得破坏当前 raw 60 fps、GMSL 上电/开流顺序
   或用户已有修改。
8. 将最终拓扑、DCC 规范化、20-region 修复、2A 基线、零拷贝实现、构建部署、
   板端/PC 启动命令、300/600/10 分钟/10 次启停结果、故障排查、回滚方法和
   已知限制写入 `docs/ox03h10-isp-streaming.md`，并更新现有 ISP 文档。

硬件与异常处理规则：

- 可逆的只读检查、日志采集、重新执行有限帧测试均可直接进行。
- 不要通过频繁 unbind/rebind CSI media 驱动来“恢复”链路；当前 6.12 TI
  media 驱动在重绑定边界可能告警或 oops。
- MAX96717 probe 出现 `-EREMOTEIO` 时，软重启通常不能恢复摄像头电源状态；
  应请求用户做一次真正断电重上电，然后重新完成从 raw 到 PC 显示的全链路复验。
- 长时间测试终止后若第一次新进程立即出现
  `TIVX_CMD_NODE_CREATE`/`kernel init ... com.ti.hwa.vpac_viss failed`
  或 `cmd_status=-7`，不要继续循环重试。保存日志，执行受控重启；若仍失败，
  请求断电重上电，并将该现象记录为清理/复位限制。
- 运行中的长时间测试不要用会提前触发 SIGKILL 的短 timeout。应根据帧数和
  FPS 计算合理时长并留足进程清理余量；需要限时结束时先发 INT/TERM，保留
  退出阶段日志，单独区分清理期日志和运行期错误。
- PC IP、GStreamer/GUI、物理网络确实不可用，或必须由用户完成断电重上电时，
  才报告明确阻塞。其余问题应继续自主诊断和修复。

验收证据要求：

- 每条关键结论必须有命令、日志、图片、帧计数、hash 或性能数据支撑。
- 300/600 帧验收必须同时给出前后段图像有效性证据。
- 10 分钟验收必须给出最终 rendered/current/average/dropped 数字，不能只给
  标称 framerate。
- 10 次启停必须给出逐轮 PASS/FAIL 表和最终 `PASS=10/10`。
- 若自动 AE/AWB 尚未完成，固定曝光基线可以验收 ISP/编码/推流，但最终报告
  必须把它列为明确限制，不能宣称自动 2A 已完成。

最终回复必须包含：

1. 已完成结果和最终端到端拓扑。
2. 修改文件、部署 hash、板端和 PC 启动命令。
3. 300/600 帧、10 分钟和 10 次启停的实测数据及证据路径。
4. 实际发现的根因、仍存在的限制和下一步接口工作。
5. 明确声明 Goal 是否全部满足；未满足的项目不能标记完成。

约束：

- 临时验证文件只放 `/tmp`。
- 不覆盖原始 DCC 和用户文件。
- 不做无关重构，不提交 Git commit，除非后续明确要求。
- 保留现有用户未提交修改，不回退工作区。
