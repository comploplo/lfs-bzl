#!/bin/bash
# Simple test wrapper for lfs_package tests
# The actual test work is done by the test_package dependency
# If we reach here, the dependency built successfully, so the test passed
echo "Test passed"
exit 0
