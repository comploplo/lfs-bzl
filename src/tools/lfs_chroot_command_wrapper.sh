#!/bin/bash
set -euo pipefail

# Get workspace root (we're running from execroot)
WORKSPACE_ROOT="$(pwd)"

LFS_PATH="$WORKSPACE_ROOT/{sysroot_dir}"
# Compute absolute path to helper script from workspace-relative path
HELPER_PATH="$(realpath "$WORKSPACE_ROOT/{helper_abs_path}")"
SCRIPT_TO_EXEC_HOST_PATH="{script_file_execpath}"
LABEL_NAME="{label}"

echo "Running chroot command for $LABEL_NAME"
echo "LFS_PATH: $LFS_PATH"
echo "HELPER_PATH: $HELPER_PATH"
echo "SCRIPT_TO_EXEC_HOST_PATH: $SCRIPT_TO_EXEC_HOST_PATH"

cleanup() {
  sudo "$HELPER_PATH" unmount-vfs "$LFS_PATH" || true
}
trap cleanup EXIT

# Ensure virtual filesystems are mounted if not already (idempotent)
sudo "$HELPER_PATH" mount-vfs "$LFS_PATH"

# Execute the script inside chroot
# The helper script will copy SCRIPT_TO_EXEC_HOST_PATH to a temporary location inside the chroot
sudo "$HELPER_PATH" exec-chroot "$LFS_PATH" "$SCRIPT_TO_EXEC_HOST_PATH"

# Mark success
touch "{output_path}"
echo "Successfully executed chroot command for $LABEL_NAME"
