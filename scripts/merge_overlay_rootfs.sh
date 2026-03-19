#!/bin/bash
#
# RootFS Overlay Merge Script
#
# Usage:
#   scripts/merge_overlay_rootfs.sh --rootfs-dir=rootfs/nfs
#   scripts/merge_overlay_rootfs.sh --rootfs-dir=rootfs/nfs --overlay-name=rootfs
#

set -e

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCRIPT_LIB_DIR="${SCRIPT_DIR}/lib"

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
CROSS_COMPILE=arm-none-linux-gnueabihf-
ROOTFS_DIR=""
OVERLAY_NAME=""
SHOW_HELP=0

# Required directories in rootfs (for validation)
REQUIRED_DIRS=("bin" "sbin" "usr")

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            SHOW_HELP=1
            ;;
        --rootfs-dir=*)
            ROOTFS_DIR="${1#*=}"
            ;;
        --rootfs-dir)
            shift
            ROOTFS_DIR="$1"
            ;;
        --overlay-name=*)
            OVERLAY_NAME="${1#*=}"
            ;;
        --overlay-name)
            shift
            OVERLAY_NAME="$1"
            ;;
        *)
            log_error "Unknown option: $1"
            SHOW_HELP=1
            ;;
    esac
    shift
done

# Default values
: "${ROOTFS_DIR:=${PROJECT_ROOT}/rootfs/nfs}"
: "${OVERLAY_NAME:=rootfs}"

OVERLAY_DIR="${PROJECT_ROOT}/rootfs/overlay/${OVERLAY_NAME}"

# Display usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --rootfs-dir=PATH    Path to target rootfs directory (default: rootfs/nfs)
  --overlay-name=NAME  Overlay directory name under rootfs/overlay/ (default: rootfs)
  --help, -h           Show this help message

Description:
  This script merges overlay files into a target root filesystem by:
  1. Checking that the target directory is safe (not / or pointing to /)
  2. Verifying the target is a valid rootfs (has bin, sbin, usr)
  3. Verifying the overlay directory exists and has content
  4. Merging overlay content into target (overlay files overwrite existing files)

Examples:
  $0                                    # Use default: overlay/rootfs -> rootfs/nfs
  $0 --rootfs-dir=rootfs/nfs            # Specify target rootfs
  $0 --rootfs-dir=rootfs/nfs --overlay-name=qt6  # Use overlay/qt6
  $0 --rootfs-dir=/tmp/myrootfs --overlay-name=rootfs

EOF
}

# Check if directory is safe (not / or pointing to /)
check_directory_safe() {
    local dir="$1"

    # Check if directory is exactly /
    if [[ "$dir" == "/" ]]; then
        log_error "Directory cannot be '/'"
        return 1
    fi

    # Resolve to absolute path
    local abs_dir
    abs_dir="$(cd "$dir" 2>/dev/null && pwd)" || {
        log_error "Cannot access directory: $dir"
        return 1
    }

    # Check if resolved path is /
    if [[ "$abs_dir" == "/" ]]; then
        log_error "Directory resolves to '/' (unsafe)"
        return 1
    fi

    log_debug "Directory safety check passed: $abs_dir"
    return 0
}

# Check if target is a valid rootfs (has required directories)
check_valid_rootfs() {
    local rootfs="$1"
    local missing=()
    local found=()

    for dir in "${REQUIRED_DIRS[@]}"; do
        if [[ -d "${rootfs}/${dir}" ]]; then
            found+=("$dir")
        else
            missing+=("$dir")
        fi
    done

    if [[ ${#found[@]} -gt 0 ]]; then
        log_debug "  Found required directories: ${found[*]}"
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Target does not appear to be a valid rootfs"
        log_error "Missing required directories: ${missing[*]}"
        log_error "Please ensure target has at least: bin, sbin, usr"
        return 1
    fi

    log_info "  ✓ Target is a valid rootfs directory"
    return 0
}

# Check if overlay directory exists and has content
check_overlay_exists() {
    local overlay="$1"

    if [[ ! -d "$overlay" ]]; then
        log_error "Overlay directory does not exist: $overlay"
        return 1
    fi

    # Check if overlay has any files/directories (excluding hidden)
    local has_content=0
    for item in "$overlay"/*; do
        if [[ -e "$item" ]]; then
            has_content=1
            break
        fi
    done

    if [[ $has_content -eq 0 ]]; then
        log_error "Overlay directory is empty: $overlay"
        return 1
    fi

    log_info "  ✓ Overlay directory exists with content"

    # List what will be merged
    log_info "  Overlay contents:"
    for item in "$overlay"/*; do
        if [[ -e "$item" ]]; then
            local name
            name="$(basename "$item")"
            log_info "    - $name"
        fi
    done

    return 0
}

# Merge overlay into target rootfs
merge_overlay() {
    local overlay="$1"
    local target="$2"

    log_info "Merging overlay into target..."

    local file_count=0
    local dir_count=0

    # Use cp -a to preserve all attributes, and --remove-destination to overwrite symlinks
    for item in "$overlay"/*; do
        if [[ -e "$item" ]]; then
            local name
            name="$(basename "$item")"
            local target_path="${target}/${name}"

            # If target exists and is a directory, copy contents (not the directory itself)
            # Otherwise copy the file/directory directly
            if [[ -d "$target_path" ]]; then
                log_cmd "cp -a --remove-destination \"$item/\"* \"$target_path/\""
                if cp -a --remove-destination "$item/"* "$target_path/"; then
                    ((dir_count++))
                    log_debug "    ✓ Merged (contents): $name/"
                else
                    log_error "    ✗ Failed to merge: $name"
                    return 1
                fi
            else
                log_cmd "cp -a --remove-destination \"$item\" \"$target_path\""
                if cp -a --remove-destination "$item" "$target_path"; then
                    if [[ -d "$item" ]]; then
                        ((dir_count++))
                    else
                        ((file_count++))
                    fi
                    log_debug "    ✓ Merged: $name"
                else
                    log_error "    ✗ Failed to merge: $name"
                    return 1
                fi
            fi
        fi
    done

    log_info "  ✓ Merge complete: $dir_count directories, $file_count files"
    return 0
}

# Main function
main() {
    # Handle help
    if [ ${SHOW_HELP} -eq 1 ]; then
        show_usage
        exit 0
    fi

    log_info "========================================"
    log_info "RootFS Overlay Merge"
    log_info "========================================"
    log_info "Overlay source: ${OVERLAY_DIR}"
    log_info "Target rootfs:  ${ROOTFS_DIR}"
    log_info ""

    # Step 1: Safety checks
    log_info "Step 1: Safety checks..."
    check_directory_safe "$ROOTFS_DIR" || exit 1
    log_info "  ✓ Target directory is safe"
    log_info ""

    # Step 2: Validate target rootfs
    log_info "Step 2: Validating target rootfs..."
    check_valid_rootfs "$ROOTFS_DIR" || exit 1
    log_info ""

    # Step 3: Check overlay exists
    log_info "Step 3: Checking overlay directory..."
    check_overlay_exists "$OVERLAY_DIR" || exit 1
    log_info ""

    # Step 4: Confirm action
    log_warn "This will OVERWRITE files in ${ROOTFS_DIR} with content from ${OVERLAY_DIR}"
    log_warn "Press Ctrl+C to cancel, or Enter to continue..."
    read -r

    # Step 5: Merge overlay
    log_info "Step 4: Merging overlay..."
    merge_overlay "$OVERLAY_DIR" "$ROOTFS_DIR" || exit 1
    log_info ""

    log_info "========================================"
    log_info "Overlay merge completed successfully!"
    log_info "========================================"
    log_info ""
    log_info "Merged ${OVERLAY_DIR} -> ${ROOTFS_DIR}"
}

main "$@"
