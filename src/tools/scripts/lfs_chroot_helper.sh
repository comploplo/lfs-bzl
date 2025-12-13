#!/bin/bash
# LFS Chroot Helper Script
#
# Privileged operations for mounting virtual filesystems and executing
# commands in chroot environment. Designed to be called via sudo with
# minimal attack surface.
#
# Security Model:
# - Allowlist-based operations (only 6 supported subcommands)
# - Path validation (absolute paths, existence checks)
# - Idempotent mounts (safe to call multiple times)
# - No arbitrary command execution (scripts are read from files)
#
# Usage:
#   sudo lfs-chroot-helper.sh mount-vfs <sysroot>
#   sudo lfs-chroot-helper.sh release-vfs <sysroot>
#   sudo lfs-chroot-helper.sh unmount-vfs <sysroot>
#   sudo lfs-chroot-helper.sh exec-chroot <sysroot> <command_script>
#   sudo lfs-chroot-helper.sh check-mounts <sysroot>
#   sudo lfs-chroot-helper.sh stage-files <sysroot> <dest_rel> <src_file>...
#
# Sudoers Configuration (example):
#   # /etc/sudoers.d/lfs-bazel-chroot
#   <user> ALL=(root) NOPASSWD: /path/to/repo/src/tools/scripts/lfs_chroot_helper.sh

set -euo pipefail

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library modules
# shellcheck source=src/tools/scripts/lfs_chroot_lib.sh
source "$SCRIPT_DIR/lfs_chroot_lib.sh"
# shellcheck source=src/tools/scripts/lfs_chroot_mount.sh
source "$SCRIPT_DIR/lfs_chroot_mount.sh"
# shellcheck source=src/tools/scripts/lfs_chroot_exec.sh
source "$SCRIPT_DIR/lfs_chroot_exec.sh"

# Main entry point
main() {
    # Require root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (via sudo)"
        exit "$EXIT_INVALID_ARGS"
    fi

    # Require at least 2 arguments
    if [[ $# -lt 2 ]]; then
        log_error "Missing required arguments"
        usage
    fi

    local operation="$1"
    local sysroot="$2"

    # Dispatch to operation handler
    case "$operation" in
        mount-vfs)
            mount_vfs "$sysroot"
            ;;
        release-vfs)
            release_vfs "$sysroot"
            ;;
        unmount-vfs)
            unmount_vfs "$sysroot"
            ;;
        check-mounts)
            check_mounts "$sysroot"
            ;;
        exec-chroot)
            if [[ $# -lt 3 ]]; then
                log_error "exec-chroot requires <sysroot> and <command_script> arguments"
                usage
            fi
            local command_script="$3"
            exec_chroot "$sysroot" "$command_script"
            ;;
        stage-files)
            if [[ $# -lt 4 ]]; then
                log_error "stage-files requires <sysroot> <dest_rel> <src_file>..."
                usage
            fi
            local dest_rel="$3"
            stage_files "$sysroot" "$dest_rel" "${@:4}"
            ;;
        *)
            log_error "Unknown operation: $operation"
            usage
            ;;
    esac
}

# Run main function
main "$@"
