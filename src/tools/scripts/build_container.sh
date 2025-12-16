#!/bin/bash
set -euo pipefail

# Build the LFS worker container image
# Usage:
#   bazel run //tools/podman:container_image        # Build the image
#   bazel run //tools/podman:container_image -- -i  # Build and run interactive shell

IMAGE_NAME="lfs-builder:bookworm"

# Use BUILD_WORKSPACE_DIRECTORY if set (bazel run), otherwise find from script
if [[ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]]; then
    PODMAN_DIR="$BUILD_WORKSPACE_DIRECTORY/tools/podman"
else
    # Direct execution - find relative to script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PODMAN_DIR="$(dirname "$SCRIPT_DIR")"
fi

echo "Building container image: $IMAGE_NAME"
echo "Using source directory: $PODMAN_DIR"
podman build -t "$IMAGE_NAME" -f "$PODMAN_DIR/Containerfile" "$PODMAN_DIR"

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
