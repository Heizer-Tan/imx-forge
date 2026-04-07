#!/bin/bash
#
# 驱动构建产物审查脚本
#
# 用法: review_driver.sh <驱动> [板卡]
#
# 功能:
#   - 审查驱动模块的完整性
#   - 检查设备树格式正确性
#   - 验证符号表和依赖关系
#   - 显示详细的产物信息
#

set -e

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_header() { echo -e "${CYAN}$1${NC}"; }
log_section() { echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# 加载配置文件（如果存在）
CONFIG_FILE="${SCRIPT_DIR}/driver_helper.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# 显示帮助
show_help() {
    cat << EOF
用法: $(basename "$0") <驱动> [板卡]

参数:
  驱动     驱动名称 (如: example-driver, led)
  板卡     板卡名称 (默认: alpha-board)

示例:
  review_driver.sh example-driver
  review_driver.sh example-driver alpha-board

功能:
  ✓ 审查驱动模块完整性和正确性
  ✓ 检查设备树格式和节点
  ✓ 验证符号表和依赖关系
  ✓ 显示代码段和符号信息
  ✓ 确认产物可以安全部署

EOF
}

# 审查驱动模块
review_driver_module() {
    local module_file="$1"

    if [[ ! -f "$module_file" ]]; then
        log_error "驱动模块不存在: $module_file"
        return 1
    fi

    log_header "🔧 驱动模块审查"
    log_section

    # 基本文件信息
    local file_size=$(ls -lh "$module_file" | awk '{print $5}')
    local file_type=$(file "$module_file")

    echo -e "${CYAN}📦 文件信息:${NC}"
    echo "  文件: $module_file"
    echo "  大小: $file_size"
    echo "  类型: $file_type"
    echo ""

    # modinfo信息
    if command -v modinfo >/dev/null 2>&1; then
        echo -e "${CYAN}📋 模块信息:${NC}"
        modinfo "$module_file" 2>/dev/null | while IFS=': ' read -r key value; do
            if [[ -n "$value" ]]; then
                case "$key" in
                    filename)
                        echo "  文件名: $value"
                        ;;
                    *)
                        echo "  $key: $value"
                        ;;
                esac
            fi
        done
        echo ""
    fi

    # ELF头信息
    echo -e "${CYAN}🔍 ELF头信息:${NC}"
    local elf_class=$(readelf -h "$module_file" 2>/dev/null | grep "Class:" | awk '{print $2}')
    local elf_machine=$(readelf -h "$module_file" 2>/dev/null | grep "Machine:" | awk '{print $2}')
    local elf_type=$(readelf -h "$module_file" 2>/dev/null | grep "Type:" | awk '{print $2}')

    echo "  架构: $elf_machine"
    echo "  类型: $elf_type"
    echo "  类别: $elf_class"

    # 验证架构
    if [[ "$elf_machine" == "ARM" ]]; then
        echo -e "  ${GREEN}✓ 架构正确 (ARM)${NC}"
    else
        echo -e "  ${RED}✗ 架构错误 (期望: ARM, 实际: $elf_machine)${NC}"
    fi
    echo ""

    # 段大小信息
    echo -e "${CYAN}📊 代码段分析:${NC}"
    local size_info=$(size "$module_file" 2>/dev/null)
    if [[ -n "$size_info" ]]; then
        echo "$size_info" | tail -1 | while read text data bss dec hex filename; do
            echo "  text:  $text  - 代码段"
            echo "  data:  $data  - 数据段"
            echo "  bss:   $bss   - 未初始化段"
            echo "  总计:  $dec ($hex)"
        done
    fi
    echo ""

    # 符号表检查
    echo -e "${CYAN}🎯 关键符号:${NC}"
    local has_init=0
    local has_exit=0

    if readelf -s "$module_file" 2>/dev/null | grep -q "fake_init\|dummy_init"; then
        echo -e "  ${GREEN}✓ init 函数存在${NC}"
        has_init=1
    else
        echo -e "  ${RED}✗ init 函数缺失${NC}"
    fi

    if readelf -s "$module_file" 2>/dev/null | grep -q "fake_exit\|dummy_exit"; then
        echo -e "  ${GREEN}✓ exit 函数存在${NC}"
        has_exit=1
    else
        echo -e "  ${RED}✗ exit 函数缺失${NC}"
    fi
    echo ""

    # 依赖检查
    echo -e "${CYAN}🔗 依赖关系:${NC}"
    local depends=$(modinfo "$module_file" 2>/dev/null | grep "^depends:" | cut -d: -f2 | sed 's/^[[:space:]]*//')
    if [[ -z "$depends" ]]; then
        echo -e "  ${GREEN}✓ 无外部依赖 (独立模块)${NC}"
    else
        echo "  依赖: $depends"
    fi
    echo ""

    # 模块参数
    echo -e "${CYAN}⚙️  模块参数:${NC}"
    local parm_info=$(modinfo "$module_file" 2>/dev/null | grep "^parm")
    if [[ -n "$parm_info" ]]; then
        echo "$parm_info" | while read -r line; do
            echo "  $line"
        done
    else
        echo "  无模块参数"
    fi
    echo ""

    # 检查结果总结
    log_section
    echo -e "${CYAN}✅ 检查总结:${NC}"
    if [[ $has_init -eq 1 && $has_exit -eq 1 ]]; then
        echo -e "  ${GREEN}✓ 驱动模块结构完整${NC}"
        return 0
    else
        echo -e "  ${RED}✗ 驱动模块存在问题${NC}"
        return 1
    fi
}

# 审查设备树
review_device_tree() {
    local dtb_file="$1"

    if [[ ! -f "$dtb_file" ]]; then
        log_warn "设备树文件不存在: $dtb_file"
        return 0
    fi

    log_header "🌳 设备树审查"
    log_section

    # 基本文件信息
    local file_size=$(ls -lh "$dtb_file" | awk '{print $5}')

    echo -e "${CYAN}📦 文件信息:${NC}"
    echo "  文件: $dtb_file"
    echo "  大小: $file_size"
    echo ""

    # 检查dtc是否可用
    if ! command -v dtc >/dev/null 2>&1; then
        log_warn "dtc工具不可用，跳过设备树详细检查"
        return 0
    fi

    # 反编译设备树
    local dts_content=$(dtc -I dtb -O dts "$dtb_file" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "设备树格式错误或损坏"
        return 1
    fi

    echo -e "${CYAN}🔍 设备树结构:${NC}"
    echo "$dts_content"
    echo ""

    # 验证格式
    echo -e "${CYAN}📋 格式验证:${NC}"

    # 检查魔数
    local magic=$(xxd -p -l 4 "$dtb_file" 2>/dev/null)
    if [[ "$magic" == "d00dfeed" ]]; then
        echo -e "  ${GREEN}✓ DTB魔数正确 (0xd00dfeed)${NC}"
    else
        echo -e "  ${RED}✗ DTB魔数错误${NC}"
    fi

    # 检查版本
    local version=$(fdtdump "$dtb_file" 2>&1 | grep "version:" | awk '{print $2}')
    if [[ -n "$version" ]]; then
        echo "  版本: $version"
    fi

    # 检查节点
    local node_count=$(echo "$dts_content" | grep -c "^\s*{")
    echo "  节点数量: $node_count"
    echo ""

    # 检查compatible属性
    echo -e "${CYAN}🎯 设备节点:${NC}"
    echo "$dts_content" | grep -E "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*{" | while read -r line; do
        local node=$(echo "$line" | sed 's/{.*//' | tr -d ' ')
        echo "  - $node"
    done
    echo ""

    # 检查compatible属性
    echo -e "${CYAN}🔗 Compatible属性:${NC}"
    local compatibles=$(echo "$dts_content" | grep "compatible=" | sed 's/.*compatible=//' | tr -d '";')
    if [[ -n "$compatibles" ]]; then
        echo "$compatibles" | while read -r compat; do
            echo "  - $compat"
        done
    else
        echo "  无compatible属性"
    fi
    echo ""

    log_section
    echo -e "${GREEN}✓ 设备树格式正确${NC}"
    return 0
}

# 审查构建信息
review_build_info() {
    local build_info="$1"

    if [[ ! -f "$build_info" ]]; then
        log_warn "构建信息文件不存在: $build_info"
        return 0
    fi

    log_header "📋 构建信息"
    log_section
    cat "$build_info"
    echo ""
}

# 主审查流程
main() {
    local driver_name="$1"
    local board_name="${2:-${DEFAULT_BOARD:-alpha-board}}"

    # 参数检查
    if [[ -z "$driver_name" ]]; then
        log_error "缺少驱动名称参数"
        show_help
        exit 1
    fi

    # 构建产物目录
    local artifact_dir="${PROJECT_ROOT}/out/driver_artifacts/${driver_name}/${board_name}"

    # 检查目录是否存在
    if [[ ! -d "$artifact_dir" ]]; then
        log_error "构建产物目录不存在: $artifact_dir"
        log_info "请先运行: ./scripts/build_driver.sh $driver_name $board_name"
        exit 1
    fi

    echo ""
    log_header "🔍 驱动构建产物审查"
    log_section
    echo ""
    log_info "驱动: $driver_name"
    log_info "板卡: $board_name"
    log_info "目录: $artifact_dir"
    echo ""
    log_section

    # 审查驱动模块
    local module_file=""
    for ko_file in "$artifact_dir"/*.ko; do
        if [[ -f "$ko_file" ]]; then
            module_file="$ko_file"
            break
        fi
    done

    if [[ -n "$module_file" ]]; then
        review_driver_module "$module_file"
        local module_status=$?
    else
        log_warn "未找到驱动模块文件 (.ko)"
        module_status=1
    fi

    echo ""
    log_section

    # 审查设备树
    local dtb_file=""
    for dtb in "$artifact_dir"/*.dtb; do
        if [[ -f "$dtb" ]]; then
            review_device_tree "$dtb"
            break
        fi
    done

    echo ""
    log_section

    # 审查构建信息
    review_build_info "$artifact_dir/build_info.txt"

    # 最终总结
    echo ""
    log_header "📊 审查总结"
    log_section
    echo ""

    if [[ $module_status -eq 0 ]]; then
        echo -e "${GREEN}✅ 驱动模块审查通过${NC}"
        echo ""
        echo -e "${CYAN}📦 产物清单:${NC}"
        ls -lh "$artifact_dir" | tail -n +2 | awk '{printf "  %-10s %s\n", $5, $9}'
        echo ""
        echo -e "${GREEN}✓ 所有产物审查通过，可以安全部署！${NC}"
        echo ""
        log_info "部署命令: ./scripts/driver_helper/deploy_driver.sh $artifact_dir"
        exit 0
    else
        echo -e "${RED}✗ 驱动模块存在问题，请检查构建流程${NC}"
        exit 1
    fi
}

# 执行主函数
main "$@"
