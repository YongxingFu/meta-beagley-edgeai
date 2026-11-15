# BeagleY-AI / Processor SDK Analytics 11.02.02

目标：由 Yocto 构建 rootfs，生成可烧录至 microSD/TF 卡、包含 Edge AI
软件栈的 WIC 镜像，并进一步验证板上硬件推理。

## 当前状态

- 2026-11-08：用户已确认 Yocto 生成的镜像在板卡上验证正确。以下专项验收项保留各自记录，摄像头、屏幕和 AI 功能的验收范围需单独确认。
- 基线为 `processor-sdk-analytics-11.02.02-config.txt`。
- 使用 `MACHINE = "beagley-ai"`、`ARAGO_BRAND = "edgeai"`。
- 并行参数为 `BB_NUMBER_THREADS = "4"`、`PARALLEL_MAKE = "-j 8"`。
- 默认 Beagle BSP 为 `bb_org-6_12`，使用 `linux-bb.org` 与 `u-boot-bb.org`。
- 修正 foundational layer 对所有 J722S 请求 `uEnv-sk.txt` 导致的解析失败。
- 增加 BeagleY-AI 自己的 microSD 启动环境。
- 使用两分区 `sdimage-2part.wks`，通过 FAT 分区的 `uEnv.txt` 调用
  `bootcmd_ti_mmc`，从 rootfs 的 `/boot/Image` 和 `/boot/dtb/ti/` 加载内核及设备树。
- 为 C7000 5.0.0.LTS、Arm LLVM 4.0.4.LTS、SysConfig 1.26.2+4477
  增加 native 配方，固件工具由 Yocto 管理，不安装进目标 rootfs。

当前 `uEnv.txt` 已接入 AI overlay，并启动 main R5F 和两个 C7x；对应的固件、
overlay 和用户态头文件由同一份生成后的内存布局配套提供。内核安装前会应用
overlay 并自动验证其与固件头文件一致。WIC 镜像构建及镜像板上验证已完成。

## 仓库管理

本目录作为独立 Git 仓库管理，默认分支为 `main`。保存配方、补丁、配置、文档和脚本；构建缓存与镜像保留在项目构建目录及制品存储中。

当前尚未配置远端。配置远端并推送后，应在外层 `yocto-build` 的项目清单中记录本仓库 URL 和固定提交，供其他工作区恢复。

完整工作区恢复步骤、TI SDK 基线、内核固定提交与镜像构建命令见[镜像复现说明](docs/reproducible-build.md)。发布镜像时应补全该说明中的 layer 仓库 URL 和固定提交，并记录镜像 SHA-256。

TI `oe-layersetup` 工作区中的项目文档、脚本以及原始本地提交索引已迁入 [`docs/yocto-build-migration/`](docs/yocto-build-migration/README.md)。

项目内核仓库已创建于 `sources/linux-beagley`；分支、基线标签、本地 Yocto 接入及后续远端切换见 [内核仓库指南](docs/linux-beagley.md)。

在本目录使用 `git status`、`git diff`、`git log` 查看修改与历史；外层仓库忽略 `sources`，不会代替本仓库保存修改。

## 摄像头与屏幕默认内核

OX03H10 / MAX96717 / MAX96716A 摄像头驱动和当前 YX50093ACT LVDS 屏幕开发仓库的完整历史分支为 `beagley/6.12`；GitHub 发布分支 `beagley/6.12-snapshot` 只保留当前源码快照。Yocto 固定提交为 `2fe5bb7cad42dd9269f9347d0806c797a210796c`。摄像头配置为 1920×1536 BGGR RAW12 60 fps，默认安装模块并启用 `ox03h10-legacy-600` CSI0 overlay 与 `yx50093act` OLDI/LVDS overlay。camera overlay 的 MAX96716A 输出端声明 600 MHz（寄存器 `0x0320=0x2c` 对应 1200 Mbit/s/lane），sensor 端声明 750 MHz。2026-11-12 冷启动后，RAW/ISP 采集、LVDS 实时预览和 DSS 硬件缩放路径已复测正常；长时间显示稳定性与自动 AE/AWB、颜色标定仍需专项验收。

详情见 [摄像头构建说明](docs/maxim-gmsl-build.md) 和 [屏幕框架说明](docs/yxma023ehd-bringup.md)。

## AI 配套与验收

TIDL 模型与运行库的兼容性问题、板上验证结果、DMA-BUF 待查项及后续
Yocto 模型打包方案见 [`docs/tidl-model-compatibility.md`](docs/tidl-model-compatibility.md)。

1. AI overlay 接入 Beagle 6.12 内核：实际内核的 DTB 和 overlay 已生成并通过内存布局校验。
2. 4 GiB 地址布局：生成器已修改，11.02 生成结果已通过参考板级 DTB 检查。
3. R5F、C7x 固件：`ti-edgeai-firmware-beagley` 已从 11.02 SDK 源码编译通过；板上运行尚待验证。
4. 用户态库：使用 11.02.02.07 manifest，并从固件 sysroot 同步生成后的头文件；Vision Apps 和 TIDL 已通过独立 Yocto 构建。
5. Edge AI 推理封装：已适配 11.02 ONNX Runtime TIDL 键值参数接口，并通过单独编译。
6. 启动流程：已设置匹配 overlay 和远端核列表，待镜像及板上验证。
7. WIC 分区、启动文件、设备树、AI 固件、TIDL 库与 rootfs 包清单已检查。
8. 待板上验证启动、remoteproc、IPC、DMA heap 和文件输入硬件推理。

Rootfs 由 Yocto 配方生成和管理。RTOS SDK 源码包只用于固件重建和内存布局生成。
当前 TI `ti-tidl-osrt` 配方仍使用厂商提供的预编译 ONNX Runtime、TFLite 等
运行库和 Python wheel，因此整个 rootfs 并非所有软件都从源码编译。

已确认上游配方原来选用的 Vision Apps 的 `DDR_SHARED_MEM_PHYS_ADDR` 是
`0x900000000`，超出 BeagleY-AI 的 RAM 范围，不能直接沿用。
11.00 BeagleBoard 移植源码提供参考布局，其共享内存物理地址为
`0x8a0000000`，但移植时仍需与 11.02 的固件及通信布局核对。

固件重建源包：
`ti-processor-sdk-rtos-j722s-evm-11_02_02_04.tar.gz`

TI 发布页提供的 SHA256：
`c176a4599e8c702bdae6c955c108699ccefbaaf3d1523c530ef60d31c3dd8105`

## 构建和产物

从 `yocto-build/build` 执行：

```bash
. conf/setenv
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
MACHINE=beagley-ai bitbake tisdk-edgeai-image
```

构建日志：`build/logs/beagley-edgeai-build.log`。
预期产物目录：`build/deploy-ti/images/beagley-ai/`。

首次构建缓存接近为空，完整任务图约 15577 项。镜像生成、板卡启动和
硬件推理是不同验收点，需分别记录结果。

## 内存检查

`scripts/check-memory-map.py <已应用 overlay 的 DTB> <固件 app_mem_map.h>`
会核对所有活动保留区是否位于 RAM 内，并比较 R5F/C7x 代码及 IPC 区域、
共享内存和日志/对象描述符的范围。

工具已在 11.00 Beagle 参考设备树和配套头文件上通过检查，确认其 17 个保留区
均位于 4 GiB RAM 内；换用当前配方的头文件会因共享内存地址不同而失败。
新 11.02 生成器与参考板级 DTB 合并后，19 个活动保留区已通过范围和一致性检查。
实际 11.02 Beagle 内核编译出的 DTB 与 overlay 已通过同样检查：
19 个活动保留区位于 4 GiB RAM 内，共享区为 0x8a0000000、512 MiB。

## 下载和恢复

TI Git 的完整克隆在当前网络下返回 HTTP 501。`scripts/prime-ti-sources.sh`
按 11.02 配方指定的提交进行浅获取并填充本机下载缓存；这些缓存不包含完整历史，
本地分支引用指向该固定提交，因此不能用它验证提交是否属于上游分支历史。
构建脚本 `scripts/build-image.sh` 会记录日志、禁止系统睡眠并使用增量缓存。
若构建失败，先检查日志中的 `ERROR:`，修复后可再次运行该脚本。

此浅获取解决的是 TI SDK 部分仓库无法完整克隆的问题：脚本对每个指定的 TI 仓库和固定提交运行 `git fetch --depth=1`，再将对象放入 Yocto 的 `downloads/git2` 缓存。内核仓库采用不同方式：`linux-beagley` 从本机现有的完整 BeagleBoard Linux 缓存独立克隆，当前不是浅仓库。

## 2026-11-08 构建结果

- WIC：`build/deploy-ti/images/beagley-ai/tisdk-edgeai-image-beagley-ai.rootfs.wic.xz`
- SHA-256：`31d6b7c9548c6c3f718904e1ad5e370873db1d0470cec5537b4652069bd99a36`
- 解压大小：14,470,484,992 字节；MBR、128 MiB FAT 启动分区及 ext4 根分区。
- 已在实际 WIC 内核对启动文件、板级设备树、三个 AI 固件和 ONNX/TFLite TIDL 库。
- rootfs 含 opkg 数据库和 14 个 ONNX/TFLite 模型文件。
- 构建存在 GStreamer 构建路径 QA 警告，尚未在实体板上验证启动或推理。
