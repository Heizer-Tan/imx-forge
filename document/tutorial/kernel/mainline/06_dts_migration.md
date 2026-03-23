# 设备树迁移：从 BSP DTS 到主线 DTS

## 前言：设备树是硬件描述的核心

说实话，第一次看到设备树（Device Tree）的时候，我是真的有点懵。一堆花括号、尖括号、各种 `@` 符号，不知道在干什么。但当你理解了它的本质，你会发现设备树其实很直观：它就是一种用文本方式描述硬件的方法。

内核通过设备树知道有哪些设备、它们怎么连接、需要什么资源。设备树写错了，驱动就 probe 不了，硬件就工作不了。从 BSP 迁移到主线内核，设备树是最需要修改的部分之一。

这篇文章会详细讲解如何把 BSP 的设备树迁移到主线内核，重点讲解显示系统的 OF graph 写法、sim2 节点的补充方法，以及其他外设的调整。

## 第一步——理解设备树层次结构

设备树文件分为几类：

| 文件类型 | 位置 | 说明 |
|----------|------|------|
| `.dtsi` | `arch/arm/boot/dts/nxp/imx/` | 基础文件，描述 SoC 的通用设备 |
| `.dts` | `arch/arm/boot/dts/nxp/imx/` | 板级文件，描述具体板子的配置 |
| `.dts` (include) | 同上 | 板级文件，包含特定外设配置 |

对于 i.MX6ULL，基础的 SoC 描述在 `imx6ul.dtsi` 和 `imx6ull.dtsi` 里，板级文件需要你自己写（或者从 BSP 移植过来）。

## 第二步——创建板级设备树文件

这个项目的移植补丁创建了两个文件：

- `imx6ull-aes.dts`：主文件，引用 dtsi 和配置
- `imx6ull-aes.dtsi`：外设配置文件

### 主文件：imx6ull-aes.dts

```dts
// SPDX-License-Identifier: (GPL-2.0 OR MIT)
//
// Copyright (C) 2016 Freescale Semiconductor, Inc.

/dts-v1/;

#include "imx6ull.dtsi"
#include "imx6ull-aes.dtsi"

/ {
    model = "Awesome Embedded Studio IMX6ULL (i.mx NXP)";
    compatible = "fsl,imx6ull-14x14-evk", "fsl,imx6ull";
};

&clks {
    assigned-clocks = <&clks IMX6UL_CLK_PLL3_PFD2>,
                      <&clks IMX6UL_CLK_PLL4_AUDIO_DIV>;
    assigned-clock-rates = <320000000>, <786432000>;
};

&csi {
    status = "okay";
};

&ov5640 {
    status = "okay";
};

/delete-node/ &sim2;

&usdhc2 {
    pinctrl-names = "default", "state_100mhz", "state_200mhz";
    pinctrl-0 = <&pinctrl_usdhc2_8bit>;
    pinctrl-1 = <&pinctrl_usdhc2_8bit_100mhz>;
    pinctrl-2 = <&pinctrl_usdhc2_8bit_200mhz>;
    bus-width = <8>;
    non-removable;
    status = "okay";
};
```

这个文件很简单，主要是引用 `.dtsi` 文件和配置一些基本属性。注意 `/delete-node/ &sim2;` 这一行，这是删除基础文件里定义的 sim2 节点，因为我们在 `.dtsi` 里会重新定义。

## 第三步——配置外设（imx6ull-aes.dtsi）

`.dtsi` 文件包含了所有外设的配置。我们先来看几个关键的节点。

### 根节点：chosen 和 memory

```dts
/ {
    chosen {
        stdout-path = &uart1;
    };

    memory@80000000 {
        device_type = "memory";
        reg = <0x80000000 0x20000000>;
    };

    reserved-memory {
        #address-cells = <1>;
        #size-cells = <1>;
        ranges;

        linux,cma {
            compatible = "shared-dma-pool";
            reusable;
            size = <0xa000000>;
            linux,cma-default;
        };
    };
};
```

- `chosen`：指定内核启动的串口
- `memory`：描述内存大小（512MB）
- `reserved-memory`：预留内存给 DMA 使用，CMA 是连续内存分配器

### 背光节点

```dts
backlight_display: backlight-display {
    compatible = "pwm-backlight";
    pwms = <&pwm1 0 5000000 0>;
    brightness-levels = <0 4 8 16 32 64 128 255>;
    default-brightness-level = <6>;
    status = "okay";
};
```

这个节点定义了 LCD 背光的控制方式：
- 使用 PWM1 通道
- PWM 周期 5000000 纳秒（200Hz）
- 亮度级别 0-255

### Panel 节点（重点）

这是主线内核的写法，和 BSP 完全不同：

```dts
panel: panel-dpi {
    compatible = "panel-dpi";
    backlight = <&backlight_display>;

    /* 屏幕物理尺寸，用于计算 DPI */
    width-mm = <154>;
    height-mm = <86>;

    /* 时序参数 */
    panel-timing {
        clock-frequency = <51200000>;
        hactive = <1024>;
        vactive = <600>;
        hfront-porch = <160>;
        hback-porch = <140>;
        hsync-len = <20>;
        vback-porch = <20>;
        vfront-porch = <12>;
        vsync-len = <3>;
        hsync-active = <0>;
        vsync-active = <0>;
        de-active = <1>;
        pixelclk-active = <0>;
    };

    /* OF graph 连接 */
    port {
        panel_in: endpoint {
            remote-endpoint = <&lcdif_out>;
        };
    };
};
```

关键是这个 `port { panel_in: endpoint { remote-endpoint = <&lcdif_out>; }; };` 结构。这就是 OF graph 的写法，它定义了 panel 和 lcdif 之间的连接关系。

### lcdif 节点（重点）

```dts
&lcdif {
    assigned-clocks = <&clks IMX6UL_CLK_LCDIF_PRE_SEL>;
    assigned-clock-parents = <&clks IMX6UL_CLK_PLL5_VIDEO_DIV>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_lcdif_dat &pinctrl_lcdif_ctrl>;
    status = "okay";

    /* 删除基础文件里的 display 属性 */
    /delete-property/ display;

    /* OF graph 连接 */
    port {
        lcdif_out: endpoint {
            remote-endpoint = <&panel_in>;
        };
    };
};
```

这里有两个关键点：

1. `/delete-property/ display;`：删除基础文件 `imx6ul.dtsi` 里遗留的 `display = <&display0>` 属性
2. `port { lcdif_out: endpoint { remote-endpoint = <&panel_in>; }; };`：定义 lcdif 的输出端点，指向 panel 的输入端点

这种 `panel_in` → `lcdif_out` 的双向引用，就是 OF graph 的核心概念。

## 第四步——理解 OF graph

OF graph（Open Firmware Graph）是内核定义的一种用设备树描述图形设备连接的标准。不仅用于显示，还用于摄像头、网络等子系统。

它的结构是这样的：

```
      lcdif (控制器)
         |
      [port]
         |
    [lcdif_out endpoint]
         |
    (remote-endpoint = <&panel_in>)
         |
    [panel_in endpoint]
         |
      [port]
         |
      panel (面板)
```

每个设备都有一个 `port` 节点，`port` 里面有 `endpoint` 节点，`endpoint` 通过 `remote-endpoint` 指向对方的 `endpoint`。这样就形成了一个有向图，内核可以通过这个图找到设备之间的连接关系。

对于显示系统，控制器是"源"（source），panel 是"汇"（sink）。控制器的 `port` 是输出端，panel 的 `port` 是输入端。

## 第五步——添加 sim2 节点

主线内核的 `imx6ul.dtsi` 里缺失 sim2 节点定义，我们需要手动添加。这个项目的移植补丁包含了这处修改：

```dts
/* 在 imx6ul.dtsi 的 AIPS2 总线节点下添加 */
sim2: sim@021b4000 {
    compatible = "fsl,imx6ul-sim";
    reg = <0x021b4000 0x4000>;
    interrupts = <GIC_SPI 113 IRQ_TYPE_LEVEL_HIGH>;
    clocks = <&clks IMX6UL_CLK_SIM2>;
    clock-names = "sim";
    status = "disabled";
};
```

然后在板级设备树里启用它：

```dts
&sim2 {
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_sim2>;
    assigned-clocks = <&clks IMX6UL_CLK_SIM_SEL>;
    assigned-clock-parents = <&clks IMX6UL_CLK_SIM_PODF>;
    assigned-clock-rates = <240000000>;
    pinctrl-assert-gpios = <&gpio4 23 GPIO_ACTIVE_HIGH>;
    port = <1>;
    sven_low_active;
    status = "okay";
};
```

## 第六步——配置 pinctrl

每个外设都需要配置引脚复用（pinctrl）。i.MX6ULL 的引脚配置通过 `iomuxc` 节点完成：

```dts
&iomuxc {
    pinctrl-names = "default";

    pinctrl_lcdif_dat: lcdifdatgrp {
        fsl,pins = <
            MX6UL_PAD_LCD_DATA00__LCDIF_DATA00  0x49
            MX6UL_PAD_LCD_DATA01__LCDIF_DATA01  0x49
            /* ... 更多 LCD 数据线 ... */
            MX6UL_PAD_LCD_DATA23__LCDIF_DATA23  0x49
        >;
    };

    pinctrl_lcdif_ctrl: lcdifctrlgrp {
        fsl,pins = <
            MX6UL_PAD_LCD_CLK__LCDIF_CLK         0x49
            MX6UL_PAD_LCD_ENABLE__LCDIF_ENABLE   0x49
            MX6UL_PAD_LCD_HSYNC__LCDIF_HSYNC     0x49
            MX6UL_PAD_LCD_VSYNC__LCDIF_VSYNC     0x49
        >;
    };
};
```

`fsl,pins` 里的每个条目包含两部分：
- 宏定义（如 `MX6UL_PAD_LCD_DATA00__LCDIF_DATA00`）：指定引脚的复用功能
- 配置值（如 `0x49`）：指定引脚的电气特性（上拉、驱动强度等）

## 第七步——编译 DTB

设备树源文件写好后，编译成二进制 DTB：

```bash
cd ~/linux-kernel/linux-mainline
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs
```

编译成功后，DTB 文件在 `arch/arm/boot/dts/nxp/imx/` 目录下：

```bash
ls arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb
```

## 第八步——验证 DTB

你可以用 `dtc` 工具反编译 DTB，检查编译结果：

```bash
dtc -I dtb -O dts -o imx6ull-aes.dts.tmp arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb
cat imx6ull-aes.dts.tmp | grep -A 20 "panel-dpi"
```

你应该能看到 panel 节点和 `port/endpoint` 结构。

或者，在运行中的系统上检查设备树：

```bash
# 在目标板上执行
ls /proc/device-tree/
cat /proc/device-tree/soc/bus@2100000/lcdif@21c8000/status
```

## 常见问题排查

### 问题一：DTB 编译报错 `phandle_references`

如果你看到类似这样的报错：

```
arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtsi:123.45: error: phandle_references: Reference to non-existent node display0
```

这是因为你删了 `display0` 节点，但没有删除 `display = <&display0>` 属性引用。解决方法是在 `&lcdif` 节点里添加：

```dts
&lcdif {
    /delete-property/ display;
    /* ... */
};
```

### 问题二：panel 驱动没有加载

如果 dmesg 里没有 panel 相关的日志，可能是 `CONFIG_DRM_PANEL_SIMPLE` 没有开启：

```bash
zcat /proc/config.gz | grep PANEL_SIMPLE
```

应该看到 `CONFIG_DRM_PANEL_SIMPLE=y`。如果是 `n` 或 `m`，重新配置内核。

### 问题三：GPIO 冲突

如果你看到类似这样的报错：

```
pin MX6UL_PAD_GPIO1_IO09 already requested by 1-005d; cannot claim for 2040000.touchscreen
```

说明两个设备在用同一个 GPIO。检查设备树里的 `pinctrl-0` 配置，确保没有重复的引脚定义。

## 下一章预告

到这里，你应该理解了设备树的迁移方法，特别是显示系统的 OF graph 写法。下一篇文章，我们会深入讲解 DRM 显示系统的移植细节：

- 从旧 framebuffer 到 DRM 的完整迁移过程
- panel-dpi 驱动的使用方法
- 背光和时序参数配置
- 常见报错的排查方法
- 显示功能验证

显示系统是主线移植最复杂的部分，我们下一章见。

---

**参考命令速查**

```bash
# 编译 DTB
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- dtbs

# 反编译 DTB 检查
dtc -I dtb -O dts -o tmp.dts arch/arm/boot/dts/nxp/imx/imx6ull-aes.dtb

# 在目标板上检查设备树
ls /proc/device-tree/
cat /proc/device-tree/soc/bus@2100000/lcdif@21c8000/status

# 检查 pinctrl 配置
cat /sys/kernel/debug/pinctrl/*/pins
```

**延伸阅读**

- [Device Tree Specification](https://www.devicetree.org/specifications/) - 设备树规范
- [OF Graph Documentation](https://www.kernel.org/doc/html/latest/devicetree/bindings/graph.txt) - OF graph 文档
- [Device Tree Usage](https://www.kernel.org/doc/html/latest/devicetree/usage-model.html) - 设备树使用指南
