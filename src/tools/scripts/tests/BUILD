# LFS Build System - Test Scripts
#
# Test scripts for validating chroot and build functionality.

load("@rules_shell//shell:sh_test.bzl", "sh_test")

package(default_visibility = ["//visibility:public"])

# Export all test scripts
exports_files(glob(["*.sh"]))

# Test script for basic chroot echo functionality
filegroup(
    name = "test_chroot_echo_script",
    srcs = ["test_chroot_echo.sh"],
)

# Smoke test for chroot environment
filegroup(
    name = "chroot_smoke_test_script",
    srcs = ["chroot_smoke_test.sh"],
)

# General chroot test script
filegroup(
    name = "test_chroot_script",
    srcs = ["test-chroot.sh"],
)

# ----------------------------------------------------------------------------
# Test Targets
# ----------------------------------------------------------------------------

# Chroot smoke test - verifies basic chroot functionality
sh_test(
    name = "chroot_smoke_test",
    args = [
        "$(location :test_chroot_script)",
        "$(location //tools:lfs_chroot_helper_script)",
        "$(location //:lfs_sysroot_files)",
    ],
    data = [
        ":test_chroot_script",  # executed inside chroot
        "//:lfs_sysroot_files",
        "//tools:lfs_chroot_helper_script",
    ],
    tags = [
        "manual",
        "requires-sudo",
    ],
)
