#!/bin/bash
# Cleanup orphaned LFS worker containers
# Usage: ./cleanup_orphaned.sh [--force]

set -euo pipefail

FORCE="${1:-}"

echo "=== LFS Worker Container Cleanup ==="
echo ""

# Find orphaned lfs-builder containers
ORPHANS=$(podman ps -a --filter "ancestor=lfs-builder:bookworm" --format "{{.ID}} {{.Names}} {{.Status}}" 2>/dev/null || true)

if [ -z "$ORPHANS" ]; then
    echo "No orphaned LFS worker containers found."
    exit 0
fi

echo "Found orphaned containers:"
echo "$ORPHANS"
echo ""

if [ "$FORCE" != "--force" ]; then
    echo "Run with --force to remove these containers:"
    echo "  bazel run //tools/podman:cleanup_orphaned -- --force"
    echo ""
    echo "Or manually:"
    echo "  podman stop \$(podman ps -aq --filter ancestor=lfs-builder:bookworm)"
    echo "  podman rm \$(podman ps -aq --filter ancestor=lfs-builder:bookworm)"
    exit 0
fi

echo "Stopping and removing orphaned containers..."
podman ps -a --filter "ancestor=lfs-builder:bookworm" --format "{{.ID}}" | while read -r id; do
    if [ -n "$id" ]; then
        echo "  Removing container $id..."
        podman stop --time 5 "$id" 2>/dev/null || true
        podman rm -f "$id" 2>/dev/null || true
    fi
done

echo ""
echo "Cleanup complete."
