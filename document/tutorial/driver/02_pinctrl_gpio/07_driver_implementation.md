# 完整驱动代码实现

## 前言：终于到实战环节了

前面我们讲了硬件原理、pinctrl 子系统、gpio 子系统、设备树配置。说实话，这些理论知识确实挺多的。但好消息是：当你真正写驱动代码的时候，你会发现代码其实挺简洁的。

这一章我们来分析完整的 LED 驱动代码，看看它是如何使用 pinctrl 和 gpio 子系统的。

## 驱动的分层设计

我们的驱动采用了分层设计，把硬件操作和应用接口分开了：

```
┌─────────────────────────────────────────────────────────────┐
│               字符设备接口 (pinctrl_gpio_demo_04_driver)    │
│          file_operations: open, read, write, release       │
└──────────────────────────┬──────────────────────────────────┘
                           │ 调用
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   硬件抽象层 (led_hw)                       │
│           led_hw_init, led_set_status, led_get_status      │
└──────────────────────────┬──────────────────────────────────┘
                           │ 调用 GPIO API
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     GPIO 子系统                             │
│              of_get_named_gpio, gpio_direction_output      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      硬件寄存器                              │
└─────────────────────────────────────────────────────────────┘
```

这种分层设计的好处是：硬件抽象层专注于硬件操作，字符设备层专注于用户接口。两者各司其职，代码更清晰。

## 硬件抽象层：led_hw.h

首先来看头文件：

```c
#pragma once

#include <linux/types.h>

int led_hw_init(void);
void led_hw_deinit(void);
void led_set_status(bool status);
bool led_get_status(void);
```

这个接口非常简洁，就四个函数：

- `led_hw_init`：初始化 LED 硬件（从设备树读取配置，设置 GPIO）
- `led_hw_deinit`：清理硬件资源
- `led_set_status`：设置 LED 状态（true = 亮，false = 灭）
- `led_get_status`：获取 LED 状态

⚠️ **注意**：这里的 `status` 参数使用布尔值，而不是 0/1。这更符合人类思维，`true` 表示开，`false` 表示关。实际的 GPIO 值由硬件抽象层内部处理。

## 硬件抽象层：led_hw.c

现在让我们来看硬件抽象层的实现。

### 数据结构

```c
struct led_handle {
    int gpio_sub_sys_nr;              // GPIO 编号
    struct device_node *device_tree_node;  // 设备树节点
};

static struct led_handle led;
```

这个结构体保存了 LED 的硬件信息。`gpio_sub_sys_nr` 是 GPIO 子系统的全局编号，`device_tree_node` 是设备树节点的指针。

### 初始化函数

```c
int led_hw_init(void)
{
    /* 1. 获取设备树节点 */
    led.device_tree_node = of_find_node_by_path("/imx_aes_led");
    if (led.device_tree_node == NULL) {
        pr_err("dtsled node can not found!\n");
        return -EINVAL;
    }
    pr_info("dtsled node has been found!\n");

    /* 2. 获取 compatible 属性 */
    struct property *proper = of_find_property(led.device_tree_node, "compatible", NULL);
    if (proper == NULL) {
        pr_err("compatible property find failed\n");
    } else {
        pr_info("compatible = %s\n", (char *)proper->value);
    }

    /* 3. 获取 status 属性 */
    const char *str;
    if (of_property_read_string(led.device_tree_node, "status", &str) < 0) {
        pr_err("status read failed!\n");
    } else {
        pr_info("status = %s\n", str);
    }

    /* 4. 获取 GPIO 编号 */
    led.gpio_sub_sys_nr = of_get_named_gpio(led.device_tree_node, "led-gpio", 0);
    if (led.gpio_sub_sys_nr < 0) {
        pr_err("Can not parse to get the gpio nr");
        return -EINVAL;
    } else {
        pr_info("Get the gpio handle: %d\n", led.gpio_sub_sys_nr);
    }

    /* 5. 设置为输出模式，初始值为 1（LED 熄灭） */
    gpio_direction_output(led.gpio_sub_sys_nr, 1);

    pr_info("LED Hardware init finished!\n");
    return 0;
}
```

这个函数做了 5 件事：

1. **获取设备树节点**：`of_find_node_by_path` 根据路径查找节点。
2. **读取 compatible 属性**：这只是调试信息，验证设备树是否正确。
3. **读取 status 属性**：同样是为了调试。
4. **获取 GPIO 编号**：`of_get_named_gpio` 是关键函数，它从设备树的 `led-gpio` 属性解析 GPIO 编号。
5. **设置方向**：`gpio_direction_output` 把 GPIO 设置为输出模式，初始值为 1。

这里有个细节需要注意：初始值是 1。因为我们的 LED 是低电平有效的，所以 1 表示熄灭。

你可能会问：为什么不直接用 `gpio_set_value`，而要用 `gpio_direction_output`？

答案是：`gpio_direction_output` 做了两件事——设置方向**和**设置初始值。而 `gpio_direction_input` 和 `gpio_set_value` 是分开的两个操作。所以 `gpio_direction_output` 更方便。

⚠️ **注意**：这里的 GPIO 编号是全局编号（3），不是控制器内编号（也是 3，但含义不同）。`of_get_named_gpio` 会自动处理这个转换。

### 设置和获取状态

```c
void led_set_status(bool status)
{
    // 设置 GPIO 值
    gpio_set_value(led.gpio_sub_sys_nr, (int)(!status));
}

bool led_get_status(void)
{
    return !gpio_get_value(led.gpio_sub_sys_nr);
}
```

这里有个取反操作 `!status` 和 `!gpio_get_value()`。为什么？

因为我们的 LED 是低电平有效的：
- 写 0 → LED 亮
- 写 1 → LED 灭

但我们的接口定义是：
- `true` → LED 亮
- `false` → LED 灭

所以需要取反。`status = true` 时，GPIO 写 0；`status = false` 时，GPIO 写 1。

### 清理函数

```c
void led_hw_deinit(void)
{
    pr_info("Deinit LED Hardware\n");

    if (led.device_tree_node) {
        of_node_put(led.device_tree_node);
        led.device_tree_node = NULL;
    }
}
```

`of_node_put` 是释放设备树节点引用的函数。当你用完一个设备树节点后，应该调用这个函数来释放引用。

## 字符设备层：主驱动文件

现在让我们来看看主驱动文件，它提供了字符设备接口。

### 数据结构

```c
struct IMXAesLED {
    dev_t devid;                    // 设备号
    struct cdev char_device_handle; // 字符设备
    struct class *char_device_class;   // 设备类
    struct device *char_device_device; // 设备
} led_handle;
```

这个结构体保存了字符设备相关的信息。`dev_t` 是设备号类型，`cdev` 是字符设备结构体，`class` 和 `device` 用于自动创建设备节点。

### file_operations 结构体

```c
static int aes_chardev_open(struct inode *inode, struct file *filp) {
    pr_info("Device: %s called open!\n", CHARDEV_NAME);
    filp->private_data = &led_handle;
    return 0;
}

static ssize_t aes_chardev_read(struct file *filp, char __user *buf, size_t cnt, loff_t *offt) {
    if (*offt > 0) {
        return 0;  // EOF
    }

    if (cnt > 1) {
        cnt = 1;
    }

    *offt += cnt;

    const bool led_status = led_get_status();
    const char user_indication = led_status ? '1' : '0';

    if (copy_to_user(buf, &user_indication, cnt) != 0) {
        pr_warn("Failed to pass the led status to user!\n");
        return -EFAULT;
    }

    return cnt;
}

static ssize_t aes_chardev_write(struct file *filp, const char __user *buf, size_t cnt, loff_t *offt) {
    pr_info("aes_chardev_write: cnt=%zu\n", cnt);

    if (cnt > 2) {
        pr_warn("Get the unexpected data, that's too much!\n");
        return -EINVAL;
    }

    char user_led_new_status = 0;
    if (copy_from_user(&user_led_new_status, buf, 1) != 0) {
        pr_warn("Failed to set the led status from user!\n");
        return -EFAULT;
    }

    const bool led_new_status = (user_led_new_status == '1') ? true : false;
    pr_info("LED status: %d (user_led_new_status='%c')\n", led_new_status, user_led_new_status);
    led_set_status(led_new_status);
    return 1;
}

static int aes_chardev_release(struct inode *inode, struct file *filp) {
    pr_info("Device: %s called close!\n", CHARDEV_NAME);
    filp->private_data = NULL;
    return 0;
}

static struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = aes_chardev_open,
    .read = aes_chardev_read,
    .write = aes_chardev_write,
    .release = aes_chardev_release,
};
```

这里的实现和我们在字符设备章节讲的类似。唯一的不同是，读写操作调用的是硬件抽象层的函数，而不是直接操作寄存器。

### 初始化流程

```c
static int __init pinctrl_gpio_demo_04_init(void)
{
    pr_info("=== Pin Control And GPIO Demo ===\n");

    /* 1. 初始化硬件抽象层 */
    led_hw_init();

    /* 2. 初始化字符设备 */
    init_led_handle(&led_handle);

    pr_info("========================\n");
    return 0;
}
```

初始化流程很简单：先初始化硬件，再初始化字符设备。

### init_led_handle 函数

```c
static int init_led_handle(struct IMXAesLED *led_handle)
{
    pr_info("Init the User Interfaces and driver handles\n");

    /* 1. 申请设备号 */
    alloc_chrdev_region(&led_handle->devid, 0, LED_CNT, CHARDEV_NAME);

    {
        const auto led_major_number = MAJOR(led_handle->devid);
        const auto led_minor_number = MINOR(led_handle->devid);

        pr_info("LED handle get the device number: major: %u, minor: %u\n",
                led_major_number, led_minor_number);
    }

    /* 2. 初始化 cdev */
    led_handle->char_device_handle.owner = THIS_MODULE;
    cdev_init(&led_handle->char_device_handle, &fops);
    if (cdev_add(&led_handle->char_device_handle, led_handle->devid, LED_CNT) < 0) {
        pr_warn("Error when trying to make a cdev in kernel\n");
        return -1;
    }

    pr_info("cdev series api called success!\n");

    /* 3. 创建设备类 */
    led_handle->char_device_class = class_create(CHARDEV_NAME);
    if (IS_ERR(led_handle->char_device_class)) {
        pr_warn("Failed to create a class\n");
        return PTR_ERR(led_handle->char_device_class);
    }

    pr_info("class create success!\n");

    /* 4. 创建设备 */
    led_handle->char_device_device =
        device_create(led_handle->char_device_class, NULL, led_handle->devid, NULL, CHARDEV_NAME);
    if (IS_ERR(led_handle->char_device_device)) {
        pr_warn("Failed to create a device\n");
        return PTR_ERR(led_handle->char_device_device);
    }

    pr_info("device create success!\n");
    return 0;
}
```

这个函数使用了新 API（`cdev` + `class` + `device`），和旧 API (`register_chrdev`) 相比，新 API 更灵活，也更安全。

**和旧 API 的对比**：

关于字符设备 API 的详细内容，可以参考 [00_chardev_base/12_new_chardev_api_overview.md](../00_chardev_base/12_new_chardev_api_overview.md)。

## 真实输出分析

现在让我们来看看驱动加载时的真实输出：

```
[   95.894724] pinctrl_gpio_demo_04_driver: loading out-of-tree module taints kernel.
[   95.895579] === Pin Control And GPIO Demo ===
[   95.895626] dtsled node has been found!
[   95.895638] compatible = imxaes_led
[   95.895654] status = okay
[   95.895706] Get the gpio handle: 3
[   95.895730] LED Hardware init finished!
[   95.895741] Init the User Interfaces and driver handles
[   95.895755] LED handle get the device number: major: 241, minor: 0
[   95.895778] cdev series api called success!
[   95.895848] class create success!
[   95.896419] device create success!
[   95.896444] ========================
```

每一行都对应代码中的一条 `pr_info`。你可以清楚地看到初始化流程：

1. 找到设备树节点
2. 读取 compatible 和 status 属性
3. 获取 GPIO 编号（3）
4. 硬件初始化完成
5. 申请设备号（major: 241）
6. cdev 初始化成功
7. 创建 class 成功
8. 创建设备成功

## 应用层测试

应用层可以通过 `/dev/AES_LED` 设备文件来控制 LED：

```bash
# 点亮 LED
printf "1" > /dev/AES_LED

# 熄灭 LED
printf "0" > /dev/AES_LED

# 读取状态
cat /dev/AES_LED
```

真实的内核输出：

```
[  108.091762] Device: AES_LED called open!
[  108.092023] aes_chardev_write: cnt=1
[  108.092051] LED status: 1 (user_led_new_status='1')
[  108.092095] Device: AES_LED called close!
```

## 小结

我们的驱动代码展示了如何正确使用 pinctrl 和 gpio 子系统：

1. **设备树配置**：引脚复用和电气特性由 pinctrl 子系统处理，GPIO 编号和极性在设备树中指定。
2. **硬件抽象层**：使用 `of_get_named_gpio` 获取 GPIO 编号，使用 `gpio_direction_output` 和 `gpio_set_value` 控制 GPIO。
3. **字符设备层**：使用新 API (`cdev` + `class` + `device`) 创建字符设备，提供用户接口。

说实话，这个驱动代码非常简洁。我们不再需要手动映射寄存器、不再需要计算配置值、不再需要担心引脚冲突。这一切都由子系统帮我们处理了。

这就是子系统的价值所在：**让驱动开发者专注于设备逻辑，而不是硬件细节**。

**下一步：** 阅读 [08_build_and_test.md](08_build_and_test.md) 了解如何编译和测试驱动。
