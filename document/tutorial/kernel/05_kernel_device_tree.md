# 设备树在内核中的使用：从硬件描述到驱动匹配

## 为什么要谈内核中的设备树

上一章我们讲了内核模块，解决了"代码如何进内核"的问题。但还有一个更根本的问题：内核怎么知道你的板子上有哪些硬件？

这个问题在设备树出现之前，是通过"硬编码"解决的——每块板子都要写专门的板级初始化代码，把硬件信息写死在 C 代码里。那种做法的痛苦程度，我们在 U-Boot 教程里已经吐槽过了。

有了设备树之后，硬件描述从代码中分离出来，内核只需要"读懂"设备树，就知道该初始化哪些硬件、怎么初始化。但这个过程对驱动开发者来说是"隐式"的——内核默默完成了设备树的解析、设备创建、驱动匹配，你只需要写好驱动代码，在 `compatible` 字段里填上正确的值，一切就能工作。

但"隐式"不代表不需要理解。实际开发中，你一定会遇到这些问题：我的驱动为什么不加载？设备树配置对了吗？怎么调试设备树相关问题？compatible 字段到底怎么匹配？

所以这一章，我们深入内核的设备树处理机制。你会看到 DTB 是怎么被解析的、设备和驱动是怎么匹配的、常见的调试方法有哪些。理解了这些，你写驱动的时候就能有的放矢，而不是像以前那样——改改设备树，编译，烧录，启动，看运气。

## 设备树在内核中的角色

### 内核启动流程中的设备树

Linux 内核启动时，设备树的解析是一个关键环节。来看一下简化版的启动流程：

```
1. BootROM 运行
2. U-Boot 加载并运行
3. U-Boot 加载 DTB 和内核镜像到内存
4. U-Boot 跳转到内核入口，传递 DTB 地址（通过 r2 寄存器）
5. 内核解压（如果是压缩的 zImage）
6. 内核初始化早期（setup_arch()）
   └── unflatten_device_tree()：解析 DTB，构建设备树数据结构
7. 内核初始化中期（arch_init_sync()）
   └── of_platform_populate()：根据设备树创建 platform 设备
8. 内核初始化后期（device_initcall）
   └── 驱动初始化，尝试匹配已注册的设备和驱动
9. 内核启动完成，用户空间启动（init 进程）
```

第 6 步的 `unflatten_device_tree()` 是关键。DTB（Device Tree Blob）是一种紧凑的二进制格式，不适合内核运行时频繁访问。所以内核会在启动早期把它"展开"（unflatten），转换成更容易访问的链表/树结构。

第 7 步的 `of_platform_populate()` 负责创建设备。对于设备树中的每个节点，如果它有 `compatible` 属性且不是"特殊"节点（如 `chosen`、`aliases`），内核会创建对应的 `struct device`，并注册到相应的总线（通常是 platform 总线）。

第 8 步是驱动匹配。当驱动模块加载时（或静态编入内核初始化时），驱动的 `probe` 函数会被调用（如果匹配成功）。

### 设备树相关的内核数据结构

内核用几个关键数据结构来表示设备树：

**struct device_node**：表示设备树节点

```c
struct device_node {
    const char *name;           // 节点名称（@ 之前的部分）
    const char *type;           // 设备类型（device_type 属性）
    phandle phandle;            // 节点的 phandle（用于引用）
    const char *full_name;      // 完整路径名
    struct fwnode_handle fwnode; // 固件节点接口

    struct property *properties; // 属性链表
    struct property *deadprops;  // 已删除的属性

    struct device_node *parent;  // 父节点
    struct device_node *child;   // 子节点
    struct device_node *sibling; // 兄弟节点

    struct kobject kobj;         // sysfs 表示
    // ...
};
```

**struct property**：表示设备树属性

```c
struct property {
    char    *name;       // 属性名
    int     length;      // 属性值长度
    void    *value;      // 属性值
    struct property *next; // 下一个属性
    // ...
};
```

这些结构在内核运行时可以通过 `/sys/firmware/devicetree/base` 看到：

```bash
# 查看根节点
ls -la /sys/firmware/devicetree/base/

# 查看某个节点的属性
ls -la /sys/firmware/devicetree/base/soc/aips-bus@02000000/spba-bus@02000000/uart@02020000/

# 查看某个属性的内容
cat /sys/firmware/devicetree/base/soc/aips-bus@02000000/spba-bus@02000000/uart@02020000/compatible
```

输出类似：

```
fsl,imx6ull-uart\x00fsl,imx6q-uart
```

注意 `\x00` 是 null 分隔符，表示 `compatible` 属性有多个值。

## DTB 解析过程

### DTB 传递给内核

U-Boot 启动内核时，需要把 DTB 地址告诉内核。对于 ARM，这是通过寄存器传递的：

- r0：CPU ID
- r1：机器 ID（设备树时代已经不用，设为 0）
- r2：DTB 物理地址（或 ATAG 列表地址）

在 U-Boot 中，这是 `bootm` 命令自动处理的。如果你手动启动，可以用：

```
bootz ${kernel_addr_r} - ${fdt_addr_r}
```

`-` 表示没有 initramfs，`${fdt_addr_r}` 是 DTB 地址。

### unflatten_device_tree()：从 DTB 到 device_node

内核的 `unflatten_device_tree()` 函数（在 `drivers/of/fdt.c`）负责把 DTB 转换成 `device_node` 树：

1. **验证 DTB 格式**：检查魔数（0xd00dfeed）、版本、大小
2. **扫描 DTB**：遍历所有节点和属性
3. **创建 device_node**：为每个节点创建 `struct device_node`
4. **创建 property**：为每个属性创建 `struct property`
5. **建立关系**：设置 parent/child/sibling 指针

完成后，你可以通过 `of_allnodes` 全局变量访问根节点。

### 设备树调试接口

内核提供了几个设备树调试接口：

**/sys/firmware/devicetree/**：sysfs 接口（只读）

```bash
# 浏览设备树
cd /sys/firmware/devicetree/base/
find . -name "compatible" | head -20

# 查看某个属性
cat /proc/device-tree/model
cat /proc/device-tree/compatible
```

`/proc/device-tree` 是 `/sys/firmware/devicetree/base` 的符号链接。

**/sys/kernel/debug/（debugfs）**：调试接口

```bash
# 挂载 debugfs（如果没挂载）
sudo mount -t debugfs none /sys/kernel/debug/

# 查看设备树
ls /sys/kernel/debug/device-tree/

# 查看某个节点的属性
ls /sys/kernel/debug/device-tree/soc/
```

**/lib/firmware/**：设备树文件存放

有些系统会把编译好的 DTB 文件放在这里。

## 设备和驱动匹配机制

### platform 总线和驱动匹配

设备树中的大部分设备都注册为 `platform_device`，对应的驱动是 `platform_driver`。匹配过程由内核的 driver core 负责。

**匹配条件（优先级从高到低）**：

1. **设备树的 `compatible` 属性** vs 驱动的 `of_match_table`
2. **设备名称** vs 驱动名称
3. **ACPI 匹配**（x86 系统，嵌入式不常见）

对于设备树，关键是 `compatible` 属性：

```dts
uart1: serial@02020000 {
    compatible = "fsl,imx6ull-uart", "fsl,imx6q-uart";
    reg = <0x02020000 0x4000>;
    interrupts = <26 2 0>;
    // ...
};
```

对应的驱动代码：

```c
static const struct of_device_id imx_uart_dt_ids[] = {
    { .compatible = "fsl,imx6ull-uart", .data = &imx6ull_uart_data },
    { .compatible = "fsl,imx6q-uart", .data = &imx6q_uart_data },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, imx_uart_dt_ids);

static struct platform_driver imx_uart_driver = {
    .driver = {
        .name = "imx-uart",
        .of_match_table = imx_uart_dt_ids,
    },
    .probe = imx_uart_probe,
    .remove = imx_uart_remove,
};
```

### MODULE_DEVICE_TABLE 宏

这个宏很重要！它做什么？

1. 在模块中创建一个特殊的 section（`.modinfo`）
2. `modinfo` 可以读取这个信息
3. 模块加载时，udev 可以根据这个信息自动加载模块

```bash
# 查看模块的设备表
modinfo imx_uart

# 输出类似：
# alias:          of:N*T*Cfsl,imx6ull-uart*
# alias:          of:N*T*Cfsl,imx6q-uart*
```

这些 alias 规则告诉 udev：当设备树中出现 `compatible = "fsl,imx6ull-uart"` 的设备时，自动加载这个模块。

> **踩坑提醒**：忘记 `MODULE_DEVICE_TABLE` 是新手常见的错误。结果是：手动 `insmod` 模块能工作，但系统启动时模块不会自动加载。

### probe 函数调用时机

驱动匹配成功后，驱动的 `probe` 函数会被调用。这是驱动的"初始化"函数，在这里进行硬件初始化、资源申请、注册子设备等。

```c
static int imx_uart_probe(struct platform_device *pdev)
{
    struct device_node *np = pdev->dev.of_node;
    struct resource *res;
    void __iomem *base;
    int irq;

    // 获取设备树中的 reg 属性（寄存器地址）
    res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
    base = devm_ioremap_resource(&pdev->dev, res);

    // 获取中断号
    irq = platform_get_irq(pdev, 0);

    // 获取时钟
    ipg_clk = devm_clk_get(&pdev->dev, "ipg");

    // 获取其他可选属性
    of_property_read_u32(np, "fsl,uart-has-rtscts", &has_rtscts);

    // 初始化硬件...

    return 0;
}
```

## 常用设备树属性在内核中的使用

### reg 属性：物理地址映射

`reg` 属性描述设备的寄存器地址范围。内核通过 `platform_get_resource()` 获取：

```dts
uart1: serial@02020000 {
    reg = <0x02020000 0x4000>;
};
```

```c
struct resource *res;
void __iomem *base;

// 获取 MEM 资源
res = platform_get_resource(pdev, IORESOURCE_MEM, 0);
if (!res) {
    dev_err(&pdev->dev, "No MEM resource\n");
    return -ENODEV;
}

// 映射到虚拟地址
base = devm_ioremap_resource(&pdev->dev, res);
if (IS_ERR(base)) {
    return PTR_ERR(base);
}

// 现在可以通过 base 访问寄存器
writel(0x1234, base + OFFSET);
```

### interrupts 属性：中断获取

```dts
uart1: serial@02020000 {
    interrupts = <26 2 0>;
};
```

```c
int irq;

// 获取中断号
irq = platform_get_irq(pdev, 0);
if (irq < 0) {
    dev_err(&pdev->dev, "No IRQ resource\n");
    return irq;
}

// 申请中断
ret = devm_request_irq(&pdev->dev, irq, uart_isr,
                       IRQF_SHARED, "imx-uart", port);
```

### clocks 属性：时钟获取

```dts
&uart1 {
    clocks = <&clks IMX6UL_CLK_UART1_IPG>,
             <&clks IMX6UL_CLK_UART1_SERIAL>;
    clock-names = "ipg", "per";
};
```

```c
struct clk *ipg_clk, *per_clk;

ipg_clk = devm_clk_get(&pdev->dev, "ipg");
if (IS_ERR(ipg_clk))
    return PTR_ERR(ipg_clk);

per_clk = devm_clk_get(&pdev->dev, "per");
if (IS_ERR(per_clk))
    return PTR_ERR(per_clk);

// 使能时钟
clk_prepare_enable(ipg_clk);
clk_prepare_enable(per_clk);
```

### GPIO 属性：GPIO 获取

```dts
&usdhc1 {
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_usdhc1>;
    cd-gpios = <&gpio1 19 GPIO_ACTIVE_LOW>;
    wp-gpios = <&gpio1 20 GPIO_ACTIVE_HIGH>;
};
```

```c
struct cd_gpio;

cd_gpio = devm_gpiod_get(&pdev->dev, "cd", GPIOD_IN);
if (IS_ERR(cd_gpio))
    return PTR_ERR(cd_gpio);

// 读取 GPIO 状态
if (gpiod_get_value(cd_gpio))
    pr_info("Card present\n");
```

### 自定义属性：of_property_read 系列

设备树中可以定义任意自定义属性，驱动通过 `of_property_read_*` 系列函数读取：

```dts
mydevice {
    vendor,id = <0x1234>;
    vendor,name = "my-awesome-device";
    vendor,config = <0x01 0x02 0x03 0x04>;
    vendor,flag;
};
```

```c
struct device_node *np = pdev->dev.of_node;
u32 id;
const char *name;
u32 config[4];
bool flag;

// 读取 u32
of_property_read_u32(np, "vendor,id", &id);

// 读取字符串
of_property_read_string(np, "vendor,name", &name);

// 读取数组
of_property_read_u32_array(np, "vendor,config", config, 4);

// 检查布尔属性（是否存在）
flag = of_property_read_bool(np, "vendor,flag");
```

## 设备树调试方法

### 方法 1：检查 DTB 是否正确

首先确保设备树被正确编译和加载：

```bash
# 1. 反编译 DTB，检查内容
dtc -I dtb -O dts /boot/imx6ull-14x14-evk.dtb > /tmp/my.dts
less /tmp/my.dts

# 2. 确认内核使用的 DTB
cat /sys/firmware/devicetree/base/model

# 3. 检查 compatible
cat /sys/firmware/devicetree/base/compatible
```

### 方法 2：检查设备是否创建

设备树解析后，对应的设备应该被创建：

```bash
# 查看 platform 设备
ls -la /sys/devices/platform/

# 查看特定设备
ls -la /sys/devices/platform/*.uart/  # 或根据实际名称

# 查看设备的 uevent 文件（包含设备信息）
cat /sys/devices/platform/xxx/uevent
```

### 方法 3：检查驱动是否加载

```bash
# 查看已加载的模块
lsmod | grep uart

# 查看 platform 驱动
ls -la /sys/bus/platform/drivers/

# 查看特定驱动
cat /sys/bus/platform/drivers/imx-uart/module
```

### 方法 4：检查绑定情况

```bash
# 查看哪些设备绑定到哪个驱动
ls -la /sys/bus/platform/devices/*/driver

# 查看驱动绑定了哪些设备
ls -la /sys/bus/platform/drivers/imx-uart/
```

### 方法 5：启用内核调试选项

在内核配置中启用设备树调试：

```
Device Drivers  --->
    -*- Device Tree and Open Firmware support  --->
        [*]   Runtime debugging of the device tree
```

然后：

```bash
# 查看设备树解析日志
dmesg | grep of_resolve

# 查看设备创建日志
dmesg | grep of_platform
```

## 常见问题排查

### 问题 1：驱动没加载

**现象**：设备树有节点，但设备没工作，`lsmod` 看不到驱动。

**排查**：

```bash
# 1. 检查设备节点是否存在
ls /sys/firmware/devicetree/base/soc/.../uart@02020000/

# 2. 检查 compatible 属性
cat /sys/firmware/devicetree/base/soc/.../uart@02020000/compatible

# 3. 查找对应的驱动
find /sys/module -name 'uevent' -exec grep -l "compatible" {} \;

# 4. 检查驱动模块是否在文件系统中
modinfo -n name-of-module
```

**常见原因**：
- 驱动模块没安装
- `MODULE_DEVICE_TABLE` 缺失
- compatible 字符串拼写错误

### 问题 2：设备存在但驱动没绑定

**现象**：`/sys/devices/platform/` 下有设备，但 `driver` 符号链接指向空。

**排查**：

```bash
# 检查设备的 modalias
cat /sys/devices/platform/xxx/modalias

# 手动加载驱动
sudo modprobe driver-name

# 查看内核日志
dmesg | grep -i probe
```

**常见原因**：
- 驱动没加载
- `of_match_table` 为空
- compatible 字符串不匹配

### 问题 3：probe 失败

**现象**：驱动已加载，但 `dmesg` 显示 probe 失败。

**排查**：

```bash
# 查看 probe 失败原因
dmesg | grep -A 5 "imx-uart"

# 检查资源获取
dmesg | grep "resource"

# 检查时钟
dmesg | grep "clock"
```

**常见原因**：
- 资源获取失败（reg、irq、clock）
- 内存分配失败
- 硬件初始化失败

## 实战：分析 i.MX6ULL 设备树

让我们看看 i.MX6ULL 开发板的一个实际设备树节点。

### UART1 设备树节点

```bash
# 查看设备树中的 UART1
cat /sys/firmware/devicetree/base/soc/aips-bus@02100000/spba-bus@02200000/serial@02020000/compatible
```

输出：

```
fsl,imx6ull-uart\x00fsl,imx6q-uart
```

### 对应的驱动代码

在内核源码中，UART 驱动位于 `drivers/tty/serial/imx.c`：

```c
static const struct of_device_id imx_uart_dt_ids[] = {
    { .compatible = "fsl,imx6ull-uart", },
    { .compatible = "fsl,imx6q-uart", },
    { /* sentinel */ }
};
MODULE_DEVICE_TABLE(of, imx_uart_dt_ids);
```

### 验证绑定关系

```bash
# 查找 UART 设备
find /sys/devices -name "*uart*" | head -10

# 查看设备信息
ls -la /sys/devices/platform/serial@02020000/

# 查看绑定的驱动
cat /sys/devices/platform/serial@02020000/driver/modalias
```

## 设备树叠加（Overlay）

设备树叠加（Device Tree Overlay）是一种在运行时修改设备树的技术。常见用途：
- 加载可插拔设备的配置（如 Cape、HAT）
- 调试时临时修改配置
- 不重新编译 DTB 的情况下添加设备

### 叠加文件格式

```dts
/dts-v1/;
/plugin/;

&uart1 {
    status = "okay";
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_uart1>;
};
```

### 加载叠加

```bash
# 编译叠加
dtc -@ -I dts -O dtb -o /tmp/uart1.dtbo uart1-overlay.dts

# 加载叠加
echo /tmp/uart1.dtbo > /sys/kernel/config/device-tree/overlays/uart1/dtbo

# 卸载叠加
rmdir /sys/kernel/config/device-tree/overlays/uart1
```

## 写在最后

设备树在内核中的使用，是一个从"硬件描述"到"驱动匹配"的完整链条。理解这个链条，你就能知道问题出在哪一环节：

- DTB 没正确加载？内核启动就失败
- 节点解析有问题？设备创建不出来
- compatible 不匹配？驱动绑不上
- probe 失败？硬件初始化有问题

每一环节都有对应的调试方法，我们都在这一章里讲了。剩下的就是多实践——改改设备树，看看效果，用我们讲的调试方法验证一下。

到这里，你应该理解了设备树是如何被内核解析和使用的。但要让内核真正在板子上跑起来，还需要解决一个实际问题：如何快速迭代开发和测试？

下一章，我们进入一个非常实战的话题：WSL2 + TFTP + 网络启动。你会看到如何用 WSL2 搭建网络开发环境，如何配置 TFTP 服务器，如何解决 Windows 防火墙带来的各种坑。那是一个"从理论到实践"的完整过程，而且踩坑记录非常详细。

准备好了吗？让我们继续。
