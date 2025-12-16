# LFS Build System - Script Templates
#
# These templates are used by Bazel rules to generate build scripts and wrappers.
# They are expanded with substitutions during the build process.

package(default_visibility = ["//visibility:public"])

# Export all template scripts
exports_files(glob([
    "*.sh",
    "*.tpl",
]))

# Template for lfs_package build scripts
filegroup(
    name = "lfs_package_build_template",
    srcs = ["lfs_package_build.sh.tpl"],
)

# Template for binary runner scripts
filegroup(
    name = "lfs_runner_script_template",
    srcs = ["lfs_runner_script.sh"],
)

# Template for sysroot file staging wrapper scripts
filegroup(
    name = "lfs_sysroot_stage_files_wrapper_template",
    srcs = ["lfs_sysroot_stage_files_wrapper.sh"],
)

# Template for chroot build runner scripts (displays build log)
filegroup(
    name = "lfs_chroot_runner_script_template",
    srcs = ["lfs_chroot_runner_script.sh.tpl"],
)

# Template for Podman worker launcher script
filegroup(
    name = "worker_launcher_template",
    srcs = ["worker_launcher.sh.tpl"],
)

# Template for Podman worker flagfile arguments
filegroup(
    name = "worker_flagfile_template",
    srcs = ["worker_flagfile.tpl"],
)
