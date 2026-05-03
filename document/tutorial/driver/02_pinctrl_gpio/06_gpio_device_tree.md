# 设备树中的 GPIO 配置实战

## 前言：GPIO 属性的两种写法

在上一章我们分析了 GPIO 子系统的源码，理解了它是如何工作的。现在让我们回到设备树，看看怎么正确配置 GPIO。

说实话，设备树里的 GPIO 配置有一个容易让人踩坑的地方：**属性名有两种写法**——`led-gpio` 和 `led-gpios`。这两个都是对的，但用法稍有不同。我们后面会详细讲。

## GPIO 控制器节点

首先，GPIO 控制器本身也需要在设备树里定义。在 i.MX 6ULL 的设备树里（imx6ull.dtsi），GPIO1 的定义大致是这样的：

```dts
gpio1: gpio@0209c000 {
    compatible = "fsl,imx7d-gpio", "fsl,imx35-gpio";
    reg = <0x0209c000 0x4000>;
    interrupts = <GIC_SPI 66 IRQ_TYPE_LEVEL_HIGH>;
    gpio-controller;
    #gpio-cells = <2>;
    interrupt-controller;
    #interrupt-cells = <2>;
};
```

这里有几个关键属性：

- `compatible`：用于驱动匹配。`fsl,imx7d-gpio` 是具体的兼容字符串。
- `reg`：GPIO 控制器的寄存器地址范围。
- `gpio-controller`：标记这是一个 GPIO 控制器。
- `#gpio-cells`：指定引用这个 GPIO 时需要几个参数。对于 i.MX，通常是 2 个：控制器内的编号和标志位。

⚠️ **注意**：`#gpio-cells = <2>` 表示引用这个 GPIO 时需要 2 个参数。第一个参数是控制器内的编号（0-31），第二个参数是标志位（比如 `GPIO_ACTIVE_LOW`）。

## GPIO 属性的两种写法

现在我们来看设备节点里怎么引用 GPIO。有两种写法：

### 写法一：单数形式 `xxx-gpio`

```dts
imx_aes_led {
    led-gpio = <&gpio1 3 GPIO_ACTIVE_LOW>;
};
```

这种写法适用于只有一个 GPIO 的情况。属性名是单数形式，值是单个 GPIO 引用。

### 写法二：复数形式 `xxx-gpios`

```dts
imx_aes_led {
    led-gpios = <&gpio1 3 GPIO_ACTIVE_LOW>;
};
```

这种写法更通用，适用于有多个 GPIO 的情况。比如一个设备有 3 个 LED：

```dts
my_device {
    led-gpios = <&gpio1 3 GPIO_ACTIVE_LOW>,
                <&gpio1 4 GPIO_ACTIVE_LOW>,
                <&gpio1 5 GPIO_ACTIVE_LOW>;
};
```

⚠️ **注意**：虽然两种写法都可以，但内核推荐使用复数形式 `xxx-gpios`。为什么？因为这样更一致，而且便于扩展。

## GPIO 引用的格式

不管用哪种写法，GPIO 引用的格式都是一样的：

```dts
<&gpio_controller pin_number flags>
```

- `&gpio_controller`：GPIO 控制器的引用（通过标签）
- `pin_number`：控制器内的编号（0-31）
- `flags`：标志位，常用的有 `GPIO_ACTIVE_LOW` 和 `GPIO_ACTIVE_HIGH`

我们的例子：

```dts
led-gpio = <&gpio1 3 GPIO_ACTIVE_LOW>;
```

表示：使用 GPIO1 控制器的第 3 号引脚，低电平有效。

## GPIO_ACTIVE_LOW vs GPIO_ACTIVE_HIGH

这两个标志位告诉内核 GPIO 的极性：

- `GPIO_ACTIVE_LOW` (0)：低电平有效。写 0 时设备激活，写 1 时设备关闭。
- `GPIO_ACTIVE_HIGH` (1)：高电平有效。写 1 时设备激活，写 0 时设备关闭。

默认值是 `GPIO_ACTIVE_HIGH`，所以如果忽略这个参数，内核会认为是高电平有效。

我们的 LED 是低电平有效的，所以必须指定 `GPIO_ACTIVE_LOW`。这样内核会自动反转逻辑，我们就可以用正常的思维（1 表示开，0 表示关）来编程了。

## 驱动代码如何解析 GPIO

让我们看看驱动代码是怎么从设备树解析 GPIO 的：

```c
// 方法一：使用 of_get_named_gpio（旧 API）
int gpio = of_get_named_gpio(dev->of_node, "led-gpio", 0);
if (gpio < 0) {
    pr_err("Failed to get GPIO\n");
    return gpio;
}

// 方法二：使用 gpiod_get（新 API，推荐）
struct gpio_desc *desc;
desc = gpiod_get(dev, "led", GPIOD_OUT_LOW);
if (IS_ERR(desc)) {
    pr_err("Failed to get GPIO\n");
    return PTR_ERR(desc);
}
```

`of_get_named_gpio` 的第二个参数是属性名（"led-gpio" 或 "led-gpios"），第三个参数是索引（如果有多个 GPIO，用索引选择）。

`gpiod_get` 的第二个参数是属性名的后缀。如果属性名是 "led-gpios"，后缀就是 "led"。

⚠️ **注意**：新代码推荐使用 `gpiod_get` 系列 API，而不是 `of_get_named_gpio`。新 API 有更好的错误处理和资源管理。

## 查找引脚冲突的方法

当你添加新的 GPIO 配置时，一定要检查引脚是否已经被其他设备使用了。

### 方法一：grep 设备树文件

```bash
grep -r "gpio1" arch/arm/boot/dts/
```

这会显示所有引用 GPIO1 的地方。你可以逐个检查，看看有没有冲突。

### 方法二：查看内核日志

如果你的 GPIO 已经被其他驱动占用了，当你尝试申请时会看到类似的错误：

```
gpio-3 (led-gpio) hogged, cannot claim
```

### 方法三：查看 sysfs

GPIO 子系统会在 sysfs 下导出信息：

```bash
ls /sys/class/gpio/
```

如果一个 GPIO 已经被导出，你会看到 `gpiochip0`、`gpio3` 这样的节点。

## 完整的设备树配置示例

现在让我们来看一个完整的设备树配置，包含 pinctrl 和 GPIO：

```dts
/dts-v1/;
#include "imx6ull.dtsi"
#include "imx6ull-aes.dtsi"

/ {
    model = "Awesome Embedded Studio IMX6ULL Example Driver";
    compatible = "fsl,imx6ull-14x14-evk", "fsl,imx6ull";

    imx_aes_led {
        compatible = "imxaes_led";

        // pinctrl 配置：引脚复用和电气特性
        pinctrl-names = "default";
        pinctrl-0 = <&pinctrl_aes_led>;

        // GPIO 配置：哪个 GPIO，极性是什么
        led-gpio = <&gpio1 3 GPIO_ACTIVE_LOW>;

        status = "okay";
    };
};

&iomuxc {
    // pinctrl 配置：把 GPIO1_IO03 配置成 GPIO 功能
    pinctrl_aes_led: led_grp {
        fsl,pins = <
            MX6UL_PAD_GPIO1_IO03__GPIO1_IO03    0x10B0
        >;
    };
};
```

这个配置做了两件事：

1. pinctrl 子系统把 GPIO1_IO03 配置成 GPIO 功能
2. 设备树告诉驱动：这个设备用的是 gpio1 的第 3 号引脚，而且是低电平有效的

## 其他外设的 GPIO 使用示例

为了让你对 GPIO 配置有更全面的理解，让我们看看其他外设是怎么用 GPIO 的。

### SD 卡的 CD 引脚

```dts
&usdhc1 {
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_usdhc1>;
    cd-gpios = <&gpio1 19 GPIO_ACTIVE_LOW>;
    status = "okay";
};
```

这里 `cd-gpios` 表示卡检测（Card Detect）引脚。当 SD 卡插入时，这个引脚会被拉低（因为是 `GPIO_ACTIVE_LOW`）。

### I2C 的 SDA/SDL 引脚

I2C 不需要单独的 GPIO 配置，因为引脚复用已经处理了：

```dts
&i2c1 {
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_i2c1>;
    status = "okay";
};

&iomuxc {
    pinctrl_i2c1: i2c1grp {
        fsl,pins = <
            MX6UL_PAD_UART4_TX_DATA__I2C1_SCL    0x4001b8b0
            MX6UL_PAD_UART4_RX_DATA__I2C1_SDA    0x4001b8b0
        >;
    };
};
```

I2C 的引脚被配置成 I2C 功能，驱动会直接使用 I2C API，不需要 GPIO API。

## 命名规范建议

虽然设备树对命名没有严格要求，但遵循一些规范会让代码更易读：

1. **GPIO 属性名**：使用 `<功能>-gpios` 或 `<功能>-gpio`。比如 `led-gpios`、`reset-gpio`。
2. **pinctrl 标签**：使用 `pinctrl_<设备>`。比如 `pinctrl_aes_led`。
3. **pinctrl 节点名**：使用 `<功能>_grp`。比如 `led_grp`。

## 调试技巧

当你修改了设备树后，怎么验证 GPIO 配置是否正确？

### 查看 sysfs

```bash
# 查看 GPIO 控制器
ls /sys/class/gpio/

# 查看特定 GPIO 的信息
cat /sys/kernel/debug/gpio
```

### 查看设备树

```bash
ls /proc/device-tree/
cat /proc/device-tree/imx_aes_led/led-gpio
```

### 使用 libgpio

你可以用 libgpio 工具来测试 GPIO：

```bash
# 导出 GPIO
echo 3 > /sys/class/gpio/export

# 设置方向
echo out > /sys/class/gpio/gpio3/direction

# 设置值
echo 1 > /sys/class/gpio/gpio3/value
echo 0 > /sys/class/gpio/gpio3/value
```

⚠️ **注意**：在手动操作 GPIO 之前，确保它没有被驱动占用。否则你会看到 "Device or resource busy" 的错误。

## 小结

设备树中的 GPIO 配置就几个关键点：

1. GPIO 控制器节点需要 `gpio-controller` 和 `#gpio-cells` 属性
2. 设备节点通过 `<&gpioX N FLAGS>` 格式引用 GPIO
3. `GPIO_ACTIVE_LOW` 和 `GPIO_ACTIVE_HIGH` 指定 GPIO 的极性
4. 属性名可以是单数 (`xxx-gpio`) 或复数 (`xxx-gpios`) 形式
5. 配置前一定要检查引脚冲突

说实话，GPIO 配置比 pinctrl 配置简单多了。你只需要知道是哪个 GPIO、极性是什么，就完了。pinctrl 那边的引脚复用和电气特性配置才是真正复杂的地方。

**下一步：** 阅读 [07_driver_implementation.md](07_driver_implementation.md) 了解完整的驱动代码实现。
