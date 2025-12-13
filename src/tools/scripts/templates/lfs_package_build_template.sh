#!/bin/bash
set -euo pipefail
# shellcheck disable=SC1054,SC1083,SC1009,SC1073,SC1056,SC1072
# This is a template file with placeholders like {toolchain_exports} that get
# replaced by the build system. Shellcheck should not analyze the raw template.

# LFS Package Build Script
# Package: {label}

EXECROOT="$(pwd)"

# Keep logs inside bazel-out (standard Bazel output tree)
LOG_DIR="$EXECROOT/bazel-out/lfs-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/{name}.log"
exec > >(tee "$LOG_FILE") 2>&1

# LFS Environment
# Use BUILD_WORKSPACE_DIRECTORY if available (bazel run)
# Otherwise, actions run with PWD set to the execroot workspace root.
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    WORKSPACE_ROOT="$BUILD_WORKSPACE_DIRECTORY"
else
    WORKSPACE_ROOT="$EXECROOT"
fi
export LFS="$WORKSPACE_ROOT/{sysroot_path}"
export LC_ALL=POSIX
export LFS_TGT=x86_64-lfs-linux-gnu
export PATH="$LFS/tools/bin:$PATH"
{toolchain_exports}
{extra_env}

# Function: Check sysroot ownership and provide recovery guidance
check_sysroot_ownership() {
    # Skip if running as root (can write to root-owned files)
    if [[ $EUID -eq 0 ]]; then
        return 0
    fi

    # Skip if sysroot doesn't exist yet (first build)
    if [[ ! -d "$LFS" ]]; then
        return 0
    fi

    # Check ownership of critical directories: usr, tools, lib
    local problem_detected=0
    local problem_dirs=()

    for dir in usr tools lib; do
        local full_path="$LFS/$dir"
        if [[ -d "$full_path" ]]; then
            # Get owner UID (portable: try Linux stat first, then BSD stat)
            local owner_uid
            owner_uid=$(stat -c '%u' "$full_path" 2>/dev/null || \
                       stat -f '%u' "$full_path" 2>/dev/null || echo "")

            if [[ "$owner_uid" == "0" ]]; then
                problem_detected=1
                problem_dirs+=("$full_path")
            fi
        fi
    done

    # Display error and exit if problem detected
    if [[ $problem_detected -eq 1 ]]; then
        # Get current user (USER may not be set in Bazel environment)
        local current_user="${USER:-$(whoami)}"

        cat >&2 <<EOF

================================================================================
ERROR: Sysroot Ownership Problem Detected
================================================================================

The sysroot directory has been changed to root ownership, likely by running
the Chapter 7 'chroot_chown_root' step. This prevents regular user builds
from writing to the sysroot.

This is expected behavior! Chapter 7 changes ownership as part of preparing
the chroot environment. However, this means you cannot re-run Chapter 5-6
builds without restoring user ownership first.

DETECTED ISSUE:
  Sysroot: $LFS
  Problem directories: ${problem_dirs[@]}
  Current owner: root:root
  Required owner: $current_user:$current_user (for Chapter 5-6 builds)

RECOVERY:
  Run this command to restore user ownership:

    sudo chown -R $current_user:$current_user "$LFS"

  After restoring ownership, you can re-run Chapter 5-6 builds normally.

IMPORTANT NOTES:
  - This will UNDO the Chapter 7 ownership changes
  - If you need to run Chapter 7+ builds after recovery, you'll need to
    run 'chroot_chown_root' again
  - Consider the build lifecycle: Ch5 → Ch6 → Ch7 → Ch8+
  - Going backwards (Ch7 → Ch5) requires ownership restoration

For more information, see:
  - docs/troubleshooting.md (Sysroot Ownership Recovery section)
  - docs/chroot.md (Chapter 7: Ownership Lifecycle)

BUILD FAILED: Cannot write to root-owned sysroot
================================================================================

EOF
        exit 1
    fi
}

# Invoke ownership check before any file operations
check_sysroot_ownership

# Working directory
WORK_DIR="$(mktemp -d)"
trap "rm -rf $WORK_DIR" EXIT
cd "$WORK_DIR"

{src_handling}

{patch_handling}

{configure_block}

{build_block}

{install_block}

# Mark success
cd "$EXECROOT"
touch "{marker_path}"
echo "Successfully built {name}"
