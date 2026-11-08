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
