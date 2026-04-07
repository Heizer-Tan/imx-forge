#!/bin/bash
#
# 设备树节点美化打印脚本
#
# 用法: show_device_tree.sh <设备树文件>
#
# 功能:
#   - 美化显示设备树节点结构
#   - 高亮显示节点和属性
#   - 显示节点路径和compatible属性
#   - 方便部署前预览设备树内容
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# 显示帮助
show_help() {
    cat << EOF
用法: $(basename "$0") <设备树文件> [选项]

参数:
  设备树文件    .dtb或.dts文件路径

选项:
  --all, -a     显示完整DTS内容
  --search, -s  搜索节点或属性
  --detailed, -d 显示详细信息

示例:
  show_device_tree.sh out/driver_artifacts/example-driver/alpha-board/imx6ull-aes-example-driver.dtb
  show_device_tree.sh driver/device_tree/alpha-board/example-driver/imx6ull-aes-example-driver.dts
  show_device_tree.sh example.dtb --search "compatible"
  show_device_tree.sh example.dtb --all

功能:
  ✓ 美化显示设备树节点结构
  ✓ 高亮显示节点和属性
  ✓ 显示节点路径和compatible属性
  ✓ 方便部署前预览设备树内容

EOF
}

# 检查dtc是否可用
check_dtc() {
    if ! command -v dtc >/dev/null 2>&1; then
        echo -e "${RED}错误: dtc工具不可用${NC}"
        echo "请安装设备树编译器: sudo apt-get install device-tree-compiler"
        exit 1
    fi
}

# 打印设备树节点（树形结构）
print_device_tree() {
    local dtb_file="$1"
    local show_all="$2"

    echo ""
    echo -e "${BOLD}${CYAN}🌳 设备树节点结构${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""

    # 反编译设备树
    local dts_content
    if [[ "$dtb_file" == *.dtb ]]; then
        dts_content=$(dtc -I dtb -O dts "$dtb_file" 2>/dev/null)
    elif [[ "$dtb_file" == *.dts ]]; then
        dts_content=$(cat "$dtb_file")
    else
        echo -e "${RED}错误: 不支持的文件格式${NC}"
        exit 1
    fi

    if [[ -z "$dts_content" ]]; then
        echo -e "${RED}错误: 无法读取设备树文件${NC}"
        exit 1
    fi

    # 显示文件信息
    local file_size=$(ls -lh "$dtb_file" | awk '{print $5}')
    echo -e "${CYAN}📁 文件:${NC} $dtb_file"
    echo -e "${CYAN}📏 大小:${NC} $file_size"
    echo ""

    # 解析并显示节点树
    local indent=0
    local line_num=0

    echo -e "${BOLD}${GREEN}🌲 节点树结构${NC}"
    echo ""

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # 跳过空行和header
        if [[ -z "$line" ]] || [[ "$line" =~ ^//.* ]] || [[ "$line" =~ ^#include ]]; then
            continue
        fi

        # 计算缩进级别
        local leading_spaces=${line%%[^[:space:]]*}
        local space_count=${#leading_spaces}
        local new_indent=$((space_count / 4))

        # 检测节点开始
        if [[ "$line" =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*\{ ]]; then
            local node_name=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*{.*//' | tr -d ' ')

            # 生成树形前缀
            local prefix=""
            local i=0
            while [[ $i -lt $new_indent ]]; do
                if [[ $i -eq 0 ]]; then
                    prefix="│  "
                else
                    prefix="${prefix}│  "
                fi
                i=$((i + 1))
            done

            echo -e "${BLUE}$prefix├──${GREEN}${node_name}${NC}"
            indent=$((new_indent + 1))

        # 检测节点结束
        elif [[ "$line" =~ ^[[:space:]]*\}[[:space:]]*\;?[[:space:]]*$ ]]; then
            indent=$((indent - 1))

        # 检测属性
        elif [[ "$line" =~ [[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*= ]]; then
            local attr_name=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*=.*//' | tr -d ' ')
            local attr_value=$(echo "$line" | sed 's/.*=[[:space:]]*//' | tr -d '";')

            # 高亮显示重要属性
            case "$attr_name" in
                compatible)
                    local prefix=""
                    local i=1
                    while [[ $i -lt $indent ]]; do
                        prefix="${prefix}│  "
                        i=$((i + 1))
                    done
                    echo -e "${BLUE}$prefix   ${MAGENTA}✦${NC} ${CYAN}$attr_name${NC} = ${YELLOW}\"$attr_value\"${NC}"
                    ;;
                status)
                    local prefix=""
                    local i=1
                    while [[ $i -lt $indent ]]; do
                        prefix="${prefix}│  "
                        i=$((i + 1))
                    done
                    local status_color="$GREEN"
                    if [[ "$attr_value" == "disabled" ]]; then
                        status_color="$YELLOW"
                    fi
                    echo -e "${BLUE}$prefix   ${MAGENTA}✦${NC} ${CYAN}$attr_name${NC} = ${status_color}\"$attr_value\"${NC}"
                    ;;
            esac
        fi
    done <<< "$dts_content"

    echo ""
    echo -e "${BOLD}${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""

    # 详细模式：显示完整DTS内容
    if [[ "$show_all" == "true" ]]; then
        echo -e "${BOLD}${CYAN}📄 完整DTS内容${NC}"
        echo ""
        echo "$dts_content"
        echo ""
    fi
}

# 显示设备树详细信息
print_device_tree_detailed() {
    local dtb_file="$1"

    echo ""
    echo -e "${BOLD}${CYAN}🔍 设备树详细信息${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""

    # 反编译设备树
    local dts_content=$(dtc -I dtb -O dts "$dtb_file" 2>/dev/null)

    # 统计信息
    local node_count=$(echo "$dts_content" | grep -c "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*{")
    local property_count=$(echo "$dts_content" | grep -c "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=")
    local compatible_count=$(echo "$dts_content" | grep -c "compatible=")

    echo -e "${CYAN}📊 统计信息:${NC}"
    echo "  节点数量: $node_count"
    echo "  属性数量: $property_count"
    echo "  Compatible属性: $compatible_count"
    echo ""

    # 列出所有节点
    echo -e "${CYAN}🌲 所有节点:${NC}"
    echo "$dts_content" | grep "^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*{" | sed 's/^[[:space:]]*//' | sed 's/{.*//' | while read -r node; do
        echo "  - $node"
    done
    echo ""

    # 列出所有compatible属性
    echo -e "${CYAN}🔗 Compatible属性:${NC}"
    echo "$dts_content" | grep "compatible=" | sed 's/.*compatible=//' | tr -d '";' | while read -r compat; do
        echo "  - $compat"
    done
    echo ""
}

# 搜索特定节点
search_node() {
    local dtb_file="$1"
    local search_term="$2"

    echo ""
    echo -e "${BOLD}${CYAN}🔍 搜索: ${YELLOW}$search_term${NC}"
    echo -e "${BLUE}═════════════════════════════════════════════════════${NC}"
    echo ""

    local dts_content=$(dtc -I dtb -O dts "$dtb_file" 2>/dev/null)

    # 搜索匹配的行
    local matches=$(echo "$dts_content" | grep -i -n "$search_term" | head -20)

    if [[ -n "$matches" ]]; then
        echo "$matches" | while IFS=: read -r line_num line_content; do
            echo -e "${GREEN}行 $line_num:${NC} $line_content"
        done
    else
        echo -e "${YELLOW}未找到匹配项${NC}"
    fi
    echo ""
}

# 主函数
main() {
    local dtb_file=""
    local search_term=""
    local show_all="false"
    local show_detailed="false"

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help|-h)
                show_help
                exit 0
                ;;
            --search|-s)
                search_term="$2"
                shift 2
                ;;
            --all|-a)
                show_all="true"
                shift
                ;;
            --detailed|-d)
                show_detailed="true"
                shift
                ;;
            -*)
                echo -e "${RED}错误: 未知选项 $1${NC}"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$dtb_file" ]]; then
                    dtb_file="$1"
                fi
                shift
                ;;
        esac
    done

    # 检查参数
    if [[ -z "$dtb_file" ]]; then
        echo -e "${RED}错误: 缺少设备树文件参数${NC}"
        show_help
        exit 1
    fi

    # 检查文件是否存在
    if [[ ! -f "$dtb_file" ]]; then
        echo -e "${RED}错误: 文件不存在: $dtb_file${NC}"
        exit 1
    fi

    # 检查dtc
    check_dtc

    # 搜索模式
    if [[ -n "$search_term" ]]; then
        search_node "$dtb_file" "$search_term"
    fi

    # 详细模式
    if [[ "$show_detailed" == "true" ]]; then
        print_device_tree_detailed "$dtb_file"
    fi

    # 打印设备树
    print_device_tree "$dtb_file" "$show_all"

    echo -e "${GREEN}✅ 显示完成${NC}"
}

# 执行主函数
main "$@"
