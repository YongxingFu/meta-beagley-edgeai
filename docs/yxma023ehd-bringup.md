# BeagleY-AI / YXMA023EHD 驱动框架

当前是代码框架，不是可直接点亮的板级配置。最终由 BeagleY-AI 直接控制屏幕，不保留 MCU。正确转接板原理图到位前，不实现电源、RESET、SWIRE 和板载 CSI1/DSI0 MUX 控制，不沿用旧转接板的 SL6802 或 MCU GPIO 映射。

## 文件与构建

驱动及设备树已经纳入 `sources/linux-beagley` 的默认分支 `beagley/6.12`，与摄像头框架共用同一内核提交：

- 内核 `drivers/gpu/drm/panel/panel-yousee-yxma023ehd.c`：I²C DRM panel，动态注册 DSI 外设。
- 内核 `arch/arm64/boot/dts/ti/k3-am67a-beagley-ai-yxma023ehd.dtso`：DSS1 VP1 → DSI0 → I²C panel 图连接模板，DSI、PHY、panel 默认禁用。
- layer `recipes-kernel/linux/files/yxma023ehd.cfg`：内核配置片段。
- layer `recipes-kernel/linux/yxma023ehd.inc`：选择内核配置和 DTBO，不再注入驱动源码。

`BEAGLEY_ENABLE_YXMA023EHD` 默认为 1。执行 `bitbake virtual/kernel` 构建内核，执行 `bitbake tisdk-edgeai-image` 构建完整镜像；镜像显式安装 `kernel-module-panel-yousee-yxma023ehd`。设为 0 可取消该模块的配置片段和显式打包请求（不保证基础 defconfig 或其他依赖没有选中它）。overlay 不自动加载，默认禁用节点不变。

修改驱动后，先在内核仓库提交，再更新 layer 的 `beagley-kernel-local.inc` 中固定 `BEAGLEY_KERNEL_SRCREV`，否则 Yocto 不会获取未提交的源码。

## 已实现

I²C 地址由设备树 `reg` 确定（模板 0x50；ADDR 高对应 0x54），不自动扫描候选地址。16 位寄存器地址低字节先发，8 位数据，禁用 regmap 缓存，使用普通 I²C 事务。

`prepare()` 沿用 MCU 工程外部视频分支：对 0x2850 清 bit7，再对 0x2401 清 bit0，保留其他位；等待 20ms 后读回校验。I²C 出错立即返回；控制位未清除返回 EIO。保留 OTP，不重放 BIST TCON 寄存器，不发送 DCS 命令。此流程在 MCU 工程中有控制位读回记录，尚无外部视频出图验证。

固定模式为 RGB888、单 lane、640×400，像素时钟 27.027MHz；水平前肩/同步/后肩为 96/64/58，总计858；垂直为63/6/56，总计525。首次尝试连续时钟、非 burst 同步脉冲视频。同步极性及接收端模式仍需确认，当前未臆造极性标志。目标 lane 速率约648.648Mbps，实际值取决于 PHY PLL 取整。

驱动提供 probe、prepare、unprepare、get_modes、remove、shutdown 及错误清理框架。当前 unprepare 不发关屏命令，也不控制电源；不应认为已支持可靠休眠、掉电或完整生命周期。BIST 测试模式、亮度接口尚未实现。

## 原理图到位后的接入点

1. 核实屏幕电源、RESET、电平域、SWIRE 和电源使能；在 prepare 的 I²C 操作前补齐上电复位，在 unprepare/shutdown 补齐关闭流程。
2. 确认 I²C 总线。模板 `main_i2c0` 仅为 DSI0/CSI1 连接器候选；尚未设置其 pinctrl/status/频率。
3. 配置板载 MUX 和引脚复用，避免与 CSI1 overlay 冲突。确认 LT6911C 等旧视频源不再连接屏幕差分对。
4. 确认单 lane CLK±、D0± 与连接器方向，补齐实际 overlay，再使能 panel、DSI0 和 dphy_tx0。
5. 完成正常电源管理后删除临时 `yousee,externally-sequenced` 门槛。当前驱动只有显式提供此布尔属性才允许 probe，含义是台架已另行完成电源/RESET，不代表最终依赖 MCU。默认模板不提供该属性。
6. 首先验证 I²C/内部 BIST，再运行 DRM 测试图，最后验证重启和反复开关屏。构建通过不等于实屏出图。

参考输入：用户提供的 BV0.1 手册、时序 PNG，以及 `/media/fyx/Docs/07-LCOS/code/gd32e103-blinky/src/chip/panel_yxma023ehd.c` 的外部视频分支。旧工程的板级电源映射不适用于当前待提供的转接板。

## 框架验证记录

- 使用当前 Yocto 的 Linux 6.12.57 构建目录和 aarch64-oe-linux GCC，外部模块编译、MODPOST 和链接通过，产物在 `/tmp/yxma023ehd-check/panel-yousee-yxma023ehd.ko`。
- overlay 经 CPP、DTC 编译通过，并使用 fdtoverlay 成功合并到当前 BeagleY-AI 基础 DTB。检查产物在 `/tmp/yxma023ehd-check/`。
- 内核 checkpatch：0 errors、0 warnings；layer 的 diff 空白检查通过。
- 迁移前的 layer 注入版本已通过 BitBake 开关两种状态解析；迁移后由主分支提供源码，取消源码注入。
- 未执行完整镜像构建、烧录或硬件显示测试。

统一默认分支验证：四个模块在同一 Kbuild 中编译及 MODPOST 通过，产物位于 `/tmp/beagley-unified-check/`；完整 `olddefconfig` 检查发现并修复了屏幕 Kconfig 的循环依赖，重新检查后四个模块均保留为 `m`。

迁移后 BitBake `virtual/kernel` 与 `tisdk-edgeai-image` 配方解析通过，确认默认分支为 `beagley/6.12`、固定提交为 `62c0095f2d1634191815410250fdc1cc0e67706a`，两个配置片段及四个模块安装包均已纳入。
