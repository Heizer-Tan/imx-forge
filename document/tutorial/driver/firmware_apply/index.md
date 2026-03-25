# 固件应用

在 Linux 驱动中加载和使用固件文件。

---

## 📚 主要内容

- **[固件加载](firmware.md)** —— 固件加载详解

---

## 🎯 学习目标

完成本章节后，你将：

- ✅ 理解 Linux 固件加载机制
- ✅ 掌握 request_firmware API
- ✅ 了解固件文件存放位置
- ✅ 能够在驱动中加载固件

---

## 📖 快速示例

```c
#include <linux/firmware.h>

static int my_driver_probe(struct device *dev)
{
    const struct firmware *fw;
    int ret;

    ret = request_firmware(&fw, "my_firmware.bin", dev);
    if (ret) {
        dev_err(dev, "Failed to load firmware\n");
        return ret;
    }

    // 使用固件数据
    process_firmware(fw->data, fw->size);

    release_firmware(fw);
    return 0;
}
```

---

## 📂 固件位置

```
/lib/firmware/
├── my_firmware.bin
└── ...
```

---

## ➡️ 返回

返回 **[驱动开发](../)**
