# 硬件抽象层 - 代码分层救我狗命

如果你看过一些简单的驱动教程代码，可能会发现它们把所有东西都塞在一个文件里：寄存器定义、硬件操作、字符设备接口、ioctl 命令…… 一两千行代码混在一起，初学者能跑通就行，根本不考虑代码组织。

说实话，这种写法对于教学 demo 来说或许可以接受，但对于实际工程来说是灾难。想象一下，当你需要把驱动移植到另一块板子上，或者硬件稍微改动了一下，你需要在一个几千行的文件里找出所有需要修改的地方。更糟糕的是，如果硬件操作代码和字符设备代码混在一起，改硬件时很可能不小心破坏了设备接口的逻辑。

所以我们采用分层设计。把硬件相关操作封装在一个独立的层里，向上提供清晰的接口。这样字符设备层只关注"用户想要什么"（开灯、关灯、查询状态），而不用关心"具体怎么操作寄存器"。硬件抽象层则专注于"怎么和硬件打交道"，提供初始化、控制、查询等基础操作。这种设计带来的好处显而易见：代码职责清晰、易于维护、便于移植。当需要更换硬件时，只需要重写硬件抽象层，上层的字符设备代码可以完全不动。

我们来看看硬件抽象层的接口定义（`led_hw.h`）：

```c
void led_hw_init(void);
void led_hw_deinit(void);
void led_set_status(bool status);
bool led_get_status(void);
```

四个函数，两个用于生命周期管理，两个用于功能操作。接口非常简洁，而且名字就能说明用途。注意我们用 `bool` 类型表示状态，`true` 是亮，`false` 是灭。至于底层怎么实现——是写寄存器还是操作 GPIO 子系统——调用者完全不需要关心。有些严谨的工程师可能会问，这里为什么没有参数校验？比如 `led_set_status()` 传入一个非 0/1 的值怎么办？这个问题提得好。在我们的实现里，参数是 `bool` 类型，C 语言里任何非零值都会被当成 `true`，所以实际上不会有"非法值"这个概念。但如果接口设计成 `int` 类型，那确实需要考虑参数校验的问题。

现在我们深入到 `led_hw.c` 的实现，看看初始化过程是怎么做的。整个初始化分为三个步骤，这在代码注释里也有明确标注。

首先是寄存器映射。我们需要把所有用到的寄存器物理地址都映射到虚拟地址空间：

```c
static void __iomem* IMX6U_CCM_CCGR1 = NULL;
static void __iomem* SW_MUX_GPIO1_IO03 = NULL;
static void __iomem* SW_PAD_GPIO1_IO03 = NULL;
static void __iomem* GPIO1_DR = NULL;
static void __iomem* GPIO1_GDIR = NULL;

static void ioremapping_registers(void) {
#define IOREMAP(BASE_ADDR) ioremap(BASE_ADDR, kRegSize)
    IMX6U_CCM_CCGR1 = IOREMAP(kCCM_CCGR1_BASE);
    SW_MUX_GPIO1_IO03 = IOREMAP(kSW_MUX_GPIO1_IO03_BASE);
    SW_PAD_GPIO1_IO03 = IOREMAP(kSW_PAD_GPIO1_IO03_BASE);
    GPIO1_DR = IOREMAP(kGPIO1_DR_BASE);
    GPIO1_GDIR = IOREMAP(kGPIO1_GDIR_BASE);
#undef IOREMAP

    pr_info("IMX6U_CCM_CCGR1    = 0x%p (phys: 0x%x)\n", IMX6U_CCM_CCGR1, kCCM_CCGR1_BASE);
    pr_info("SW_MUX_GPIO1_IO03  = 0x%p (phys: 0x%x)\n", SW_MUX_GPIO1_IO03, kSW_MUX_GPIO1_IO03_BASE);
    pr_info("SW_PAD_GPIO1_IO03  = 0x%p (phys: 0x%x)\n", SW_PAD_GPIO1_IO03, kSW_PAD_GPIO1_IO03_BASE);
    pr_info("GPIO1_DR           = 0x%p (phys: 0x%x)\n", GPIO1_DR, kGPIO1_DR_BASE);
    pr_info("GPIO1_GDIR         = 0x%p (phys: 0x%x)\n", GPIO1_GDIR, kGPIO1_GDIR_BASE);
}
```

这里用了一个小技巧：宏定义 `IOREMAP` 来简化代码。这样每行寄存器映射的代码都有统一的格式，而且方便调整映射大小（只需要改 `kRegSize` 的定义）。打印映射前后的地址对比，这在调试时非常有用——你可以一眼确认内核把物理地址映射到了哪个虚拟地址。

我们这里的实现为了教学简洁，省略了错误检查。但在实际工程中，每个 `ioremap()` 调用后都应该检查返回值。如果映射失败，应该打印错误信息并返回错误码，而不是继续执行导致后续崩溃。

第二步是使能时钟：

```c
static void enable_gpio_clock(void) {
    u32 clock_settings = readl(IMX6U_CCM_CCGR1);
    pr_info("CCGR1 raw value: 0x%08x\n Bits: ", clock_settings);
    pr_info("\n");
    pr_bin_u32(clock_settings);

    clock_settings &= ~(0b11 << 26);  // 清除原来的值
    clock_settings |= 0b11 << 26;     // 设置为 11

    pr_info("CCGR1 new raw value: 0x%08x \nBits: ", clock_settings);
    pr_bin_u32(clock_settings);
    pr_info("\n");
    writel(clock_settings, IMX6U_CCM_CCGR1);
}
```

这里我们用了标准的"读-改-写"模式。先读取当前值，修改需要改的位，然后写回。注意我们用的是 `&= ~` 和 `|=` 组合，这样可以保证只修改目标位，不影响其他位。打印二进制位的函数 `pr_bin_u32()` 虽然只有几行，但在调试时非常有用。你可以直观地看到修改前后的寄存器状态，确认时钟位确实被设置成了 `11`。

第三步是配置 GPIO 功能：

```c
static void gpio_func_init(void) {
    // 配置引脚复用为 ALT5 (GPIO 模式)
    const u32 kGPIO_MUX_SETTINGS = 0b101;
    pr_info("Setting SW_MUX_GPIO1_IO03 = 0x%x\n", kGPIO_MUX_SETTINGS);
    writel(kGPIO_MUX_SETTINGS, SW_MUX_GPIO1_IO03);

    // 配置电气特性
    const u32 kGPIO_PAD_SETTINGS = 0x10B0;
    writel(kGPIO_PAD_SETTINGS, SW_PAD_GPIO1_IO03);

    // 配置为输出模式
    const u32 kGPIO_DR_OUTPUT = (1 << 3);
    u32 gpio_direction = readl(GPIO1_GDIR);
    gpio_direction &= ~kGPIO_DR_OUTPUT;  // 清除 bit 3
    gpio_direction |= kGPIO_DR_OUTPUT;   // 设置 bit 3 为 1
    writel(gpio_direction, GPIO1_GDIR);
    pr_info("GPIO1_GDIR set to 0x%08x\n", gpio_direction);

    // 初始化为高电平（LED 熄灭）
    u32 gpio_val = readl(GPIO1_DR);
    gpio_val |= (1 << 3);
    writel(gpio_val, GPIO1_DR);
    pr_info("GPIO1_DR init set to 0x%08x (LED OFF)\n", gpio_val);
}
```

这一步做了三件事：配置引脚复用、配置电气特性、配置 GPIO 方向。每个配置我们都打印了调试信息，方便验证。注意 PAD 设置值 `0x10B0`，这是一个根据硬件手册计算出来的值，具体每一位的含义在硬件文档里有详细说明。如果你使用的是不同的开发板或不同的 LED 引脚，这个值可能需要调整。最后我们把 LED 初始化为熄灭状态（输出高电平）。这看起来有点多余，但考虑到系统启动时 LED 可能处于随机状态，明确设置一个初始状态是个好习惯。

控制函数的实现非常直接：

```c
void led_set_status(bool status) {
    const u32 led_bits = (1 << 3);
    u32 gpio_val = readl(GPIO1_DR);
    pr_info("led_set_status: status=%d, GPIO1_DR before=0x%08x\n", status, gpio_val);
    if (status) {
        gpio_val &= ~led_bits;  // 清零 -> 点亮
    } else {
        gpio_val |= led_bits;   // 置一 -> 熄灭
    }
    writel(gpio_val, GPIO1_DR);
    pr_info("led_set_status: GPIO1_DR after=0x%08x, bit3=%d\n", gpio_val, !status);
}

bool led_get_status(void) {
    u32 gpio_val = readl(GPIO1_DR);
    return (gpio_val & (1 << 3)) == 0;  // 低电平为亮
}
```

因为我们的 LED 是低电平有效，所以控制逻辑稍微有点"反直觉"：写 0 点亮，写 1 熄灭。但我们在接口层做了抽象，调用者用 `true` 表示点亮、`false` 表示熄灭，不用关心底层电平。`led_get_status()` 的实现也体现了这一点——它读回寄存器的值，如果 bit 3 是 0（低电平），返回 `true`（点亮）；否则返回 `false`。

这里有个细节需要特别注意：我们在 `led_set_status()` 里用的是 `&= ~led_bits` 和 `|= led_bits`，而不是直接赋值。这很重要，因为 GPIO1_DR 寄存器控制了 32 个 GPIO 引脚，我们只关心 bit 3，其他位不能动。如果直接赋值，会影响其他引脚的状态。

清理函数的实现很简单：

```c
void led_hw_deinit(void) {
    pr_info("Deinit the LED Hardware\n");
    iounmap(IMX6U_CCM_CCGR1);
    iounmap(SW_MUX_GPIO1_IO03);
    iounmap(SW_PAD_GPIO1_IO03);
    iounmap(GPIO1_DR);
    iounmap(GPIO1_GDIR);
}
```

就是解除所有映射。注意这里没有把硬件恢复到初始状态（比如关闭时钟、恢复引脚复用）。这其实是个设计选择：如果这个硬件之后不会再被使用，恢复初始状态是礼貌的；但如果系统马上就要关机或重启，这些操作就没什么意义了。和初始化时必须按顺序来不同，清理时 `iounmap()` 的顺序不重要。每个映射都是独立的，谁先解映射都可以。

现在我们来看看这个硬件抽象层是如何被字符设备层调用的。在下一章我们会完整分析字符设备的实现，但这里先给个大概印象：

```c
static int __init chardev_led_v1_01_init(void) {
    led_hw_init();  // 硬件初始化，一行搞定
    register_chrdev(CHARDEV_MAJOR, CHARDEV_NAME, &fops);
    // ...
}

static ssize_t aes_chardev_write(struct file* filp, const char __user* buf,
                                 size_t cnt, loff_t* offt) {
    char user_led_new_status = 0;
    copy_from_user(&user_led_new_status, buf, 1);
    const bool led_new_status = (user_led_new_status == '1');
    led_set_status(led_new_status);  // 一行搞定控制
    return 1;
}
```

看到没有？字符设备层完全不需要知道寄存器地址、不需要知道时钟配置、不需要知道引脚复用。它只需要调用 `led_hw_init()` 初始化硬件，调用 `led_set_status()` 控制 LED。如果将来硬件改了，比如换成了另一款芯片，只需要重写 `led_hw.c`，字符设备的代码一行都不用改。这就是分层设计的威力。

到这里，我们已经完成了硬件抽象层的实现。代码不长，但涵盖了驱动开发中最核心的概念：寄存器映射、时钟控制、引脚配置、位操作。下一章，我们会看看字符设备层是如何实现用户接口的。包括如何处理 `open()`、`read()`、`write()`、`release()` 这些系统调用，如何实现用户空间和内核空间的数据交互，以及如何把硬件抽象层集成进来。
