# 根文件系统

根文件系统 (Rootfs) 是 Linux 运行时挂载的第一个文件系统，包含系统运行所需的所有程序和配置。

---

## 📚 章节目录

| 章节 | 标题 | 内容 |
|------|------|------|
| 01 | [Rootfs 概述](01_rootfs_overview) | 根文件系统简介 |
| 02 | [BusyBox 编译](02_busybox_compile) | BusyBox 配置与编译 |
| 03 | [inittab 与 init](03_inittab_init) | 启动流程详解 |
| 04 | [目录结构](04_rootfs_structure) | 文件系统布局 |
| 05 | [NFS 挂载](05_nfs_wsl_troubleshoot) | 网络文件系统 |
| 06 | [应用集成](06_apps_integration) | 添加自定义程序 |

---

## 🎯 学习目标

完成本教程后，你将：

- ✅ 理解根文件系统的作用
- ✅ 能够使用 BusyBox 构建最小 Rootfs
- ✅ 掌握 init 进程和 inittab 配置
- ✅ 能够配置 NFS 网络挂载
- ✅ 能够集成自定义应用程序

---

## 🔧 前置知识

- Linux 文件系统基础
- Shell 脚本基础
- 网络基本概念

---

## 📖 延伸阅读

- [BusyBox 官方文档](https://busybox.net/FAQ.html)
- [Linux 文件系统层次标准](https://refspecs.linuxfoundation.org/FHS_3.0/)
- [init 系统](https://en.wikipedia.org/wiki/Init)

---

## ➡️ 下一章

完成 Rootfs 学习后，继续 **驱动开发教程**。

---

## 🆘 相关资源

- NFS Rootfs 目录 —— 项目 Rootfs 参考
- Overlay 目录 —— 叠加层文件
