"""
LFS Build Rules and Tooling.

Implements the "Managed Chaos" bridge: Bazel orchestrates while shell/make
perform the real LFS steps. Includes helpers for package builds, autotools
shortcuts, and toolchain handoff.
"""

load("//tools:lfs_defaults.bzl", "phase_defaults")
load("//tools:providers.bzl", "LfsToolchainInfo")

def _default_package_toolchain():
    """Returns a sensible default toolchain label based on the current package path.

    Allows BUILD files to omit explicit toolchain wiring when using standard
    chapter layout.
    """
    pkg = native.package_name()
    if pkg.startswith("packages/chapter_05"):
        return "//packages/chapter_05:cross_toolchain"
    if pkg.startswith("packages/chapter_06"):
        return "//packages/chapter_06:temp_tools_toolchain"
    if pkg.startswith("packages/chapter_07"):
        return "//packages/chapter_07:chroot_base_toolchain"
    return None

def _lfs_toolchain_impl(ctx):
    """Returns an LfsToolchainInfo provider to hand to downstream packages."""
    return [
        LfsToolchainInfo(
            bin_path = ctx.attr.bin_path,
            env = ctx.attr.env,
        ),
    ]

def _lfs_package_impl(ctx):
    """
    Implementation of the lfs_package rule.
    """
    sysroot_path = "sysroot"

    marker = ctx.actions.declare_file(ctx.label.name + ".done")
    runner_name = ctx.attr.binary_name if ctx.attr.binary_name else (ctx.label.name if ctx.attr.create_runner else "")
    output = ctx.actions.declare_file(ctx.label.name) if runner_name else marker

    inputs = list(ctx.files.srcs) + list(ctx.files.patches)
    for dep in ctx.attr.deps:
        inputs.extend(dep.files.to_list())

    src_list = " ".join(['"$EXECROOT/{}"'.format(f.path) for f in ctx.files.srcs])
    patch_list = " ".join(['"$EXECROOT/{}"'.format(f.path) for f in ctx.files.patches])

    script_parts = [
        "#!/bin/bash",
        "set -euo pipefail",
        "",
        "# LFS Package Build Script",
        "# Package: {}".format(ctx.label),
        "",
        'EXECROOT="$(pwd)"',
        # Keep logs inside bazel-out (standard Bazel output tree)
        'LOG_DIR="$EXECROOT/bazel-out/lfs-logs"',
        'mkdir -p "$LOG_DIR"',
        'LOG_FILE="$LOG_DIR/{}.log"'.format(ctx.label.name),
        'exec > >(tee "$LOG_FILE") 2>&1',
        "",
        "# LFS Environment",
        'export LFS="$EXECROOT/{}"'.format(sysroot_path),
        "export LC_ALL=POSIX",
        "export LFS_TGT=x86_64-lfs-linux-gnu",
        'export PATH="$LFS/tools/bin:$PATH"',
        "",
    ]

    if ctx.attr.env:
        for key, value in ctx.attr.env.items():
            script_parts.append('export {}="{}"'.format(key, value))
        script_parts.append("")

    if ctx.attr.toolchain:
        toolchain_info = ctx.attr.toolchain[LfsToolchainInfo]
        if toolchain_info.bin_path:
            script_parts.append('export PATH="{}:$PATH"'.format(toolchain_info.bin_path))
        if toolchain_info.env:
            for key, value in toolchain_info.env.items():
                script_parts.append('export {}="{}"'.format(key, value))
        script_parts.append("")

    script_parts.extend([
        "# Working directory",
        'WORK_DIR="$(mktemp -d)"',
        'trap "rm -rf $WORK_DIR" EXIT',
        'cd "$WORK_DIR"',
        "",
    ])

    if ctx.files.srcs:
        script_parts.extend([
            "# Stage sources (supports multiple tarballs/files)",
            "SRC_DIR=0",
            "for SRC in {} ; do".format(src_list),
            '  echo "Inspecting $(basename "$SRC")"',
            '  if tar tf "$SRC" >/dev/null 2>&1; then',
            '    echo "Extracting $(basename "$SRC")"',
            '    FIRST_DIR="$(tar tf "$SRC" | head -1 | cut -d/ -f1)" || true',
            '    tar xf "$SRC"',
            '    if [ "$SRC_DIR" = 0 ] && [ -n "$FIRST_DIR" ] && [ -d "$FIRST_DIR" ]; then',
            '      SRC_DIR="$FIRST_DIR"',
            "    fi",
            "  else",
            '    echo "Copying $(basename "$SRC")"',
            '    cp "$SRC" .',
            "  fi",
            "done",
            'if [ "$SRC_DIR" != 0 ] && [ -d "$SRC_DIR" ]; then',
            '  cd "$SRC_DIR"',
            "fi",
            "",
        ])

    if ctx.files.patches:
        script_parts.extend([
            "# Apply patches",
            "for PATCH in {} ; do".format(patch_list),
            '  echo "Applying $(basename "$PATCH")"',
            '  patch -Np1 -i "$PATCH"',
            "done",
            "",
        ])

    if ctx.attr.configure_cmd:
        script_parts.extend([
            "# Configure",
            'echo "Configuring {}"...'.format(ctx.label.name),
            ctx.attr.configure_cmd,
            "",
        ])

    if ctx.attr.build_cmd:
        script_parts.extend([
            "# Build",
            'echo "Building {}"...'.format(ctx.label.name),
            ctx.attr.build_cmd,
            "",
        ])

    if ctx.attr.install_cmd:
        script_parts.extend([
            "# Install",
            'echo "Installing {} to $LFS..."'.format(ctx.label.name),
            ctx.attr.install_cmd,
            "",
        ])

    script_parts.extend([
        "# Mark success",
        'cd "$EXECROOT"',
        'touch "{}"'.format(marker.path),
        'echo "Successfully built {}"'.format(ctx.label.name),
    ])

    ctx.actions.run_shell(
        inputs = inputs,
        outputs = [marker],
        command = "\n".join(script_parts),
        mnemonic = "LfsPackage",
        progress_message = "Building LFS package: {}".format(ctx.label.name),
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    if runner_name:
        ctx.actions.expand_template(
            template = ctx.file._runner_template,
            output = output,
            substitutions = {
                "{name}": ctx.label.name,
                "{binary}": runner_name,
                "{label}": str(ctx.label),
            },
            is_executable = True,
        )

        return [DefaultInfo(
            files = depset([output]),
            executable = output,
            runfiles = ctx.runfiles(files = [marker]),
        )]

    return [DefaultInfo(
        files = depset([marker]),
        executable = marker,
    )]

lfs_package = rule(
    implementation = _lfs_package_impl,
    doc = """
    Build an LFS package using the standard extract/configure/make/install pattern.
    Supports multiple source archives/files, optional patches, and log capture.
    """,
    attrs = {
        "srcs": attr.label_list(
            doc = "Source files (tarballs or individual files)",
            allow_files = True,
            mandatory = False,
        ),
        "patches": attr.label_list(
            doc = "Patch files to apply with patch -Np1",
            allow_files = True,
            mandatory = False,
            default = [],
        ),
        "deps": attr.label_list(
            doc = "Other lfs_package targets that must complete first",
            allow_files = False,
            mandatory = False,
            default = [],
        ),
        "env": attr.string_dict(
            doc = "Extra environment variables to export before running commands",
            default = {},
        ),
        "configure_cmd": attr.string(
            doc = "Configure command (e.g., './configure --prefix=/tools')",
            mandatory = False,
        ),
        "build_cmd": attr.string(
            doc = "Build command (e.g., 'make -j$(nproc)')",
            mandatory = False,
        ),
        "install_cmd": attr.string(
            doc = "Install command (e.g., 'make install')",
            mandatory = False,
        ),
        "toolchain": attr.label(
            doc = "Optional LFS toolchain to inject into build environment",
            providers = [LfsToolchainInfo],
            mandatory = False,
        ),
        "binary_name": attr.string(
            doc = "Name of the binary in $LFS/tools/bin/ (set create_runner to True to use label name)",
            mandatory = False,
            default = "",
        ),
        "create_runner": attr.bool(
            doc = "Set True to emit a runner script (uses label name unless binary_name is provided)",
            default = False,
        ),
        "_runner_template": attr.label(
            default = "//tools:lfs_runner_script_template",
            allow_single_file = True,
        ),
    },
    executable = True,
)

lfs_toolchain = rule(
    implementation = _lfs_toolchain_impl,
    doc = "Wraps bin_path and env into an LfsToolchainInfo for downstream packages.",
    attrs = {
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

def _default_phase_opts(phase, prefix, destdir, build_subdir, make_flags):
    defaults = phase_defaults(phase)
    return {
        "prefix": prefix if prefix else defaults["prefix"],
        "destdir": destdir if destdir else defaults["destdir"],
        "build_subdir": build_subdir if build_subdir else defaults["build_subdir"],
        "make_flags": make_flags if make_flags else defaults["make_flags"],
    }

def _render_configure(prefix, build_subdir, configure_flags, pre_cmds = []):
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
    flags = make_flags if make_flags else []
    cmd = "( cd {bd} && make".format(bd = build_subdir)
    if flags:
        cmd += " " + " ".join(flags)
    if make_targets:
        cmd += " " + " ".join(make_targets)
    cmd += " )"
    return cmd

def _render_install(build_subdir, install_targets, destdir):
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
    resolved_toolchain = toolchain if toolchain else _default_package_toolchain()
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
    resolved_toolchain = toolchain if toolchain else _default_package_toolchain()
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
    resolved_toolchain = toolchain if toolchain else _default_package_toolchain()
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

def _lfs_chroot_command_impl(ctx):
    """Implementation of the lfs_chroot_command rule.

    Executes a shell script inside the LFS chroot environment.

    Args:
      ctx: Rule context
    """
    sysroot_path = "sysroot"

    # Use short_path for workspace-relative path (e.g., "src/tools/lfs-chroot-helper.sh")
    # The wrapper script will compute the absolute path at runtime
    chroot_helper_path = ctx.file.chroot_helper.short_path

    output = ctx.actions.declare_file(ctx.label.name + ".done")
    script_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    wrapper_script_file = ctx.actions.declare_file(ctx.label.name + "_wrapper.sh")

    env_lines = [
        'export HOME="/root"',
        'export LC_ALL="C"',
        'export TERM="${TERM:-linux}"',
        'export LFS="/"',
        'export PATH="/usr/bin:/usr/sbin:/bin:/sbin"',
    ]

    if ctx.attr.toolchain:
        toolchain_info = ctx.attr.toolchain[LfsToolchainInfo]
        if toolchain_info.bin_path:
            env_lines.append('export PATH="{}:$PATH"'.format(toolchain_info.bin_path))
        for key, value in toolchain_info.env.items():
            env_lines.append('export {}="{}"'.format(key, value))

    for key, value in ctx.attr.env.items():
        env_lines.append('export {}="{}"'.format(key, value))

    # Write the user-provided command into a script file with environment setup
    ctx.actions.write(
        output = script_file,
        content = "\n".join(
            ["#!/bin/bash", "set -euo pipefail"] + env_lines + [""] + [ctx.attr.cmd],
        ),
        is_executable = True,
    )

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = wrapper_script_file,
        substitutions = {
            "{sysroot_dir}": sysroot_path,
            "{helper_abs_path}": chroot_helper_path,
            "{script_file_execpath}": script_file.path,
            "{label}": ctx.label.name,
            "{output_path}": output.path,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        inputs = [script_file, wrapper_script_file, ctx.file.chroot_helper] + ctx.files.lfs_sysroot + ctx.files.data,
        outputs = [output],
        command = "bash {}".format(wrapper_script_file.path),
        mnemonic = "LfsChrootCommand",
        progress_message = "Executing chroot command: {}".format(ctx.label.name),
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [DefaultInfo(
        files = depset([output]),
        executable = output,
    )]

lfs_chroot_command = rule(
    implementation = _lfs_chroot_command_impl,
    doc = """
    Executes a shell command inside the LFS chroot environment.
    """,
    attrs = {
        "cmd": attr.string(
            doc = "The shell commands to execute inside the chroot.",
            mandatory = True,
        ),
        "env": attr.string_dict(
            doc = "Additional environment variables to export inside the chroot.",
            default = {},
        ),
        "toolchain": attr.label(
            doc = "Optional toolchain provider to set PATH/ENV inside chroot.",
            providers = [LfsToolchainInfo],
        ),
        "lfs_sysroot": attr.label(
            doc = "The label of the filegroup representing the LFS sysroot directory.",
            allow_files = True,
            mandatory = True,
        ),
        "chroot_helper": attr.label(
            doc = "The label of the filegroup representing the lfs-chroot-helper.sh script.",
            allow_single_file = True,
            mandatory = True,
        ),
        "data": attr.label_list(
            doc = "Additional data dependencies for the command.",
            allow_files = True,
            default = [],
        ),
        "deps": attr.label_list(
            doc = "Other targets that must complete before this command runs.",
            default = [],
        ),
        "_wrapper_template": attr.label(
            default = "//tools:lfs_chroot_command_wrapper_template",
            allow_single_file = True,
        ),
    },
    executable = True,
)

def lfs_chroot_step(
        name,
        cmd,
        toolchain = None,
        env = {},
        lfs_sysroot = "//:lfs_sysroot_files",
        chroot_helper = "//tools:lfs_chroot_helper_script",
        tags = [],
        **kwargs):
    """
    Macro wrapper for lfs_chroot_command with sane defaults.
    """
    merged_tags = ["manual", "requires-sudo"] + tags
    resolved_toolchain = toolchain if toolchain else _default_package_toolchain()
    lfs_chroot_command(
        name = name,
        cmd = cmd,
        env = env,
        toolchain = resolved_toolchain,
        lfs_sysroot = lfs_sysroot,
        chroot_helper = chroot_helper,
        tags = merged_tags,
        **kwargs
    )

def lfs_chroot_extract_tarball(
        name,
        tarball_name,
        dest = "/sources",
        toolchain = None,
        env = {},
        tags = [],
        **kwargs):
    """Extract a tarball inside chroot and depend on its completion.

    The extraction directory is typically <dest>/<tarball basename without .tar.*>.

    Args:
      name: Target name
      tarball_name: Name of the tarball file (e.g., "perl-5.40.0.tar.xz")
      dest: Destination directory (default: /sources)
      toolchain: LfsToolchainInfo provider (default: auto-detected)
      env: Additional environment variables
      tags: Build tags
      **kwargs: Additional arguments passed to lfs_chroot_step
    """
    cmd = """
set -euo pipefail
tarball="{dest}/{tar}"
if [ ! -f "$tarball" ]; then
  echo "Missing tarball: $tarball" >&2
  exit 1
fi
dirname=$(basename "$tarball")
dirname=${{dirname%%.tar.*}}
tar -xf "$tarball" -C {dest}
if [ ! -d "{dest}/$dirname" ]; then
  echo "Expected directory {dest}/$dirname not found after extraction" >&2
  exit 1
fi
""".format(dest = dest, tar = tarball_name)

    lfs_chroot_step(
        name = name,
        cmd = cmd,
        toolchain = toolchain,
        env = env,
        tags = tags,
        **kwargs
    )
