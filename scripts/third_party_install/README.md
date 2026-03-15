# Third-Party Dependency Installation Scripts

这个目录用于存放 rootfs 的第三方依赖安装脚本。当运行 `scripts/varified_rootfs_ok.sh` 时，这里所有的 `.sh` 脚本都会被自动执行。

## 工作原理

主脚本 (`varified_rootfs_ok.sh`) 会按以下方式执行这里的脚本：

1. 查找此目录下所有 `*.sh` 文件（排除 README 和隐藏文件）
2. 按文件名字母顺序执行每个脚本
3. 向脚本传递以下环境变量：
   - `ROOTFS_DIR` - rootfs 目录路径
   - `PROJECT_ROOT` - 项目根目录路径

## 脚本编写规范

### 基本模板

```bash
#!/bin/bash
#
# 简短描述这个脚本做什么
#

set -e  # 遇到错误时退出

# 使用可选的 $ROOTFS_DIR，提供默认值
: "${ROOTFS_DIR:=../../rootfs/nfs}"

# 你的安装逻辑...
```

### 推荐做法

1. **使用 `set -e`** - 确保脚本在出错时停止执行
2. **提供默认值** - 为 `ROOTFS_DIR` 提供合理的默认值，方便独立测试
3. **输出信息** - 使用清晰的日志输出，方便调试
4. **幂等性** - 脚本应该可以安全地多次执行
5. **错误处理** - 失败时返回非零退出码

### 输出格式建议

```bash
# 使用颜色和前缀使输出更清晰
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[your_script]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[your_script]${NC} $1"; }

log_info "Installing foo library..."
```

## 示例脚本

### install_libc.sh

从交叉编译工具链拷贝 libc 库文件到 rootfs。

```bash
#!/bin/bash
#
# libc Installation Script
#

: "${ROOTFS_DIR:=../../rootfs/nfs}"
CROSS_COMPILE=arm-none-linux-gnueabihf-

# 从工具链拷贝 .a 和 .so 文件
cp -d /usr/lib/${CROSS_COMPILE}/*.a* "${ROOTFS_DIR}/lib/"
cp -d /usr/lib/${CROSS_COMPILE}/*.so* "${ROOTFS_DIR}/lib/"
```

### 安装自定义库

```bash
#!/bin/bash
#
# Install Custom Library
#

: "${ROOTFS_DIR:=../../rootfs/nfs}"

# 检查 rootfs 是否存在
if [[ ! -d "$ROOTFS_DIR" ]]; then
    echo "Error: ROOTFS_DIR not found: $ROOTFS_DIR"
    exit 1
fi

# 拷贝库文件
mkdir -p "${ROOTFS_DIR}/usr/lib"
cp -d path/to/library.so* "${ROOTFS_DIR}/usr/lib/"
```

## 测试脚本

你可以单独运行这里的脚本进行测试：

```bash
# 设置 rootfs 目录
ROOTFS_DIR=../../rootfs/nfs ./install_libc.sh

# 或者使用完整路径
ROOTFS_DIR=/path/to/rootfs ./install_libc.sh
```

## 执行顺序

脚本按文件名字母顺序执行。如果需要控制执行顺序，可以在文件名中使用数字前缀：

```
10-install-libc.sh
20-install-ssl.sh
30-install-custom-app.sh
```

## 注意事项

1. **不要修改系统根目录** - 脚本会检查 `ROOTFS_DIR` 不是 `/`
2. **保持脚本幂等** - 可以安全地重复执行
3. **使用相对路径** - 或通过 `PROJECT_ROOT` 变量引用项目文件
4. **错误处理** - 失败时返回适当的退出码
