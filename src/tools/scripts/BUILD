# LFS Build System Scripts
#
# This directory contains scripts organized into functional groups:
# - templates/: Bazel rule template scripts (expanded during build)
# - tests/: Test scripts for validation
# - Root: Chroot-related scripts and utilities
#
# For backward compatibility, this BUILD file re-exports filegroups from
# subdirectories with their original names.

package(default_visibility = ["//visibility:public"])

# Export all scripts in the root directory
exports_files(glob(["*.sh"]))

# ----------------------------------------------------------------------------
# Chroot Helper Scripts (in root directory)
# ----------------------------------------------------------------------------

# Main chroot helper (privileged operations via sudo)
filegroup(
    name = "lfs_chroot_helper_script",
    srcs = ["lfs_chroot_helper.sh"],
)

# Chroot library modules (sourced by lfs_chroot_helper.sh)
filegroup(
    name = "lfs_chroot_lib",
    srcs = ["lfs_chroot_lib.sh"],
)

filegroup(
    name = "lfs_chroot_mount",
    srcs = ["lfs_chroot_mount.sh"],
)

filegroup(
    name = "lfs_chroot_exec",
    srcs = ["lfs_chroot_exec.sh"],
)

# Chroot utility scripts
filegroup(
    name = "chroot_extract_tarball_script",
    srcs = ["chroot_extract_tarball.sh"],
)

filegroup(
    name = "chroot_create_dirs_script",
    srcs = ["chroot_create_dirs.sh"],
)

filegroup(
    name = "chroot_seed_files_script",
    srcs = ["chroot_seed_files.sh"],
)

# Other utility scripts
filegroup(
    name = "stage_ch7_sources_script",
    srcs = ["stage_ch7_sources.sh"],
)

# ----------------------------------------------------------------------------
# Re-exports from subdirectories (for backward compatibility)
# ----------------------------------------------------------------------------

# Templates (from templates/ subdirectory)
alias(
    name = "lfs_runner_script_template",
    actual = "//tools/scripts/templates:lfs_runner_script_template",
)

alias(
    name = "lfs_package_build_template",
    actual = "//tools/scripts/templates:lfs_package_build_template",
)

alias(
    name = "lfs_chroot_command_wrapper_template",
    actual = "//tools/scripts/templates:lfs_chroot_command_wrapper_template",
)

alias(
    name = "lfs_sysroot_stage_files_wrapper_template",
    actual = "//tools/scripts/templates:lfs_sysroot_stage_files_wrapper_template",
)

# Tests (from tests/ subdirectory)
alias(
    name = "test_chroot_echo_script",
    actual = "//tools/scripts/tests:test_chroot_echo_script",
)

alias(
    name = "chroot_smoke_test_script",
    actual = "//tools/scripts/tests:chroot_smoke_test_script",
)

alias(
    name = "test_chroot_script",
    actual = "//tools/scripts/tests:test_chroot_script",
)
