#!/bin/bash
# Runner script for chroot LFS package: {name}
# This script displays the build output from the log file

set -euo pipefail

if [ -n "${BUILD_WORKSPACE_DIRECTORY:-}" ]; then
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

if [ -z "${WORKSPACE_ROOT:-}" ]; then
    echo "Error: Could not find workspace root" >&2
    exit 1
fi

# Find the log file in bazel-bin
LOG_FILE="$WORKSPACE_ROOT/bazel-bin/{log_path}"

if [ ! -f "$LOG_FILE" ]; then
    echo "Error: Build log not found at $LOG_FILE" >&2
    echo "" >&2
    echo "Run 'bazel build {label}' first" >&2
    exit 1
fi

# Display the build output
echo "=== Build output for {label} ==="
echo ""
cat "$LOG_FILE"
