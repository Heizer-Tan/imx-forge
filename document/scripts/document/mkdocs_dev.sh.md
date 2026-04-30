# mkdocs_dev.sh - MkDocs 文档开发环境管理器

## 脚本概述

`mkdocs_dev.sh` 是 IMX-Forge 项目的 MkDocs 文档开发环境管理脚本。它封装了虚拟环境创建、依赖安装、开发服务器启动和静态站点构建等操作。

### 核心功能

- **虚拟环境管理**：自动创建和管理 Python 虚拟环境
- **依赖安装**：智能检测并安装/更新文档依赖
- **开发服务器**：启动带热重载的本地预览服务器
- **静态构建**：生成可部署的静态网站
- **清理工具**：清理构建产物和缓存

### 设计理念

这个脚本的设计目标是让开发者无需关心 Python 环境配置细节，只需运行简单的命令即可开始文档开发。

### 依赖关系

```
mkdocs_dev.sh
    ├─ scripts/lib/bash/lib_common.sh (日志工具库)
    ├─ scripts/document/pyproject.toml (依赖配置)
    ├─ Python >= 3.10
    └─ virtualenv (内置)
```

## 参数说明

### 命令语法

```bash
./scripts/document/mkdocs_dev.sh <command> [OPTIONS]
```

### 命令列表

| 命令 | 说明 |
|------|------|
| `serve` | 启动 MkDocs 开发服务器（默认） |
| `build` | 构建静态站点到 `out/docs/site/` |
| `install` | 创建/更新虚拟环境并安装依赖 |
| `clean` | 清理构建产物 |
| `reset` | 删除并重建虚拟环境 |
| `help` | 显示帮助信息 |

### 选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-p, --port PORT` | 开发服务器端口 | `8000` |
| `-b, --bind ADDR` | 开发服务器绑定地址 | `127.0.0.1` |
| `-v, --verbose` | 启用详细输出 | 禁用 |
| `-h, --help` | 显示帮助信息 | - |

### 环境要求

- **Python 版本**：>= 3.10
- **虚拟环境目录**：`.venv/`（项目根目录）
- **依赖配置文件**：`scripts/document/pyproject.toml`

## 执行流程

### 命令实现流程

#### cmd_serve()

```
┌─────────────────────────────────────┐
│  ensure_venv()                      │
│    ├─ check_python()                │
│    ├─ create_venv()                 │
│    ├─ activate_venv()               │
│    └─ install_deps()                │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│  启动开发服务器                      │
│  mkdocs serve --dev-addr            │
└─────────────────────────────────────┘
```

#### cmd_build()

```
┌─────────────────────────────────────┐
│  ensure_venv()                      │
└─────────────────────────────────────┘
                ↓
┌─────────────────────────────────────┐
│  构建静态站点                        │
│  mkdocs build --clean -d out/docs/site │
└─────────────────────────────────────┘
```

#### cmd_install()

```
┌─────────────────────────────────────┐
│  ensure_venv()                      │
│    ├─ check_python()                │
│    ├─ create_venv()                 │
│    ├─ activate_venv()               │
│    └─ install_deps()                │
└─────────────────────────────────────┘
```

### 函数详解

#### ensure_venv()

**作用**：确保虚拟环境存在且依赖已安装。

**执行步骤**：

1. 检查 Python 版本（>= 3.10）
2. 创建虚拟环境（如不存在）
3. 激活虚拟环境
4. 安装/更新依赖

#### install_deps()

**作用**：安装文档开发依赖，智能检测变更。

**优化机制**：

- 使用 `.deps_installed` 标记文件记录 pyproject.toml 的 MD5 哈希
- 仅当配置文件变更时重新安装依赖
- 避免不必要的网络请求和安装时间

#### cmd_clean()

**作用**：清理构建产物和缓存。

**清理内容**：

| 目录/文件 | 说明 |
|-----------|------|
| `out/docs/site/` | MkDocs 构建输出 |
| `__pycache__/` | Python 字节码缓存 |

## 配置选项

### 常量定义

```bash
readonly MIN_PYTHON_MAJOR=3
readonly MIN_PYTHON_MINOR=10
readonly VENV_DIR=".venv"
readonly DEPS_MARKER=".deps_installed"
readonly DOCS_OUTPUT_DIR="out/docs/site"
```

### 目录结构

```
PROJECT_ROOT/
├── .venv/                      # 虚拟环境（自动创建）
│   ├── bin/                    # 可执行文件
│   ├── lib/                    # 已安装的包
│   └── .deps_installed         # 依赖安装标记
├── scripts/
│   └── document/
│       ├── mkdocs_dev.sh       # 本脚本
│       └── pyproject.toml      # 依赖配置
├── document/                   # 文档源文件
│   └── ...
└── out/
    └── docs/
        └── site/               # 构建输出
```

## 使用示例

### 启动开发服务器

```bash
# 默认配置（127.0.0.1:8000）
./scripts/document/mkdocs_dev.sh serve

# 自定义端口
./scripts/document/mkdocs_dev.sh serve --port 8080

# 监听所有接口
./scripts/document/mkdocs_dev.sh serve --bind 0.0.0.0
```

### 构建静态站点

```bash
./scripts/document/mkdocs_dev.sh build
```

### 安装依赖

```bash
# 首次使用或依赖更新时
./scripts/document/mkdocs_dev.sh install
```

### 清理构建产物

```bash
./scripts/document/mkdocs_dev.sh clean
```

### 重置虚拟环境

```bash
# 删除并重建虚拟环境
./scripts/document/mkdocs_dev.sh reset
```

## 输出示例

### 开发服务器启动

```
=== MkDocs 开发服务器 ===
地址: http://127.0.0.1:8000
文档: /home/user/imx-forge/document

INFO    -  Building documentation...
INFO    -  Building directory structure
INFO    -  Building template pages
INFO    -  Building documentation...
INFO    -  The following pages exist in the documentation:
INFO    -  index.md
INFO    -  tutorial/driver/index.md
...
INFO    -  Serving on http://127.0.0.1:8000
```

### 构建静态站点

```
=== MkDocs 构建 ===
输出: /home/user/imx-forge/out/docs/site

INFO    -  Building documentation...
INFO    -  Building directory structure
INFO    -  Building template pages
INFO    -  Building documentation...
INFO    -  The following pages exist in the documentation:
...
INFO    -  Documentation built in 2.34 seconds
✅ 构建完成: /home/user/imx-forge/out/docs/site
```

## 故障排除

### 常见错误

#### 错误 1：Python 版本过低

```
[ERROR] Python 版本过低: 3.9.0，需要 >= 3.10
```

**解决方法**：

安装 Python 3.10+：

```bash
# Ubuntu/Debian
sudo apt install python3.12 python3.12-venv

# macOS
brew install python@3.12
```

#### 错误 2：虚拟环境激活失败

```
[ERROR] 虚拟环境激活脚本不存在: .venv/bin/activate
```

**解决方法**：

重新创建虚拟环境：

```bash
./scripts/document/mkdocs_dev.sh reset
```

#### 错误 3：依赖安装失败

```
[ERROR] 依赖安装失败
```

**解决方法**：

1. 检查网络连接
2. 手动安装依赖：

```bash
source .venv/bin/activate
pip install -e scripts/document/
```

#### 错误 4：端口已被占用

```
ERROR: Address already in use
```

**解决方法**：

使用其他端口：

```bash
./scripts/document/mkdocs_dev.sh serve --port 8081
```

## 开发指南

### 添加新的依赖

编辑 `scripts/document/pyproject.toml`：

```toml
[project]
dependencies = [
    "mkdocs>=1.5.0",
    "mkdocs-material>=9.0.0",
    "your-new-package>=1.0.0",
]
```

然后运行：

```bash
./scripts/document/mkdocs_dev.sh install
```

### 调试构建问题

启用详细输出：

```bash
./scripts/document/mkdocs_dev.sh build --verbose
```

### 检查安装的包

```bash
source .venv/bin/activate
pip list
```

## 相关文档

- [MkDocs 官方文档](https://www.mkdocs.org/)
- [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
- 项目文档结构 - `document/README.md`
