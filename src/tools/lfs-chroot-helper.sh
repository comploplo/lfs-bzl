#!/bin/bash
# LFS Chroot Helper Script
#
# Privileged operations for mounting virtual filesystems and executing
# commands in chroot environment. Designed to be called via sudo with
# minimal attack surface.
#
# Security Model:
# - Allowlist-based operations (only 4 supported subcommands)
# - Path validation (absolute paths, existence checks)
# - Idempotent mounts (safe to call multiple times)
# - No arbitrary command execution (scripts are read from files)
#
# Usage:
#   sudo lfs-chroot-helper.sh mount-vfs <sysroot>
#   sudo lfs-chroot-helper.sh unmount-vfs <sysroot>
#   sudo lfs-chroot-helper.sh exec-chroot <sysroot> <command_script>
#   sudo lfs-chroot-helper.sh check-mounts <sysroot>
#
# Sudoers Configuration (example):
#   # /etc/sudoers.d/lfs-bazel-chroot
#   <user> ALL=(root) NOPASSWD: /path/to/repo/src/tools/lfs-chroot-helper.sh

set -euo pipefail

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
readonly EXIT_MOUNT_FAILED=2
readonly EXIT_CHROOT_FAILED=3
readonly EXIT_VALIDATION_FAILED=4

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Usage information
usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <operation> <sysroot> [args...]

Operations:
  mount-vfs <sysroot>              Mount virtual kernel filesystems
  unmount-vfs <sysroot>            Unmount all virtual filesystems
  exec-chroot <sysroot> <script>   Execute script inside chroot
  check-mounts <sysroot>           Verify all mounts are active

Arguments:
  <sysroot>  Absolute path to LFS sysroot directory
  <script>   Absolute path to bash script to execute in chroot

Exit Codes:
  0 - Success
  1 - Invalid arguments
  2 - Mount/unmount operation failed
  3 - Chroot execution failed
  4 - Validation failed

Examples:
  $(basename "$0") mount-vfs /home/user/lfs-bzl/src/sysroot
  $(basename "$0") check-mounts /home/user/lfs-bzl/src/sysroot
  $(basename "$0") exec-chroot /home/user/lfs-bzl/src/sysroot /tmp/build-script.sh
  $(basename "$0") unmount-vfs /home/user/lfs-bzl/src/sysroot
EOF
    exit "$EXIT_INVALID_ARGS"
}

# Validate sysroot path
validate_sysroot() {
    local sysroot="$1"

    # Must be absolute path
    if [[ ! "$sysroot" =~ ^/ ]]; then
        log_error "Sysroot must be an absolute path: $sysroot"
        return "$EXIT_VALIDATION_FAILED"
    fi

    # Must exist and be a directory
    if [[ ! -d "$sysroot" ]]; then
        log_error "Sysroot directory does not exist: $sysroot"
        return "$EXIT_VALIDATION_FAILED"
    fi

    # Basic sanity check: should have usr directory (LFS structure)
    if [[ ! -d "$sysroot/usr" ]]; then
        log_warn "Sysroot does not contain /usr directory: $sysroot"
        log_warn "This may not be a valid LFS sysroot"
    fi

    return 0
}

# Check if a filesystem is mounted at a given path
is_mounted() {
    local path="$1"
    findmnt "$path" >/dev/null 2>&1
}

# Mount virtual kernel filesystems
mount_vfs() {
    local sysroot="$1"

    validate_sysroot "$sysroot" || return $?

    log_info "Mounting virtual kernel filesystems in $sysroot"

    # Create mount points if they don't exist
    mkdir -p "$sysroot"/{dev,proc,sys,run}

    # Use lock file to coordinate with parallel builds
    local lock_file="$sysroot/tmp/.lfs-mount-lock"
    mkdir -p "$sysroot/tmp"

    # Acquire exclusive lock (automatically released on script exit)
    exec 200>"$lock_file"
    if ! flock -x -w 10 200; then
        log_error "Failed to acquire mount lock (timeout after 10s)"
        return "$EXIT_MOUNT_FAILED"
    fi

    local mount_failed=0

    # Mount /dev (bind mount from host)
    if ! is_mounted "$sysroot/dev"; then
        log_info "Mounting $sysroot/dev"
        if ! mount -v --bind /dev "$sysroot/dev"; then
            log_error "Failed to mount $sysroot/dev"
            mount_failed=1
        fi
    else
        log_info "$sysroot/dev already mounted"
    fi

    # Mount /dev/pts (devpts for pseudo-terminals)
    mkdir -p "$sysroot/dev/pts"
    if ! is_mounted "$sysroot/dev/pts"; then
        log_info "Mounting $sysroot/dev/pts"
        if ! mount -v -t devpts devpts -o gid=5,mode=0620 "$sysroot/dev/pts"; then
            log_error "Failed to mount $sysroot/dev/pts"
            mount_failed=1
        fi
    else
        log_info "$sysroot/dev/pts already mounted"
    fi

    # Mount /proc (kernel process information)
    if ! is_mounted "$sysroot/proc"; then
        log_info "Mounting $sysroot/proc"
        if ! mount -v -t proc proc "$sysroot/proc"; then
            log_error "Failed to mount $sysroot/proc"
            mount_failed=1
        fi
    else
        log_info "$sysroot/proc already mounted"
    fi

    # Mount /sys (kernel sysfs interface)
    if ! is_mounted "$sysroot/sys"; then
        log_info "Mounting $sysroot/sys"
        if ! mount -v -t sysfs sysfs "$sysroot/sys"; then
            log_error "Failed to mount $sysroot/sys"
            mount_failed=1
        fi
    else
        log_info "$sysroot/sys already mounted"
    fi

    # Mount /run (tmpfs for runtime data)
    if ! is_mounted "$sysroot/run"; then
        log_info "Mounting $sysroot/run"
        if ! mount -v -t tmpfs tmpfs "$sysroot/run"; then
            log_error "Failed to mount $sysroot/run"
            mount_failed=1
        fi
    else
        log_info "$sysroot/run already mounted"
    fi

    # Handle /dev/shm (shared memory)
    if [[ -h "$sysroot/dev/shm" ]]; then
        log_info "$sysroot/dev/shm is a symbolic link (OK)"
    else
        mkdir -p "$sysroot/dev/shm"
        if ! is_mounted "$sysroot/dev/shm"; then
            log_info "Mounting $sysroot/dev/shm"
            if ! mount -v -t tmpfs -o nosuid,nodev tmpfs "$sysroot/dev/shm"; then
                log_error "Failed to mount $sysroot/dev/shm"
                mount_failed=1
            fi
        else
            log_info "$sysroot/dev/shm already mounted"
        fi
    fi

    # Lock released automatically when fd 200 closes

    if [[ $mount_failed -eq 1 ]]; then
        log_error "Some mounts failed"
        return "$EXIT_MOUNT_FAILED"
    fi

    log_info "All virtual filesystems mounted successfully"
    return "$EXIT_SUCCESS"
}

# Unmount virtual kernel filesystems
unmount_vfs() {
    local sysroot="$1"

    validate_sysroot "$sysroot" || return $?

    log_info "Unmounting virtual kernel filesystems from $sysroot"

    local unmount_failed=0

    # Unmount in reverse order (most nested first)
    for mount_point in dev/shm dev/pts run sys proc dev; do
        local full_path="$sysroot/$mount_point"

        # Skip if it's a symlink (e.g., dev/shm -> /run/shm)
        if [[ -h "$full_path" ]]; then
            continue
        fi

        if is_mounted "$full_path"; then
            log_info "Unmounting $full_path"

            # Try normal unmount first
            if ! umount -v "$full_path" 2>/dev/null; then
                # If busy, try lazy unmount as fallback
                log_warn "$full_path is busy, attempting lazy unmount"
                if ! umount -v -l "$full_path"; then
                    log_error "Failed to unmount $full_path"
                    unmount_failed=1
                fi
            fi
        else
            log_info "$full_path not mounted (skipping)"
        fi
    done

    if [[ $unmount_failed -eq 1 ]]; then
        log_error "Some unmounts failed"
        return "$EXIT_MOUNT_FAILED"
    fi

    log_info "All virtual filesystems unmounted successfully"
    return "$EXIT_SUCCESS"
}

# Check if all required mounts are active
check_mounts() {
    local sysroot="$1"

    validate_sysroot "$sysroot" || return $?

    log_info "Checking mount status in $sysroot"

    local all_mounted=0
    local required_mounts=("proc" "sys" "dev" "dev/pts" "run")

    for mount_point in "${required_mounts[@]}"; do
        local full_path="$sysroot/$mount_point"

        if is_mounted "$full_path"; then
            log_info "✓ $full_path is mounted"
        else
            log_error "✗ $full_path is NOT mounted"
            all_mounted=1
        fi
    done

    # Check dev/shm (may be symlink or mount)
    if [[ -h "$sysroot/dev/shm" ]]; then
        log_info "✓ $sysroot/dev/shm is a symbolic link"
    elif is_mounted "$sysroot/dev/shm"; then
        log_info "✓ $sysroot/dev/shm is mounted"
    else
        log_error "✗ $sysroot/dev/shm is neither mounted nor a symlink"
        all_mounted=1
    fi

    if [[ $all_mounted -eq 0 ]]; then
        log_info "All required mounts are active"
        return "$EXIT_SUCCESS"
    else
        log_error "Some required mounts are missing"
        return "$EXIT_VALIDATION_FAILED"
    fi
}

# Execute command inside chroot environment
exec_chroot() {
    local sysroot="$1"
    local command_script="$2"

    validate_sysroot "$sysroot" || return $?

    # Validate command script exists and is readable
    if [[ ! -f "$command_script" ]]; then
        log_error "Command script does not exist: $command_script"
        return "$EXIT_VALIDATION_FAILED"
    fi

    if [[ ! -r "$command_script" ]]; then
        log_error "Command script is not readable: $command_script"
        return "$EXIT_VALIDATION_FAILED"
    fi

    # Verify mounts before entering chroot
    if ! check_mounts "$sysroot" >/dev/null 2>&1; then
        log_error "Required mounts are not active, cannot enter chroot"
        log_error "Run 'mount-vfs $sysroot' first"
        return "$EXIT_VALIDATION_FAILED"
    fi

    log_info "Entering chroot environment: $sysroot"
    log_info "Executing script: $command_script"

    # Execute chroot with clean environment
    # Note: The command script should set its own environment variables
    # Create a temporary script path inside the chroot
    local chroot_script_name
    chroot_script_name=$(basename "$command_script")
    local chroot_tmp_script="/tmp/$chroot_script_name"

    # Copy the script from the host system to the chroot's /tmp
    # We use cp here, not rsync, as this is a simple file copy from host to chroot target.
    log_info "Copying '$command_script' to '$sysroot/$chroot_tmp_script'"
    if ! cp "$command_script" "$sysroot/$chroot_tmp_script"; then
        log_error "Failed to copy command script to chroot: $command_script"
        return "$EXIT_CHROOT_FAILED"
    fi

    # Set executable permissions on the copied script inside the chroot
    if ! chmod +x "$sysroot/$chroot_tmp_script"; then
        log_error "Failed to set executable permissions on $sysroot/$chroot_tmp_script"
        return "$EXIT_CHROOT_FAILED"
    fi

    if ! chroot "$sysroot" /bin/bash "$chroot_tmp_script"; then
        log_error "Chroot execution failed"
        return "$EXIT_CHROOT_FAILED"
    fi

    # Optional: Clean up the temporary script in chroot after execution
    rm -f "$sysroot/$chroot_tmp_script"

    log_info "Chroot execution completed successfully"
    return "$EXIT_SUCCESS"
}

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
        *)
            log_error "Unknown operation: $operation"
            usage
            ;;
    esac
}

# Run main function
main "$@"
