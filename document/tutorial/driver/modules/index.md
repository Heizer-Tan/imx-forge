# 内核模块开发

Linux 内核模块 (LKM) 是动态加载到内核的代码，是驱动开发的基础。

---

## 📚 章节目录

| 章节 | 标题 | 内容 |
|------|------|------|
| 00 | [模块概述](00_module_overview.md) | 内核模块简介 |
| 01 | [Hello World 模块](01_hello_world_module.md) | 第一个内核模块 |
| 02 | [编译与加载](02_module_build_and_load.md) | 模块构建方法 |
| 03 | [模块参数与调试](03_module_params_and_debug.md) | 参数传递和调试 |
| 04 | [ELF 与 KO 结构](04_elf_and_ko_structure.md) | 模块文件格式 |
| 05 | [insmod 内部机制](05_insmod_internals_advanced.md) | 模块加载深入 |
| 06 | [struct_module 深入](06_struct_module_deep_dive.md) | 模块结构体 |

---

## 🎯 学习目标

完成本章节后，你将：

- ✅ 理解内核模块的概念和作用
- ✅ 能够编写简单的 Hello World 模块
- ✅ 掌握模块的编译、加载和卸载
- ✅ 理解模块参数传递机制
- ✅ 了解 KO 文件的内部结构

---

## 🔧 前置知识

- C 语言基础
- Linux 基本操作
- Makefile 基础

---

## 📖 快速开始

### 最简单的内核模块

```c
// hello.c
#include <linux/module.h>
#include <linux/kernel.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Your Name");
MODULE_DESCRIPTION("A simple Hello World module");

static int __init hello_init(void)
{
    printk(KERN_INFO "Hello, World!\n");
    return 0;
}

static void __exit hello_exit(void)
{
    printk(KERN_INFO "Goodbye, World!\n");
}

module_init(hello_init);
module_exit(hello_exit);
```

### Makefile

```makefile
obj-m += hello.o

all:
    make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
    make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
```

---

## 📖 延伸阅读

- [Linux 内核模块编程指南](https://sysprog21.github.io/lkmpg/)
- [内核模块文档](https://www.kernel.org/doc/html/latest/kbuild/)

---

## ➡️ 返回

返回 **[驱动开发](../)**
