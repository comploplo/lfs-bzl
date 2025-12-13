#!/bin/bash
# LFS Chroot Mount Operations
#
# Handles mounting, unmounting, and checking virtual filesystems for chroot.
# Uses reference counting to support parallel builds.
#
# This file is sourced by lfs_chroot_helper.sh, not executed directly.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/tools/scripts/lfs_chroot_lib.sh
source "$SCRIPT_DIR/lfs_chroot_lib.sh"

# Helper function to mount a filesystem with error handling
# Args: mount_point, mount_cmd_array
# Returns: 1 if mount failed, 0 otherwise
try_mount() {
    local mount_point="$1"
    shift
    local mount_cmd=("$@")

    if ! is_mounted "$mount_point"; then
        log_info "Mounting $mount_point"
        if ! "${mount_cmd[@]}" "$mount_point"; then
            log_error "Failed to mount $mount_point"
            return 1
        fi
    else
        log_info "$mount_point already mounted"
    fi
    return 0
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

    local refcount_file="$sysroot/tmp/.lfs-mount-refcount"
    local mount_refcount=0
    if [[ -f "$refcount_file" ]]; then
        mount_refcount="$(cat "$refcount_file" 2>/dev/null || echo 0)"
        mount_refcount="${mount_refcount:-0}"
    fi

    local mount_failed=0

    # Mount /dev (bind mount from host)
    try_mount "$sysroot/dev" mount --bind /dev || mount_failed=1

    # Mount /dev/pts (devpts for pseudo-terminals)
    mkdir -p "$sysroot/dev/pts"
    try_mount "$sysroot/dev/pts" mount -t devpts -o gid=5,mode=0620 devpts || mount_failed=1

    # Mount /proc (kernel process information)
    try_mount "$sysroot/proc" mount -t proc proc || mount_failed=1

    # Mount /sys (kernel sysfs interface)
    try_mount "$sysroot/sys" mount -t sysfs sysfs || mount_failed=1

    # Mount /run (tmpfs for runtime data)
    try_mount "$sysroot/run" mount -t tmpfs tmpfs || mount_failed=1

    # Handle /dev/shm (shared memory)
    if [[ -h "$sysroot/dev/shm" ]]; then
        log_info "$sysroot/dev/shm is a symbolic link (OK)"
    else
        mkdir -p "$sysroot/dev/shm"
        try_mount "$sysroot/dev/shm" mount -t tmpfs -o nosuid,nodev tmpfs || mount_failed=1
    fi

    if [[ $mount_failed -eq 1 ]]; then
        log_error "Some mounts failed"
        return "$EXIT_MOUNT_FAILED"
    fi

    mount_refcount=$((mount_refcount + 1))
    echo "$mount_refcount" >"$refcount_file"
    log_info "Mount lease acquired (refcount=$mount_refcount)"

    # Lock released automatically when fd 200 closes

    log_info "All virtual filesystems mounted successfully"
    return "$EXIT_SUCCESS"
}

# Unmount virtual kernel filesystems
unmount_vfs() {
    local sysroot="$1"

    validate_sysroot "$sysroot" || return $?

    log_info "Unmounting virtual kernel filesystems from $sysroot"

    # Use lock file to coordinate with parallel builds
    local lock_file="$sysroot/tmp/.lfs-mount-lock"
    mkdir -p "$sysroot/tmp"

    # Acquire exclusive lock while adjusting refcount / unmounting.
    exec 200>"$lock_file"
    if ! flock -x -w 10 200; then
        log_error "Failed to acquire mount lock (timeout after 10s)"
        return "$EXIT_MOUNT_FAILED"
    fi

    local refcount_file="$sysroot/tmp/.lfs-mount-refcount"
    local mount_refcount=0
    if [[ -f "$refcount_file" ]]; then
        mount_refcount="$(cat "$refcount_file" 2>/dev/null || echo 0)"
        mount_refcount="${mount_refcount:-0}"
    fi

    if [[ "$mount_refcount" -gt 1 ]]; then
        mount_refcount=$((mount_refcount - 1))
        echo "$mount_refcount" >"$refcount_file"
        log_info "Mount lease released (refcount=$mount_refcount); skipping unmount"
        return "$EXIT_SUCCESS"
    fi

    # Last (or unknown) lease: proceed with unmount.
    rm -f "$refcount_file" || true

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
            if ! umount "$full_path" 2>/dev/null; then
                # If busy, try lazy unmount as fallback
                log_warn "$full_path is busy, attempting lazy unmount"
                if ! umount -l "$full_path"; then
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

# Release a mount lease without unmounting (for keep-mounts workflows).
release_vfs() {
    local sysroot="$1"

    validate_sysroot "$sysroot" || return $?

    local lock_file="$sysroot/tmp/.lfs-mount-lock"
    mkdir -p "$sysroot/tmp"

    exec 200>"$lock_file"
    if ! flock -x -w 10 200; then
        log_error "Failed to acquire mount lock (timeout after 10s)"
        return "$EXIT_MOUNT_FAILED"
    fi

    local refcount_file="$sysroot/tmp/.lfs-mount-refcount"
    if [[ ! -f "$refcount_file" ]]; then
        return "$EXIT_SUCCESS"
    fi

    local mount_refcount
    mount_refcount="$(cat "$refcount_file" 2>/dev/null || echo 0)"
    mount_refcount="${mount_refcount:-0}"

    if [[ "$mount_refcount" -gt 1 ]]; then
        mount_refcount=$((mount_refcount - 1))
        echo "$mount_refcount" >"$refcount_file"
        log_info "Mount lease released (refcount=$mount_refcount)"
        return "$EXIT_SUCCESS"
    fi

    rm -f "$refcount_file" || true
    log_info "Mount lease released (refcount=0); mounts kept"
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
