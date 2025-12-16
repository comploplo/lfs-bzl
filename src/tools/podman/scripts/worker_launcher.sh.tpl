#!/bin/bash
set -euo pipefail

# Worker Launcher for LFS Podman Container
# This script launches the Podman container with the Bazel JSON worker.
# Template variables are substituted by Bazel genrule at build time.

# Bazel runs workers with env - which clears PATH
# Set it explicitly so we can find realpath, podman, etc.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

CONTAINER_TAR="{CONTAINER_TAR}"
SYSROOT_REL="{SYSROOT_REL}"

EXECROOT="${PWD}"
SYSROOT_PATH="$(realpath "$SYSROOT_REL")"

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

# Load container image if not present
if ! podman image exists lfs-builder:bookworm 2>/dev/null; then
  echo "[LAUNCHER] Loading container image..." >&2
  podman load < "$CONTAINER_TAR" >/dev/null
  echo "[LAUNCHER] Container image loaded" >&2
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
  --rm \
  --interactive \
  --privileged \
  --network=none \
  --security-opt label=disable \
  --volume "${SYSROOT_PATH}:/lfs:rw" \
  --volume "${EXECROOT}:/execroot:rw" \
  --volume "${EXTERNAL_DIR}:${EXTERNAL_DIR}:rw" \
  lfs-builder:bookworm \
  python3 /work/worker.py --external-dir "${EXTERNAL_DIR}"
