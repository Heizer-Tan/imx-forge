# 新字符设备驱动 API 概览

## 前言：我们为什么需要一个新的 API

前一章我们用老 API 写了一个字符设备驱动，跑起来了，LED 也亮了。说实话，老 API 确实很简单，一行 `register_chrdev` 搞定注册，代码量少，学习曲线平缓。但这种简单是有代价的。

当你开始写更复杂的驱动，或者需要在同一个系统里集成多个驱动时，老 API 的问题就会一个接一个地冒出来。我们在这章会详细讲这些问题，以及新 API 是怎么解决它们的。你可能一开始会觉得新 API 有点繁琐，代码量多了不少，但相信我们，这是值得的。

## 第一个问题：资源霸占

有一种错觉，几乎是每个刚写完第一个驱动的人都会有的：觉得 `register_chrdev` 这一行代码只要不报错，世界就和平了。但这个错觉很危险。

为什么危险？因为当你写下 `register_chrdev(200, ...)` 时，你告诉内核的是：把 200 号设备通道下面所有的门——从第 0 扇到第 1048575 扇——全部交给我。

1048575 是什么概念？设备号是一个 32 位数，其中高 12 位是主设备号，低 20 位是次设备号。每个主设备号下可以有 2的20次方个，也就是 1,048,576 个次设备号。当你使用 `register_chrdev(200, ...)` 时，哪怕你的驱动只需要一对设备号，内核也会把剩下的那一百多万扇门统统锁死，谁也别想用。

这种行为在工程上叫资源霸占。在内核这种寸土寸金的地方，这是严重的社交事故。想象一下，你写了一个驱动，占用了主设备号 200 下的所有次设备号。后来另一个开发者也想用主设备号 200，但发现已经被你霸占了，他只能换个号。如果大家都这么干，设备号很快就会用完。

## 第二个问题：设备号冲突

使用老 API 时，你必须凭感觉或查手册来确定一个主设备号没被占用。这种做法在单机开发时可能还行，但在团队协作或者系统集成时就是灾难。

早期 Linux 开发中，不同驱动开发者经常选择相同的主设备号，导致驱动无法共存。后来建立了设备号分配表，但这带来了新的问题：你需要去查阅、去申请、去协调。对于一个简单的驱动来说，这个成本太高了。

## 第三个问题：手动创建节点的麻烦

使用老 API 注册驱动后，你还需要手动执行 `mknod` 命令创建设备节点：

```bash
mknod /dev/mydevice c 200 0
```

这看起来很简单，但在实际工程中带来几个问题。每次加载驱动后都要手动创建，容易忘记，导致用户空间程序找不到设备文件。在自动化部署中需要额外的脚本，增加了复杂度。

而且，用户必须知道正确的主设备号和次设备号才能创建节点。如果驱动用的是动态分配的设备号，用户还得先去 `/proc/devices` 查看分配结果，然后才能创建节点。这个过程很容易出错。

## 新 API 的设计理念

新 API 的核心理念可以概括为两个字：按需。你需要几个设备号，就申请几个，不再霸占整个主设备号下的所有次设备号。你需要创建设备节点，内核会自动帮你处理，不用手动 mknod。

这种设计把注册这个大动作拆成了清晰的三个阶段：

第一步是领号。向内核申请设备号，可以是动态分配（让内核帮你找一个空闲的），也可以是静态注册（你指定一个设备号，但如果已被占用就会失败）。

第二步是填表。初始化字符设备结构体 `cdev`，把它和你的操作函数集关联起来，然后添加到内核的字符设备表中。

第三步是进门。创建设备类和设备，触发 udev/mdev 自动在 `/dev` 下创建设备节点。

这种三步走的设计强迫开发者思考每个步骤的目的，而不是像老 API 那样一行搞定细节全黑。虽然代码量多了，但每一步都很清晰，出了问题也容易定位。

## 三步走详解

我们来看一下每个步骤具体怎么实现。这里先给个整体框架，后面会有更详细的讲解。

第一步领号有两种方式。动态分配是推荐的做法，因为不会冲突：

```c
dev_t devid;
alloc_chrdev_region(&devid, 0, 1, "my_dev");
// 内核自动分配一个可用的设备号
```

静态注册适用于你有特殊需求必须用特定设备号的情况：

```c
dev_t devid = MKDEV(200, 0);
register_chrdev_region(devid, 1, "my_dev");
// 使用指定的主设备号 200
```

第二步填表涉及到 `cdev` 结构体：

```c
struct cdev cdev;
cdev_init(&cdev, &fops);      // 初始化
cdev.owner = THIS_MODULE;     // 设置所属模块（重要！）
cdev_add(&cdev, devid, 1);     // 添加到系统
```

这里有个细节很多人容易忘：`cdev_init` 不会设置 `owner` 字段，你必须手动设置。如果忘了，模块在使用时可能被意外卸载，导致系统崩溃。

第三步进门：

```c
struct class *cls = class_create("my_class");
struct device *dev = device_create(cls, NULL, devid, NULL, "my_device");
// 此时 /dev/my_device 自动创建
```

`class_create` 创建一个设备类，`device_create` 创建具体的设备并触发 udev/mdev 自动创建设备节点。这比手动 mknod 方便多了。

## 新 API vs 老 API：一个实际的对比

我们来用一个实际的例子对比一下两种 API。假设我们要实现一个简单的字符设备驱动。

老 API 的实现：

```c
static int __init old_init(void)
{
    register_chrdev(200, "old_dev", &old_fops);
    // 需要手动 mknod /dev/old_dev c 200 0
    return 0;
}
```

就这一行，看起来很简洁对吧？但问题我们已经讲过了：霸占了 1,048,576 个次设备号，设备号可能冲突，还需要手动创建节点。

新 API 的实现：

```c
struct cdev testcdev;
struct class *test_class;
struct device *test_device;
dev_t devid;

static int __init test_init(void)
{
    int retvalue;

    /* 第一步：领号 */
    retvalue = alloc_chrdev_region(&devid, 0, 1, "test");
    if (retvalue < 0) {
        return retvalue;
    }

    /* 第二步：填表 */
    testcdev.owner = THIS_MODULE;
    cdev_init(&testcdev, &test_fops);
    retvalue = cdev_add(&testcdev, devid, 1);
    if (retvalue < 0) {
        goto failed_cdev;
    }

    /* 第三步：进门 */
    test_class = class_create("test_class");
    if (IS_ERR(test_class)) {
        retvalue = PTR_ERR(test_class);
        goto failed_class;
    }

    test_device = device_create(test_class, NULL, devid, NULL, "test0");
    if (IS_ERR(test_device)) {
        retvalue = PTR_ERR(test_device);
        goto failed_device;
    }

    return 0;

failed_device:
    class_destroy(test_class);
failed_class:
    cdev_del(&testcdev);
failed_cdev:
    unregister_chrdev_region(devid, 1);
    return retvalue;
}
```

代码量多了不少，但每一步都很清晰。而且注意到了吗？这里有错误处理，如果某一步失败了，会回滚之前成功的步骤。老 API 那种一行搞定的写法很难做到这么细致的错误处理。

## 新 API 的优势总结

我们来总结一下新 API 到底带来了什么好处。

首先是资源利用率高。老 API 浪费 1,048,575 个次设备号，新 API 只占用 1 个。这个效率提升是百万倍的。在一个资源紧张的嵌入式系统里，这种差距是很可观的。

其次是避免冲突。动态分配设备号，不需要手动管理设备号分配表，内核会自动找一个空闲的给你用。

第三是自动化程度高。设备节点自动创建，无需人工干预。这对于系统集成和自动化部署来说太重要了。

第四是可扩展性强。清晰的模块化设计，易于扩展到多设备场景。比如你想做一个驱动控制多个 LED，用新 API 可以很方便地管理多个设备。

最后是符合现代内核开发规范。新 API 是内核开发者的推荐方式，与设备模型、sysfs 等现代机制深度集成。

## 什么时候用新 API，什么时候还能用老 API

我们不是说老 API 完全不能用。在某些场景下，老 API 仍然是合适的选择。

比如你正在做快速原型，想验证一个想法，这时候老 API 的简单性就是一个优势。代码少，上手快，能让你专注于核心逻辑而不是 API 细节。

再比如你在学习驱动基础概念，老 API 能让你不被繁琐的初始化步骤分散注意力。先把核心概念搞清楚，然后再学新 API 也不迟。

但如果你在写生产环境的代码，或者需要管理多个设备，或者需要系统集成，那新 API 绝对是更合适的选择。虽然代码量多一些，但带来的好处是值得的。

## 下一步做什么

这一章我们从整体上讲了新 API 的设计理念和优势。但知道理念还不够，我们还需要了解具体的实现细节。

下一章我们会深入学习 `struct cdev` 结构体和设备号管理。你会了解到 `cdev` 的每个字段是干什么的，设备号的宏怎么用，动态分配和静态注册的区别是什么。

再往后，我们会学习 class 和 device 模型，了解内核是怎么管理设备层次结构的，以及 sysfs 是怎么工作的。

这些知识可能看起来有点枯燥，但它们是理解现代 Linux 驱动框架的基础。就像盖房子一样，先把地基打好，后面的事情就顺理成章了。

**相关文档**：
- [老 API 字符设备驱动](06_legacy_chardev.md)
- [cdev 结构体与设备号管理](13_cdev_and_device_number.md)
- [class 和 device 模型](14_class_device_model.md)
