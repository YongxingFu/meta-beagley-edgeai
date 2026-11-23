# BeagleY-AI 镜像从零构建说明

本文说明如何在一台新的 Linux 构建机上，先获取 TI Processor SDK Analytics 11.02.02 工程，再获取 BeagleY-AI 项目 layer 和内核仓库，最后构建可写入 microSD/TF 卡的 WIC 镜像。

工程目录由 TI 的 `oe-layersetup` 管理；BeagleY-AI 的 Yocto 配方、补丁和脚本保存在 `meta-beagley-edgeai`；内核源码保存在 `linux-beagley`。不要把项目修改提交到 TI 的 `oe-layersetup` 仓库。

## 1. 固定输入版本

| 输入 | 仓库/配置 | 本说明采用的版本 |
| --- | --- | --- |
| TI 工程配置工具 | `https://git.ti.com/git/arago-project/oe-layersetup.git` | `a5d7c4cb5afdee8300dc7ce2d6b7d64e23599b0b` |
| TI SDK 层清单 | `configs/processor-sdk-analytics/processor-sdk-analytics-11.02.02-config.txt` | 清单内固定的各仓库提交 |
| BeagleY-AI 集成层 | `https://github.com/YongxingFu/meta-beagley-edgeai.git` | `main` 分支；发布镜像时应记录实际检出的完整 SHA。已核对版本：`7759a35fb234e7df9aac16c30f81b966cfcfa1da` |
| BeagleY-AI 内核 | `https://github.com/YongxingFu/linux-beagley.git` | `beagley/6.12-snapshot`，提交 `2fe5bb7cad42dd9269f9347d0806c797a210796c` |
| Yocto machine / image | `beagley-ai` / `tisdk-edgeai-image` | 由下文配置启用 |

TI 配置清单将 OpenEmbedded、meta-ti、meta-arago 等仓库锁定到明确提交。使用这份清单即可复现对应 SDK 层组合；不要用其他版本的配置文件替换它。内核远端分支是单提交源码快照，用于减少首次下载量；不要将本地完整开发历史推送到该发布分支。

项目 layer 的 `main` 会随开发更新。复现某次已发布镜像时，使用发布记录中的 layer 完整 SHA，而不是移动的分支名。上表 SHA 是本说明编写时核对过的 layer 基线，可直接用于当前仓库版本。

## 2. 安装主机依赖

使用 TI/Yocto 支持的 Linux 构建主机，并按 TI Processor SDK Analytics 11.02.02 的安装说明安装构建依赖。主机需要 Git、Python、GNU make、编译工具链和足够的磁盘空间；首次构建还会从 TI、Yocto 和其他上游下载大量源代码与预编译工具。建议使用有线网络，并为源码下载、构建缓存和镜像预留充足空间。

以下命令假设所有内容放在 `~/work/beagley/yocto-build`。路径可以更改，但首次初始化、后续克隆和构建都要使用相同目录结构。

## 3. 获取 TI 工程和 SDK 层

先克隆 TI 的工程配置仓库，并检出本说明采用的版本：

```bash
mkdir -p ~/work/beagley
cd ~/work/beagley
git clone https://git.ti.com/git/arago-project/oe-layersetup.git yocto-build
cd yocto-build
git checkout a5d7c4cb5afdee8300dc7ce2d6b7d64e23599b0b
```

用 TI 提供的 11.02.02 配置文件获取 SDK 所需的上游仓库，并生成 `sources/`、`build/` 和构建环境文件：

```bash
./oe-layertool-setup.sh \
  -f configs/processor-sdk-analytics/processor-sdk-analytics-11.02.02-config.txt
```

脚本结束时会提示 `conf/setenv` 已生成。该文件记录本机工作区的绝对路径，因此不要从另一台机器复制旧的 `build/` 或 `conf/setenv`；每台新机器都应在自己的工程目录执行初始化。初始化会写入 `sources/`、`build/`，重复运行前先确认目标目录状态。

确认 TI 层清单已经配置完成：

```bash
cd build
. conf/setenv
bitbake-layers show-layers
```

## 4. 获取 BeagleY-AI 项目仓库

回到工程根目录，在 `sources/` 下分别克隆项目 layer 和内核快照：

```bash
cd ~/work/beagley/yocto-build
git clone https://github.com/YongxingFu/meta-beagley-edgeai.git sources/meta-beagley-edgeai
git -C sources/meta-beagley-edgeai checkout 7759a35fb234e7df9aac16c30f81b966cfcfa1da

git clone --depth=1 --branch beagley/6.12-snapshot \
  https://github.com/YongxingFu/linux-beagley.git sources/linux-beagley
git -C sources/linux-beagley checkout --detach 2fe5bb7cad42dd9269f9347d0806c797a210796c
```

核对检出的提交：

```bash
git -C sources/meta-beagley-edgeai rev-parse HEAD
git -C sources/linux-beagley rev-parse HEAD
```

layer 的版本应与发布记录一致；内核应输出 `2fe5bb7cad42dd9269f9347d0806c797a210796c`。发布新的镜像版本时，应先选择经过审查的 layer 提交，并将 SHA 与内核 SHA 一起记录。

## 5. 将 Beagle layer 加入构建配置

加载 TI 构建环境，然后把项目 layer 加入 `bblayers.conf`：

```bash
cd ~/work/beagley/yocto-build/build
. conf/setenv
bitbake-layers add-layer "$OEBASE/sources/meta-beagley-edgeai"
```

在 `build/conf/local.conf` 末尾加入以下设置：

```bitbake
MACHINE = "beagley-ai"
ARAGO_BRAND = "edgeai"
BB_NUMBER_THREADS = "4"
PARALLEL_MAKE = "-j 8"
require conf/distro/include/beagley-edgeai.inc
require conf/distro/include/beagley-kernel-local.inc
```

`beagley-kernel-local.inc` 从 `${TOPDIR}/../sources/linux-beagley` 读取已提交的固定内核快照，并让原有 `linux-bb.org` 配方继续执行。不要把未提交的内核工作区修改当成构建输入；要构建新修改，先提交并发布快照，再更新 layer 中的 kernel 分支和 `BEAGLEY_KERNEL_SRCREV`。

如果 `build/conf/local.conf` 已有 `MACHINE` 或并行参数定义，编辑原有定义，避免同一变量重复赋值造成配置不清楚。可检查最终配置：

```bash
bitbake-layers show-layers
bitbake -e linux-bb.org | rg '^(KERNEL_GIT_URI|KERNEL_GIT_PROTOCOL|BRANCH|SRCREV)='
bitbake -e tisdk-edgeai-image | rg '^(MACHINE|ARAGO_BRAND|IMAGE_BASENAME|DEPLOY_DIR_IMAGE)='
```

## 6. 构建镜像

在已加载环境的 `build/` 目录执行：

```bash
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
MACHINE=beagley-ai bitbake -k tisdk-edgeai-image
```

`-k` 会在部分任务失败后继续执行其他可执行任务，便于收集错误；构建最终仍以 BitBake 返回成功为准。也可以从工程根目录运行项目脚本，它会加载 `build/conf/setenv`、设置 machine 和语言环境、记录日志并阻止系统休眠：

```bash
sources/meta-beagley-edgeai/scripts/build-image.sh
```

脚本日志位于 `build/logs/beagley-edgeai-build.log`。不要同时从多个终端启动相同构建目录的 BitBake 构建。

## 7. 查找并校验 WIC 镜像

构建成功后，镜像位于：

```text
build/deploy-ti/images/beagley-ai/
```

预期 WIC 文件名：

```text
tisdk-edgeai-image-beagley-ai.rootfs.wic.xz
```

确认文件并计算校验和：

```bash
ls -lh build/deploy-ti/images/beagley-ai/tisdk-edgeai-image-beagley-ai.rootfs.wic.xz
sha256sum build/deploy-ti/images/beagley-ai/tisdk-edgeai-image-beagley-ai.rootfs.wic.xz
```

将 WIC 写入 microSD/TF 卡前，务必确认目标设备名，写入操作会覆盖整张卡。可使用 Raspberry Pi Imager、balenaEtcher 等镜像写入工具；在 Linux 上也可以按实际设备路径使用 `bmaptool copy` 或 `dd`。烧录后在 BeagleY-AI 上启动，并单独验证启动、网络、摄像头、显示和 Edge AI 功能。成功生成镜像只证明构建完成，不代表板上功能已经验收。

## 8. 保存每次构建的复现信息

发布或交付镜像时，至少记录以下信息：

```bash
git -C "$OEBASE" rev-parse HEAD
git -C "$OEBASE/sources/meta-beagley-edgeai" rev-parse HEAD
git -C "$OEBASE/sources/linux-beagley" rev-parse HEAD
sha256sum "$OEBASE/build/deploy-ti/images/beagley-ai/tisdk-edgeai-image-beagley-ai.rootfs.wic.xz"
```

同时保留所用 TI 配置文件名、构建日期、构建结果和板上验收情况。`build/`、`downloads/`、BitBake work 目录、日志和 WIC 镜像是本机缓存或构建产物，不应提交到 `meta-beagley-edgeai` 或 TI 的 `oe-layersetup` 仓库。
