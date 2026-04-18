# 内核模块机制 - Linux 的插件系统

## 前言：模块到底是什么

在前面的章节中，我们一直在说"内核模块"这个词，但从来没有深入解释：**到底什么是内核模块？为什么需要它？它是如何工作的？**

这一章，我们要揭开内核模块的神秘面纱。说实话，理解模块机制很重要，因为这是我们开发驱动的基础。如果你不知道模块是怎么加载和卸载的，写起代码来就会感觉在云里雾里。

## 静态编译 vs 动态加载：从重启到热插拔

在 Linux 的早期，内核是一个单一的、庞大的可执行文件。你想添加新功能？没问题，但代价很大。你得修改内核源码，重新编译整个内核，然后重启系统。这个过程耗时很长，而且很烦人。每次改一行代码都要重启，这个开发效率真的让人血压拉满。

后来，内核开发者引入了**模块（Module）**机制，允许在运行时动态地加载和卸载代码。这就像是给内核装上了一个"插件系统"。

你可以把模块理解成一个内核插件。它是一段编译好的内核代码，可以在系统运行时插入内核，也可以在不需要时移除。整个过程不需要重启系统，就像你在浏览器里安装和卸载扩展一样方便。

这个机制对驱动开发特别重要。想象一下，如果你每次修改驱动代码都要重启系统，那调试起来得有多痛苦。有了模块机制，你只需要卸载旧模块，加载新模块，几秒钟就能完成测试。这对开发效率的提升是巨大的。

## 模块的生命周期：从加载到卸载

一个内核模块从诞生到消亡，会经历几个阶段。理解这个生命周期对于编写正确的驱动至关重要。我们先从整体上看一遍流程。

首先是编译阶段。你写的源码（.c 文件）通过内核构建系统编译成一个 .ko 文件（Kernel Object）。这个文件包含了模块的代码、元数据、符号信息等等。

然后是加载阶段。用户执行 `insmod` 命令，内核读取 .ko 文件，解析 ELF 格式，重定位符号地址，解析模块依赖，最后调用模块的初始化函数。如果初始化函数返回 0，加载成功；否则加载失败。

接下来是运行阶段。模块在这个阶段响应系统调用、处理中断、管理设备和数据。这个阶段可能持续几秒，也可能持续几天，取决于你的需求。

最后是卸载阶段。用户执行 `rmmod` 命令，内核检查模块的引用计数。如果引用计数为 0，内核调用模块的清理函数，释放内存，完全移除模块。

这个生命周期看起来简单，但每个阶段都有需要注意的细节。我们来一步步拆解。

## module_init 和 module_exit：入口和出口

在模块代码里，你会看到两个奇怪的宏：`module_init()` 和 `module_exit()`。这两个宏是模块机制的核心。

`module_init()` 的作用是告诉内核："这个函数是初始化函数，加载模块时调用它"。`module_exit()` 则告诉内核："这个函数是清理函数，卸载模块时调用它"。

这两个函数的写法有固定的套路。初始化函数必须用 `__init` 宏标记，返回 `int`，成功返回 0，失败返回负数错误码。清理函数用 `__exit` 宏标记，返回 `void`，因为它不需要也不能失败。

```c
static int __init my_module_init(void) {
    printk(KERN_INFO "Module is loading\n");
    // 做初始化工作
    return 0;  // 返回 0 表示成功
}

static void __exit my_module_exit(void) {
    printk(KERN_INFO "Module is unloading\n");
    // 做清理工作
}

module_init(my_module_init);
module_exit(my_module_exit);
```

这里有个有趣的细节。`__init` 和 `__exit` 宏不仅仅是标记，它们还会把代码放到特殊的 ELF 段里。`__init` 段的代码在初始化完成后会被释放掉，节省内存。`__exit` 段的代码在模块被编译进内核（而不是作为模块）时会被完全丢弃，因为这种情况下模块永远不会被"卸载"。

## 模块参数：运行时配置

还记得我们在前面看到的 `debug_level` 参数吗？

```bash
insmod modern_print_kernel_base00_driver.ko debug_level=2
```

这就是模块参数，它允许在加载模块时传递配置信息。这个机制真的很实用，你可以用同一个模块二进制文件，通过不同的参数实现不同的行为，不用重新编译。

定义模块参数的套路也很固定。首先定义一个变量作为参数的存储，然后用 `module_param()` 宏注册它。你还可以用 `MODULE_PARM_DESC()` 添加参数说明。

```c
static int debug_level = 1;  // 默认值
module_param(debug_level, int, 0644);
MODULE_PARM_DESC(debug_level, "Debug level (0=none, 1=info, 2=debug)");
```

`module_param()` 的第二个参数是类型。常用的类型有 `int`（整数）、`bool`（布尔值）、`charp`（字符串指针）。第三个参数是权限，它决定这个参数是否在 sysfs 中可见，以及是否可以修改。

权限参数的含义和文件的权限位一样。`0` 表示不在 sysfs 中显示，`0444` 表示只读，`0644` 表示 root 可写其他人只读。如果你希望参数可以在运行时修改，就用 `0644`。

加载模块后，你可以通过 sysfs 修改参数。这个功能在调试时特别有用，你可以动态调整日志级别，不用卸载模块重新加载。

```bash
# 查看当前参数值
cat /sys/module/my_module/parameters/my_param

# 动态修改参数
echo 10 > /sys/module/my_module/parameters/my_param
```

## 模块依赖：不是孤岛

模块不是孤立的，它们之间可能存在依赖关系。比如你的驱动用到了 USB 核心的功能，那它就依赖 `usbcore` 模块。如果依赖不满足，模块加载会失败。

查看模块依赖用 `modinfo` 命令。它会列出模块的元数据，包括依赖哪些其他模块。

```bash
modinfo my_module.ko
# 输出：
# filename:       my_module.ko
# description:    My test driver
# license:        GPL
# depends:        usbcore
# vermagic:       6.12.49 SMP mod_unload modversions
```

说到加载命令，这里有个常见的问题：`insmod` 和 `modprobe` 有什么区别？两者都能加载模块，但 `modprobe` 更智能。它会自动处理依赖关系，如果模块依赖 `usbcore`，`modprobe` 会先加载 `usbcore` 再加载你的模块。`insmod` 就不会这么贴心，你得自己手动按顺序加载。

## 引用计数：防止误卸载

内核通过**引用计数**来跟踪模块的使用情况，防止模块还在被使用时被误卸载。这个机制真的很重要，我见过太多新手因为忘记管理引用计数，导致系统崩溃。

引用计数的原理很简单。每次有对象"使用"模块时，计数加 1；每次"停止使用"时，计数减 1。只有当计数为 0 时，模块才能被卸载。

对于字符设备驱动，"使用"通常对应应用程序打开设备文件。所以你在 `open` 函数里要增加引用计数，在 `release` 函数里要减少引用计数。

```c
static int my_open(struct inode *inode, struct file *filp) {
    try_module_get(THIS_MODULE);  // 增加引用计数
    return 0;
}

static int my_release(struct inode *inode, struct file *filp) {
    module_put(THIS_MODULE);      // 减少引用计数
    return 0;
}
```

如果引用计数不为 0 时尝试卸载模块，`rmmod` 会失败并报错："Module is in use"。这个保护机制可以防止应用程序还在使用设备时驱动被卸载，那会导致不可预测的行为。

## 模块元数据：MODULE_* 宏

在模块代码里，你会看到很多 `MODULE_*` 宏。这些宏用于在模块中嵌入元数据信息。

`MODULE_LICENSE()` 是必需的。如果模块没有声明许可证，内核会拒绝加载，并在 `dmesg` 中留下警告："module license 'unspecified' taints kernel"。内核这么做的原因是，有些内核函数只能被 GPL 许可证的代码使用，闭源驱动不能调用这些函数。

常用的许可证有 `"GPL"`、`"GPL v2"`、`"Dual BSD/GPL"`。如果你写的是闭源驱动，用 `"Proprietary"`，但会被标记为"污染内核"。

其他元数据宏是可选的，但推荐都写上。`MODULE_AUTHOR()` 说明作者，`MODULE_DESCRIPTION()` 描述模块功能，`MODULE_VERSION()` 标记版本号。这些信息都会出现在 `modinfo` 的输出里，对维护很有帮助。

```c
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name <email@example.com>");
MODULE_DESCRIPTION("Brief description of the module");
MODULE_VERSION("1.0");
```

## 版本控制：vermagic 的坑

你可能注意到了 `modinfo` 输出中的 `vermagic` 字段。这是内核的版本控制机制，也是新手常踩的坑。

`vermagic`（version magic）是一个字符串，描述了模块编译时的内核版本和配置。如果模块编译时的内核版本和运行时的内核版本不一致，加载会失败。错误信息大概是："disagrees about version of symbol module_layout"。

这个问题的原因很简单：内核内部数据结构可能在不同版本间发生变化。用老版本编译的模块试图访问新版本的内核结构，可能会导致内存错乱。所以内核干脆拒绝加载不匹配的模块。

解决方法是重新编译。确保你的模块用当前内核的源码树编译，`make` 命令会自动处理版本匹配。当然，你可以用 `--force` 强制加载，但千万别这么干，那是在玩火。

## insmod 和 rmmod 的内部流程

我们来深入了解一下 `insmod` 和 `rmmod` 的底层机制。虽然理解这些不是开发驱动的必需，但知道底层发生了什么，有助于调试问题。

`insmod` 的内部流程是这样的：用户空间的 `insmod` 命令读取 .ko 文件，然后发起 `finit_module` 系统调用。内核接管后，首先验证模块签名（如果启用了模块签名），然后检查版本兼容性。接着分配内核内存，重定位符号地址（把代码里对内核函数的引用解析成实际地址），解析模块依赖，调用 `module_init` 指定的初始化函数，最后创建 sysfs 条目。如果任何一步失败，整个加载过程回滚，模块不会被加载。

`rmmod` 的流程相对简单：用户空间的 `rmmod` 命令发起 `delete_module` 系统调用。内核首先检查模块的引用计数，如果计数不为 0，直接返回错误。如果计数为 0，调用 `module_exit` 指定的清理函数，移除 sysfs 条目，释放模块占用的内存。

知道这些流程后，你就明白为什么有些错误会发生了。比如"Unknown symbol"错误，是因为符号重定位失败——你的模块用到了一个不存在的内核函数。"Module is in use"错误，是因为引用计数不为 0。

## 一个完整的模块示例

让我们把上面的知识串起来，看一个完整的模块示例。这个模块不做什么实际的事，只是演示模块机制的基本框架。

```c
#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>

// 模块参数
static int my_param = 1;
module_param(my_param, int, 0644);
MODULE_PARM_DESC(my_param, "My integer parameter");

// 模块元数据
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A complete module example");
MODULE_VERSION("1.0");

// 初始化函数
static int __init my_module_init(void) {
    printk(KERN_INFO "Module loading...\n");
    printk(KERN_INFO "Parameter my_param = %d\n", my_param);

    // 初始化工作
    printk(KERN_INFO "Module loaded successfully!\n");
    return 0;
}

// 退出函数
static void __exit my_module_exit(void) {
    printk(KERN_INFO "Module unloading...\n");
    printk(KERN_INFO "Module unloaded successfully!\n");
}

module_init(my_module_init);
module_exit(my_module_exit);
```

这个例子包含了模块的基本框架。编译、加载、卸载的流程前面讲过了，这里不再重复。但你应该能看出来，模块开发的核心就是编写 `init` 和 `exit` 两个函数，其他的都是辅助机制。

## 小结

这一章我们深入学习了内核模块机制。从概念上讲，模块是内核的"插件系统"，允许运行时动态加载代码。从实现上讲，模块通过 `module_init`/`module_exit` 宏定义入口和出口函数，通过 `MODULE_*` 宏声明元数据，通过引用计数防止误卸载。

模块机制对驱动开发特别重要。它让我们可以快速迭代代码，不用每次修改都重启系统。模块参数机制提供了运行时配置能力，同一个二进制文件可以适应不同的使用场景。

理解了模块机制，你就可以开始写真正的驱动了。下一章我们会讲内核调试技术，这对驱动开发同样重要。说实话，驱动开发离不开调试，你会花大量时间在 `dmesg` 里找线索。

**继续阅读：** [04_kernel_print_guide.md](04_kernel_print_guide.md) 了解内核打印和日志机制，或者跳到 [06_legacy_chardev.md](06_legacy_chardev.md) 看实战代码。
