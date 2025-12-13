#!/usr/bin/env bash
echo "Hello from inside the chroot!"
/bin/bash --version || true # Check for bash, allow failure
id || true
