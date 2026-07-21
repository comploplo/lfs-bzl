#!/bin/bash
# Cleanup orphaned LFS worker containers
# Usage: ./cleanup_orphaned.sh [--force]

set -euo pipefail

FORCE="${1:-}"

echo "=== LFS Worker Container Cleanup ==="
echo ""

# Find orphaned lfs-worker containers. Filter by name (matching how the launcher
# names workers) and status=exited only — matching worker_launcher.sh.tpl's
# cleanup filter. status=created is deliberately NOT matched: a sibling
# launcher's just-created (not yet running) worker would be killed mid-startup.
ORPHANS=$(podman ps -a --filter "name=lfs-worker-" --filter "status=exited" --format "{{.ID}} {{.Names}} {{.Status}}" 2>/dev/null || true)

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
    echo "  podman stop \$(podman ps -aq --filter name=lfs-worker- --filter status=exited)"
    echo "  podman rm \$(podman ps -aq --filter name=lfs-worker- --filter status=exited)"
    exit 0
fi

echo "Stopping and removing orphaned containers..."
podman ps -a --filter "name=lfs-worker-" --filter "status=exited" --format "{{.ID}}" | while read -r id; do
    if [ -n "$id" ]; then
        echo "  Removing container $id..."
        podman stop --time 5 "$id" 2>/dev/null || true
        podman rm -f "$id" 2>/dev/null || true
    fi
done

echo ""
echo "Cleanup complete."
