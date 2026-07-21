#!/bin/bash
# Runner script for LFS package: {name}
# This script executes the binary from sysroot

if [ -n "$BUILD_WORKSPACE_DIRECTORY" ]; then
    WORKSPACE_ROOT="$BUILD_WORKSPACE_DIRECTORY"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    CURRENT="$SCRIPT_DIR"
    while [ "$CURRENT" != "/" ]; do
        if [ -f "$CURRENT/WORKSPACE" ] || [ -f "$CURRENT/WORKSPACE.bazel" ]; then
            WORKSPACE_ROOT="$CURRENT"
            break
        fi
        CURRENT="$(dirname "$CURRENT")"
    done
fi

if [ -z "$WORKSPACE_ROOT" ]; then
    echo "Error: Could not find workspace root" >&2
    exit 1
fi

SYSROOT="$WORKSPACE_ROOT/sysroot"
BINARY="$SYSROOT/tools/bin/{binary}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY" >&2
    echo "Run 'bazel build {label}' first" >&2
    exit 1
fi

# The sysroot binaries are Linux ELF; on a macOS host they cannot exec
# directly — run them inside the worker container instead.
if [ "$(uname -s)" = "Darwin" ]; then
    exec podman run --rm -i \
        --security-opt label=disable \
        --volume "$SYSROOT:/lfs:rw" \
        lfs-builder:trixie "/lfs/tools/bin/{binary}" "$@"
fi

exec "$BINARY" "$@"
