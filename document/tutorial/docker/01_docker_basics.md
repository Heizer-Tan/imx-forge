# Docker 基础知识

## 目录

1. [什么是 Docker](#什么是-docker)
2. [为什么嵌入式开发需要 Docker](#为什么嵌入式开发需要-docker)
3. [Docker 核心概念](#docker-核心概念)
4. [Docker 安装](#docker-安装)
5. [基本命令](#基本命令)
6. [国内加速配置](#国内加速配置)
7. [常见问题](#常见问题)

---

## 什么是 Docker

### 容器技术简介

Docker 是一个开源的容器化平台，它可以将应用程序及其依赖项打包到一个轻量级、可移植的容器中。容器共享主机系统的内核，但彼此隔离，运行在独立的用户空间中。

**核心特点**：
- **轻量级**：相比虚拟机，容器不需要完整的操作系统，占用资源极少
- **快速启动**：容器可以在秒级启动，而虚拟机需要分钟级
- **环境一致性**："Build once, run anywhere" - 一次构建，到处运行
- **可移植性**：容器可以在任何支持 Docker 的平台上运行

### 容器 vs 虚拟机

| 特性 | 容器 | 虚拟机 |
|------|------|--------|
| 启动速度 | 秒级 | 分钟级 |
| 资源占用 | MB级 | GB级 |
| 性能 | 接近原生 | 有损耗（5-20%） |
| 隔离性 | 进程级隔离 | 硬件级隔离 |
| 系统要求 | 共享主机内核 | 需要完整的 Guest OS |
| 可移植性 | 极高 | 较低 |

**图示对比**：

```
虚拟机架构：
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  App A      │  │  App B      │  │  App C      │
│  Guest OS   │  │  Guest OS   │  │  Guest OS   │
│  Hypervisor │─────────────────│─────────────────
└─────────────┴──────────────────┴─────────────────┘
│                    Host OS                      │
│                    Hardware                     │
└─────────────────────────────────────────────────┘

容器架构：
┌───────────┐  ┌───────────┐  ┌───────────┐
│  App A    │  │  App B    │  │  App C    │
│  Bins/Libs│  │  Bins/Libs│  │  Bins/Libs│
└───────────┴───────────────┴───────────────┘
│             Docker Engine                    │
│                    Host OS                   │
│                    Hardware                  │
└──────────────────────────────────────────────┘
```

---

## 为什么嵌入式开发需要 Docker

### 传统开发的痛点

**1. 工具链版本冲突**

不同项目可能需要不同版本的交叉编译工具链：
- 项目 A：ARM GCC 9.3
- 项目 B：ARM GCC 11.2
- 项目 C：ARM GCC 15.2

在同一主机上维护多个版本的工具链容易产生冲突。

**2. 依赖库混乱**

嵌入式开发依赖大量的库和工具：
- build-essential, cmake, ninja-build
- device-tree-compiler, u-boot-tools
- python3-pyelftools, swig
- libssl-dev, libncurses-dev

这些库在不同 Linux 发行版上版本不同，可能导致编译失败。

**3. "在我机器上能跑"问题**

- 开发环境：Ubuntu 22.04 + ARM GCC 11.2
- CI 环境：Ubuntu 20.04 + ARM GCC 9.3
- 同事环境：Ubuntu 24.04 + ARM GCC 15.2
- **结果**：同样的代码，三个不同的编译结果！

**4. 跨平台开发困难**

- Windows 用户需要安装 WSL2 或双系统
- macOS 用户需要处理各种兼容性问题
- 不同发行版的 Linux 配置方法不同

**5. 新手入门门槛高**

对于嵌入式开发新手，配置开发环境是一个巨大的挑战：
- 工具链下载、解压、配置 PATH
- 依赖库安装、版本匹配
- 环境变量配置、权限问题
- **结果**：还没开始写代码，就被环境配置劝退

### Docker 的优势

**✅ 环境统一**

所有开发者使用相同的 Docker 镜像，确保环境完全一致：
```bash
# 开发者 A（Ubuntu）
docker run -it -v $(pwd):/workspace imx-forge:latest

# 开发者 B（Windows + WSL2）
docker run -it -v $(pwd):/workspace imx-forge:latest

# 开发者 C（macOS）
docker run -it -v $(pwd):/workspace imx-forge:latest
```
**结果**：三人的编译结果完全相同！

**✅ 依赖隔离**

每个容器都有独立的依赖环境，不会相互影响：
- 项目 A 使用容器 A（ARM GCC 9.3）
- 项目 B 使用容器 B（ARM GCC 11.2）
- 项目 C 使用容器 C（ARM GCC 15.2）

**✅ 快速上手**

新手只需要：
```bash
# 安装 Docker
sudo apt install docker.io

# 运行容器
docker run -it -v $(pwd):/workspace imx-forge:latest

# 开始编译
./scripts/release-all.sh
```

5分钟内开始编译，无需配置工具链和依赖！

**✅ 跨平台支持**

Docker 支持 Linux、Windows、macOS，同一个镜像可以在所有平台上运行。

**✅ 团队协作友好**

- 新员工入职：拉取 Docker 镜像，立即开始工作
- CI/CD：使用相同的镜像进行自动化构建
- 代码审查：环境一致，容易重现问题

### IMX-Forge Docker 环境的价值

IMX-Forge 的 Docker 环境专门为 i.MX6ULL 嵌入式开发优化：

**预装的工具链和依赖**：
- ✅ ARM GNU Toolchain 15.2.rel1（最新稳定版）
- ✅ 所有编译依赖（build-essential, cmake, ninja-build等）
- ✅ 设备树编译器（device-tree-compiler）
- ✅ U-Boot 工具（u-boot-tools, mkimage）
- ✅ Python ELF 工具（python3-pyelftools）

**特殊优化**：
- ✅ 国内镜像加速（Dockerfile.cn）
- ✅ 多阶段构建优化镜像大小
- ✅ 非 root 用户运行（安全）
- ✅ USB 设备支持（烧录、调试）
- ✅ WSL2 深度集成（Windows 用户）

**实际效果**：
- 传统方式：30分钟配置 → 可能遇到依赖问题 → 修复 → 终于能编译
- Docker 方式：5分钟构建镜像 → 立即开始编译

---

## Docker 核心概念

### 镜像 (Image)

镜像是只读的模板，包含运行应用所需的所有内容：

**特点**：
- **只读**：镜像创建后不能修改
- **分层存储**：镜像由多层组成，每层代表 Dockerfile 中的一条指令
- **复用性**：多个容器可以共享同一个镜像

**示例**：
```dockerfile
# Dockerfile 示例
FROM ubuntu:24.04                    # 第1层：基础镜像
RUN apt update && apt install gcc    # 第2层：安装工具
COPY . /app                          # 第3层：复制代码
WORKDIR /app                         # 第4层：设置工作目录
```

**操作**：
```bash
# 查看本地镜像
docker images

# 拉取镜像
docker pull ubuntu:24.04

# 构建镜像
docker build -t myimage:latest .

# 删除镜像
docker rmi myimage:latest
```

### 容器 (Container)

容器是镜像的运行实例，提供了一个隔离的执行环境：

**特点**：
- **可写**：容器在镜像之上添加了一个可写层
- **隔离性**：每个容器有独立的进程空间、网络、文件系统
- **临时性**：容器删除后，其中的更改会丢失（除非使用卷）

**生命周期**：
```
创建 → 启动 → 运行 → 停止 → 删除
```

**操作**：
```bash
# 运行容器
docker run -it ubuntu:24.04 bash

# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a

# 停止容器
docker stop <container_id>

# 启动已停止的容器
docker start <container_id>

# 删除容器
docker rm <container_id>
```

### 卷 (Volume)

卷用于数据持久化和宿主机与容器之间的文件共享：

**类型**：
1. **命名卷**：由 Docker 管理，存储在 `/var/lib/docker/volumes/`
2. **绑定挂载**：将宿主机目录挂载到容器

**示例**：
```bash
# 创建命名卷
docker volume create mydata

# 使用命名卷
docker run -it -v mydata:/data ubuntu:24.04

# 绑定挂载（常用）
docker run -it -v $(pwd):/workspace ubuntu:24.04

# 只读挂载
docker run -it -v $(pwd):/workspace:ro ubuntu:24.04
```

**IMX-Forge 中的应用**：
```bash
# 挂载项目目录
docker run -it -v $(pwd):/workspace imx-forge:latest

# 挂载输出目录
docker run -it -v $(pwd):/workspace -v $(pwd)/out:/output imx-forge:latest
```

### Dockerfile

Dockerfile 是用于构建镜像的脚本：

**基本结构**：
```dockerfile
# 基础镜像
FROM ubuntu:24.04

# 维护者信息
LABEL maintainer="your-email@example.com"

# 环境变量
ENV DEBIAN_FRONTEND=noninteractive

# 工作目录
WORKDIR /workspace

# 复制文件
COPY . /workspace

# 安装依赖
RUN apt update && apt install -y \
    build-essential \
    gcc \
    make

# 设置默认命令
CMD ["/bin/bash"]
```

**最佳实践**：
- 使用 `.dockerignore` 排除不需要的文件
- 合并 RUN 指令减少层数
- 使用多阶段构建减小镜像大小
- 利用构建缓存

---

## Docker 安装

### Ubuntu/Debian 安装

```bash
# 1. 卸载旧版本
sudo apt remove docker docker-engine docker.io containerd runc

# 2. 更新软件包索引并安装依赖
sudo apt update
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 4. 设置 Docker APT 源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. 安装 Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# 6. 验证安装
sudo docker run hello-world
```

**配置用户权限**（可选，避免每次都使用 sudo）：
```bash
# 将当前用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录或运行
newgrp docker

# 验证（不需要 sudo）
docker run hello-world
```

### WSL2 安装 ⭐

> **Windows 用户首选方案**：IMX-Forge 项目在 WSL2 环境下深度测试通过

#### 为什么选择 WSL2 + Docker

**优势**：
- ✅ **Windows 下原生 Docker 体验**：无需切换到 Linux 桌面
- ✅ **无需双系统或虚拟机**：直接在 Windows 上运行 Linux 环境
- ✅ **与 Windows 文件系统集成**：轻松访问 Windows 文件系统
- ✅ **支持 USB 设备直通**：烧录、串口调试一步到位
- ✅ **性能接近原生 Linux**：相比传统虚拟机性能大幅提升

#### 安装步骤

**1. 安装 WSL2**

在 PowerShell（管理员）中执行：

```powershell
# 安装 WSL2
wsl --install

# 重启电脑后，完成 Ubuntu 安装
```

安装完成后，你会看到 Ubuntu 终端窗口，按照提示创建用户名和密码。

**2. 配置 WSL2 网络（重要！）**

IMX-Forge 需要 WSL2 使用 **Mirrored 网络模式**，这样才能直接访问开发板。

在 Windows 用户目录下创建 `.wslconfig` 文件：

```powershell
# 在 PowerShell 中执行
notepad $env:USERPROFILE\.wslconfig
```

添加以下内容：

```ini
[wsl2]
networkingMode=mirrored
```

> **为什么需要 mirrored 网络模式？**
>
> - **默认 NAT 模式**：WSL2 有自己的虚拟网络，无法直接访问 Windows 所在网络的开发板
> - **Mirrored 模式**：WSL2 与 Windows 共享网络，可以直接 ping 通开发板，进行 TFTP/NFS 开发
>
> **场景对比**：
> - **NAT 模式**：开发板（192.168.1.100）←→ Windows → WSL2（无法直接访问）
> - **Mirrored 模式**：开发板（192.168.1.100）←→ WSL2（直接访问，同网段）

重启 WSL：

```powershell
wsl --shutdown
wsl
```

**3. 安装 Docker Desktop**

1. 下载 Docker Desktop for Windows：
   https://www.docker.com/products/docker-desktop/

2. 运行安装程序，安装时确保勾选：
   - ✅ "Use WSL 2 based engine"（使用 WSL2 引擎）
   - ✅ "Add shortcut to desktop"（添加桌面快捷方式）

3. 安装完成后启动 Docker Desktop

**4. 启用 WSL2 集成**

这是关键步骤！在 Docker Desktop 中启用 WSL2 集成：

1. 打开 Docker Desktop
2. 点击右上角齿轮图标 ⚙️ 打开 **Settings**
3. 进入 **Resources** → **WSL Integration**
4. 启用 **"Enable integration with my default WSL distro"**
5. 选择你的 WSL2 发行版（如 Ubuntu），启用集成
6. 点击 **"Apply & Restart"**

**5. 验证安装**

在 WSL2 中执行以下命令验证：

```bash
# 检查 Docker 版本
docker --version

# 测试运行容器
docker run hello-world

# 查看 Docker 信息
docker info
```

如果能正常运行 Docker 命令，说明集成成功！

**6. 验证网络**

验证 WSL2 的网络模式是否正确：

```bash
# 查看网络接口（应该能看到与 Windows 相同的网卡）
ip addr

# 测试 ping 开发板（假设开发板 IP 是 192.168.1.100）
ping 192.168.1.100

# 测试 DNS 解析
ping google.com
```

如果可以 ping 通开发板，说明 Mirrored 网络模式配置成功！

#### 使用 Docker 开发

在 WSL2 中使用 Docker 与在 Linux 中完全相同：

```bash
# 克隆项目
git clone --recurse-submodules https://github.com/Awesome-Embedded-Learning-Studio/imx-forge.git
cd imx-forge

# 构建 Docker 镜像
cd docker
DOCKER_BUILDKIT=1 docker build -t imx-forge:latest .
cd ..

# 运行容器
docker run -it --rm -v $(pwd):/workspace imx-forge:latest

# 在容器内编译
./scripts/release-all.sh
```

#### USB 设备访问

WSL2 支持 USB 设备直通（需要 Windows 11 或 Windows 10 较新版本）：

```bash
# 检查 USB 设备
ls /dev/ttyUSB*

# 在容器中访问 USB 设备
docker run -it --rm \
  --device=/dev/ttyUSB0 \
  -v $(pwd):/workspace \
  imx-forge:latest
```

如果 USB 设备不显示，可能需要安装 USBIPD-WIN：

```powershell
# 在 Windows PowerShell (管理员) 中执行
winget install usbipd

# 查看 USB 设备
usbipd list

# 绑定设备（例如 USB 串口）
usbipd bind --busid 1-1

# 附加到 WSL2
usbipd attach --wsl --busid 1-1
```

详细步骤参考：[WSL USB 设备直通文档](https://learn.microsoft.com/en-us/windows/wsl/connect-usb)

#### 常见问题

**Q: Docker Desktop 无法启动？**

A: 确保 WSL2 已正确安装：
```powershell
# 检查 WSL 版本
wsl --list --verbose

# 更新到最新版本
wsl --update
```

另外，确保在 BIOS 中开启了虚拟化（VT-x/AMD-V）。

**Q: docker 命令提示权限错误？**

A: 在 WSL2 中将用户添加到 docker 组：
```bash
sudo usermod -aG docker $USER
```
然后重新登录 WSL2（关闭终端重新打开）。

**Q: 无法访问开发板网络？**

A: 确保已配置 `.wslconfig` 的 `networkingMode=mirrored` 并重启 WSL：
```powershell
# 检查配置
cat $env:USERPROFILE\.wslconfig

# 重启 WSL
wsl --shutdown
wsl
```

**Q: Docker 镜像构建很慢？**

A: 在 WSL2 中使用国内镜像加速：
```bash
cd /path/to/imx-forge/docker
sudo bash setup-mirror.sh
```

**Q: WSL2 中无法访问 Windows 文件？**

A: WSL2 可以直接访问 Windows 文件系统：
```bash
# Windows 的 C 盘挂载在 /mnt/c/
cd /mnt/c/Users/YourUsername/Documents
```

### Windows 安装（不推荐）

> 不推荐在 Windows 上直接使用 Docker Desktop 进行嵌入式开发，原因如下：
>
> - **路径转换问题**：Windows 路径（`C:\...`）转换为 Linux 路径（`/mnt/c/...`）可能导致构建脚本失败
> - **文件权限问题**：Windows 和 Linux 文件系统权限模型不同，可能导致编译问题
> - **性能不如 WSL2**：文件系统 I/O 性能较差
> - **工具链兼容性问题**：某些嵌入式工具可能无法在 Windows 上正常运行
>
> **强烈建议 Windows 用户使用 WSL2 + Docker 方案。**

### macOS 安装

1. 下载 Docker Desktop for Mac：
   https://www.docker.com/products/docker-desktop/

2. 安装并启动 Docker Desktop

3. 验证安装：
```bash
docker --version
docker run hello-world
```

---

## 基本命令

### 镜像操作

```bash
# 查看本地镜像
docker images

# 拉取镜像
docker pull ubuntu:24.04

# 构建镜像
docker build -t myimage:latest .

# 使用 BuildKit 构建（推荐，更快）
DOCKER_BUILDKIT=1 docker build -t myimage:latest .

# 删除镜像
docker rmi myimage:latest

# 强制删除镜像（即使有容器在使用）
docker rmi -f myimage:latest

# 清理未使用的镜像
docker image prune
```

### 容器操作

```bash
# 运行容器（交互式）
docker run -it ubuntu:24.04 bash

# 运行容器（后台）
docker run -d ubuntu:24.04 sleep 1000

# 运行容器（用完即删）
docker run -it --rm ubuntu:24.04 bash

# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a

# 停止容器
docker stop <container_id>

# 启动已停止的容器
docker start <container_id>

# 重启容器
docker restart <container_id>

# 删除容器
docker rm <container_id>

# 强制删除运行中的容器
docker rm -f <container_id>

# 清理停止的容器
docker container prune
```

### 卷挂载

```bash
# 挂载当前目录
docker run -it -v $(pwd):/workspace ubuntu:24.04

# 挂载多个目录
docker run -it \
  -v $(pwd):/workspace \
  -v /tmp/output:/output \
  ubuntu:24.04

# 只读挂载
docker run -it -v $(pwd):/workspace:ro ubuntu:24.04

# 使用命名卷
docker volume create mydata
docker run -it -v mydata:/data ubuntu:24.04

# 查看卷
docker volume ls

# 删除卷
docker volume rm mydata
```

### 网络配置

```bash
# 查看网络
docker network ls

# 创建网络
docker network create mynet

# 使用网络
docker run --network mynet ubuntu:24.04

# 查看网络详情
docker network inspect mynet

# 删除网络
docker network rm mynet
```

### 日志和调试

```bash
# 查看容器日志
docker logs <container_id>

# 实时查看日志
docker logs -f <container_id>

# 查看容器详细信息
docker inspect <container_id>

# 在运行中的容器中执行命令
docker exec -it <container_id> bash

# 查看容器资源使用
docker stats
```

### 清理系统

```bash
# 清理所有未使用的对象（镜像、容器、网络、卷）
docker system prune -a --volumes

# 查看磁盘使用
docker system df
```

---

## 国内加速配置

### 为什么需要加速

- **Docker Hub 在国外**：国内访问速度慢或无法访问
- **镜像构建慢**：拉取基础镜像（如 ubuntu:24.04）可能需要很长时间
- **影响开发效率**：每次构建镜像都要等待很长时间

### 使用 setup-mirror.sh

IMX-Forge 提供了一键配置脚本：

```bash
cd /path/to/imx-forge/docker
sudo bash setup-mirror.sh
```

**脚本功能**：
- 配置多个国内镜像源（USTC、网易、腾讯）
- 自动备份旧配置
- 重启 Docker 服务
- 验证配置是否生效

**配置的镜像源**：
- USTC（中国科学技术大学）
- 网易
- 腾讯云

### 手动配置

如果需要手动配置或使用其他镜像源：

```bash
# 1. 创建配置目录
sudo mkdir -p /etc/docker

# 2. 编辑配置文件
sudo nano /etc/docker/daemon.json
```

添加以下内容：

```json
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

**3. 重启 Docker**

```bash
# Ubuntu/Debian
sudo systemctl daemon-reload
sudo systemctl restart docker

# WSL2（在 Windows PowerShell 中）
wsl --shutdown
wsl
```

**4. 验证配置**

```bash
# 查看 Docker 信息
docker info | grep -A 10 "Registry Mirrors"

# 测试拉取镜像
docker pull ubuntu:24.04
```

### 其他镜像源

**阿里云镜像加速**：
1. 登录阿里云控制台
2. 进入 "容器镜像服务" → "镜像工具" → "镜像加速器"
3. 获取专属加速地址
4. 添加到 `daemon.json` 的 `registry-mirrors` 中

---

## 常见问题

### Q1: Docker 命令需要 sudo？

**A**: 将用户添加到 docker 组：

```bash
sudo usermod -aG docker $USER
newgrp docker
```

然后重新登录或运行 `newgrp docker`。

**注意**：添加到 docker 组相当于授予了 root 权限，请确保你信任该用户。

### Q2: 容器内无法访问网络？

**A**: 检查以下几点：

1. **检查防火墙**：
```bash
# Ubuntu
sudo ufw status

# 临时关闭防火墙测试
sudo ufw disable
```

2. **检查 DNS**：
```bash
# 查看 DNS 配置
cat /etc/resolv.conf

# 在容器中测试
docker run ubuntu:24.04 cat /etc/resolv.conf

# 手动指定 DNS
docker run --dns 8.8.8.8 --dns 114.114.114.114 ubuntu:24.04
```

3. **检查网络模式**：
```bash
# 查看网络
docker network ls

# 使用 bridge 网络
docker run --network bridge ubuntu:24.04
```

### Q3: 镜像构建失败？

**A**: 常见原因和解决方法：

1. **网络问题**：
```bash
# 使用国内镜像
# 在 Dockerfile 第一行使用国内基础镜像
FROM ubuntu:24.04

# 或配置镜像加速（见上方"国内加速配置"）
```

2. **磁盘空间不足**：
```bash
# 检查磁盘空间
df -h

# 清理 Docker 缓存
docker system prune -a

# 清理构建缓存
docker builder prune
```

3. **Docker 版本过旧**：
```bash
# 检查版本
docker --version

# 更新 Docker
sudo apt update && sudo apt install docker-ce
```

### Q4: 容器磁盘空间占用过大？

**A**: 定期清理：

```bash
# 清理停止的容器
docker container prune

# 清理未使用的镜像
docker image prune -a

# 清理未使用的卷
docker volume prune

# 清理所有未使用的对象
docker system prune -a --volumes

# 查看磁盘使用
docker system df
```

### Q5: 如何进入正在运行的容器？

**A**: 使用 `docker exec`：

```bash
# 查看运行中的容器
docker ps

# 进入容器
docker exec -it <container_id> bash

# 如果容器中没有 bash，尝试 sh
docker exec -it <container_id> sh
```

### Q6: 如何在容器和宿主机之间复制文件？

**A**:

```bash
# 从容器复制到宿主机
docker cp <container_id>:/path/in/container /path/on/host

# 从宿主机复制到容器
docker cp /path/on/host <container_id>:/path/in/container
```

**注意**：推荐使用卷挂载（`-v`）而不是 `docker cp`。

### Q7: 如何查看容器的资源使用？

**A**:

```bash
# 实时查看所有容器的资源使用
docker stats

# 查看特定容器
docker stats <container_id>
```

输出包括：
- CPU 使用率
- 内存使用
- 网络 I/O
- 磁盘 I/O

### Q8: 如何限制容器的资源？

**A**:

```bash
# 限制内存和 CPU
docker run -it \
  --memory=4g \
  --cpus=2 \
  ubuntu:24.04

# 限制 CPU 核心数（使用第 0 和第 1 核心）
docker run -it \
  --cpuset-cpus="0,1" \
  ubuntu:24.04

# 限制交换空间
docker run -it \
  --memory=4g \
  --memory-swap=4g \
  ubuntu:24.04
```

### Q9: 如何在 Docker 中使用图形界面？

**A**: 虽然嵌入式开发通常不需要图形界面，但如果需要：

```bash
# 使用 X11 转发
docker run -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  ubuntu:24.04
```

### Q10: 如何持久化容器中的数据？

**A**: 使用卷：

```bash
# 使用命名卷
docker volume create mydata
docker run -it -v mydata:/data ubuntu:24.04

# 使用绑定挂载
docker run -it -v $(pwd)/data:/data ubuntu:24.04

# 查看卷
docker volume ls

# 查看卷详情
docker volume inspect mydata
```

---

## 下一步

学习完基础知识后，继续阅读：

- [IMX-Forge Docker 开发指南](02_imx_forge_docker_guide.md) - 学习如何在 IMX-Forge 项目中使用 Docker
- [docker/README.md](https://github.com/Awesome-Embedded-Learning-Studio/imx-forge/blob/main/docker/README.md) - IMX-Forge Docker 环境详细参考

## 参考资料

- [Docker 官方文档](https://docs.docker.com/)
- [Dockerfile 最佳实践](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker Compose 文档](https://docs.docker.com/compose/)
- [WSL2 文档](https://learn.microsoft.com/en-us/windows/wsl/)
- [IMX-Forge 项目主页](https://github.com/Awesome-Embedded-Learning-Studio/imx-forge)

---

**Happy Containerizing!** 🐳
