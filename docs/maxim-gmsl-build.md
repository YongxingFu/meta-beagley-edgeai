# MAX96716A / MAX96717 编译验证配置

这是用于编译和集成评估的实验配置，尚未完成设备树、Sensor、板上加载及视频采集验证。不要将其作为已验证产品镜像。

- 内核分支：`feature/maxim-gmsl2`
- 内核提交：`64f75630fdf1220bc1e1ff4391a0bbf6296ddf63`
- 开发 worktree：`sources/linux-beagley-gmsl`
- Yocto 获取源：`sources/linux-beagley`；功能分支引用与 worktree 共用同一个 Git 仓库。
- 默认构建依然使用 `beagley/6.12`，需要显式选择本实验配置。

从项目根目录进入 `build`：

```bash
. conf/setenv
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
bitbake -R ../sources/meta-beagley-edgeai/conf/distro/include/beagley-kernel-gmsl-compile.inc -e linux-bb.org | \
  rg '^(BRANCH|SRCREV|SRC_URI|KERNEL_CONFIG_FRAGMENTS)='
bitbake -R ../sources/meta-beagley-edgeai/conf/distro/include/beagley-kernel-gmsl-compile.inc -c compile linux-bb.org
```

配置片段关闭原有 `VIDEO_MAX96717`，启用 `VIDEO_MAXIM_SERDES`、
`VIDEO_MAX96717_GMSL` 和 `VIDEO_MAX9296A`。独立 worktree 中未提交的变更不会被 BitBake 构建：更新驱动后先提交，再将 include 中的完整 SHA 更新到新提交。

内核还修改 media-core；驱动模块不能直接安装到未经修改的现有内核。完整来源、6.12 兼容性及多输出链路频率限制见内核仓库 `Documentation/admin-guide/media/beagley-maxim-gmsl2.rst`。

## 2026-11-08 编译结果

基于上面的内核提交、当前 BeagleY-AI 内核 `.config` 和 Yocto 的 AArch64 GCC 13.4 工具链，在独立输出目录完成：

- `Image` 和 `dtbs` 构建成功；包括 `k3-am67a-beagley-ai.dtb`。
- 以模块方式编译并经 modpost 链接 `max-serdes.ko`、`max9296a.ko`、`max96717.ko` 和修改过的 `mc.ko`。
- modpost 使用当前已构建的 6.12 基线 `Module.symvers`；这不是完整 Yocto 新内核的模块打包或 ABI 验证。
- `bitbake -e` 已确认实验配置选择该功能分支、固定提交及 `maxim-gmsl.cfg`。尚未执行实验配置下的 Yocto 完整内核构建或镜像构建。

构建日志、`.config`、Image、基础 DTB 和模块临时保存于 `build/validation/maxim-gmsl2/`；该目录属于构建产物，不在 Git 中。独立构建未执行 Yocto 的 AI 固件和 overlay 集成任务，产物不应直接用于替换板上运行的内核。
