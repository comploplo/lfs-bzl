# LFS Build System Scripts
#
# This directory contains scripts for the Podman worker build system:
# - templates/: Bazel rule template scripts (expanded during build)
# - Root: Utility scripts

package(default_visibility = ["//visibility:public"])

# Export all scripts in the root directory
exports_files(glob(["*.sh"]))

# ----------------------------------------------------------------------------
# Utility Scripts
# ----------------------------------------------------------------------------

# Test wrapper for lfs_package tests
filegroup(
    name = "test_wrapper",
    srcs = ["test_wrapper.sh"],
)
