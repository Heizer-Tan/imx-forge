# 欢迎来到 IMX-Forge 教程文档

<div align="center">

```
██╗███╗   ███╗██╗  ██╗      ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
██║████╗ ████║╚██╗██╔╝      ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
██║██╔████╔██║ ╚███╔╝ █████╗█████╗  ██║   ██║██████╔╝██║  ███╗█████╗
██║██║╚██╔╝██║ ██╔██╗ ╚════╝██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
██║██║ ╚═╝ ██║██╔╝ ██╗      ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
╚═╝╚═╝     ╚═╝╚═╝  ╚═╝      ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
```

**面向 NXP i.MX6ULL 的嵌入式 Linux 开发工坊**

从工具链到 QT 应用的完整学习路径

</div>

---

## 📚 文档导航

### 🚀 快速开始

如果你是第一次来这里，建议按照以下顺序阅读：

1. **[快速入门指南](../QUICK_START.md)** —— 5分钟快速体验项目
2. **[项目 README](../README.md)** —— 了解项目概况和特性
3. **[教程目录](tutorial/)** —— 开始系统学习

---

## 🗂️ 文档分类

### 教程系列 (Tutorial)

从零开始，系统学习嵌入式 Linux 开发：

| 教程 | 描述 | 状态 |
|------|------|------|
| **[入门准备](tutorial/start/)** | 工具链安装、环境搭建 | ✅ 完整 |
| **[U-Boot 教程](tutorial/uboot/)** | Bootloader 原理、编译、移植 | ✅ 完整 |
| **[内核教程](tutorial/kernel/)** | 内核配置、设备树、驱动开发 | ✅ 完整 |
| **[Mainline 内核](tutorial/kernel/mainline/)** | 上游主线内核迁移 | ✅ 已完成 |
| **[根文件系统](tutorial/rootfs/)** | BusyBox、inittab、NFS 挂载 | ✅ 完整 |
| **[驱动开发](tutorial/driver/)** | 驱动编写、模块、固件 | 🚧 WIP |
| **[实战演练](tutorial/practical/)** | 完整项目实战 | ✅ 基础完成 |

### 架构文档 (Architecture)

深入了解项目的设计和实现：

- **[系统架构](architecture/SYSTEM_ARCHITECTURE.md)** —— 整体架构设计
- **[构建系统](architecture/BUILD_SYSTEM.md)** —— 构建脚本详解
- **[补丁系统](architecture/PATCH_SYSTEM.md)** —— 双轨补丁管理

### 开发指南 (Development)

- **[环境搭建](development/ENVIRONMENT_SETUP.md)** —— 开发环境配置

### 参考手册 (Reference)

- **[设备树指南](modules/DEVICE_TREE_GUIDE.md)** —— 设备树完全参考

### 脚本文档 (Scripts)

- **[构建脚本](scripts/)** —— 构建系统脚本说明
- **[补丁工具](scripts/patch_maker.sh.md)** —— 补丁生成工具

### 项目规划 (Todo)

- **[项目规划](todo/project.md)** —— 功能规划
- **[待办事项](todo/todo.md)** —— 当前进度

---

## 🎯 学习路径

### 初学者路径

```mermaid
graph LR
    A[工具链] --> B[U-Boot]
    B --> C[内核配置]
    C --> D[设备树]
    D --> E[Rootfs]
    E --> F[驱动开发]
```

### 进阶路径

- **双轨内核策略**：了解 NXP BSP 和 Mainline 内核的区别
- **QT 应用开发**：使用 `qt-compile-pipeline` 构建图形界面
- **网络启动**：配置 TFTP/NFS 提高开发效率
- **驱动移植**：为自制板编写驱动

---

## 📖 外部资源

### 官方文档

> [!IMPORTANT]
> 教程具备时效性，嵌入式开发技术更新迅速，请自行对比时间参考。
> 官方文档总是你的第一参考人：

| 项目 | 官方文档 |
|------|----------|
| **U-Boot** | [https://www.denx.de/wiki/U-Boot](https://www.denx.de/wiki/U-Boot) |
| **Linux 内核** | [https://www.kernel.org/doc/html/latest/](https://www.kernel.org/doc/html/latest/) |
| **BusyBox** | [https://busybox.net/FAQ.html](https://busybox.net/FAQ.html) |
| **Device Tree** | [https://www.devicetree.org/](https://www.devicetree.org/) |
| **NXP i.MX6ULL** | [https://www.nxp.com/products/processors-and-microcontrollers/arm-processors/i-mx-applications-processors/i-mx-6-processors:IMX6ULL](https://www.nxp.com/products/processors-and-microcontrollers/arm-processors/i-mx-applications-processors/i-mx-6-processors:IMX6ULL) |

### 相关链接

- **GitHub 仓库**: [https://github.com/Awesome-Embedded-Learning-Studio/imx-forge](https://github.com/Awesome-Embedded-Learning-Studio/imx-forge)
- **在线文档**: [https://awesome-embedded-learning-studio.github.io/imx-forge/](https://awesome-embedded-learning-studio.github.io/imx-forge/)
- **问题反馈**: [GitHub Issues](https://github.com/Awesome-Embedded-Learning-Studio/imx-forge/issues)

---

## 🛠️ 技术栈

```
┌─────────────────────────────────────────────────────────────┐
│                    IMX-Forge 技术栈                          │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  开发环境: WSL2 / Ubuntu 22.04+                              │
│  工具链:   ARM GNU Toolchain 15.2                            │
│                                                               │
│  Bootloader: U-Boot 2025.04 (NXP fork)                       │
│  内核:       Linux 6.12.3 (NXP BSP) / Mainline               │
│  Rootfs:     BusyBox + 自定义脚本                             │
│                                                               │
│  构建系统:   Bash + Make                                      │
│  文档系统:   MkDocs + Material Theme                          │
│                                                               │
│  [可选] QT:   QT6 交叉编译 (qt-compile-pipeline)              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🤝 贡献

欢迎贡献文档！请参考：

- **贡献指南**: [README.md - 贡献指南](../README.md#-贡献指南)
- **补丁规范**:
  - `[linux-imx]` —— NXP BSP 轨道
  - `[mainline]` —— 上游内核轨道
  - `[uboot]` —— U-Boot 补丁

---

## 📧 联系方式

**Awesome-Embedded-Learning-Studio**

- 作者：Charliechen
- 邮箱：[725610365@qq.com](mailto:725610365@qq.com)
- GitHub：[Awesome-Embedded-Learning-Studio](https://github.com/Awesome-Embedded-Learning-Studio)

---

<div align="center">

**用 🔥 和无数串口终端堆出来的工程。**

**Happy Hacking! :rocket:**

---

*Copyright © 2026 IMX-Forge Project. MIT License.*

</div>
