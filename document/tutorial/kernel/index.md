# 内核教程

Linux 内核是嵌入式系统的核心，理解内核是成为高级嵌入式开发者的必经之路。

---

## 📚 章节目录

| 章节 | 标题 | 内容 |
|------|------|------|
| 01 | [内核概述](01_kernel_overview) | Linux 内核简介 |
| 02 | [内核编译](02_kernel_compile) | 获取源码、编译配置 |
| 03 | [内核配置](03_kernel_config) | make menuconfig 详解 |
| 04 | [内核模块](04_kernel_modules) | 模块开发与加载 |
| 05 | [设备树详解](05_kernel_device_tree) | 设备树深入解析 |
| 06 | [网络启动](06_wsl_network_boot) | TFTP/NFS 配置 |
| 07 | [驱动基础](07_driver_basic) | 字符设备驱动 |
| 08 | [启动调试](08_kernel_boot_debug) | 内核启动调试 |

---

## 🔄 双轨内核策略

IMX-Forge 支持两种内核：

| 轨道 | 版本 | 特点 | 适用场景 |
|------|------|------|----------|
| **linux-imx** | NXP BSP 6.12.3 | 稳定，驱动完善 | 生产环境、新手 |
| **mainline** | 上游主线 | 长期维护，可贡献 | 追求最新特性 |

### Mainline 内核

**[mainline/](mainline/)** —— 上游主线内核专题

- [主线内核迁移](mainline) —— 如何迁移到主线

---

## 🎯 学习目标

完成本教程后，你将：

- ✅ 理解 Linux 内核的组成和启动流程
- ✅ 能够独立编译和配置内核
- ✅ 掌握设备树的编写方法
- ✅ 能够编写简单的字符设备驱动
- ✅ 熟悉内核调试技巧

---

## 🔧 前置知识

- C 语言高级特性
- 计算机组成原理
- U-Boot 基础

---

## 📖 延伸阅读

- [Linux 内核官方文档](https://www.kernel.org/doc/html/latest/)
- [Linux 设备树规范](https://www.devicetree.org/)
- [内核驱动开发指南](https://www.kernel.org/doc/html/latest/driver-api/)

---

## ➡️ 下一章

完成内核学习后，继续 **[根文件系统教程](../rootfs/)**。

---

## 🆘 相关资源

- 设备树完全参考
- [i.MX6ULL 参考手册](https://www.nxp.com/docs/en/reference-manual/IMX6ULLRM.pdf)
- 阿尔法开发板设备树
