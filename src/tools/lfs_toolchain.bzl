"""
LFS Toolchain Management

This module provides toolchain support for LFS builds, allowing different build
phases (cross-compilation, temporary tools, chroot) to use custom toolchains.

Public API:
- lfs_toolchain: Rule that wraps toolchain configuration into LfsToolchainInfo
- default_package_toolchain(): Auto-detect toolchain based on package path

Related modules:
- providers.bzl: Defines LfsToolchainInfo provider
- lfs_package.bzl: Consumes toolchains in package builds
- lfs_chroot.bzl: Uses toolchains in chroot operations
"""

load("//tools:providers.bzl", "LfsToolchainInfo")

def default_package_toolchain():
    """Returns a sensible default toolchain label based on the current package path.

    Allows BUILD files to omit explicit toolchain wiring when using standard
    chapter layout.

    Returns:
        Toolchain label string for the current chapter, or None if not in a chapter package
    """
    pkg = native.package_name()
    if pkg.startswith("packages/chapter_05"):
        # Chapter 5 builds the cross-toolchain using the host gcc
        return None
    if pkg.startswith("packages/chapter_06"):
        # Chapter 6 uses the cross-toolchain built in Chapter 5
        return "//packages/chapter_05:cross_toolchain"
    if pkg.startswith("packages/chapter_07"):
        # Chapter 7 uses the temporary tools built in Chapter 6
        return "//packages/chapter_06:temp_tools_toolchain"
    return None

def _lfs_toolchain_impl(ctx):
    """Returns an LfsToolchainInfo provider (and a marker output) for downstream packages.

    Args:
        ctx: Rule context containing bin_path, env, and optional deps

    Returns:
        Providers including LfsToolchainInfo and DefaultInfo for a marker file.
    """
    marker = ctx.actions.declare_file(ctx.label.name + ".toolchain_ready")

    dep_files = depset(transitive = [d.files for d in ctx.attr.deps]).to_list()
    if dep_files:
        ctx.actions.run_shell(
            inputs = dep_files,
            outputs = [marker],
            command = "printf '%s\\n' 'ready' > '{}'".format(marker.path),
            mnemonic = "LfsToolchainReady",
            progress_message = "Assembling LFS toolchain: {}".format(ctx.label.name),
        )
    else:
        ctx.actions.write(
            output = marker,
            content = "ready\n",
        )

    return [
        DefaultInfo(files = depset([marker])),
        LfsToolchainInfo(
            bin_path = ctx.attr.bin_path,
            env = ctx.attr.env,
        ),
    ]

lfs_toolchain = rule(
    implementation = _lfs_toolchain_impl,
    doc = """Wraps bin_path and env into an LfsToolchainInfo for downstream packages.

    This rule defines a custom toolchain that can be passed to lfs_package, lfs_chroot_command,
    and other LFS build rules. It allows controlling the PATH and environment variables used
    during builds.

    Example:
        ```python
        lfs_toolchain(
            name = "cross_toolchain",
            bin_path = "$LFS/tools/bin",
            env = {
                "CC": "x86_64-lfs-linux-gnu-gcc",
                "CXX": "x86_64-lfs-linux-gnu-g++",
                "LFS_TGT": "x86_64-lfs-linux-gnu",
            },
        )

        lfs_package(
            name = "glibc",
            toolchain = ":cross_toolchain",
            ...
        )
        ```
    """,
    attrs = {
        "deps": attr.label_list(
            doc = "Build prerequisites for this toolchain (forces transitive build ordering).",
            default = [],
        ),
        "bin_path": attr.string(
            doc = "Path to prepend to PATH for consumers (e.g., sysroot/tools/bin)",
            default = "",
        ),
        "env": attr.string_dict(
            doc = "Environment variables to export (e.g., CC, CXX, LFS_TGT)",
            default = {},
        ),
    },
)
