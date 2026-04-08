# IMX-Forge 综合实战教程

## 教程概述

本教程系列旨在手把手带你从零构建一个完整的 i.MX6ULL 嵌入式 Linux 系统。通过三个章节的实战指导，你将掌握从工具链配置到系统启动调试的完整技能链。

## 教程章节

### 第01章：实战项目概述

**文件**: [01_practical_overview.md](01_practical_overview)

本章介绍实战项目的整体框架和准备工作：
- 实战项目的目标和预期结果
- 项目预备知识清单
- 硬件要求和软件环境配置
- 完整构建流程概览
- 各组件版本选择说明

**适合人群**: 所有准备开始实战的读者

**预计阅读时间**: 20-30 分钟

---

### 第02章：从零构建完整系统

**文件**: [02_build_system.md](02_build_system)

本章是实战教程的核心，串讲完整的构建流程：
- 工具链验证
- U-Boot 编译（引用 U-Boot 教程关键点）
- Linux 内核编译（引用 Linux 教程关键点）
- BusyBox Rootfs 构建（引用 Rootfs 教程关键点）
- 整合所有组件
- 镜像烧录步骤
- 每一步的验证方法

**适合人群**: 已完成各组件独立编译学习的读者

**预计完成时间**: 2-4 小时（首次尝试）

---

### 第03章：系统启动与调试

**文件**: [03_boot_and_debug.md](03_boot_and_debug)

本章是实战教程的收官之作，教你如何让系统跑起来并排查问题：
- 系统启动前的准备
- 串口监控工具使用
- U-Boot 启动日志解读
- 内核启动日志解读
- Rootfs 挂载确认
- 常见启动失败案例
- 系统调试技巧汇总
- 成功启动后的验证

**适合人群**: 已完成系统构建并准备启动的读者

**预计完成时间**: 1-2 小时（调试时间因情况而异）

---

## 学习路径建议

```
工具链教程
    ↓
U-Boot 教程 (document/tutorial/uboot/)
    ↓
Linux 内核教程 (document/tutorial/kernel/)
    ↓
Rootfs 教程 (document/tutorial/rootfs/)
    ↓
【你在这里】综合实战教程
    │
    ├─ 01_practical_overview.md (项目概述)
    ├─ 02_build_system.md (构建系统)
    └─ 03_boot_and_debug.md (启动调试)
```

## 前置知识要求

在开始本教程之前，建议你已经：

1. 阅读《从 0 开始构建嵌入式 Linux 开发环境》工具链教程
2. 阅读 U-Boot 基础教程（至少前两章）
3. 了解 Linux 内核的基本概念
4. 熟悉 Linux 命令行操作

## 硬件要求

- **开发板**: 正点原子阿尔法 i.MX6ULL 开发板（或兼容板）
- **调试工具**: USB 转 TTL 串口线
- **存储**: Micro SD 卡（推荐 Class 10）
- **网络**: 以太网网线（可选但推荐）

## 软件环境

- **主机系统**: Ubuntu 20.04 / 22.04 / 24.04 LTS
- **工具链**: Arm GNU Toolchain 15.2.rel1
- **串口工具**: picocom / minicom / screen

## 常见问题

### Q: 必须使用正点原子开发板吗？
A: 不是。本教程以正点原子阿尔法为例，但原理通用，其他基于 i.MX6ULL 的板子也可参考，需调整设备树配置。

### Q: 可以用 Windows 系统吗？
A: 不推荐。本教程基于 Linux 环境，Windows 用户建议使用 WSL2。

### Q: 预计需要多时间完成？
A: 首次尝试需要 2-3 天，熟悉后可缩短至 2-4 小时。

## 相关资源

- **项目主页**: [IMX-Forge](https://github.com/your-repo)
- **U-Boot 官方文档**: [https://www.denx.de/wiki/U-Boot](https://www.denx.de/wiki/U-Boot)
- **Linux 内核文档**: [https://www.kernel.org/doc/html/latest/](https://www.kernel.org/doc/html/latest/)
- **BusyBox 官方网站**: [https://busybox.net/](https://busybox.net/)

## 贡献与反馈

如果你在实践过程中遇到问题或有改进建议，欢迎：

1. 提交 Issue 描述问题
2. 提交 PR 改进教程
3. 分享你的实践经验

## 版本历史

- **v1.0** (2026-03-15): 初版发布

---

**祝你在嵌入式开发的道路上越走越远！**
