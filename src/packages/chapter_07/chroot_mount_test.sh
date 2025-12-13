#!/bin/bash
set -euo pipefail

log_info() {
    echo "[INFO CHROOT] $*"
}

log_error() {
    echo "[ERROR CHROOT] $*" >&2
    exit 1
}

log_info "Starting chroot mount behavior test."

log_info "1. Checking initial mounts inside chroot:"
mount -v || true # Use true to prevent failure if mount returns non-zero

# Try to create a dummy mount point and bind mount something
DUMMY_MOUNT_POINT="/mnt/test_chroot_mount"
log_info "2. Attempting to create and bind mount a dummy directory: $DUMMY_MOUNT_POINT"
mkdir -p "$DUMMY_MOUNT_POINT" || log_error "Failed to create dummy mount point"
mount --bind /tmp "$DUMMY_MOUNT_POINT" || log_error "Failed to bind mount /tmp"
log_info "Bind mount successful. New mounts:"
mount -v | grep "$DUMMY_MOUNT_POINT" || true

log_info "3. Unmounting dummy directory: $DUMMY_MOUNT_POINT"
umount "$DUMMY_MOUNT_POINT" || log_error "Failed to unmount dummy mount point"
rmdir "$DUMMY_MOUNT_POINT" || log_error "Failed to remove dummy mount point"
log_info "Unmount successful."

# Verify persistent LFS virtual mounts
log_info "4. Verifying persistence of standard LFS chroot mounts:"
REQUIRED_MOUNTS=("/proc" "/sys" "/dev" "/run" "/dev/pts")
for MNT in "${REQUIRED_MOUNTS[@]}"; do
    if ! mountpoint -q "$MNT"; then
        log_error "Required chroot mount $MNT is missing or unmounted!"
    else
        log_info "Mount $MNT is present."
    fi
done

# Special check for /dev/shm (could be symlink or mount)
if [ -h "/dev/shm" ]; then
    log_info "Mount /dev/shm is a symlink, as expected."
elif mountpoint -q "/dev/shm"; then
    log_info "Mount /dev/shm is a mountpoint, as expected."
else
    log_error "Mount /dev/shm is neither a symlink nor a mountpoint!"
fi

log_info "Chroot mount behavior test completed successfully."
