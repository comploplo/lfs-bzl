"""
LFS Build Macros

This module provides high-level convenience macros built on top of lfs_package.
These macros handle common build patterns (autotools, make, C binaries) with
sensible defaults and phase-based configuration.

Public API:
- lfs_autotools: Declarative autotools macro using phase presets
- lfs_plain_make: Macro for packages that only need make + install
- lfs_autotools_package: Simple autotools wrapper with minimal config
- lfs_c_binary: Helper for simple C/C++ builds
- lfs_configure_make: Common configure/make/install pattern

Related modules:
- lfs_package.bzl: Core package building rule
- lfs_toolchain.bzl: Toolchain management
- lfs_defaults.bzl: Phase-based defaults
"""

load("//tools:lfs_defaults.bzl", "phase_defaults")
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_toolchain.bzl", "default_package_toolchain")

def _default_phase_opts(phase, prefix, destdir, build_subdir, make_flags):
    """Merge user-provided options with phase defaults.

    Args:
        phase: Phase identifier (ch5, ch6, ch7)
        prefix: Install prefix override (or None for default)
        destdir: DESTDIR override (or None for default)
        build_subdir: Build subdirectory override (or None for default)
        make_flags: Make flags override (or None for default)

    Returns:
        Dict with resolved options
    """
    defaults = phase_defaults(phase)
    return {
        "prefix": prefix if prefix else defaults["prefix"],
        "destdir": destdir if destdir else defaults["destdir"],
        "build_subdir": build_subdir if build_subdir else defaults["build_subdir"],
        "make_flags": make_flags if make_flags else defaults["make_flags"],
    }

def _render_configure(prefix, build_subdir, configure_flags, pre_cmds = []):
    """Render configure command for out-of-tree builds.

    Args:
        prefix: Install prefix (e.g., /tools, /usr)
        build_subdir: Build subdirectory name
        configure_flags: Additional configure flags
        pre_cmds: Commands to run before configure

    Returns:
        Rendered shell command string
    """
    lines = []
    if pre_cmds:
        lines.extend(pre_cmds)
    cmd = "( mkdir -p {bd} && cd {bd} && ../configure --prefix={prefix}".format(
        bd = build_subdir,
        prefix = prefix,
    )
    if configure_flags:
        cmd += " " + " ".join(configure_flags)
    cmd += " )"
    lines.append(cmd)
    return "\n".join(lines)

def _render_make(build_subdir, make_targets, make_flags):
    """Render make command.

    Args:
        build_subdir: Build subdirectory name
        make_targets: Make targets to build
        make_flags: Make flags (e.g., -j$(nproc))

    Returns:
        Rendered shell command string
    """
    flags = make_flags if make_flags else []
    cmd = "( cd {bd} && make".format(bd = build_subdir)
    if flags:
        cmd += " " + " ".join(flags)
    if make_targets:
        cmd += " " + " ".join(make_targets)
    cmd += " )"
    return cmd

def _render_install(build_subdir, install_targets, destdir):
    """Render make install command.

    Args:
        build_subdir: Build subdirectory name
        install_targets: Install targets (default: install)
        destdir: DESTDIR value (or None)

    Returns:
        Rendered shell command string
    """
    targets = " ".join(install_targets) if install_targets else "install"
    dest_prefix = "DESTDIR={destdir} ".format(destdir = destdir) if destdir else ""
    return "( cd {bd} && {dest}make {targets} )".format(
        bd = build_subdir,
        dest = dest_prefix,
        targets = targets,
    )

def lfs_autotools(
        name,
        srcs,
        phase = "ch6",
        configure_flags = [],
        make_targets = [],
        install_targets = ["install"],
        prefix = None,
        destdir = None,
        build_subdir = None,
        make_flags = None,
        pre_configure_cmds = [],
        toolchain = None,
        env = {},
        **kwargs):
    """Declarative autotools macro using phase presets (ch5/ch6/ch7).

    Only specify deltas: extra configure flags, make targets, or install targets.
    Sensible defaults are provided based on the build phase.

    Example:
        ```python
        lfs_autotools(
            name = "binutils_pass1",
            srcs = ["@binutils_src//file"],
            phase = "ch5",
            configure_flags = [
                "--with-sysroot=$LFS",
                "--target=$LFS_TGT",
                "--disable-nls",
            ],
        )
        ```

    Args:
      name: Target name
      srcs: Source files (tarballs)
      phase: Build phase preset ("ch5", "ch6", "ch7")
      configure_flags: Additional flags for configure
      make_targets: Make targets to build (default: no targets, runs default make)
      install_targets: Install targets (default: ["install"])
      prefix: Install prefix (overrides phase default)
      destdir: DESTDIR for install (overrides phase default)
      build_subdir: Build subdirectory (overrides phase default)
      make_flags: Make flags (overrides phase default)
      pre_configure_cmds: Commands to run before configure
      toolchain: LfsToolchainInfo provider (default: auto-detected from package path)
      env: Additional environment variables
      **kwargs: Additional arguments passed to lfs_package
    """
    resolved_toolchain = toolchain if toolchain else default_package_toolchain()
    opts = _default_phase_opts(
        phase = phase,
        prefix = prefix,
        destdir = destdir,
        build_subdir = build_subdir,
        make_flags = make_flags,
    )

    lfs_package(
        name = name,
        srcs = srcs,
        configure_cmd = _render_configure(
            prefix = opts["prefix"],
            build_subdir = opts["build_subdir"],
            configure_flags = configure_flags,
            pre_cmds = pre_configure_cmds,
        ),
        build_cmd = _render_make(
            build_subdir = opts["build_subdir"],
            make_targets = make_targets,
            make_flags = opts["make_flags"],
        ),
        install_cmd = _render_install(
            build_subdir = opts["build_subdir"],
            install_targets = install_targets,
            destdir = opts["destdir"],
        ),
        toolchain = resolved_toolchain,
        env = env,
        **kwargs
    )

def lfs_plain_make(
        name,
        srcs,
        phase = "ch6",
        make_targets = [],
        install_cmd = None,
        make_flags = None,
        build_subdir = None,
        destdir = None,
        toolchain = None,
        env = {},
        **kwargs):
    """Macro for packages that only need make + install (no configure).

    Example:
        ```python
        lfs_plain_make(
            name = "util-linux",
            srcs = ["@util_linux_src//file"],
            phase = "ch6",
            make_targets = ["all"],
        )
        ```

    Args:
      name: Target name
      srcs: Source files (tarballs)
      phase: Build phase preset ("ch5", "ch6", "ch7")
      make_targets: Make targets to build
      install_cmd: Custom install command (default: uses phase default)
      make_flags: Make flags (overrides phase default)
      build_subdir: Build subdirectory (overrides phase default)
      destdir: DESTDIR for install (overrides phase default)
      toolchain: LfsToolchainInfo provider (default: auto-detected)
      env: Additional environment variables
      **kwargs: Additional arguments passed to lfs_package
    """
    resolved_toolchain = toolchain if toolchain else default_package_toolchain()
    opts = _default_phase_opts(
        phase = phase,
        prefix = None,
        destdir = destdir,
        build_subdir = build_subdir,
        make_flags = make_flags,
    )
    build_cmd = _render_make(
        build_subdir = opts["build_subdir"],
        make_targets = make_targets,
        make_flags = opts["make_flags"],
    )
    final_install = install_cmd if install_cmd else _render_install(
        build_subdir = opts["build_subdir"],
        install_targets = ["install"],
        destdir = opts["destdir"],
    )

    lfs_package(
        name = name,
        srcs = srcs,
        build_cmd = build_cmd,
        install_cmd = final_install,
        toolchain = resolved_toolchain,
        env = env,
        **kwargs
    )

def lfs_autotools_package(
        name,
        srcs,
        prefix = "/tools",
        configure_flags = [],
        make_flags = [],
        **kwargs):
    """Convenience macro for standard autotools packages.

    This is a simplified version of lfs_autotools for common cases.

    Example:
        ```python
        lfs_autotools_package(
            name = "m4",
            srcs = ["@m4//file"],
            configure_flags = ["--host=$LFS_TGT"],
        )
        ```

    Args:
      name: Target name
      srcs: Source files (tarballs)
      prefix: Install prefix (default: /tools)
      configure_flags: Additional flags for configure
      make_flags: Make flags
      **kwargs: Additional arguments passed to lfs_autotools
    """
    phase = "ch5" if prefix == "/tools" else "ch6"
    lfs_autotools(
        name = name,
        srcs = srcs,
        phase = phase,
        prefix = prefix,
        configure_flags = configure_flags,
        make_flags = make_flags,
        install_targets = ["install"],
        **kwargs
    )

def lfs_c_binary(
        name,
        srcs,
        toolchain = None,
        prefix = "/tools",
        binary_name = None,
        copts = [],
        ldopts = [],
        make_targets = [],
        **kwargs):
    """Convenience wrapper for simple C/C++ style builds.

    Emits a runner by default (same as `bazel run`) unless you override via
    `create_runner` in `**kwargs`.

    Example (direct compilation):
        ```python
        lfs_c_binary(
            name = "hello",
            srcs = ["hello.c"],
            toolchain = ":cross_toolchain",
        )
        ```

    Example (using make):
        ```python
        lfs_c_binary(
            name = "hello",
            srcs = ["hello.c", "Makefile"],
            make_targets = ["all"],
        )
        ```

    Args:
      name: Target name
      srcs: Source files
      toolchain: LfsToolchainInfo provider (default: auto-detected)
      prefix: Install prefix (default: /tools)
      binary_name: Output binary name (default: same as name)
      copts: Compiler options
      ldopts: Linker options
      make_targets: If set, use make instead of direct compilation
      **kwargs: Additional arguments passed to lfs_package
    """
    resolved_toolchain = toolchain if toolchain else default_package_toolchain()
    bin_name = binary_name if binary_name else name
    if make_targets:
        build_cmd = "make -j$(nproc) {}".format(" ".join(make_targets))
        install_cmd = "install -D {} $LFS{}/bin/{}".format(bin_name, prefix, bin_name)
    else:
        # Direct compile path
        src_list = " ".join(srcs)
        build_cmd = "$CC {} {} -o {}".format(" ".join(copts), src_list, bin_name)
        if ldopts:
            build_cmd += " " + " ".join(ldopts)
        install_cmd = "install -D {} $LFS{}/bin/{}".format(bin_name, prefix, bin_name)

    lfs_package(
        name = name,
        srcs = srcs,
        build_cmd = build_cmd,
        install_cmd = install_cmd,
        toolchain = resolved_toolchain,
        binary_name = bin_name,
        create_runner = True,
        **kwargs
    )

def lfs_configure_make(
        name,
        srcs,
        configure_flags = [],
        make_targets = [],
        install_targets = ["install"],
        prefix = "/tools",
        destdir = None,
        toolchain = None,
        build_subdir = "build",
        phase = None,
        **kwargs):
    """Macro for the common configure/make/install pattern with an out-of-tree build.

    Phase can be overridden; defaults to ch5 for /tools prefixes, otherwise ch6.

    Example:
        ```python
        lfs_configure_make(
            name = "glibc",
            srcs = ["@glibc//file"],
            configure_flags = [
                "--host=$LFS_TGT",
                "--build=$(../scripts/config.guess)",
            ],
            prefix = "/usr",
            destdir = "$LFS",
        )
        ```

    Args:
      name: Target name
      srcs: Source files (tarballs)
      configure_flags: Additional flags for configure
      make_targets: Make targets to build
      install_targets: Install targets (default: ["install"])
      prefix: Install prefix (default: /tools)
      destdir: DESTDIR for install
      toolchain: LfsToolchainInfo provider (default: auto-detected)
      build_subdir: Build subdirectory (default: "build")
      phase: Build phase preset (default: auto-detected from prefix)
      **kwargs: Additional arguments passed to lfs_autotools
    """
    phase_value = phase if phase else ("ch5" if prefix == "/tools" else "ch6")
    lfs_autotools(
        name = name,
        srcs = srcs,
        phase = phase_value,
        configure_flags = configure_flags,
        make_targets = make_targets,
        install_targets = install_targets,
        prefix = prefix,
        destdir = destdir,
        build_subdir = build_subdir,
        toolchain = toolchain,
        **kwargs
    )
