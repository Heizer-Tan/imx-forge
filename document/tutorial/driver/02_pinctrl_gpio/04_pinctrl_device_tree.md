# 设备树中的 pinctrl 配置实战

## 前言：设备树是配置的中心

在上一章我们分析了 pinctrl 子系统的源码，理解了它是如何工作的。但说实话，作为驱动开发者，你更关心的是：怎么在设备树里正确配置 pinctrl？

这一章我们不讲源码，只讲设备树。我会手把手教你如何写 pinctrl 配置，每个属性是什么意思，配置值是怎么计算出来的。

## iomuxc 节点：pinctrl 的"大本营"

在 i.MX 的设备树里，所有的 pinctrl 配置都挂在 `iomuxc` 节点下。iomuxc 是 IOMUX Controller 的缩写，就是我们在硬件章节讲的那个控制引脚复用的硬件模块。

在内核的设备树文件里（imx6ull.dtsi），iomuxc 节点的定义是这样的：

```dts
iomuxc: iomuxc@020e0000 {
    compatible = "fsl,imx6ull-iomuxc";
    reg = <0x020e0000 0x4000>;
};
```

这里有两个关键属性：

- `compatible`：用于驱动匹配。pinctrl-imx 驱动会查找这个 compatible 值，匹配上之后就会加载。
- `reg`：IOMUXC 控制器的寄存器地址范围。`0x020e0000` 是起始地址，`0x4000` 是地址范围大小（16KB）。

## &iomuxc 引用语法：向现有节点追加内容

现在问题来了：我们自己的设备树文件怎么往 iomuxc 节点里添加内容？

答案是使用引用语法 `&iomuxc`。这个语法的作用是"打开已经存在的节点，向里面追加内容"。

```dts
&iomuxc {
    pinctrl_aes_led: led_grp {
        fsl,pins = <
            MX6UL_PAD_GPIO1_IO03__GPIO1_IO03    0x10B0
        >;
    };
};
```

这里有几个要点：

1. `&iomuxc` 是引用语法，表示我们要修改的是已经存在的 iomuxc 节点。
2. `pinctrl_aes_led` 是标签（label），后面其他节点可以通过这个标签引用这个配置。
3. `led_grp` 是节点名称，可以自由命名，建议起个有意义的名字。
4. `fsl,pins` 是 NXP i.MX 系列专用的属性名，定义了引脚配置。

⚠️ **注意**：这个 `&iomuxc` 引用语法必须这么写，不能写成 `iomuxc { ... }`。后者是创建一个新节点，而我们需要的是修改已有节点。

## fsl,pins 属性：核心配置所在

`fsl,pins` 属性包含了所有引脚配置信息。它的格式是这样的：

```dts
fsl,pins = <
    PIN_FUNC_ID    CONFIG
    PIN_FUNC_ID    CONFIG
    ...
>;
```

每一行有两个值：`PIN_FUNC_ID` 和 `CONFIG`。

### PIN_FUNC_ID：引脚功能标识

`PIN_FUNC_ID` 实际上是一个宏定义，展开后是 5 个整数：

```
<mux_reg conf_reg input_reg mux_val input_val>
```

让我们以 `MX6UL_PAD_GPIO1_IO03__GPIO1_IO03` 为例：

```c
#define MX6UL_PAD_GPIO1_IO03__GPIO1_IO03    0x0068 0x02f4 0x0000 5 0
```

这 5 个数字的含义是：

| 参数 | 值 | 含义 |
|------|-----|------|
| mux_reg | 0x0068 | MUX 寄存器的偏移地址 |
| conf_reg | 0x02f4 | PAD 配置寄存器的偏移地址 |
| input_reg | 0x0000 | 输入选择寄存器的偏移地址（0 表示不需要） |
| mux_val | 5 | MUX 模式值（5 表示 ALT5，即 GPIO 模式） |
| input_val | 0 | 输入选择值（0 表示不需要） |

这些值都可以从芯片手册里查到，但更简单的方法是直接使用内核提供的宏定义。这些宏定义在 `imx6ul-pinfunc.h` 文件里。

### CONFIG：电气特性配置

`CONFIG` 是一个 32 位的配置值，用来设置引脚的电气特性。我们的例子中是 `0x10B0`。

让我们来分解这个值：

```
0x10B0 = 0b0001 0000 1011 0000

位 [16]    HYS   = 0  (不使能迟滞)
位 [15:14] PUS   = 10 (100K 上拉)
位 [13]    PUE   = 1  (使能上拉)
位 [12]    PKE   = 1  (使能保持器)
位 [11]    ODE   = 0  (禁止开漏)
位 [10:6]  SPEED = 00010 (中速 100MHz)
位 [5:3]   DSE   = 011 (R0/3 驱动强度)
位 [1:0]   SRE   = 0  (慢速 slew rate)
```

对于不同的应用场景，配置值会有所不同。比如高速信号（如 UART、SPI）需要更快的 SPEED 和更小的 SRE 延迟。

### 特殊配置值

有两个特殊的配置值需要注意：

1. `NO_PAD_CTL` (0x80000000)：表示这个引脚不需要 PAD 配置。
2. `SION` (0x40000000)：Software Input On，强制使能输入路径，不管 MUX 模式是什么。

## 完整的设备树配置示例

现在让我们来看一个完整的设备树配置：

```dts
/dts-v1/;
#include "imx6ull.dtsi"
#include "imx6ull-aes.dtsi"

/ {
    model = "Awesome Embedded Studio IMX6ULL Example Driver";
    compatible = "fsl,imx6ull-14x14-evk", "fsl,imx6ull";

    imx_aes_led {
        compatible = "imxaes_led";

        pinctrl-names = "default";
        pinctrl-0 = <&pinctrl_aes_led>;

        status = "okay";

        led-gpio = <&gpio1 3 GPIO_ACTIVE_LOW>;
    };
};

&iomuxc {
    pinctrl_aes_led: led_grp {
        fsl,pins = <
            MX6UL_PAD_GPIO1_IO03__GPIO1_IO03    0x10B0
        >;
    };
};
```

这里有两个关键的地方：

1. `pinctrl-0 = <&pinctrl_aes_led>`：设备节点通过这个属性引用 pinctrl 配置。
2. `&pinctrl_aes_led`：通过标签引用 iomuxc 节点下定义的配置。

## pinctrl-names 和 pinctrl-0：设备如何使用 pinctrl

设备节点通过两个属性来使用 pinctrl 配置：

- `pinctrl-names`：pinctrl 配置的名称列表
- `pinctrl-0`、`pinctrl-1`...：对应的 pinctrl 配置引用

```dts
imx_aes_led {
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_aes_led>;
};
```

这里 `pinctrl-names = "default"` 表示这是默认的 pinctrl 配置。设备加载时，pinctrl 子系统会自动应用这个配置。

有些设备可能有多个 pinctrl 配置，比如：

```dts
uart1 {
    pinctrl-names = "default", "sleep";
    pinctrl-0 = <&pinctrl_uart1>;
    pinctrl-1 = <&pinctrl_uart1_sleep>;
};
```

这种情况下，默认使用 `pinctrl_uart1` 配置，设备进入休眠时会切换到 `pinctrl_uart1_sleep` 配置。

## 宏定义的命名规则

你可能会好奇，`MX6UL_PAD_GPIO1_IO03__GPIO1_IO03` 这个宏定义是怎么命名的？

命名规则是这样的：

```
MX6UL_PAD_<引脚名>__<功能名>
```

- `MX6UL` 表示这是 i.MX6UL 的定义
- `PAD` 表示这是一个 PAD 引脚
- `<引脚名>` 是芯片手册上的引脚名称
- `<功能名>` 是要配置成的功能

同一个物理引脚可以有多个宏定义，对应不同的功能：

```c
MX6UL_PAD_GPIO1_IO03__I2C1_SDA       // 配置成 I2C1 的数据线
MX6UL_PAD_GPIO1_IO03__GPT1_COMPARE3  // 配置成定时器的比较输出
MX6UL_PAD_GPIO1_IO03__USB_OTG2_OC    // 配置成 USB 的过流检测
MX6UL_PAD_GPIO1_IO03__GPIO1_IO03     // 配置成 GPIO
```

你在设备树里选择哪个宏定义，就决定了引脚被配置成什么功能。

## 多引脚配置：一次配置多个引脚

如果你的设备需要多个引脚，可以在 `fsl,pins` 里配置多个：

```dts
pinctrl_uart1: uart1grp {
    fsl,pins = <
        MX6UL_PAD_UART1_TX_DATA__UART1_DCE_TX  0x1b0b0
        MX6UL_PAD_UART1_RX_DATA__UART1_DCE_RX  0x1b0b0
    >;
};
```

这里配置了 UART1 的两个引脚：TX 和 RX。每个引脚都有自己的 MUX 配置和 PAD 配置。

## 引脚冲突检测：避免踩坑

当你添加新的 pinctrl 配置时，一定要检查引脚是否已经被其他设备使用了。

检查方法很简单：grep 设备树文件，看看这个引脚是否已经在其他地方被配置了。

```bash
grep -r "GPIO1_IO03" arch/arm/boot/dts/
```

如果发现冲突，你需要：

1. 确认这个引脚是否真的被其他功能使用
2. 如果是，考虑换一个引脚
3. 如果不是，可以删除冲突的配置

⚠️ **注意**：引脚冲突很难调试。如果两个设备都试图控制同一个引脚，结果是不确定的。可能一个设备工作正常，另一个不行；或者两个都不工作。

## 调试技巧：查看 pinctrl 配置

当你修改了设备树后，怎么验证配置是否正确呢？

### 方法一：查看 sysfs

pinctrl 子系统会在 sysfs 下导出调试信息：

```bash
# 查看 pinctrl 设备
ls /sys/class/pinctrl/

# 查看特定 pinctrl 的引脚配置
cat /sys/kernel/debug/pinctrl/20e0000.iomuxc/pins
```

### 方法二：查看设备树

系统启动后，可以在 `/proc/device-tree/` 下查看设备树：

```bash
ls /proc/device-tree/
cat /proc/device-tree/imx_aes_led/status
```

这就是我们在 output.md 里看到的命令：

```bash
~ # ls /proc/device-tree/
#address-cells      imx_aes_led         model
...
~ # cd /proc/device-tree/imx_aes_led
/proc/device-tree/imx_aes_led # ls
compatible     name          pinctrl-0      status
pinctrl-names
```

## 小结

设备树中的 pinctrl 配置其实就几个关键点：

1. 使用 `&iomuxc` 引用语法向 iomuxc 节点追加内容
2. 在 `fsl,pins` 属性里配置引脚功能（宏定义）和电气特性（配置值）
3. 设备节点通过 `pinctrl-0` 引用 pinctrl 配置
4. 注意检查引脚冲突

说实话，写 pinctrl 配置不需要你从头计算每个值。内核已经为每个芯片准备好了宏定义，你只需要选择正确的宏，然后根据应用场景调整配置值就行了。

**下一步：** 阅读 [05_gpio_subsystem_arch.md](05_gpio_subsystem_arch.md) 了解 GPIO 子系统的架构。
