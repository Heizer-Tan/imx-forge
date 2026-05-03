# GPIO 子系统架构深度解析

## 前言：比 pinctrl 更简单但同样重要

在上一章我们分析了 pinctrl 子系统，说实话，那部分真的挺复杂的。好消息是，GPIO 子系统会简单一些。它的核心思想很清晰：提供一个统一的 API 来控制 GPIO 引脚，不管底层是什么芯片。

## GPIO 子系统的分层设计

GPIO 子系统采用了经典的分层设计：

```
┌─────────────────────────────────────────────────────────────┐
│                    设备驱动 (你的代码)                        │
│                gpio_set_value(gpio, 1)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │ GPIO API
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   GPIO 子系统核心层                          │
│                 (gpiolib.c - gpiolib.h)                     │
│            提供统一的 API: gpio_request, gpio_set_value     │
└──────────────────────────┬──────────────────────────────────┘
                           │ gpio_chip ops
                           ▼
┌─────────────────────────────────────────────────────────────┐
│              GPIO 控制器驱动 (平台特定)                        │
│              gpio-mxc.c, gpio-pl061.c, ...                  │
│              实现 struct gpio_chip 的各种回调函数             │
└──────────────────────────┬──────────────────────────────────┘
                           │ 寄存器操作
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     硬件寄存器                                │
│           GPIO_DR, GPIO_GDIR, GPIO_PSR, ...                 │
└─────────────────────────────────────────────────────────────┘
```

这种分层设计的好处是：设备驱动不需要关心底层是什么芯片，只要调用 GPIO API 就行。如果换了芯片，只需要修改底层的 GPIO 控制器驱动，设备驱动代码完全不用改。

## 核心数据结构：gpio_chip

GPIO 子系统的核心是 `struct gpio_chip`，这个结构体描述了一个 GPIO 控制器的能力和操作函数。

```c
struct gpio_chip {
    const char *label;              // 控制器名称
    struct device *dev;             // 关联的设备
    struct module *owner;           // 模块所有者

    int base;                       // GPIO 编号的起始值
    int ngpio;                      // GPIO 的数量

    const char *const *names;       // GPIO 名称数组

    // 方向操作
    int (*get_direction)(struct gpio_chip *chip, unsigned offset);
    int (*direction_input)(struct gpio_chip *chip, unsigned offset);
    int (*direction_output)(struct gpio_chip *chip, unsigned offset, int value);

    // 值操作
    int (*get)(struct gpio_chip *chip, unsigned offset);
    void (*set)(struct gpio_chip *chip, unsigned offset, int value);

    // 其他操作...
    int (*request)(struct gpio_chip *chip, unsigned offset);
    void (*free)(struct gpio_chip *chip, unsigned offset);
    int (*to_irq)(struct gpio_chip *chip, unsigned offset);
    // ...
};
```

每个 GPIO 控制器驱动都需要实现这个结构体，填充各种回调函数。当设备驱动调用 GPIO API 时，GPIO 核心层会找到对应的 gpio_chip，然后调用这些回调函数。

## i.MX 的 GPIO 控制器驱动

现在让我们来看看 i.MX 的 GPIO 控制器驱动是怎么实现的。源码在 `drivers/gpio/gpio-mxc.c`。

### 硬件描述结构：mxc_gpio_hwdata

i.MX 系列有多个芯片代际，每个代际的 GPIO 寄存器布局可能不同。为了兼容这些差异，驱动定义了一个 `mxc_gpio_hwdata` 结构体：

```c
struct mxc_gpio_hwdata {
    unsigned dr_reg;        // 数据寄存器偏移
    unsigned gdir_reg;      // 方向寄存器偏移
    unsigned psr_reg;       // 状态寄存器偏移
    unsigned icr1_reg;      // 中断控制寄存器1
    unsigned icr2_reg;      // 中断控制寄存器2
    unsigned imr_reg;       // 中断屏蔽寄存器
    unsigned isr_reg;       // 中断状态寄存器
    int edge_sel_reg;       // 边沿选择寄存器
    // ...
};
```

每个芯片代际都有一个这样的结构体：

```c
static struct mxc_gpio_hwdata imx35_gpio_hwdata = {
    .dr_reg     = 0x00,
    .gdir_reg   = 0x04,
    .psr_reg    = 0x08,
    .icr1_reg   = 0x0c,
    .icr2_reg   = 0x10,
    .imr_reg    = 0x14,
    .isr_reg    = 0x18,
    .edge_sel_reg = 0x1c,
    // ...
};
```

这些偏移值和我们在硬件章节讲的寄存器地址是对应的。比如 `dr_reg = 0x00` 表示数据寄存器在 GPIO 模块基址的偏移 0 处。

### 端口结构：mxc_gpio_port

```c
struct mxc_gpio_port {
    struct list_head node;
    void __iomem *base;                // 寄存器基地址
    struct clk *clk;                   // 时钟
    int irq;                           // 中断号
    struct gpio_chip gc;               // gpio_chip 结构体
    struct device *dev;                // 设备指针
    const struct mxc_gpio_hwdata *hwdata;  // 硬件描述
    // ...
};
```

这个结构体描述了一个 GPIO 端口（比如 GPIO1、GPIO2）。i.MX 6ULL 有 5 个 GPIO 端口，每个端口最多 32 个 GPIO。

### 设备树匹配

驱动通过设备树的 compatible 属性来匹配：

```c
static const struct of_device_id mxc_gpio_dt_ids[] = {
    { .compatible = "fsl,imx1-gpio", .data = &imx1_imx21_gpio_hwdata },
    { .compatible = "fsl,imx21-gpio", .data = &imx1_imx21_gpio_hwdata },
    { .compatible = "fsl,imx31-gpio", .data = &imx31_gpio_hwdata },
    { .compatible = "fsl,imx35-gpio", .data = &imx35_gpio_hwdata },
    { .compatible = "fsl,imx7d-gpio", .data = &imx35_gpio_hwdata },
    { .compatible = "fsl,imx8dxl-gpio", .data = &imx35_gpio_hwdata },
    { /* sentinel */ }
};
```

i.MX 6ULL 对应的是 `fsl,imx7d-gpio`（实际上 6ULL 和 7D 的 GPIO 模块兼容）。

### probe 函数流程

当 GPIO 控制器驱动加载时，probe 函数会被调用。流程大致是这样的：

```c
static int mxc_gpio_probe(struct platform_device *pdev)
{
    // 1. 分配端口结构体
    port = devm_kzalloc(&pdev->dev, sizeof(*port), GFP_KERNEL);

    // 2. 获取硬件描述
    port->hwdata = device_get_match_data(&pdev->dev);

    // 3. 映射寄存器地址
    port->base = devm_platform_ioremap_resource(pdev, 0);

    // 4. 获取中断号
    port->irq = platform_get_irq(pdev, 0);

    // 5. 获取并使能时钟
    port->clk = devm_clk_get_optional_enabled(&pdev->dev, NULL);

    // 6. 初始化 gpio_chip
    err = bgpio_init(&port->gc, &pdev->dev, 4,
                     port->base + GPIO_PSR,   // 读取
                     port->base + GPIO_DR,    // 写入
                     NULL,
                     port->base + GPIO_GDIR,  // 方向
                     NULL,
                     BGPIOF_READ_OUTPUT_REG_SET);

    // 7. 设置自定义函数
    port->gc.request = mxc_gpio_request;
    port->gc.free = mxc_gpio_free;
    port->gc.to_irq = mxc_gpio_to_irq;

    // 8. 设置 GPIO 编号基数
    port->gc.base = of_alias_get_id(np, "gpio") * 32;

    // 9. 注册 gpio_chip
    err = devm_gpiochip_add_data(&pdev->dev, &port->gc, port);
}
```

这里有几个关键点：

1. **bgpio_init**：这是一个辅助函数，用于初始化基于寄存器的 GPIO 控制器。它会设置基本的读写函数。
2. **GPIO 编号基数**：每个 GPIO 端口有 32 个 GPIO。GPIO1 的编号是 0-31，GPIO2 是 32-63，以此类推。
3. **devm_gpiochip_add_data**：注册 gpio_chip 到 GPIO 核心层。

## GPIO API：设备驱动如何使用

现在让我们看看设备驱动是怎么使用 GPIO API 的。这些 API 定义在 `linux/gpio/consumer.h` 和 `linux/gpio.h` 中。

### 获取 GPIO 编号

从设备树获取 GPIO 编号：

```c
int gpio = of_get_named_gpio(dev->of_node, "led-gpio", 0);
if (gpio < 0) {
    pr_err("Failed to get GPIO\n");
    return gpio;
}
```

`of_get_named_gpio` 会从设备树的 `led-gpio` 属性解析 GPIO 编号。

### 申请 GPIO

在使用 GPIO 之前，需要先申请：

```c
err = gpio_request(gpio, "aes-led");
if (err) {
    pr_err("Failed to request GPIO %d\n", gpio);
    return err;
}
```

`gpio_request` 的作用是检查这个 GPIO 是否已经被其他驱动占用了。

### 设置方向

```c
// 设置为输出，初始值为 1
err = gpio_direction_output(gpio, 1);
if (err) {
    pr_err("Failed to set GPIO direction\n");
    return err;
}

// 或设置为输入
err = gpio_direction_input(gpio);
```

### 设置/获取值

```c
// 设置值（0 或 1）
gpio_set_value(gpio, 0);

// 获取值
int value = gpio_get_value(gpio);
```

### 释放 GPIO

```c
gpio_free(gpio);
```

## GPIO 编号空间：全局编号 vs 控制器编号

这里有个容易混淆的概念：GPIO 有两种编号方式。

### 全局编号

全局编号是整个系统范围内的唯一编号。GPIO1_IO03 的全局编号是：

```
gpio1_base + 3 = 0 + 3 = 3
```

因为 GPIO1 的基数是 0，GPIO1_IO03 是第 3 号引脚，所以全局编号是 3。

### 控制器编号

控制器编号是相对于特定控制器的编号。GPIO1_IO03 在 GPIO1 控制器内的编号是 3。

设备树里使用的是控制器编号：

```dts
led-gpio = <&gpio1 3 GPIO_ACTIVE_LOW>;
```

这里 `&gpio1` 表示 GPIO1 控制器，`3` 是控制器内的编号。

## 主线内核与 imx 内核的差异对比

### 代码量对比

```
主线内核 gpio-mxc.c:  733 行
imx 内核 gpio-mxc.c:   739 行
```

两个版本非常接近，只差 6 行。这说明 GPIO 驱动已经相当稳定了。

### API 差异

两个内核的 GPIO API 完全兼容。主要的差异可能在于：

1. **设备树绑定**：主线内核的设备树绑定文档可能更完整，格式也更新（从 .txt 转到 .yaml）。

2. **错误处理**：主线内核可能有更严格的错误检查。

3. **devm_* API**：主线内核更倾向于使用 `devm_` 前缀的资源管理 API，这些 API 会在设备卸载时自动释放资源。

### 数据结构差异

两个内核的核心数据结构（`struct gpio_chip`、`struct mxc_gpio_port`）完全一致。

## GPIO 子系统与 pinctrl 子系统的协作

GPIO 子系统和 pinctrl 子系统是紧密协作的。当你调用 `gpio_direction_output` 时，实际上发生了这些事情：

```
1. GPIO 子系统检查 GPIO 是否已经被申请
2. GPIO 子系统调用 gpio_chip 的 direction_output 回调
3. gpio-mxc.c 驱动写 GDIR 寄存器，设置方向
4. （可能）GPIO 子系统请求 pinctrl 子系统配置引脚
5. pinctrl 子系统检查引脚是否已被配置
6. （如果需要）pinctrl 子系统配置引脚复用
```

在大多数情况下，pinctrl 子系统会在设备加载时自动配置好引脚，GPIO 子系统只需要操作 GPIO 寄存器就行了。

## 小结

GPIO 子系统是 Linux 内核里相对简单但非常重要的子系统。它的核心思想是：**提供一个统一的 API，屏蔽不同芯片的硬件差异**。

从硬件角度看，GPIO 子系统是对 GPIO 模块寄存器的软件抽象。

从软件角度看，GPIO 子系统提供了一套标准的 API，让设备驱动不需要关心具体的寄存器操作。

从架构角度看，GPIO 子系统采用了"核心层 + 平台驱动层"的分层设计，和 pinctrl 子系统类似。

说实话，GPIO 子系统的源码相对容易理解。如果你想深入学习，建议从 `gpio-mxc.c` 的 probe 函数开始，然后追踪 `bgpio_init` 和 `devm_gpiochip_add_data` 的调用链。

**下一步：** 阅读 [06_gpio_device_tree.md](06_gpio_device_tree.md) 了解如何在设备树里配置 GPIO。
