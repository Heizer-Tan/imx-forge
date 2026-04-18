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
# 确保 NFS_DIR 是绝对路径
if [[ -n "$NFS_DIR" && ! "$NFS_DIR" = /* ]]; then
    NFS_DIR="${PROJECT_ROOT}/${NFS_DIR}"
fi
NFS_DIR="${NFS_DIR:-${PROJECT_ROOT}/rootfs/nfs}"

# 列出可部署的驱动
list_drivers() {
    log_info "========================================"
    log_info "可部署驱动列表"
    log_info "========================================"

    local artifacts_dir="${PROJECT_ROOT}/out/driver_artifacts"
    local driver_dir="${PROJECT_ROOT}/driver"

    # 检查是否有已构建的产物
    if [[ -d "$artifacts_dir" ]]; then
        local found_any=0
        for driver_path in "${artifacts_dir}"/*/; do
            if [[ -d "$driver_path" ]]; then
                local driver=$(basename "$driver_path")

                # 跳过非驱动目录
                if [[ "$driver" == "base_driver" ]] || [[ "$driver" == "device_tree" ]] || [[ "$driver" == "firmwares" ]]; then
                    continue
                fi

                log_info ""
                log_info "📦 $driver"

                # 列出该驱动下的所有板卡产物
                for board_path in "$driver_path"/*/; do
                    if [[ -d "$board_path" ]]; then
                        local board=$(basename "$board_path")
                        local has_ko=0
                        local has_dtb=0
                        local file_count=0

                        # 检查文件
                        [[ $(find "$board_path" -maxdepth 1 -name "*.ko" -type f | wc -l) -gt 0 ]] && has_ko=1
                        [[ $(find "$board_path" -maxdepth 1 -name "*.dtb" -type f | wc -l) -gt 0 ]] && has_dtb=1
                        file_count=$(find "$board_path" -maxdepth 1 -type f \( -name "*.ko" -o -name "*.dtb" \) | wc -l)

                        if [[ $file_count -gt 0 ]]; then
                            local status=""
                            [[ $has_ko -eq 1 ]] && status="${status}✓ KO "
                            [[ $has_dtb -eq 1 ]] && status="${status}✓ DTB"
                            log_info "  └─ ${board} [${status}]"
                            log_info "     路径: out/driver_artifacts/${driver}/${board}"
                            found_any=1
                        fi
                    fi
                done
            fi
        done

        if [[ $found_any -eq 0 ]]; then
            log_info ""
            log_warn "未找到已构建的驱动产物"
            log_info ""
            log_info "请先使用 build_driver.sh 构建驱动："
            log_info "  ./scripts/driver_helper/build_driver.sh <驱动名> <板名>"
        fi
    else
        log_info ""
        log_warn "产物目录不存在: $artifacts_dir"
        log_info ""
        log_info "请先使用 build_driver.sh 构建驱动："
        log_info "  ./scripts/driver_helper/build_driver.sh <驱动名> <板名>"
    fi

    # 显示可用的驱动源码
    log_info ""
    log_info "========================================"
    log_info "可用的驱动源码"
    log_info "========================================"

    if [[ -d "$driver_dir" ]]; then
        local source_count=0
        for drv_path in "${driver_dir}"/*/; do
            if [[ -d "$drv_path" ]]; then
                local drv=$(basename "$drv_path")

                # 跳过非驱动目录
                if [[ "$drv" == "base_driver" ]] || [[ "$drv" == "device_tree" ]] || [[ "$drv" == "firmwares" ]]; then
                    continue
                fi

                source_count=$((source_count + 1))
                log_info "  📁 $drv"
            fi
        done

        if [[ $source_count -eq 0 ]]; then
            log_info "  (无)"
        fi
    else
        log_info "  驱动源码目录不存在: $driver_dir"
    fi

    log_info ""
    log_info "========================================"
    log_info "使用方法:"
    log_info "  $(basename "$0") <驱动名> <板名>"
    log_info ""
    log_info "示例:"
    log_info "  $(basename "$0") chardev_base_00 alpha-board"
    log_info "========================================"
}

# 显示帮助
show_help() {
    cat << EOF
用法: $(basename "$0") <驱动名> [板名] [选项]
   或: $(basename "$0") <产物目录> [选项]
   或: $(basename "$0") --list

参数:
  驱动名        驱动名称（如：chardev_base_00）
  板名          板名称（如：alpha-board，默认：alpha-board）
  产物目录      驱动产物目录的完整路径

选项:
  --list            列出所有可部署的驱动（已构建的产物）
  --target=TYPE     部署目标 (tftp|nfs|local|remote)
  --tftp-dir=PATH   TFTP目录
  --nfs-dir=PATH    NFS目录
  --local-dir=PATH  本地目录
  --remote=HOST     远程主机
  --remote-path=PATH 远程路径
  --help, -h        显示此帮助信息

示例:
  # 列出可部署的驱动
  $(basename "$0") --list

  # 使用驱动名和板名（推荐）
  $(basename "$0") chardev_base_00 alpha-board
  $(basename "$0") chardev_base_00          # 使用默认板名 alpha-board

  # 使用产物目录路径
  $(basename "$0") out/driver_artifacts/chardev_base_00/alpha-board
  $(basename "$0") driver/chardev_base_00/alpha-board

  # 直接部署到TFTP
  $(basename "$0") chardev_base_00 alpha-board --target=tftp

  # 部署到NFS
  $(basename "$0") chardev_base_00 alpha-board --target=nfs

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
    local driver_name=""
    local board_name=""
    local positional_args=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list) list_drivers; exit 0 ;;
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
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    # 处理位置参数
    if [[ ${#positional_args[@]} -eq 0 ]]; then
        log_error "缺少产物目录参数"
        show_help
        exit 1
    elif [[ ${#positional_args[@]} -eq 1 ]]; then
        # 单个参数，可能是目录路径或驱动名
        artifacts_dir="${positional_args[0]}"
        # 如果不是有效目录，尝试构建路径
        if [[ ! -d "$artifacts_dir" ]]; then
            # 尝试: out/driver_artifacts/<驱动名>/alpha-board
            local guess1="${PROJECT_ROOT}/out/driver_artifacts/${artifacts_dir}/alpha-board"
            # 尝试: driver/<驱动名>/alpha-board
            local guess2="${PROJECT_ROOT}/driver/${artifacts_dir}/alpha-board"
            # 尝试: out/driver_artifacts/<驱动名>/<板名>（如果板名是默认的）
            if [[ -d "$guess1" ]]; then
                artifacts_dir="$guess1"
            elif [[ -d "$guess2" ]]; then
                artifacts_dir="$guess2"
            else
                log_error "目录不存在: $artifacts_dir"
                log_error "尝试查找的路径:"
                log_error "  - $guess1"
                log_error "  - $guess2"
                exit 1
            fi
        fi
    elif [[ ${#positional_args[@]} -eq 2 ]]; then
        # 两个参数：驱动名 和 板名
        driver_name="${positional_args[0]}"
        board_name="${positional_args[1]}"
        artifacts_dir="${PROJECT_ROOT}/out/driver_artifacts/${driver_name}/${board_name}"
        # 如果产物目录不存在，尝试源码目录
        if [[ ! -d "$artifacts_dir" ]]; then
            local src_dir="${PROJECT_ROOT}/driver/${driver_name}/${board_name}"
            if [[ -d "$src_dir" ]]; then
                artifacts_dir="$src_dir"
                log_warn "产物目录不存在，使用源码目录: $artifacts_dir"
            else
                log_error "目录不存在: $artifacts_dir"
                log_error "源码目录也不存在: $src_dir"
                exit 1
            fi
        fi
    else
        log_error "参数过多"
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
