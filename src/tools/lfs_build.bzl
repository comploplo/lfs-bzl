"""
LFS Build Rules and Tooling.

Implements the "Managed Chaos" bridge: Bazel orchestrates while shell/make
perform the real LFS steps. Includes helpers for package builds, autotools
shortcuts, and toolchain handoff.
"""

load("//tools:providers.bzl", "LfsToolchainInfo")

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

    Handles the standard LFS package build pattern:
    1. Extract tarballs (all provided)
    2. Apply patches (optional)
    3. Inject toolchain environment
    4. Run configure with specified flags
    5. Run make
    6. Run make install to sysroot
    7. Create marker file for dependency tracking
    8. Create runner script if executable
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
        'LOG_DIR="$EXECROOT/tracker/logs"',
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
            'echo "Configuring {}..."'.format(ctx.label.name),
            ctx.attr.configure_cmd,
            "",
        ])

    if ctx.attr.build_cmd:
        script_parts.extend([
            "# Build",
            'echo "Building {}..."'.format(ctx.label.name),
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
        runner_script = """#!/bin/bash
# Runner script for LFS package: {name}
# This script executes the binary from sysroot

if [ -n "$BUILD_WORKSPACE_DIRECTORY" ]; then
    WORKSPACE_ROOT="$BUILD_WORKSPACE_DIRECTORY"
else
    SCRIPT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd -P)"
    CURRENT="$SCRIPT_DIR"
    while [ "$CURRENT" != "/" ]; do
        if [ -f "$CURRENT/WORKSPACE" ]; then
            WORKSPACE_ROOT="$CURRENT"
            break
        fi
        CURRENT="$(dirname "$CURRENT")"
    done
fi

if [ -z "$WORKSPACE_ROOT" ]; then
    echo "Error: Could not find workspace root" >&2
    exit 1
fi

SYSROOT="$WORKSPACE_ROOT/sysroot"
BINARY="$SYSROOT/tools/bin/{binary}"

if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY" >&2
    echo "Run 'bazel build {label}' first" >&2
    exit 1
fi

exec "$BINARY" "$@"
""".format(
            name = ctx.label.name,
            binary = runner_name,
            label = ctx.label,
        )

        ctx.actions.write(
            output = output,
            content = runner_script,
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

def lfs_autotools_package(
        name,
        srcs,
        prefix = "/tools",
        configure_flags = [],
        make_flags = [],
        install_cmd = None,
        **kwargs):
    """
    Convenience macro for standard autotools packages.

    Args:
        name: Target name
        srcs: Source tarball(s)
        prefix: Install prefix (default: /tools)
        configure_flags: Additional configure flags
        make_flags: Additional make flags
        install_cmd: Optional override for the install command
        **kwargs: Additional arguments passed to lfs_package
    """
    configure_cmd = "./configure --prefix={}".format(prefix)
    if configure_flags:
        configure_cmd += " " + " ".join(configure_flags)

    make_cmd = "make"
    if make_flags:
        make_cmd += " " + " ".join(make_flags)
    else:
        make_cmd += " -j$(nproc)"

    lfs_package(
        name = name,
        srcs = srcs,
        configure_cmd = configure_cmd,
        build_cmd = make_cmd,
        install_cmd = install_cmd if install_cmd else "make install",
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
    """
    Convenience wrapper for simple C/C++ style builds.

    - If make_targets are provided, runs `make -j$(nproc) <targets>` then installs
      the produced binary from the current directory.
    - Otherwise, compiles srcs directly with $CC/$CXX and installs to prefix/bin.

    Args:
        name: Target name.
        srcs: Source files to compile (or feed to make).
        toolchain: Optional LfsToolchainInfo to seed PATH/CC/CXX.
        prefix: Install prefix (default /tools).
        binary_name: Optional override for installed binary name.
        copts: Extra compiler options for direct compile path.
        ldopts: Extra linker options for direct compile path.
        make_targets: If set, run `make -j$(nproc) <targets>` instead of direct compile.
        **kwargs: Forwarded to lfs_package (deps, patches, env, etc.).
    """
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
        toolchain = toolchain,
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
        **kwargs):
    """
    Macro for the common configure/make/install pattern with an out-of-tree build.

    Args:
        name: Target name
        srcs: Source tarball(s)
        configure_flags: Extra flags appended to ./configure
        make_targets: Explicit build targets (empty = default all)
        install_targets: Targets to pass to `make` for installation (default: install)
        prefix: Install prefix (default /tools)
        destdir: Optional DESTDIR for staged installs
        toolchain: Optional LfsToolchainInfo provider
        build_subdir: Directory used for out-of-tree build (default: "build")
        **kwargs: Forwarded to lfs_package (deps, patches, env, binary_name, etc.)
    """
    cfg_cmd = "( mkdir -p {bd} && cd {bd} && ../configure --prefix={prefix}".format(
        bd = build_subdir,
        prefix = prefix,
    )
    if configure_flags:
        cfg_cmd += " " + " ".join(configure_flags)
    cfg_cmd += " )"

    build_cmd = "( mkdir -p {bd} && cd {bd} && make -j$(nproc)".format(bd = build_subdir)
    if make_targets:
        build_cmd += " " + " ".join(make_targets)
    build_cmd += " )"

    install_base = "( cd {bd} && ".format(bd = build_subdir)
    if destdir:
        install_base += "DESTDIR={destdir} ".format(destdir = destdir)
    install_cmd = install_base + "make {targets} )".format(
        targets = " ".join(install_targets) if install_targets else "install",
    )

    lfs_package(
        name = name,
        srcs = srcs,
        configure_cmd = cfg_cmd,
        build_cmd = build_cmd,
        install_cmd = install_cmd,
        toolchain = toolchain,
        **kwargs
    )
