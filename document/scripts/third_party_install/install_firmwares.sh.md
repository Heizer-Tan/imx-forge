# install_firmwares.sh - i.MX 固件安装脚本详解

## 脚本概述

`install_firmwares.sh` 是 IMX-Forge 项目中用于下载和安装 i.MX6 系列处理器固件文件到根文件系统的脚本。这些固件文件是硬件正常工作所必需的，特别是对于 i.MX6 的 SDMA（Smart DMA）控制器。

### 核心功能

- **自动下载固件**：从 Armbian 固件仓库自动下载官方固件文件
- **固件完整性检查**：跳过已存在的固件文件，避免重复下载
- **目录结构创建**：自动创建 `/lib/firmware/imx/sdma` 目录结构
- **下载失败处理**：下载失败时清理不完整文件并报错退出
- **安装统计报告**：显示已安装的固件文件数量和列表

### 为什么需要固件

在嵌入式 Linux 系统中，某些硬件外设需要特定的二进制固件才能正常工作。固件是预先编译好的二进制代码，由硬件厂商提供，用于：

1. **初始化硬件**：配置硬件寄存器和内部状态
2. **提供微代码**：某些控制器（如 SDMA）包含微处理器，需要运行固件
3. **实现复杂功能**：硬件的高级功能可能需要固件支持

```
┌─────────────────────────────────────────────────────────────────┐
│  i.MX6 SDMA 控制器固件需求                                        │
├─────────────────────────────────────────────────────────────────┤
│  1. SDMA (Smart DMA) 是 i.MX6 的智能 DMA 控制器                 │
│  2. SDMA 包含一个微处理器，需要加载固件才能工作                   │
│  3. Linux 驱动在启动时请求固件文件                               │
│  4. 如果固件不存在，SDMA 无法初始化                              │
│  5. 许多外设依赖 SDMA（音频、串口等）                            │
└─────────────────────────────────────────────────────────────────┘
```

### i.MX6 固件架构

i.MX6 系列处理器的固件需求：

| 组件 | 固件文件 | 用途 | 必需性 |
|------|----------|------|--------|
| SDMA | sdma-imx6q.bin | i.MX6 Quad SDMA 固件 | 必需 |
| SDMA | sdma-imx6dl.bin | i.MX6 DualLite SDMA 固件 | 可选 |
| SDMA | sdma-imx6sl.bin | i.MX6 SoloLite SDMA 固件 | 可选 |
| VPU | vpu_fw.bin | 视频处理单元固件 | 可选 |
| GPU | gpu.bin | GPU 固件 | 可选 |

目前脚本主要安装 SDMA 固件，因为这是大多数基本功能（串口、音频等）所必需的。

### 依赖关系

```
install_firmwares.sh
    ├─ wget (下载工具)
    ├─ ROOTFS_DIR (根文件系统目录)
    └─ Internet connection (访问 GitHub)
```

调用关系：

```
varified_rootfs_ok.sh
    └─ install_firmwares.sh (被调用)
```

## 技术背景

### SDMA (Smart DMA) 详解

SDMA 是 NXP i.MX 系列处理器特有的智能 DMA 控制器：

```
┌─────────────────────────────────────────────────────────────┐
│                     i.MX6 SDMA 架构                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   ┌─────────┐     ┌─────────────┐     ┌──────────────┐     │
│   │  CPU    │────▶│  AIPS 总线   │────▶│   SDMA 控制器 │     │
│   └─────────┘     └─────────────┘     └──────┬───────┘     │
│                                               │             │
│                                     ┌─────────▼─────────┐   │
│                                     │  SDMA 微处理器     │   │
│                                     │  (需要固件)        │   │
│                                     └─────────┬─────────┘   │
│                                               │             │
│                                     ┌─────────▼─────────┐   │
│                                     │  固件 RAM          │   │
│                                     │  (sdma-imx6q.bin)  │   │
│                                     └───────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**SDMA 固件的作用**：

1. **脚本执行**：SDMA 微处理器运行固件中的 DMA 传输脚本
2. **通道管理**：管理多个 DMA 通道的优先级和调度
3. **外设支持**：为各种外设提供优化的 DMA 传输模式
4. **低功耗**：替代 CPU 处理数据传输，降低功耗

**依赖 SDMA 的外设**：

- UART（串口）
- SPI（串行外设接口）
- I2C（I2C 总线）
- Audio（音频控制器）
- ECSPI（增强型 SPI）

### Linux 固件加载机制

Linux 内核通过以下流程加载固件：

```
1. 内核启动时初始化设备驱动
        ↓
2. 驱动检测到硬件设备
        ↓
3. 驱动调用 request_firmware() 请求固件
        ↓
4. 用户空间 helper (udev) 搜索固件文件
   搜索路径：/lib/firmware/updates, /lib/firmware/
        ↓
5. 固件文件通过 sysfs 传递给内核
        ↓
6. 内核将固件加载到硬件
        ↓
7. 设备初始化完成
```

**固件文件的标准位置**：

```
/lib/firmware/                    # 主要固件目录
/lib/firmware/imx/               # i.MX 特定固件
/lib/firmware/imx/sdma/          # SDMA 固件
├── sdma-imx6q.bin               # i.MX6 Quad 固件
└── sdma-imx6dl.bin              # i.MX6 DualLite 固件
```

### Armbian 固件仓库

脚本从 Armbian 固件仓库下载固件：

- **仓库地址**：https://github.com/armbian/firmware
- **原因**：Armbian 维护了一个全面的 ARM 设备固件集合
- **优势**：
  - 定期更新
  - 经过测试验证
  - 包含多个厂商的固件

## 使用方法

### 基本用法

脚本通常由 `varified_rootfs_ok.sh` 自动调用，但也可以独立运行：

```bash
# 使用默认 rootfs 路径 (../rootfs/nfs)
./scripts/third_party_install/install_firmwares.sh

# 指定 rootfs 路径
ROOTFS_DIR=out/rootfs ./scripts/third_party_install/install_firmwares.sh

# 同时指定项目根目录
ROOTFS_DIR=out/rootfs \
  PROJECT_ROOT=/home/user/imx-forge \
  ./scripts/third_party_install/install_firmwares.sh
```

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ROOTFS_DIR` | 根文件系统目录路径 | `../rootfs/nfs` |
| `PROJECT_ROOT` | 项目根目录路径 | 自动检测 |
| `FIRMWARE_BASE_URL` | 固件下载基础 URL | `https://github.com/armbian/firmware/raw/master` |

### 输出格式

脚本使用带颜色和前缀的输出格式：

```
[install_firmwares] Installing i.MX firmware files to: rootfs/nfs
[install_firmwares] Downloading firmware files...
[install_firmwares]   Downloading: sdma-imx6q.bin
[install_firmwares]     ✓ Installed: sdma-imx6q.bin
[install_firmwares] Firmware installation complete!
[install_firmwares]   Installed 1 firmware file(s) to rootfs/nfs/lib/firmware/imx/sdma
[install_firmwares]
[install_firmwares] Installed firmware files:
[install_firmwares]   - sdma-imx6q.bin
```

## 执行流程

### 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. 初始化阶段                                               │
│     - 设置颜色变量                                           │
│     - 定义日志函数                                           │
│     - 设置默认参数                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 预检查阶段                                               │
│     - 检查 ROOTFS_DIR 是否存在                               │
│     - 如果不存在，报错退出                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. 目录准备阶段                                             │
│     - 创建 /lib/firmware/imx/sdma 目录                      │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. 固件下载阶段                                             │
│     - 遍历 FIRMWARE_FILES 列表                               │
│     - 检查文件是否已存在                                     │
│     - 下载缺失的固件文件                                     │
│     - 验证下载成功                                           │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  5. 统计报告阶段                                             │
│     - 统计已安装的固件文件数量                               │
│     - 显示已安装的固件文件列表                               │
└─────────────────────────────────────────────────────────────┘
```

### 函数详解

#### 日志函数

脚本定义了三个内嵌的日志函数：

```bash
log_info()  { echo -e "${GREEN}[install_firmwares]${NC} $1"; }
log_error() { echo -e "${RED}[install_firmwares]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[install_firmwares]${NC} $1"; }
```

**设计说明**：

- 使用 `[install_firmwares]` 前缀区分其他脚本的输出
- 颜色编码：绿色（信息）、红色（错误）、黄色（警告）
- `log_error` 输出到 stderr（`>&2`）

#### 固件配置

脚本开头定义了固件相关配置：

```bash
# 固件下载基础 URL
FIRMWARE_BASE_URL="https://github.com/armbian/firmware/raw/master"

# 固件目标目录
FIRMWARE_DEST_DIR="${ROOTFS_DIR}/lib/firmware/imx/sdma"

# 要安装的固件文件列表（相对路径）
FIRMWARE_FILES=(
    "imx/sdma/sdma-imx6q.bin"
)
```

**固件 URL 构建规则**：

```
完整 URL = FIRMWARE_BASE_URL + "/" + 固件相对路径
         = https://github.com/armbian/firmware/raw/master/imx/sdma/sdma-imx6q.bin
```

#### 目录创建

```bash
mkdir -p "$FIRMWARE_DEST_DIR"
```

使用 `-p` 参数确保：

- 父目录不存在时自动创建（`/lib/firmware/imx/sdma`）
- 目录已存在时不报错

**创建的目录结构**：

```
rootfs/nfs/
└── lib/
    └── firmware/
        └── imx/
            └── sdma/
                └── sdma-imx6q.bin
```

#### 固件下载逻辑

```bash
for fw_rel_path in "${FIRMWARE_FILES[@]}"; do
    # 提取文件名
    fw_file=$(basename "$fw_rel_path")
    # 构建完整 URL
    fw_url="${FIRMWARE_BASE_URL}/${fw_rel_path}"
    # 确定目标路径
    fw_dest="${FIRMWARE_DEST_DIR}/${fw_file}"

    # 检查是否已存在
    if [[ -f "$fw_dest" ]]; then
        log_info "  ✓ Already exists: ${fw_file}"
        continue
    fi

    # 下载
    log_info "  Downloading: ${fw_file}"
    if wget -q -O "$fw_dest" "$fw_url"; then
        log_info "    ✓ Installed: ${fw_file}"
    else
        log_error "    ✗ Failed to download: ${fw_file}"
        rm -f "$fw_dest"
        exit 1
    fi
done
```

**wget 参数说明**：

| 参数 | 作用 |
|------|------|
| `-q` | 安静模式，减少输出 |
| `-O "$fw_dest"` | 指定输出文件路径 |

**错误处理**：

- 下载失败时，删除可能不完整的文件（`rm -f "$fw_dest"`）
- 使用 `exit 1` 中止脚本执行

**为什么检查文件是否存在**：

1. **节省时间**：避免重复下载已存在的文件
2. **节省流量**：对于网络有限的环境很重要
3. **可恢复性**：可以多次运行脚本，不会重复操作

#### 统计报告

```bash
# 统计已安装的固件文件数量
FW_COUNT=$(find "${FIRMWARE_DEST_DIR}" -type f -name "*.bin" 2>/dev/null | wc -l)

log_info "Firmware installation complete!"
log_info "  Installed ${FW_COUNT} firmware file(s) to ${FIRMWARE_DEST_DIR}"
log_info ""
log_info "Installed firmware files:"

# 列出所有已安装的固件
find "${FIRMWARE_DEST_DIR}" -type f -name "*.bin" -exec basename {} \; 2>/dev/null | while read -r fw; do
    log_info "  - ${fw}"
done
```

**命令详解**：

- `find ... -type f -name "*.bin"`：查找所有 .bin 文件
- `wc -l`：统计行数（文件数量）
- `-exec basename {} \;`：只显示文件名，不显示路径

## 配置选项

### 硬编码配置

```bash
# 默认 rootfs 目录
: "${ROOTFS_DIR:=../rootfs/nfs}"

# 固件下载源
FIRMWARE_BASE_URL="https://github.com/armbian/firmware/raw/master"

# 固件目标目录
FIRMWARE_DEST_DIR="${ROOTFS_DIR}/lib/firmware/imx/sdma"

# 要安装的固件文件
FIRMWARE_FILES=(
    "imx/sdma/sdma-imx6q.bin"
)
```

### 添加更多固件文件

要支持更多 i.MX6 变体或其他固件，修改 `FIRMWARE_FILES` 数组：

```bash
FIRMWARE_FILES=(
    "imx/sdma/sdma-imx6q.bin"      # i.MX6 Quad
    "imx/sdma/sdma-imx6dl.bin"     # i.MX6 DualLite
    "imx/sdma/sdma-imx6sl.bin"     # i.MX6 SoloLite
    "imx/sdma/sdma-imx6sll.bin"    # i.MX6 SoloLite UL
    "imx/sdma/sdma-imx6ull.bin"    # i.MX6 UltraLite
)
```

### 使用本地固件源

如果无法访问 GitHub，可以修改 `FIRMWARE_BASE_URL` 指向本地或镜像：

```bash
# 使用本地目录
FIRMWARE_BASE_URL="file:///opt/firmware"

# 使用镜像
FIRMWARE_BASE_URL="https://mirror.example.com/firmware"
```

## 使用示例

### 场景 1：首次安装

```bash
$ ./scripts/third_party_install/install_firmwares.sh
[install_firmwares] Installing i.MX firmware files to: ../rootfs/nfs
[install_firmwares] Downloading firmware files...
[install_firmwares]   Downloading: sdma-imx6q.bin
[install_firmwares]     ✓ Installed: sdma-imx6q.bin
[install_firmwares] Firmware installation complete!
[install_firmwares]   Installed 1 firmware file(s) to ../rootfs/nfs/lib/firmware/imx/sdma
[install_firmwares]
[install_firmwares] Installed firmware files:
[install_firmwares]   - sdma-imx6q.bin
```

### 场景 2：固件已存在

```bash
$ ./scripts/third_party_install/install_firmwares.sh
[install_firmwares] Installing i.MX firmware files to: ../rootfs/nfs
[install_firmwares] Downloading firmware files...
[install_firmwares]   ✓ Already exists: sdma-imx6q.bin
[install_firmwares] Firmware installation complete!
[install_firmwares]   Installed 1 firmware file(s) to ../rootfs/nfs/lib/firmware/imx/sdma
[install_firmwares]
[install_firmwares] Installed firmware files:
[install_firmwares]   - sdma-imx6q.bin
```

### 场景 3：下载失败

```bash
$ ./scripts/third_party_install/install_firmwares.sh
[install_firmwares] Installing i.MX firmware files to: ../rootfs/nfs
[install_firmwares] Downloading firmware files...
[install_firmwares]   Downloading: sdma-imx6q.bin
[install_firmwares]     ✗ Failed to download: sdma-imx6q.bin
```

解决方法：

```bash
# 检查网络连接
ping -c 3 github.com

# 手动下载并安装
wget -O rootfs/nfs/lib/firmware/imx/sdma/sdma-imx6q.bin \
  https://github.com/armbian/firmware/raw/master/imx/sdma/sdma-imx6q.bin
```

### 场景 4：指定自定义 rootfs

```bash
$ ROOTFS_DIR=out/rootfs ./install_firmwares.sh
[install_firmwares] Installing i.MX firmware files to: out/rootfs
[install_firmwares] Downloading firmware files...
[install_firmwares]   Downloading: sdma-imx6q.bin
[install_firmwares]     ✓ Installed: sdma-imx6q.bin
[install_firmwares] Firmware installation complete!
[install_firmwares]   Installed 1 firmware file(s) to out/rootfs/lib/firmware/imx/sdma
```

## 故障排除

### 常见错误

#### 错误 1：rootfs 目录不存在

```
[install_firmwares] Rootfs directory not found: /path/to/rootfs
```

**原因**：指定的 `ROOTFS_DIR` 不存在

**解决方法**：

```bash
# 创建目录
mkdir -p out/rootfs

# 重新运行
ROOTFS_DIR=out/rootfs ./install_firmwares.sh
```

#### 错误 2：下载失败

```
[install_firmwares]   ✗ Failed to download: sdma-imx6q.bin
```

**原因**：

1. 网络连接问题
2. GitHub 访问受限
3. URL 错误

**解决方法**：

```bash
# 检查网络连接
wget --spider https://github.com/armbian/firmware/raw/master/imx/sdma/sdma-imx6q.bin

# 使用代理
export https_proxy=http://proxy.example.com:8080
./install_firmwares.sh

# 手动下载
wget -O rootfs/nfs/lib/firmware/imx/sdma/sdma-imx6q.bin \
  https://github.com/armbian/firmware/raw/master/imx/sdma/sdma-imx6q.bin
```

#### 错误 3：wget 未安装

```
bash: wget: command not found
```

**解决方法**：

```bash
# Ubuntu/Debian
sudo apt-get install wget

# Fedora/RHEL
sudo dnf install wget

# Arch Linux
sudo pacman -S wget
```

#### 错误 4：权限不足

```
bash: rootfs/nfs/lib/firmware/imx/sdma/sdma-imx6q.bin: Permission denied
```

**解决方法**：

```bash
# 检查目录权限
ls -ld rootfs/nfs/lib/firmware/imx/sdma/

# 修改权限
chmod 755 rootfs/nfs/lib/firmware/imx/sdma/

# 或使用 sudo
sudo ROOTFS_DIR=rootfs/nfs ./install_firmwares.sh
```

### 调试技巧

#### 手动测试固件 URL

```bash
# 测试 URL 是否可访问
curl -I https://github.com/armbian/firmware/raw/master/imx/sdma/sdma-imx6q.bin

# 预期输出包含：HTTP/1.1 200 OK
```

#### 查看已安装的固件

```bash
# 列出所有固件文件
find rootfs/nfs/lib/firmware -type f -name "*.bin"

# 检查 SDMA 固件
ls -l rootfs/nfs/lib/firmware/imx/sdma/

# 验证文件内容
file rootfs/nfs/lib/firmware/imx/sdma/sdma-imx6q.bin
# 预期输出：data
```

#### 验证固件大小

```bash
# 检查固件文件大小
ls -lh rootfs/nfs/lib/firmware/imx/sdma/sdma-imx6q.bin

# 正常的 sdma-imx6q.bin 约 7KB
# 如果文件很小（0 字节），说明下载失败
```

#### 在目标板上验证

在 i.MX6 板子上启动后，检查内核日志：

```bash
# 在板子上执行
dmesg | grep -i firmware
dmesg | grep -i sdma

# 预期输出（成功）：
# sdma 20ec000.sdma: firmware found
```

如果固件缺失：

```bash
# 预期输出（失败）：
# sdma 20ec000.sdma: failed to get firmware
# sdma 20ec000.sdma: request firmware failed
```

## 设计决策说明

### 为什么从 Armbian 仓库下载

Armbian 是一个成熟的 ARM Linux 发行版项目，其固件仓库的优势：

1. **官方维护**：定期更新和验证
2. **全面覆盖**：包含多个厂商和型号
3. **稳定可靠**：经过实际项目验证
4. **易于访问**：GitHub 托管，全球可用

**为什么不从 NXP 官网下载**：

- NXP 固件分散在多个 SDK 和包中
- 需要注册账号和接受许可
- 下载链接不稳定
- Armbian 已经整理好了常用固件

### 为什么使用 -q 参数

wget 的 `-q`（安静）参数减少输出，让脚本输出更简洁：

```bash
# 不使用 -q
wget -O "$fw_dest" "$fw_url"
# 输出：大量进度信息

# 使用 -q
wget -q -O "$fw_dest" "$fw_url"
# 输出：无额外信息，只显示脚本日志
```

如果需要调试，可以临时移除 `-q` 参数：

```bash
wget -O "$fw_dest" "$fw_url"  # 显示下载进度
```

### 为什么下载失败时删除文件

```bash
if ! wget -q -O "$fw_dest" "$fw_url"; then
    rm -f "$fw_dest"
    exit 1
fi
```

**原因**：

1. **避免残留**：不完整的文件可能导致系统误以为固件已安装
2. **可重试**：下次运行脚本会重新尝试下载
3. **明确状态**：要么完整，要么不存在

### 为什么固件放在 /lib/firmware 而不是 /usr/lib/firmware

遵循 Linux FHS（Filesystem Hierarchy Standard）：

- `/lib/firmware`：内核和硬件相关固件（系统启动必需）
- `/usr/lib/firmware`：非必需固件

SDMA 固件在系统启动时就需要，所以放在 `/lib/firmware`。

### 为什么不验证固件校验和

脚本目前不验证固件文件的完整性（如 MD5/SHA256），原因：

1. **HTTPS 保护**：从 GitHub HTTPS 下载，传输过程中不会被篡改
2. **信任源**：Armbian 是可信的开源项目
3. **简化设计**：保持脚本简单，不增加复杂度

如果需要更高安全性，可以添加校验和验证：

```bash
# 预期校验和
EXPECTED_SHA256="a1b2c3d4..."

# 下载后验证
ACTUAL_SHA256=$(sha256sum "$fw_dest" | cut -d' ' -f1)
if [[ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]]; then
    log_error "Firmware checksum mismatch"
    rm -f "$fw_dest"
    exit 1
fi
```

## 扩展和定制

### 支持其他 i.MX6 变体

```bash
FIRMWARE_FILES=(
    "imx/sdma/sdma-imx6q.bin"      # i.MX6 Quad (已有)
    "imx/sdma/sdma-imx6q.bin"      # i.MX6 Quad Plus
    "imx/sdma/sdma-imx6dl.bin"     # i.MX6 DualLite
    "imx/sdma/sdma-imx6solo.bin"   # i.MX6 Solo
)
```

### 添加其他硬件固件

```bash
FIRMWARE_FILES=(
    "imx/sdma/sdma-imx6q.bin"
    "imx/vpu/vpu_fw_imx6.bin"      # 视频处理单元
    "ath10k/QCA9377/hw1.0/firmware-5.bin"  # WiFi 固件
    "rtl_bt/rtl8723bs_fw.bin"      # 蓝牙固件
)
```

注意：不同类型的固件可能需要不同的目标目录。

### 使用本地固件文件

如果需要使用自定义或离线固件：

```bash
# 创建本地固件目录
mkdir -p /opt/firmware/imx/sdma

# 复制固件文件
cp /path/to/custom_sdma.bin /opt/firmware/imx/sdma/sdma-imx6q.bin

# 修改脚本使用本地源
FIRMWARE_BASE_URL="file:///opt/firmware"
```

### 添加固件版本选择

支持选择不同版本的固件：

```bash
# 添加版本变量
FIRMWARE_VERSION="${FIRMWARE_VERSION:-latest}"

# 构建带版本的 URL
FIRMWARE_BASE_URL="https://github.com/armbian/firmware/raw/${FIRMWARE_VERSION}"
```

使用：

```bash
# 使用特定版本
FIRMWARE_VERSION=v1.0 ./install_firmwares.sh
```

### 添加离线模式

支持离线安装（跳过下载，只检查）：

```bash
# 离线模式变量
: "${FIRMWARE_OFFLINE:=0}"

# 在下载逻辑前添加检查
if [[ "$FIRMWARE_OFFLINE" == "1" ]]; then
    if [[ ! -f "$fw_dest" ]]; then
        log_error "Firmware not found and offline mode enabled: ${fw_file}"
        exit 1
    fi
    log_info "  ✓ Using cached: ${fw_file}"
    continue
fi
```

使用：

```bash
FIRMWARE_OFFLINE=1 ROOTFS_DIR=rootfs/nfs ./install_firmwares.sh
```

## 相关概念

### Linux 固件 API

Linux 内核提供两种主要的固件请求 API：

#### request_firmware()

同步请求固件：

```c
const struct firmware *fw;
int ret;

ret = request_firmware(&fw, "sdma-imx6q.bin", &dev->dev);
if (ret) {
    dev_err(&dev->dev, "Failed to load firmware\n");
    return ret;
}

/* 使用固件 */
memcpy_toio(device_base, fw->data, fw->size);

/* 释放固件 */
release_firmware(fw);
```

#### request_firmware_nowait()

异步请求固件（不阻塞驱动初始化）：

```c
int ret;

ret = request_firmware_nowait(THIS_MODULE, 1,
                              "sdma-imx6q.bin",
                              &dev->dev, GFP_KERNEL,
                              dev, firmware_load_cb);
if (ret) {
    dev_err(&dev->dev, "Failed to request firmware\n");
    return ret;
}

/* 固件在回调函数中处理 */
```

### 固件加载用户空间 Helper

传统的固件加载方式需要 `udev` 的 `firmware_helper`：

```
内核请求固件
     ↓
uevent 事件
     ↓
udev 固件 helper
     ↓
搜索 /lib/firmware
     ↓
通过 sysfs 传递给内核
```

现代内核使用 `CONFIG_FW_LOADER_USER_HELPER_FALLBACK` 可以直接在内核中加载固件。

### 内核配置选项

相关内核配置：

```
CONFIG_FW_LOADER=y                    # 固件加载器支持
CONFIG_FW_LOADER_USER_HELPER=n        # 不使用用户空间 helper
CONFIG_FIRMWARE_IN_KERNEL=n           # 固件不内嵌到内核镜像
CONFIG_EXTRA_FIRMWARE=""              # 内嵌固件列表（空）
CONFIG_EXTRA_FIRMWARE_DIR=""          # 内嵌固件目录
```

**为什么不内嵌固件到内核**：

- 增加内核镜像大小
- 更新固件需要重新编译内核
- 分离固件便于更新和管理

### 设备树固件指定

某些驱动可以通过设备树指定固件名称：

```dts
sdma: dma-controller@20ec000 {
    compatible = "fsl,imx6q-sdma";
    reg = <0x020ec000 0x4000>;
    interrupts = <0 6 IRQ_TYPE_LEVEL_HIGH>;
    fsl,sdma-ram-script-name = "imx/sdma/sdma-imx6q.bin";
};
```

## 相关文档

- Rootfs 概述 - Rootfs 的基本概念
- 设备驱动开发 - Linux 设备驱动
- [varified_rootfs_ok.sh](../varified_rootfs_ok.sh) - 调用此脚本的上级脚本
- install_libc.sh - libc 安装脚本
- [i.MX6 参考手册](https://www.nxp.com/docs/en/reference-manual/IMX6DQRM.pdf) - NXP 官方文档

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-03-19 | 1.0 | 初始完整版本 |

---

> **文档生成时间**: 2026-03-19
> **对应脚本版本**: install_firmwares.sh
