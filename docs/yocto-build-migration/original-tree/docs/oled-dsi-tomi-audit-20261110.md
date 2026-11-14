# BeagleY-AI DSI 源码复核（2026-11-10）

## 范围与结论

复核基线是 `sources/linux-beagley` 的
`dc2fbaa20e3b8673321cb33d17c6c99fb2b8e8b8`（6.12.57-ti）及工作区差异，
参照 Tomi 的 2026-11-03 v5 显示支持系列、2026-09-07 v2 Cadence 修复系列，
并用本地 TI MCU+ SDK J722S 11.02.02.06 的寄存器定义交叉检查。

**确定发现一项此前调试引入的错误：lane 使能循环的 `<=` 应恢复成 `<`。**
它会导致控制器启用的数据 lane 数量与启动、复位、带宽配置不一致。
这足以使此前在该内核上的无数据测试失去可靠基线；但尚未完成修正后的硬件验证，
不能把它称为最初黑屏问题已经证实的唯一根因。

## 当前板上运行的内容（本轮只读采集）

| 项目 | 实际值 |
| --- | --- |
| `/boot/Image` SHA256 | `041391bb71740023ba8417100ac1917bebcdb483beb756a5b9411401f3279c9e` |
| 已安装面板模块 SHA256 | `8f8cd80c56984576b187b32641e87f001284becdc7866a6f8a2e1ca674e46c23` |
| 面板模块变体 | 无屏测试版，跳过 OLED I²C 初始化，单 lane，640×400，像素时钟 13.5 MHz（约 30 Hz） |
| DRM 状态 | DSI-1 → crtc-1 → plane-1，640×400 XR24，modetest 分配的 framebuffer |
| U9 控制 GPIO | OE=0，SEL=0 |

模块文件哈希与已有测试产物对照，DRM 模式读自 `/sys/kernel/debug/dri/0/state`。
它不是正式的 27.027 MHz 屏驱动；`connected` 和 page flip 不验证接收端存在或像素已上线路。
`/tmp/yxma-noscreen` 源码目前已被另一变体覆盖，也不能用来代表正在运行的模块。

只读寄存器快照：

| 地址 | 值 | 检查意义 |
| --- | --- | --- |
| `0x30500004` MAIN_DATA_CTL | `0x20027` | link、video、DPI/IF2 选择 |
| `0x30500008` MAIN_PHY_CTL | `0x11` | continuous clock，错误地启用第二条数据 lane |
| `0x3050000c` MAIN_EN | `0x4019` | IF2 使能，只有第一条数据 lane 启动 |
| `0x30500010` DPHY_CFG0 | `0x1103f1` | 只有第一条数据 lane 的 reset release 位 |
| `0x30500024` MAIN_STS | `0x7` | PLL、时钟及第一条数据 lane ready |
| `0x30500028` DPHY_ERR | `0` | 此时未报告相应错误 |
| `0x3050002c` LANE_STS | `0x40006` | 源码宏解码：时钟 HS，第一条数据 lane idle |
| `0x30270004` WRAP_DPI_CONTROL | `0x1` | DPI0 输入已启用 |
| `0x00104310` DPHY_TX0_CTRL | `0` | 与 TI SDK 选择 DSITX 为 DPHYTX 来源的写值一致 |

未通过 `/dev/mem` 修改寄存器，未重启、替换板上产物或打断 modetest。

## 1. lane 位定义：原来的 `<` 正确

SDK 路径前缀：
`build-adi/arago-tmp-default-glibc/work/beagley_ai-oe-linux/ti-edgeai-firmware-beagley/11.02.02.04/ti-processor-sdk-rtos-j722s-evm-11_02_02_04/mcu_plus_sdk_j722s_11_02_02_06/source/drivers/dss/v1/`。

- `hw_include/dsi/include/dsitx_regs_macros.h:185`：bit0 是 `LANE2_EN`，bit1 是 `LANE3_EN`，bit2 是 `LANE4_EN`。
- `hw_include/dsi/include/dsitx_structs_if.h:159`：`lane2Enabled` 明确为“Enable second lane”。
- `dctrl/dss_dctrlDsi.c:740`：仅当 `numOfLanes > 1` 才设置 `lane2Enabled`；第三、四条同理。

Linux 宏 `DATA_LANE_EN(i) = BIT(i - 1)` 的参数是额外 lane 的零起始编号，
不是“一条 lane 对应 bit0”。第一条 lane 无此可选使能位。

| 配置的数据 lane 数 | PHY_CTL[2:0] 正确值 | 连续时钟时 PHY_CTL（其余位为 0） |
| --- | --- | --- |
| 1 | `000` | `0x10` |
| 2 | `001` | `0x11` |
| 3 | `011` | `0x13` |
| 4 | `111` | `0x17` |

此前 `<=` 在单 lane 下写成 `0x11`；双 lane 下则误启用第三条。
本轮恢复 `<` 并加注释，不更改 DATA_LANE_START、复位位或 PLL 计算。

## 2. Tomi 补丁对照

| 补丁/功能 | 本版本核对结果 |
| --- | --- |
| Cadence v2 1/3，clk debug print | 之前遗漏；仅日志，不是无输出功能修复。本轮补齐原始打印 |
| Cadence v2 2/3，enable 时 stop-state | 当前实现与补丁等价：PHY 启动前强制 stop，释放 reset 后保持 100–200 μs，再撤销 |
| Cadence v2 3/3，mode/bus flags | 当前实现与补丁等价：负 H/V 同步，DE_HIGH，像素及同步上升沿 drive |
| DSS1 第二个 VP → DSI | overlay 用 `dss1_ports/port@1`，与 Tomi 定义一致 |
| DSI wrapper、地址、时钟、PHY 引用 | 与 Tomi v5 相关节点吻合；wrapper 注释提及 J721E DSS0 不是 J722S 实际走错路的证据 |
| tidss bus flags 传播 | `tidss_encoder.c` 已将下一 bridge 的 input_bus_cfg 传给 CRTC，dispc 据此配置极性 |
| v5 的 AM62P 通用 features/compatible | 本版使用 TI 的 am62p51/am62p52 区分；名字不同不代表 DSI 缺失。相关 RGB888/VP 使能路径未见阻断 |
| TC358762 / attiny 前置修复 | 针对 Tomi 的 RPi 面板链路；当前 I²C OLED 无这两个器件，不照搬 |

DSI core 固定 `input->id = CDNS_DPI_INPUT = 1`，对应 SDK 的 IF2；
不是误选第二个外部输出。SDK 同样选 `DSITX_VID_IF_SELECT_IF2 = 1`，使能 IF2。
板上读回 `0x20027` 和 `0x4019` 与此吻合。

原先无显式 bus flags 时，`DE_LOW` 位未设，tidss 的 DE 实际已经是高有效；
因此不能把这次移植解释为“修正了原本低有效的 DE”。新增 flags 改变了同步边沿 RF 等配置。
Tomi v5 已移除 CTRL_MMR 外部 DPI 极性相关系列改动；不可据此随意修改内部 DSI 路由。

## 3. 不再采用的旧测试推论

1. **旧 TVG 不能排除 DSS。** SDK `DSITX_TestVideoModeConfig.bytesPerLine` 的单位是字节，
   必须等于 VSG RGB size。640 像素 RGB888 应填 1920（`0x780`），旧测试填 640。
   因此旧测试的 `TVG_RUNNING` 不等价于完成了一次参数有效的内部图案发送。
2. **NOP 超时不能单独证明 D-PHY 损坏。** 当时控制器仍受错误 lane 配置影响，
   测试发生在视频工作状态或手工切换视频位之后，缺乏完整且正确的独立命令模式基线。
3. **FIFO 变化不等价于已传输。** SDK 确认 DPI_CFG 低 16 位为 FIFO_LEVEL，
   其变化是输入活动线索，不能独自证明完整帧、正确同步或 DSI payload 输出。
4. **无屏观测与接屏验证分开记录。** 无屏测试版没有 I²C 初始化，不能用于证明 OLED 参数正确。
5. **GD32 外部视频已验证。** 用户确认 HDMI 经 LT6911C 固件转换后能够驱动同一 OLED。
   正式驱动中“external video is not yet verified”的过时注释已纠正；桥内固件参数仍未知。

## 本轮修改与后续验证

源码仅恢复正确的 lane 循环、增加解释及 Tomi 的 dev_dbg 打印、修正文档性注释，
同步更新 `yxma023ehd-adapter.patch`。旧 Yocto patch 保存于
`backups/oled-dsi-audit-20261110/yxma023ehd-adapter.patch`。

后续应先用修正后的内核建立可复现基线：单 lane、确认 PHY_CTL=0x10，
其余启动/复位位保持对应第一条 lane。修正与 30/60 Hz 或包模式切换分开验证。
接 OLED 时恢复正式 I²C 面板驱动及标准时序，再验证图像。
若仍 idle，按 SDK 的字节单位和启停顺序重新做 TVG；只有正确 TVG 能发数据而正常输入不能，
才有依据将排查重点收敛到 DSS→DPI 同步/数据链路。

## 构建验证

构建验证：`bitbake -c compile linux-bb.org` 成功，930 个任务中 921 个复用，
其余任务全部成功；`git diff --check` 和 Yocto patch 反向应用检查通过。
构建树的 DSI core 源文件与正式工作区 SHA256 一致。
新 Image 位于
`build/arago-tmp-default-glibc/work/beagley_ai-oe-linux/linux-bb.org/6.12.57+git/build/arch/arm64/boot/Image`，
SHA256：`6b94f08cd5716b3405002074dff5d4d9b65353efdbef92ce8c2f3d6516846c8d`。
本次为 compile 任务，未执行 deploy、模块安装或板上替换。
构建日志：`/tmp/oled-dsi-audit-build.log`。

## 替换后冷启动验证

用户冷启动后，板上 Image 哈希为上述 `6b94f08c...`，保留原单 lane 30 Hz 无屏模块。
`MAIN_PHY_CTL=0x10`，`MAIN_EN=0x4019`，`DPHY_CFG0=0x1103f1`，
`MAIN_STS=0x7`，`DPHY_ERR=0`，PLL 配置 `0x80d00402`（325 Mbps，时钟 162.5 MHz）。
启动 `modetest -M tidss -s 51@49:640x400 -F tiles -v`，持续约 30.06 Hz 翻页。
10000 次 lane 状态采样中 `0x4000a` 为 9982 次（第一条数据 lane WRITE），
`0x40006` 为 18 次（idle）。此前错误配置下采样一直 idle；修正后控制器已出现发送状态。
这些是控制器侧证据，连接器波形和接屏显示仍待实测确认。

## 接屏显示验证成功

用户接回 OLED 后，恢复备份的正式 I²C 面板模块（SHA256
`826d21260ca12c128440a5181e7cd66d9987899b8828d5789bd04895e12694b4`），
软件重启，保留修正后的 Image `6b94f08c...`。
OLED 读回 `0x2850=0x00`、`0x2401=0x14`（BIST 关闭）。
模式恢复为 640×400、27.027 MHz 请求像素时钟、单 lane RGB888、
连续时钟、非 burst sync-pulse、VC0。PLL `0x80d00202`，
实际 lane 速率 650 Mbps，DSI 时钟 325 MHz；PHY_CTL=0x10，数据 lane WRITE。

用户首先确认 OLED 显示 TI Edge AI Gallery 界面，证明外部视频链路工作。
随后运行带 `-v` 的 modetest，用户报告闪烁；去掉 `-v`，改为
`modetest -M tidss -s 51@49:640x400 -F tiles` 后用户确认“ok 能显示了”。
因此目前保留静态测试图。翻页时闪烁的具体机制未进一步验证，不据此断言 DSI 信号质量。
此轮接屏显示已经成功，但尚未完成长期稳定性或反复冷启动验证。

成功配置产物已保存到板上 `/root/oled-stage/known-good-display-20261110/`。

## 整理后的代码基线

内核仓库 `sources/linux-beagley`：

- `4773da1cc402`：Cadence 启动 stop-state、DPI flags、时钟日志及 lane 位注释。
- `1198505462d2df7021771a3e14d6102ab5e16c49`：正式面板驱动、电源/复位时序及 adapter overlay。

整理仅调整代码格式、注释和模块描述，不改变上述已验证的硬件配置。
`checkpatch.pl` 检查为 0 errors / 0 warnings，`git diff --check` 通过；
整理后的 Cadence 对象、面板模块和 dtbo 均编译成功。
面板模块校验使用现有构建的 `vmlinux.symvers` 解析内建内核符号，未忽略未定义符号。

Yocto 集成改为固定该内核提交；历史 `yxma023ehd-adapter.patch` 已从活动配置中撤除，
避免对新源码重复应用。历史补丁保留在本地 backups 中，不提交构建产物或临时测试模块。
主构建的 `local.conf` 也已同步 SRCREV。集成及重建方法见独立 layer 仓库
`sources/meta-beagley-edgeai/docs/oled-yxma023ehd.md`。
集成提交为 `e90735e`；`bitbake -e linux-bb.org` 中 SRCREV 已解析为
`1198505462d2df7021771a3e14d6102ab5e16c49`，OLED 配置片段仍启用，
SRC_URI 不再包含临时 OLED 补丁。
本轮整理未再次替换板上成功产物，也未执行完整镜像重建。

## 原始邮件

- [Tomi v5 显示支持系列（含 DSI 测试与前置依赖说明）](https://lore-kernel.gnuweeb.org/dri-devel/20261103-beagley-ai-display-v5-11-f1c8d0e52bb4@ideasonboard.com/T/)
- [Cadence v2 0/3](https://lkml.iu.edu/2609.0/15472.html)
- [1/3 clk debug print](https://lkml.iu.edu/2609.0/15498.html)
- [2/3 stop-state](https://lists.openwall.net/linux-kernel/2026/09/07/1369)
- [3/3 mode/bus flags](https://lkml.iu.edu/2609.0/15476.html)
