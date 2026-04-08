# install_qt_with_compile.sh - Qt6 编译安装脚本详解

## 脚本概述

`install_qt_with_compile.sh` 是 IMX-Forge 项目中用于编译和安装 Qt6 框架到目标板的核心脚本。它通过调用 `qt-compile-pipeline` 子模块中的编译管道，自动完成从源码下载、交叉编译到 ROOTFS 部署的完整流程。

### 核心功能

- **自动分支管理**：将 qt-compile-pipeline 子模块切换到独立的编译分支
- **配置覆盖**：将自定义配置文件拷贝到编译管道
- **六阶段编译**：执行完整的 Qt6 编译流程（源码获取、工具链、Host Qt、依赖、Target Qt、打包）
- **ROOTFS 部署**：自动将编译产物安装到根文件系统
- **第三方库集成**：安装 PulseAudio、FFmpeg、OpenSSL 等依赖库
- **字体安装**：可选的中文字体支持

### 为什么需要这个脚本

Qt6 是一个复杂的跨平台应用程序开发框架，在嵌入式 Linux 上交叉编译 Qt6 涉及多个步骤：

```
┌─────────────────────────────────────────────────────────────────┐
│  Qt6 交叉编译复杂度                                               │
├─────────────────────────────────────────────────────────────────┤
│  1. 首先编译 Host Qt（x86_64），用于编译 Target Qt 时的工具     │
│  2. 获取交叉编译工具链并验证                                     │
│  3. 安装目标平台的依赖库（ALSA、PulseAudio、FFmpeg 等）          │
│  4. 交叉编译 Target Qt（ARM）                                    │
│  5. 将编译产物部署到 ROOTFS                                      │
│  6. 配置运行时环境（字体、库路径等）                              │
└─────────────────────────────────────────────────────────────────┘
```

这个脚本自动化了上述所有步骤，让开发者只需运行一个命令就能完成 Qt6 的编译和部署。

### 设计理念

脚本遵循"配置与代码分离"的原则：

1. **配置外部化**：所有编译参数都在 `config/qt/` 目录下的配置文件中
2. **分支隔离**：每次编译创建独立的 `compile-YYYYMMDD` 分支
3. **主项目保护**：子模块分支切换不影响主项目 Git 状态
4. **增量构建**：支持 `--stage` 参数从指定阶段继续

### 依赖关系

```
install_qt_with_compile.sh
    ├─ scripts/lib/logging.sh (日志工具库)
    ├─ third_party/qt-compile-pipeline (Qt 编译管道子模块)
    │   ├─ scripts/00-fetch-qt-src.sh (阶段 1)
    │   ├─ scripts/01-fetch-toolchain.sh (阶段 2)
    │   ├─ scripts/02-build-host-qt.sh (阶段 3)
    │   ├─ scripts/install_target_deps.sh (阶段 4)
    │   ├─ scripts/03-build-target-qt.sh (阶段 5)
    │   └─ scripts/04-package.sh (阶段 6)
    ├─ config/qt/*.conf (配置文件)
    ├─ scripts/third_party_install/install_fonts.sh (字体安装)
    └─ ROOTFS_DIR (根文件系统目录)
```

## 编译阶段说明

Qt 编译流程分为 6 个阶段，每个阶段负责特定的任务：

```
┌─────────────────────────────────────────────────────────────┐
│  阶段 1: 下载 Qt 源码                                         │
│  ├─ 脚本: 00-fetch-qt-src.sh                                 │
│  ├─ 功能: 从官方服务器下载 Qt 源码包                         │
│  └─ 输出: ${WORK_DIR}/qt-everywhere-src-${QT_VERSION}/      │
├─────────────────────────────────────────────────────────────┤
│  阶段 2: 获取交叉编译工具链                                   │
│  ├─ 脚本: 01-fetch-toolchain.sh                              │
│  ├─ 功能: 下载并验证 ARM 交叉编译工具链                      │
│  └─ 输出: ${WORK_DIR}/toolchain/                            │
├─────────────────────────────────────────────────────────────┤
│  阶段 3: 编译 Host Qt                                         │
│  ├─ 脚本: 02-build-host-qt.sh                                │
│  ├─ 功能: 编译 x86_64 版本的 Qt6                              │
│  ├─ 用途: 为 Target Qt 编译提供工具（如 qmake、moc、rcc）    │
│  └─ 输出: ${PROJECT_ROOT}/host/qt6-host/                    │
├─────────────────────────────────────────────────────────────┤
│  阶段 4: 安装 Target 依赖                                     │
│  ├─ 脚本: install_target_deps.sh                             │
│  ├─ 功能: 下载并编译目标平台的依赖库                         │
│  ├─ 依赖: ALSA、PulseAudio、FFmpeg、OpenSSL、tslib          │
│  └─ 输出: ${WORK_DIR}/third-party-sysroot/                  │
├─────────────────────────────────────────────────────────────┤
│  阶段 5: 编译 Target Qt                                       │
│  ├─ 脚本: 03-build-target-qt.sh                              │
│  ├─ 功能: 交叉编译 ARM 版本的 Qt6                             │
│  ├─ 使用: Host Qt 的工具 + 交叉编译工具链                    │
│  └─ 输出: ${PROJECT_ROOT}/out/qt6-imx6ull/                  │
├─────────────────────────────────────────────────────────────┤
│  阶段 6: 打包                                                 │
│  ├─ 脚本: 04-package.sh                                      │
│  ├─ 功能: 整理和验证编译产物                                  │
│  └─ 输出: 最终的 Qt6 安装包                                  │
└─────────────────────────────────────────────────────────────┘
```

### 阶段详细说明

#### 阶段 1: 下载 Qt 源码

从 Qt 官方服务器下载完整的 Qt6 源码包（qt-everywhere-src-6.9.1.tar.xz），解压到工作目录。

#### 阶段 2: 获取交叉编译工具链

下载 ARM 交叉编译工具链（如果本地不存在），验证工具链版本和完整性。

#### 阶段 3: 编译 Host Qt

编译运行在主机（x86_64）上的 Qt6，这一步是必须的，因为：
- Qt 的元对象编译器（moc）需要先编译
- 资源编译器（rcc）需要先编译
- qmake 工具需要先编译

这些工具在编译 Target Qt 时会被调用。

#### 阶段 4: 安装 Target 依赖

下载并编译目标平台需要的第三方库：

| 库 | 用途 | Qt 模块 |
|---|------|---------|
| tslib | 触摸屏校准 | Qt Gui |
| libsndfile | 音频文件格式支持 | PulseAudio |
| PulseAudio | 音频服务 | Qt Multimedia |
| FFmpeg | 多媒体编解码 | Qt Multimedia |
| OpenSSL | SSL/TLS 支持 | Qt Network |

#### 阶段 5: 编译 Target Qt

使用 Host Qt 的工具和交叉编译工具链，编译 ARM 版本的 Qt6。

#### 阶段 6: 打包

整理编译产物，生成最终的安装包。

## 使用方法

### 基本用法

```bash
# 完整编译（执行所有 6 个阶段）
./scripts/third_party_install/install_qt_with_compile.sh

# 从指定阶段开始（用于中断后继续）
./scripts/third_party_install/install_qt_with_compile.sh --stage 3

# 使用自定义分支名
./scripts/third_party_install/install_qt_with_compile.sh --branch my-qt-build

# 跳过字体安装
./scripts/third_party_install/install_qt_with_compile.sh --no-fonts
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--stage <n>` | 只执行指定阶段（1-6） | 执行所有阶段 |
| `--branch <name>` | 使用自定义分支名 | `compile-YYYYMMDD` |
| `--no-fonts` | 跳过字体安装步骤 | 安装字体 |
| `-h, --help` | 显示帮助信息 | - |

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `PROJECT_ROOT` | 项目根目录 | 自动检测 |
| `CONFIG_SOURCE_DIR` | Qt 配置文件源目录 | `scripts/third_party_install/config/qt` |
| `ROOTFS_DIR` | 根文件系统目录 | `rootfs/nfs` |

### 输出格式

```
[INFO] === Qt 编译安装脚本 ===
[INFO] 项目根目录: /home/charliechen/imx-forge
[INFO] qt-compile-pipeline: /home/charliechen/imx-forge/third_party/qt-compile-pipeline
[INFO] 配置源目录: /home/charliechen/imx-forge/scripts/third_party_install/config/qt

[INFO] 准备覆盖的配置文件:
[INFO]   - qt.conf
[INFO]   - host.conf
[INFO]   - target.conf
[INFO]   - third_party.conf

[INFO] 在子模块 qt-compile-pipeline 中切换分支
[INFO] 子模块回到默认分支: main
[INFO] 子模块创建新分支: compile-20260319
[INFO] 主项目分支保持不变: main

[INFO] === 覆盖配置文件 ===
[INFO] 拷贝 qt.conf...
[INFO]   → /home/charliechen/imx-forge/third_party/qt-compile-pipeline/config/qt.conf

[INFO] === 配置摘要 ===
[INFO] Qt 版本: 6.9.1
[INFO] 模块: qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat
[INFO] 输出路径:
[INFO]   Host Qt:   /home/charliechen/imx-forge/host/qt6-host
[INFO]   Target Qt: /home/charliechen/imx-forge/out/qt6-imx6ull
[INFO]   工作目录:  /home/charliechen/imx-forge/out/third_party/.qt-workdir

[INFO] === 开始编译 ===
[INFO] 阶段 1: 下载 Qt 源码
...
```

## 配置文件说明

Qt 编译配置由四个配置文件控制，位于 `scripts/third_party_install/config/qt/`：

### qt.conf - Qt 版本与源码配置

```bash
# Qt 版本
QT_VERSION="6.9.1"

# 源码下载地址
QT_SRC_URL="https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-${QT_VERSION}.tar.xz"

# 工作目录（中间产物）
WORK_DIR="${PROJECT_ROOT}/out/third_party/.qt-workdir"

# Qt 模块列表
QT_MODULES="qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat"

# 编译开关
BUILD_HOST_QT=true
BUILD_TARGET_QT=true
```

### host.conf - Host Qt 编译配置

```bash
# Host Qt 安装路径
HOST_INSTALL_PREFIX="${PROJECT_ROOT}/host/qt6-host"

# 是否构建 Debug 版本
HOST_BUILD_DEBUG=false

# 额外 configure 参数
HOST_CONFIGURE_EXTRA="\
  -ltcg \
  -DFEATURE_sql=OFF \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
"

# 额外 CMake 参数
HOST_CMAKE_EXTRA="\
  -DFEATURE_optimize_full=ON \
"
```

### target.conf - Target Qt 交叉编译配置

```bash
# Target Qt 安装路径
TARGET_INSTALL_PREFIX="${PROJECT_ROOT}/out/qt6-imx6ull"

# 目标设备上的路径
TARGET_DEVICE_PREFIX="/usr/local/qt6"

# OpenGL 配置
TARGET_USE_OPENGL=false

# ALSA 音频支持
TARGET_USE_ALSA=true

# FFmpeg 多媒体支持
TARGET_USE_FFMPEG=true

# 目标架构
TARGET_ARCH="armhf"

# Qt 平台插件
QT_TARGET_PLATFORM="linux-arm-gnueabihf-g++"

# 渲染后端配置
TARGET_RENDER_BACKENDS="\
  -DFEATURE_xcb=OFF \
  -DFEATURE_eglfs=OFF \
  -DFEATURE_linuxfb=ON \
  -DFEATURE_evdev=ON \
  -DFEATURE_tslib=ON \
  -DFEATURE_libinput=OFF \
  -DINPUT_opengl=no \
  -DFEATURE_glib=OFF \
  -DFEATURE_system_sqlite=OFF
"

# 额外 configure 参数
TARGET_CONFIGURE_EXTRA="\
  -DFEATURE_printsupport=OFF \
  -no-feature-opengl \
  -DFEATURE_openssl=ON \
  -DFEATURE_ssl=ON \
  -ltcg \
"
```

### third_party.conf - 第三方库配置

```bash
# 第三方库 sysroot 目录
THIRD_PARTY_SYSROOT="${WORK_DIR}/third-party-sysroot"

# tslib 配置（触摸屏校准）
TSLIB_ENABLED="${TSLIB_ENABLED:-true}"
TSLIB_BUILTIN_VERSION="1.22"

# PulseAudio 配置
PULSEAUDIO_ENABLED="${PULSEAUDIO_ENABLED:-true}"
PULSEAUDIO_BUILTIN_VERSION="17.0"

# FFmpeg 配置
FFMPEG_ENABLED="${FFMPEG_ENABLED:-true}"
FFMPEG_BUILTIN_VERSION="7.1"

# OpenSSL 配置
OPENSSL_ENABLED="${OPENSSL_ENABLED:-true}"
OPENSSL_BUILTIN_VERSION="3.4.0"

# 启用的库列表
THIRD_PARTY_LIBS="tslib libsndfile pulseaudio ffmpeg openssl"
```

## ROOTFS 安装过程

编译完成后，脚本自动将产物部署到 ROOTFS：

### 第 1 步: 安装 Target Qt

```
源目录: ${TARGET_INSTALL_PREFIX}
目标目录: ${ROOTFS_DIR}/usr

拷贝内容:
  lib/*       → ${ROOTFS_DIR}/usr/lib/       (Qt 库文件)
  bin/*       → ${ROOTFS_DIR}/usr/bin/       (Qt 可执行文件)
  plugins/*   → ${ROOTFS_DIR}/usr/lib/qt6/plugins/  (Qt 插件)
  qml/*       → ${ROOTFS_DIR}/usr/lib/qt6/qml/      (QML 模块)
  mkspecs/*   → ${ROOTFS_DIR}/usr/lib/qt6/mkspecs/  (编译规范)
  ...         → ${ROOTFS_DIR}/usr/lib/qt6/  (其他目录)
```

### 第 2 步: 安装第三方库

```
源目录: ${THIRD_PARTY_SYSROOT}
目标目录: ${ROOTFS_DIR}

拷贝内容:
  *.so, *.a  → ${ROOTFS_DIR}/usr/lib/  (库文件)
  可执行文件  → ${ROOTFS_DIR}/usr/bin/ (工具程序)
```

### 第 3 步: 安装字体

```
内容:
  - DejaVu Fonts (拉丁字符 + 等宽字体)
  - Noto Sans CJK (中日韩字符)
  - Noto Color Emoji (Emoji 支持)

目标目录: ${ROOTFS_DIR}/usr/share/fonts/
```

### 安装完成摘要

```
[INFO] === ROOTFS 安装完成 ===
[INFO] 安装内容:
[INFO]   Qt 库:      ${ROOTFS_DIR}/usr/lib/
[INFO]   Qt 可执行:  ${ROOTFS_DIR}/usr/bin/
[INFO]   Qt 插件:    ${ROOTFS_DIR}/usr/lib/qt6/plugins/
[INFO]   Qt QML:     ${ROOTFS_DIR}/usr/lib/qt6/qml/
[INFO]   第三方库:   ${ROOTFS_DIR}/usr/lib/
[INFO]   字体:       ${ROOTFS_DIR}/usr/share/fonts/
[INFO]
[INFO] Qt 字体环境变量:
[INFO]   export QT_QPA_FONTDIR=/usr/share/fonts
[INFO]   export LANG=C.UTF-8
```

## 输出目录

脚本创建以下目录结构：

```
PROJECT_ROOT/
├── host/
│   └── qt6-host/              # Host Qt (x86_64)
│       ├── bin/               # qmake, moc, rcc, uic 等
│       ├── lib/               # Qt 库文件
│       ├── plugins/           # Qt 插件
│       └── mkspecs/           # 编译规范
├── out/
│   ├── qt6-imx6ull/           # Target Qt (ARM) - staging 目录
│   │   ├── bin/               # ARM 版本的工具
│   │   ├── lib/               # ARM 版本的库
│   │   ├── plugins/           # ARM 版本的插件
│   │   ├── qml/               # QML 模块
│   │   └── mkspecs/           # 编译规范
│   └── .qt-workdir/           # 工作目录（中间产物）
│       ├── qt-everywhere-src-6.9.1/  # Qt 源码
│       ├── build-host/        # Host Qt 构建目录
│       ├── build-target/      # Target Qt 构建目录
│       ├── toolchain/         # 工具链
│       └── third-party-sysroot/  # 第三方库
└── rootfs/
    └── nfs/                   # ROOTFS (最终部署位置)
        ├── usr/
        │   ├── lib/           # Qt 库 + 第三方库
        │   ├── bin/           # Qt 工具
        │   └── share/
        │       └── fonts/     # 字体文件
        └── lib/
            └── firmware/      # 固件
```

## 使用示例

### 场景 1: 首次完整编译

```bash
$ ./scripts/third_party_install/install_qt_with_compile.sh
[INFO] === Qt 编译安装脚本 ===
[INFO] 项目根目录: /home/charliechen/imx-forge
[INFO] qt-compile-pipeline: /home/charliechen/imx-forge/third_party/qt-compile-pipeline
...
[INFO] 阶段 1: 下载 Qt 源码
[INFO] 阶段 1 完成
[INFO] 阶段 2: 下载交叉编译工具链
[INFO] 阶段 2 完成
[INFO] 阶段 3: 编译 Host Qt
[INFO] 阶段 3 完成
[INFO] 阶段 4: 安装 Target 依赖
[INFO] 阶段 4 完成
[INFO] 阶段 5: 编译 Target Qt
[INFO] 阶段 5 完成
[INFO] 阶段 6: 打包
[INFO] 阶段 6 完成
...
[INFO] === ROOTFS 安装完成 ===
[INFO] === 编译完成 ===
```

### 场景 2: 从指定阶段继续

如果编译在第 3 阶段后中断，可以从第 4 阶段继续：

```bash
$ ./scripts/third_party_install/install_qt_with_compile.sh --stage 4
[INFO] === Qt 编译安装脚本 ===
...
[INFO] === 开始编译 ===
[INFO] 阶段 4: 安装 Target 依赖
...
```

### 场景 3: 使用自定义分支名

```bash
$ ./scripts/third_party_install/install_qt_with_compile.sh --branch feature-qt6-network
[INFO] 子模块创建新分支: feature-qt6-network
...
```

### 场景 4: 跳过字体安装

```bash
$ ./scripts/third_party_install/install_qt_with_compile.sh --no-fonts
...
[INFO] 步骤 3/3: 安装字体
[INFO] 已跳过 (--no-fonts)
```

### 场景 5: 指定不同的 ROOTFS

```bash
$ ROOTFS_DIR=out/rootfs ./scripts/third_party_install/install_qt_with_compile.sh
```

## 故障排除

### 常见错误

#### 错误 1: qt-compile-pipeline 子模块未初始化

```
[ERROR] qt-compile-pipeline 目录不存在
```

**解决方法**：

```bash
# 初始化子模块
git submodule update --init --recursive third_party/qt-compile-pipeline
```

#### 错误 2: ROOTFS 目录不存在

```
[ERROR] ROOTFS 目录不存在: /path/to/rootfs
```

**解决方法**：

```bash
# 创建 ROOTFS 目录
mkdir -p rootfs/nfs

# 或指定其他路径
ROOTFS_DIR=out/rootfs ./scripts/third_party_install/install_qt_with_compile.sh
```

#### 错误 3: 交叉编译工具链未找到

```
[ERROR] 交叉编译器 arm-none-linux-gnueabihf-gcc 未找到
```

**解决方法**：

```bash
# 安装工具链
sudo apt install gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf

# 验证安装
arm-linux-gnueabihf-gcc --version
```

#### 错误 4: 源码下载失败

```
[ERROR] 下载 Qt 源码失败
```

**解决方法**：

```bash
# 检查网络连接
ping -c 3 download.qt.io

# 使用国内镜像（修改 qt.conf）
# QT_SRC_URL="https://mirrors.ustc.edu.cn/qtproject/archive/qt/6.9/6.9.1/single/qt-everywhere-src-6.9.1.tar.xz"

# 或手动下载后放到工作目录
wget https://download.qt.io/official_releases/qt/6.9/6.9.1/single/qt-everywhere-src-6.9.1.tar.xz
mv qt-everywhere-src-6.9.1.tar.xz out/third_party/.qt-workdir/downloads/
```

#### 错误 5: Host Qt 编译失败

```
[ERROR] 阶段 3 失败: 编译 Host Qt
```

**解决方法**：

```bash
# 检查主机依赖
sudo apt install build-essential cmake perl python3 ninja-build \
                 libgl1-mesa-dev libglib2.0-dev libxkbcommon-dev \
                 libfontconfig1-dev libfreetype6-dev libssl-dev

# 清理后重新编译
rm -rf out/third_party/.qt-workdir/build-host
./scripts/third_party_install/install_qt_with_compile.sh --stage 3
```

#### 错误 6: Target Qt 编译失败

```
[ERROR] 阶段 5 失败: 编译 Target Qt
```

**解决方法**：

```bash
# 检查交叉编译环境
arm-linux-gnueabihf-gcc --version
arm-linux-gnueabihf-g++ --version

# 检查 Host Qt 是否正确编译
ls host/qt6-host/bin/qmake

# 清理后重新编译
rm -rf out/third_party/.qt-workdir/build-target
./scripts/third_party_install/install_qt_with_compile.sh --stage 5
```

### 调试技巧

#### 查看详细日志

```bash
# 启用 bash 调试模式
bash -x scripts/third_party_install/install_qt_with_compile.sh
```

#### 检查编译产物

```bash
# 检查 Host Qt
host/qt6-host/bin/qmake -v

# 检查 Target Qt 架构
readelf -h out/qt6-imx6ull/lib/libQt6Core.so.6 | grep Machine
# 应显示: ARM

# 检查 ROOTFS 中的 Qt
ls -l rootfs/nfs/usr/lib/libQt6*
```

#### 验证交叉编译

```bash
# 检查动态链接
arm-linux-gnueabihf-readelf -d out/qt6-imx6ull/lib/libQt6Core.so.6

# 检查依赖
arm-linux-gnueabihf-ldd out/qt6-imx6ull/bin/qmake 2>/dev/null || echo "跨平台 ldd 不可用"
```

## 设计决策说明

### 为什么需要创建独立分支

每次编译创建 `compile-YYYYMMDD` 分支的原因：

1. **配置隔离**：不同编译任务使用不同配置，互不干扰
2. **可追溯性**：可以回退到任意历史编译配置
3. **主项目保护**：子模块分支切换不影响主项目

### 为什么先编译 Host Qt

Qt6 的交叉编译需要 Host Qt 的工具：

- `qmake`：项目生成工具
- `moc`：元对象编译器
- `rcc`：资源编译器
- `uic`：UI 编译器

这些工具在编译 Target Qt 时会被调用。

### 为什么使用 `cp -d` 复制库文件

脚本中 `cp -rf` 用于拷贝大多数文件，但第三方库拷贝使用 `cp -d`：

```bash
cp -d {} "${ROOTFS_DIR}/usr/lib/"
```

`-d` 参数保留符号链接，不解引用，这对于动态链接很重要。

### 为什么 Qt 安装到 /usr 而不是 /usr/local

Qt 库被安装到 `/usr/lib` 而不是 `/usr/local/lib`，因为：

1. **系统兼容性**：大多数程序查找库的路径包含 `/usr/lib`
2. **简洁性**：避免设置额外的 `LD_LIBRARY_PATH`
3. **FHS 规范**：用户安装的库可以放在 `/usr/lib`

## 扩展和定制

### 添加 Qt 模块

修改 `config/qt/qt.conf`：

```bash
# 添加新模块
QT_MODULES="qtbase qtdeclarative qtmultimedia qtcharts qtshadertools qtserialport qtvirtualkeyboard qt5compat qt3d qtscxml"
```

### 修改目标架构

修改 `config/qt/target.conf`：

```bash
# 使用 ARMv8-A 64位
TARGET_ARCH="arm64"
QT_TARGET_PLATFORM="linux-aarch64-gnu-g++"

# 更新工具链
# 在环境变量中设置
CROSS_COMPILE=aarch64-linux-gnu-
```

### 禁用某些第三方库

修改 `config/qt/third_party.conf`：

```bash
# 禁用 FFmpeg
FFMPEG_ENABLED=false

# 禁用 PulseAudio
PULSEAUDIO_ENABLED=false

# 修改库列表
THIRD_PARTY_LIBS="tslib openssl"
```

### 添加编译优化

修改 `config/qt/target.conf`：

```bash
TARGET_CMAKE_EXTRA="\
  -DCMAKE_CXX_FLAGS=-O3 -march=armv7-a -mtune=cortex-a9 \
  -DFEATURE_optimize_size=ON \
"
```

### 自定义字体

修改 `config/qt/fonts.conf`（如果存在）或直接调用字体安装脚本：

```bash
# 编辑字体配置
vim scripts/third_party_install/config/qt/fonts.conf

# 手动安装字体
ROOTFS_DIR=rootfs/nfs ./scripts/third_party_install/install_fonts.sh
```

## 相关文档

- Qt6 编译教程 - Qt 交叉编译原理
- Rootfs 概述 - 根文件系统介绍
- install_fonts.sh - 字体安装脚本
- [Qt6 官方文档](https://doc.qt.io/qt-6/embedded-linux.html) - Qt 嵌入式 Linux 指南
- [qt-compile-pipeline](https://github.com/your-org/qt-compile-pipeline) - 编译管道项目

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| 2026-03-19 | 1.0 | 初始完整版本 |
