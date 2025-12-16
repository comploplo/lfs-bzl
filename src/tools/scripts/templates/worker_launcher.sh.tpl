#!/bin/bash
set -euo pipefail

# Worker Launcher for LFS Podman Container
# This script launches the Podman container with the Bazel JSON worker.
# Template variables are substituted by Bazel genrule at build time.

# Bazel runs workers with env - which clears PATH
# Set it explicitly so we can find realpath, podman, etc.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IMAGE_NAME="lfs-builder:bookworm"
SYSROOT_REL="{SYSROOT_REL}"

# Check if container image exists
if ! podman image exists "$IMAGE_NAME" 2>/dev/null; then
    echo "" >&2
    echo "=========================================================" >&2
    echo "ERROR: Container image '$IMAGE_NAME' not found" >&2
    echo "=========================================================" >&2
    echo "" >&2
    echo "The LFS worker container must be built before running chroot builds." >&2
    echo "" >&2
    echo "Build the container with:" >&2
    echo "  bazel run //tools/podman:container_image" >&2
    echo "" >&2
    echo "This only needs to be done once (or when updating the worker)." >&2
    echo "=========================================================" >&2
    exit 1
fi

EXECROOT="${PWD}"
SYSROOT_PATH="$(realpath "$SYSROOT_REL")"

# Generate unique container name for tracking and cleanup
CONTAINER_NAME="lfs-worker-$(date +%s)-$$"

# Cleanup function for abnormal termination
cleanup_container() {
    echo "[LAUNCHER] Cleaning up container $CONTAINER_NAME..." >&2
    podman stop --time 10 "$CONTAINER_NAME" 2>/dev/null || true
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

# Register cleanup on script exit (SIGTERM, SIGINT, EXIT)
trap cleanup_container EXIT TERM INT

# Bazel external repos are symlinked from execroot/external/ to a shared cache
# Mount the external directory so symlinks resolve correctly
# External dir structure: .../HASH/execroot/_main and .../HASH/external
# We need to handle two cases:
#   1. Running from actual execroot: /path/to/HASH/execroot/_main
#   2. Running from runfiles: /path/to/HASH/execroot/_main/bazel-out/.../runfiles/_main
# In both cases, find the "execroot" directory and go up one level to get HASH
if [[ "$EXECROOT" =~ (.*/execroot)/[^/]+ ]]; then
    # Extract the execroot parent directory
    EXECROOT_PARENT="${BASH_REMATCH[1]}"
    EXTERNAL_DIR="$(dirname "$EXECROOT_PARENT")/external"
else
    echo "[LAUNCHER] Error: Cannot determine execroot path from PWD=$PWD" >&2
    exit 1
fi

# Verify sysroot exists
if [ ! -d "$SYSROOT_PATH" ]; then
    echo "[LAUNCHER] Error: Sysroot not found at $SYSROOT_PATH" >&2
    exit 1
fi

# Launch worker container
# Mounts:
#   - /lfs:rw - Sysroot staging tree (read-write for builds)
#   - /execroot:rw - Build scripts and inputs (execroot)
#   - external:rw - External repos (mounted at same path so symlinks work)
# Options:
#   - --rm: Remove container when it exits
#   - --interactive: Keep stdin open for JSON worker protocol
#   - --network=none: Enforce offline builds (no network access)
#   - --security-opt label=disable: Disable SELinux labeling (reduces friction)

exec podman run \
  --name "$CONTAINER_NAME" \
  --rm \
  --interactive \
  --privileged \
  --network=none \
  --security-opt label=disable \
  --stop-timeout 30 \
  --volume "${SYSROOT_PATH}:/lfs:rw" \
  --volume "${EXECROOT}:/execroot:rw" \
  --volume "${EXTERNAL_DIR}:${EXTERNAL_DIR}:rw" \
  "$IMAGE_NAME" \
  python3 /work/worker.py --external-dir "${EXTERNAL_DIR}"
