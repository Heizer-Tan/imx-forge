# install_fonts.sh - 字体下载和安装脚本详解

## 脚本概述

`install_fonts.sh` 是 IMX-Forge 项目中用于下载并安装字体到根文件系统的脚本。它为嵌入式 Qt 应用程序提供完整的多语言字体支持，包括拉丁字符、中日韩字符和 Emoji 表情符号。

### 核心功能

- **自动下载字体**：从官方源下载 DejaVu、Noto CJK、Noto Emoji 字体
- **增量安装**：检测已安装字体，跳过重复下载
- **断点续传**：支持下载中断后继续
- **文件完整性验证**：ZIP 文件解压测试
- **强制重装**：`--force` 参数重新安装所有字体
- **智能查找**：在解压目录中自动定位字体文件

### 为什么需要这个脚本

嵌入式 Linux 系统通常不包含完整的字体支持。Qt 应用程序要正确显示多语言文本，需要：

```
┌─────────────────────────────────────────────────────────────────┐
│  问题场景                                                         │
├─────────────────────────────────────────────────────────────────┤
│  1. Qt 应用显示中文 → 显示为方块 ▢▢▢                              │
│  2. 使用等宽字体 → 找不到合适的终端字体                           │
│  3. 显示 Emoji → 显示为空白或方框                                 │
│  4. 中英混排 → 字体切换不正确                                     │
└─────────────────────────────────────────────────────────────────┘
```

这个脚本通过安装三种互补的字体解决上述问题：

| 字体 | 用途 | 字符集 |
|------|------|--------|
| DejaVu Sans | UI 默认字体 | 拉丁字母、希腊字母、西里尔字母 |
| DejaVu Sans Mono | 终端等宽字体 | 同上，等宽 |
| Noto Sans CJK | 中日韩文字 | 汉字、假名、谚文 |
| Noto Color Emoji | Emoji | Unicode Emoji |

### 设计理念

脚本遵循"自动化但可配置"的原则：

1. **默认智能**：自动检测已安装字体，避免重复下载
2. **网络容错**：支持断点续传和失败重试
3. **用户控制**：`--force` 参数强制重新安装
4. **配置分离**：字体配置在 `fonts.conf` 中独立管理
5. **无 fontconfig 依赖**：直接拷贝到顶层目录，适配嵌入式环境

### 依赖关系

```
install_fonts.sh
    ├─ scripts/lib/logging.sh (日志工具库)
    ├─ scripts/third_party_install/config/qt/fonts.conf (字体配置)
    ├─ curl (下载工具)
    ├─ tar/unzip (解压工具)
    └─ ROOTFS_DIR (根文件系统目录)
```

调用关系：

```
install_qt_with_compile.sh
    └─ install_fonts.sh (被调用)
```

## 字体说明

### DejaVu Fonts 2.37

**用途**：拉丁字符 + 等宽字体

**特点**：

- 基于 Bitstream Vera 字体扩展
- 覆盖拉丁字母、希腊字母、西里尔字母
- 提供等宽版本（Mono）用于终端
- 文件较小（~5.2 MB）

**包含文件**：

| 文件 | 描述 | 用途 |
|------|------|------|
| `DejaVuSans.ttf` | 无衬线常规 | UI 默认字体 |
| `DejaVuSans-Bold.ttf` | 无衬线粗体 | 强调文本 |
| `DejaVuSans-Oblique.ttf` | 无衬线斜体 | 斜体文本 |
| `DejaVuSans-BoldOblique.ttf` | 无衬线粗斜体 | 强调斜体 |
| `DejaVuSansMono.ttf` | 等宽常规 | 终端、代码 |
| `DejaVuSansMono-Bold.ttf` | 等宽粗体 | 终端强调 |

**许可**：Bitstream Vera Font License（自由使用）

### Noto Sans CJK 2.004

**用途**：中日韩字符显示

**特点**：

- Google 和 Adobe 联合开发
- 覆盖简体中文、繁体中文、日文、韩文
- 使用 Super OTC 格式，单文件包含所有语言
- 文件较大（~18 MB）

**包含内容**：

| 文件 | 描述 | 覆盖 |
|------|------|------|
| `NotoSansCJK-OTC.ttc` | Super OTC | 所有 CJK 语言和字重 |

**什么是 TTC/OTC**：

TTC（TrueType Collection）是包含多个字体文件的容器：

```
NotoSansCJK-OTC.ttc (单个文件)
├── NotoSansCJK-Regular.ttc   (常规字重)
│   ├── 简体中文
│   ├── 繁体中文
│   ├── 日文
│   └── 韩文
├── NotoSansCJK-Bold.ttc      (粗体)
│   └── ...
└── ... (其他字重)
```

**许可**：SIL Open Font License 1.1（自由使用）

### Noto Color Emoji

**用途**：Emoji 字符显示

**特点**：

- Google 官方 Emoji 字体
- 彩色 Emoji（需要系统支持）
- 单个 TTF 文件
- 文件大小（~9 MB）

**内容**：Unicode 标准 Emoji 字符

**许可**：SIL Open Font License 1.1

## 配置文件

脚本加载两个配置文件：

### 1. qt.conf

```bash
source "${CONFIG_TARGET_DIR}/qt.conf"
```

提供 `WORK_DIR` 基础目录。

### 2. fonts.conf

字体专用配置文件位置：

```
scripts/third_party_install/config/qt/fonts.conf
```

**配置项**：

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `FONTS_ENABLED` | 字体安装开关 | `true` |
| `FONTS_TARGET_DIR` | ROOTFS 中目标目录 | `/usr/share/fonts` |
| `FONTS_DL_DIR` | 临时下载目录 | `${WORK_DIR}/fonts-downloads` |
| `FONTS_CACHE_DIR` | 解压缓存目录 | `${WORK_DIR}/fonts-cache` |

**字体源配置**：

| 变量 | 说明 |
|------|------|
| `DEJAVU_URL` | DejaVu 下载地址 |
| `DEJAVU_FILE` | DejaVu 文件名 |
| `DEJAVU_KEY_FILES` | DejaVu 关键文件（检测用） |
| `NOTO_CJK_URL` | Noto CJK 下载地址 |
| `NOTO_CJK_FILE` | Noto CJK 文件名 |
| `NOTO_CJK_KEY_FILES` | Noto CJK 关键文件 |
| `NOTO_EMOJI_URL` | Noto Emoji 下载地址 |
| `NOTO_EMOJI_FILE` | Noto Emoji 文件名 |
| `NOTO_EMOJI_KEY_FILES` | Noto Emoji 关键文件 |

## 使用方法

### 基本用法

```bash
# 使用默认 ROOTFS 路径
./scripts/third_party_install/install_fonts.sh

# 指定 ROOTFS 路径
ROOTFS_DIR=out/rootfs ./scripts/third_party_install/install_fonts.sh

# 强制重新安装
./scripts/third_party_install/install_fonts.sh --force
```

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--force` | 强制重新安装，即使字体已存在 | 禁用 |
| `--help`, `-h` | 显示帮助信息 | - |

### 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| `ROOTFS_DIR` | 根文件系统目录路径 | `rootfs/nfs` |
| `FONTS_ENABLED` | 字体安装开关 | `true` |
| `WORK_DIR` | 工作目录（用于计算下载路径） | 自动检测 |

### 输出格式

```
[INFO] === 字体安装脚本 ===
[INFO] 项目根目录: /home/user/imx-forge
[INFO] ROOTFS 目录: rootfs/nfs
[INFO]
[INFO] 将要安装的字体:
[INFO]   1. DejaVu Fonts 2.37 (拉丁字符 + 等宽字体)
[INFO]   2. Noto Sans CJK 2.004 (中日韩字符)
[INFO]   3. Noto Color Emoji (Emoji 支持)
[INFO]
[INFO] ----------------------------------------
[INFO] DejaVu Fonts 2.37
[INFO] ----------------------------------------
[INFO]   正在下载: dejavu-fonts-ttf-2.37.tar.bz2
[INFO]   来源: https://sourceforge.net/...
[INFO]   ✓ 下载完成: 5.2MiB
[INFO]   正在解压...
[INFO]   正在安装字体文件...
[INFO]   ✓ 已安装 6 个 DejaVu 字体文件到 rootfs/nfs/usr/share/fonts
[INFO]
[INFO] ----------------------------------------
[INFO] Noto Sans CJK 2.004
[INFO] ----------------------------------------
[INFO]   正在下载: 03_NotoSansCJK-OTC.zip
[INFO]   来源: https://github.com/...
[INFO]   ✓ 下载完成: 18MiB
[INFO]   正在解压...
[INFO]   正在安装字体文件...
[INFO]     ✓ NotoSansCJK-OTC.ttc (17MiB)
[INFO]   ✓ 已安装 1 个 Noto CJK 字体文件到 rootfs/nfs/usr/share/fonts
[INFO]
[INFO] ----------------------------------------
[INFO] Noto Color Emoji v2.042
[INFO] ----------------------------------------
[INFO]   正在下载: NotoColorEmoji.ttf
[INFO]   来源: https://github.com/...
[INFO]   ✓ 下载完成: 9MiB
[INFO]   正在安装字体文件...
[INFO]   ✓ 已安装 Noto Color Emoji 到 rootfs/nfs/usr/share/fonts
[INFO]
[INFO] === 字体安装摘要 ===
[INFO]
[INFO] 已安装字体:
[INFO]   DejaVu:     6 个文件
[INFO]   Noto CJK:   1 个文件
[INFO]   Noto Emoji: 1 个文件
[INFO]
[INFO] 总大小: ~32 MB
[INFO]
[INFO] Qt 字体环境变量配置:
[INFO]   export QT_QPA_FONTDIR=/usr/share/fonts
[INFO]   export LANG=C.UTF-8
[INFO]   export LC_ALL=C.UTF-8
[INFO]
[INFO] ✓ 字体安装完成
```

## 执行流程

### 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  1. 初始化阶段                                               │
│     - 设置脚本路径                                           │
│     - 加载日志库                                             │
│     - 获取项目根目录                                         │
│     - 加载配置文件 (qt.conf, fonts.conf)                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  2. 预检查阶段                                               │
│     - 检查 ROOTFS_DIR 是否存在                               │
│     - 检查 FONTS_ENABLED 开关                                │
│     - 创建下载和缓存目录                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  3. DejaVu 字体安装                                          │
│     - check_fonts_installed() (检测是否已安装)               │
│     - download_file() (下载 tar.bz2)                         │
│     - tar -xjf (解压)                                        │
│     - find + cp (查找并拷贝字体文件)                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  4. Noto CJK 字体安装                                        │
│     - check_fonts_installed()                               │
│     - download_file() (下载 ZIP)                             │
│     - unzip -q (解压)                                        │
│     - 查找 TTC 文件并拷贝                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  5. Noto Emoji 字体安装                                      │
│     - check_fonts_installed()                               │
│     - download_file() (下载 TTF)                             │
│     - cp (直接拷贝 TTF 文件)                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  6. 摘要报告阶段                                             │
│     - 统计已安装字体数量                                      │
│     - 计算总大小                                             │
│     - 显示 Qt 环境变量配置                                   │
└─────────────────────────────────────────────────────────────┘
```

### 函数详解

#### check_fonts_installed()

**作用**：检测指定字体是否已安装。

**参数**：

1. `$1`：字体名称（用于日志）
2. `$2`：目标目录
3. `$3`：关键文件数组（引用传递）

**实现**：

```bash
check_fonts_installed() {
    local font_name="$1"
    local target_dir="$2"
    local -n key_files_ref="$3"  # 名称引用
    local missing_count=0

    for font_file in "${key_files_ref[@]}"; do
        local font_path="${target_dir}/${font_file}"
        if [[ ! -f "${font_path}" ]]; then
            ((missing_count++)) || true
            log_debug "  缺少: ${font_file}"
        fi
    done

    if [[ ${missing_count} -eq 0 ]]; then
        return 0  # 所有字体都存在
    else
        return 1  # 有字体缺失
    fi
}
```

**关键文件数组示例**：

```bash
DEJAVU_KEY_FILES=(
    "DejaVuSans.ttf"
    "DejaVuSans-Bold.ttf"
    "DejaVuSansMono.ttf"
)
```

**设计说明**：

使用关键文件数组而不是检查所有文件，原因：

1. **更快**：只检查几个代表性文件
2. **灵活**：允许部分文件缺失（比如粗体）
3. **可配置**：每个字体可以定义自己的关键文件列表

#### download_file()

**作用**：下载文件，支持断点续传和完整性验证。

**参数**：

1. `$1`：下载 URL
2. `$2`：目标文件路径

**实现特点**：

```bash
# 1. 检查文件是否已存在
if [[ -f "${dest}" ]]; then
    # 对于 ZIP 文件，验证完整性
    if [[ "${filename}" == *.zip ]]; then
        if unzip -t "${dest}" >/dev/null 2>&1; then
            return 0  # 文件完整，跳过下载
        else
            rm -f "${dest}"  # 文件损坏，删除重新下载
        fi
    fi
fi

# 2. 使用 curl 下载（支持断点续传）
curl -fL -C - -o "${dest}" "${url}"

# 3. 断点续传失败时重新下载
if [[ $? -ne 0 ]]; then
    rm -f "${dest}"
    curl -fL -o "${dest}" "${url}"
fi
```

**参数解释**：

| 参数 | 作用 |
|------|------|
| `-f` | HTTP 错误时失败（不显示服务器错误页面） |
| `-L` | 跟随重定向 |
| `-C -` | 断点续传（自动检测已下载部分） |
| `-o` | 输出文件 |

**为什么先尝试断点续传**：

- 首次下载：`-C -` 无效，自动从头开始
- 断线重连：继续下载剩余部分
- 服务器不支持：删除文件后重新下载

#### install_dejavu()

**作用**：安装 DejaVu 字体。

**流程**：

```bash
# 1. 检查是否已安装
check_fonts_installed "DejaVu" "${target_dir}" DEJAVU_KEY_FILES
if [[ $? -eq 0 && "${FORCE_REINSTALL}" == false ]]; then
    return 0  # 已安装，跳过
fi

# 2. 下载 tar.bz2
download_file "${DEJAVU_URL}" "${archive}"

# 3. 解压到缓存目录
tar -xjf "${archive}" -C "${cache_dir}"

# 4. 查找并拷贝字体文件
for font_file in "${DEJAVU_KEY_FILES[@]}"; do
    found="$(find "${cache_dir}" -name "${font_file}" -type f | head -n1)"
    if [[ -n "${found}" ]]; then
        cp -f "${found}" "${target_dir}/"
    fi
done
```

**为什么使用 find**：

DejaVu tar.bz2 的目录结构：

```
dejavu-fonts-ttf-2.37/
├── DejaVuSans.ttf          # 我们需要的
├── LICENSE                 # 不需要
├── README                  # 不需要
└── ... (其他不需要的文件)
```

使用 `find` 可以在复杂目录结构中精确定位需要的字体文件。

#### install_noto_cjk()

**作用**：安装 Noto CJK 字体。

**流程**：

```bash
# 1. 检查是否已安装
check_fonts_installed "Noto CJK" "${target_dir}" NOTO_CJK_KEY_FILES

# 2. 下载 ZIP
download_file "${NOTO_CJK_URL}" "${archive}"

# 3. 解压
unzip -q -o "${archive}" -d "${cache_dir}"

# 4. 查找 TTC 文件
otc_file="$(find "${cache_dir}" -name "*.ttc" -type f | head -n1)"
if [[ -n "${otc_file}" ]]; then
    cp -f "${otc_file}" "${target_dir}/NotoSansCJK-OTC.ttc"
fi

# 5. 备用：查找 OTF 文件（如果没有 TTC）
if [[ ${copied} -eq 0 ]]; then
    for otf_file in "${otf_files[@]}"; do
        found="$(find "${cache_dir}" -name "${otf_file}")"
        cp -f "${found}" "${target_dir}/"
    done
fi
```

**为什么优先 TTC**：

| 格式 | 优点 | 缺点 |
|------|------|------|
| TTC (Super OTC) | 单文件包含所有语言和字重 | 文件较大 |
| OTF | 单个语言文件 | 需要多个文件 |

TTC 格式更适合嵌入式场景，因为只需要一个文件即可支持所有 CJK 语言。

#### install_noto_emoji()

**作用**：安装 Noto Emoji 字体。

**流程**：

```bash
# 1. 检查是否已安装
check_fonts_installed "Noto Emoji" "${target_dir}" NOTO_EMOJI_KEY_FILES

# 2. 下载 TTF 文件（直接是字体文件，不需要解压）
download_file "${NOTO_EMOJI_URL}" "${dest}"

# 3. 直接拷贝到目标目录
cp -f "${dest}" "${target_dir}/"
```

**为什么不需要解压**：

Noto Color Emoji 直接以 TTF 格式提供，下载后即可使用。

## 目录结构

### 下载和缓存目录

```
WORK_DIR/
├── fonts-downloads/         # 原始下载文件
│   ├── dejavu-fonts-ttf-2.37.tar.bz2
│   ├── 03_NotoSansCJK-OTC.zip
│   └── NotoColorEmoji.ttf
└── fonts-cache/             # 解压后的文件
    ├── dejavu/
    │   └── dejavu-fonts-ttf-2.37/
    │       ├── DejaVuSans.ttf
    │       ├── DejaVuSans-Bold.ttf
    │       └── ...
    ├── noto-cjk/
    │   └── ... (解压的 ZIP 内容)
    └── emoji/
        └── NotoColorEmoji.ttf
```

### ROOTFS 目标结构

```
rootfs/nfs/usr/share/fonts/
├── DejaVuSans.ttf           # Latin UI 字体
├── DejaVuSans-Bold.ttf
├── DejaVuSans-Oblique.ttf
├── DejaVuSans-BoldOblique.ttf
├── DejaVuSansMono.ttf       # 终端等宽字体
├── DejaVuSansMono-Bold.ttf
├── NotoSansCJK-OTC.ttc      # CJK 字符
└── NotoColorEmoji.ttf       # Emoji
```

**注意**：所有字体文件都直接放在 `/usr/share/fonts/` 顶层目录，而不是子目录。

**为什么不用子目录**：

Qt 的 QFontDatabase 在没有 fontconfig 的嵌入式环境下，可能不递归扫描子目录。直接放在顶层确保 Qt 能找到所有字体。

## Qt 字体环境配置

字体安装后，需要配置 Qt 使用这些字体。

### 环境变量

```bash
# 告诉 Qt 在哪里查找字体
export QT_QPA_FONTDIR=/usr/share/fonts

# 设置 UTF-8 语言环境（确保中文正确显示）
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

### 配置位置

**方法 1：系统级配置**

```bash
# /etc/environment
QT_QPA_FONTDIR=/usr/share/fonts
LANG=C.UTF-8
LC_ALL=C.UTF-8
```

**方法 2：启动脚本**

```bash
# /etc/profile.d/qt-fonts.sh
export QT_QPA_FONTDIR=/usr/share/fonts
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
```

**方法 3：应用启动时**

```bash
#!/bin/bash
# 启动 Qt 应用前
export QT_QPA_FONTDIR=/usr/share/fonts
export LANG=C.UTF-8
./my-qt-app
```

### C++ 代码中使用

```cpp
#include <QApplication>
#include <QFont>
#include <QLabel>

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    // 设置默认字体（支持中文）
    QFont font("Noto Sans CJK SC", 12);
    app.setFont(font);

    // 中英混排
    QLabel *label = new QLabel("Hello 世界 🎉");
    label->setFont(QFont("Noto Sans CJK SC", 20));
    label->show();

    return app.exec();
}
```

**字体 fallback**：

Qt 会自动根据字符选择合适的字体：

| 字符 | 使用的字体 |
|------|-----------|
| A-Z, a-z | DejaVu Sans |
| 你好世界 | Noto Sans CJK |
| 🎉 | Noto Color Emoji |
| 代码 | DejaVu Sans Mono |

## 故障排除

### 常见错误

#### 错误 1：ROOTFS 目录不存在

```
[ERROR] ROOTFS 目录不存在: /path/to/rootfs
[ERROR] 请先创建 ROOTFS
```

**解决方法**：

```bash
# 创建 ROOTFS 目录
mkdir -p out/rootfs

# 重新运行
ROOTFS_DIR=out/rootfs ./install_fonts.sh
```

#### 错误 2：字体下载失败

```
[ERROR]   ✗ 下载失败: dejavu-fonts-ttf-2.37.tar.bz2
```

**可能原因**：

1. 网络连接问题
2. SourceForge 镜像不可用

**解决方法**：

```bash
# 手动下载并放到缓存目录
mkdir -p out/.qt-workdir/fonts-downloads
cp ~/Downloads/dejavu-fonts-ttf-2.37.tar.bz2 out/.qt-workdir/fonts-downloads/

# 重新运行脚本
./install_fonts.sh
```

或者修改 `fonts.conf` 中的 URL 使用其他镜像。

#### 错误 3：解压失败

```
[ERROR]   ✗ 解压失败
```

**可能原因**：

1. 下载的文件损坏
2. 缺少解压工具（tar/unzip）

**解决方法**：

```bash
# 检查解压工具
which tar unzip

# 安装缺失工具
sudo apt install tar unzip

# 删除损坏文件后重新下载
rm out/.qt-workdir/fonts-downloads/*
./install_fonts.sh
```

#### 错误 4：中文显示为方块

**原因**：

1. Qt 找不到 Noto CJK 字体
2. 没有设置 `QT_QPA_FONTDIR`
3. 语言环境不是 UTF-8

**解决方法**：

```bash
# 检查字体文件
ls -l rootfs/nfs/usr/share/fonts/Noto*

# 设置环境变量
export QT_QPA_FONTDIR=/usr/share/fonts
export LANG=C.UTF-8

# 运行应用
./my-qt-app
```

#### 错误 5：Emoji 显示为方块

**原因**：

1. Noto Color Emoji 未安装
2. 系统不支持彩色 Emoji（需要正确的 Qt 平台插件）

**解决方法**：

```bash
# 检查 Emoji 字体
ls -l rootfs/nfs/usr/share/fonts/NotoColorEmoji.ttf

# 在代码中设置 Emoji 字体
label->setFont(QFont("Noto Color Emoji"));
```

### 调试技巧

#### 查看已安装字体

```bash
# 列出所有字体文件
ls -lh rootfs/nfs/usr/share/fonts/

# 统计字体数量
find rootfs/nfs/usr/share/fonts/ -name "*.ttf" -o -name "*.ttc" | wc -l
```

#### 测试 Qt 字体加载

```cpp
// 在 Qt 应用中打印所有可用字体
qDebug() << "Available fonts:";
foreach (const QString &family, QFontDatabase::families()) {
    qDebug() << "  -" << family;
}

// 检查特定字体
bool hasNoto = QFontDatabase::supportsFontFamilies("Noto Sans CJK SC");
qDebug() << "Has Noto Sans CJK SC:" << hasNoto;
```

#### 验证环境变量

```bash
# 在目标板上运行
echo $QT_QPA_FONTDIR
echo $LANG
echo $LC_ALL

# 应该输出：
# /usr/share/fonts
# C.UTF-8
# C.UTF-8
```

## 设计决策说明

### 为什么直接拷贝到顶层目录

传统 Linux 字体目录结构：

```
/usr/share/fonts/
├── dejavu/
│   └── DejaVuSans.ttf
├── noto/
│   └── NotoSansCJK.ttc
└── emoji/
    └── NotoColorEmoji.ttf
```

本脚本使用扁平结构：

```
/usr/share/fonts/
├── DejaVuSans.ttf
├── NotoSansCJK.ttc
└── NotoColorEmoji.ttf
```

**原因**：

1. **Qt 限制**：没有 fontconfig 的 Qt 可能不递归扫描
2. **简单**：配置更简单，只需设置 `QT_QPA_FONTDIR=/usr/share/fonts`
3. **兼容性**：确保所有字体都能被发现

### 为什么用 curl 而不是 wget

脚本使用 `curl` 而不是 `wget`：

| 特性 | curl | wget |
|------|------|------|
| 断点续传 | `-C -` 自动 | `-c` 需要指定 |
| HTTPS | 默认支持 | 默认支持 |
| 跟随重定向 | `-L` | 自动 |
| 错误处理 | `-f` 失败 | 默认 |

选择 curl 主要因为其断点续传功能更可靠。

### 为什么检查关键文件而不是所有文件

每个字体定义关键文件数组：

```bash
DEJAVU_KEY_FILES=(
    "DejaVuSans.ttf"
    "DejaVuSans-Bold.ttf"
    "DejaVuSansMono.ttf"
)
```

而不是检查所有 6 个 DejaVu 文件。

**原因**：

1. **更快**：只检查几个文件
2. **足够**：几个关键文件存在说明安装成功
3. **灵活**：允许部分变体缺失（比如 Oblique）

### 为什么使用 WORK_DIR 而不是 /tmp

下载和缓存使用 `WORK_DIR/fonts-downloads` 而不是 `/tmp`：

**原因**：

1. **持久化**：`/tmp` 可能被清理
2. **共享**：多个构建可以共享缓存
3. **可控**：用户知道在哪里找文件

## 扩展和定制

### 添加新字体

在 `fonts.conf` 中添加新字体配置：

```bash
# ------------------------------------------------------------------------------
# Fira Code (程序员字体)
# ------------------------------------------------------------------------------
FIRA_CODE_VERSION="6.2"
FIRA_CODE_URL="https://github.com/tonsky/FiraCode/releases/download/${FIRA_CODE_VERSION}/FiraCode-v${FIRA_CODE_VERSION}.zip"
FIRA_CODE_FILE="FiraCode.zip"
FIRA_CODE_KEY_FILES=(
    "FiraCode-Regular.ttf"
    "FiraCode-Bold.ttf"
)
```

在脚本中添加安装函数：

```bash
install_fira_code() {
    log_info "----------------------------------------"
    log_info "Fira Code ${FIRA_CODE_VERSION}"
    log_info "----------------------------------------"

    local cache_dir="${FONTS_CACHE_DIR}/firacode"
    local target_dir="${ROOTFS_DIR}/usr/share/fonts"

    # 检查、下载、解压、安装...
}
```

### 修改目标目录

如果需要将字体放到子目录：

```bash
# 修改脚本中的 target_dir
local target_dir="${ROOTFS_DIR}/usr/share/fonts/custom"

# 同时修改环境变量
export QT_QPA_FONTDIR=/usr/share/fonts/custom
```

### 使用本地字体源

如果无法访问外网，可以使用本地源：

```bash
# 修改 fonts.conf
DEJAVU_URL="file:///mnt/shared/fonts/dejavu-fonts-ttf-2.37.tar.bz2"
NOTO_CJK_URL="file:///mnt/shared/fonts/03_NotoSansCJK-OTC.zip"
NOTO_EMOJI_URL="file:///mnt/shared/fonts/NotoColorEmoji.ttf"
```

### 禁用特定字体

如果不需要某个字体，可以在 `main()` 函数中注释掉对应的调用：

```bash
main() {
    # ...
    if ! install_dejavu; then
        exit_code=1
    fi

    # if ! install_noto_cjk; then  # 禁用 CJK 字体
    #     exit_code=1
    # fi

    # if ! install_noto_emoji; then  # 禁用 Emoji
    #     exit_code=1
    # fi
}
```

## 相关文档

- [qt_fonts_env.sh](config/qt/qt_fonts_env.sh.md) - Qt 字体环境变量配置脚本
- [install_qt_with_compile.sh](install_qt_with_compile.sh.md) - 调用此脚本的 Qt 编译脚本
- [Qt 字体配置](../../../tutorial/qt/font_configuration.md) - Qt 字体使用教程
