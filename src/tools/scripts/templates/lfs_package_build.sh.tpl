#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1054,SC1083,SC1009,SC1073,SC1056,SC1072

# LFS Package Build Script
# Package: {label}
# Mode: {mode}

EXECROOT="/execroot"

if [[ "{mode}" == "container" ]]; then
    export LFS="/lfs"
    export PATH="$LFS/tools/bin:$PATH"
elif [[ "{mode}" == "chroot" ]]; then
    export LFS="${LFS:-/}"
fi

export LC_ALL=POSIX
export LFS_TGT=x86_64-lfs-linux-gnu
# shellcheck disable=SC1083,SC1054
{toolchain_exports}
# shellcheck disable=SC1083,SC1054
{extra_env}

WORK_DIR="$(mktemp -d)"
chmod 755 "$WORK_DIR"
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

# shellcheck disable=SC1083,SC1054
{src_handling}

# shellcheck disable=SC1083,SC1054
{patch_handling}

WORKDIR="$(pwd)"

# shellcheck disable=SC1083,SC1054
{configure_block}

# shellcheck disable=SC1083,SC1054
{build_block}

# shellcheck disable=SC1083,SC1054
{install_block}

cd "$EXECROOT"
touch "{marker_path}"
echo "Successfully built {name}"
