# copy_to_tftp.sh - TFTP文件复制脚本详解

## 脚本概述

`copy_to_tftp.sh` 是 IMX-Forge 项目中用于自动化复制编译产物到 TFTP 目录的辅助脚本。在网络启动开发流程中，每次编译内核或设备树后，都需要将产物复制到 TFTP 服务器目录才能被开发板下载。这个脚本简化了这个过程，支持灵活的路径配置，并提供文件验证功能。

### 核心功能

- **自动文件复制**：将编译好的内核镜像(zImage)和设备树文件(DTB)复制到TFTP目录
- **源文件验证**：复制前检查源文件是否存在，避免复制失败
- **目录自动创建**：目标目录不存在时自动创建
- **工具链适配**：优先使用 rsync，回退到 cp 命令
- **灵活配置**：支持命令行参数覆盖默认路径

### 设计理念

这个脚本遵循"简单即美"的设计原则，专注于解决一个具体问题：快速将编译产物部署到 TFTP 目录。

**为什么需要这个脚本**：

1. **提高效率**：手动复制文件容易出错，路径容易写错
2. **减少重复**：开发过程中频繁修改代码、编译、部署，自动化复制能节省时间
3. **统一路径**：项目中所有开发者使用相同的 TFTP 路径配置
4. **验证机制**：复制前验证源文件存在，提前发现问题

### 在开发工作流中的位置

```
┌─────────────────────────────────────────────────────────────┐
│  1. 代码修改                                                   │
│     - 修改内核代码                                             │
│     - 修改设备树文件                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 编译构建                                                   │
│     - ./scripts/build_helper/build-linux.sh                 │
│     - 生成 out/linux/arch/arm/boot/zImage                   │
│     - 生成 out/linux/arch/arm/boot/dts/.../*.dtb            │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. 部署到TFTP  ← copy_to_tftp.sh 在这里                      │
│     - ./scripts/server_helper/copy_to_tftp.sh               │
│     - 复制 zImage 到 ~/tftp                                  │
│     - 复制 DTB 到 ~/tftp                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. 网络启动                                                   │
│     - U-Boot: tftp 0x80800000 zImage                        │
│     - U-Boot: bootz 0x80800000 - 0x83000000                │
└─────────────────────────────────────────────────────────────┘
```

### 依赖关系

```
copy_to_tftp.sh
    ├─ rsync (首选，可选)
    └─ cp (rsync不可用时的回退选项)
```

**被集成到**：
- 构建脚本的后处理步骤
- 手动开发工作流
- CI/CD 流水线（可选）

## 参数说明

### 命令行参数

```bash
./scripts/server_helper/copy_to_tftp.sh [OPTIONS]
```

| 参数 | 说明 | 默认值 | 必需/可选 |
|------|------|--------|-----------|
| `--kernel=PATH` | 内核镜像文件路径 | `out/linux/arch/arm/boot/zImage` | 可选 |
| `--dts=PATH` | 设备树文件路径 | `out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb` | 可选 |
| `--tftp-path=PATH` | TFTP服务器目录路径 | `~/tftp` | 可选 |
| `-h, --help` | 显示帮助信息 | - | 可选 |

### 默认路径详解

#### 内核默认路径

```bash
DEFAULT_KERNEL="out/linux/arch/arm/boot/zImage"
```

**路径结构解析**：

```
out/linux/                    # 内核编译输出根目录
└── arch/arm/boot/            # ARM架构的启动镜像目录
    ├── Image                 # 未压缩的内核镜像
    └── zImage                # 压缩的内核镜像（默认使用）
```

**为什么使用 zImage**：

- `zImage` 是压缩后的内核镜像，占用空间更小
- TFTP传输速度更快
- U-Boot会自动解压

#### 设备树默认路径

```bash
DEFAULT_DTS="out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb"
```

**路径结构解析**：

```
out/linux/arch/arm/boot/dts/    # 设备树编译输出目录
└── nxp/imx/                    # NXP i.MX 系列设备树
    └── imx6ull-aes.dtb         # AES开发板的设备树（二进制）
```

**设备树文件命名规则**：

- `.dts`：设备树源文件（文本格式）
- `.dtb`：编译后的设备树二进制文件（U-Boot使用）
- 名称通常匹配板子型号，如 `imx6ull-14x14-evk.dtb`

#### TFTP目录默认路径

```bash
DEFAULT_TFTP_PATH="$HOME/tftp"
```

**默认值展开**：

- `~` 展开为用户的 home 目录（如 `/home/charliechen`）
- 最终路径：`/home/charliechen/tftp`

**为什么选择 `~/tftp`**：

1. 用户目录有写权限，不需要 sudo
2. 避免系统目录权限问题
3. 符合 Linux 用户目录结构规范

## 执行流程

### 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. 初始化阶段                                               │
│     - 设置默认路径                                           │
│     - 解析命令行参数                                         │
│     - 检测复制命令（rsync/cp）                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 预处理阶段                                               │
│     - 切换到项目根目录                                       │
│     - 显示配置信息                                           │
│     - 展开 TFTP 路径中的 ~                                   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. 复制内核镜像                                             │
│     - check_and_copy() 验证源文件                           │
│     - 创建目标目录（如需要）                                 │
│     - 执行复制操作                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. 复制设备树文件                                           │
│     - check_and_copy() 验证源文件                           │
│     - 创建目标目录（如需要）                                 │
│     - 执行复制操作                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  5. 完成确认                                                 │
│     - 显示成功消息                                           │
└─────────────────────────────────────────────────────────────┘
```

### 函数详解

#### usage()

**作用**：显示帮助信息并退出。

**实现方式**：

```bash
usage() {
    sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# //g' | sed 's/^#//g'
    exit 0
}
```

**实现原理**：

1. 使用 `sed` 提取脚本文件自身的注释部分
2. 从 `# Usage:` 行开始，到空行结束
3. 去除 `#` 前缀和空格
4. 显示提取的帮助文本

**好处**：

- 帮助信息就在脚本文件中，单文件维护
- 代码即文档，不会不同步
- 符合 Unix 工具的传统

**输出示例**：

```
Usage: copy_to_tftp.sh [OPTIONS]

Options:
  --kernel=PATH      Path to zImage kernel file
                     (default: out/linux/zImage)
  --dts=PATH         Path to DTB file
                     (default: out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb)
  --tftp-path=PATH   Path to TFTP directory
                     (default: ~/tftp)
  -h, --help         Show this help message
```

#### 参数解析逻辑

**代码片段**：

```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel=*)
            KERNEL="${1#*=}"
            ;;
        --dts=*)
            DTS="${1#*=}"
            ;;
        --tftp-path=*)
            TFTP_PATH="${1#*=}"
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Error: Unknown option '$1'"
            usage
            ;;
    esac
    shift
done
```

**解析原理**：

- `${1#*=}`：bash 参数扩展，删除 `=` 及其之前的内容，保留等号后的值
- 示例：`--kernel=/path/to/kernel` → 提取 `/path/to/kernel`

**参数展开示例**：

| 输入 | 变量 | 值 |
|------|------|-----|
| `--kernel=/tmp/test.zImage` | `KERNEL` | `/tmp/test.zImage` |
| `--dts=custom.dtb` | `DTS` | `custom.dtb` |
| `--tftp-path=/var/tftp` | `TFTP_PATH` | `/var/tftp` |

#### 复制命令选择逻辑

**代码片段**：

```bash
if command -v rsync &> /dev/null; then
    COPY_CMD="rsync -ah --progress"
else
    COPY_CMD="cp -v"
fi
```

**检测方式**：

- `command -v rsync`：检查命令是否存在
- `&> /dev/null`：隐藏输出（包括 stdout 和 stderr）
- 存在则使用 rsync，否则回退到 cp

**为什么优先使用 rsync**：

| 特性 | rsync | cp |
|------|-------|-----|
| 增量传输（只传变化部分） | ✓ | ✗ |
| 传输进度显示 | ✓ | ✗ |
| 权限保留 | ✓ | ✓ |
| 速度（小文件） | 相当 | 相当 |
| 速度（大文件） | 更快 | - |
| 可用性 | 需安装 | 内置 |

**命令参数说明**：

- `rsync -ah --progress`：
  - `-a`：归档模式，保留权限、时间戳等
  - `-h`：人类可读的输出格式
  - `--progress`：显示传输进度

- `cp -v`：
  - `-v`：verbose 模式，显示复制的文件

#### check_and_copy()

**作用**：验证源文件存在并执行复制操作。

**函数签名**：

```bash
check_and_copy() {
    local src="$1"    # 源文件路径
    local dst="$2"    # 目标文件路径
    local desc="$3"   # 描述文字（用于输出）
}
```

**执行流程**：

```
┌─────────────────────────────────────────┐
│  Step 1: 检查源文件是否存在               │
│  if [[ ! -f "${src}" ]]                 │
│  → 输出错误信息                          │
│  → return 1                              │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 2: 创建目标目录                    │
│  mkdir -p "$(dirname "${dst}")"         │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 3: 执行复制                        │
│  ${COPY_CMD} "${src}" "${dst}"          │
└─────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Step 4: 检查执行结果                    │
│  if [[ $? -eq 0 ]]                      │
│  → 输出成功信息                          │
│  → return 0                              │
│  else                                   │
│  → 输出失败信息                          │
│  → return 1                              │
└─────────────────────────────────────────┘
```

**关键实现细节**：

1. **文件存在性检查**：
```bash
if [[ ! -f "${src}" ]]; then
    echo "Error: ${desc} not found at '${src}'"
    return 1
fi
```
- 使用 `-f` 检查常规文件（排除目录、设备文件等）
- 错误信息包含文件描述和完整路径，便于排查

2. **目录自动创建**：
```bash
mkdir -p "$(dirname "${dst}")"
```
- `dirname` 提取路径的目录部分
- 示例：`/home/user/tftp/zImage` → `/home/user/tftp`
- `-p` 参数确保父目录不存在时递归创建
- 如果目录已存在，不会报错

3. **复制执行**：
```bash
${COPY_CMD} "${src}" "${dst}"
```
- 使用变量存储的命令（rsync 或 cp）
- 路径加引号防止空格问题

#### 主执行流程

**切换项目根目录**：

```bash
MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${MAIN_DIR}" || exit 1
```

**路径解析**：

```
scripts/server_helper/copy_to_tftp.sh
    dirname → scripts/server_helper
    ../..    → 项目根目录
```

**为什么要切换到项目根目录**：

1. 相对路径（如 `out/linux/...`）基于根目录解析
2. 脚本可以从任何位置执行
3. 保证路径一致性

**波浪号展开**：

```bash
TFTP_PATH="${TFTP_PATH/#\~/$HOME}"
```

**展开原理**：

- `${变量/#模式/替换}`：bash 参数扩展，从开头匹配模式并替换
- 将 `~` 替换为 `$HOME` 的值

**示例**：

| 输入 | 输出 |
|------|------|
| `~/tftp` | `/home/charliechen/tftp` |
| `~user/tftp` | `~user/tftp`（不变，只处理 `~`） |
| `/var/tftp` | `/var/tftp`（不变，无 `~`） |

**为什么不直接使用 `eval`**：

- `eval` 有安全风险（可能执行任意代码）
- 参数扩展更安全、更高效

**复制执行**：

```bash
# 内核
KERNEL_DST="${TFTP_PATH}/$(basename "${KERNEL}")"
check_and_copy "${KERNEL}" "${KERNEL_DST}" "Kernel" || exit 1

# 设备树
DTB_DST="${TFTP_PATH}/$(basename "${DTS}")"
check_and_copy "${DTS}" "${DTB_DST}" "DTB" || exit 1
```

**目标路径构造**：

- `basename`：提取文件名
- 示例：
  - KERNEL: `out/linux/arch/arm/boot/zImage` → `zImage`
  - DTS: `out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb` → `imx6ull-aes.dtb`

**错误处理**：

- `|| exit 1`：复制失败时立即退出脚本
- 避免继续执行导致状态不一致

## TFTP配置

### TFTP服务概述

TFTP（Trivial File Transfer Protocol）是一个简单的文件传输协议，主要用于网络启动场景：

- **端口**：UDP 69
- **无认证**：任何客户端都可以访问
- **简单协议**：只支持读写操作，不支持列出目录
- **小文件优化**：适合传输内核、设备树等小文件

### TFTP目录结构

**标准TFTP目录布局**：

```
~/tftp/
├── zImage                    # 内核镜像
├── imx6ull-aes.dtb           # 设备树
├── uImage                    # U-Boot镜像（可选）
└── boot.scr                  # U-Boot脚本（可选）
```

**权限要求**：

```bash
# 目录权限
drwxrwxrwx  tftp/

# 文件权限
-rwxrwxrwx  zImage
-rwxrwxrwx  imx6ull-aes.dtb
```

**为什么需要 777 权限**：

1. TFTP服务通常以 `tftp` 用户运行
2. `tftp` 用户需要读权限
3. 开发阶段简化权限管理
4. 生产环境应使用更严格的权限

### WSL下的特殊配置

**WSL2网络模式**：

WSL2有两种网络模式，影响TFTP可达性：

| 模式 | 特点 | TFTP可用性 |
|------|------|------------|
| NAT | WSL在独立网段 | 需要端口转发 |
| Mirrored | WSL共享主机网络 | 直接可用（推荐） |

**切换到Mirrored模式**：

编辑 Windows 用户目录下的 `.wslconfig`：

```ini
[wsl2]
networkingMode=mirrored
```

重启WSL：

```powershell
wsl --shutdown
wsl
```

**TFTP服务安装**：

```bash
sudo apt update
sudo apt install tftpd-hpa
```

**TFTP配置文件**：`/etc/default/tftpd-hpa`

```bash
TFTP_USERNAME="tftp"
TFTP_DIRECTORY="/home/charliechen/tftp"
TFTP_ADDRESS="192.168.60.1:69"
TFTP_OPTIONS="--secure"
```

**配置说明**：

- `TFTP_ADDRESS`：必须绑定到开发板可访问的IP地址
- `--secure`：限制访问在TFTP目录内（安全）
- 可选 `--create`：允许上传文件

### Windows防火墙配置

**问题**：WSL2的网络流量经过Windows防火墙，默认阻止UDP 69。

**解决方案**：在管理员PowerShell中执行：

```powershell
New-NetFirewallRule -DisplayName "WSL TFTP" `
                    -Direction Inbound `
                    -Protocol UDP `
                    -LocalPort 69 `
                    -Action Allow
```

**验证规则**：

```powershell
Get-NetFirewallRule -DisplayName "WSL TFTP" | Format-List
```

**测试端口**：

```powershell
Test-NetConnection -ComputerName 192.168.60.1 -Port 69
```

**输出示例**：

```
ComputerName     : 192.168.60.1
RemoteAddress    : 192.168.60.1
RemotePort       : 69
InterfaceAlias   : 网桥
TcpTestSucceeded : False
```

注意：TFTP使用UDP，TcpTestSucceeded为False是正常的。

## 使用示例

### 基本用法

```bash
# 使用默认路径
./scripts/server_helper/copy_to_tftp.sh
```

**输出示例**：

```
TFTP Copy Helper
================
Kernel:   out/linux/arch/arm/boot/zImage
DTB:      out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb
TFTP dir: ~/tftp

Success: Copied Kernel to '/home/charliechen/tftp/zImage'
Success: Copied DTB to '/home/charliechen/tftp/imx6ull-aes.dtb'

All files copied successfully!
```

### 自定义内核路径

```bash
# 指定自定义内核路径
./scripts/server_helper/copy_to_tftp.sh --kernel=out/linux/arch/arm/boot/Image
```

**适用场景**：

- 使用未压缩内核镜像
- 测试不同编译配置的输出

### 自定义设备树路径

```bash
# 指定自定义设备树
./scripts/server_helper/copy_to_tftp.sh --dts=out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-14x14-evk.dtb
```

**适用场景**：

- 使用不同的开发板设备树
- 测试修改后的设备树

### 自定义TFTP目录

```bash
# 使用非标准TFTP目录
./scripts/server_helper/copy_to_tftp.sh --tftp-path=/var/lib/tftpboot
```

**适用场景**：

- 系统级TFTP服务
- 多项目共享TFTP目录

### 组合使用

```bash
# 完整自定义
./scripts/server_helper/copy_to_tftp.sh \
    --kernel=build/output/zImage \
    --dts=build/output/custom.dtb \
    --tftp-path=/srv/tftp
```

### 查看帮助

```bash
./scripts/server_helper/copy_to_tftp.sh --help
```

### 在U-Boot中使用

复制完成后，在U-Boot中下载：

```bash
# 下载内核
=> tftp 0x80800000 zImage
Using ethernet@20b4000 device
TFTP from server 192.168.60.1; our IP address is 192.168.60.200
Filename 'zImage'.
Load address: 0x80800000
Loading: #################################################################
         2.1 MiB/s
Bytes transferred = 6543210 (63d00a hex)

# 下载设备树
=> tftp 0x83000000 imx6ull-aes.dtb
Using ethernet@20b4000 device
TFTP from server 192.168.60.1; our IP address is 192.168.60.200
Filename 'imx6ull-aes.dtb'.
Load address: 0x83000000
Loading: #
         456 KiB/s
Bytes transferred = 45678 (b26e hex)

# 启动
=> bootz 0x80800000 - 0x83000000
```

### 集成到构建流程

**在build-linux.sh后自动调用**：

```bash
# 编译内核
./scripts/build_helper/build-linux.sh

# 自动复制到TFTP
./scripts/server_helper/copy_to_tftp.sh
```

**创建别名**（在 `~/.bashrc` 中）：

```bash
alias deploy-kernel='./scripts/server_helper/copy_to_tftp.sh'
```

使用：

```bash
deploy-kernel
```

## 故障排除

### 常见错误

#### 错误 1：内核文件不存在

**现象**：

```
Error: Kernel not found at 'out/linux/arch/arm/boot/zImage'
```

**原因**：

- 内核尚未编译
- 编译失败
- 使用了错误的输出路径

**解决方法**：

1. 确认内核已编译：

```bash
ls -la out/linux/arch/arm/boot/zImage
```

2. 如果不存在，执行编译：

```bash
./scripts/build_helper/build-linux.sh
```

3. 检查编译是否成功：

```bash
ls -la out/linux/
```

应该能看到 `zImage`、`.config`、`System.map` 等文件。

#### 错误 2：设备树文件不存在

**现象**：

```
Error: DTB not found at 'out/linux/arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb'
```

**原因**：

- 设备树未编译
- 设备树名称不匹配
- 内核配置未启用该设备树

**解决方法**：

1. 检查已编译的设备树：

```bash
find out/linux -name "*.dtb" -type f
```

2. 查找正确的设备树名称：

```bash
ls out/linux/arch/arm/boot/dts/nxp/imx/
```

3. 使用实际的设备树路径：

```bash
./scripts/server_helper/copy_to_tftp.sh \
    --dts=out/linux/arch/arm/boot/dts/nxp/imx/实际名称.dtb
```

#### 错误 3：TFTP目录权限不足

**现象**：

```
Error: Failed to copy Kernel
```

或在 TFTP 日志中看到：

```
tftp: permission denied
```

**原因**：

- TFTP 目录权限不足
- 文件权限不足
- TFTP 服务用户无法访问

**解决方法**：

1. 修改目录权限：

```bash
chmod 777 ~/tftp
```

2. 确保用户 home 目录可进入：

```bash
sudo chmod o+x /home/$(whoami)
```

3. 修改已复制文件的权限：

```bash
chmod 777 ~/tftp/*
```

#### 错误 4：rsync 未安装

**现象**：

脚本仍然工作，但使用 `cp` 而不是 `rsync`。

**影响**：

- 每次都复制整个文件
- 无进度显示

**解决方法**：

安装 rsync：

```bash
sudo apt install rsync
```

**验证安装**：

```bash
which rsync
```

#### 错误 5：相对路径问题

**现象**：

```
Error: Kernel not found at 'out/linux/arch/arm/boot/zImage'
```

但文件确实存在。

**原因**：

- 从非项目根目录执行脚本
- 工作目录不正确

**解决方法**：

1. 确保从项目根目录执行：

```bash
cd /home/charliechen/imx-forge
./scripts/server_helper/copy_to_tftp.sh
```

2. 或使用绝对路径：

```bash
./scripts/server_helper/copy_to_tftp.sh \
    --kernel=$(pwd)/out/linux/arch/arm/boot/zImage
```

### WSL 特定问题

#### 问题 1：Windows 防火墙阻止 TFTP

**现象**：

U-Boot 中 TFTP 超时：

```
Loading: T T T T T T T T
Retry count exceeded; starting again
```

**原因**：

Windows 防火墙阻止 UDP 69 入站流量。

**解决方法**：

1. 在管理员 PowerShell 中添加规则：

```powershell
New-NetFirewallRule -DisplayName "WSL TFTP" `
                    -Direction Inbound `
                    -Protocol UDP `
                    -LocalPort 69 `
                    -Action Allow
```

2. 验证规则：

```powershell
Get-NetFirewallRule -DisplayName "WSL TFTP"
```

#### 问题 2：WSL2 NAT 模式网络隔离

**现象**：

- WSL 内部 TFTP 正常
- 开发板无法连接

**原因**：

WSL2 NAT 模式下，WSL 在独立网段。

**解决方法**：

1. 切换到 mirrored 模式

编辑 `C:\Users\<用户名>\.wslconfig`：

```ini
[wsl2]
networkingMode=mirrored
```

2. 重启 WSL：

```powershell
wsl --shutdown
wsl
```

3. 验证网络模式：

```bash
ip addr show | grep 192.168.60.1
```

应该能看到开发板网段的 IP。

#### 问题 3：TFTP 服务未启动

**现象**：

```
Error: Failed to copy Kernel
```

或连接被拒绝。

**解决方法**：

1. 检查服务状态：

```bash
sudo service tftpd-hpa status
```

2. 启动服务：

```bash
sudo service tftpd-hpa start
```

3. 验证监听端口：

```bash
sudo ss -ulnp | grep 69
```

应该看到：

```
UNCONN 0 0 192.168.60.1:69  0.0.0.0:*  users:(("in.tftpd",pid=xxx,fd=xxx))
```

### 调试技巧

#### 启用详细输出

使用 `cp -v`（rsync 不可用时自动启用）：

```bash
# 卸载 rsync 临时使用 cp
sudo apt remove rsync

# 执行脚本，会显示详细输出
./scripts/server_helper/copy_to_tftp.sh
```

#### 手动验证复制

```bash
# 手动复制内核
cp -v out/linux/arch/arm/boot/zImage ~/tftp/

# 验证文件存在
ls -la ~/tftp/zImage

# 验证文件大小
du -h out/linux/arch/arm/boot/zImage
du -h ~/tftp/zImage
```

#### 测试 TFTP 连接

**从WSL内部测试**：

```bash
# 安装客户端
sudo apt install tftp-hpa

# 测试
echo "get zImage" | tftp 192.168.60.1
ls -la zImage
```

**从开发板测试**：

```bash
=> tftp 0x80800000 zImage
```

#### 检查路径解析

```bash
# 在脚本中添加调试输出
echo "Kernel source: ${KERNEL}"
echo "Kernel dest: ${KERNEL_DST}"
echo "Working dir: $(pwd)"
echo "Home: ${HOME}"
```

## 设计决策说明

### 为什么使用 rsync 而不是 cp

**rsync 的优势**：

1. **增量传输**：只传输文件变化的部分
2. **进度显示**：显示传输进度和速度
3. **断点续传**：支持中断后继续传输
4. **权限保留**：更好地保留文件属性

**为什么有 cp 回退**：

- rsync 可能未安装在最小系统上
- 确保脚本在各种环境都能工作
- cp 是 POSIX 标准，更可移植

### 为什么需要文件验证

**复制前验证的好处**：

1. **提前失败**：在执行复制前发现问题
2. **清晰错误**：明确指出哪个文件找不到
3. **节省时间**：避免复制一半才发现源文件不存在

**示例对比**：

```bash
# 无验证
cp nonexistent.zImage ~/tftp/
cp: cannot stat 'nonexistent.zImage': No such file or directory

# 有验证
Error: Kernel not found at 'nonexistent.zImage'
```

### 为什么自动创建目录

**设计考虑**：

1. **简化使用**：用户不需要手动创建 TFTP 目录
2. **一次配置**：首次运行后目录结构就建立好了
3. **幂等性**：多次运行不会出错

**实现方式**：

```bash
mkdir -p "$(dirname "${dst}")"
```

`-p` 参数确保：
- 父目录不存在时递归创建
- 目录已存在时不报错

### 为什么支持命令行参数

**灵活性考虑**：

1. **不同环境**：开发、测试、生产环境路径可能不同
2. **不同项目**：可以复用脚本到其他项目
3. **特殊需求**：临时使用不同的文件或目录

**默认值优先级**：

1. 硬编码的默认值
2. 环境变量（未来可扩展）
3. 命令行参数（最高优先级）

### 为什么切换到项目根目录

**路径一致性**：

```bash
MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${MAIN_DIR}" || exit 1
```

**好处**：

1. 相对路径总是从根目录解析
2. 可以从任何位置执行脚本
3. 避免路径混乱

**示例**：

```bash
# 从项目根目录执行
./scripts/server_helper/copy_to_tftp.sh

# 从项目子目录执行
cd out/linux
../../scripts/server_helper/copy_to_tftp.sh  # 仍然工作

# 从其他位置执行
/home/charliechen/imx-forge/scripts/server_helper/copy_to_tftp.sh  # 仍然工作
```

## 扩展和定制

### 添加环境变量支持

**修改脚本**：

```bash
# 在参数解析前添加
KERNEL="${KERNEL:-${DEFAULT_KERNEL}}"
DTS="${DTS:-${DEFAULT_DTS}}"
TFTP_PATH="${TFTP_PATH:-${DEFAULT_TFTP_PATH}}"
```

**使用方式**：

```bash
export KERNEL_PATH="/custom/path/zImage"
./scripts/server_helper/copy_to_tftp.sh
```

### 添加更多文件类型

**修改脚本添加 U-Boot 支持**：

```bash
# 在默认值中添加
DEFAULT_UBOOT="out/uboot/u-boot.imx"

# 在参数解析中添加
--uboot=*)
    UBOOT="${1#*=}"
    ;;

# 在主执行中添加
if [[ -n "${UBOOT}" ]]; then
    UBOOT_DST="${TFTP_PATH}/$(basename "${UBOOT}")"
    check_and_copy "${UBOOT}" "${UBOOT_DST}" "U-Boot" || exit 1
fi
```

### 添加文件完整性验证

**添加 md5 校验**：

```bash
check_and_copy() {
    local src="$1"
    local dst="$2"
    local desc="$3"

    if [[ ! -f "${src}" ]]; then
        echo "Error: ${desc} not found at '${src}'"
        return 1
    fi

    mkdir -p "$(dirname "${dst}")"

    # 计算源文件 MD5
    local src_md5=$(md5sum "${src}" | cut -d' ' -f1)

    ${COPY_CMD} "${src}" "${dst}"
    if [[ $? -eq 0 ]]; then
        # 验证目标文件 MD5
        local dst_md5=$(md5sum "${dst}" | cut -d' ' -f1)

        if [[ "${src_md5}" == "${dst_md5}" ]]; then
            echo "Success: Copied ${desc} to '${dst}' (verified)"
            return 0
        else
            echo "Error: ${desc} copy verification failed"
            return 1
        fi
    else
        echo "Error: Failed to copy ${desc}"
        return 1
    fi
}
```

### 添加自动编译集成

**创建包装脚本**：

```bash
#!/bin/bash
# build_and_deploy.sh

set -e

echo "Building kernel..."
./scripts/build_helper/build-linux.sh

echo "Deploying to TFTP..."
./scripts/server_helper/copy_to_tftp.sh

echo "Done! Ready to boot from network."
```

**使用**：

```bash
chmod +x build_and_deploy.sh
./build_and_deploy.sh
```

### 添加日志功能

**记录复制历史**：

```bash
# 在脚本开头添加
LOG_FILE="${PROJECT_ROOT}/logs/tftp_deploy.log"
mkdir -p "$(dirname "${LOG_FILE}")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

# 在复制成功后记录
log_message "Copied ${KERNEL} to ${KERNEL_DST}"
log_message "Copied ${DTS} to ${DTB_DST}"
```

## 最佳实践

### 开发工作流

**推荐的开发流程**：

1. 修改代码
2. 编译内核
3. 复制到 TFTP
4. 网络启动测试
5. 重复

**一键化**：

```bash
# 创建别名
alias rebuild='./scripts/build_helper/build-linux.sh && ./scripts/server_helper/copy_to_tftp.sh'

# 使用
rebuild
```

### 版本管理

**建议**：

- 不要将 `~/tftp` 目录加入 git
- TFTP 目录是运行时目录，不是源代码
- 在 `.gitignore` 中添加：

```
/tftp
*.tftpproject
```

### 安全考虑

**生产环境注意事项**：

1. TFTP 无认证，不应暴露在公网
2. 限制 TFTP 服务只监听内网接口
3. 使用防火墙限制访问来源
4. 定期清理 TFTP 目录中的敏感文件

### 性能优化

**频繁开发时**：

1. 使用 rsync 的增量传输
2. 考虑使用 NFS 挂载整个 rootfs
3. 对于大型项目，使用增量编译

**网络优化**：

1. 使用千兆网络
2. 开发板和主机直接连接（避免交换机延迟）
3. 调整 MTU 大小

## 相关文档

- WSL2 + TFTP 网络启动踩坑记 - WSL2 环境下 TFTP 配置详解
- [build-linux.sh](../build_helper/build-linux.sh) - 内核编译脚本
- [logging.sh](../lib/logging.sh) - 日志工具库

---

> **文档版本**: 1.0
> **最后更新**: 2026-03-15
> **脚本路径**: `scripts/server_helper/copy_to_tftp.sh`
