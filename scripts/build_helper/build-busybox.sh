#!/bin/bash
#
# BusyBox build script for i.MX6ULL
#

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/../lib"

# Source shared logging (with fallback for standalone usage)
if [[ -f "${SCRIPT_LIB_DIR}/logging.sh" ]]; then
    source "${SCRIPT_LIB_DIR}/logging.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
    log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_debug() { if [[ "${DEBUG:-0}" == "1" ]]; then echo -e "${BLUE}[DEBUG]${NC} $1"; fi; }
    log_cmd()   { echo -e "${YELLOW}[CMD]${NC} $1"; }
fi

# Configuration
ARCH=arm
CROSS_COMPILE=arm-none-linux-gnueabihf-
CLEAN_BUILD=0
STATIC_BUILD=0
BUILD_ONLY=0
INSTALL_ONLY=0
SHOW_HELP=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            SHOW_HELP=1
            ;;
        --clean)
            CLEAN_BUILD=1
            ;;
        --static)
            STATIC_BUILD=1
            ;;
        --build-only)
            BUILD_ONLY=1
            ;;
        --install-only)
            INSTALL_ONLY=1
            ;;
        *)
            # If it's not an option, treat it as TARGET (like defconfig, menuconfig, etc.)
            if [[ "$1" != --* ]]; then
                TARGET="$1"
            fi
            ;;
    esac
    shift
done

# Default target if none provided
: "${TARGET:=defconfig}"

# Directories
BUSYBOX_SRC_DIR="${PROJECT_ROOT}/third_party/busybox"
: "${OUTPUT_DIR:=${PROJECT_ROOT}/out/busybox}"

# Create timestamped rootfs directory
setup_install_dir() {
    local datetime=$(date +%Y%m%d-%H%M%S)
    local new_rootfs_dir="${PROJECT_ROOT}/out/rootfs-${datetime}"
    local nfs_mount_point="${PROJECT_ROOT}/rootfs/nfs"

    # Check if INSTALL_DIR is already set (by release-all.sh for example)
    if [ -n "${INSTALL_DIR}" ]; then
        log_info "Using existing INSTALL_DIR: ${INSTALL_DIR}"
        mkdir -p "${INSTALL_DIR}"
        return 0
    fi

    # Create new rootfs directory
    mkdir -p "${new_rootfs_dir}"
    log_info "Created rootfs directory: ${new_rootfs_dir}"

    # Show NFS mount instructions (emphasized 3 times)
    log_info ""
    log_info "========================================"
    log_info "📌 NFS Mount Instructions"
    log_info "========================================"
    log_info ""
    log_info "If you want to access rootfs via NFS:"
    log_info ""
    log_info "  sudo mount --bind ${new_rootfs_dir} ${nfs_mount_point}"
    log_info ""
    log_info "========================================"
    log_info ""
    log_info "Or access directly at: ${new_rootfs_dir}"
    log_info ""

    export INSTALL_DIR="${new_rootfs_dir}"
}

: "${INSTALL_DIR:=${PROJECT_ROOT}/rootfs/nfs}"

# Get number of CPU cores for parallel build
NPROC=$(nproc)

# Check host dependencies
check_host_dependencies() {
    log_info "Checking host dependencies..."

    MISSING_PKGS=()
    FOUND_PKGS=()

    check_cmd() {
        local cmd=$1
        local pkg=$2
        if command -v ${cmd} &> /dev/null; then
            FOUND_PKGS+=("${pkg}")
            return 0
        else
            MISSING_PKGS+=("${pkg}")
            return 1
        fi
    }

    check_cmd gcc build-essential || true
    check_cmd make build-essential || true

    if dpkg -s libncurses-dev &> /dev/null || \
       [ -f /usr/include/ncursesw/ncurses.h ] || \
       [ -f /usr/include/ncurses/ncurses.h ]; then
        FOUND_PKGS+=("libncurses-dev")
    else
        MISSING_PKGS+=("libncurses-dev")
    fi

    FOUND_PKGS=($(echo "${FOUND_PKGS[@]}" | tr ' ' '\n' | sort -u))
    MISSING_PKGS=($(echo "${MISSING_PKGS[@]}" | tr ' ' '\n' | sort -u))

    for pkg in "${FOUND_PKGS[@]}"; do
        log_info "  ✓ ${pkg}"
    done

    for pkg in "${MISSING_PKGS[@]}"; do
        log_warn "  ✗ ${pkg} (not found)"
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${MISSING_PKGS[*]}"
        echo ""
        log_info "Install missing packages with:"
        echo -e "  ${YELLOW}sudo apt install ${MISSING_PKGS[*]}${NC}"
        echo ""
        exit 1
    fi

    log_info "All host dependencies found"
}

# Check if toolchain exists
check_toolchain() {
    log_info "Checking toolchain..."

    if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        log_error "Cross compiler '${CROSS_COMPILE}gcc' not found!"
        log_error "Please ensure the toolchain is installed and in your PATH"
        exit 1
    fi

    GCC_VERSION=$(${CROSS_COMPILE}gcc --version | head -n1)
    log_info "Toolchain found: ${GCC_VERSION}"

    for tool in objcopy objdump strip; do
        if ! command -v ${CROSS_COMPILE}${tool} &> /dev/null; then
            log_warn "Tool '${CROSS_COMPILE}${tool}' not found (may be needed)"
        fi
    done

    log_info "Toolchain verified"
}

# Check if BusyBox source exists
check_busybox_source() {
    log_info "Checking BusyBox source..."

    if [ ! -d "${BUSYBOX_SRC_DIR}" ]; then
        log_error "BusyBox source directory not found: ${BUSYBOX_SRC_DIR}"
        log_error "Please initialize the BusyBox submodule"
        exit 1
    fi

    if [ ! -f "${BUSYBOX_SRC_DIR}/Makefile" ]; then
        log_error "BusyBox Makefile not found: ${BUSYBOX_SRC_DIR}/Makefile"
        exit 1
    fi

    if [ -f "${BUSYBOX_SRC_DIR}/Makefile" ]; then
        VERSION=$(grep "^VERSION"      "${BUSYBOX_SRC_DIR}/Makefile" | head -n1 | sed 's/VERSION = //')
        PATCHLEVEL=$(grep "^PATCHLEVEL" "${BUSYBOX_SRC_DIR}/Makefile" | head -n1 | sed 's/PATCHLEVEL = //')
        SUBLEVEL=$(grep "^SUBLEVEL"    "${BUSYBOX_SRC_DIR}/Makefile" | head -n1 | sed 's/SUBLEVEL = //')
        log_info "BusyBox source: ${VERSION}.${PATCHLEVEL}.${SUBLEVEL}"
    fi

    log_info "BusyBox source verified"
}

# Clean build directory
do_distclean() {
    log_info "Cleaning build directory..."
    log_info "  Removing ${OUTPUT_DIR}"
    rm -rf "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"
    # Note: INSTALL_DIR will be setup by setup_install_dir() in main()
}

# Fix ARM-incompatible configs generated by defconfig
fix_arm_config() {
    log_info "Checking ARM-incompatible config items..."
    local cfg="${OUTPUT_DIR}/.config"
    local patched=0

    if grep -q "^CONFIG_SHA1_HWACCEL=y" "${cfg}"; then
        sed -i 's/^CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' "${cfg}"
        log_warn "  Disabled CONFIG_SHA1_HWACCEL (x86-only, not supported on ARM)"
        patched=1
    fi

    if grep -q "^CONFIG_SHA256_HWACCEL=y" "${cfg}"; then
        sed -i 's/^CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' "${cfg}"
        log_warn "  Disabled CONFIG_SHA256_HWACCEL (x86-only, not supported on ARM)"
        patched=1
    fi

    if [ ${patched} -eq 1 ]; then
        log_info "Running oldconfig to sync patched dependencies..."
        make -C "${BUSYBOX_SRC_DIR}" \
            ARCH=${ARCH} \
            CROSS_COMPILE=${CROSS_COMPILE} \
            O="${OUTPUT_DIR}" \
            oldconfig </dev/null || {
            log_warn "  oldconfig failed, continuing anyway (config may need manual review)"
        }
    else
        log_info "  No ARM-incompatible items found, skipping patch"
    fi
}

# Configure BusyBox
do_configure() {
    log_info "Configuring BusyBox with ${TARGET}..."
    local cmd="make -C ${BUSYBOX_SRC_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} O=${OUTPUT_DIR} ${TARGET}"
    log_cmd "${cmd}"
    ${cmd}

    # menuconfig is interactive — exit after user finishes, do not proceed to build
    if [[ "${TARGET}" == "menuconfig" ]]; then
        echo ""
        log_info "========================================"
        log_info "menuconfig completed."
        log_info "Your configuration has been saved to:"
        log_info "  ${OUTPUT_DIR}/.config"
        log_info ""
        log_info "To build BusyBox with the new config, run:"
        log_info "  $0"
        log_info "  -- or manually --"
        log_info "  make -C third_party/busybox \\"
        log_info "      ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} \\"
        log_info "      O=\$(pwd)/out/busybox -j\$(nproc)"
        log_info "========================================"
        exit 0
    fi

    # Enable static build if requested
    if [ ${STATIC_BUILD} -eq 1 ]; then
        log_info "Enabling static binary build..."
        sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "${OUTPUT_DIR}/.config" || true
        sed -i 's/^CONFIG_STATIC=n/CONFIG_STATIC=y/'            "${OUTPUT_DIR}/.config" || true
    fi

    # Apply ARM-specific config fixes
    fix_arm_config
}

# Build BusyBox
do_build() {
    log_info "Building BusyBox (${NPROC} parallel jobs)..."
    local cmd="make -C ${BUSYBOX_SRC_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} O=${OUTPUT_DIR} -j${NPROC}"
    log_cmd "${cmd}"
    ${cmd}
}

# Install BusyBox
do_install() {
    log_info "Installing BusyBox to ${INSTALL_DIR}..."
    # Handle symlinks - only create if path doesn't exist
    if [ ! -e "${INSTALL_DIR}" ]; then
        mkdir -p "${INSTALL_DIR}"
    fi
    local cmd="make -C ${BUSYBOX_SRC_DIR} ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} O=${OUTPUT_DIR} install CONFIG_PREFIX=${INSTALL_DIR}"
    log_cmd "${cmd}"
    ${cmd}
}

# Verify build artifacts
verify_build_artifacts() {
    log_info "Verifying build artifacts..."

    local has_error=0

    if [ -f "${OUTPUT_DIR}/busybox" ]; then
        FILE_INFO=$(file "${OUTPUT_DIR}/busybox")
        log_info "  ✓ ${OUTPUT_DIR}/busybox: ${FILE_INFO}"

        if [[ ! "${FILE_INFO}" == *"ARM"* ]]; then
            log_warn "    Binary may not be ARM architecture"
        fi

        SIZE=$(stat -c%s "${OUTPUT_DIR}/busybox" 2>/dev/null || stat -f%z "${OUTPUT_DIR}/busybox" 2>/dev/null)
        log_info "    Size: ${SIZE} bytes"
    else
        log_error "  ✗ ${OUTPUT_DIR}/busybox: not found"
        has_error=1
    fi

    if [ -f "${OUTPUT_DIR}/.config" ]; then
        log_info "  ✓ ${OUTPUT_DIR}/.config: present"
    else
        log_error "  ✗ ${OUTPUT_DIR}/.config: not found"
        has_error=1
    fi

    if [ -f "${INSTALL_DIR}/bin/busybox" ]; then
        log_info "  ✓ ${INSTALL_DIR}/bin/busybox: installed"
        if [ -d "${INSTALL_DIR}/bin" ]; then
            LINK_COUNT=$(find "${INSTALL_DIR}/bin" -type l | wc -l)
            log_info "    Symlinks in bin/: ${LINK_COUNT}"
        fi
    else
        log_warn "  ! ${INSTALL_DIR}/bin/busybox: not installed (may be expected if --no-install was used)"
    fi

    if [ ${has_error} -eq 0 ]; then
        log_info "Build artifacts verified successfully"
        return 0
    else
        log_error "Build artifact verification failed"
        return 1
    fi
}

# Display usage
show_usage() {
    cat << EOF
Usage: $0 [TARGET] [OPTIONS]

Targets (BusyBox make targets):
  defconfig      - Default configuration (default)
  menuconfig     - Interactive curses-based configurator (exits after config, no build)
  config         - Text-based configurator (exits after config, no build)
  allnoconfig    - Disable all symbols (exits after config, no build)
  allyesconfig   - Enable all symbols (exits after config, no build)

Options:
  --clean        - Clean build directory before building
  --static       - Build static binary
  --build-only    - Build only, using existing .config
  --install-only  - Install only, using existing build

Examples:
  $0                          # Full flow: config (defconfig) + build + install
  $0 menuconfig                  # Interactive configuration only (exits after config)
  $0 --build-only                # Build only using existing .config
  $0 --install-only              # Install only using existing build
  $0 --clean                    # Clean and rebuild from scratch
  $0 defconfig --clean --static  # Clean build with static binary

EOF
}

# Main build process
main() {
    # Handle help first, before any logging
    if [ ${SHOW_HELP} -eq 1 ]; then
        show_usage
        exit 0
    fi

    log_info "Starting BusyBox build for ${ARCH}"
    log_info "Target: ${TARGET}"
    log_info "========================================"

    # Check for mutually exclusive options
    if [ ${BUILD_ONLY} -eq 1 ] && [ ${CLEAN_BUILD} -eq 1 ]; then
        log_error "Error: --build-only and --clean are mutually exclusive"
        log_error "Use --build-only to keep existing config, or --clean to start fresh"
        exit 1
    fi

    if [ ${INSTALL_ONLY} -eq 1 ] && [ ${CLEAN_BUILD} -eq 1 ]; then
        log_error "Error: --install-only and --clean are mutually exclusive"
        exit 1
    fi

    if [ ${BUILD_ONLY} -eq 1 ] && [ ${INSTALL_ONLY} -eq 1 ]; then
        log_error "Error: --build-only and --install-only are mutually exclusive"
        exit 1
    fi

    # Pre-flight checks
    check_host_dependencies
    check_toolchain
    check_busybox_source

    log_info "========================================"
    log_info "All checks passed"
    log_info "========================================"

    # Clean if requested
    if [ ${CLEAN_BUILD} -eq 1 ]; then
        do_distclean
    else
        mkdir -p "${OUTPUT_DIR}"
    fi

    # Setup install directory (create timestamped dir and update symlink)
    # Skip for config-only modes
    if [[ "${TARGET}" != "menuconfig" ]] && [[ "${TARGET}" != "config" ]] && \
       [[ "${TARGET}" != "allnoconfig" ]] && [[ "${TARGET}" != "allyesconfig" ]]; then
        setup_install_dir
    fi

    # === Mode: Config only (menuconfig, config, allnoconfig, allyesconfig) ===
    if [[ "${TARGET}" == "menuconfig" ]] || [[ "${TARGET}" == "config" ]] || \
       [[ "${TARGET}" == "allnoconfig" ]] || [[ "${TARGET}" == "allyesconfig" ]]; then
        do_configure
        exit 0
    fi

    # === Mode: Install only ===
    if [ ${INSTALL_ONLY} -eq 1 ]; then
        if [ ! -f "${OUTPUT_DIR}/busybox" ]; then
            log_error "Install-only mode requires existing busybox binary at: ${OUTPUT_DIR}/busybox"
            log_error "Please build first with '$0' or '$0 --build-only'"
            exit 1
        fi
        log_info "Install-only mode: installing existing build..."
        do_install
        log_info "Installation completed successfully!"
        exit 0
    fi

    # === Mode: Build only (use existing config) ===
    if [ ${BUILD_ONLY} -eq 1 ]; then
        if [ ! -f "${OUTPUT_DIR}/.config" ]; then
            log_error "Build-only mode requires existing .config at: ${OUTPUT_DIR}/.config"
            log_error "Please run '$0 defconfig' or '$0 menuconfig' first to create a config"
            exit 1
        fi
        log_info "Build-only mode: using existing .config (skipping configure step)"
        fix_arm_config
        do_build
        log_info "Build completed successfully (not installed, use --install-only to install)"
        exit 0
    fi

    # === Mode: Default (configure + build + install) ===
    do_configure
    do_build
    do_install

    log_info "========================================"
    verify_build_artifacts || exit 1

    log_info "========================================"
    log_info "Build completed successfully!"

    log_info "Output directory: ${OUTPUT_DIR}"
    [ -f "${OUTPUT_DIR}/busybox" ] && log_info "  ✓ busybox binary"
    [ -f "${OUTPUT_DIR}/.config" ] && log_info "  ✓ .config"

    log_info "Install directory: ${INSTALL_DIR}"
    [ -f "${INSTALL_DIR}/bin/busybox" ] && log_info "  ✓ bin/busybox and symlinks"

    log_info "========================================"
    log_info ""
    log_info "========================================"
    log_info "📌 To access via NFS mount point"
    log_info "========================================"
    log_info ""
    log_info "  sudo mount --bind ${INSTALL_DIR} ${PROJECT_ROOT}/rootfs/nfs"
    log_info ""
    log_info "========================================"
    log_info ""
}

main "$@"