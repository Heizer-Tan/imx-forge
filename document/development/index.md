# 开发指南

开发 IMX-Forge 相关的工具和指南。

---

## 📚 文档目录

| 文档 | 描述 |
|------|------|
| **[环境搭建](ENVIRONMENT_SETUP.md)** | 开发环境配置 |

---

## 🎯 开发环境

### 必需组件

- Ubuntu 22.04+ / WSL2
- ARM GNU Toolchain 15.2
- Git
- MkDocs (文档构建)

### 可选组件

- QT6 (图形界面开发)
- QEMU (模拟器)

---

## 📖 开发工作流

```bash
# 1. 克隆项目
git clone --recurse-submodules https://github.com/Awesome-Embedded-Learning-Studio/imx-forge.git

# 2. 创建分支
git checkout -b feature/your-feature

# 3. 开发和测试
./scripts/release-all.sh

# 4. 提交 PR
```

---

## ➡️ 返回 [文档首页](../)
