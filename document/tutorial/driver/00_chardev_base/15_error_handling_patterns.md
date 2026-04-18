# 驱动错误处理模式 - 当资源分配失败时该怎么办

## 前言：内核代码的容错哲学

在用户空间写程序的时候，我们经常会偷懒。malloc 失败了？不管了，大概率不会发生。文件打开失败？打印个错误然后继续。但在内核空间，这种偷懒的态度是绝对不允许的。内核是系统的核心，它的每一个错误都可能导致整个系统崩溃。而且内核的错误处理比用户空间要困难得多——你不能简单地退出进程，因为内核没有"进程退出"这个概念；你不能抛出异常，因为内核不支持异常机制。

所以内核开发者形成了一套成熟的错误处理模式。这套模式虽然在应用层看起来有点"反直觉"（比如大量使用 goto），但在内核环境中它是最有效、最安全的做法。这一章我们就来学习这套模式。

## 错误指针：用指针传递错误码

在内核中，函数返回值有两种常见的约定：返回整数和返回指针。返回整数的函数通常用 0 表示成功，负数表示错误码。返回指针的函数通常用有效指针表示成功，NULL 表示失败。

但问题来了：如果一个函数既需要返回指针，又需要传递详细的错误码，该怎么办？返回 NULL 只能表示"失败了"，但无法说明为什么失败。

内核的解决方案叫做"错误指针"（Error Pointer）。它的思想是利用内核地址空间的保留区域来编码错误码。内核虚拟地址空间的最后几个页是保留的，永远不会分配给有效数据。内核可以把错误码存储在这些保留地址中，然后返回这个特殊的指针。

这里涉及到三个核心宏：`ERR_PTR()`、`PTR_ERR()` 和 `IS_ERR()`。

`ERR_PTR()` 把错误码转换成错误指针：

```c
void *p = ERR_PTR(-ENOMEM);  // p 指向一个特殊的"错误地址"
```

`PTR_ERR()` 从错误指针中提取错误码：

```c
void *p = ERR_PTR(-ENOMEM);
long err = PTR_ERR(p);  // err = -ENOMEM (-12)
```

`IS_ERR()` 判断一个指针是否为错误指针：

```c
struct class *cls = class_create("aes_led");

if (IS_ERR(cls)) {
    long err = PTR_ERR(cls);
    pr_warn("Failed to create class: %ld\n", err);
    return err;
}
```

还有一个变体 `IS_ERR_OR_NULL()`，它同时检查错误指针和 NULL。某些函数可能返回 NULL 表示"没有对象"，返回错误指针表示"发生错误"，这时就需要用这个宏。

## goto 错误处理模式

说实话，当我们在应用层编程时，goto 语句被认为是绝对禁止的。但在内核错误处理中，goto 却是标准做法。为什么？因为内核中的资源分配通常是分步进行的，如果某一步失败，需要清理前面所有步骤分配的资源。不用 goto 的话，代码会变得非常冗余。

让我们看一个例子。驱动初始化通常是这样的流程：

```c
ret = alloc_chrdev_region(...);  // 步骤 1
ret = cdev_add(...);              // 步骤 2
cls = class_create(...);          // 步骤 3
dev = device_create(...);         // 步骤 4
```

如果步骤 3 失败，需要清理步骤 1 和 2。如果步骤 4 失败，需要清理步骤 1、2、3。不用 goto 的话，代码会变成这样：

```c
static int __init test_init(void)
{
    int ret;

    ret = alloc_chrdev_region(&devid, 0, 1, "test");
    if (ret < 0) {
        return ret;
    }

    ret = cdev_add(&cdev, devid, 1);
    if (ret < 0) {
        unregister_chrdev_region(devid, 1);  // 清理步骤 1
        return ret;
    }

    cls = class_create("test");
    if (IS_ERR(cls)) {
        ret = PTR_ERR(cls);
        cdev_del(&cdev);                      // 清理步骤 2
        unregister_chrdev_region(devid, 1);  // 清理步骤 1
        return ret;
    }

    dev = device_create(cls, NULL, devid, NULL, "test");
    if (IS_ERR(dev)) {
        ret = PTR_ERR(dev);
        class_destroy(cls);                   // 清理步骤 3
        cdev_del(&cdev);                      // 清理步骤 2
        unregister_chrdev_region(devid, 1);  // 清理步骤 1
        return ret;
    }

    return 0;
}
```

看到问题了吗？每增加一个步骤，每个错误处理分支就需要多写一行清理代码。如果有 10 个步骤，你就得写 10 行清理代码，而且每个分支都不同。这种代码维护起来是噩梦，很容易漏掉某个清理步骤。

用 goto 重写后，代码就清爽多了：

```c
static int __init test_init(void)
{
    int ret;

    /* 步骤 1：申请设备号 */
    ret = alloc_chrdev_region(&devid, 0, 1, "test");
    if (ret < 0) {
        return ret;  // 无需清理
    }

    /* 步骤 2：添加 cdev */
    ret = cdev_add(&cdev, devid, 1);
    if (ret < 0) {
        goto failed_cdev;  // 清理步骤 1
    }

    /* 步骤 3：创建类 */
    cls = class_create("test");
    if (IS_ERR(cls)) {
        ret = PTR_ERR(cls);
        goto failed_class;  // 清理步骤 2、1
    }

    /* 步骤 4：创建设备 */
    dev = device_create(cls, NULL, devid, NULL, "test");
    if (IS_ERR(dev)) {
        ret = PTR_ERR(dev);
        goto failed_device;  // 清理步骤 3、2、1
    }

    return 0;

/* 清理标签（逆序） */
failed_device:
    class_destroy(cls);
failed_class:
    cdev_del(&cdev);
failed_cdev:
    unregister_chrdev_region(devid, 1);
    return ret;
}
```

这里的关键是 goto 标签的组织方式。标签按清理顺序逆序排列，每个标签负责清理到此为止的所有资源。如果失败发生在步骤 3，我们跳转到 `failed_class`，它会清理步骤 2，然后自动落到 `failed_cdev` 清理步骤 1。

这种模式的美妙之处在于，无论在哪个步骤失败，只需要一个 goto 语句，所有必要的清理都会自动完成。添加新步骤时，只需要在现有代码中插入新的分配和对应的标签，不需要修改已有的错误处理代码。

## 逆序清理原则

我们在上一章提到过逆序清理，这里再深入讲一下。为什么要逆序清理？因为资源之间可能存在依赖关系。后创建的资源可能持有对先创建资源的引用。如果你先销毁被依赖的资源，依赖它的资源就会处于不一致的状态。

```
创建顺序：alloc_chrdev_region → cdev_add → class_create → device_create
                                                           ↑
                                                        失败点

清理顺序：class_destroy ← cdev_del ← unregister_chrdev_region
           (步骤3)     (步骤2)        (步骤1)
```

在这个例子中，device 依赖 class（它必须在某个 class 下），class 依赖 cdev 的存在（虽然不是直接依赖，但逻辑上它们是一个整体）。所以清理时必须先销毁 device，再销毁 class，最后清理 cdev 和设备号。

## 真实驱动代码示例

让我们看看实际驱动中的错误处理是怎么写的。这是我们的 LED 驱动的初始化函数：

```c
static int init_led_handle(struct IMXAesLED *led_handle)
{
    int ret;

    pr_info("Init the User Interfaces and driver handles\n");

    /* 步骤 1：申请设备号 */
    ret = alloc_chrdev_region(&led_handle->devid, 0, LED_CNT, CHARDEV_NAME);
    if (ret < 0) {
        pr_warn("Failed to alloc chrdev region: %d\n", ret);
        return ret;  // 无需清理
    }

    /* 打印分配结果 */
    {
        const int major = MAJOR(led_handle->devid);
        const int minor = MINOR(led_handle->devid);
        pr_info("LED handle get the device number: major: %d, minor: %d\n",
                major, minor);
    }

    /* 步骤 2：初始化并添加 cdev */
    led_handle->char_device_handle.owner = THIS_MODULE;
    cdev_init(&led_handle->char_device_handle, &fops);

    ret = cdev_add(&led_handle->char_device_handle,
                   led_handle->devid, LED_CNT);
    if (ret < 0) {
        pr_warn("Error when trying to make a cdev in kernel: %d\n", ret);
        goto failed_cdev;  // 清理设备号
    }

    pr_info("cdev series api called success!\n");

    /* 步骤 3：创建类 */
    led_handle->char_device_class = class_create(CHARDEV_NAME);
    if (IS_ERR(led_handle->char_device_class)) {
        ret = PTR_ERR(led_handle->char_device_class);
        pr_warn("Failed to create a class, code: %ld\n", ret);
        goto failed_class;  // 清理 cdev、设备号
    }

    pr_info("class create success!\n");

    /* 步骤 4：创建设备 */
    led_handle->char_device_device =
        device_create(led_handle->char_device_class, NULL,
                      led_handle->devid, NULL, CHARDEV_NAME);
    if (IS_ERR(led_handle->char_device_device)) {
        ret = PTR_ERR(led_handle->char_device_device);
        pr_warn("Failed to create a device, code: %ld\n", ret);
        goto failed_device;  // 清理 class、cdev、设备号
    }

    pr_info("device create success!\n");
    return 0;

/* 清理标签（逆序） */
failed_device:
    class_destroy(led_handle->char_device_class);
failed_class:
    cdev_del(&led_handle->char_device_handle);
failed_cdev:
    unregister_chrdev_region(led_handle->devid, LED_CNT);
    return ret;
}
```

对应的清理函数就简单多了，直接按逆序销毁所有资源：

```c
static void release_led_handle(struct IMXAesLED *led_handle)
{
    /* 逆序清理 */
    device_destroy(led_handle->char_device_class,
                   led_handle->devid);
    class_destroy(led_handle->char_device_class);
    cdev_del(&led_handle->char_device_handle);
    unregister_chrdev_region(led_handle->devid, LED_CNT);
}
```

## file_operations 中的错误处理

除了初始化函数，file_operations 中的回调函数也需要正确处理错误。这里的情况稍有不同，因为这些函数直接与用户空间交互，返回值会被用户程序看到。

```c
static ssize_t aes_chardev_write(struct file *filp, const char __user *buf,
                                 size_t cnt, loff_t *offt)
{
    pr_info("aes_chardev_write: cnt=%zu\n", cnt);

    /* 防御性编程：限制输入大小 */
    if (cnt > 2) {
        pr_warn("Get the unexpected data, thats to more!\n");
        return -EINVAL;
    }

    /* 从用户空间拷贝数据 */
    char user_led_new_status = 0;
    const auto kResult = copy_from_user(&user_led_new_status, buf, 1);
    if (kResult != 0) {
        pr_warn("Failed to set the led status from user! code: %ld\n", kResult);
        return -EFAULT;
    }

    /* ... 其他操作 ... */

    return 1;  // 返回写入的字节数
}
```

这里有几个关键点。第一，永远不要信任用户输入。用户提供的 `cnt` 可能是任何值，必须检查它是否在合理范围内。第二，`copy_from_user()` 和 `copy_to_user()` 的返回值是"未能拷贝的字节数"，而不是"成功拷贝的字节数"。如果完全成功，它们返回 0；如果失败，返回一个非零值。所以检查时应该用 `!= 0` 而不是 `< 0`。

返回值的语义也很重要。`write()` 应该返回成功写入的字节数，如果发生错误则返回负的错误码。`read()` 也是类似的。用户程序根据返回值判断操作是否成功，如果返回值搞错了，用户程序的行为就会不正确。

## 常见错误码

内核定义了大量的错误码，但我们只需要掌握几个最常用的：

`-EINVAL`（Invalid Argument）表示参数无效。当用户提供的参数不符合预期范围或类型时，返回这个错误码。比如我们的 write 函数检查到数据长度超过 2 字节，就返回 `-EINVAL`。

`-EFAULT`（Bad Address）表示地址错误。通常在 `copy_from_user` 或 `copy_to_user` 失败时使用。这意味着用户空间指针无效，可能是 NULL、指向不可访问的内存，或者页面错误。

`-ENOMEM`（Out of Memory）表示内存不足。当 kmalloc 或其他内存分配函数失败时使用。`alloc_chrdev_region` 失败也可能返回这个错误码，表示设备号已经耗尽。

`-ENODEV`（No such Device）表示设备不存在。当用户尝试访问一个不存在的次设备号时，返回这个错误码。

`-EBUSY`（Device or Resource Busy）表示设备或资源忙。当设备号冲突或资源已被占用时使用。`register_chrdev_region` 失败很可能返回这个错误码。

`-EPERM`（Operation Not Permitted）表示操作不允许。通常是权限问题或安全限制。

这些错误码的定义在 `include/uapi/asm-generic/errno.h` 中，如果需要查看完整的错误码列表，可以去这个文件里找。

## 防御性编程

内核代码必须采用防御性编程的态度。永远不要假设输入是合法的，永远不要假设资源分配会成功，永远不要假设硬件会按预期工作。

输入验证是第一步。对于从用户空间传入的参数，必须检查它们的合法性。指针是否可能为 NULL？大小是否在合理范围内？标志位组合是否有效？这些检查可能看起来很繁琐，但它们能避免很多安全问题。

边界检查也很重要。数组访问前检查索引，字符串操作前检查长度，数值运算前检查溢出。内核中的缓冲区溢出不仅仅是程序崩溃，它可能被利用来提权，所以必须严肃对待。

资源泄漏预防是另一个重点。每一个分配的资源（内存、设备号、锁等）都必须有对应的释放路径。goto 错误处理模式正是为此设计的。如果你在某个错误路径上忘记清理资源，长时间运行后系统资源会耗尽。

## 本章小结

内核错误处理有一套成熟的模式，虽然它在某些方面与应用层编程的习惯不同，但它是内核环境中最有效、最安全的做法。

错误指针机制让返回指针的函数也能传递详细的错误码。`IS_ERR()`、`PTR_ERR()`、`ERR_PTR()` 这三个宏是内核错误处理的基础工具，必须熟练掌握。

goto 错误处理模式虽然在应用层被认为是反模式，但在内核中却是标准做法。它让代码简洁、清理逻辑集中、易于维护。逆序清理原则不是某种约定，而是资源依赖关系的必然要求。

防御性编程是内核开发的必修课。永远不要信任输入，永远做好错误处理，永远记得释放资源。这些原则看起来很繁琐，但当错误发生时，它们能救你的命。

下一章我们会学习新 API 中的设备结构体封装，看看如何用面向对象的思想组织驱动代码。你会发现，良好的结构设计能让错误处理变得更简单。

---

**相关文档：**
- [class 和 device 模型](14_class_device_model.md)
- [新 API 中的设备结构体](16_device_structure_in_new_api.md)
