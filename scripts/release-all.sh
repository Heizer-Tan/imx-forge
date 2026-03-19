#!/bin/bash
#
# build-all.sh - Unified build script for mini Linux distribution
#
# Usage:
#   ./scripts/build-all.sh [OPTIONS]
#
# Options:
#   --fast-build    - Pass --fast-build to linux build (skip distclean)
#   --stage N       - Run only specific stage (1-4)
#   --help, -h      - Show this help message
#
# Stages:
#   1 - U-Boot bootloader
#   2 - Linux kernel
#   3 - BusyBox userland
#   4 - RootFS completion (third-party dependencies)
#
# Output directory: out/release-latest/
#

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

# Source shared logging
if [[ -f "${SCRIPT_LIB_DIR}/logging.sh" ]]; then
    source "${SCRIPT_LIB_DIR}/logging.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
    log_info() { echo -e "${GREEN}[build-all]${NC} $1"; }
    log_error() { echo -e "${RED}[build-all]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[build-all]${NC} $1"; }
fi

# Configuration
BUILD_OUTPUT_DIR="${PROJECT_ROOT}/out/release-latest"
CROSS_COMPILE=arm-none-linux-gnueabihf-

# Build options
FAST_BUILD=0
SPECIFIC_STAGE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fast-build)
            FAST_BUILD=1
            shift
            ;;
        --stage)
            SPECIFIC_STAGE="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --fast-build      Pass --fast-build to linux build (skip distclean)
  --stage N         Run only specific stage (1-4)
  --help, -h        Show this help message

Stages:
  1  U-Boot bootloader
  2  Linux kernel
  3  BusyBox userland
  4  RootFS completion with third-party dependencies

Examples:
  $0                          # Build all stages
  $0 --stage 1                # Build U-Boot only
  $0 --fast-build             # Build all with fast build mode
  $0 --stage 2 --fast-build   # Build Linux with fast build mode

Output directory: ${BUILD_OUTPUT_DIR}/
EOF
}

# Stage 1: U-Boot
stage_1_uboot() {
    log_info "========================================="
    log_info "Stage 1/4: Building U-Boot"
    log_info "========================================="

    export OUTPUT_DIR="${BUILD_OUTPUT_DIR}/uboot"

    log_info "Output directory: ${OUTPUT_DIR}"
    echo ""

    bash "${SCRIPT_DIR}/release_builder/build_release_uboot.sh"

    # Verify key artifacts
    if [[ -f "${OUTPUT_DIR}/u-boot-dtb.imx" ]]; then
        log_info "U-Boot build successful"
    else
        log_error "U-Boot build failed - u-boot-dtb.imx not found"
        exit 1
    fi
}

# Stage 2: Linux
stage_2_linux() {
    log_info "========================================="
    log_info "Stage 2/4: Building Linux Kernel"
    log_info "========================================="

    export OUTPUT_DIR="${BUILD_OUTPUT_DIR}/linux"

    log_info "Output directory: ${OUTPUT_DIR}"

    if [[ ${FAST_BUILD} -eq 1 ]]; then
        log_info "Fast build mode enabled"
        echo ""
        bash "${SCRIPT_DIR}/release_builder/build_release_linux.sh" --fast-build
    else
        echo ""
        bash "${SCRIPT_DIR}/release_builder/build_release_linux.sh"
    fi

    # Verify key artifacts
    if [[ -f "${OUTPUT_DIR}/arch/arm/boot/zImage" ]]; then
        log_info "Linux build successful"
    else
        log_error "Linux build failed - zImage not found"
        exit 1
    fi
}

# Stage 3: BusyBox
stage_3_busybox() {
    log_info "========================================="
    log_info "Stage 3/4: Building BusyBox"
    log_info "========================================="

    export OUTPUT_DIR="${BUILD_OUTPUT_DIR}/busybox"
    export INSTALL_DIR="${BUILD_OUTPUT_DIR}/rootfs"

    log_info "Output directory: ${OUTPUT_DIR}"
    log_info "Install directory: ${INSTALL_DIR}"
    echo ""

    bash "${SCRIPT_DIR}/release_builder/build_release_busybox.sh"
    
    # Verify key artifacts
    if [[ -f "${OUTPUT_DIR}/busybox" ]]; then
        log_info "BusyBox build successful"
    else
        log_error "BusyBox build failed - busybox binary not found"
        exit 1
    fi

    if [[ -f "${INSTALL_DIR}/bin/busybox" ]]; then
        log_info "BusyBox installed to rootfs"
    else
        log_warn "BusyBox installation may have issues"
    fi
}

# Stage 4: RootFS completion
stage_4_rootfs() {
    log_info "========================================="
    log_info "Stage 4/4: Completing RootFS"
    log_info "========================================="

    export ROOTFS_DIR="${BUILD_OUTPUT_DIR}/rootfs"
    mkdir -p "$ROOTFS_DIR"
    log_info "RootFS directory: ${ROOTFS_DIR}"
    echo ""
    log_info "Running Command: ${SCRIPT_DIR}/varified_rootfs_ok.sh --rootfs-dir=${ROOTFS_DIR}"
    bash "${SCRIPT_DIR}/varified_rootfs_ok.sh" --rootfs-dir="${ROOTFS_DIR}"

    echo ""
    log_info "Merging Rootfs Overlay from rootfs/overlay/rootfs to ${ROOTFS_DIR}"
    bash "${SCRIPT_DIR}/merge_overlay_rootfs.sh" --rootfs-dir="${ROOTFS_DIR}" --overlay-name=rootfs

    log_info "RootFS completion successful"
}

# Create convenience symlinks
create_symlinks() {
    log_info "========================================="
    log_info "Creating convenience symlinks"
    log_info "========================================="

    local images_dir="${BUILD_OUTPUT_DIR}/images"
    mkdir -p "${images_dir}"

    # U-Boot images
    if [[ -f "${BUILD_OUTPUT_DIR}/uboot/u-boot-dtb.imx" ]]; then
        ln -sf "../uboot/u-boot-dtb.imx" "${images_dir}/"
        log_info "  + images/u-boot-dtb.imx"
    fi

    # Linux images
    if [[ -f "${BUILD_OUTPUT_DIR}/linux/arch/arm/boot/zImage" ]]; then
        mkdir -p "${images_dir}"
        ln -sf "../linux/arch/arm/boot/zImage" "${images_dir}/"
        log_info "  + images/zImage"
    fi

    # Device trees (if available)
    if [[ -f "${BUILD_OUTPUT_DIR}/linux/arch/arm/boot/dts/imx6ull-14x14-evk-emmc.dtb" ]]; then
        ln -sf "../linux/arch/arm/boot/dts/imx6ull-14x14-evk-emmc.dtb" "${images_dir}/"
        log_info "  + images/imx6ull-14x14-evk-emmc.dtb"
    fi

    log_info "Symlinks created in ${images_dir}/"

    # Export NFS rootfs for debugging
    log_info "Exporting NFS rootfs..."
    local nfs_dir="${PROJECT_ROOT}/rootfs/nfs"
    rm -rf "${nfs_dir}"
    mkdir -p "$(dirname "${nfs_dir}")"
    ln -sf "${BUILD_OUTPUT_DIR}/rootfs" "${nfs_dir}"
    log_info "  + rootfs/nfs/ -> ${BUILD_OUTPUT_DIR}/rootfs/ (NFS export ready)"
}

# Show final summary
show_summary() {
    log_info "========================================="
    log_info "Build Summary"
    log_info "========================================="
    log_info ""
    log_info "Build artifacts location: ${BUILD_OUTPUT_DIR}/"
    log_info ""
    log_info "Directory structure:"
    log_info "  uboot/        - U-Boot bootloader"
    log_info "  linux/        - Linux kernel"
    log_info "  busybox/      - BusyBox userland"
    log_info "  rootfs/       - Complete root filesystem"
    log_info "  images/       - Flashable images (symlinks)"
    log_info ""
    log_info "Flashable images:"
    local images_dir="${BUILD_OUTPUT_DIR}/images"
    if [[ -d "${images_dir}" ]]; then
        for f in "${images_dir}"/*; do
            if [[ -e "$f" ]]; then
                log_info "  - $(basename "$f")"
            fi
        done
    fi
    log_info ""
    log_info "To use the rootfs:"
    log_info "  1. Export via NFS: ${BUILD_OUTPUT_DIR}/rootfs"
    log_info "  2. Or copy to SD card"
    log_info ""
}

# Main build process
main() {
    log_info "========================================="
    log_info "Mini Distribution Build"
    log_info "========================================="
    log_info "Project root: ${PROJECT_ROOT}"
    log_info "Build output: ${BUILD_OUTPUT_DIR}"
    log_info "Cross compiler: ${CROSS_COMPILE}gcc"
    log_info "========================================="
    log_info ""

    # Determine which stages to run
    local stages=()
    if [[ -n "${SPECIFIC_STAGE}" ]]; then
        if [[ "${SPECIFIC_STAGE}" =~ ^[1-4]$ ]]; then
            stages=("${SPECIFIC_STAGE}")
            log_info "Running stage ${SPECIFIC_STAGE} only"
        else
            log_error "Invalid stage number: ${SPECIFIC_STAGE} (must be 1-4)"
            exit 1
        fi
    else
        stages=(1 2 3 4)
        log_info "Running all stages (1-4)"
    fi
    log_info ""

    # Create build output directory
    # If release-latest exists, rename it to release-{datetime}
    if [[ -d "${BUILD_OUTPUT_DIR}" ]]; then
        local datetime=$(date +%Y%m%d-%H%M%S)
        local archive_dir="${PROJECT_ROOT}/out/release-${datetime}"
        log_info "Archiving existing ${BUILD_OUTPUT_DIR} -> ${archive_dir}"
        mv "${BUILD_OUTPUT_DIR}" "${archive_dir}"
    fi
    mkdir -p "${BUILD_OUTPUT_DIR}"

    # Run stages
    for stage in "${stages[@]}"; do
        case "${stage}" in
            1) stage_1_uboot ;;
            2) stage_2_linux ;;
            3) stage_3_busybox ;;
            4) stage_4_rootfs ;;
        esac
        echo ""
    done

    # Create convenience symlinks
    create_symlinks
    echo ""

    # Show summary
    show_summary

    log_info "========================================="
    log_info "Build completed successfully!"
    log_info "========================================="
}

main "$@"
