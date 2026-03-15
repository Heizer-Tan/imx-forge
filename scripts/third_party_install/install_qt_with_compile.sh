#!/usr/bin/env bash
# ==============================================================================
# install_qt_with_compile.sh - Qt 编译安装脚本
# ==============================================================================
# 功能：
#   1. 先回到默认分支（main）
#   2. 创建 compile-${date} 分支
#   3. 将自定义配置拷贝覆盖到 qt-compile-pipeline
#   4. 执行 Qt 编译流程
#
# 输出目录：
#   - Host Qt:   项目根目录/host/qt6-host/
#   - Target Qt: 项目根目录/out/qt6-imx6ull/
#   - 中间文件:  项目根目录/out/.qt-workdir/
#
# 使用方法:
#   bash scripts/third_party_install/install_qt_with_compile.sh [--stage <stage>]
#
# 选项:
#   --stage <n>    只执行指定阶段（1-6）
#                  1=fetch源码, 2=fetch工具链, 3=build host, 4=install target deps, 5=build target, 6=package
#   --branch <name> 使用自定义分支名（默认: compile-YYYYMMDD）
# ==============================================================================

set -euo pipefail

# ================================================================
# 脚本目录和项目根目录
# ================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/logging.sh
source "${SCRIPT_DIR}/../lib/logging.sh"

PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
QT_PIPELINE_DIR="${PROJECT_ROOT}/third_party/qt-compile-pipeline"
CONFIG_SOURCE_DIR="${SCRIPT_DIR}/config/qt"
CONFIG_TARGET_DIR="${QT_PIPELINE_DIR}/config"
DEFAULT_BRANCH="main"

# ================================================================
# 参数解析
# ================================================================
SPECIFIC_STAGE=""
CUSTOM_BRANCH_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stage)
            SPECIFIC_STAGE="$2"
            shift 2
            ;;
        --branch)
            CUSTOM_BRANCH_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "用法: $0 [--stage <n>] [--branch <name>]"
            echo ""
            echo "选项:"
            echo "  --stage <n>      只执行指定阶段（1-6）"
            echo "  --branch <name>  使用自定义分支名（默认: compile-YYYYMMDD）"
            echo ""
            echo "输出目录:"
            echo "  Host Qt:   ${PROJECT_ROOT}/host/qt6-host/"
            echo "  Target Qt: ${PROJECT_ROOT}/out/qt6-imx6ull/"
            echo "  中间文件:  ${PROJECT_ROOT}/out/.qt-workdir/"
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            echo "使用 --help 查看帮助"
            exit 1
            ;;
    esac
done

# ================================================================
# 工具函数
# ================================================================
die() {
    log_error "$@"
    exit 1
}

# ================================================================
# 前置检查
# ================================================================
log_info "=== Qt 编译安装脚本 ==="
log_info "项目根目录: ${PROJECT_ROOT}"
log_info "qt-compile-pipeline: ${QT_PIPELINE_DIR}"
log_info "配置源目录: ${CONFIG_SOURCE_DIR}"
echo ""

# 检查目录是否存在
if [[ ! -d "${QT_PIPELINE_DIR}" ]]; then
    die "qt-compile-pipeline 目录不存在: ${QT_PIPELINE_DIR}"
fi

if [[ ! -d "${CONFIG_SOURCE_DIR}" ]]; then
    die "配置源目录不存在: ${CONFIG_SOURCE_DIR}"
fi

# 列出将要覆盖的配置文件
log_info "准备覆盖的配置文件:"
for conf in "${CONFIG_SOURCE_DIR}"/*.conf; do
    if [[ -f "$conf" ]]; then
        log_info "  - $(basename "$conf")"
    fi
done
echo ""

# ================================================================
# 在子模块中切换分支（不影响主项目）
# ================================================================
log_info "在子模块 qt-compile-pipeline 中切换分支"

# 先回到默认分支
log_info "子模块回到默认分支: ${DEFAULT_BRANCH}"
if ! git -C "${QT_PIPELINE_DIR}" checkout "${DEFAULT_BRANCH}" 2>/dev/null; then
    die "无法切换到默认分支 ${DEFAULT_BRANCH}"
fi
log_info "子模块当前分支: $(git -C "${QT_PIPELINE_DIR}" symbolic-ref --short HEAD)"
echo ""

# 创建编译分支
if [[ -n "${CUSTOM_BRANCH_NAME}" ]]; then
    BRANCH_NAME="${CUSTOM_BRANCH_NAME}"
else
    BRANCH_NAME="compile-$(date +%Y%m%d)"
fi

# 检查分支是否已存在
if git -C "${QT_PIPELINE_DIR}" rev-parse --verify "${BRANCH_NAME}" >/dev/null 2>&1; then
    log_warn "分支 ${BRANCH_NAME} 已存在，删除旧分支..."
    git -C "${QT_PIPELINE_DIR}" branch -D "${BRANCH_NAME}"
fi

# 创建并切换到新分支
log_info "子模块创建新分支: ${BRANCH_NAME}"
git -C "${QT_PIPELINE_DIR}" checkout -b "${BRANCH_NAME}"
log_info "子模块当前分支: $(git -C "${QT_PIPELINE_DIR}" symbolic-ref --short HEAD)"
echo ""

# 显示主项目分支状态（未改变）
log_info "主项目分支保持不变: $(git symbolic-ref --short HEAD)"
echo ""

# ================================================================
# 覆盖配置文件
# ================================================================
log_info "=== 覆盖配置文件 ==="

for conf_file in "${CONFIG_SOURCE_DIR}"/*.conf; do
    if [[ -f "$conf_file" ]]; then
        conf_name="$(basename "$conf_file")"
        target_path="${CONFIG_TARGET_DIR}/${conf_name}"

        log_info "拷贝 ${conf_name}..."
        cp "$conf_file" "$target_path"
        log_info "  → ${target_path}"
    fi
done
echo ""

# ================================================================
# 显示配置摘要
# ================================================================
log_info "=== 配置摘要 ==="

# Source qt.conf 来获取配置变量
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/qt.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/host.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/target.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/third_party.conf"

log_info "Qt 版本: ${QT_VERSION}"
log_info "模块: ${QT_MODULES}"
log_info ""
log_info "输出路径:"
log_info "  Host Qt:   ${HOST_INSTALL_PREFIX}"
log_info "  Target Qt: ${TARGET_INSTALL_PREFIX}"
log_info "  工作目录:  ${WORK_DIR}"
echo ""

# ================================================================
# 执行编译
# ================================================================
log_info "=== 开始编译 ==="
echo ""

cd "${QT_PIPELINE_DIR}"

# 定义编译阶段函数
run_stage() {
    local stage="$1"
    local script="$2"
    local name="$3"

    log_info "阶段 ${stage}: ${name}"
    if bash "scripts/${script}"; then
        log_info "阶段 ${stage} 完成"
    else
        die "阶段 ${stage} 失败: ${name}"
    fi
    echo ""
}

# 根据参数执行对应阶段
if [[ -z "${SPECIFIC_STAGE}" ]]; then
    # 执行所有阶段
    run_stage "1" "00-fetch-qt-src.sh" "下载 Qt 源码"
    run_stage "2" "01-fetch-toolchain.sh" "下载交叉编译工具链"
    run_stage "3" "02-build-host-qt.sh" "编译 Host Qt"
    run_stage "4" "install_target_deps.sh" "安装 Target 依赖"
    run_stage "5" "03-build-target-qt.sh" "编译 Target Qt"
    run_stage "6" "04-package.sh" "打包"
else
    # 执行指定阶段
    case "${SPECIFIC_STAGE}" in
        1) run_stage "1" "00-fetch-qt-src.sh" "下载 Qt 源码" ;;
        2) run_stage "2" "01-fetch-toolchain.sh" "下载交叉编译工具链" ;;
        3) run_stage "3" "02-build-host-qt.sh" "编译 Host Qt" ;;
        4) run_stage "4" "install_target_deps.sh" "安装 Target 依赖" ;;
        5) run_stage "5" "03-build-target-qt.sh" "编译 Target Qt" ;;
        6) run_stage "6" "04-package.sh" "打包" ;;
        *)
            die "无效的阶段号: ${SPECIFIC_STAGE} (有效值: 1-6)"
            ;;
    esac
fi

# ================================================================
# 安装到 ROOTFS
# ================================================================
log_info "=== 安装到 ROOTFS ==="
echo ""

# 获取 superproject（主项目）的根目录，因为脚本在子模块中运行
GIT_PROJECT_ROOT="$(git rev-parse --show-superproject-working-tree)"
: "${GIT_PROJECT_ROOT:=$(git rev-parse --show-toplevel)}"

# ROOTFS 目录配置
ROOTFS_DIR="${GIT_PROJECT_ROOT}/rootfs/nfs"

# 重新加载配置文件以获取正确的路径（使用正确的 PROJECT_ROOT）
export PROJECT_ROOT="${GIT_PROJECT_ROOT}"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/qt.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/host.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/target.conf"
# shellcheck disable=SC1090
source "${CONFIG_TARGET_DIR}/third_party.conf"

# 检查 ROOTFS 是否存在
if [[ ! -d "${ROOTFS_DIR}" ]]; then
    log_warn "ROOTFS 目录不存在: ${ROOTFS_DIR}"
    log_warn "跳过 ROOTFS 安装步骤"
    log_warn ""
    log_warn "提示: 运行以下命令创建并验证 ROOTFS:"
    log_warn "  bash scripts/varified_rootfs_ok.sh"
else
    log_info "ROOTFS 目录: ${ROOTFS_DIR}"

    # 创建 ROOTFS 下的必要目录
    mkdir -p "${ROOTFS_DIR}/usr/local"
    mkdir -p "${ROOTFS_DIR}/usr/lib"
    mkdir -p "${ROOTFS_DIR}/lib"

    # --------------------------------------
    # 第 1 步: 安装 Target Qt 到 ROOTFS (/usr)
    # --------------------------------------
    log_info ""
    log_info "----------------------------------------"
    log_info "步骤 1/2: 安装 Target Qt"
    log_info "----------------------------------------"
    log_info "源目录: ${TARGET_INSTALL_PREFIX}"
    log_info "目标目录: ${ROOTFS_DIR}/usr"

    # 显示将要执行的操作
    log_info ""
    log_info "将要执行的操作:"
    log_info "  lib/*       -> ${ROOTFS_DIR}/usr/lib/"
    log_info "  bin/*       -> ${ROOTFS_DIR}/usr/bin/"
    log_info "  plugins/*   -> ${ROOTFS_DIR}/usr/lib/qt6/plugins/"
    log_info "  qml/*       -> ${ROOTFS_DIR}/usr/lib/qt6/qml/"
    log_info ""

    # 执行拷贝
    if [[ -d "${TARGET_INSTALL_PREFIX}" ]]; then
        # 创建目标目录
        mkdir -p "${ROOTFS_DIR}/usr/lib"
        mkdir -p "${ROOTFS_DIR}/usr/bin"
        mkdir -p "${ROOTFS_DIR}/usr/lib/qt6"

        # 拷贝库文件
        log_info "正在拷贝库文件..."
        if [[ -d "${TARGET_INSTALL_PREFIX}/lib" ]]; then
            cp -rf "${TARGET_INSTALL_PREFIX}/lib/"* "${ROOTFS_DIR}/usr/lib/"
            log_info "  ✓ 库文件已拷贝"
        fi

        # 拷贝可执行文件
        log_info "正在拷贝可执行文件..."
        if [[ -d "${TARGET_INSTALL_PREFIX}/bin" ]]; then
            cp -f "${TARGET_INSTALL_PREFIX}/bin/"* "${ROOTFS_DIR}/usr/bin/"
            log_info "  ✓ 可执行文件已拷贝"
        fi

        # 拷贝插件到 /usr/lib/qt6/plugins/
        if [[ -d "${TARGET_INSTALL_PREFIX}/plugins" ]]; then
            log_info "正在拷贝插件..."
            cp -rf "${TARGET_INSTALL_PREFIX}/plugins" "${ROOTFS_DIR}/usr/lib/qt6/"
            log_info "  ✓ 插件已拷贝"
        fi

        # 拷贝 QML 模块到 /usr/lib/qt6/qml/
        if [[ -d "${TARGET_INSTALL_PREFIX}/qml" ]]; then
            log_info "正在拷贝 QML 模块..."
            cp -rf "${TARGET_INSTALL_PREFIX}/qml" "${ROOTFS_DIR}/usr/lib/qt6/"
            log_info "  ✓ QML 模块已拷贝"
        fi

        # 拷贝其他目录（如 mkspecs, architectures 等）
        for dir in "${TARGET_INSTALL_PREFIX}"/*/; do
            dirname="$(basename "$dir")"
            # 跳过已处理的目录
            if [[ "$dirname" == "lib" || "$dirname" == "bin" || "$dirname" == "plugins" || "$dirname" == "qml" ]]; then
                continue
            fi
            # 拷贝其他目录到 /usr/lib/qt6/
            if [[ -d "$dir" ]]; then
                log_info "正在拷贝 ${dirname}..."
                cp -rf "$dir" "${ROOTFS_DIR}/usr/lib/qt6/"
            fi
        done

        log_info "✓ Qt 已安装到 ROOTFS /usr/"
    else
        log_warn "Target Qt 目录不存在，跳过: ${TARGET_INSTALL_PREFIX}"
    fi

    # --------------------------------------
    # 第 2 步: 安装第三方库到 ROOTFS
    # --------------------------------------
    log_info ""
    log_info "----------------------------------------"
    log_info "步骤 2/2: 安装第三方库"
    log_info "----------------------------------------"
    log_info "源目录: ${THIRD_PARTY_SYSROOT}"
    log_info "目标目录: ${ROOTFS_DIR}"

    # 检查第三方库 sysroot 是否存在
    if [[ ! -d "${THIRD_PARTY_SYSROOT}" ]]; then
        log_warn "第三方库 sysroot 不存在: ${THIRD_PARTY_SYSROOT}"
        log_warn "跳过第三方库安装"
    else
        # 查找并显示将要拷贝的库
        log_info ""
        log_info "找到的第三方库文件:"

        # 收集需要拷贝的文件
        declare -a LIB_FILES=()
        declare -a BIN_FILES=()

        # 查找 .so 文件（库文件），最多显示 20 个
        lib_count=0
        max_libs=20
        while IFS= read -r -d '' file; do
            LIB_FILES+=("$file")
            ((lib_count++)) || true
            [[ $lib_count -ge $max_libs ]] && break
        done < <(find "${THIRD_PARTY_SYSROOT}" -type f \( -name "*.so*" -o -name "*.a" \) -print0 2>/dev/null)

        # 查找可执行文件（排除 downloads 和 build 目录），最多显示 10 个
        bin_count=0
        max_bins=10
        while IFS= read -r -d '' file; do
            BIN_FILES+=("$file")
            ((bin_count++)) || true
            [[ $bin_count -ge $max_bins ]] && break
        done < <(find "${THIRD_PARTY_SYSROOT}" -type f -executable -not -path "*/downloads/*" -not -path "*/build/*" -not -name "*.so*" -print0 2>/dev/null)

        # 显示文件列表（最多显示前 20 个）
        if [[ ${#LIB_FILES[@]} -gt 0 ]]; then
            log_info "  库文件 (*.so, *.a):"
            for file in "${LIB_FILES[@]}"; do
                rel_path="${file#${THIRD_PARTY_SYSROOT}/}"
                log_info "    - ${rel_path}"
            done
            if [[ ${#LIB_FILES[@]} -ge 20 ]]; then
                log_info "    ... (还有更多)"
            fi
        fi

        if [[ ${#BIN_FILES[@]} -gt 0 ]]; then
            log_info "  可执行文件:"
            for file in "${BIN_FILES[@]}"; do
                rel_path="${file#${THIRD_PARTY_SYSROOT}/}"
                log_info "    - ${rel_path}"
            done
            if [[ ${#BIN_FILES[@]} -ge 10 ]]; then
                log_info "    ... (还有更多)"
            fi
        fi

        log_info ""
        log_info "将要执行的操作:"
        log_info "  1. 拷贝库文件 (*.so, *.a) -> ${ROOTFS_DIR}/usr/lib/"
        log_info "  2. 拷贝可执行文件 -> ${ROOTFS_DIR}/usr/bin/"
        log_info ""

        # 等待用户确认
        read -p "按 Enter 继续安装第三方库到 ROOTFS，或 Ctrl+C 取消..."

        # 拷贝库文件
        log_info "正在拷贝库文件..."
        mkdir -p "${ROOTFS_DIR}/usr/lib"
        if find "${THIRD_PARTY_SYSROOT}" -type f \( -name "*.so*" -o -name "*.a" \) -print0 2>/dev/null | \
           xargs -0 -I {} cp -d {} "${ROOTFS_DIR}/usr/lib/" 2>/dev/null; then
            log_info "✓ 已拷贝库文件到 ${ROOTFS_DIR}/usr/lib/"
        else
            log_warn "库文件拷贝失败或没有找到库文件"
        fi

        # 拷贝可执行文件
        log_info "正在拷贝可执行文件..."
        mkdir -p "${ROOTFS_DIR}/usr/bin"
        BIN_COUNT=0
        while IFS= read -r -d '' file; do
            basename="$(basename "$file")"
            if cp -f "$file" "${ROOTFS_DIR}/usr/bin/${basename}" 2>/dev/null; then
                ((BIN_COUNT++)) || true
            fi
        done < <(find "${THIRD_PARTY_SYSROOT}" -type f -executable -not -path "*/downloads/*" -not -path "*/build/*" -not -name "*.so*" -print0 2>/dev/null)

        if [[ $BIN_COUNT -gt 0 ]]; then
            log_info "✓ 已拷贝 ${BIN_COUNT} 个可执行文件到 ${ROOTFS_DIR}/usr/bin/"
        else
            log_warn "没有找到可执行文件或拷贝失败"
        fi
    fi

    # --------------------------------------
    # 安装完成摘要
    # --------------------------------------
    log_info ""
    log_info "=== ROOTFS 安装完成 ==="
    log_info ""
    log_info "安装内容:"
    log_info "  Qt 库:      ${ROOTFS_DIR}/usr/lib/"
    log_info "  Qt 可执行:  ${ROOTFS_DIR}/usr/bin/"
    log_info "  Qt 插件:    ${ROOTFS_DIR}/usr/lib/qt6/plugins/"
    log_info "  Qt QML:     ${ROOTFS_DIR}/usr/lib/qt6/qml/"
    log_info "  第三方库:   ${ROOTFS_DIR}/usr/lib/"
    log_info ""
fi

# ================================================================
# 完成
# ================================================================
echo ""
log_info "=== 编译完成 ==="
echo ""
log_info "输出位置:"
log_info "  Host Qt:   ${HOST_INSTALL_PREFIX}"
log_info "  Target Qt: ${TARGET_INSTALL_PREFIX}"
log_info ""
log_info "验证命令:"
log_info "  ${HOST_INSTALL_PREFIX}/bin/qmake -v"
log_info "  ${TARGET_INSTALL_PREFIX}/bin/qmake -v"
echo ""
log_info "当前分支: ${BRANCH_NAME}"
log_info "完成工作后，可以切换回 ${DEFAULT_BRANCH} 分支"
