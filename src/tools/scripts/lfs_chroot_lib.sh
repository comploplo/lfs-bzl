#!/bin/bash
# LFS Chroot Library - Shared Utilities
#
# Provides common functions, constants, and validation logic used by all
# chroot helper modules.
#
# This file is sourced by other chroot scripts, not executed directly.

# Guard against multiple sourcing
if [[ -n "${LFS_CHROOT_LIB_LOADED:-}" ]]; then
    return 0
fi
readonly LFS_CHROOT_LIB_LOADED=1

# Exit codes
# shellcheck disable=SC2034  # Used by scripts that source this library
readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_ARGS=1
# shellcheck disable=SC2034  # Used by scripts that source this library
readonly EXIT_MOUNT_FAILED=2
# shellcheck disable=SC2034  # Used by scripts that source this library
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
  release-vfs <sysroot>            Release a mount lease (no unmount)
  unmount-vfs <sysroot>            Unmount all virtual filesystems
  exec-chroot <sysroot> <script>   Execute script inside chroot
  check-mounts <sysroot>           Verify all mounts are active
  stage-files <sysroot> <dest_rel> <src_file>...
                                   Copy host files into sysroot/<dest_rel>

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
  $(basename "$0") release-vfs /home/user/lfs-bzl/src/sysroot
  $(basename "$0") check-mounts /home/user/lfs-bzl/src/sysroot
  $(basename "$0") exec-chroot /home/user/lfs-bzl/src/sysroot /tmp/build-script.sh
  $(basename "$0") unmount-vfs /home/user/lfs-bzl/src/sysroot
  $(basename "$0") stage-files /home/user/lfs-bzl/src/sysroot sources /tmp/foo.tar.xz
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
