# cdev 结构体与设备号管理

## 前言：走进字符设备的内心世界

前一章我们从整体上讲了新 API 的设计理念，那个"三步走"的流程：领号、填表、进门。现在我们要深入细节，把每一步拆开来仔细看看。

这一章我们重点讲两个东西：`struct cdev` 结构体和设备号管理。`cdev` 是字符设备驱动的核心数据结构，内核通过它来管理你的设备。设备号则是设备的唯一标识，用户空间通过设备号来找到对应的设备驱动。

理解这两个东西，你就理解了字符设备驱动的一半。

## cdev 结构体长什么样

`struct cdev` 是内核中字符设备的核心结构体，定义在 `include/linux/cdev.h` 中。我们先看一下它的完整定义：

```c
struct cdev {
    struct kobject kobj;           /* 内核对象基础 */
    struct module *owner;          /* 模块所属 */
    const struct file_operations *ops;  /* 操作函数集 */
    struct list_head list;         /* 字符设备链表节点 */
    dev_t dev;                     /* 设备号 */
    unsigned int count;            /* 次设备数量 */
} __randomize_layout;
```

乍一看好像挺复杂的，但其实每个字段都有它的用武之地。我们来一个一个看。

## kobj：内核对象系统的门面

`kobj` 是内核对象系统（kobject）的基础结构。说实话，kobject 本身是一个非常宏大的话题，足够写一章专门讲它。但对于我们写驱动的人来说，只需要知道它是干什么的就够了。

kobject 在这里主要扮演三个角色。第一是管理对象的生命周期，通过引用计数来跟踪对象被使用了多少次。当引用计数归零时，对象会被自动清理。第二是提供 sysfs 表示，在 `/sys` 下创建目录。第三是支持对象层次结构，通过 parent 和 kset 来建立对象之间的关系。

在我们的驱动中，`cdev.kobj` 被 `cdev_add()` 自动初始化，我们通常不需要直接操作它。当然，如果你想做一些高级操作，比如在 sysfs 里创建自定义属性，那就要和 kobject 打交道了。不过那是进阶话题，我们先不聊。

## owner：防止模块被意外卸载

`owner` 字段指向拥有此 cdev 的内核模块。你需要在初始化时这样设置：

```c
cdev.owner = THIS_MODULE;
```

这一行代码非常重要，但很多人容易忘。如果忘了设置，会发生什么？

当用户空间打开设备文件时，内核会增加 `owner` 指向模块的引用计数。这样，在设备文件被使用期间，`rmmod` 会失败，防止模块被意外卸载导致系统崩溃。如果你没设置 `owner`，内核就不知道这个设备属于哪个模块，可能会在设备还在使用时就允许卸载模块，然后你的系统就崩了。

说实话，这个坑我们踩过。一开始没太注意 `owner` 这个字段，结果调试的时候模块突然没了，系统直接 panic。后来才知道，设置 `owner` 是必须的，不是可选项。

## ops：操作函数集

`ops` 指向 `file_operations` 结构体，定义了设备的所有操作。这是你真正实现设备功能的地方。

```c
const struct file_operations *ops;
```

一个典型的例子：

```c
static struct file_operations aes_fops = {
    .owner = THIS_MODULE,
    .open = aes_chardev_open,
    .read = aes_chardev_read,
    .write = aes_chardev_write,
    .release = aes_chardev_release,
};

cdev_init(&cdev, &aes_fops);  // 初始化时关联 ops
```

`cdev_init()` 会把 `aes_fops` 的地址赋给 `cdev.ops`，这样内核就知道当用户调用 `open`、`read`、`write` 时该跳转到哪个函数了。

## dev 和 count：设备号相关

`dev` 存储分配给此设备的设备号，`count` 是此设备支持的次设备号数量。我们后面会详细讲设备号，这里先简单说一下。

设备号包含主设备号和次设备号，主设备号标识驱动程序，次设备号标识具体设备。如果你的驱动只有一个设备，`count` 就是 1。如果你想用一个驱动管理多个设备（比如多个 LED），`count` 就可以大于 1。

## cdev 操作函数：初始化、添加、删除

有了 `cdev` 结构体，接下来就是怎么操作它了。主要有三个函数：`cdev_init()`、`cdev_add()`、`cdev_del()`。

### cdev_init()：初始化结构体

`cdev_init()` 的函数原型是：

```c
void cdev_init(struct cdev *cdev, const struct file_operations *fops);
```

它的作用是初始化 `struct cdev` 结构体并关联 `file_operations` 操作函数集。我们可以看一下它的源码（简化版）：

```c
void cdev_init(struct cdev *cdev, const struct file_operations *fops)
{
    memset(cdev, 0, sizeof *cdev);     // 清零
    INIT_LIST_HEAD(&cdev->list);       // 初始化链表节点
    kobject_init(&cdev->kobj, &ktype_cdev_dynamic);  // 初始化 kobj
    cdev->ops = fops;                   // 关联操作函数
}
```

基本就是把结构体清零，初始化各个字段，然后把 `fops` 关联进来。

使用示例：

```c
struct cdev cdev;
cdev_init(&cdev, &fops);
cdev.owner = THIS_MODULE;  // 注意：需要手动设置 owner
```

这里有个细节一定要记住：`cdev_init()` 不会设置 `owner` 字段，你必须手动设置。我们前面讲过为什么这个很重要，这里就不重复了。

### cdev_add()：添加到系统

`cdev_add()` 的函数原型是：

```c
int cdev_add(struct cdev *p, dev_t dev, unsigned count);
```

参数包括：指向 `cdev` 的指针、设备号、次设备数量。返回值是 0 表示成功，负数表示失败。

它的作用是将字符设备注册到内核，使设备号与 cdev 关联，用户空间可以通过设备号访问设备。

使用示例：

```c
int ret;
ret = cdev_add(&cdev, devid, 1);
if (ret < 0) {
    printk("cdev_add failed: %d\n", ret);
    return ret;
}
```

注意错误处理，`cdev_add()` 是可能失败的。失败的原因可能是设备号冲突、内存不足等。如果不检查返回值，驱动加载时可能看起来成功了，但实际上设备并没有注册成功，用户空间访问时就会出错。

### cdev_del()：从系统删除

`cdev_del()` 的函数原型是：

```c
void cdev_del(struct cdev *p);
```

它的作用是从内核注销字符设备，释放相关资源。

使用示例：

```c
cdev_del(&cdev);
```

调用 `cdev_del()` 后，不应再访问 `cdev` 结构体。这是很多人的一个误区，以为删除后还能继续用，其实这时候结构体已经被内核回收了，再访问就是未定义行为，可能导致系统崩溃。

## 设备号的那些事

设备号是一个 32 位无符号整数，用于标识设备。它包含两部分：主设备号和次设备号。

### dev_t 的结构

`dev_t` 本质上就是一个 `u32`：

```c
typedef u32 dev_t;
```

但它的位布局有特殊含义：

```
31            20 19                   0
┌───────────────┬───────────────────────┐
│  Major (12位)  │  Minor (20位)          │
│  主设备号       │   次设备号             │
└───────────────┴───────────────────────┘
```

主设备号占高 12 位，次设备号占低 20 位。这意味着主设备号范围是 0 到 4095，次设备号范围是 0 到 1048575。

### 设备号宏：MKDEV、MAJOR、MINOR

内核提供了三个宏来操作设备号：

`MKDEV()` 用于构建设备号：

```c
#define MKDEV(ma, mi)    (((ma) << MINORBITS) | (mi))
```

示例：

```c
dev_t devid = MKDEV(200, 0);  // 主设备号 200，次设备号 0
```

`MAJOR()` 用于提取主设备号：

```c
#define MAJOR(dev)    ((unsigned int) ((dev) >> MINORBITS))
```

示例：

```c
dev_t devid = MKDEV(200, 0);
unsigned int major = MAJOR(devid);  // major = 200
```

`MINOR()` 用于提取次设备号：

```c
#define MINOR(dev)    ((unsigned int) ((dev) & MINORMASK))
```

示例：

```c
dev_t devid = MKDEV(200, 5);
unsigned int minor = MINOR(devid);  // minor = 5
```

这三个宏在驱动开发中非常常用，基本上只要涉及到设备号就会用到它们。

### 动态分配 vs 静态注册

分配设备号有两种方式：动态分配和静态注册。动态分配是让内核帮你找一个空闲的设备号，静态注册是你指定一个设备号。

动态分配的函数是 `alloc_chrdev_region()`：

```c
int alloc_chrdev_region(dev_t *dev, unsigned baseminor,
                         unsigned count, const char *name);
```

参数包括：传出参数返回分配到的设备号、次设备号的起始值（通常为 0）、申请的设备数量、设备名称（显示在 `/proc/devices`）。

示例：

```c
dev_t devid;
int ret;

ret = alloc_chrdev_region(&devid, 0, 1, "aes_led");
if (ret < 0) {
    printk("alloc_chrdev_region failed: %d\n", ret);
    return ret;
}

printk("allocated: major=%d, minor=%d\n",
       MAJOR(devid), MINOR(devid));
```

输出示例：

```
allocated: major=241, minor=0
```

静态注册的函数是 `register_chrdev_region()`：

```c
int register_chrdev_region(dev_t from, unsigned count, const char *name);
```

参数包括：指定的起始设备号、设备数量、设备名称。

示例：

```c
dev_t devid = MKDEV(200, 0);
int ret;

ret = register_chrdev_region(devid, 1, "aes_led");
if (ret < 0) {
    printk("register_chrdev_region failed: %d\n", ret);
    return ret;
}
```

静态注册可能因设备号冲突而失败，这是它的主要问题。如果你指定了一个已经被占用的设备号，注册就会失败。因此，除非你有特殊需求必须用特定的设备号，否则建议使用动态分配。

### 注销设备号

无论使用哪种方式分配，卸载时都必须注销设备号：

```c
void unregister_chrdev_region(dev_t from, unsigned count);
```

示例：

```c
unregister_chrdev_region(devid, 1);
```

如果忘记注销，设备号就会被一直占用，即使你的驱动已经卸载了。下次再想用这个设备号就会失败。所以记住，申请了就要释放，这是编程的基本素养。

## 查看系统中的设备号分配

系统中的设备号分配情况可以从 `/proc/devices` 查看：

```bash
$ cat /proc/devices
Character devices:
  1 mem
  4 /dev/vc/0
  4 tty
  5 /dev/tty
  5 /dev/console
  5 /dev/ptmx
  7 vcs
 10 misc
 13 input
  ...
 241 aes_led          # 我们的驱动
```

这是我们驱动加载后的实际输出。你可以看到，`aes_led` 驱动被分配了主设备号 241。（哦对，每一个系统上可能被分配的不一样，真的看Linux的心情的）

## 一个完整的例子

我们把前面讲的东西串起来，看一个完整的设备号分配和 cdev 注册的例子：

```c
static int init_led_handle(struct IMXAesLED *led_handle)
{
    int ret;

    /* 第一步：申请设备号 */
    ret = alloc_chrdev_region(&led_handle->devid, 0, LED_CNT, CHARDEV_NAME);
    if (ret < 0) {
        pr_warn("Failed to alloc chrdev region: %d\n", ret);
        return ret;
    }

    /* 打印分配结果 */
    {
        const int major = MAJOR(led_handle->devid);
        const int minor = MINOR(led_handle->devid);
        pr_info("LED handle get the device number: major: %d, minor: %d\n",
                major, minor);
    }

    /* 第二步：初始化并添加 cdev */
    led_handle->char_device_handle.owner = THIS_MODULE;
    cdev_init(&led_handle->char_device_handle, &fops);

    ret = cdev_add(&led_handle->char_device_handle,
                   led_handle->devid, LED_CNT);
    if (ret < 0) {
        pr_warn("Error when trying to make a cdev in kernel: %d\n", ret);
        unregister_chrdev_region(led_handle->devid, LED_CNT);
        return ret;
    }

    pr_info("cdev series api called success!\n");
    return 0;
}
```

注意这里的错误处理：如果 `cdev_add()` 失败，我们会注销之前分配的设备号。这种资源清理的顺序很重要，分配和释放要相反的顺序进行。

对应的清理代码：

```c
static void release_led_handle(struct IMXAesLED *led_handle)
{
    device_destroy(led_handle->char_device_class, led_handle->devid);
    class_destroy(led_handle->char_device_class);
    cdev_del(&led_handle->char_device_handle);
    unregister_chrdev_region(led_handle->devid, LED_CNT);
}
```

注意清理的顺序和初始化的顺序是相反的。这是一种常见的编程模式，叫做栈式分配释放。

## cdev_device_add()：更现代的 API

内核还提供了一个更高级的 API：`cdev_device_add()`。它把 `cdev_add()` 和 `device_create()` 合并成一个操作。

```c
int cdev_device_add(struct cdev *cdev, struct device *dev);
void cdev_device_del(struct cdev *cdev, struct device *dev);
```

使用示例：

```c
struct cdev cdev;
struct device *dev;

// 初始化 cdev
cdev_init(&cdev, &fops);
cdev.owner = THIS_MODULE;

// 初始化 device（需要先设置 devt）
dev->devt = devid;

// 统一注册
ret = cdev_device_add(&cdev, dev);
if (ret) {
    // 自动清理，无需手动处理
    return ret;
}
```

这个 API 的优势是一次性完成注册，自动设置父子关系，失败时自动清理，代码更简洁。但它的使用场景相对有限，需要你已经有了一个 `device` 结构体。对于简单的字符设备驱动，传统的 `cdev_add()` + `device_create()` 组合可能更直观。

## 常见错误和解决方法

我们总结了一些常见的错误，希望能帮你节省调试时间。

第一个错误是忘记设置 owner。这个我们已经讲过了，但还是要强调一下：

```c
/* 错误 */
cdev_init(&cdev, &fops);
cdev_add(&cdev, devid, 1);  // 忘记设置 owner

/* 正确 */
cdev.owner = THIS_MODULE;
cdev_init(&cdev, &fops);
cdev_add(&cdev, devid, 1);
```

第二个错误是设备号冲突。你会看到这样的错误：

```
register_chrdev_region failed: -16 (-EBUSY)
```

解决方法是使用动态分配 `alloc_chrdev_region()`，让内核帮你找一个空闲的设备号。

第三个错误是忘记注销设备号：

```c
/* 错误 */
cdev_del(&cdev);
// 忘记 unregister_chrdev_region

/* 正确 */
cdev_del(&cdev);
unregister_chrdev_region(devid, 1);
```

忘记注销会导致设备号泄漏，虽然不会立即引起问题，但多次加载卸载后可能会耗尽设备号。

## 本章小结

这一章我们深入讲解了 `struct cdev` 和设备号管理。回顾一下，我们学了什么：

第一，`cdev` 结构体的各个字段都有它的用途。`kobj` 是内核对象系统的门面，`owner` 防止模块被意外卸载，`ops` 是操作函数集，`dev` 和 `count` 是设备号相关。

第二，`cdev_init()`、`cdev_add()`、`cdev_del()` 是操作 `cdev` 的三个主要函数。初始化、添加到系统、从系统删除，这是生命周期管理的基本流程。

第三，设备号是一个 32 位数，包含主设备号和次设备号。`MKDEV()`、`MAJOR()`、`MINOR()` 是操作设备号的三个常用宏。

第四，动态分配和静态注册是分配设备号的两种方式。动态分配避免冲突，是推荐的做法。静态注册适用于有特殊需求必须用特定设备号的场景。

下一章我们会学习 class 和 device 模型，了解内核是怎么管理设备层次结构的，以及 sysfs 是怎么工作的。这些知识会让你对 Linux 设备模型有更深的理解。

**相关文档**：
- [新字符设备驱动 API 概览](12_new_chardev_api_overview.md)
- [老 API 字符设备驱动](06_legacy_chardev.md)
- [class 和 device 模型](14_class_device_model.md)
