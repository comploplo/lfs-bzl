#!/bin/bash
# LFS Chroot Execution and File Staging
#
# Handles executing commands inside chroot and copying files into the sysroot.
#
# This file is sourced by lfs_chroot_helper.sh, not executed directly.

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/tools/scripts/lfs_chroot_lib.sh
source "$SCRIPT_DIR/lfs_chroot_lib.sh"
# shellcheck source=src/tools/scripts/lfs_chroot_mount.sh
source "$SCRIPT_DIR/lfs_chroot_mount.sh"

# Copy host files into a directory under the sysroot.
stage_files() {
    local sysroot="$1"
    local dest_rel="$2"
    shift 2

    validate_sysroot "$sysroot" || return $?

    if [[ -z "$dest_rel" ]]; then
        log_error "Destination must be provided"
        return "$EXIT_INVALID_ARGS"
    fi

    if [[ "$dest_rel" == /* ]]; then
        dest_rel="${dest_rel#/}"
    fi

    # Disallow path traversal in dest_rel.
    if [[ "$dest_rel" == *".."* ]]; then
        log_error "Invalid destination path: $dest_rel"
        return "$EXIT_VALIDATION_FAILED"
    fi

    if [[ $# -lt 1 ]]; then
        log_error "No source files provided"
        return "$EXIT_INVALID_ARGS"
    fi

    local dest_dir="$sysroot/$dest_rel"
    mkdir -p "$dest_dir"

    for src in "$@"; do
        if [[ ! "$src" =~ ^/ ]]; then
            log_error "Source path must be absolute: $src"
            return "$EXIT_VALIDATION_FAILED"
        fi
        if [[ ! -f "$src" ]]; then
            log_error "Source file does not exist: $src"
            return "$EXIT_VALIDATION_FAILED"
        fi

        local base
        base="$(basename "$src")"
        log_info "Staging $src -> $dest_dir/$base"
        install -m 0644 "$src" "$dest_dir/$base"
    done

    log_info "File staging completed successfully"
    return "$EXIT_SUCCESS"
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

    # Execute with a clean environment as recommended by the LFS book, and set
    # MAKEFLAGS/TESTSUITEFLAGS for parallel builds.
    local env_path="/usr/bin/env"
    if [[ ! -x "$sysroot$env_path" ]]; then
        env_path="/bin/env"
    fi

    local host_term="${TERM:-linux}"
    local nproc_count
    nproc_count="$(nproc 2>/dev/null || echo 1)"
    local makeflags="-j${nproc_count}"

    if ! chroot "$sysroot" "$env_path" -i \
        HOME=/root \
        TERM="$host_term" \
        PATH=/usr/bin:/usr/sbin:/bin:/sbin \
        MAKEFLAGS="$makeflags" \
        TESTSUITEFLAGS="$makeflags" \
        bash --login "$chroot_tmp_script"; then
        log_error "Chroot execution failed"
        return "$EXIT_CHROOT_FAILED"
    fi

    # Optional: Clean up the temporary script in chroot after execution
    rm -f "$sysroot/$chroot_tmp_script"

    log_info "Chroot execution completed successfully"
    return "$EXIT_SUCCESS"
}
