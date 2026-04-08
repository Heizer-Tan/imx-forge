# build-linux.sh - Linux内核构建脚本详解

## 脚本概述

`build-linux.sh` 是 IMX-Forge 项目中用于编译 Linux 内核的核心构建脚本。它自动化了从依赖检查、工具链验证到内核配置、编译和产物验证的完整流程。

### 核心功能

- **依赖自动检查**：检测并提示缺失的主机构建工具
- **工具链验证**：确保交叉编译工具链正确安装且可用
- **配置管理**：基于 defconfig 生成内核配置
- **并行编译**：自动利用多核 CPU 加速编译
- **产物验证**：验证编译产物的架构、大小等关键指标
- **快速构建模式**：支持跳过 distclean 的增量编译

### 设计理念

这个脚本的设计遵循"先检查，后执行"的原则。在真正开始编译之前，它会逐一验证所有前置条件，避免编译到一半因为缺少依赖而失败。这种设计可以大大节省开发时间，特别是在 CI/CD 环境中。

另一个重要的设计决策是源码与产物分离。脚本将所有编译产物输出到 `PROJECT_ROOT/out/linux` 目录，保持源码目录 `third_party/linux-imx` 的干净。这样做有几个好处：

1. 源码目录不会被编译产物污染
2. 清理编译产物只需要删除输出目录
3. 可以同时维护多个编译配置（不同的输出目录）

### 依赖关系

```
build-linux.sh
    ├─ scripts/lib/logging.sh (日志工具库)
    ├─ scripts/init/env-init.sh (依赖检查库) ← 新增
    ├─ third_party/linux-imx (Linux内核源码子模块)
    └─ arm-none-linux-gnueabihf-gcc (交叉编译工具链)
```

如果 `logging.sh` 不可用，脚本会使用内嵌的备用日志函数，确保可以独立运行。

## 参数说明

### 命令行参数

```bash
./scripts/build_helper/build-linux.sh [OPTIONS]
```

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--fast-build` | 跳过 distclean，使用现有配置快速编译 | 禁用 |

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ARCH` | 目标架构 | `arm` |
| `CROSS_COMPILE` | 交叉编译器前缀 | `arm-none-linux-gnueabihf-` |
| `DEFCONFIG` | 内核配置文件 | `imx_aes_defconfig` |
| `DEBUG` | 启用调试输出 | `0` |

## 执行流程

### 总体架构

脚本的执行流程可以分为以下几个阶段：

```
┌─────────────────────────────────────────────────────────────┐
│  1. 初始化阶段                                               │
│     - 获取脚本路径                                           │
│     - 设置项目根目录                                         │
│     - 加载日志库                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 预检查阶段                                               │
│     - check_host_dependencies()                              │
│     - check_toolchain()                                      │
│     - check_defconfig()                                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. 构建阶段                                                 │
│     - do_distclean() [可选]                                 │
│     - do_configure()                                         │
│     - do_build()                                             │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. 验证阶段                                                 │
│     - verify_build_artifacts()                               │
└─────────────────────────────────────────────────────────────┘
```

### 函数详解

#### check_host_dependencies()

**作用**：检查主机系统是否安装了所有必需的构建工具。

**实现方式**：

通过导入 `scripts/init/env-init.sh`，调用 `check_linux_dependencies()` 函数实现依赖检查：

```bash
source "${SCRIPT_DIR}/../init/env-init.sh"
check_linux_dependencies || exit 1
```

**检查项目**：

| 工具/库 | 用途 | 检查方式 |
|---------|------|----------|
| `gcc` | C 编译器 | `command -v gcc` |
| `make` | 构建工具 | `command -v make` |
| `bc` | 配置计算器 | `command -v bc` |
| `bison` | 语法分析器 | `command -v bison` |
| `flex` | 词法分析器 | `command -v flex` |
| `dtc` | 设备树编译器 | `command -v dtc` |
| `python3` | Python 环境 | `command -v python3` |
| `libssl-dev` | 加密库 | `dpkg -s libssl-dev` |
| `libgnutls28-dev` | 加密库 | `dpkg -s libgnutls28-dev` |
| `libncurses-dev` | 终端库 | `dpkg -s libncurses-dev` |

**输出示例**：

```
[INFO] 检查 Linux 依赖包...
[INFO]   ✓ build-essential
[INFO]   ✓ bc
[INFO]   ✓ bison
[INFO]   ✓ flex
[INFO]   ✓ device-tree-compiler
[INFO]   ✓ python3
[INFO]   ✓ libssl-dev
[INFO]   ✓ libgnutls28-dev
[INFO]   ✓ libncurses-dev
[INFO] All Linux dependencies found
```

**详细的依赖检查逻辑**：

请参考以下文档：
- env-init.sh 源码
- 环境初始化指南

#### check_toolchain()

**作用**：验证交叉编译工具链是否正确安装。

**检查流程**：

1. 检查 `${CROSS_COMPILE}gcc` 是否存在
2. 显示工具链版本信息
3. 检查 `objcopy`、`objdump`、`strip` 等配套工具

**输出示例**：

```
[INFO] Checking toolchain...
[INFO] Toolchain found: arm-none-linux-gnueabihf-gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
[INFO] All required toolchain components found
```

**为什么检查这些工具**：

- `gcc`：主编译器
- `objcopy`：格式转换（ELF → 二进制）
- `objdump`：反汇编和分析
- `strip`：去除符号表

#### check_defconfig()

**作用**：验证指定的 defconfig 文件是否存在。

**检查路径**：

```
${LINUX_SRC_DIR}/arch/arm/configs/${DEFCONFIG}
```

对于默认配置，完整路径是：

```
third_party/linux-imx/arch/arm/configs/imx_aes_defconfig
```

#### do_distclean()

**作用**：清理旧的编译产物，确保干净的构建环境。

**实现方式**：

```bash
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"
```

**为什么不用 make distclean**：

脚本的实现是直接删除并重建输出目录，而不是运行 `make distclean`。这样做的原因：

1. 更彻底：删除整个输出目录
2. 更快速：不需要 make 遍历源码树
3. 更干净：确保没有任何残留文件

#### do_configure()

**作用**：使用 defconfig 配置内核。

**执行的命令**：

```bash
make -C ${LINUX_SRC_DIR} \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    O=${OUTPUT_DIR} \
    ${DEFCONFIG}
```

**参数解释**：

- `-C ${LINUX_SRC_DIR}`：指定源码目录
- `ARCH=arm`：目标架构
- `CROSS_COMPILE=arm-none-linux-gnueabihf-`：交叉编译器前缀
- `O=${OUTPUT_DIR}`：输出目录（所有产物都在这里）
- `imx_aes_defconfig`：使用的配置文件

**输出结果**：

在 `${OUTPUT_DIR}` 目录生成 `.config` 文件。

#### do_build()

**作用**：编译内核。

**执行的命令**：

```bash
make -C ${LINUX_SRC_DIR} \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    O=${OUTPUT_DIR} \
    -j${NPROC}
```

**参数解释**：

- `-j${NPROC}`：并行编译，`NPROC` 是 CPU 核心数

**编译过程**：

1. 编译内核源文件 → 生成 `.o` 目标文件
2. 链接目标文件 → 生成 `vmlinux` ELF 文件
3. 生成符号表 → `System.map`
4. 转换格式 → `arch/arm/boot/Image`
5. 压缩镜像 → `arch/arm/boot/zImage`
6. 编译设备树 → `*.dtb`

#### verify_build_artifacts()

**作用**：验证编译产物是否正确。

**验证项目**：

| 产物 | 验证方法 | 期望结果 |
|------|----------|----------|
| `vmlinux` | `readelf -h | grep Machine` | `ARM` |
| `vmlinux` | `readelf -h | grep Entry point` | `0xc0008000` |
| `zImage` | 文件存在性检查 | 存在 |
| `.config` | 文件存在性检查 | 存在 |
| `System.map` | 文件存在性检查 | 存在（可选） |
| `modules/` | 目录存在性检查 | 存在（可选） |

**输出示例**：

```
[INFO] Verifying build artifacts in out/linux...
[INFO]   ✓ vmlinux: ARM
[INFO]     Entry: 0xc0008000
[INFO]   ✓ zImage: 3245152 bytes
[INFO]   ✓ .config: present
[INFO]   ✓ System.map: present
[INFO] All build artifacts verified successfully
```

**架构验证的重要性**：

如果架构验证失败（比如显示的是 `x86-64` 而不是 `ARM`），说明用错了工具链。这种情况下产物无法在目标板子上运行。

## 配置选项

### 硬编码配置

脚本开头定义了以下配置：

```bash
ARCH=arm
CROSS_COMPILE=arm-none-linux-gnueabihf-
DEFCONFIG=imx_aes_defconfig
FAST_BUILD=0

LINUX_SRC_DIR="${PROJECT_ROOT}/third_party/linux-imx"
OUTPUT_DIR="${PROJECT_ROOT}/out/linux"
```

### 目录结构

```
PROJECT_ROOT/
├── third_party/
│   └── linux-imx/          # 内核源码（子模块）
├── out/
│   └── linux/              # 编译产物
│       ├── vmlinux         # ELF 内核
│       ├── System.map      # 符号表
│       ├── .config         # 配置文件
│       └── arch/arm/boot/
│           ├── Image       # 未压缩镜像
│           └── zImage      # 压缩镜像
└── scripts/
    └── build_helper/
        └── build-linux.sh  # 本脚本
```

## 使用示例

### 基本用法

```bash
# 完整编译（清理 + 配置 + 编译）
./scripts/build_helper/build-linux.sh
```

### 快速编译（跳过清理）

```bash
# 跳过 distclean，保留现有配置
./scripts/build_helper/build-linux.sh --fast-build
```

### 调试模式

```bash
# 启用调试输出
DEBUG=1 ./scripts/build_helper/build-linux.sh
```

### 输出示例

```
[INFO] Starting Linux kernel build for imx_aes_defconfig
[INFO] ========================================
[INFO] Checking host dependencies...
[INFO]   ✓ build-essential
[INFO]   ✓ bc
[INFO]   ✓ bison
[INFO]   ✓ flex
[INFO]   ✓ device-tree-compiler
[INFO]   ✓ python3
[INFO]   ✓ libssl-dev
[INFO]   ✓ libgnutls28-dev
[INFO]   ✓ libncurses-dev
[INFO] All host dependencies found
[INFO] Checking toolchain...
[INFO] Toolchain found: arm-none-linux-gnueabihf-gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
[INFO] All required toolchain components found
[INFO] Checking defconfig...
[INFO] Defconfig found: third_party/linux-imx/arch/arm/configs/imx_aes_defconfig
[INFO] ========================================
[INFO] All checks passed, starting build...
[INFO] ========================================
[INFO] Running distclean... Using Remove All as to make all clear!
[INFO]   Removing out/linux
[INFO] Configuring Linux kernel with imx_aes_defconfig...
[CMD] make -C third_party/linux-imx ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- O=out/linux imx_aes_defconfig
#
# configuration written to out/linux/.config
#
[INFO] Building Linux kernel...
[CMD] make -C third_party/linux-imx ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- O=out/linux -j8
  CC      init/main.o
  CC      kernel/sched.o
  ...
  LD      vmlinux
  SYST    System.map
  OBJCOPY arch/arm/boot/Image
  GZIP    arch/arm/boot/zImage
[INFO] ========================================
[INFO] Verifying build artifacts in out/linux...
[INFO]   ✓ vmlinux: ARM
[INFO]     Entry: 0xc0008000
[INFO]   ✓ zImage: 3245152 bytes
[INFO]   ✓ .config: present
[INFO]   ✓ System.map: present
[INFO] All build artifacts verified successfully
[INFO] ========================================
[INFO] Build completed successfully!
[INFO] Kernel artifacts in out/linux:
[INFO]   ✓ vmlinux (ELF kernel)
[INFO]   ✓ arch/arm/boot/zImage (compressed kernel)
[INFO]   ✓ System.map (symbol table)
[INFO]   ✓ .config (kernel configuration)
[INFO] ========================================
```

## 故障排除

### 常见错误

#### 错误 1：缺少 bc 包

```
[ERROR] Missing dependencies: bc
```

**解决方法**：

```bash
sudo apt install bc
```

#### 错误 2：工具链未找到

```
[ERROR] Cross compiler 'arm-none-linux-gnueabihf-gcc' not found!
```

**解决方法**：

1. 检查工具链是否安装：

```bash
which arm-none-linux-gnueabihf-gcc
```

2. 如果未安装，安装工具链：

```bash
sudo apt install gcc-arm-linux-gnueabihf
```

3. 或者添加工具链到 PATH：

```bash
export PATH=/path/to/toolchain/bin:$PATH
```

#### 错误 3：defconfig 文件不存在

```
[ERROR] Defconfig file not found: third_party/linux-imx/arch/arm/configs/imx_aes_defconfig
```

**可能原因**：

1. 内核子模块未初始化
2. 使用的 defconfig 名称不正确

**解决方法**：

```bash
# 初始化子模块
git submodule update --init --recursive

# 检查可用的 defconfig
ls third_party/linux-imx/arch/arm/configs/
```

#### 错误 4：产物架构不正确

```
[ERROR] vmlinux: Wrong architecture (x86-64)
```

**原因**：使用了错误的工具链（系统 gcc 而不是交叉编译器）。

**解决方法**：

确保 `CROSS_COMPILE` 变量正确设置：

```bash
echo $CROSS_COMPILE
# 应该输出：arm-none-linux-gnueabihf-
```

#### 错误 5：zImage 未生成

```
[ERROR] ✗ zImage: not found
```

**可能原因**：

1. 编译未完成
2. 配置问题（某些驱动配置错误导致编译失败）

**解决方法**：

1. 检查完整编译输出
2. 手动运行编译命令查看详细错误：

```bash
make -C third_party/linux-imx \
    ARCH=arm \
    CROSS_COMPILE=arm-none-linux-gnueabihf- \
    O=out/linux \
    -j8
```

## 设计决策说明

### 为什么使用 O= 参数而不是在源码目录编译

传统的内核编译方式是在源码目录直接运行 make，这会在源码树中生成大量 `.o` 文件和其他编译产物。IMX-Forge 的构建脚本使用 `O=输出目录` 参数，将所有编译产物放到单独的目录。

**好处**：

1. 源码目录保持干净，可以快速清理
2. 可以用同一个源码树编译多个配置
3. 便于查找编译产物

### 为什么需要 distclean

内核的构建系统依赖于 `.config` 文件。当你修改 defconfig 后，如果旧的 `.config` 还在，make 可能会使用旧的配置而不是新的。distclean 确保每次编译都使用最新的配置。

**但有时不需要**：

开发过程中，如果你只是修改了一两个源文件，使用 `--fast-build` 跳过 distclean 可以节省大量时间。

### 为什么分别检查依赖而不是一次性安装

脚本会分别检查每个依赖，并告诉用户哪些缺失，而不是自动安装。这是出于以下考虑：

1. 用户可能希望使用特定版本的包
2. 用户可能使用不同的包管理器（apt、yum、dnf 等）
3. CI/CD 环境可能有特殊的安装要求

### 为什么需要 verify_build_artifacts

编译完成不等于编译正确。产物验证阶段确保：

1. 架构正确（ARM 而不是 x86）
2. 所需文件都已生成
3. 文件大小在合理范围内

这种"防御性编程"的思想可以在早期发现问题，避免将有问题的镜像烧录到板子上。

## 扩展和定制

### 添加新的 defconfig

如果你的板子需要不同的配置：

1. 在内核源码中创建新的 defconfig
2. 修改脚本中的 `DEFCONFIG` 变量

```bash
# 编辑脚本
vim scripts/build_helper/build-linux.sh

# 修改这一行
DEFCONFIG=my_custom_defconfig
```

### 修改工具链

如果使用不同的交叉编译器：

```bash
# 方法1：修改脚本
CROSS_COMPILE=arm-linux-gnueabihf-

# 方法2：环境变量覆盖
CROSS_COMPILE=arm-linux-gnueabihf- ./scripts/build_helper/build-linux.sh
```

### 添加编译选项

如果需要传递额外的 make 选项：

```bash
# 编辑 do_build() 函数
do_build() {
    log_info "Building Linux kernel..."
    local cmd="make -C ${LINUX_SRC_DIR} \
        ARCH=${ARCH} \
        CROSS_COMPILE=${CROSS_COMPILE} \
        O=${OUTPUT_DIR} \
        -j${NPROC} \
        EXTRA_CFLAGS=-O2"  # 添加的选项
    echo -e "${YELLOW}[CMD]${NC} ${cmd}"
    ${cmd}
}
```

## 相关文档

- Linux内核编译教程 - 内核编译的详细原理
- 内核配置详解 - defconfig 和 .config 的关系
- [U-Boot构建脚本](./build-uboot.sh) - 对比的 U-Boot 构建脚本
