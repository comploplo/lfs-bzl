#!/bin/bash
# Simple test script to verify chroot execution

set -euo pipefail

echo "=== Chroot Environment Test ==="
echo "Working directory: $(pwd)"
echo "PATH: $PATH"
echo "Bash location: $(which bash)"
echo "GCC version:"
x86_64-lfs-linux-gnu-gcc --version | head -1
echo ""
echo "Available binaries in /usr/bin:"
find /usr/bin -maxdepth 1 -type f -o -type l | head -20
echo ""
echo "Test completed successfully!"
