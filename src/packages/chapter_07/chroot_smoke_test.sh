#!/bin/bash
# Host-side Bazel test that mounts the sysroot, runs a smoke script inside
# chroot, and then unmounts. Requires passwordless sudo for the helper.

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <chroot_script> <helper_path> <sysroot_path>" >&2
  exit 1
fi

CHROOT_SCRIPT="$1"
HELPER_PATH="$2"
SYSROOT_PATH="$3"

CHROOT_SCRIPT="$(realpath "$CHROOT_SCRIPT")"
HELPER_PATH="$(realpath "$HELPER_PATH")"
SYSROOT_PATH="$(realpath "$SYSROOT_PATH")"

if [[ ! -x "$HELPER_PATH" ]]; then
  echo "Helper not executable: $HELPER_PATH" >&2
  exit 1
fi

if [[ ! -d "$SYSROOT_PATH" ]]; then
  echo "Sysroot not found: $SYSROOT_PATH" >&2
  exit 1
fi

tmp_script="$(mktemp)"
trap 'rm -f "$tmp_script"' EXIT
cp "$CHROOT_SCRIPT" "$tmp_script"
chmod +x "$tmp_script"

mounted=0
cleanup() {
  if [[ $mounted -eq 1 ]]; then
    sudo "$HELPER_PATH" unmount-vfs "$SYSROOT_PATH" || true
  fi
}
trap cleanup EXIT

sudo "$HELPER_PATH" mount-vfs "$SYSROOT_PATH"
mounted=1

sudo "$HELPER_PATH" exec-chroot "$SYSROOT_PATH" "$tmp_script"
