# 字符设备驱动实现 - 让用户空间能玩硬件

前面几章我们把硬件相关的操作都封装到了硬件抽象层里。现在要做的事情，就是把这些硬件能力通过字符设备的接口暴露给用户空间。用户程序可以通过 `open()` 打开设备文件，通过 `write()` 发送控制命令，通过 `read()` 查询 LED 状态，最后通过 `close()` 关闭设备。这一章我们会分析 `chardev_led_v1_01_main.c` 的完整实现，看看字符设备驱动是怎么组织的，以及如何和硬件抽象层集成。

我们的主驱动文件结构大致是这样的：

```c
// 头文件包含
#include "led_hw.h"           // 硬件抽象层接口
#include "linux/fs.h"         // 文件操作相关
#include "linux/printk.h"     // 内核打印
#include "linux/uaccess.h"    // 用户空间访问
// ... 其他头文件

// 设备标识
static const char* CHARDEV_NAME = "AES_LED";
static const int CHARDEV_MAJOR = 200;

// 文件操作函数
static int aes_chardev_open(struct inode* inode, struct file* filp);
static ssize_t aes_chardev_read(struct file* filp, char __user* buf, size_t cnt, loff_t* offt);
static ssize_t aes_chardev_write(struct file* filp, const char __user* buf, size_t cnt, loff_t* offt);
static int aes_chardev_release(struct inode* inode, struct file* filp);

// 文件操作结构
static struct file_operations fops = { ... };

// 模块初始化/退出
static int __init chardev_led_v1_01_init(void);
static void __exit chardev_led_v1_01_exit(void);
```

这是一个非常标准的字符设备驱动模板。如果你以后要写其他字符设备驱动，基本也是这个结构。

我们先来看最简单的 `open()` 函数：

```c
static int aes_chardev_open(struct inode* inode, struct file* filp) {
    pr_info("Device: %s called open!\n", CHARDEV_NAME);
    return 0;
}
```

这是最简单的一个函数。它的作用是在用户打开设备文件时被调用，做一些必要的初始化工作。但对于我们的 LED 驱动来说，硬件初始化已经在模块加载时完成了（通过 `led_hw_init()`），所以这里不需要做任何额外的事情，只是打印一条日志记录一下。

你可能想知道 `inode` 和 `filp` 这两个参数是什么。`inode` 包含了文件的元数据信息，从这里可以获取设备号。`filp`（file pointer）代表了这次打开操作的文件实例，我们可以用它来存储一些私有数据。但我们的驱动很简单，不需要这些，所以这两个参数都没有使用。`open()` 的返回值是 int 类型，0 表示成功，负数表示错误。如果你返回一个负数，用户空间的 `open()` 调用会失败，并设置 errno。这里的 0 表示成功打开设备。

接下来是 `read()` 函数：

```c
static ssize_t aes_chardev_read(struct file* filp, char __user* buf, size_t cnt, loff_t* offt) {
    if (*offt > 0) {
        return 0;  // EOF，防止 cat 无限读取
    }

    if (cnt > 1) {
        cnt = 1;  // 我们只提供一个字节的状态
    }

    *offt += cnt;

    const bool led_status = led_get_status();
    const char user_indication = led_status ? '1' : '0';

    const auto kResult = copy_to_user(buf, &user_indication, cnt);
    if (kResult != 0) {
        pr_warn("Failed to pass the led status to user! code: %ld\n", kResult);
        return -EFAULT;
    }

    return cnt;
}
```

这个函数的工作是：当用户读取设备文件时，返回 LED 的当前状态。我们用字符 `'1'` 表示点亮，`'0'` 表示熄灭。有几个细节值得注意。

`*offt > 0` 的判断是为了防止 `cat` 这样的程序无限循环读取。`cat` 每次读到数据后会继续读，直到遇到 EOF（返回 0）。我们的设备只提供一个字节的状态，读一次就够了，所以当偏移量大于 0 时直接返回 0，告诉用户空间"没数据了"。

如果用户请求读取的数据量大于 1，我们只返回 1 个字节。这是因为 LED 状态只有一个字节，多返回没有意义。

你可能会想，为什么不用 `memcpy(buf, &user_indication, cnt)`？因为 `buf` 指向的是用户空间内存，而内核代码不能直接访问用户空间内存。原因有很多：用户空间指针可能是无效的、用户空间内存可能被换出、直接访问可能绕过安全检查等等。正确的做法是使用 `copy_to_user()`，这个函数会做所有的安全检查，并且在出错时返回未拷贝的字节数。如果返回值不是 0，说明拷贝失败了，我们返回 `-EFAULT` 表示错误。

然后是 `write()` 函数：

```c
static ssize_t aes_chardev_write(struct file* filp, const char __user* buf, size_t cnt,
                                 loff_t* offt) {
    pr_info("aes_chardev_write: cnt=%zu\n", cnt);

    if (cnt > 2) {
        pr_warn("Get the unexpected data, that's too much!\n");
        return -EINVAL;
    }

    char user_led_new_status = 0;
    const auto kResult = copy_from_user(&user_led_new_status, buf, 1);
    if (kResult != 0) {
        pr_warn("Failed to set the led status from user! code: %ld\n", kResult);
        return -EFAULT;
    }

    const bool led_new_status = (user_led_new_status == '1');
    pr_info("LED status: %d (user_led_new_status='%c')\n", led_new_status, user_led_new_status);
    led_set_status(led_new_status);
    return 1;
}
```

这个函数接收用户空间发来的控制命令，并调用硬件抽象层的 `led_set_status()` 来实际控制 LED。我们只接受 1-2 个字节的数据，如果用户写了太多数据，返回 `-EINVAL` 表示参数错误。这其实是一个简化的处理，严格来说应该更灵活一点，但对于 LED 控制这个场景来说足够了。

和 `copy_to_user()` 类似，从用户空间拷贝数据也必须使用专门的函数。`copy_from_user()` 会做安全检查，返回未拷贝的字节数。如果返回值不是 0，说明拷贝失败。我们设计的协议很简单：用户写入字符 `'1'` 点亮 LED，写入其他任何字符（通常用 `'0'`）熄灭 LED。这个协议虽然简单，但很实用，而且容易扩展——如果将来需要支持亮度调节，可以增加 `'2'`、`'3'` 等命令。

`release()` 函数更简单：

```c
static int aes_chardev_release(struct inode* inode, struct file* filp) {
    pr_info("Device: %s called close!\n", CHARDEV_NAME);
    return 0;
}
```

当用户关闭设备文件时这个函数被调用。我们的驱动不需要做任何清理工作，因为硬件资源是在模块卸载时统一释放的，而不是每次关闭设备时释放。所以这里只是打印一条日志。

我们把这些函数组织成 `file_operations` 结构：

```c
static struct file_operations fops = {
    .owner = THIS_MODULE,
    .open = aes_chardev_open,
    .read = aes_chardev_read,
    .write = aes_chardev_write,
    .release = aes_chardev_release,
};
```

这个结构告诉内核：当用户对我们的设备文件执行各种操作时，应该调用哪些函数。`.owner = THIS_MODULE` 这一行很重要，它告诉内核这个结构属于哪个模块，用于模块引用计数管理。你可能注意到了，我们没有实现 `llseek()`、`ioctl()`、`mmap()` 等操作。这对于 LED 驱动来说没关系，因为我们不需要这些功能。如果用户尝试这些操作，内核会返回默认的错误代码（通常是 `-ENOSYS` 或 `-EINVAL`）。

模块初始化和退出函数：

```c
static int __init chardev_led_v1_01_init(void) {
    led_hw_init();  // 先初始化硬件
    const int kResult = register_chrdev(CHARDEV_MAJOR, CHARDEV_NAME, &fops);
    if (kResult != 0) {
        pr_warn("Failed to register the chardev region! kResult=%d\n", kResult);
        return kResult;
    }

    pr_info("%s load successfully!\n", CHARDEV_NAME);
    return kResult;
}

static void __exit chardev_led_v1_01_exit(void) {
    pr_info("=== chardev_led_v1_01 rmmod progress ===\n");
    led_hw_deinit();           // 先清理硬件
    unregister_chrdev(CHARDEV_MAJOR, CHARDEV_NAME);  // 再注销设备
    pr_info("========================\n");
}
```

初始化时我们做两件事：先初始化硬件，然后注册字符设备。这里用的是 `register_chrdev()` 这个 legacy API，所以只需要一行代码就完成了注册。如果注册失败，打印错误信息并返回错误码，这样模块加载会失败。一定要先初始化硬件，再注册设备。如果顺序反了，可能出现这种情况：设备注册成功了，用户空间马上开始操作，但硬件还没初始化好，就会出问题。虽然在这个简单的驱动里不太可能发生，但养成正确的顺序习惯很重要。

退出时我们做的和初始化相反：先清理硬件资源，再注销设备。顺序和初始化时相反，这是一个通用的原则——先建立的资源后释放，后建立的资源先释放。

你可能已经注意到了，整个字符设备层对硬件的访问只有三个地方：

```c
led_hw_init();    // 初始化时调用
led_set_status(); // write() 里调用
led_get_status(); // read() 里调用
```

这就是分层设计的好处。字符设备层完全不需要知道寄存器地址、时钟配置、引脚复用这些细节，只需要调用硬件抽象层提供的接口。如果将来硬件改了，只需要修改硬件抽象层，字符设备层的代码一行都不用动。

驱动写好之后，用户空间怎么使用呢？首先需要创建设备节点：

```bash
mknod /dev/led c 200 0
```

这条命令创建了一个字符设备文件（c），主设备号是 200，次设备号是 0。主设备号 200 必须和我们在驱动里注册的一致（`CHARDEV_MAJOR = 200`）。然后就可以用普通文件操作来控制 LED 了：

```bash
# 点亮 LED
printf '1' > /dev/led

# 熄灭 LED
printf '0' > /dev/led

# 查询状态
cat /dev/led
```

还可以用 C 程序来操作，就像操作普通文件一样：

```c
int fd = open("/dev/led", O_RDWR);
write(fd, "1", 1);  // 点亮
char status;
read(fd, &status, 1);  // 读取状态
close(fd);
```

到这里，我们的 LED 驱动代码就分析完了。从硬件原理到内存映射，从硬件抽象层到字符设备层，我们走完了整个驱动开发流程。下一章，我们会看看如何编译这个驱动，如何把它部署到开发板上，以及如何调试常见问题。
