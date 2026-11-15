# linux-beagley 的管理与 Yocto 对接

## 当前仓库

- 路径：项目根目录下的 `sources/linux-beagley`，独立 Git 仓库。
- 上游：`https://github.com/beagleboard/linux.git`，remote 名为 `upstream`。
- 上游分支：`v6.12.57-ti-arm64-r64`。
- 本地开发分支（完整历史）：`beagley/6.12`。
- GitHub 发布分支（单提交源码快照）：`beagley/6.12-snapshot`。
- 发布快照提交：`2fe5bb7cad42dd9269f9347d0806c797a210796c`，源自本地开发提交 `380dd018bcd73f7b23b75f937495c85739f8dc71`。
- 基线提交：`2eea568f445af33f3280261904bf1027b02512d8`。
- 基线标签：`baseline/beagleboard-6.12.57-20261108`。
- 提交身份：`yxing.f <yxing.f@xx.com>`，仅对本仓库生效。

本地开发仓库从下载缓存完整克隆，保留上游历史，供驱动开发和审查。GitHub 上发布的是单提交快照分支，不含上游历史；这样新工作区只需下载快照所需源码对象。快照提交的树与本地开发提交 `380dd018bcd73f7b23b75f937495c85739f8dc71` 完全相同。

标签描述的是已验证镜像所用的上游内核源码提交；镜像中的 AI overlay、内存布局和固件还由 layer 生成。完整回退需要同时选择匹配的 layer 版本和构建配置。

## 当前 Yocto 配置

主构建目录 `build/conf/local.conf` 已启用：

```bitbake
require conf/distro/include/beagley-kernel-local.inc
```

该 include 由本 layer 管理，以 `protocol=file` 从 `sources/linux-beagley` 获取固定提交 `2fe5bb7cad42dd9269f9347d0806c797a210796c`，使用本地分支 `beagley/6.12-snapshot`。它使用现有 `linux-bb.org` 配方，继续应用 AI overlay 生成与内存布局校验任务。这里不是 `externalsrc`：BitBake 在自身工作区编译，不直接编译开发 checkout；只有提交并选定的版本会进入构建。

路径默认由 `${TOPDIR}/../sources/linux-beagley` 推导。若工作区不同，可在 `local.conf` 设置 `BEAGLEY_KERNEL_LOCAL_PATH`。辅助构建目录 `build-beagley-tools` 未自动切换。

在项目根目录运行：

```bash
cd build
. conf/setenv
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
bitbake -e linux-bb.org | rg '^(KERNEL_GIT_URI|KERNEL_GIT_PROTOCOL|BRANCH|SRCREV)='
bitbake linux-bb.org
bitbake tisdk-edgeai-image
```

新工作区需先恢复 layer 和内核快照仓库，再在构建配置中启用该 include。获取快照可使用 `git clone --depth=1 --branch beagley/6.12-snapshot https://github.com/YongxingFu/linux-beagley.git sources/linux-beagley`。仅恢复上游 TI layer 清单尚不能恢复本项目的本地仓库和配置。

## 驱动开发循环

从项目根目录进入内核仓库：

```bash
cd sources/linux-beagley
git switch -c feature/gmsl2 beagley/6.12
# 修改源码，按功能审阅并提交
git add <本次修改的文件>
git commit -m "media: add project camera support"
```

验证后将功能分支合并到 `beagley/6.12`；在构建配置中将 `BEAGLEY_KERNEL_SRCREV` 更新为合并后的完整提交 SHA。要直接测试功能分支，可同时设置：

```bitbake
BEAGLEY_KERNEL_BRANCH = "feature/gmsl2"
BEAGLEY_KERNEL_SRCREV = "<功能分支完整提交 SHA>"
```

`SRCREV` 必须属于所选分支。发布前将确认的默认分支和固定提交写入受版本管理的集成配置；不要只保留在 `build/conf/local.conf`。不使用 `AUTOREV` 发布。

驱动和常规内核设备树放内核仓库，内核配置片段、DTBO 选择及镜像打包放 layer。同一修改不同时维护为内核提交和 layer 补丁。现有 AI 内存布局生成与配套 overlay 继续由 layer 管理，避免与固件布局脱节。

## 回退基线

保留未提交修改后，可以从基线创建修复分支：

```bash
git switch -c fix/from-baseline baseline/beagleboard-6.12.57-20261108
```

Yocto 回退无需切换开发 checkout：将分支配置恢复为 `beagley/6.12`、固定提交恢复为上述基线 SHA，然后重新构建即可。需要复现整个系统时，也恢复匹配的 layer 和构建配置。

## GitHub 发布快照

远端 `origin` 指向 `git@github.com:YongxingFu/linux-beagley.git`，`upstream` 保留 BeagleBoard Linux。发布分支 `beagley/6.12-snapshot` 当前指向单提交快照 `2fe5bb7cad42dd9269f9347d0806c797a210796c`。另一个远端分支 `beagley/6.12` 目前也指向此快照；不要将本地完整历史开发分支直接推到这两个快照分支。

若发布新的源码状态，创建新的根快照提交并更新快照分支；构建配置必须同步更新 `BEAGLEY_KERNEL_SRCREV`。由于快照没有父提交，更新该发布分支时需明确使用 `--force-with-lease`，并先核对远端当前 SHA。每个已发布镜像都记录 layer SHA、快照 SHA、TI 配置和镜像 SHA256。

## 摄像头与屏幕统一默认分支（2026-11-08）

提交 `62c0095f2d16` 最初以 OVX3H 框架名纳入 MAX96716A/MAX96717 固定拓扑；寄存器 CSV 标明的实际传感器是 OX03H10。后续驱动按 OX03H10 命名，模式已配置为 1920x1536 BGGR RAW12 60 fps，并新增 CSI0 GMSL overlay；CSV 的 VTS=814 与图像高度不符，需硬件确认。旧 feature worktree 保留作历史对照，后续修改在默认分支提交。

两个驱动构建开关默认启用，EdgeAI 镜像显式包含四个模块。屏幕 DTBO 源码由内核仓库维护，不再由 layer 注入；硬件节点仍禁用。摄像头寄存器 profile 与 CSI0 overlay 已接入；当前 MAX96717 基线及验收范围见 [摄像头构建说明](maxim-gmsl-build.md)。

2026-11-10：将已验证的 MAX96717 修复 `14dbaed8e5e2` 合入主仓库，得到 `0437cebcb1316ba9b7046fc147ce7daa24cced0d`，并同步 Yocto 固定提交。layer 不再重复应用 serializer 实验补丁。该组合保留主分支已有 OLED 修改，完整镜像待重新构建验收。
