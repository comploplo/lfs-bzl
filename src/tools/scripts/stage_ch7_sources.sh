#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$LFS/sources"

if [ "${LFS_PKG_SRCS_FILE+set}" != "set" ] || [ ! -f "$LFS_PKG_SRCS_FILE" ]; then
  echo "Error: LFS_PKG_SRCS_FILE is missing; expected lfs_package to provide src list file" >&2
  exit 1
fi

while IFS= read -r f; do
  [ -n "$f" ] || continue
  cp -v "$f" "$LFS/sources/"
done < "$LFS_PKG_SRCS_FILE"
