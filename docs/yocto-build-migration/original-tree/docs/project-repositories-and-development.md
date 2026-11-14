# BeagleY-AI 项目仓库与开发指南

适用范围：BeagleY-AI / AM67A，Yocto 构建，后续接入 GMSL 摄像头、DSI 屏幕，以及视频和 AI 应用。

本文根据 2026-11-08 的本地工程编写。标为“建议”的仓库、分支和目录尚未创建；示例中的组织名、提交和设备参数需要替换。本文不表示摄像头、屏幕或 AI 链路已经通过板上验收。

板上状态：用户已确认 Yocto 生成的镜像在板卡上验证正确。摄像头、DSI 屏幕及具体 AI 应用的专项验收范围仍需单独记录，不能从镜像验证结果推定。

2026-11-10 更新：主内核仓库现固定为 `0437cebcb1316ba9b7046fc147ce7daa24cced0d`，包含已验证的 MAX96717 启流修复及已有 OLED 修改。下文保留项目初期规划；当前摄像头、ISP 测试范围见 [ISP 实现记录](ox03h10-isp-streaming.md)。完整组合镜像和自动 AE/AWB 仍待验收。

## 1. 当前工程与基线

当前目录 `yocto-build` 是构建配置与上游 layer 获取入口，使用 TI 的 `oe-layertool-setup.sh` 及配置清单组织源码。

| 项目 | 当前值或位置 |
| --- | --- |
| SDK 配置基线 | `configs/processor-sdk-analytics/processor-sdk-analytics-11.02.02-config.txt` |
| Machine / Distro | `beagley-ai` / `arago` |
| 品牌配置 | `ARAGO_BRAND = "edgeai"` |
| BSP | `bb_org-6_12`，`linux-bb.org` 与 `u-boot-bb.org` |
| 内核上游 | `https://github.com/beagleboard/linux.git` |
| 内核分支 | `v6.12.57-ti-arm64-r64` |
| 内核提交 | `2eea568f445af33f3280261904bf1027b02512d8` |
| 自定义 layer | `sources/meta-beagley-edgeai` |
| 主构建目录 | `build` |
| 镜像目标 | `tisdk-edgeai-image` |
| 部署产物 | `build/deploy-ti/images/beagley-ai/` |

上游 layer 清单锁定的是各 layer 的版本；内核、应用、固件等配方获取的源码还需要由各配方的 `SRCREV` 或归档校验值锁定。只记录 layer 分支名不足以重建同一镜像。

当前自定义 layer 已包含：启动环境、Edge AI 镜像调整、TI 固件工具配方、BeagleY-AI 远端核固件和内存布局适配、Vision Apps/TIDL 适配及构建检查脚本。详细状态见其 `README.md` 与 `docs/tidl-model-compatibility.md`，并以实际测试记录为准。

### 拉取 TI 基线后的修改核对

以本节所列 SDK 配置清单为基线，本地 `sources` 下的 12 个上游 Git 仓库工作区均干净，HEAD 与清单指定版本一致（将 tag 解析为 commit 后比较）。包括 `meta-ti`、`meta-edgeai`、`meta-tisdk`、`meta-arago`、`bitbake`、`oe-core`、`meta-openembedded`、`meta-arm`、`meta-clang`、`meta-lts-mixins`、`meta-qt6` 和 `meta-virtualization`。

其中 `meta-tisdk` 清单值 `3ab112850d7f52f3ab443b2a01e863ca29d7ebee` 是 annotated tag 对象，解析到提交 `8ccd0f212ef01517a9c92f77dfb4da0f4ee0cb65`，与本地 HEAD 一致，并非额外修改。

项目改动集中在新增的 `sources/meta-beagley-edgeai`。上游 layer 保持原样，不代表配方构建的组件源码没有变化：该 layer 会在获取源码后应用补丁或在任务中生成/调整文件。

| 被适配组件 | layer 管理的修改 |
| --- | --- |
| Linux | 生成并接入 AI 内存布局 DTSI/overlay，追加设备树构建目标，校验 DTB 与固件内存布局 |
| TI RTOS SDK / Vision Apps | 为 4 GiB RAM 调整布局生成器，重建远端核固件；用户态采用 11.02 manifest，同步生成的内存布局头文件，修正 demo 构建目录，调整共享内存探测 |
| TIDL | 调整共享内存适用性探测，减少不适用路径的诊断输出 |
| edgeai-dl-inferer | 对接 11.02 ONNX Runtime TIDL provider 参数 API |
| edgeai-apps-utils | 增加单通道 GRAY8 图像预处理 |
| ti-tidl-osrt | 安装阶段统一 Python wheel 与系统 ONNX Runtime 库的提供方式 |
| websocketd | 调整配方源码获取分支/参数 |
| 启动与镜像 | BeagleY-AI 的 uEnv、两分区镜像、固件包选择及配套构建配置 |
| 固件工具链 | 新增 C7000、Arm LLVM、SysConfig native 配方 |

Linux 构建工作区出现的 Makefile 修改和新增内存布局/overlay 文件，可由当前 layer 的任务解释。随后已建立独立的 `sources/linux-beagley` 项目仓库，开发分支为 `beagley/6.12`，基线标签为 `baseline/beagleboard-6.12.57-20261108`；主构建目录通过 layer 的可选 `beagley-kernel-local.inc` 接入固定提交。详细流程见 `sources/meta-beagley-edgeai/docs/linux-beagley.md`。根 `yocto-build` 的已追踪文件修改为指南入口 `README`；新增指南位于 `docs/`，当时尚未提交。

## 2. 建议维护的项目仓库

先维护三个核心仓库；应用开始独立开发时增加应用仓库。

| 仓库 | 职责 | 主要内容 |
| --- | --- | --- |
| `yocto-build` | 构建入口与版本组合 | 项目清单、配置模板、源码获取、CI、发布记录、跨仓库指南 |
| `meta-beagley-edgeai` | 产品集成 | `.bb`/`.bbappend`、内核配置片段、启动与镜像配置、固件适配、应用和模型打包、systemd 服务 |
| `linux-beagley` | 内核开发 | SerDes/Sensor/panel/bridge 驱动、内核设备树、CSI/DSI 相关修改 |
| `beagley-video-ai-apps` | 视频与 AI 应用 | GStreamer 管线、预览/UI、推理逻辑、业务接口、运行诊断、应用测试 |

`linux-beagley` 是建议的内部名称，表示派生自 `beagleboard/linux` 的完整 Linux 内核仓库，并非新的官方内核项目。继续使用当前 `linux-bb.org` 配方，通过自定义 layer 调整源码来源即可。

应用规模较小时，视频预览与 AI 应用可以共用一个仓库，按目录划分；在团队、依赖或发布周期明显分离后再拆仓库。

建议工作区布局：

```text
yocto-build/                       # Git：构建入口
├── configs/                       # 固定提交的构建配置
├── src/configs/                   # 配置生成源 XML
├── sample-files/                  # 可复用配置模板
├── docs/                          # 跨仓库文档及发布记录
├── sources/
│   ├── meta-beagley-edgeai/        # 独立 Git：产品集成
│   ├── linux-beagley/             # 独立 Git：当前实际内核开发仓库
│   ├── meta-ti/                   # 上游固定提交
│   ├── meta-edgeai/               # 上游固定提交
│   └── ...
├── build/                         # 构建工作区，不入源码仓库
├── downloads/                     # 下载缓存
└── build-beagley-tools/            # 辅助构建工作区

# 当前已将 linux-beagley 放在上述 sources/ 中，亦可独立放置并配置路径
beagley-video-ai-apps/              # 建议放工作区旁，独立 Git
```

内核与应用开发 checkout 的本地路径不应写死在发布配方中。发布配方从仓库获取固定提交。

### 当前优先整理项

首次核对时，根仓库 `.gitignore` 忽略 `/sources`，`sources/meta-beagley-edgeai` 没有独立 Git 仓库，也没有文件被根仓库追踪。随后已按用户要求初始化该 layer 的独立 Git 仓库，分支为 `main`，添加忽略规则和仓库说明，并完成首次提交 `60e3218`，提交身份为 `yxing.f <yxing.f@xx.com>`。远端和项目清单尚待接入。完整整理流程如下：

1. 先备份并审阅 layer 内全部文件，排除凭据、下载文件和构建产物。
2. 将 `meta-beagley-edgeai` 建立为独立仓库，提交当前可用基线。
3. 仓库可获取后，在项目清单中加入 URL、分支及固定提交，并生成/核对构建配置。
4. 将 `MACHINE`、`ARAGO_BRAND`、自定义 include 和 layer 接入写入受版本管理的项目配置或模板。
5. 在空工作区验证初始化流程，确认无需手动复制原工作区的文件。
6. 根仓库忽略辅助构建目录 `build-beagley-tools/`；发布镜像进入制品存储。

在自定义 layer 完成提交和备份前，不要删除或重新初始化 `sources`。本地初始化不会自动提供远端备份；尚未执行远端创建或推送。

## 3. 上游仓库的管理方式

| 仓库/组件 | 默认方式 | 需要派生仓库的时机 |
| --- | --- | --- |
| `meta-ti`、`meta-edgeai`、`meta-tisdk`、`meta-arago` | 清单固定提交，项目覆盖集中在自定义 layer | 存在无法通过 layer 表达且需长期维护的修改 |
| `oe-core`、`bitbake`、`meta-openembedded` 等 | 固定提交，按验证过的 SDK 组合升级 | 明确需要维护构建系统自身补丁 |
| BeagleBoard Linux | 项目内核仓库派生并固定基线 | 本项目计划持续开发摄像头/屏幕驱动，建议建立 |
| U-Boot | 使用现有配方，项目启动设置放 layer | 确实需要修改 U-Boot 源码时 |
| TI 固件、Vision Apps、TIDL | 锁定版本/校验值，有限修改以 layer 补丁管理 | 源码修改持续扩大、需要独立发布时 |

当前无需为每个上游 layer 建立内部 fork。需要可长期重建时，可另外配置上游 Git 镜像和 Yocto 源码镜像。

## 4. 修改应该放在哪里

| 修改类型 | 权威来源 |
| --- | --- |
| 摄像头 Sensor、MAX96716A/MAX96717 驱动 | `linux-beagley` |
| DSI panel、bridge、内核触摸驱动 | `linux-beagley` |
| 内核板级 DTS/DTSI/DT overlay 源码 | 原则上放 `linux-beagley` |
| 固件内存布局生成及其配套 AI overlay | 保留当前 layer 的生成和一致性检查流程 |
| 启用哪些内核功能、打包哪些 DTBO | `meta-beagley-edgeai` |
| U-Boot 启动参数、默认启用哪些 overlay | `meta-beagley-edgeai` |
| DCC/标定数据、模型、运行配置的安装 | layer 配方；参数源与大文件按下一节管理 |
| 应用算法、视频管线、UI 与恢复策略 | `beagley-video-ai-apps` |
| 服务安装、运行依赖、镜像包选择 | `meta-beagley-edgeai` |
| 跨仓库发布版本、验收报告 | `yocto-build` 的文档/发布记录 |

同一内核修改只保留一个权威来源。采用内核分支后，不再在 layer 中重复维护同一组驱动补丁。少量临时补丁可以由 layer 携带，但应明确何时转入内核仓库。

不要把 `build/.../work`、`work-shared/.../kernel-source` 或目标板上的手工修改作为唯一成果；这些位置可能在清理或重建时被覆盖。

## 5. 接入新的摄像头

### 5.1 接口与模式记录

每种摄像头建立一份硬件/模式说明，记录：完整料号、模组版本、接线图、供电/PoC、I²C 地址和别名、时钟/复位、lane 顺序及极性、分辨率/帧率、Bayer 排列、位宽、CSI 数据类型、VC、嵌入行、HDR/PWL 和同步方式。

当前规划的链路为：

```text
Sensor → MAX96717 → GMSL2 → MAX96716A → CSI0
       → V4L2 采集 → ISP（RAW 输入时）→ 视频/AI 应用
```

OVX3H 的完整料号和模组输出格式需要确认，不能直接按 OX03H10 或普通 Bayer RAW 假设。

### 5.2 驱动与设备树

1. 从当前已验证的 BeagleBoard 内核提交建立功能分支。
2. 使用单路固定拓扑，不引入通用 SerDes 路由框架、I²C ATR 或 media-core internal-pad 修改。
3. 接入 Sensor subdev，支持初始化、模式、曝光/增益、启停流等必要功能。
4. 配置远端 I²C、GPIO/时钟、CSI endpoint、数据 lane、频率和媒体拓扑。
5. 在 layer 中加入配置片段和 DTBO 打包/启动选择，锁定内核提交。

### 5.3 分层验收

按“本地 I²C → GMSL 锁定 → 远端器件识别 → 支持模式下的 SerDes 测试图 → Sensor RAW/YUV → ISP → 应用”推进。开始时使用一路摄像头、一个 VC、一个固定模式。

使用 `media-ctl -p`、`v4l2-ctl`、驱动状态日志和保存的样帧确认媒体图、实际格式、帧长度、帧率、丢帧及 CSI/GMSL 错误计数。设备节点通过媒体拓扑或稳定规则识别，不在产品代码中固定 `/dev/video0`。

RAW 采集通过后，单独验证 Bayer、黑电平、PWL 解压、DCC 以及曝光/白平衡闭环。HDR 数据能传到内存不等于已经完成 HDR 成像。YUV 模组根据实际能力评估直接预览路径。

## 6. 接入新的屏幕

摄像头使用 CSI0；屏幕连接共享的 CSI1/DSI0 接口，并配置为 DSI。具体连接依据板卡版本与原理图确认。

1. 记录 panel/bridge 完整型号、接口针脚、供电复位时序、lane 数、pixel format、显示时序、初始化命令、背光及触摸接口。
2. 在内核仓库适配 DRM panel/bridge 驱动、设备树连接和板级复用。
3. 在 layer 中启用内核配置、安装 DTBO、配置启动选项及必要用户态组件。
4. 用 `modetest` 等工具先验证测试图、分辨率、颜色和刷新率，再验证应用预览。
5. 单独验证触摸、背光、冷启动及项目需要的休眠恢复行为。

当前生成了 J722S EVM 的 DSI 屏 overlay，不能据此认定它可以直接应用于 BeagleY-AI。必须核对基板节点、GPIO、电源和复用配置。

验收记录包含可重复的测试条件、显示模式、启动成功率及异常现象。摄像头和屏幕各自通过后，再做联合测试。

## 7. 视频与 AI 应用开发

建议应用仓库按职责组织，目录名可根据语言和框架调整：

```text
beagley-video-ai-apps/
├── src/                       # 采集、处理、推理、显示、业务逻辑
├── configs/                   # 管线、摄像头模式和模型选择
├── tools/                     # 帧率、时间戳、链路状态等诊断工具
├── tests/                     # 文件输入、异常恢复及业务行为测试
├── docs/                      # 接口、部署和性能说明
└── LICENSE
```

应用接口应能配置输入、模式、模型和输出，先支持文件输入以便独立验证推理，再接入实时摄像头。管线根据实际支持的格式选择：

```text
RAW：V4L2 → TI ISP → NV12 → 缩放/预处理 → AI → 叠加/显示
YUV：V4L2 → 格式转换/缩放 → AI → 叠加/显示
```

先保证图像和推理正确，再评估 DMA-BUF、队列深度、缓冲池和硬件缩放，降低复制及延迟。DMA-BUF 支持要对整条管线验证，不能只看某一个插件的能力。

通过 layer 配方获取固定应用提交，声明许可证、构建和运行依赖，安装程序/配置/systemd 服务，并由镜像或 packagegroup 选择安装。应用主逻辑留在应用仓库，避免在配方中逐渐堆积业务代码。

无桌面预览可评估 DRM/KMS；需要 UI 时选择与桌面或合成器兼容的显示方式。开发时明确 DRM 设备使用关系，避免应用和桌面同时争用显示资源。

应用验收至少覆盖：文件输入正确性、实时输入、持续运行内存变化、帧率/延迟、启停流，以及需求中约定的断链恢复行为。AI 附加记录模型精度、预处理方式和硬件加速是否实际生效。

## 8. DCC、标定数据和模型

| 数据 | 管理要求 |
| --- | --- |
| ISP DCC | 关联 Sensor、镜头、模式和 ISP 工具/运行库版本；保留可获得的调参源文件 |
| 标定数据 | 区分模组型号的公共参数与每台设备的独立参数，记录标定方法和适用对象 |
| 原始 AI 模型 | 记录来源、许可证、训练/导出版本、输入输出和预处理 |
| TIDL 编译产物 | 记录编译工具、目标 SoC、量化方式、编译配置及兼容运行库 |
| RAW/视频样本 | 记录采集模式与用途，大文件放制品或数据存储 |

小型、允许共享的配置可随对应源码仓库管理。大型模型、视频、厂商受限文件和二进制参数放具有访问控制的制品存储，由配方通过版本和 SHA256 获取。不要在公共仓库提交受限的厂商寄存器资料。

每台设备的运行时标定和用户配置应有明确的数据分区或持久化位置，避免镜像升级直接覆盖。

## 9. Yocto 集成与开发循环

### 9.1 固定源码与配置

在 `meta-beagley-edgeai/recipes-kernel/linux/linux-bb.org_6.12.bbappend` 中覆盖项目内核来源。下面是模板，填写真实值后才能使用：

```bitbake
KERNEL_GIT_URI:beagley-ai = "git://<内部主机>/<组织>/linux-beagley.git"
KERNEL_GIT_PROTOCOL:beagley-ai = "https"
BRANCH:beagley-ai = "<项目内核分支>"
SRCREV:beagley-ai = "<完整提交 SHA>"
```

保持现有内存布局生成、依赖及校验任务；不要用简化示例替换整个 `.bbappend`。新内核分支仍需与当前配方和 TI 用户态/固件兼容。

该内核配方使用 `setup-defconfig.inc`，支持 `KERNEL_CONFIG_FRAGMENTS`。例如将配置片段加入 `SRC_URI`，并在同一 `.bbappend` 中追加：

```bitbake
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"
SRC_URI:append:beagley-ai = " file://camera-display.cfg"
KERNEL_CONFIG_FRAGMENTS:append:beagley-ai = " ${WORKDIR}/camera-display.cfg"
```

片段中填写所选驱动版本实际提供的 Kconfig 项，构建后核对最终 `.config`。只把 `.cfg` 加进 `SRC_URI` 不代表一定被合并。新增 overlay 还需纳入内核构建目标、`KERNEL_DEVICETREE` 和启动选择。

### 9.2 构建与验证

已初始化的当前工作区中，从项目根目录执行：

```bash
cd build
. conf/setenv
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
MACHINE=beagley-ai bitbake linux-bb.org
MACHINE=beagley-ai bitbake tisdk-edgeai-image
```

以上命令用于当前工作区，不等同于从空目录初始化项目的完整流程。初始化流程应在自定义 layer 纳管后，由项目清单和模板补齐并实测。

应用单独构建时运行 `bitbake <应用配方名>`。本地快速迭代可以使用 `devtool` 或开发专用 `externalsrc` 配置；发布前将修改提交到权威仓库，更新固定提交，并在去掉本地源码覆盖的环境构建。

不要把直接覆盖 SD 卡上的 Image/DTB 当作最终集成结果。完成调试后重建镜像，并从镜像启动验收。通常无需先执行 `cleanall`，保留正常增量缓存。

### 9.3 更新清单

本构建仓库的上游配置源位于 `src/configs/*.xml`，`configs/`、`kas/` 等格式由生成流程维护。建议创建项目专用配置，保留 TI 基线配置便于比较；按根 `README` 的流程修改 XML 并在 `src` 运行生成任务，审阅生成差异。

项目配置应能恢复所有 layer 及关键构建设置，不依赖被忽略的 `build/conf`。发布使用固定提交，避免 `AUTOREV`、浮动分支头或开发机绝对路径。

## 10. 分支、发布与验收

建议从当前固定内核提交建立项目集成分支，例如 `beagley/6.12`；功能分支可使用 `feature/gmsl2`、`feature/sensor-<型号>`、`feature/panel-<型号>`。提交拆分为公共框架回移、板级配置、具体设备支持和应用集成，便于审阅与后续升级。

跨仓库按以下顺序落地：

1. 内核或应用仓库提交功能，并完成对应验证。
2. layer 更新源码固定提交、配置和打包。
3. 构建仓库更新 layer 固定提交及发布记录。
4. 从固定版本组合重建镜像，完成板上验收并记录镜像校验值。

发布记录至少包含：

```text
发布编号 / 日期
yocto-build commit / 使用的项目配置
全部 layer 的固定提交
Linux commit / U-Boot 版本与提交
应用 commit
TI 固件 / Vision Apps / TIDL / GStreamer 插件版本
Sensor / SerDes / 屏幕 / 板卡版本及工作模式
DCC / 标定 / 模型版本与 SHA256
镜像文件名与 SHA256
构建环境 / 测试条件 / 测试结果 / 已知限制
```

构建产物、下载缓存和 sstate 不进入源码仓库。镜像、SDK、日志、调试符号、包清单及许可证资料按发布编号保存到制品存储。

升级内核或 TI SDK 时，单独安排兼容性验证，覆盖启动、内存布局、remoteproc/IPC、DMA-BUF、摄像头格式、ISP、显示和 AI。构建通过、板卡启动、采集成功、ISP 成像及 AI 正确运行是不同验收点，分别记录。

## 11. 建议的推进顺序

1. 将现有自定义 layer 纳管，建立可从空工作区恢复的项目清单。
2. 建立 `linux-beagley`，固定当前 BeagleBoard 内核基线。
3. 分别完成 DSI 测试图和 GMSL/CSI0 采集验收，再验证 ISP 与联合预览。
4. 建立应用仓库，以文件输入验证 AI，再接入实时视频。
5. 形成可复现镜像、参数/模型制品和板上发布验收记录。
