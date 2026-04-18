# 内核打印详解

## 内核里的"printf"去哪了？

当你第一次写内核模块时，最自然的冲动可能是写上一句：

```c
printf("Hello, kernel!\n");  // 编译错误
```

然后你就会得到一个困惑的编译错误：`implicit declaration of function 'printf'`。说实话，第一次看到这个错误的时候，我还以为是自己忘包含头文件了，翻了半天stdio.h才发现问题根本不在这里。

为什么？因为内核里没有标准C库。这不是内核开发者故意刁难你，而是有深刻的技术原因。标准C库（glibc）是为用户空间程序设计的，它依赖用户空间的种种设施，而内核运行在一个完全不同的世界里。所以内核有自己的打印系统——printk。

## printk vs printf：名字的微妙差异

你可能会问，为什么不直接叫kprintf或者kernel_printf，而是叫printk？这不是随意的命名，而是有深意的。printf代表print formatted（格式化打印），而printk代表print kernel（内核打印）。那个k代表kernel，提醒你这不是普通的打印，这是在内核空间的打印。

更重要的是，printk和printf有本质区别。用户空间的printf没有日志级别的概念，但在内核空间，printk必须处理日志级别。这是因为内核的输出目的地是内核日志缓冲区，而不是标准输出，而且内核消息有紧急程度的区分，有些消息需要立即显示到控制台，有些则可以缓冲处理。

## 日志级别：从紧急到调试

Linux内核定义了8个日志级别，每个级别对应不同的紧急程度。从0级的KERN_EMERG（紧急情况，系统不可用）到7级的KERN_DEBUG（调试消息），覆盖了从内核崩溃到详细调试信息的各种场景。说实话，一开始我觉得这么多级别有点过度设计了，但当你真正在调试一个复杂的驱动问题时，你会感谢内核开发者提供了这么细粒度的控制。

让我们看看modern_print_kernel_base00_driver的实际输出，了解不同日志级别的效果：

```
[  276.787517] EMERGENCY: System is unusable (level 0)
[  276.787526] ALERT: Action must be taken immediately (level 1)
[  276.787534] CRITICAL: Critical conditions occurred (level 2)
[  276.787541] ERROR: Error condition detected (level 3)
[  276.787549] WARNING: Warning condition (level 4)
[  276.787556] NOTICE: Normal but significant condition (level 5)
[  276.787564] INFO: Informational message (level 6)
```

注意最后一行缺少了DEBUG级别的输出。这让我们发现了一个重要的事实：默认的内核日志级别设置会过滤掉DEBUG消息。这一点真的坑了很多新手，包括我自己。你明明在代码里写了pr_debug，但就是看不到输出，以为是代码有问题，结果只是日志级别没设置对。

## pr_*宏：现代化的打印方式

直接使用printk虽然可以，但内核开发者提供了更便利的pr_*宏系列。你对比一下就知道差距了。

```c
// 传统方式
printk(KERN_INFO "Device initialized\n");

// 现代方式
pr_info("Device initialized\n");
```

现代方式明显更简洁，不需要手动添加KERN_XXX前缀。而且pr_*宏还有其他优势：更安全，自动处理格式化字符串；更易读，代码更清晰；支持前缀，可以统一添加模块名前缀。这些优势在大型驱动开发中会越来越明显。

## pr_fmt：统一前缀的魔法

你注意到前面的测试输出中，每条消息都有一个前缀：modern_print_kernel_base00_driver:。这个前缀是怎么来的？答案是pr_fmt宏。

在驱动源码文件的开头定义：

```c
#define pr_fmt(fmt) "MY_DRIVER: " fmt
```

后续所有的pr_*宏都会自动添加这个前缀。在modern_print_kernel_base00_driver中就是这样做的：

```c
#define pr_fmt(fmt) "MODERN_PRINT_KERNEL: " fmt
```

有了这个前缀，日志过滤变得非常简单：

```bash
dmesg | grep MODERN_PRINT_KERNEL
```

调试定位也变得快速得多，你可以马上找到问题发生的模块。在复杂系统中区分不同驱动的输出时，这个前缀的价值就体现出来了。

## 高级打印功能

除了基本的pr_*宏，内核还提供了一些高级打印功能，这些在特定场景下真的能救命。

第一个就是一次性打印（\*_once）。有些消息你只想打印一次，比如初始化信息。如果模块被反复加载卸载，这些消息会重复出现，淹没日志。使用\*_once宏可以解决这个问题：

```c
pr_info_once("This message will only appear once\n");
pr_warn_once("Warning: deprecated API usage\n");
pr_err_once("Critical: configuration error\n");
```

即使多次加载模块，这些消息只出现一次。在我们的测试中，这个特性工作得很好。

第二个是多行连续打印（pr_cont）。有时候你想打印多行相关内容，但每行都加上时间戳和前缀会很乱。使用pr_cont继续上一行，可以让输出更整洁：

```c
pr_info("Multi-line message example:\n");
pr_cont("  - Line 1: Continued line without prefix\n");
pr_cont("  - Line 2: Continued line without prefix\n");
pr_cont("  - Line 3: Continued line without prefix\n");
```

注意pr_cont输出的行没有时间戳和模块名前缀，这样多行输出看起来就像一个整体。

第三个是限速打印（*_ratelimited）。在高频路径中，如果每次都打印，会导致日志洪水。内核会自动限制这类消息的输出频率：

```c
if (some_error_condition) {
    pr_err_ratelimited("Frequent error occurred\n");
}
```

这个特性在处理中断、定时器等高频回调时特别有用，不然你的日志会被瞬间淹没。

## 模块参数：动态控制调试级别

modern_print_kernel_base00_driver演示了一个重要特性：模块参数。你可以这样定义：

```c
static int debug_level = 1;
module_param(debug_level, int, 0644);
MODULE_PARM_DESC(debug_level, "Debug level (0=none, 1=info, 2=debug)");
```

这种机制让你可以在不重新编译模块的情况下，动态调整输出的详细程度。我们对比三种不同参数的输出，效果很明显。

当debug_level=0时，没有"Debug level >= 1"的输出，因为条件不满足。当debug_level=1时，显示基本信息输出。当debug_level=2时，如果启用了DEBUG日志级别，还会显示更详细的调试信息。这种灵活性在实际开发中真的很有用。

## 内核日志级别控制

你可能会问，为什么pr_debug默认不显示？答案是内核日志级别控制。你可以通过以下命令查看当前日志级别：

```bash
cat /proc/sys/kernel/printk
```

输出类似"4 4 1 7"这样四个数字。第一个数字是控制台日志级别，决定了哪些消息显示到控制台。默认值通常是4，所以pr_debug消息不会显示。如果你想看到所有消息，包括DEBUG级别的，可以这样设置：

```bash
echo 8 > /proc/sys/kernel/printk
```

设置完成后重新加载模块，你就能看到DEBUG消息了。这个设置是临时的，重启后会恢复默认值。如果想永久设置，可以修改/etc/sysctl.conf文件。

## 条件编译：DEBUG宏的妙用

除了运行时的日志级别控制，内核还支持编译时的条件编译。pr_debug的行为取决于编译时选项：如果定义了DEBUG，它会被编译为printk(KERN_DEBUG ...)；如果未定义DEBUG，它会被编译为空，完全不生成代码。这个特性让你可以在发布版本中完全移除调试代码，既减小了代码体积，又避免了性能影响。

如何在编译时启用DEBUG？你可以在Makefile中添加：

```makefile
ccflags-y += -DDEBUG
```

或者在编译时传递参数：

```bash
make EXTRA_CFLAGS=-DDEBUG
```

还有一个类似的宏pr_devel，它总是编译为空，除非定义了DEBUG。它比pr_debug更激进，即使在运行时启用DEBUG日志级别也不会显示。

## dmesg的高级用法

dmesg是你最重要的调试工具，内核把所有消息写入一个环形缓冲区，dmesg就是查看这个缓冲区的窗口。除了基本的查看功能，还有一些高级用法值得掌握。

实时监控日志非常有用：

```bash
dmesg -w
```

或者结合过滤使用：

```bash
dmesg -w | grep MODERN_PRINT_KERNEL
```

这样你就能实时看到特定模块的日志输出，不用反复手动执行dmesg命令。

清空日志缓冲区在测试时很有用：

```bash
dmesg -c
insmod my_driver.ko
dmesg
```

先清空，加载模块，然后查看纯净的输出，这样可以避免被其他消息干扰。

查看特定级别的消息：

```bash
dmesg -l err,warn
```

这个命令只显示错误和警告，忽略其他级别的消息。当你只关心错误时，这个过滤功能能帮你快速定位问题。

时间戳显示让日志分析更方便：

```bash
dmesg -T
```

这个参数让时间戳变成人类可读的格式，而不是默认的秒数，方便你理解事件发生的时间顺序。

## 常见错误与最佳实践

在我们踩过无数坑之后，总结了一些常见的错误和最佳实践。

第一个常见错误是忘记添加换行符。你可能会写成这样：

```c
pr_info("Loading module");
pr_info("Initialization complete");
```

结果输出会连在一起："Loading moduleInitialization complete"。一定要记得在每个pr_*调用末尾加上换行符，否则输出会混成一团。

第二个错误是在敏感路径使用printk。在中断处理中使用可能睡眠的函数是危险的，虽然printk通常不会睡眠，但在某些配置下可能会。如果你的驱动在中断上下文中运行，要特别小心。

第三个错误是过度使用pr_debug。在高频循环中使用pr_debug会导致日志洪水，不仅影响性能，还会让日志无法阅读。更好的做法是使用条件打印或pr_debug_ratelimited。

至于最佳实践，我们总结了几条经验。首先，始终使用pr_\*宏，不要直接用printk。其次，添加统一前缀，使用pr_fmt宏。第三，选择合适的日志级别：生产环境主要使用pr_err、pr_warn、pr_info，开发调试时可使用pr_debug，关键错误使用pr_emerg、pr_alert、pr_crit。第四，考虑性能影响，高频路径使用\*_ratelimited。最后，提供上下文，错误消息要详细，包含足够的调试信息，这样你看到日志时能快速定位问题。

## 下一步

到这里，我们已经把内核打印系统讲完了。你现在应该能熟练使用pr_*宏系列，理解日志级别的控制，知道如何通过dmesg查看和分析日志。这些技能在后面的驱动开发中会派上大用场，因为调试驱动很大程度上就是在看日志、分析日志。

接下来我们要学习内核调试技术，了解如何在驱动出问题时系统地排查和定位问题。准备好了吗？
