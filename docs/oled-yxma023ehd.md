# BeagleY-AI YXMA023EHD OLED

2026-11-10：已在 BeagleY-AI CSI1/DSI0 接口、40-pin 转接板、YXMA023EHD OLED
组合上验证 TI Edge AI Gallery 启动画面和 modetest 静态图显示。
长期运行及反复冷启动稳定性尚未验证。

## 源码和构建

正式实现已提交到独立 `linux-beagley` 仓库的 `beagley/6.12` 分支：

| 提交 | 内容 |
| --- | --- |
| `4773da1cc402` | Tomi 的 Cadence stop-state、DPI bus flags 和时钟日志；说明额外 lane 的使能位 |
| `1198505462d2df7021771a3e14d6102ab5e16c49` | 面板 GPIO 电源/复位/开漏 CTRL 时序，I²C 初始化，DSI overlay |

本层 `beagley-kernel-local.inc` 默认固定到上述最终提交，不再通过临时
`yxma023ehd-adapter.patch` 覆盖旧版本。不要在新内核上重复应用该补丁。
本地源码配置应包含：

```bitbake
require conf/distro/include/beagley-kernel-local.inc
BEAGLEY_KERNEL_SRCREV = "1198505462d2df7021771a3e14d6102ab5e16c49"
BEAGLEY_ENABLE_YXMA023EHD = "1"
```

已有 `local.conf` 中的旧 SRCREV 会覆盖默认值，需要同步更新。
配置片段构建面板模块、Cadence DSI host 和 D-PHY；overlay 默认只构建，不自动启用。

```sh
bitbake linux-bb.org
```

部署时使用同一构建输出的 Image、模块和 dtbo。板上 `uEnv.txt` 的
`name_overlays` 保留现有项目，并追加：

```text
ti/k3-am67a-beagley-ai-yxma023ehd.dtbo
```

不要使用 `/tmp` 下跳过 I²C、30 Hz 或多 lane 的测试面板模块代替正式模块。

## 验证参数

| 项目 | 已验证设置 |
| --- | --- |
| 图像 | 640×400，RGB888，约 60 Hz |
| 水平 | HFP 96 / HSA 64 / HBP 58，总计 858 |
| 垂直 | VFP 63 / VSA 6 / VBP 56，总计 525 |
| 请求像素时钟 | 27.027 MHz；实际时钟受 PHY/VP 取整影响 |
| DSI | 单 lane，VC0，连续时钟，非 burst sync-pulse |
| 实际 lane 速率 / 时钟 | 650 Mbps / 325 MHz |
| BIST 关闭后的 I²C 读回 | `0x2850=0x00`，`0x2401=0x14` |
| 单 lane MAIN_PHY_CTL | `0x10`，bit0 是第二条数据 lane 的使能位，应为 0 |

查看 connector 和 CRTC 编号，再运行静态测试图：

```sh
modetest -M tidss -c -p
# 此次板上编号为 connector 51、CRTC 49；重新加载驱动后编号可能变化。
modetest -M tidss -s 51@49:640x400 -F tiles
```

测试进程需保持运行。此次带 `-v` 翻页测试时观察到闪烁，静态图显示成功；
尚未分析翻页闪烁的具体机制。DRM connected、翻页频率及控制器 WRITE 状态
均不能单独代替实际屏幕显示验证。

## 板上已验证产物

本次成功配置保存于 `/root/oled-stage/known-good-display-20261110/`，
包含内核、面板模块、overlay、启动配置、哈希清单和 DRM 状态。
这些是整理前的板上成功产物；本轮代码整理仅调整样式、注释和模块描述。

- Image SHA256：`6b94f08cd5716b3405002074dff5d4d9b65353efdbef92ce8c2f3d6516846c8d`
- 面板模块 SHA256：`826d21260ca12c128440a5181e7cd66d9987899b8828d5789bd04895e12694b4`

调试中错误的 `<=` lane 循环已经撤回，不进入提交。
Tomi 两项功能修复是否分别为本屏必需，尚未独立对照验证。

参考：[Tomi 的 Cadence 修复系列](https://lkml.iu.edu/2609.0/15472.html)。
