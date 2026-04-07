#!/bin/bash
#
# 简化的驱动部署脚本
# 直接复制驱动产物到目标位置
#

set +e

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 加载配置文件（如果存在）
CONFIG_FILE="${SCRIPT_DIR}/driver_helper.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 默认参数
TFTP_DIR="${TFTP_DIR:-/srv/tftp}"
NFS_DIR="${NFS_DIR:-${PROJECT_ROOT}/rootfs/nfs}"

# 显示帮助
show_help() {
    cat << EOF
用法: $(basename "$0") <产物目录> [选项]

参数:
  产物目录  驱动产物目录路径

选项:
  --target=TYPE    部署目标 (tftp|nfs|local|remote)
  --tftp-dir=PATH  TFTP目录
  --nfs-dir=PATH   NFS目录
  --local-dir=PATH 本地目录
  --remote=HOST    远程主机
  --remote-path=PATH 远程路径

示例:
  # 交互式部署
  $(basename "$0") out/driver_artifacts/example-driver/alpha-board

  # 直接部署到TFTP
  $(basename "$0") out/driver_artifacts/example-driver/alpha-board --target=tftp

  # 部署到NFS
  $(basename "$0") out/driver_artifacts/example-driver/alpha-board --target=nfs

EOF
}

# 部署到TFTP
deploy_tftp() {
    local src="$1"
    local dst="$2"

    log_info "部署到TFTP: $dst"
    mkdir -p "$dst" || return 1

    # 只拷贝设备树文件，不拷贝 .ko 文件
    local count=0
    for file in "$src"/*.dtb; do
        if [[ -f "$file" ]]; then
            # 目标文件名固定为 imx6ull-aes.dtb
            local target_file="$dst/imx6ull-aes.dtb"

            # 如果文件已存在，先备份旧的
            if [[ -f "$target_file" ]]; then
                local backup_file="$dst/imx6ull-aes-$(date +%Y%m%d%H%M%S).dtb"
                log_info "  备份现有文件: $(basename "$backup_file")"
                mv "$target_file" "$backup_file"
            fi

            # 拷贝新的设备树文件
            cp "$file" "$target_file"
            log_info "  ✓ $(basename "$file") → imx6ull-aes.dtb"
            count=$((count + 1))
        fi
    done

    log_info "已复制 $count 个设备树文件（.ko 文件已跳过）"
}

# 部署到NFS
deploy_nfs() {
    local src="$1"
    local dst="$2"

    log_info "部署到NFS: $dst"
    mkdir -p "$dst/lib/modules" "$dst/boot" || return 1

    local count=0
    for file in "$src"/*.ko; do
        if [[ -f "$file" ]]; then
            cp "$file" "$dst/lib/modules/"
            log_info "  ✓ $(basename "$file") -> lib/modules/"
            count=$((count+1))
        fi
    done

    for file in "$src"/*.dtb; do
        if [[ -f "$file" ]]; then
            cp "$file" "$dst/boot/"
            log_info "  ✓ $(basename "$file") -> boot/"
            count=$((count+1))
        fi
    done

    log_info "已复制 $count 个文件"
}

# 部署到本地
deploy_local() {
    local src="$1"
    local dst="$2"

    log_info "部署到本地: $dst"
    mkdir -p "$dst" || return 1

    local count=0
    for file in "$src"/*.{ko,dtb}; do
        if [[ -f "$file" ]]; then
            cp "$file" "$dst/"
            log_info "  ✓ $(basename "$file")"
            count=$((count+1))
        fi
    done

    log_info "已复制 $count 个文件"
}

# 部署到远程
deploy_remote() {
    local src="$1"
    local host="$2"
    local path="$3"

    log_info "部署到远程: $host:$path"

    # 测试连接
    ssh -o ConnectTimeout=5 "$host" "echo test" >/dev/null 2>&1 || {
        log_error "无法连接到 $host"
        return 1
    }

    # 创建远程目录
    ssh "$host" "mkdir -p $path" || return 1

    local count=0
    for file in "$src"/*.{ko,dtb}; do
        if [[ -f "$file" ]]; then
            scp "$file" "$host:$path/"
            log_info "  ✓ $(basename "$file")"
            count=$((count+1))
        fi
    done

    log_info "已复制 $count 个文件"
}

# 交互式选择
select_target() {
    local src="$1"

    echo ""
    echo "选择部署目标:"
    echo "1) TFTP服务器"
    echo "2) NFS rootfs"
    echo "3) 本地目录"
    echo "4) 远程服务器"
    echo ""
    read -p "请选择 [1-4]: " choice

    case "$choice" in
        1) deploy_tftp "$src" "$TFTP_DIR" ;;
        2) deploy_nfs "$src" "$NFS_DIR" ;;
        3)
            read -p "目标目录: " dir
            deploy_local "$src" "$dir"
            ;;
        4)
            read -p "远程主机 (user@host): " host
            read -p "远程路径: " path
            deploy_remote "$src" "$host" "$path"
            ;;
        *)
            log_error "无效选择"
            return 1
            ;;
    esac
}

# 主函数
main() {
    local artifacts_dir=""
    local target=""
    local tftp_dir="$TFTP_DIR"
    local nfs_dir="$NFS_DIR"
    local local_dir=""
    local remote=""
    local remote_path=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --target=*) target="${1#*=}"; shift ;;
            --tftp-dir=*) tftp_dir="${1#*=}"; shift ;;
            --nfs-dir=*) nfs_dir="${1#*=}"; shift ;;
            --local-dir=*) local_dir="${1#*=}"; shift ;;
            --remote=*) remote="${1#*=}"; shift ;;
            --remote-path=*) remote_path="${1#*=}"; shift ;;
            --help|-h) show_help; exit 0 ;;
            -*)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
            *)
                artifacts_dir="$1"
                shift
                ;;
        esac
    done

    # 检查参数
    if [[ -z "$artifacts_dir" ]]; then
        log_error "缺少产物目录参数"
        show_help
        exit 1
    fi

    # 检查目录
    if [[ ! -d "$artifacts_dir" ]]; then
        log_error "目录不存在: $artifacts_dir"
        exit 1
    fi

    # 显示文件列表
    echo ""
    log_info "驱动产物:"
    for file in "$artifacts_dir"/*.{ko,dtb}; do
        if [[ -f "$file" ]]; then
            size=$(ls -lh "$file" | awk '{print $5}')
            log_info "  - $(basename "$file") ($size)"
        fi
    done
    echo ""

    # 部署
    if [[ -n "$target" ]]; then
        case "$target" in
            tftp) deploy_tftp "$artifacts_dir" "$tftp_dir" ;;
            nfs) deploy_nfs "$artifacts_dir" "$nfs_dir" ;;
            local)
                if [[ -z "$local_dir" ]]; then
                    log_error "请指定--local-dir"
                    exit 1
                fi
                deploy_local "$artifacts_dir" "$local_dir"
                ;;
            remote)
                if [[ -z "$remote" || -z "$remote_path" ]]; then
                    log_error "请指定--remote和--remote-path"
                    exit 1
                fi
                deploy_remote "$artifacts_dir" "$remote" "$remote_path"
                ;;
            *)
                log_error "未知目标: $target"
                exit 1
                ;;
        esac
    else
        select_target "$artifacts_dir"
    fi

    echo ""
    log_info "✓ 部署完成"
}

main "$@"
