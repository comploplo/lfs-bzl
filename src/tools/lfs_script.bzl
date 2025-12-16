"""
LFS Script Rule

This module provides the lfs_script macro for executing arbitrary scripts
in the LFS environment (e.g., for configuration, file creation, or cleanup).
It wraps lfs_package to reuse the worker/environment setup but provides
a simpler interface for scripting tasks. Intended for use in the chroot phase.
"""

load("//tools:lfs_package.bzl", "lfs_package")

def lfs_script(
        name,
        script,
        srcs = [],
        phase = "chroot",
        deps = [],
        **kwargs):
    """
    Execute a script in the LFS environment.

    Args:
        name: Target name
        script: The script to execute (passed to install_cmd)
        srcs: Optional source files available to the script
        phase: Build phase (default: "chroot")
        deps: Dependencies that must run before this script
        **kwargs: Additional arguments passed to lfs_package
    """
    lfs_package(
        name = name,
        srcs = srcs,
        phase = phase,
        build_cmd = "true",
        configure_cmd = "true",
        install_cmd = script,
        deps = deps,
        **kwargs
    )
