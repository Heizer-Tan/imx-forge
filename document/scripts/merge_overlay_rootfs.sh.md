# merge_overlay_rootfs.sh - RootFS叠加层合并脚本详解

## 脚本概述

`merge_overlay_rootfs.sh` 是 IMX-Forge 项目中用于将叠加层（overlay）文件合并到目标根文件系统的脚本。它提供了一种安全、便捷的方式来扩展或修改根文件系统内容，而无需直接修改基础 rootfs。

### 核心功能

- **安全保护**：多重安全检查防止意外覆盖系统根目录
- **目录验证**：验证目标目录是有效的 rootfs 结构
- **叠加层验证**：确保叠加层目录存在且包含内容
- **智能合并**：正确处理文件和目录的合并，overlay 文件覆盖现有文件
- **用户确认**：合并前要求用户确认操作
- **详细日志**：显示合并过程和统计信息

### 设计理念

这个脚本遵循"安全第一，透明操作"的设计原则：

1. **安全优先**：多层安全检查防止灾难性操作
2. **明确告知**：清楚显示将要执行的操作和影响
3. **用户控制**：操作前要求用户确认
4. **可追溯性**：详细记录所有操作步骤

**为什么需要叠加层机制**：

1. **模块化**：不同功能/配置的文件可以组织在不同的 overlay 目录中
2. **可维护性**：基础 rootfs 保持不变，修改集中在 overlay 目录
3. **可复用**：同一个 overlay 可以应用到多个 rootfs
4. **版本控制友好**：overlay 内容变更更清晰，便于追踪

### 依赖关系

```
merge_overlay_rootfs.sh
    ├─ scripts/lib/logging.sh (日志工具库，可选)
    ├─ rootfs/overlay/ (叠加层源目录)
    └─ rootfs/nfs/ (目标 rootfs 目录)
```

## 参数说明

### 命令行参数

```bash
./scripts/merge_overlay_rootfs.sh [OPTIONS]
```

#### OPTIONS 选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--rootfs-dir=PATH` | 目标 rootfs 目录路径 | `rootfs/nfs` |
| `--rootfs-dir PATH` | 同上（空格分隔形式） | - |
| `--overlay-name=NAME` | overlay 目录名称（位于 rootfs/overlay/ 下） | `rootfs` |
| `--overlay-name NAME` | 同上（空格分隔形式） | - |
| `--help, -h` | 显示帮助信息 | - |

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `DEBUG` | 启用调试输出 | `0` |

### 目录结构

```
PROJECT_ROOT/
├── rootfs/
│   ├── overlay/              # 叠加层根目录
│   │   ├── rootfs/           # 默认叠加层
│   │   │   ├── etc/          # 配置文件覆盖
│   │   │   ├── usr/          # 用户文件覆盖
│   │   │   └── ...
│   │   └── qt6/              # Qt6 特定叠加层
│   │       ├── usr/          # Qt6 库文件
│   │       └── ...
│   └── nfs/                  # 目标 rootfs (NFS)
│       ├── bin/
│       ├── sbin/
│       ├── usr/
│       └── ...
```

## 执行流程

### 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. 初始化阶段                                               │
│     - 解析命令行参数                                         │
│     - 设置默认值                                             │
│     - 加载日志库（或使用后备定义）                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 安全检查阶段                                             │
│     - check_directory_safe()                                │
│       * 检查目录是否为 /                                     │
│       * 检查目录是否解析为 /                                 │
│       * 验证目录可访问                                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. 目标验证阶段                                             │
│     - check_valid_rootfs()                                  │
│       * 检查必需目录存在 (bin, sbin, usr)                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. 叠加层验证阶段                                           │
│     - check_overlay_exists()                                │
│       * 检查叠加层目录存在                                   │
│       * 检查叠加层非空                                       │
│       * 列出将要合并的内容                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  5. 用户确认阶段                                             │
│     - 显示警告信息                                           │
│     - 等待用户按 Enter 继续                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  6. 合并执行阶段                                             │
│     - merge_overlay()                                       │
│       * 遍历叠加层内容                                       │
│       * 处理文件和目录合并                                   │
│       * 统计合并结果                                         │
└─────────────────────────────────────────────────────────────┘
```

### 函数详解

#### show_usage()

**作用**：显示脚本使用帮助信息。

**输出内容**：

- 命令语法
- 所有可用选项
- 功能描述
- 使用示例

**调用时机**：

- 用户指定 `--help` 或 `-h`
- 参数解析失败时

#### check_directory_safe()

**作用**：验证目录安全，防止意外修改系统根目录。

**安全检查**：

1. 检查目录路径是否为 `/`
2. 将目录解析为绝对路径
3. 检查解析后的路径是否为 `/`

**安全策略**：

```bash
# 直接检查
if [[ "$dir" == "/" ]]; then
    log_error "Directory cannot be '/'"
    return 1
fi

# 解析后检查（处理 ../ 等相对路径）
abs_dir="$(cd "$dir" 2>/dev/null && pwd)"
if [[ "$abs_dir" == "/" ]]; then
    log_error "Directory resolves to '/' (unsafe)"
    return 1
fi
```

**输出示例**：

```
[INFO] Step 1: Safety checks...
[INFO]   ✓ Target directory is safe
```

**设计考虑**：

为什么不直接禁止 `/` 而要解析后检查？

- 用户可能使用相对路径如 `../../` 最终指向 `/`
- 符号链接可能指向 `/`
- 解析后检查能捕获这些情况

#### check_valid_rootfs()

**作用**：验证目标目录是有效的 rootfs 结构。

**验证标准**：

目标目录必须包含以下必需目录：

| 目录 | 用途 |
|------|------|
| `bin` | 基本命令二进制文件 |
| `sbin` | 系统管理二进制文件 |
| `usr` | 用户程序和数据 |

**验证逻辑**：

```bash
REQUIRED_DIRS=("bin" "sbin" "usr")

for dir in "${REQUIRED_DIRS[@]}"; do
    if [[ -d "${rootfs}/${dir}" ]]; then
        found+=("$dir")
    else
        missing+=("$dir")
    fi
done
```

**输出示例**：

```
[INFO] Step 2: Validating target rootfs...
[DEBUG]   Found required directories: bin sbin usr
[INFO]   ✓ Target is a valid rootfs directory
```

**失败示例**：

```
[ERROR] Target does not appear to be a valid rootfs
[ERROR] Missing required directories: usr
[ERROR] Please ensure target has at least: bin, sbin, usr
```

**设计考虑**：

为什么只检查三个目录？

1. **最小要求**：这是 Linux rootfs 的最小合理结构
2. **宽松验证**：避免过于严格的检查导致合法 rootfs 被拒绝
3. **实用主义**：这三个目录是最不可能缺少的

#### check_overlay_exists()

**作用**：验证叠加层目录存在且包含内容。

**检查内容**：

1. 目录是否存在
2. 目录是否为空（排除隐藏文件）

**空目录检查**：

```bash
local has_content=0
for item in "$overlay"/*; do
    if [[ -e "$item" ]]; then
        has_content=1
        break
    fi
done

if [[ $has_content -eq 0 ]]; then
    log_error "Overlay directory is empty: $overlay"
    return 1
fi
```

**输出示例**：

```
[INFO] Step 3: Checking overlay directory...
[INFO]   ✓ Overlay directory exists with content
[INFO]   Overlay contents:
[INFO]     - etc
[INFO]     - usr
[INFO]     - lib
```

**设计考虑**：

为什么要显示叠加层内容？

1. **透明性**：让用户了解将要合并什么
2. **验证机会**：用户可以确认内容是否符合预期
3. **调试辅助**：帮助诊断问题

#### merge_overlay()

**作用**：执行实际的文件合并操作。

**合并策略**：

1. 遍历叠加层中的所有项（文件和目录）
2. 对于每一项：
   - 如果目标是已存在的目录：合并内容
   - 否则：直接复制文件或目录

**核心逻辑**：

```bash
for item in "$overlay"/*; do
    if [[ -e "$item" ]]; then
        local name="$(basename "$item")"
        local target_path="${target}/${name}"

        if [[ -d "$target_path" ]]; then
            # 目标存在且是目录：合并内容
            cp -a --remove-destination "$item/"* "$target_path/"
            ((dir_count++))
        else
            # 目标不存在或是文件：直接复制
            cp -a --remove-destination "$item" "$target_path"
            if [[ -d "$item" ]]; then
                ((dir_count++))
            else
                ((file_count++))
            fi
        fi
    fi
done
```

**cp 命令参数说明**：

| 参数 | 作用 |
|------|------|
| `-a` | 归档模式，保留所有属性（权限、时间戳、符号链接等） |
| `--remove-destination` | 删除目标文件后复制（用于覆盖符号链接） |

**为什么使用 --remove-destination**：

当目标是符号链接时，普通的 `cp -f` 无法正确覆盖：

```bash
# 假设 target 是一个符号链接
lrwxrwxrwx target -> /somewhere/else

# cp -f 会跟随符号链接，可能导致错误
# cp -a --remove-destination 会先删除符号链接再复制
```

**输出示例**：

```
[INFO] Step 4: Merging overlay...
[CMD] cp -a --remove-destination "overlay/etc/"* "rootfs/nfs/etc/"
[DEBUG]     ✓ Merged (contents): etc/
[CMD] cp -a --remove-destination "overlay/usr/lib" "rootfs/nfs/usr/"
[DEBUG]     ✓ Merged: usr/lib
[INFO]   ✓ Merge complete: 2 directories, 15 files
```

**设计考虑**：

为什么区分目录内容和整个目录？

1. **目录合并**：当两边都有同名目录时，需要合并内容而不是替换
2. **文件/新目录**：直接复制，简单高效
3. **语义正确**：符合 overlay 文件系统的预期行为

## 使用示例

### 基本用法

```bash
# 使用默认设置：overlay/rootfs -> rootfs/nfs
./scripts/merge_overlay_rootfs.sh
```

### 指定目标目录

```bash
# 合并到指定的 rootfs 目录
./scripts/merge_overlay_rootfs.sh --rootfs-dir=rootfs/nfs
```

### 使用不同的叠加层

```bash
# 使用 Qt6 特定的叠加层
./scripts/merge_overlay_rootfs.sh --overlay-name=qt6
```

### 完整示例

```bash
# 指定目标 rootfs 和叠加层
./scripts/merge_overlay_rootfs.sh \
    --rootfs-dir=rootfs/nfs \
    --overlay-name=rootfs
```

### 合并到临时目录

```bash
# 合并到临时 rootfs（用于测试）
./scripts/merge_overlay_rootfs.sh \
    --rootfs-dir=/tmp/test-rootfs \
    --overlay-name=rootfs
```

### 输出示例

```
[INFO] ========================================
[INFO] RootFS Overlay Merge
[INFO] ========================================
[INFO] Overlay source: /home/user/imx-forge/rootfs/overlay/rootfs
[INFO] Target rootfs:  /home/user/imx-forge/rootfs/nfs
[INFO]
[INFO] Step 1: Safety checks...
[INFO]   ✓ Target directory is safe
[INFO]
[INFO] Step 2: Validating target rootfs...
[DEBUG]   Found required directories: bin sbin usr
[INFO]   ✓ Target is a valid rootfs directory
[INFO]
[INFO] Step 3: Checking overlay directory...
[INFO]   ✓ Overlay directory exists with content
[INFO]   Overlay contents:
[INFO]     - etc
[INFO]     - usr
[INFO]     - lib
[INFO]
[WARN] This will OVERWRITE files in rootfs/nfs with content from rootfs/overlay/rootfs
[WARN] Press Ctrl+C to cancel, or Enter to continue...
[INFO] Step 4: Merging overlay...
[CMD] cp -a --remove-destination "rootfs/overlay/rootfs/etc/"* "rootfs/nfs/etc/"
[DEBUG]     ✓ Merged (contents): etc/
[CMD] cp -a --remove-destination "rootfs/overlay/rootfs/usr/"* "rootfs/nfs/usr/"
[DEBUG]     ✓ Merged (contents): usr/
[INFO]   ✓ Merge complete: 2 directories, 0 files
[INFO]
[INFO] ========================================
[INFO] Overlay merge completed successfully!
[INFO] ========================================
[INFO]
[INFO] Merged rootfs/overlay/rootfs -> rootfs/nfs
```

## 典型应用场景

### 场景1：应用配置叠加

```bash
# 创建应用特定的配置叠加层
mkdir -p rootfs/overlay/myapp/etc/myapp
cp myapp.conf rootfs/overlay/myapp/etc/myapp/

# 合并到 rootfs
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=myapp \
    --rootfs-dir=rootfs/nfs
```

### 场景2：Qt6 库文件叠加

```bash
# Qt6 安装后创建叠加层
./scripts/third_party_install/install_qt.sh

# 合并 Qt6 文件到 rootfs
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=qt6 \
    --rootfs-dir=rootfs/nfs
```

### 场景3：多环境配置

```bash
# 开发环境
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=dev \
    --rootfs-dir=rootfs/nfs-dev

# 生产环境
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=prod \
    --rootfs-dir=rootfs/nfs-prod
```

### 场景4：测试 rootfs

```bash
# 创建测试用的临时 rootfs
cp -r rootfs/nfs /tmp/test-rootfs

# 合并测试叠加层
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=test \
    --rootfs-dir=/tmp/test-rootfs
```

## 故障排除

### 常见错误

#### 错误1：目标目录不安全

```
[ERROR] Directory cannot be '/'
```

**原因**：尝试使用系统根目录作为目标。

**解决方法**：

```bash
# 使用正确的 rootfs 路径
./scripts/merge_overlay_rootfs.sh --rootfs-dir=rootfs/nfs
```

#### 错误2：目录解析到根目录

```
[ERROR] Directory resolves to '/' (unsafe)
```

**原因**：目录路径使用相对路径最终指向 `/`。

**解决方法**：

```bash
# 使用绝对路径或项目内相对路径
./scripts/merge_overlay_rootfs.sh --rootfs-dir=rootfs/nfs

# 或者
./scripts/merge_overlay_rootfs.sh --rootfs-dir=/home/user/imx-forge/rootfs/nfs
```

#### 错误3：无效的 rootfs

```
[ERROR] Target does not appear to be a valid rootfs
[ERROR] Missing required directories: bin sbin usr
```

**原因**：目标目录缺少必需的系统目录。

**解决方法**：

1. 检查目标路径是否正确
2. 确保 rootfs 已经正确构建

```bash
# 检查目标目录结构
ls -la rootfs/nfs/

# 如果是空目录，先构建基础 rootfs
./scripts/build_helper/build-busybox.sh
```

#### 错误4：叠加层目录不存在

```
[ERROR] Overlay directory does not exist: rootfs/overlay/myoverlay
```

**原因**：指定的叠加层目录不存在。

**解决方法**：

```bash
# 检查可用的叠加层
ls -la rootfs/overlay/

# 使用存在的叠加层
./scripts/merge_overlay_rootfs.sh --overlay-name=rootfs
```

#### 错误5：叠加层目录为空

```
[ERROR] Overlay directory is empty: rootfs/overlay/empty
```

**原因**：叠加层目录存在但没有内容。

**解决方法**：

```bash
# 检查叠加层内容
ls -la rootfs/overlay/empty/

# 添加需要叠加的文件
mkdir -p rootfs/overlay/empty/etc
cp config.conf rootfs/overlay/empty/etc/
```

#### 错误6：权限不足

```
cp: cannot create 'rootfs/nfs/etc/config': Permission denied
```

**原因**：目标目录没有写权限。

**解决方法**：

```bash
# 修改目录权限
chmod -R u+w rootfs/nfs

# 或使用 sudo（谨慎使用）
sudo ./scripts/merge_overlay_rootfs.sh
```

### 调试技巧

#### 启用详细输出

```bash
# 启用调试模式查看详细信息
DEBUG=1 ./scripts/merge_overlay_rootfs.sh
```

#### 预览将要合并的内容

```bash
# 查看叠加层内容
ls -laR rootfs/overlay/rootfs/

# 使用 debug 模式预览检查过程
DEBUG=1 ./scripts/merge_overlay_rootfs.sh
```

#### 测试合并（不修改原目录）

```bash
# 复制目标目录到临时位置
cp -r rootfs/nfs /tmp/test-nfs

# 合并到临时目录
./scripts/merge_overlay_rootfs.sh \
    --rootfs-dir=/tmp/test-nfs \
    --overlay-name=rootfs

# 检查结果
diff -r rootfs/nfs /tmp/test-nfs
```

## 设计决策说明

### 为什么需要安全检查

在脚本中，安全检查是首要考虑：

1. **防止灾难性操作**：误操作可能导致系统损坏
2. **防御性编程**：用户可能输入各种奇怪的路径
3. **明确失败**：在问题发生前检测并报告

多重安全检查：

```bash
# 检查1：直接路径
if [[ "$dir" == "/" ]]; then
    return 1
fi

# 检查2：解析后路径
abs_dir="$(cd "$dir" 2>/dev/null && pwd)"
if [[ "$abs_dir" == "/" ]]; then
    return 1
fi
```

### 为什么使用 cp 而不是 rsync

`cp` 的优势：

1. **标准工具**：所有系统都有，无需额外安装
2. **简单直接**：功能明确，易于理解
3. **原子操作**：单次操作完成，出错少

`rsync` 的优势（本场景不需要）：

1. 增量同步
2. 远程同步
3. 更复杂的过滤规则

对于本地一次性合并，`cp` 更简单可靠。

### 为什么需要用户确认

合并操作会覆盖文件，必须让用户明确同意：

1. **透明性**：用户知道将要发生什么
2. **可控性**：用户有机会取消
3. **责任感**：确认后执行，用户承担后果

```bash
log_warn "This will OVERWRITE files in ${ROOTFS_DIR}..."
log_warn "Press Ctrl+C to cancel, or Enter to continue..."
read -r
```

### 为什么要求 rootfs 有特定目录

验证 rootfs 合理性：

1. **防止错误**：避免合并到错误目录
2. **明确用途**：确保目标确实是 rootfs
3. **早期发现**：在合并前发现问题

选择的三个目录是 Linux rootfs 的最小合理结构：

```
bin/  - 基本命令
sbin/ - 系统管理命令
usr/  - 用户程序
```

## 扩展和定制

### 添加新的验证规则

如果需要验证更多 rootfs 特征：

```bash
# 在 check_valid_rootfs() 中添加
REQUIRED_FILES=("etc/passwd" "etc/group")
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "${rootfs}/${file}" ]]; then
        missing+=("$file")
    fi
done
```

### 添加备份功能

在合并前备份目标目录：

```bash
# 在 merge_overlay() 前添加
backup_target() {
    local target="$1"
    local backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
    log_info "Creating backup: ${backup}"
    cp -a "${target}" "${backup}"
}

# 在 main() 中调用
backup_target "$ROOTFS_DIR"
merge_overlay "$OVERLAY_DIR" "$ROOTFS_DIR"
```

### 添加 dry-run 模式

显示将要执行的操作但不实际执行：

```bash
# 添加参数
DRY_RUN=0

# 解析参数
--dry-run)
    DRY_RUN=1
    ;;

# 修改 cp 命令执行
if [[ $DRY_RUN -eq 1 ]]; then
    log_cmd "cp -a --remove-destination \"$item\" \"$target_path\""
    log_info "[DRY-RUN] Would merge: $name"
else
    cp -a --remove-destination "$item" "$target_path"
fi
```

### 添加排除模式

支持排除某些文件/目录：

```bash
# 添加参数
EXCLUDE_PATTERNS=("*.bak" "*~" "*.tmp")

# 在 merge_overlay() 中检查
should_skip() {
    local name="$1"
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$name" == $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# 在循环中使用
for item in "$overlay"/*; do
    name="$(basename "$item")"
    if should_skip "$name"; then
        log_debug "Skipping excluded: $name"
        continue
    fi
    # ... 处理合并
done
```

## 最佳实践

### 组织叠加层目录

1. **按功能组织**：

```
rootfs/overlay/
├── base/          # 基础配置
├── qt6/           # Qt6 相关
├── gtk/           # GTK 相关
├── development/   # 开发工具
└── production/    # 生产环境配置
```

2. **明确命名**：使用描述性的名称

3. **文档化**：在叠加层目录中添加 README

```bash
echo "# Qt6 Overlay
# Contains Qt6 libraries and plugins
# Generated by: install_qt.sh
# Date: $(date)" > rootfs/overlay/qt6/README.md
```

### 版本控制

1. **提交叠加层内容**：

```bash
git add rootfs/overlay/
git commit -m "Add Qt6 overlay files"
```

2. **使用 .gitignore** 排除生成的内容：

```
# rootfs/overlay/.gitignore
*.o
*.a
*.so.*
```

### 测试叠加层

1. **在临时目录测试**：

```bash
# 创建测试环境
cp -r rootfs/nfs /tmp/test-rootfs

# 应用叠加层
./scripts/merge_overlay_rootfs.sh \
    --overlay-name=myapp \
    --rootfs-dir=/tmp/test-rootfs

# 验证结果
chroot /tmp/test-rootfs /bin/sh
```

2. **验证文件结构**：

```bash
# 检查合并后的结构
tree -L 3 rootfs/nfs/
```

### 自动化集成

在构建脚本中自动应用叠加层：

```bash
# 在其他构建脚本中
build_and_install_qt6() {
    # 安装 Qt6
    ./scripts/third_party_install/install_qt_with_compile.sh

    # 合并到 rootfs
    ./scripts/merge_overlay_rootfs.sh \
        --overlay-name=qt6 \
        --rootfs-dir=rootfs/nfs
}
```

## 相关文档

- [build-busybox.sh](./build_helper/build-busybox.sh) - BusyBox 构建脚本
- [varified_rootfs_ok.sh](./varified_rootfs_ok.sh) - RootFS 验证脚本
- 根文件系统教程 - RootFS 相关教程
