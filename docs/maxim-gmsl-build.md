# OVX3H fixed-topology GMSL camera framework

这是 BeagleY-AI 的单摄像头固定拓扑驱动框架，不包含 ADI v17 通用 SerDes
框架、I²C ATR 或 media-core internal-pad 修改。

当前链路：

```text
OVX3H -> MAX96717 -> MAX96716A -> AM67A CSI0
```

当前仅完成 V4L2、电源管理、媒体图、I²C gate 和模块编译框架。Sensor 与
MAX96716A 的具体寄存器 profile 尚未填写；未填写时驱动会拒绝 probe，避免
产生无法出图的假成功。

## 内核来源与默认构建

摄像头与 YXMA023EHD 屏幕框架已统一到 `sources/linux-beagley` 的默认分支 `beagley/6.12`。原 `sources/linux-beagley-gmsl` / `feature/maxim-gmsl2` worktree 保留供历史对照，原工作区的未提交内容未改写；后续开发应使用默认分支。

Yocto 从 `sources/linux-beagley` 获取固定提交，版本由 `conf/distro/include/beagley-kernel-local.inc` 的 `BEAGLEY_KERNEL_SRCREV` 指定。修改内核后需提交并更新该值。

`BEAGLEY_ENABLE_MAXIM_GMSL_LEGACY` 默认 1，配置片段启用：

```text
CONFIG_VIDEO_MAX96716A=m
CONFIG_VIDEO_MAX96717=m
CONFIG_VIDEO_OVX3H=m
```

从正常构建环境执行 `bitbake virtual/kernel` 或 `bitbake tisdk-edgeai-image` 即可，不必切实验分支或添加 `-R`。旧的 gmsl include 现为默认内核选择的兼容入口。

EdgeAI 镜像显式安装上述三个内核模块；屏幕模块同时默认构建和安装。尚未加入摄像头硬件 overlay，屏幕 overlay 默认禁用，不会因模块打包而自动启用未完成的硬件链路。

## 配置位置

寄存器、模式和控制配置的准确位置见内核仓库：

```text
Documentation/admin-guide/media/beagley-ovx3h-legacy.rst
```

主要入口：

- OVX3H：`drivers/media/i2c/ovx3h.c` 中的 `ovx3h_config`、
  `ovx3h_modes`、`ovx3h_init_controls()` 和电源函数。
- MAX96717：`drivers/media/i2c/max96717.c` 中的
  `max96717_hw_init()`、stream enable/disable 和 lane 初始化。
- MAX96716A：`drivers/media/i2c/max96716a.c` 中的
  `max96716a_hw_init()`、`max96716a_start_output()` 和
  `max96716a_stop_output()`。
- 设备树：在独立 CSI0 overlay 中增加 `max96716a -> i2c-gate ->
  max96717 -> i2c-gate -> ovx3h`。

## 当前验证结果

使用当前 6.12.57 和 Yocto AArch64 GCC 13.4 工具链：

- Kconfig `olddefconfig` 只选择 legacy MAX96716A、旧 MAX96717 和 OVX3H。
- `max96716a.ko`、`max96717.ko`、`ovx3h.ko` 编译及 modpost 通过。
- `checkpatch` 无错误或警告。
- DT binding YAML 语法解析通过；完整 `dt_binding_check` 因环境缺少
  `dt-doc-validate` 未执行。

尚未完成实板 probe、I²C gate 访问、GMSL 锁定、Sensor 出图和 CSI0 采集。

## 统一默认分支检查

统一提交 `62c0095f2d1634191815410250fdc1cc0e67706a` 后，四个驱动在同一 Kbuild 编译、MODPOST 和链接通过；使用默认配置合并两个片段后，`olddefconfig` 成功且四个驱动均为 `m`。BitBake `virtual/kernel` 和 `tisdk-edgeai-image` 配方解析通过，确认默认分支、固定提交、两个配置片段及四个显式安装包一致。未执行新的完整镜像构建或实板验证。
