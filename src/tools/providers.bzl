"""
LFS Build System Providers

This module defines custom providers for the LFS Bazel build system.
We use custom toolchain providers instead of native cc_toolchain to maintain
full control over the build environment.
"""

LfsToolchainInfo = provider(
    doc = """
    Provider for LFS toolchain information.

    This provider carries the necessary PATH and environment configuration
    to inject into build scripts, allowing us to use custom-built toolchains
    (cross-compiler, temporary tools, etc.) during different LFS phases.
    """,
    fields = {
        "bin_path": "Path to prepend to $PATH (string)",
        "env": "Dictionary of environment variables to export (dict[string, string])",
    },
)
