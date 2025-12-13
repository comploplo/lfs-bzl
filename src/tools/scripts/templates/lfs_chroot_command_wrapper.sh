#!/bin/bash
set -euo pipefail

# In a build action, PWD is the execroot.
EXECROOT="$(pwd -P)"

# In `bazel run`, prefer the runfiles tree (it contains generated scripts too).
MAIN_RUNFILES=""
if [ -n "${RUNFILES_DIR:-}" ] && [ -d "${RUNFILES_DIR}/_main" ]; then
  MAIN_RUNFILES="${RUNFILES_DIR}/_main"
fi

if [ -n "$MAIN_RUNFILES" ]; then
  LFS_PATH="$(realpath "$MAIN_RUNFILES/{sysroot_dir}")"
  HELPER_PATH="$(realpath "$MAIN_RUNFILES/{helper_abs_path}")"
  SCRIPT_TO_EXEC_HOST_PATH="$(realpath "$MAIN_RUNFILES/{script_file_run_path}")"
else
  LFS_PATH="$(realpath "{sysroot_dir}")"
  HELPER_PATH="$(realpath "{helper_abs_path}")"
  SCRIPT_TO_EXEC_HOST_PATH="$(realpath "{script_file_build_path}")"
fi

LABEL_NAME="{label}"

echo "Running chroot command for $LABEL_NAME"
echo "EXECROOT: $EXECROOT"
if [ -n "$MAIN_RUNFILES" ]; then
  echo "MAIN_RUNFILES: $MAIN_RUNFILES"
fi
echo "LFS_PATH: $LFS_PATH"
echo "HELPER_PATH: $HELPER_PATH"
echo "SCRIPT_TO_EXEC_HOST_PATH: $SCRIPT_TO_EXEC_HOST_PATH"

cleanup() {
  if [ "${LFS_CHROOT_KEEP_MOUNTS:-0}" = "1" ]; then
    sudo "$HELPER_PATH" release-vfs "$LFS_PATH"
    return 0
  fi
  sudo "$HELPER_PATH" unmount-vfs "$LFS_PATH"
}
trap cleanup EXIT

# Acquire a mount lease for this action. The helper implements refcounted mounts,
# so parallel actions won't unmount underneath each other.
sudo "$HELPER_PATH" mount-vfs "$LFS_PATH"

# Execute the script inside chroot
# The helper script will copy SCRIPT_TO_EXEC_HOST_PATH to a temporary location inside the chroot
sudo "$HELPER_PATH" exec-chroot "$LFS_PATH" "$SCRIPT_TO_EXEC_HOST_PATH"

if [ -z "$MAIN_RUNFILES" ]; then
  # Mark success (build action only; output path is relative to the execroot).
  OUTPUT_PATH="$(realpath -m "{output_path}")"
  mkdir -p "$(dirname "$OUTPUT_PATH")"
  touch "$OUTPUT_PATH"
fi
echo "Successfully executed chroot command for $LABEL_NAME"
