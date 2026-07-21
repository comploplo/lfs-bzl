#!/bin/bash
set -euo pipefail

# Worker Launcher for LFS Podman Container
# This script launches the Podman container with the Bazel JSON worker.
# Template variables are substituted by Bazel genrule at build time.

# Bazel runs workers with a cleared env. Restore PATH so realpath, podman, etc.
# are findable -- including /opt/homebrew/bin where podman lives on Apple Silicon
# (harmless extra entry on Linux). Restore HOME so podman can locate its machine
# connection config for `podman run`.
export PATH="/opt/homebrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export HOME="${HOME:-$(cd ~ && pwd)}"

IMAGE_NAME="lfs-builder:trixie"
# Bazel clears the worker env, so an LFS_PLATFORM override can never reach
# this script; derive the platform from the host arch instead (native build).
case "$(uname -m)" in
  arm64|aarch64) PLATFORM="linux/arm64" ;;
  x86_64)        PLATFORM="linux/amd64" ;;
  *) echo "[LAUNCHER] Unsupported host arch: $(uname -m)" >&2; exit 1 ;;
esac
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
    podman stop --time 5 "$CONTAINER_NAME" 2>/dev/null || true
    podman rm -f "$CONTAINER_NAME" 2>/dev/null || true
}

# Register cleanup on script exit (SIGTERM, SIGINT, EXIT, HUP)
trap cleanup_container EXIT TERM INT HUP

# Clean up any stale containers from previous runs that weren't properly cleaned
# This handles cases where Bazel killed workers without proper cleanup
stale_containers=$(podman ps -a -q --filter "name=lfs-worker-" --filter "status=exited" 2>/dev/null || true)
if [ -n "$stale_containers" ]; then
    echo "[LAUNCHER] Cleaning up stale containers from previous runs..." >&2
    echo "$stale_containers" | xargs -r podman rm -f 2>/dev/null || true
fi

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

# Bazel materializes external repos as symlinks into the repository cache
# (see .bazelrc --repository_cache). The source tarballs therefore live under
# the repo cache, not under external/. Mount it at its real path so those
# symlinks resolve inside the container. Keep this path in sync with .bazelrc.
REPO_CACHE="$HOME/.cache/bazel/_bazel_repo_cache"

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

# Run podman as a child process (not exec) so trap handlers can fire
# when Bazel terminates the worker
podman run \
  --platform "$PLATFORM" \
  --name "$CONTAINER_NAME" \
  --rm \
  --interactive \
  --cap-add SYS_ADMIN \
  --cap-add SYS_CHROOT \
  --cap-add CHOWN \
  --cap-add DAC_OVERRIDE \
  --cap-add FOWNER \
  --cap-add MKNOD \
  --network=none \
  --security-opt label=disable \
  --stop-timeout 30 \
  --volume "${SYSROOT_PATH}:/lfs:rw" \
  --volume "${EXECROOT}:/execroot:rw" \
  --volume "${EXTERNAL_DIR}:${EXTERNAL_DIR}:rw" \
  --volume "${REPO_CACHE}:${REPO_CACHE}:ro" \
  "$IMAGE_NAME" \
  python3 /work/worker.py --external-dir "${EXTERNAL_DIR}"

# Capture exit code and exit (trap will run on EXIT)
exit $?
