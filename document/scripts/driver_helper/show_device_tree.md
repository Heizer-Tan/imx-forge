# show_device_tree.sh - 设备树查看脚本

## 概述

`show_device_tree.sh` 是 IMX Forge 项目中的设备树可视化工具，用于美化显示设备树文件的内容。支持 DTB 和 DTS 格式，提供树形结构展示、详细内容显示和节点搜索功能。

## 功能特性

- ✅ 支持 DTB 和 DTS 文件格式
- ✅ 美化的树形结构显示
- ✅ 高亮显示节点和属性
- ✅ 显示完整 DTS 内容
- ✅ 节点和属性搜索功能
- ✅ 统计信息展示
- ✅ 自动检测文件格式

## 语法

```bash
./scripts/driver_helper/show_device_tree.sh <设备树文件> [选项]
```

## 参数说明

### 位置参数

| 参数 | 说明 | 必需 |
|------|------|------|
| 设备树文件 | .dtb 或 .dts 文件路径 | 是 |

### 选项参数

| 选项 | 说明 | 示例 |
|------|------|------|
| `--all, -a` | 显示完整 DTS 内容 | `--all` |
| `--search, -s` | 搜索节点或属性 | `--search "compatible"` |
| `--detailed, -d` | 显示详细信息（统计、节点列表） | `--detailed` |
| `--help, -h` | 显示帮助信息 | `--help` |

## 可视化选项

### 1. 树形结构显示（默认）

显示设备树的层次结构，使用树形符号（├──、│）表示节点关系。

**特点**：
- 清晰的层次结构
- 重要属性高亮显示
- compatible 和 status 属性特殊标记
- 节点深度可视化

**示例**：
```bash
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb
```

输出示例：
```
🌳 设备树节点结构
═════════════════════════════════════════════════════

📁 文件: out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb
📏 大小: 1.2K

🌲 节点树结构

│  ├──root
│  │   ├──#address-cells
│  │   ├──#size-cells
│  │   ├──compatible
│  │   │   ✦ compatible = "fsl,imx6ull-14x14-evk"
│  │   ├──model
│  │   │   ✦ model = "WT-IMX6ULL-AES-Board"
│  │   ├──cpus
│  │   │   ├──cpu@0
│  │   │   │   ├──compatible
│  │   │   │   │   ✦ compatible = "arm,cortex-a7"
│  │   │   │   ├──operating-points
│  │   │   │   └──status
│  │   │   │       ✦ status = "okay"
│  │   └──example-device@40050000
│  │       ├──compatible
│  │       │   ✦ compatible = "vendor,example-driver"
│  │       ├──reg
│  │       ├──interrupts
│  │       └──status
│  │           ✦ status = "okay"

═════════════════════════════════════════════════════
```

### 2. 完整内容显示

使用 `--all` 选项显示完整的 DTS 源码内容。

**特点**：
- 显示反编译后的完整 DTS
- 保留所有格式和注释
- 适合深度分析

**示例**：
```bash
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --all
```

输出示例：
```
🌳 设备树节点结构
═════════════════════════════════════════════════════

📁 文件: out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb
📏 大小: 1.2K

🌲 节点树结构

│  ├──root
│  │   ├──compatible
│  │   │   ✦ compatible = "fsl,imx6ull"
│  │   └──example-device@40050000
│  │       ├──compatible
│  │       │   ✦ compatible = "vendor,example-driver"
│  │       └──status
│  │           ✦ status = "okay"

═════════════════════════════════════════════════════

📄 完整DTS内容

/dts-v1/;
/ {
    #address-cells = <0x01>;
    #size-cells = <0x01>;
    compatible = "fsl,imx6ull-14x14-evk";
    model = "WT-IMX6ULL-AES-Board";
    interrupt-parent = <0x01>;

    cpus {
        #address-cells = <0x01>;
        #size-cells = <0x00>;

        cpu@0 {
            compatible = "arm,cortex-a7";
            device_type = "cpu";
            reg = <0x00>;
            operating-points = <0x3d 0xf4240 0x2d 0x989680>;
            clock-latency = <0x3d080>;
            clocks = <0x02 0x83>;
            clock-names = "cpu";
        };
    };

    example-device@40050000 {
        compatible = "vendor,example-driver";
        reg = <0x40050000 0x1000>;
        interrupts = <0x00 0x32 0x04>;
        status = "okay";
    };
};
```

### 3. 详细信息显示

使用 `--detailed` 选项显示统计信息和详细列表。

**特点**：
- 节点数量统计
- 属性数量统计
- 所有节点列表
- 所有 compatible 属性列表

**示例**：
```bash
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --detailed
```

输出示例：
```
🔍 设备树详细信息
═════════════════════════════════════════════════════

📊 统计信息:
  节点数量: 15
  属性数量: 42
  Compatible属性: 8

🌲 所有节点:
  - root
  - cpus
  - cpu@0
  - example-device@40050000
  - gpio@50000000
  - uart@2020000
  - i2c@21a0000
  ...

🔗 Compatible属性:
  - fsl,imx6ull-14x14-evk
  - arm,cortex-a7
  - vendor,example-driver
  - fsl,imx6ull-gpio
  - fsl,imx6ull-uart
  - fsl,imx6ull-i2c
  ...
```

### 4. 搜索功能

使用 `--search` 选项搜索特定的节点或属性。

**特点**：
- 不区分大小写搜索
- 显示匹配的行号和内容
- 限制结果显示数量（最多20行）

**示例**：
```bash
# 搜索 compatible 属性
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --search "compatible"

# 搜索特定节点
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --search "gpio"

# �搜索 status 属性
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --search "status"
```

输出示例：
```
🔍 搜索: compatible
═════════════════════════════════════════════════════

行 12:     compatible = "fsl,imx6ull-14x14-evk";
行 45:         compatible = "arm,cortex-a7";
行 78:         compatible = "vendor,example-driver";
行 89:         compatible = "fsl,imx6ull-gpio";
行 102:        compatible = "fsl,imx6ull-uart";
```

### 5. 组合选项

可以组合多个选项以获得更多信息。

**示例**：
```bash
# 显示详细信息 + 搜索
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --detailed --search "example"

# 显示完整内容 + 详细信息
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb --all --detailed
```

## 使用示例

### 1. 查看构建的设备树

```bash
# 查看构建后的设备树
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb
```

### 2. 查看源码中的设备树

```bash
# 查看 .dts 源文件
./scripts/driver_helper/show_device_tree.sh driver/device_tree/alpha-board/example-driver/imx6ull-aes-example-driver.dts
```

### 3. 部署前预览

```bash
# 构建驱动
./scripts/driver_helper/build_driver.sh example-driver

# 预览设备树内容
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb

# 确认无误后部署
./scripts/driver_helper/deploy_driver.sh out/driver_artifacts/example-driver/alpha-board
```

### 4. 调试设备树问题

```bash
# 搜索特定节点
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --search "gpio"

# 查看详细信息
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --detailed

# 查看完整内容
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all
```

## 高亮显示说明

脚本使用颜色高亮显示不同类型的信息：

| 颜色 | 用途 | 示例 |
|------|------|------|
| 🟦 蓝色 | 树形结构符号 | `│  ├──` |
| 🟩 绿色 | 节点名称 | `example-device@40050000` |
| 🟦 青色 | 属性名称 | `compatible`、`status` |
| 🟨 黄色 | 属性值 | `"okay"`、`"disabled"` |
| 🟪 紫色 | 属性标记 | `✦` |

## 常见问题

### 1. dtc 工具未安装

**错误信息**：
```
❌ 错误: dtc工具不可用
请安装设备树编译器: sudo apt-get install device-tree-compiler
```

**解决方案**：
```bash
# 安装设备树编译器
sudo apt-get install device-tree-compiler

# 验证安装
dtc --version
```

### 2. 文件格式不支持

**错误信息**：
```
❌ 错误: 不支持的文件格式
```

**解决方案**：
```bash
# 确保文件是 .dtb 或 .dts 格式
ls -la out/driver_artifacts/example-driver/alpha-board/

# 只支持这两种格式
# .dtb - 编译后的二进制设备树
# .dts - 设备树源码文件
```

### 3. 文件不存在

**错误信息**：
```
❌ 错误: 文件不存在: example.dtb
```

**解决方案**：
```bash
# 检查文件路径
ls -la out/driver_artifacts/example-driver/alpha-board/

# 使用绝对路径或相对路径
./scripts/driver_helper/show_device_tree.sh /absolute/path/to/file.dtb
```

### 4. 设备树文件损坏

**错误信息**：
```
❌ 错误: 无法读取设备树文件
```

**解决方案**：
```bash
# 检查文件大小和权限
ls -lh out/driver_artifacts/example-driver/alpha-board/*.dtb

# 尝试使用 dtc 直接检查
dtc -I dtb -O dts out/driver_artifacts/example-driver/alpha-board/*.dtb

# 重新构建设备树
./scripts/driver_helper/build_driver.sh example-driver
```

## 高级用法

### 1. 批量查看多个设备树

```bash
# 查看所有构建的设备树
for dtb in out/driver_artifacts/*/*/*.dtb; do
    echo "查看设备树: $dtb"
    ./scripts/driver_helper/show_device_tree.sh "$dtb"
    echo "---"
done
```

### 2. 比较两个设备树

```bash
# 保存设备树内容到文件
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/driver1/alpha-board/*.dtb --all > dtb1.txt
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/driver2/alpha-board/*.dtb --all > dtb2.txt

# 比较差异
diff dtb1.txt dtb2.txt
```

### 3. 提取特定信息

```bash
# 提取所有 compatible 属性
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --search "compatible" | awk -F'"' '{print $2}'

# 统计节点数量
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --detailed | grep "节点数量"
```

### 4. 集成到文档

```bash
# 生成设备树文档
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all > device_tree_documentation.txt

# 转换为 Markdown
echo '## 设备树结构\n```' > device_tree.md
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all >> device_tree.md
echo '```' >> device_tree.md
```

## 与其他脚本的配合

### 1. 构建后查看

```bash
# 构建驱动
./scripts/driver_helper/build_driver.sh example-driver

# 查看设备树
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb
```

### 2. 审查前查看

```bash
# 查看设备树内容
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all

# 确认无误后审查
./scripts/driver_helper/review_driver.sh example-driver
```

### 3. 部署前验证

```bash
# 查看设备树
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb

# 搜索关键节点
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --search "compatible"

# 确认无误后部署
./scripts/driver_helper/deploy_driver.sh out/driver_artifacts/example-driver/alpha-board
```

## 最佳实践

### 1. 开发阶段

```bash
# 修改设备树源码后
vim driver/device_tree/alpha-board/example-driver/imx6ull-aes-example-driver.dts

# 重新构建
./scripts/driver_helper/build_driver.sh example-driver

# 立即查看结果
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all
```

### 2. 调试阶段

```bash
# 搜索特定节点
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --search "problematic-node"

# 查看详细信息
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --detailed
```

### 3. 文档编写

```bash
# 生成设备树文档
./scripts/driver_helper/show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/*.dtb --all > docs/device_tree_reference.txt
```

## 注意事项

1. **dtc 工具**：必须安装设备树编译器才能使用
2. **文件格式**：只支持 .dtb 和 .dts 格式
3. **颜色显示**：某些终端可能不支持颜色，但内容仍会正确显示
4. **大文件**：大型设备树文件可能需要较长处理时间
5. **搜索限制**：搜索结果最多显示 20 行匹配
6. **路径问题**：使用相对路径时确保从项目根目录执行

## 相关文档

- [build_driver.md](./build_driver.md) - 驱动构建脚本
- [deploy_driver.md](./deploy_driver.md) - 驱动部署脚本
- [review_driver.md](./review_driver.md) - 驱动审查脚本
- [configuration.md](./configuration.md) - 配置文件说明
- [driver_buildlib.md](../lib/driver_buildlib.md) - 构建库说明
