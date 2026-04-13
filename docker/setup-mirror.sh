#!/bin/bash
#
# Docker 镜像加速器配置脚本
# 用于解决国内访问 Docker Hub 慢的问题
#

set -e

echo "========================================"
echo "Docker 镜像加速器配置"
echo "========================================"
echo ""

# 检查是否为 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "请使用 sudo 运行此脚本"
   exit 1
fi

# 创建 Docker 配置目录
echo "[1/4] 创建 Docker 配置目录..."
mkdir -p /etc/docker

# 备份现有配置
if [[ -f /etc/docker/daemon.json ]]; then
    echo "[2/4] 备份现有配置..."
    cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d%H%M%S)
fi

# 写入新配置
echo "[3/4] 写入镜像加速器配置..."
cat > /etc/docker/daemon.json <<EOF
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
EOF

# 重启 Docker 服务
echo "[4/4] 重启 Docker 服务..."
systemctl daemon-reload
systemctl restart docker

# 验证配置
echo ""
echo "========================================"
echo "配置完成！"
echo "========================================"
echo ""
echo "镜像加速器列表："
docker info | grep -A 5 "Registry Mirrors" || echo "未找到镜像加速器配置"

echo ""
echo "现在可以构建镜像了："
echo "  cd /home/tan/code/imx-forge/docker"
echo "  sudo docker build -t imx-forge:latest ."
echo ""
