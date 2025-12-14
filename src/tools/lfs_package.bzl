"""
LFS Package Building Rule

This module provides the core lfs_package rule for building LFS packages using
the standard extract/configure/make/install pattern.

Public API:
- lfs_package: Rule for building LFS packages with configurable build phases

Related modules:
- providers.bzl: Defines LfsToolchainInfo provider
- lfs_toolchain.bzl: Provides toolchain management
- lfs_macros.bzl: Higher-level convenience macros built on lfs_package
"""

load("//tools:providers.bzl", "LfsToolchainInfo")

def _lfs_package_impl(ctx):
    """
    Implementation of the lfs_package rule.

    Builds an LFS package by:
    1. Setting up LFS environment (PATH, variables)
    2. Extracting sources and applying patches
    3. Running configure/build/install phases
    4. Creating output marker and optional runner script

    Args:
        ctx: Rule context with sources, commands, and configuration

    Returns:
        DefaultInfo with files and optional executable
    """
    sysroot_path = "sysroot"

    marker = ctx.actions.declare_file(ctx.label.name + ".done")
    runner_name = ctx.attr.binary_name if ctx.attr.binary_name else (ctx.label.name if ctx.attr.create_runner else "")
    output = ctx.actions.declare_file(ctx.label.name) if runner_name else marker

    inputs = list(ctx.files.srcs) + list(ctx.files.patches)
    cmd_inputs = []
    for dep in ctx.attr.deps:
        inputs.extend(dep.files.to_list())

    toolchain_files = []
    if ctx.attr.toolchain:
        toolchain_files = ctx.attr.toolchain[DefaultInfo].files.to_list()
        inputs.extend(toolchain_files)

    def _resolve_cmd(name, inline_value, file_value):
        if inline_value and file_value:
            fail("{}: specify either {} or {}_file, not both".format(ctx.label, name, name))
        if file_value:
            cmd_inputs.append(file_value)
            return 'bash "$EXECROOT/{}"'.format(file_value.path)
        return inline_value or ""

    src_list = " ".join(['"$EXECROOT/{}"'.format(f.path) for f in ctx.files.srcs])
    patch_list = " ".join(['"$EXECROOT/{}"'.format(f.path) for f in ctx.files.patches])

    extra_env_lines = []
    for key, value in ctx.attr.env.items():
        extra_env_lines.append('export {}="{}"'.format(key, value))
    extra_env = "\n".join(extra_env_lines)

    toolchain_exports = []
    if ctx.attr.toolchain:
        toolchain_info = ctx.attr.toolchain[LfsToolchainInfo]
        if toolchain_info.bin_path:
            toolchain_exports.append('export PATH="{}:$PATH"'.format(toolchain_info.bin_path))
        for key, value in toolchain_info.env.items():
            toolchain_exports.append('export {}="{}"'.format(key, value))
    toolchain_env = "\n".join(toolchain_exports)

    src_handling = ""
    if ctx.files.srcs:
        src_handling = """# Stage sources (supports multiple tarballs/files)
LFS_PKG_SRCS_FILE="$WORK_DIR/.lfs_pkg_srcs"
rm -f "$LFS_PKG_SRCS_FILE"
touch "$LFS_PKG_SRCS_FILE"
for SRC in {srcs} ; do
  printf '%s\\n' "$SRC" >> "$LFS_PKG_SRCS_FILE"
done
export LFS_PKG_SRCS_FILE
SRC_DIR=0
for SRC in {srcs} ; do
  echo "Inspecting $(basename "$SRC")"
  if tar tf "$SRC" >/dev/null 2>&1; then
    echo "Extracting $(basename "$SRC")"
    FIRST_DIR="$(tar tf "$SRC" | head -1 | cut -d/ -f1)" || true
    tar xf "$SRC"
    if [ "$SRC_DIR" = 0 ] && [ -n "$FIRST_DIR" ] && [ -d "$FIRST_DIR" ]; then
      SRC_DIR="$FIRST_DIR"
    fi
  else
    echo "Copying $(basename "$SRC")"
    cp "$SRC" .
  fi
done
if [ "$SRC_DIR" != 0 ] && [ -d "$SRC_DIR" ]; then
  cd "$SRC_DIR"
fi
""".format(srcs = src_list)

    patch_handling = ""
    if ctx.files.patches:
        patch_handling = """# Apply patches
for PATCH in {patches} ; do
  echo "Applying $(basename "$PATCH")"
  patch -Np1 -i "$PATCH"
done
""".format(patches = patch_list)

    configure_cmd = _resolve_cmd("configure_cmd", ctx.attr.configure_cmd, ctx.file.configure_cmd_file)
    build_cmd = _resolve_cmd("build_cmd", ctx.attr.build_cmd, ctx.file.build_cmd_file)
    install_cmd = _resolve_cmd("install_cmd", ctx.attr.install_cmd, ctx.file.install_cmd_file)

    configure_block = ""
    if configure_cmd:
        configure_block = """# Configure
echo "Configuring {name}"...
{cmd}
""".format(name = ctx.label.name, cmd = configure_cmd)

    build_block = ""
    if build_cmd:
        build_block = """# Build
echo "Building {name}"...
{cmd}
""".format(name = ctx.label.name, cmd = build_cmd)

    install_block = ""
    if install_cmd:
        install_block = """# Install
echo "Installing {name} to $LFS"...
{cmd}
""".format(name = ctx.label.name, cmd = install_cmd)

    build_script = ctx.actions.declare_file(ctx.label.name + "_build.sh")
    ctx.actions.expand_template(
        template = ctx.file._build_template,
        output = build_script,
        substitutions = {
            "{label}": str(ctx.label),
            "{name}": ctx.label.name,
            "{sysroot_path}": sysroot_path,
            "{skip_ownership_check}": "1" if ctx.attr.skip_ownership_check else "0",
            "{toolchain_exports}": (toolchain_env + "\n") if toolchain_env else "",
            "{extra_env}": (extra_env + "\n") if extra_env else "",
            "{src_handling}": src_handling,
            "{patch_handling}": patch_handling,
            "{configure_block}": configure_block,
            "{build_block}": build_block,
            "{install_block}": install_block,
            "{marker_path}": marker.path,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        inputs = inputs + cmd_inputs + [build_script],
        outputs = [marker],
        command = build_script.path,
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
            runfiles = ctx.runfiles(files = [marker] + toolchain_files),
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
    Commands can be provided as inline strings or as separate script files.

    Example:
        ```python
        lfs_package(
            name = "hello",
            srcs = ["hello.c"],
            build_cmd = "gcc hello.c -o hello",
            install_cmd = "install -D hello $LFS/tools/bin/hello",
        )
        ```

    For packages that produce executables:
        ```python
        lfs_package(
            name = "hello",
            srcs = ["hello.c"],
            build_cmd = "gcc hello.c -o hello",
            install_cmd = "install -D hello $LFS/tools/bin/hello",
            binary_name = "hello",
            create_runner = True,  # Allows 'bazel run :hello'
        )
        ```
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
        "configure_cmd_file": attr.label(
            doc = "File containing configure commands to run (exclusive with configure_cmd)",
            allow_single_file = True,
            mandatory = False,
        ),
        "build_cmd": attr.string(
            doc = "Build command (e.g., 'make -j$(nproc)')",
            mandatory = False,
        ),
        "build_cmd_file": attr.label(
            doc = "File containing build commands to run (exclusive with build_cmd)",
            allow_single_file = True,
            mandatory = False,
        ),
        "install_cmd": attr.string(
            doc = "Install command (e.g., 'make install')",
            mandatory = False,
        ),
        "install_cmd_file": attr.label(
            doc = "File containing install commands to run (exclusive with install_cmd)",
            allow_single_file = True,
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
        "phase": attr.string(
            doc = "Optional metadata describing the package phase (for documentation only)",
            default = "",
        ),
        "skip_ownership_check": attr.bool(
            doc = "Skip sysroot ownership check (for chroot builds running as root)",
            default = False,
        ),
        "_runner_template": attr.label(
            default = "//tools/scripts:lfs_runner_script_template",
            allow_single_file = True,
        ),
        "_build_template": attr.label(
            default = "//tools/scripts:lfs_package_build_template",
            allow_single_file = True,
        ),
    },
    executable = True,
)
