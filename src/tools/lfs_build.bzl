"""
LFS Build Rules - Main Entry Point

This file re-exports all rules and macros from the modular implementation for
backward compatibility. Existing BUILD files can continue to use:
    load("//tools:lfs_build.bzl", "lfs_package", "lfs_autotools", ...)

For new code or when you want more explicit imports, prefer loading from
specific modules:
    load("//tools:lfs_package.bzl", "lfs_package")
    load("//tools:lfs_toolchain.bzl", "lfs_toolchain")
    load("//tools:lfs_chroot.bzl", "lfs_chroot_command", "lfs_chroot_step")
    load("//tools:lfs_macros.bzl", "lfs_autotools", "lfs_autotools_package")

Module Organization:
- lfs_package.bzl: Core package building rule
- lfs_toolchain.bzl: Toolchain management
- lfs_chroot.bzl: Chroot operations (Chapter 7+)
- lfs_macros.bzl: Convenience macros (autotools, make, c_binary)
- lfs_defaults.bzl: Phase-based defaults
- providers.bzl: Custom providers
"""

# Re-export from lfs_chroot.bzl
load(
    "//tools:lfs_chroot.bzl",
    _lfs_chroot_command = "lfs_chroot_command",
    _lfs_chroot_extract_tarball = "lfs_chroot_extract_tarball",
    _lfs_chroot_step = "lfs_chroot_step",
    _lfs_sysroot_stage_files = "lfs_sysroot_stage_files",
)

# Re-export from lfs_macros.bzl
load(
    "//tools:lfs_macros.bzl",
    _lfs_autotools = "lfs_autotools",
    _lfs_autotools_package = "lfs_autotools_package",
    _lfs_c_binary = "lfs_c_binary",
    _lfs_configure_make = "lfs_configure_make",
    _lfs_plain_make = "lfs_plain_make",
)

# Re-export from lfs_package.bzl
load("//tools:lfs_package.bzl", _lfs_package = "lfs_package")

# Re-export from lfs_toolchain.bzl
load(
    "//tools:lfs_toolchain.bzl",
    _lfs_toolchain = "lfs_toolchain",
)

# Public API - re-export everything with original names
lfs_package = _lfs_package
lfs_toolchain = _lfs_toolchain
lfs_chroot_command = _lfs_chroot_command
lfs_chroot_extract_tarball = _lfs_chroot_extract_tarball
lfs_chroot_step = _lfs_chroot_step
lfs_sysroot_stage_files = _lfs_sysroot_stage_files
lfs_autotools = _lfs_autotools
lfs_autotools_package = _lfs_autotools_package
lfs_c_binary = _lfs_c_binary
lfs_configure_make = _lfs_configure_make
lfs_plain_make = _lfs_plain_make
