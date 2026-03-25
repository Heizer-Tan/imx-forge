# 脚本文档

IMX-Forge 构建系统的脚本说明。

---

## 📁 目录结构

```
scripts/
├── build_helper/          # 组件构建脚本
│   ├── build-uboot.sh
│   ├── build-linux.sh
│   ├── build-mainline-linux.sh
│   └── build-busybox.sh
├── release-all.sh         # 一键构建
├── patch_maker.sh         # 补丁生成
├── lib/                   # 共享库
├── logo_helper/           # Logo 处理
├── release_builder/       # 发布构建
├── server_helper/         # 服务器工具
└── third_party_install/   # 第三方安装
```

---

## 📚 主要脚本

| 脚本 | 用途 |
|------|------|
| **[release-all.sh](../scripts/release-all.sh)** | 一键构建所有组件 |
| **[patch_maker.sh](../scripts/patch_maker.sh)** | 补丁生成工具 |
| **build-uboot.sh** | 构建 U-Boot |
| **build-linux.sh** | 构建 NXP BSP 内核 |
| **build-mainline-linux.sh** | 构建主线内核 |
| **build-busybox.sh** | 构建 BusyBox |

---

## 🔧 使用方法

### 一键构建

```bash
./scripts/release-all.sh
```

### 分步构建

```bash
./scripts/build_helper/build-uboot.sh
./scripts/build_helper/build-linux.sh
./scripts/build_helper/build-busybox.sh
```

### 单独构建主线内核

```bash
./scripts/build_helper/build-mainline-linux.sh
```

---

## 📖 延伸阅读

- [构建系统文档](../architecture/BUILD_SYSTEM.md)
- [补丁系统文档](../architecture/PATCH_SYSTEM.md)

---

## ➡️ 返回 [文档首页](../)
