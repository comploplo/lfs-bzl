# LFS Build Tools Package
# This package contains Starlark rules for building LFS packages

# Export the build rules for use by other packages
exports_files([
    "lfs_build.bzl",
    "providers.bzl",
    "lfs_defaults.bzl",
])

filegroup(
    name = "lfs_chroot_helper_script",
    srcs = ["lfs-chroot-helper.sh"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "lfs_runner_script_template",
    srcs = ["lfs_runner_script.sh"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "lfs_chroot_command_wrapper_template",
    srcs = ["lfs_chroot_command_wrapper.sh"],
    visibility = ["//visibility:public"],
)
