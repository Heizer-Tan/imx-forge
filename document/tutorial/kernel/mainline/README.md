# i.MX6ULL 主线内核移植教程

本教程系列针对**正点原子 i.MX6ULL 开发板**，讲解如何从 NXP BSP 内核（6.12.x）迁移到 Linux 主线内核（7.0-rc4）。

## 教程目录

| 文件 | 标题 | 说明 |
|------|------|------|
| [01_why_mainline.md](01_why_mainline.md) | 为什么要折腾主线内核 | NXP BSP vs 主线内核的根本差异 |
| [02_env_setup.md](02_env_setup.md) | 从零开始搭建编译环境 | 依赖安装、工具链配置 |
| [03_source_fetch.md](03_source_fetch.md) | 获取主线内核源码 | kernel.org 克隆、补丁应用 |
| [04_bsp_vs_mainline.md](04_bsp_vs_mainline.md) | BSP vs 主线深度对比 | DRM 显示子系统、设备树 binding 变化 |
| [05_defconfig.md](05_defconfig.md) | 主线内核配置 | defconfig 配置、关键选项说明 |
| [06_dts_migration.md](06_dts_migration.md) | 设备树迁移 | OF graph 连接、sim2 节点补充 |
| [07_display_drm.md](07_display_drm.md) | DRM 显示系统移植 | LCD 驱动完整迁移指南 |
| [08_touch_gt9xx.md](08_touch_gt9xx.md) | 触摸屏移植 | GT9147/Goodix 驱动配置 |
| [09_network_dual_phy.md](09_network_dual_phy.md) | 双网口移植 | FEC + KSZ8081 以太网配置 |
| [10_debug_tricks.md](10_debug_tricks.md) | 调试技巧 | dmesg 分析、设备树验证、DRM 调试 |
| [11_common_issues.md](11_common_issues.md) | 常见问题 | 报错速查表、GPIO 冲突解决 |

## 快速开始

1. 阅读 [01_why_mainline.md](01_why_mainline.md) 了解主线内核的优势和代价
2. 跟随 [02_env_setup.md](02_env_setup.md) 搭建编译环境
3. 参考 [03_source_fetch.md](03_source_fetch.md) 获取主线源码并应用补丁
4. 学习 [04_bsp_vs_mainline.md](04_bsp_vs_mainline.md) 理解架构差异
5. 按 [05_defconfig.md](05_defconfig.md) 和 [06_dts_migration.md](06_dts_migration.md) 配置内核和设备树
6. 参考 [07_display_drm.md](07_display_drm.md)、[08_touch_gt9xx.md](08_touch_gt9xx.md)、[09_network_dual_phy.md](09_network_dual_phy.md) 移植具体外设
7. 使用 [10_debug_tricks.md](10_debug_tricks.md) 调试问题
8. 查阅 [11_common_issues.md](11_common_issues.md) 解决常见报错

## 技术要点

### DRM 显示系统

主线内核的 eLCDIF 驱动已迁移到 DRM 子系统，设备树写法从旧式的 `display = <&display0>` 变为 OF graph 的 `port/endpoint` 方式。

### 设备树 binding

- 旧 BSP：`&lcdif { display = <&display0>; display0: display@0 { ... }; }`
- 主线：`panel: panel-dpi { ... port { panel_in: endpoint { ... }; }; }; &lcdif { port { lcdif_out: endpoint { ... }; }; }`

### sim2 节点

主线内核的 `imx6ul.dtsi` 缺失 sim2 节点定义，移植时需要手动添加。

## 参考资源

| 文件 | 说明 |
|------|------|
| `scripts/build_helper/build-mainline-linux.sh` | 主线内核构建脚本 |
| `patches/linux_mainline/linux_mainline-feat-imx6ull_patches-20260322.patch` | 完整移植补丁 |
| `driver/device_tree/alpha-board/linux/imx6ull_mainline_defconfig.template` | defconfig 模板 |
| `document/tutorial/kernel/mainline/mainline_imgrate.md` | LCD 驱动排查指南（原始参考） |

## 硬件平台

- **芯片**：NXP i.MX6ULL (ARM Cortex-A7, 528MHz)
- **开发板**：正点原子 i.MX6ULL
- **显示**：7 寸 LCD (1024×600)
- **触摸**：Goodix GT9147
- **网络**：双 KSZ8081 PHY (RMII)

## 许可

本教程系列遵循项目的整体许可协议。
