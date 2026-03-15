#!/bin/bash
#
# scripts_readme_check.sh
#
# 检查 scripts/ 目录下的每个 .sh 文件是否都有对应的 .md 文档
#
# 用法：
#   ./develop/scripts_readme_check.sh          # 检查所有脚本
#   ./develop/scripts_readme_check.sh --fix    # 自动创建缺失的文档模板
#   ./develop/scripts_readme_check.sh --verbose # 详细输出
#

# 获取脚本目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 选项
AUTO_FIX=0
VERBOSE=0
SHOW_HELP=0

# 统计变量
TOTAL_SCRIPTS=0
HAS_DOCS=0
MISSING_DOCS=0
EXTRA_DOCS=0

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            SHOW_HELP=1
            ;;
        --fix)
            AUTO_FIX=1
            ;;
        --verbose|-v)
            VERBOSE=1
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            SHOW_HELP=1
            ;;
    esac
    shift
done

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

检查 scripts/ 目录下的每个 .sh 文件是否都有对应的 .md 文档。

选项：
  --help, -h      显示此帮助信息
  --fix           自动创建缺失的文档模板
  --verbose, -v   详细输出模式

示例：
  $0                    # 检查所有脚本
  $0 --fix              # 检查并自动创建缺失的文档模板
  $0 --verbose          # 详细输出模式

文档镜像规则：
  脚本路径：scripts/build_helper/build-linux.sh
  文档路径：document/scripts/build_helper/build-linux.sh.md

EOF
}

if [ ${SHOW_HELP} -eq 1 ]; then
    show_help
    exit 0
fi

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_debug() {
    if [ ${VERBOSE} -eq 1 ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# 获取相对于项目根目录的路径
get_relative_path() {
    local full_path="$1"
    local root="$2"
    echo "${full_path#$root/}"
}

# 检查并创建文档模板
create_doc_template() {
    local script_path="$1"
    local doc_path="$2"
    local relative_script="$(get_relative_path "$script_path" "$PROJECT_ROOT")"
    local script_name="$(basename "$script_path")"

    # 创建目录
    local doc_dir="$(dirname "$doc_path")"
    mkdir -p "$doc_dir"

    # 写入模板
    cat > "$doc_path" << EOF
# ${script_name} 说明文档

> **文件路径**: \`$(get_relative_path "$script_path" "$PROJECT_ROOT")\`
> **脚本类型**: $(basename "$(dirname "$script_path")")
> **状态**: 待完善

## 概述

<!-- 请描述此脚本的作用和功能 -->

## 使用方法

\`\`\`bash
# 基本用法
$(basename "$script_path") [参数]

# 示例
$(basename "$script_path") --help
\`\`\`

## 参数说明

| 参数 | 说明 | 必需/可选 |
|------|------|-----------|
| --help | 显示帮助信息 | 可选 |
<!-- 请添加更多参数说明 -->

## 执行流程

<!-- 请描述脚本的主要执行步骤 -->

1. 步骤一
2. 步骤二
3. 步骤三

## 依赖关系

### 依赖的脚本
- <!-- 列出被此脚本 source 的其他脚本 -->

### 依赖的工具
- <!-- 列出此脚本需要的外部工具 -->

## 环境变量

| 变量 | 说明 | 默认值 |
|------|------|--------|
| <!-- 环境变量说明 --> | | |

## 输出产物

<!-- 描述脚本执行后生成的文件 -->

## 故障排除

### 常见错误

**错误**: <!-- 错误描述 -->
**原因**: <!-- 原因分析 -->
**解决**: <!-- 解决方法 -->

## 更新日志

| 日期 | 版本 | 更新内容 |
|------|------|----------|
| $(date +%Y-%m-%d) | 1.0 | 初始版本 |

---

> **文档生成时间**: $(date)
> **模板生成器**: \`develop/scripts_readme_check.sh --fix\`
EOF

    log_info "创建文档模板: $(get_relative_path "$doc_path" "$PROJECT_ROOT")"
}

# 主检查逻辑
main() {
    log_info "开始检查 scripts/ 目录..."
    log_info "项目根目录: ${PROJECT_ROOT}"
    echo ""

    # 检查 scripts 目录是否存在
    if [ ! -d "${PROJECT_ROOT}/scripts" ]; then
        log_error "scripts/ 目录不存在: ${PROJECT_ROOT}/scripts"
        exit 1
    fi

    # 收集所有脚本文件
    declare -a SCRIPT_FILES
    declare -a DOC_FILES

    log_debug "扫描脚本文件..."
    while IFS= read -r -d '' script_file; do
        # 跳过测试文件和备份文件
        if [[ "$script_file" == *".test.sh" ]] || [[ "$script_file" == *".backup."* ]]; then
            log_debug "跳过测试/备份文件: $(get_relative_path "$script_file" "$PROJECT_ROOT")"
            continue
        fi
        SCRIPT_FILES+=("$script_file")
    done < <(find "${PROJECT_ROOT}/scripts" -type f -name "*.sh" -print0 | sort -z)

    log_debug "扫描文档文件..."
    while IFS= read -r -d '' doc_file; do
        DOC_FILES+=("$doc_file")
    done < <(find "${PROJECT_ROOT}/document/scripts" -type f -name "*.sh.md" -print0 | sort -z)

    TOTAL_SCRIPTS=${#SCRIPT_FILES[@]}

    log_info "发现 ${TOTAL_SCRIPTS} 个脚本文件"
    log_info "发现 ${#DOC_FILES[@]} 个文档文件"
    echo ""

    # 检查每个脚本
    declare -a MISSING_LIST

    for script_file in "${SCRIPT_FILES[@]}"; do
        relative_script="$(get_relative_path "$script_file" "$PROJECT_ROOT")"
        # 移除 scripts/ 前缀，因为我们会添加 document/scripts/
        doc_relative="${relative_script#scripts/}"
        expected_doc="${PROJECT_ROOT}/document/scripts/${doc_relative}.md"

        if [ -f "$expected_doc" ]; then
            ((HAS_DOCS++))
            if [ ${VERBOSE} -eq 1 ]; then
                echo -e "  ${GREEN}✓${NC} ${relative_script} → document/scripts/${doc_relative}.md"
            fi
        else
            ((MISSING_DOCS++))
            MISSING_LIST+=("$script_file")
            echo -e "  ${RED}✗${NC} ${relative_script} → ${YELLOW}缺失文档${NC}"
        fi
    done

    # 检查多余的文档（孤立的文档）
    declare -a EXTRA_LIST

    for doc_file in "${DOC_FILES[@]}"; do
        relative_doc="$(get_relative_path "$doc_file" "$PROJECT_ROOT")"
        # 移除 document/scripts/ 前缀和 .md 后缀得到脚本路径
        script_relative="${relative_doc#document/scripts/}"
        script_relative="${script_relative%.md}"
        expected_script="${PROJECT_ROOT}/scripts/${script_relative}"

        if [ ! -f "$expected_script" ]; then
            ((EXTRA_DOCS++))
            EXTRA_LIST+=("$doc_file")
            echo -e "  ${YELLOW}!${NC} ${relative_doc} → ${CYAN}孤立文档（无对应脚本）${NC}"
        fi
    done

    # 输出统计
    echo ""
    log_info "========== 检查结果 =========="
    echo -e "  总脚本数:    ${BLUE}${TOTAL_SCRIPTS}${NC}"
    echo -e "  已有文档:    ${GREEN}${HAS_DOCS}${NC}"
    echo -e "  缺失文档:    ${RED}${MISSING_DOCS}${NC}"
    echo -e "  孤立文档:    ${YELLOW}${EXTRA_DOCS}${NC}"
    echo ""

    # 自动修复
    if [ ${AUTO_FIX} -eq 1 ] && [ ${MISSING_DOCS} -gt 0 ]; then
        log_info "开始自动创建缺失的文档模板..."
        echo ""

        for script_file in "${MISSING_LIST[@]}"; do
            relative_script="$(get_relative_path "$script_file" "$PROJECT_ROOT")"
            doc_relative="${relative_script#scripts/}"
            expected_doc="${PROJECT_ROOT}/document/scripts/${doc_relative}.md"
            create_doc_template "$script_file" "$expected_doc"
        done

        echo ""
        log_info "已创建 ${MISSING_DOCS} 个文档模板"
        log_info "请编辑文档内容：vim document/scripts/$(get_relative_path "${MISSING_LIST[0]}" "$PROJECT_ROOT").md"
    fi

    # 返回状态码
    if [ ${MISSING_DOCS} -gt 0 ]; then
        echo ""
        log_warn "发现 ${MISSING_DOCS} 个脚本缺少文档"
        log_info "运行 '$0 --fix' 自动创建文档模板"
        exit 1
    elif [ ${EXTRA_DOCS} -gt 0 ]; then
        echo ""
        log_warn "发现 ${EXTRA_DOCS} 个孤立文档（对应的脚本不存在）"
        exit 1
    else
        echo ""
        log_info "所有脚本都有对应的文档！"
        exit 0
    fi
}

main "$@"
