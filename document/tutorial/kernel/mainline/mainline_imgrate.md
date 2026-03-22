# i.MX6ULL 主线内核 LCD 驱动移植全流程排查指南

> 平台：NXP i.MX6ULL（ARMv7）  
> 内核版本：Linux 7.0.0-rc4（主线）  
> 显示控制器：eLCDIF（`mxsfb`）  
> 屏幕：7 寸 RGB 并行接口 LCD，1024×600  
> 触摸：Goodix GT911（GT9147 兼容）  
> 根文件系统：NFS 挂载

---

## 第一章：背景与升级动机

### 1.1 旧内核（6.12.x）与主线（7.0-rc4）的显示驱动差异

在 NXP 的 BSP 内核（如 6.12.x 分支）中，i.MX6ULL 的 LCD 显示依赖两套体系：

- **旧 Framebuffer 驱动**：`drivers/video/fbdev/mxsfb.c`，对应内核配置 `CONFIG_FB_MXS`
- **设备树 binding**：旧式 `display = <&display0>` + `display@0` 子节点写法

进入主线内核（5.x 以后逐步完成迁移，7.x 彻底切换），eLCDIF 控制器的驱动已迁移至 DRM 子系统：

- **新 DRM 驱动**：`drivers/gpu/drm/mxsfb/mxsfb_drv.c`
- **设备树 binding**：新式 `port → endpoint → remote-endpoint` 图形连接方式

这是本次移植最核心的变化。两套体系在同一内核里同时存在时会产生冲突，且新驱动不认旧式 DT 写法。

---

## 第二章：NFS 根文件系统搭建

在进行 LCD 排查之前，需要先确保开发环境正常：NFS rootfs 启动。

### 2.1 服务端配置

```bash
# 安装 NFS 服务端
sudo apt install nfs-kernel-server

# 将已构建的 rootfs 目录直接导出（推荐，无需额外 bind mount）
echo "/home/charliechen/imx-forge/rootfs/nfs *(rw,sync,no_subtree_check,no_root_squash)" \
  | sudo tee -a /etc/exports

sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

# 验证导出
showmount -e localhost
```

关键选项说明：

| 选项               | 作用                                               |
| ------------------ | -------------------------------------------------- |
| `rw`               | 读写挂载                                           |
| `sync`             | 同步写入，保证数据一致性                           |
| `no_subtree_check` | 禁用子目录校验，提升性能                           |
| `no_root_squash`   | 允许嵌入式设备以 root 身份访问，嵌入式场景必须开启 |

### 2.2 内核启动参数

```
console=ttymxc0,115200
root=/dev/nfs
nfsroot=192.168.60.1:/home/charliechen/imx-forge/rootfs/nfs,vers=3,proto=tcp
rw
ip=192.168.60.200:192.168.60.1:192.168.60.1:255.255.255.0::eth0:off
```

参数格式说明（`ip=` 字段顺序）：

```
ip=<客户端IP>:<服务器IP>:<网关IP>:<子网掩码>::<网卡名>:<自动配置>
```

---

## 第三章：LCD 驱动排查方法论

### 3.1 第一步——读 dmesg，定位关键报错

启动后立即执行：

```bash
dmesg | grep -E "drm|fb|panel|lcdif|mxsfb|display"
```

**本案例的关键报错：**

```
[    1.964868] mxsfb 21c8000.lcdif: error -ENODEV: Cannot connect bridge
```

`-ENODEV` 含义：驱动 probe 时调用 `drm_of_find_panel_or_bridge()` 在设备树里找不到下游的 panel 或 bridge 节点，直接失败返回。

注意：驱动本身加载成功了（说明 compatible 字符串匹配、时钟/pinctrl 都正常），失败点在 DRM 的 panel/bridge 连接环节。

### 3.2 第二步——检查设备树实际生效内容

```bash
# 查看 lcdif 节点下有哪些属性/子节点
ls /proc/device-tree/soc/bus@2100000/lcdif@21c8000/

# 尝试读取 port 连接（如果不存在则说明 DT 写法是旧式的）
cat /proc/device-tree/soc/bus@2100000/lcdif@21c8000/port/endpoint/remote-endpoint
```

**本案例结果：**

```
assigned-clock-parents  display                 pinctrl-names
assigned-clocks         display@0               reg
clock-names             interrupts              status
clocks                  name
compatible              pinctrl-0
```

发现 `display@0` 子节点存在，但没有 `port` 节点——这就是旧式 binding，主线驱动不支持。

### 3.3 第三步——确认内核编译的 panel 驱动

```bash
zcat /proc/config.gz | grep -i panel
```

**本案例关键发现：**

```
CONFIG_DRM_PANEL_SEIKO_43WVF1G=y   # Seiko 4.3寸屏驱动，已编入
CONFIG_DRM_PANEL_SIMPLE=y          # 通用 simple panel 驱动，已编入
CONFIG_DRM_PANEL=y                 # DRM panel 子系统，已编入
```

`CONFIG_DRM_PANEL_SIMPLE=y` 包含了 `panel-dpi` 通用驱动，这正是我们需要的。

### 3.4 第四步——分析旧 DTS binding 结构

旧式写法（NXP BSP 内核，6.x 及更早）：

```dts
&lcdif {
    display = <&display0>;    /* 指向下面的子节点 */
    status = "okay";

    display0: display@0 {
        bits-per-pixel = <16>;
        bus-width = <24>;

        display-timings {
            native-mode = <&timing0>;
            timing0: timing0 {
                clock-frequency = <51200000>;
                hactive = <1024>;
                vactive = <600>;
                /* ... */
            };
        };
    };
};
```

新式写法（主线内核，DRM 子系统）：

```dts
/* panel 节点独立于 lcdif 之外 */
panel: panel-dpi {
    compatible = "panel-dpi";
    /* 时序直接写在 panel 里 */
    panel-timing { /* ... */ };

    port {
        panel_in: endpoint {
            remote-endpoint = <&lcdif_out>;  /* 指向 lcdif 的输出 */
        };
    };
};

&lcdif {
    status = "okay";
    /* 不再有 display@0 子节点 */
    port {
        lcdif_out: endpoint {
            remote-endpoint = <&panel_in>;   /* 指向 panel 的输入 */
        };
    };
};
```

这种 `port/endpoint` 图形化连接方式是内核 OF graph binding 标准，定义于 `Documentation/devicetree/bindings/graph.txt`。

---

## 第四章：DTS 修改方案

### 4.1 为什么用 `panel-dpi` 而不是 `seiko,43wvf1g`

本案例屏幕是 7 寸 1024×600 自定义时序面板，不是 Seiko 标准屏。`seiko,43wvf1g` 驱动内部硬编码了 Seiko 屏幕的时序参数，不适合自定义时序。

`panel-dpi` 是内核提供的通用 DPI panel 驱动（`drivers/gpu/drm/panel/panel-dpi.c`），时序参数完全由设备树的 `panel-timing` 子节点指定，适合所有并行 RGB 接口屏幕。

### 4.2 完整修改后的 DTS

#### 根节点：添加 panel 节点，修正 backlight label

```dts
/ {
    /* 给 backlight 添加 label，供 panel 节点引用 */
    backlight_display: backlight-display {
        compatible = "pwm-backlight";
        pwms = <&pwm1 0 5000000 0>;
        brightness-levels = <0 4 8 16 32 64 128 255>;
        default-brightness-level = <6>;
        status = "okay";
    };

    /* 新增：panel-dpi 通用面板节点 */
    panel: panel-dpi {
        compatible = "panel-dpi";
        backlight = <&backlight_display>;

        /* 7寸屏物理尺寸（用于计算 DPI，不影响实际显示） */
        width-mm = <154>;
        height-mm = <86>;

        /* 屏幕时序参数（从原 display@0 迁移而来） */
        panel-timing {
            clock-frequency = <51200000>;
            hactive = <1024>;
            vactive = <600>;
            hfront-porch = <160>;
            hback-porch = <140>;
            hsync-len = <20>;
            vback-porch = <20>;
            vfront-porch = <12>;
            vsync-len = <3>;
            hsync-active = <0>;
            vsync-active = <0>;
            de-active = <1>;
            pixelclk-active = <0>;
        };

        /* OF graph 连接：panel 输入端 → lcdif 输出端 */
        port {
            panel_in: endpoint {
                remote-endpoint = <&lcdif_out>;
            };
        };
    };
};
```

#### lcdif 节点：删除旧属性，改为 port 连接

```dts
&lcdif {
    assigned-clocks = <&clks IMX6UL_CLK_LCDIF_PRE_SEL>;
    assigned-clock-parents = <&clks IMX6UL_CLK_PLL5_VIDEO_DIV>;
    pinctrl-names = "default";
    pinctrl-0 = <&pinctrl_lcdif_dat &pinctrl_lcdif_ctrl>;
    status = "okay";

    /*
     * 关键：删除 imx6ul.dtsi 基础文件里遗留的 display 属性。
     * dtsi 里有 display = <&display0>，但 display0 节点已被我们删除，
     * 不加这行会导致 DTB 编译时报 phandle_references 错误。
     */
    /delete-property/ display;

    /* 新式 OF graph 连接：lcdif 输出端 → panel 输入端 */
    port {
        lcdif_out: endpoint {
            remote-endpoint = <&panel_in>;
        };
    };
};
```

### 4.3 `/delete-property/` 的作用

DTS 文件是分层叠加的：`imx6ul.dtsi`（SoC 基础文件）→ 板级 `.dts`。基础文件 `imx6ul.dtsi` 里的 lcdif 节点有：

```dts
/* imx6ul.dtsi（只读，不能修改） */
lcdif: lcdif@21c8000 {
    compatible = "fsl,imx6ul-lcdif", "fsl,imx28-lcdif";
    display = <&display0>;   /* ← 这行会造成悬空引用 */
    /* ... */
};
```

在板级 DTS 里用 `&lcdif { /delete-property/ display; }` 可以在编译时覆盖删除这个属性，而不需要修改只读的 dtsi 文件。这是 DTS 继承机制中处理遗留属性的标准做法。

---

## 第五章：内核配置要点

### 5.1 必须开启的配置

```kconfig
# DRM 子系统
CONFIG_DRM=y
CONFIG_DRM_MXSFB=y              # eLCDIF DRM 驱动

# Panel 驱动
CONFIG_DRM_PANEL=y
CONFIG_DRM_PANEL_BRIDGE=y
CONFIG_DRM_PANEL_SIMPLE=y       # 包含 panel-dpi 通用驱动

# 背光
CONFIG_BACKLIGHT_PWM=y
CONFIG_PWM_IMX27=y              # i.MX6ULL PWM 控制器
```

### 5.2 应当关闭的旧驱动（避免冲突）

```kconfig
# CONFIG_FB_MXS is not set          # 旧 Framebuffer 驱动，与 DRM 冲突
# CONFIG_FB_MXC_SYNC_PANEL is not set  # NXP BSP 旧显示驱动
```

**为什么会冲突：** 两个驱动的 `compatible` 字符串都匹配 `fsl,imx28-lcdif`，先 probe 的会抢占设备，后者报 `-EBUSY`。即使只有一个成功，混用两套框架也会导致不可预期的行为。

---

## 第六章：编译与验证

### 6.1 编译 DTB

```bash
# 只编译 DTB，不重新编译内核（节省时间）
make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabihf- dtbs

# 目标文件路径
arch/arm/boot/dts/nxp/imx/imx6ull-<your-board>.dtb
```

### 6.2 启动后验证清单

```bash
# 1. 确认 DRM 驱动和 panel 都正常 probe
dmesg | grep -E "mxsfb|panel|lcdif|drm"
# 期望看到：
# panel-dpi: panel enabled
# mxsfb 21c8000.lcdif: bound ...

# 2. 确认 DRM 设备节点存在
ls /dev/dri/           # 应有 card0
ls /dev/fb*            # 应有 fb0

# 3. 查看 connector 状态
cat /sys/class/drm/card*/card*-*/status   # 应为 connected
cat /sys/class/drm/card*/card*-*/modes    # 应显示 1024x600

# 4. framebuffer 分辨率确认
fbset -i

# 5. 显示测试：写随机噪点（屏幕应出现花屏）
cat /dev/urandom > /dev/fb0 &
sleep 2; kill %1

# 6. 背光控制验证
ls /sys/class/backlight/
cat /sys/class/backlight/*/max_brightness
echo 255 > /sys/class/backlight/*/brightness  # 全亮
echo 0   > /sys/class/backlight/*/brightness  # 全暗
```

---

## 第七章：常见问题与解决方案

### 7.1 问题速查表

| 报错信息                                                     | 根本原因                                                | 解决方法                           |
| ------------------------------------------------------------ | ------------------------------------------------------- | ---------------------------------- |
| `Cannot connect bridge` (`-ENODEV`)                          | DTS 用旧式 `display@0` 写法，缺少 `port/endpoint`       | 按第四章修改 DTS                   |
| `phandle_references: Reference to non-existent node display0` | 删了 `display0` 节点但没删 dtsi 里的 `display` 属性引用 | 加 `/delete-property/ display;`    |
| `pin already requested by 1-005d`                            | GT911 触摸驱动和其他驱动（SD卡/TSC）的 GPIO 冲突        | 本案例中为非关键警告，触摸正常工作 |
| `wm8960: Failed to issue reset`                              | WM8960 音频编解码器硬件问题或供电异常                   | 检查 I2C 和音频电源                |
| `spi-nor: unrecognized JEDEC id`                             | SPI NOR Flash 不存在或已损坏                            | 非关键，不影响 LCD                 |

### 7.2 GT911 触摸 GPIO 冲突详解

启动日志中出现：

```
pin MX6UL_PAD_GPIO1_IO09 already requested by 1-005d; cannot claim for 2040000.touchscreen
pin MX6UL_PAD_GPIO1_IO05 already requested by 1-005d; cannot claim for 2190000.mmc
```

原因：GT9147（gt9147@5d）优先 probe，占用了：

- `GPIO1_IO09`（触摸中断引脚）
- `GPIO1_IO05`（触摸复位引脚）

而 usdhc1 的 `pinctrl_usdhc1` 里也配置了这两个引脚作为 SD 卡的 RESET 和 VSELECT 功能。GT911 先到先得，SD 卡（usdhc1）probe 失败，但触摸本身工作正常。

**如果需要 SD 卡正常工作：** 删除 `pinctrl_usdhc1` 中重复的引脚配置：

```dts
pinctrl_usdhc1: usdhc1grp {
    fsl,pins = <
        MX6UL_PAD_SD1_CMD__USDHC1_CMD      0x17059
        MX6UL_PAD_SD1_CLK__USDHC1_CLK      0x10071
        MX6UL_PAD_SD1_DATA0__USDHC1_DATA0  0x17059
        MX6UL_PAD_SD1_DATA1__USDHC1_DATA1  0x17059
        MX6UL_PAD_SD1_DATA2__USDHC1_DATA2  0x17059
        MX6UL_PAD_SD1_DATA3__USDHC1_DATA3  0x17059
        MX6UL_PAD_UART1_RTS_B__GPIO1_IO19  0x17059  /* SD1 CD，保留 */
        /* 删掉下面两行，与 GT911 冲突 */
        /* MX6UL_PAD_GPIO1_IO05__USDHC1_VSELECT 0x17059 */
        /* MX6UL_PAD_GPIO1_IO09__GPIO1_IO09      0x17059 */
    >;
};
```

### 7.3 `width-mm` / `height-mm` 填错的影响

这两个属性仅用于计算屏幕物理 DPI，影响范围非常有限：

- X11/Wayland 下字体物理大小渲染
- 少数按物理尺寸布局 UI 的 GUI 框架

对以下场景**完全没有影响**：

- 直接读写 `/dev/fb0`
- Qt/LVGL/LittlevGL 等嵌入式 GUI 框架
- 内核 logo 显示
- DRM modetest

7 寸 1024×600 LCD 的标准物理尺寸参考值：

```dts
width-mm = <154>;
height-mm = <86>;
```

---

## 第八章：DRM 子系统架构理解

### 8.1 主线内核 eLCDIF 数据流

```
应用程序 / GUI 框架
       ↓ (read/write /dev/fb0 或 DRM ioctl)
  DRM 核心子系统
       ↓
  mxsfb CRTC (drivers/gpu/drm/mxsfb/)
       ↓  [OF graph: lcdif port → panel port]
  panel-dpi (drivers/gpu/drm/panel/panel-dpi.c)
       ↓  [物理并行 RGB 信号]
  LCD 屏幕硬件
```

### 8.2 `drm_of_find_panel_or_bridge()` 工作原理

这是 `mxsfb` 驱动 probe 时的关键调用：

1. 读取设备树中 `lcdif` 节点的 `port/endpoint/remote-endpoint` 属性
2. 通过 phandle 找到对应的 panel 或 bridge 节点
3. 查找已注册的匹配 `drm_panel` 结构体
4. 失败则返回 `-ENODEV` 或 `-EPROBE_DEFER`

`-EPROBE_DEFER` 是延迟 probe，表示依赖的设备还没准备好，内核会稍后重试。`-ENODEV` 表示连节点都找不到，是配置错误。

---

## 附录 A：完整的排查命令速查

```bash
# === 显示子系统状态 ===
dmesg | grep -E "drm|fb|panel|lcdif|mxsfb|display"
ls /dev/dri/ /dev/fb*
cat /sys/class/drm/card*/card*-*/status
cat /sys/class/drm/card*/card*-*/modes
fbset -i

# === 设备树验证 ===
ls /proc/device-tree/soc/bus@2100000/lcdif@21c8000/
dtc -I fs /proc/device-tree 2>/dev/null | grep -A 20 "lcdif"

# === 内核配置确认 ===
zcat /proc/config.gz | grep -E "DRM|FB_MXS|PANEL|BACKLIGHT"

# === 显示功能测试 ===
cat /dev/urandom > /dev/fb0 &   # 花屏测试
sleep 2; kill %1
dd if=/dev/zero of=/dev/fb0     # 清屏（全黑）

# === 背光控制 ===
ls /sys/class/backlight/
echo 255 > /sys/class/backlight/*/brightness

# === modetest（如果安装了 libdrm-tests）===
modetest -M mxsfb               # 列出所有 connector/mode
```

---

## 附录 B：关键内核源码文件索引

| 文件路径                                                     | 说明                          |
| ------------------------------------------------------------ | ----------------------------- |
| `drivers/gpu/drm/mxsfb/mxsfb_drv.c`                          | eLCDIF DRM 主驱动             |
| `drivers/gpu/drm/panel/panel-dpi.c`                          | 通用 DPI panel 驱动           |
| `arch/arm/boot/dts/nxp/imx/imx6ul.dtsi`                      | i.MX6UL SoC 基础设备树        |
| `Documentation/devicetree/bindings/display/panel/panel-dpi.yaml` | panel-dpi DT binding 文档     |
| `Documentation/devicetree/bindings/graph.txt`                | OF graph（port/endpoint）规范 |

---

*文档整理于 2026 年 3 月22日，基于实际调试 i.MX6ULL + Linux 7.0-rc4 主线内核的经验总结。*