#!/bin/bash
#
# libc Installation Script for RootFS
#
# This script copies libc library files from the cross-compilation toolchain
# to the root filesystem.
#
# Environment variables:
#   ROOTFS_DIR  - Path to the root filesystem (provided by main script)
#   PROJECT_ROOT - Path to the project root (provided by main script)
#
# Usage:
#   This script is automatically executed by varified_rootfs_ok.sh
#   Or run manually: ROOTFS_DIR=rootfs/nfs ./install_libc.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[install_libc]${NC} $1"; }
log_error() { echo -e "${RED}[install_libc]${NC} $1" >&2; }
log_warn()  { echo -e "${YELLOW}[install_libc]${NC} $1"; }

# Cross-compiler prefix
CROSS_COMPILE=arm-none-linux-gnueabihf-

# Default rootfs directory (for standalone execution)
: "${ROOTFS_DIR:=../rootfs/nfs}"

log_info "Installing libc libraries to: ${ROOTFS_DIR}"

# Check if rootfs directory exists
if [[ ! -d "$ROOTFS_DIR" ]]; then
    log_error "Rootfs directory not found: ${ROOTFS_DIR}"
    exit 1
fi

# Try to find the toolchain library directory
TOOLCHAIN_LIB_DIRS=(
    "/usr/lib/${CROSS_COMPILE}gcc"
    "/usr/${CROSS_COMPILE}/lib"
    "/usr/arm-linux-gnueabihf/lib"
    "/usr/arm-none-linux-gnueabihf/lib"
    "/opt/${CROSS_COMPILE}/lib"
    "/usr/local/lib/${CROSS_COMPILE}"
)

TOOLCHAIN_LIB_DIR=""

for dir in "${TOOLCHAIN_LIB_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
        TOOLCHAIN_LIB_DIR="$dir"
        log_info "Found toolchain library directory: ${dir}"
        break
    fi
done

# If not found in standard locations, try to locate via gcc
if [[ -z "$TOOLCHAIN_LIB_DIR" ]]; then
    if command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        # Get the sysroot from gcc
        SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot 2>/dev/null || echo "")
        if [[ -n "$SYSROOT" && -d "$SYSROOT" ]]; then
            TOOLCHAIN_LIB_DIR="${SYSROOT}/lib"
            log_info "Found toolchain sysroot: ${SYSROOT}"
        fi
    fi
fi

# If still not found, ask user
if [[ -z "$TOOLCHAIN_LIB_DIR" ]]; then
    log_warn "Could not automatically locate toolchain library directory"
    log_warn "Please specify the path to your cross-compiler's library directory"
    log_warn ""
    log_warn "Common locations:"
    for dir in "${TOOLCHAIN_LIB_DIRS[@]}"; do
        log_warn "  - $dir"
    done
    log_warn ""
    log_warn "You can set TOOLCHAIN_LIB_DIR environment variable and run again"
    log_warn ""
    log_warn "For now, skipping libc installation (you can copy libraries manually)"
    exit 0
fi

# Create target directories
mkdir -p "${ROOTFS_DIR}/lib"
mkdir -p "${ROOTFS_DIR}/usr/lib"

log_info "Copying library files..."

# Copy .a and .so files to lib/
log_info "  Copying to lib/..."
if find "${TOOLCHAIN_LIB_DIR}" -maxdepth 1 \( -name "*.a" -o -name "*.a.*" -o -name "*.so" -o -name "*.so.*" \) -print0 2>/dev/null | xargs -0 -I {} cp -d {} "${ROOTFS_DIR}/lib/" 2>/dev/null; then
    LIB_COUNT=$(find "${ROOTFS_DIR}/lib" -maxdepth 1 -type f \( -name "*.a" -o -name "*.so*" \) 2>/dev/null | wc -l)
    log_info "    Copied ${LIB_COUNT} library files to lib/"
else
    log_warn "    No library files found or copy failed"
fi

# Also check for lib subdirectories like usr/lib within the toolchain
if [[ -d "${TOOLCHAIN_LIB_DIR}/../usr/lib" ]]; then
    USR_LIB_DIR="$(cd "${TOOLCHAIN_LIB_DIR}/../usr/lib" && pwd)"
    log_info "  Copying to usr/lib/..."
    if find "${USR_LIB_DIR}" -maxdepth 1 \( -name "*.a" -o -name "*.a.*" -o -name "*.so" -o -name "*.so.*" \) -print0 2>/dev/null | xargs -0 -I {} cp -d {} "${ROOTFS_DIR}/usr/lib/" 2>/dev/null; then
        USR_LIB_COUNT=$(find "${ROOTFS_DIR}/usr/lib" -maxdepth 1 -type f \( -name "*.a" -o -name "*.so*" \) 2>/dev/null | wc -l)
        log_info "    Copied ${USR_LIB_COUNT} library files to usr/lib/"
    fi
fi

# Show summary
LIB_SIZE=$(du -sh "${ROOTFS_DIR}/lib" 2>/dev/null | cut -f1)
USR_LIB_SIZE=$(du -sh "${ROOTFS_DIR}/usr/lib" 2>/dev/null | cut -f1)

log_info "Library installation complete!"
log_info "  /lib size:  ${LIB_SIZE:-N/A}"
log_info "  /usr/lib size: ${USR_LIB_SIZE:-N/A}"
