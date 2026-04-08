# 教程系列

欢迎来到 IMX-Forge 教程系列！这里是系统学习嵌入式 Linux 开发的完整路径。

---

## 📚 教程目录

### 1️⃣ 入门准备

**[start/](start/)**

从零开始搭建开发环境：

- [工具链安装](start/01_start_from_toolchain) —— ARM GNU Toolchain 15.2

### 2️⃣ U-Boot 教程

**[uboot/](uboot/)**

深入理解 Bootloader：

- [U-Boot 简介](uboot/01_what_is_uboot) —— 什么是 U-Boot
- [编译与配置](uboot/02_uboot_compile) —— 编译 U-Boot
- [移植概述](uboot/03_uboot_porting_overview) —— 移植流程
- [板级配置](uboot/04_board_config_basic) —— 基础配置
- [设备树基础](uboot/05_device_tree_basics) —— 设备树入门
- [LCD 移植](uboot/06_lcd_porting) —— 显示屏驱动
- [网络移植](uboot/07_network_porting) —— 网络功能
- [Logo 定制](uboot/08_logo_splash) —— 启动画面
- [调试命令](uboot/09_debugging_commands) —— 常用命令
- [Q&A](uboot/bonus_qa) —— 常见问题

### 3️⃣ 内核教程

**[kernel/](kernel/)**

Linux 内核开发：

- [内核概述](kernel/01_kernel_overview) —— 内核简介
- [内核编译](kernel/02_kernel_compile) —— 编译流程
- [内核配置](kernel/03_kernel_config) —— 配置选项
- [内核模块](kernel/04_kernel_modules) —— 模块开发
- [设备树详解](kernel/05_kernel_device_tree) —— 设备树深入
- [网络启动](kernel/06_wsl_network_boot) —— TFTP/NFS
- [驱动基础](kernel/07_driver_basic) —— 驱动入门
- [启动调试](kernel/08_kernel_boot_debug) —— 调试技巧

#### Mainline 内核

**[kernel/mainline/](kernel/mainline/)**

上游主线内核：

- [主线内核迁移](kernel/mainline) —— 迁移指南

### 4️⃣ 根文件系统

**[rootfs/](rootfs/)**

构建嵌入式 Rootfs：

- [Rootfs 概述](rootfs/01_rootfs_overview) —— 基础概念
- [BusyBox 编译](rootfs/02_busybox_compile) —— 编译配置
- [inittab 与 init](rootfs/03_inittab_init) —— 启动流程
- [目录结构](rootfs/04_rootfs_structure) —— 文件系统布局
- [NFS 挂载](rootfs/05_nfs_wsl_troubleshoot) —— 网络文件系统
- [应用集成](rootfs/06_apps_integration) —— 添加应用程序

### 5️⃣ 驱动开发

**driver/**

Linux 驱动编写：

- 基础驱动 —— 从零开始
- 模块开发 —— 内核模块
- 固件应用 —— 固件加载

### 6️⃣ 实战演练

**[practical/](practical/)**

完整项目实战：

- [实战概述](practical/01_practical_overview) —— 项目介绍
- [构建系统](practical/02_build_system) —— 完整构建流程

---

## 🎯 推荐学习顺序

```mermaid
graph LR
    A[入门准备] --> B[U-Boot]
    B --> C[内核教程]
    C --> D[根文件系统]
    D --> E[驱动开发]
    E --> F[实战演练]
```

对于初学者，建议按顺序学习。如果你已经有一定经验，可以直接跳转到感兴趣的章节。

---

## 📝 学习建议

1. **边学边做** —— 每个章节都配有实践操作
2. **做好笔记** —— 记录遇到的问题和解决方案
3. **查阅官方文档** —— 遇到问题时优先参考官方文档
4. **动手实验** —— 尝试修改配置，观察效果

---

## 🆘 需要帮助？

- 查看 GitHub 仓库的 FAQ
- 提交 [GitHub Issue](https://github.com/Awesome-Embedded-Learning-Studio/imx-forge/issues)
- 参考 [官方文档链接](../index.md#-外部资源)
