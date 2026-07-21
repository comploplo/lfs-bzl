#!/bin/bash
set -euo pipefail

# Build the LFS worker container image
# Usage:
#   bazel run //tools/podman:container_image        # Build the image
#   bazel run //tools/podman:container_image -- -i  # Build and run interactive shell

IMAGE_NAME="lfs-builder:trixie"
PLATFORM="${LFS_PLATFORM:-linux/arm64}"

# Use BUILD_WORKSPACE_DIRECTORY if set (bazel run), otherwise find from script
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    PODMAN_DIR="$BUILD_WORKSPACE_DIRECTORY/tools/podman"
else
    # Direct execution - find relative to script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PODMAN_DIR="$(dirname "$SCRIPT_DIR")/podman"
fi

echo "Building container image: $IMAGE_NAME"
echo "Using source directory: $PODMAN_DIR"
echo "Target platform: $PLATFORM"
# LFS's supported path for non-x86 targets expects the host Linux system to
# target that architecture. On Apple Silicon, linux/arm64 keeps the container
# native and makes LFS_TGT resolve to aarch64-lfs-linux-gnu.
podman build --platform "$PLATFORM" -t "$IMAGE_NAME" -f "$PODMAN_DIR/Containerfile" "$PODMAN_DIR"

echo ""
echo "Container image built successfully: $IMAGE_NAME"
echo ""

# If -i flag passed, launch interactive shell in container
if [[ "${1:-}" == "-i" ]]; then
    echo "Launching interactive shell..."
    exec podman run --rm -it "$IMAGE_NAME" /bin/bash
fi

echo "To test the image interactively:"
echo "  bazel run //tools/podman:container_image -- -i"
echo ""
echo "The worker_launcher will now use this image for chroot builds."
