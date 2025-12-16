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

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:providers.bzl", "LfsToolchainInfo")

def _is_chroot_phase(phase):
    """Returns True if this phase should use the Podman worker."""
    return phase == "chroot"

def _run_chroot_build(ctx, build_script, marker, inputs):
    """Execute build using Podman worker with JSON protocol."""
    log_file = ctx.actions.declare_file(ctx.label.name + ".log")

    # Create flagfile from template (required by Bazel worker strategy)
    # Bazel reads this and sends contents as JSON work requests via stdin
    flagfile = ctx.actions.declare_file(ctx.label.name + "_worker.params")
    ctx.actions.expand_template(
        template = ctx.file._worker_flagfile_template,
        output = flagfile,
        substitutions = {
            "{script_path}": build_script.path,
            "{done_path}": marker.path,
            "{log_path}": log_file.path,
        },
    )

    ctx.actions.run(
        executable = ctx.executable._worker_launcher,
        arguments = ["@" + flagfile.path],
        inputs = depset(inputs + [build_script, flagfile]),
        outputs = [marker, log_file],
        mnemonic = "LfsChrootBuild",
        progress_message = "Building LFS package (chroot): {}".format(ctx.label.name),
        execution_requirements = {
            "supports-workers": "1",
            "requires-worker-protocol": "json",
            "no-sandbox": "1",
        },
    )
    return log_file

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
cd "$WORKDIR"
{cmd}
""".format(name = ctx.label.name, cmd = configure_cmd)

    build_block = ""
    if build_cmd:
        build_block = """# Build
echo "Building {name}"...
cd "$WORKDIR"
{cmd}
""".format(name = ctx.label.name, cmd = build_cmd)

    install_block = ""
    if install_cmd:
        install_block = """# Install
echo "Installing {name} to $LFS"...
cd "$WORKDIR"
{cmd}
""".format(name = ctx.label.name, cmd = install_cmd)

    # Determine if we should skip ownership check
    # For chroot phase builds, always skip ownership check (runs as root inside container)
    # Otherwise use the explicit attribute value
    phase = ctx.attr.phase
    skip_check = _is_chroot_phase(phase) or ctx.attr.skip_ownership_check

    build_script = ctx.actions.declare_file(ctx.label.name + "_build.sh")
    ctx.actions.expand_template(
        template = ctx.file._build_template,
        output = build_script,
        substitutions = {
            "{label}": str(ctx.label),
            "{name}": ctx.label.name,
            "{sysroot_path}": sysroot_path,
            "{skip_ownership_check}": "1" if skip_check else "0",
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

    # Execute build - use Podman worker for chroot phase, direct shell otherwise
    phase = ctx.attr.phase
    if _is_chroot_phase(phase):
        _run_chroot_build(ctx, build_script, marker, inputs + cmd_inputs)
    else:
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

_lfs_package_rule = rule(
    implementation = _lfs_package_impl,
    doc = """
    Internal rule for building LFS packages.

    Use the lfs_package macro instead of calling this rule directly.
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
            doc = "Build phase (REQUIRED): ch5 (cross), ch6 (temp), or chroot (Podman worker)",
            mandatory = True,
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
        "_worker_launcher": attr.label(
            default = "//tools/podman:worker_launcher",
            executable = True,
            cfg = "exec",
        ),
        "_worker_flagfile_template": attr.label(
            default = "//tools/podman:worker_flagfile_template",
            allow_single_file = True,
        ),
    },
    executable = True,
)

def lfs_package(
        name,
        test_cmd = None,
        tags = [],
        **kwargs):
    """
    Build an LFS package using the standard extract/configure/make/install pattern.

    When test_cmd is provided, automatically creates a test target named {name}_test.

    Args:
        name: Target name
        test_cmd: Optional test command (e.g., 'make check'). Creates a test target if provided.
        tags: Tags to apply to the build target
        **kwargs: All other arguments passed to the underlying _lfs_package_rule

    Example:
        ```python
        lfs_package(
            name = "zlib",
            srcs = ["@zlib_src//file"],
            phase = "chroot",
            configure_cmd = "./configure --prefix=/usr",
            build_cmd = "make -j$(nproc)",
            install_cmd = "make install",
            test_cmd = "make check",  # Creates zlib_test target
        )
        ```

    This creates two targets:
    - :zlib - builds and installs the package
    - :zlib_test - runs the test suite
    """

    # Create the main build target
    _lfs_package_rule(
        name = name,
        tags = tags,
        **kwargs
    )

    # If test_cmd is provided, create a test target
    if test_cmd:
        test_name = name + "_test"
        test_package_name = name + "_test_package"

        # Create internal test package that rebuilds and tests
        # Tests need the package to be built first, so we run: configure + build + test
        test_build_cmd = kwargs.get("build_cmd", "make -j$(nproc)")
        if test_build_cmd:
            # Run build first, then test
            combined_test_cmd = test_build_cmd + " && " + test_cmd
        else:
            combined_test_cmd = test_cmd

        _lfs_package_rule(
            name = test_package_name,
            srcs = kwargs.get("srcs", []),
            patches = kwargs.get("patches", []),
            phase = kwargs.get("phase", "chroot"),
            toolchain = kwargs.get("toolchain", None),
            env = kwargs.get("env", {}),
            configure_cmd = kwargs.get("configure_cmd", "true"),  # Use same configure as main build
            build_cmd = combined_test_cmd,  # Build + test
            install_cmd = "true",  # Skip install for tests
            deps = kwargs.get("deps", []),  # Same deps as main build (don't depend on main build to avoid circular deps)
            tags = ["manual"],  # Don't build unless explicitly requested
        )

        # Create sh_test wrapper that depends on the test package
        sh_test(
            name = test_name,
            srcs = ["//tools/scripts:test_wrapper.sh"],
            data = [":" + test_package_name],
            tags = tags + ["test"],
            size = "large",  # Tests can take a while
        )
