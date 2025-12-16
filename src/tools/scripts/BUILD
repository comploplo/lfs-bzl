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

# ----------------------------------------------------------------------------
# Re-exports from templates/ subdirectory
# ----------------------------------------------------------------------------

alias(
    name = "lfs_runner_script_template",
    actual = "//tools/scripts/templates:lfs_runner_script_template",
)

alias(
    name = "lfs_package_build_template",
    actual = "//tools/scripts/templates:lfs_package_build_template",
)

alias(
    name = "lfs_sysroot_stage_files_wrapper_template",
    actual = "//tools/scripts/templates:lfs_sysroot_stage_files_wrapper_template",
)
