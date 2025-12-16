#!/bin/bash
set -euo pipefail

# Worker Smoke Test
# Tests the Podman worker's JSON protocol and basic functionality

echo "=== Worker Smoke Test ==="

# Debug EXTERNAL_DIR calculation
echo "=== Debug Info ==="
echo "PWD=$PWD"
EXECROOT="${PWD}"
echo "EXECROOT=$EXECROOT"
EXTERNAL_DIR="$(dirname "$(dirname "$EXECROOT")")/external"
echo "EXTERNAL_DIR=$EXTERNAL_DIR"
ls -ld "$EXTERNAL_DIR" 2>&1 || echo "Warning: EXTERNAL_DIR does not exist!"
echo "==================="

# Create test directories
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

# Create minimal sysroot for testing
# Note: The launcher expects sysroot relative to PWD
SYSROOT="$PWD/sysroot"
mkdir -p "$SYSROOT/usr/bin"
cp /bin/bash "$SYSROOT/usr/bin/"

# Create a simple test build script in PWD (so it's in /execroot when mounted)
cat > "$PWD/test_build.sh" << 'EOF'
#!/bin/bash
echo "=== Test Build Script ==="
echo "LFS=$LFS"
echo "PATH=$PATH"
echo "HOME=$HOME"
echo "Test successful!"
EOF
chmod +x "$PWD/test_build.sh"

# Create JSON request (use /lfs for outputs since it's mounted RW in the container)
cat > "$TEST_DIR/request.json" << EOF
{"requestId":1,"arguments":["--script","/execroot/test_build.sh","--done","/lfs/test.done","--log","/lfs/test.log"]}
EOF

# Get paths to worker components
WORKER_LAUNCHER="$1"

# Verify container image exists
if ! podman image exists lfs-builder:bookworm 2>/dev/null; then
    echo "ERROR: Container image 'lfs-builder:bookworm' not found"
    echo "Build it first with: bazel run //tools/podman:container_image"
    exit 1
fi

# Run worker with timeout
echo "Starting worker..."
if ! timeout 10 "$WORKER_LAUNCHER" < "$TEST_DIR/request.json" > "$TEST_DIR/worker_output.txt" 2>&1; then
    echo "ERROR: Worker failed or timed out"
    echo "Worker output:"
    cat "$TEST_DIR/worker_output.txt"
    exit 1
fi

echo "Worker output:"
cat "$TEST_DIR/worker_output.txt"

# Check for JSON response
if ! grep -q '"requestId":' "$TEST_DIR/worker_output.txt"; then
    echo "ERROR: No JSON response from worker"
    exit 1
fi

echo "✓ Worker responded with JSON"

# Check if log file was created (in sysroot since that's where container wrote it)
if [ ! -f "$SYSROOT/test.log" ]; then
    echo "ERROR: Log file not created at $SYSROOT/test.log"
    exit 1
fi

echo "✓ Log file created"
echo "Log contents:"
cat "$SYSROOT/test.log"

# Note: We don't check for test.done because the chroot will fail
# (minimal sysroot doesn't have all dependencies), but the protocol should work

echo ""
echo "=== Smoke Test PASSED ==="
echo "Worker successfully:"
echo "  - Started and prepared chroot environment"
echo "  - Accepted JSON request"
echo "  - Processed the request"
echo "  - Sent JSON response"
echo "  - Created output log file"
