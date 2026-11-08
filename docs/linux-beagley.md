# linux-beagley 的管理与 Yocto 对接

## 当前仓库

- 路径：项目根目录下的 `sources/linux-beagley`，独立 Git 仓库。
- 上游：`https://github.com/beagleboard/linux.git`，remote 名为 `upstream`。
- 上游分支：`v6.12.57-ti-arm64-r64`。
- 项目集成分支：`beagley/6.12`。
- 基线提交：`2eea568f445af33f3280261904bf1027b02512d8`。
- 基线标签：`baseline/beagleboard-6.12.57-20261108`。
- 提交身份：`yxing.f <yxing.f@xx.com>`，仅对本仓库生效。

仓库从本地完整下载缓存克隆，未使用 `--shared`，未使用对象硬链接或 alternates；Git 对象独立于 Yocto 缓存。保留缓存中已有的历史，没有在初始化过程中联网更新上游。基线源码保持不变，项目管理文档位于本 layer。

标签描述的是已验证镜像所用的上游内核源码提交；镜像中的 AI overlay、内存布局和固件还由 layer 生成。完整回退需要同时选择匹配的 layer 版本和构建配置。

## 当前 Yocto 配置

主构建目录 `build/conf/local.conf` 已启用：

```bitbake
require conf/distro/include/beagley-kernel-local.inc
```

该 include 由本 layer 管理，以 `protocol=file` 从 `sources/linux-beagley` 获取固定提交。它使用现有 `linux-bb.org` 配方，继续应用 AI overlay 生成与内存布局校验任务。这里不是 `externalsrc`：BitBake 在自身工作区编译，不直接编译开发 checkout；只有提交并选定的版本会进入构建。

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

新工作区需先恢复 layer 和内核仓库，再在构建配置中启用该 include。仅恢复上游 TI layer 清单尚不能恢复本项目的本地仓库和配置。

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

## 配置远端与发布

当前没有项目远端 `origin`。在 Git 服务创建空仓库后执行（替换地址）：

```bash
git remote add origin <项目内核仓库地址>
git push -u origin beagley/6.12
git push origin baseline/beagleboard-6.12.57-20261108
```

然后移除 `local.conf` 中本地内核 include，改由 layer 的内核 `.bbappend` 指向远端，并固定提交。例如 HTTPS 源：

```bitbake
KERNEL_GIT_URI:beagley-ai = "git://<主机>/<组织>/linux-beagley.git"
KERNEL_GIT_PROTOCOL:beagley-ai = "https"
BRANCH:beagley-ai = "beagley/6.12"
SRCREV:beagley-ai = "<已推送的完整提交 SHA>"
```

发布时记录内核提交、layer 提交、构建配置和镜像 SHA256。基线标签保持不变，新里程碑创建新标签。远端创建和推送尚未执行，本地仓库不是异机备份。

## 摄像头与屏幕统一默认分支（2026-11-08）

默认 `beagley/6.12` 现已纳入 OVX3H、MAX96716A、MAX96717 固定拓扑摄像头框架和 YXMA023EHD panel 框架。统一提交为 `62c0095f2d1634191815410250fdc1cc0e67706a`，Yocto 本地源的固定版本已同步。旧 feature worktree 保留作历史对照，后续修改在默认分支提交。

两个驱动构建开关默认启用，EdgeAI 镜像显式包含四个模块。屏幕 DTBO 源码由内核仓库维护，不再由 layer 注入；硬件节点仍禁用。摄像头寄存器 profile、CSI0 硬件 overlay 和屏幕电源/复位/MUX 配置待补齐。
