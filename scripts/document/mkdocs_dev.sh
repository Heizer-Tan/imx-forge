#!/usr/bin/env bash
##
## @file mkdocs_dev.sh
## @brief MkDocs documentation development environment manager
## @date 2026-04-08
##
## Usage:
##   ./scripts/document/mkdocs_dev.sh <command> [OPTIONS]
##
## Commands:
##   serve    Start MkDocs dev server (default)
##   build    Build static site to out/docs/site/
##   install  Create/update virtual environment and install dependencies
##   clean    Clean build artifacts (out/docs/, __pycache__)
##   reset    Delete and recreate .venv
##   help     Show this help message
##
## Options:
##   -p, --port PORT    Dev server port (default: 8000)
##   -b, --bind ADDR    Dev server bind address (default: 127.0.0.1)
##   -v, --verbose      Enable verbose output
##   -h, --help         Show this help message
##

set -eo pipefail

# === Constants ===
readonly MIN_PYTHON_MAJOR=3
readonly MIN_PYTHON_MINOR=10
readonly VENV_DIR=".venv"
readonly DEPS_MARKER=".deps_installed"
readonly DOCS_OUTPUT_DIR="out/docs/site"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# === Source libraries ===
source "$SCRIPT_DIR/../lib/bash/lib_common.sh"

# === Global variables ===
DEV_PORT=8000
DEV_ADDR="127.0.0.1"
VERBOSE=false

# =============================================================================
# Utility functions
# =============================================================================

verbose_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "[VERBOSE] $*"
    fi
}

# =============================================================================
# Python environment
# =============================================================================

check_python() {
    if ! command -v python3 &>/dev/null; then
        log_error "Python 3 未安装，请先安装 Python >= ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}"
        log_info "  Ubuntu/Debian: sudo apt install python3 python3-venv"
        log_info "  macOS:         brew install python@3.12"
        exit 1
    fi

    local major minor
    major=$(python3 -c 'import sys; print(sys.version_info.major)')
    minor=$(python3 -c 'import sys; print(sys.version_info.minor)')

    if [[ "$major" -lt "$MIN_PYTHON_MAJOR" ]] || \
       [[ "$major" -eq "$MIN_PYTHON_MAJOR" && "$minor" -lt "$MIN_PYTHON_MINOR" ]]; then
        log_error "Python 版本过低: ${major}.${minor}，需要 >= ${MIN_PYTHON_MAJOR}.${MIN_PYTHON_MINOR}"
        exit 1
    fi

    local full_version
    full_version=$(python3 --version 2>&1)
    verbose_log "Found: $full_version"
}

create_venv() {
    local venv_path="$PROJECT_ROOT/$VENV_DIR"

    if [[ -d "$venv_path" ]]; then
        verbose_log "虚拟环境已存在: $venv_path"
        return 0
    fi

    log_info "创建 Python 虚拟环境: $venv_path"
    python3 -m venv "$venv_path"

    if [[ ! -d "$venv_path" ]]; then
        log_error "虚拟环境创建失败"
        exit 1
    fi

    log_success "虚拟环境创建成功"
}

activate_venv() {
    local activate_script="$PROJECT_ROOT/$VENV_DIR/bin/activate"

    if [[ ! -f "$activate_script" ]]; then
        log_error "虚拟环境激活脚本不存在: $activate_script"
        log_info "请先运行: $0 install"
        exit 1
    fi

    source "$activate_script"
    verbose_log "虚拟环境已激活"
}

install_deps() {
    local marker="$PROJECT_ROOT/$VENV_DIR/$DEPS_MARKER"
    local pyproject="$SCRIPT_DIR/pyproject.toml"

    # Check if deps are already installed and pyproject hasn't changed
    if [[ -f "$marker" ]]; then
        local marker_hash pyproject_hash
        marker_hash=$(cat "$marker" 2>/dev/null)
        pyproject_hash=$(md5sum "$pyproject" 2>/dev/null | cut -d' ' -f1)

        if [[ "$marker_hash" == "$pyproject_hash" ]]; then
            verbose_log "依赖已安装且未变更，跳过安装"
            return 0
        fi
    fi

    log_info "安装文档开发依赖..."
    pip install --upgrade pip --quiet
    pip install -e "$SCRIPT_DIR" --quiet

    # Write marker with pyproject hash for change detection
    md5sum "$pyproject" 2>/dev/null | cut -d' ' -f1 > "$marker"
    log_success "依赖安装完成"
}

ensure_venv() {
    check_python
    create_venv
    activate_venv
    install_deps
}

# =============================================================================
# Command implementations
# =============================================================================

cmd_serve() {
    ensure_venv

    log_cyan "=== MkDocs 开发服务器 ==="
    log_info "地址: http://${DEV_ADDR}:${DEV_PORT}"
    log_info "文档: $PROJECT_ROOT/document"
    echo ""

    cd "$PROJECT_ROOT"
    mkdocs serve --dev-addr="${DEV_ADDR}:${DEV_PORT}"
}

cmd_build() {
    ensure_venv

    local output_path="$PROJECT_ROOT/$DOCS_OUTPUT_DIR"

    log_cyan "=== MkDocs 构建 ==="
    log_info "输出: $output_path"
    echo ""

    cd "$PROJECT_ROOT"
    mkdocs build --clean -d "$DOCS_OUTPUT_DIR"

    log_success "构建完成: $output_path"
}

cmd_install() {
    ensure_venv
    log_success "环境准备就绪"
}

cmd_clean() {
    log_cyan "=== 清理构建产物 ==="

    local cleaned=0

    # Clean MkDocs output
    if [[ -d "$PROJECT_ROOT/$DOCS_OUTPUT_DIR" ]]; then
        rm -rf "$PROJECT_ROOT/$DOCS_OUTPUT_DIR"
        log_info "已清理: $DOCS_OUTPUT_DIR"
        cleaned=$((cleaned + 1))
    fi

    # Clean __pycache__
    local pycache_count
    pycache_count=$(find "$PROJECT_ROOT" -type d -name "__pycache__" 2>/dev/null | wc -l)
    if [[ "$pycache_count" -gt 0 ]]; then
        find "$PROJECT_ROOT" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        log_info "已清理: __pycache__ (${pycache_count} 个)"
        cleaned=$((cleaned + 1))
    fi

    if [[ "$cleaned" -eq 0 ]]; then
        log_info "没有需要清理的内容"
    else
        log_success "清理完成 (${cleaned} 项)"
    fi
}

cmd_reset() {
    local venv_path="$PROJECT_ROOT/$VENV_DIR"

    log_cyan "=== 重置虚拟环境 ==="

    if [[ -d "$venv_path" ]]; then
        log_info "删除: $venv_path"
        rm -rf "$venv_path"
        log_success "已删除旧环境"
    fi

    # Recreate
    ensure_venv
    log_success "虚拟环境已重建"
}

# =============================================================================
# Help & Argument parsing
# =============================================================================

show_help() {
    grep '^##' "$0" | sed 's/^## \?//g' | sed '/^$/d'
    exit 0
}

parse_args() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            serve|build|install|clean|reset|help)
                command="$1"
                shift
                ;;
            -p|--port)
                DEV_PORT="$2"
                shift 2
                ;;
            -b|--bind)
                DEV_ADDR="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "未知参数: $1"
                echo ""
                show_help
                ;;
        esac
    done

    # Default command
    command="${command:-serve}"

    case "$command" in
        serve)    cmd_serve ;;
        build)    cmd_build ;;
        install)  cmd_install ;;
        clean)    cmd_clean ;;
        reset)    cmd_reset ;;
        help)     show_help ;;
    esac
}

# =============================================================================
# Entry point
# =============================================================================

parse_args "$@"
