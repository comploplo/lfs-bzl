"""
LFS Package Building Rule

This module provides the core lfs_package rule for building LFS packages using
the standard extract/configure/make/install pattern. All builds execute inside
a rootless Podman container via the Bazel persistent worker protocol.

Public API:
- lfs_package: Rule for building LFS packages with configurable build phases

Related modules:
- providers.bzl: Defines LfsToolchainInfo provider
- lfs_toolchain.bzl: Provides toolchain management
- lfs_macros.bzl: Higher-level convenience macros built on lfs_package
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:providers.bzl", "LfsToolchainInfo")

def _worker_mode(phase):
    """Returns the worker execution mode for a phase.

    All phases run in the Podman worker. ch5/ch6 use 'container' mode
    (direct execution), chroot uses 'chroot' mode.
    """
    if phase == "chroot":
        return "chroot"

    # "image" == container-mode disk assembly (chapter 11); maps to container.
    return "container"

def _run_worker_build(ctx, build_script, marker, inputs, mode):
    """Execute build using Podman worker with JSON protocol."""
    log_file = ctx.actions.declare_file(ctx.label.name + ".log")

    flagfile = ctx.actions.declare_file(ctx.label.name + "_worker.params")
    ctx.actions.expand_template(
        template = ctx.file._worker_flagfile_template,
        output = flagfile,
        substitutions = {
            "{mode}": mode,
            "{script_path}": build_script.path,
            "{done_path}": marker.path,
            "{log_path}": log_file.path,
        },
    )

    ctx.actions.run(
        executable = ctx.executable._worker_launcher,
        arguments = ["@" + flagfile.path],
        inputs = depset([build_script, flagfile], transitive = [inputs]),
        outputs = [marker, log_file],
        mnemonic = "LfsWorkerBuild",
        progress_message = "Building LFS package ({}): {}".format(mode, ctx.label.name),
        execution_requirements = {
            "supports-workers": "1",
            "requires-worker-protocol": "json",
            "no-sandbox": "1",
        },
    )
    return log_file

def _lfs_package_impl(ctx):
    marker = ctx.actions.declare_file(ctx.label.name + ".done")
    runner_name = ctx.attr.binary_name if ctx.attr.binary_name else (ctx.label.name if ctx.attr.create_runner else "")
    output = ctx.actions.declare_file(ctx.label.name) if runner_name else marker

    inputs = list(ctx.files.srcs) + list(ctx.files.patches)

    dep_depsets = [dep.files for dep in ctx.attr.deps]

    toolchain_depset = depset()
    if ctx.attr.toolchain:
        toolchain_depset = ctx.attr.toolchain[DefaultInfo].files

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

    configure_cmd = ctx.attr.configure_cmd
    build_cmd = ctx.attr.build_cmd
    install_cmd = ctx.attr.install_cmd

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

    phase = ctx.attr.phase
    mode = _worker_mode(phase)

    build_script = ctx.actions.declare_file(ctx.label.name + "_build.sh")
    ctx.actions.expand_template(
        template = ctx.file._build_template,
        output = build_script,
        substitutions = {
            "{label}": str(ctx.label),
            "{name}": ctx.label.name,
            "{mode}": mode,
            "{toolchain_exports}": (toolchain_env + "\n") if toolchain_env else "",
            "{extra_env}": (extra_env + "\n") if extra_env else "",
            "{src_handling}": src_handling,
            "{patch_handling}": patch_handling,
            "{configure_block}": configure_block,
            "{build_block}": build_block,
            "{install_block}": install_block,
        },
        is_executable = True,
    )

    transitive_depsets = dep_depsets + ([toolchain_depset] if ctx.attr.toolchain else [])
    all_inputs = depset(
        direct = inputs,
        transitive = transitive_depsets,
    )
    _run_worker_build(ctx, build_script, marker, all_inputs, mode)

    if runner_name:
        if phase == "chroot":
            log_path = ctx.label.package + "/" + ctx.label.name + ".log"
            ctx.actions.expand_template(
                template = ctx.file._chroot_runner_template,
                output = output,
                substitutions = {
                    "{name}": ctx.label.name,
                    "{label}": str(ctx.label),
                    "{log_path}": log_path,
                },
                is_executable = True,
            )
        else:
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
            files = depset([output, marker]),
            executable = output,
            runfiles = ctx.runfiles(files = [marker] + (toolchain_depset.to_list() if ctx.attr.toolchain else [])),
        )]

    return [DefaultInfo(
        files = depset([marker]),
        executable = marker,
    )]

_lfs_package_rule = rule(
    implementation = _lfs_package_impl,
    attrs = {
        "srcs": attr.label_list(
            allow_files = True,
            mandatory = False,
        ),
        "patches": attr.label_list(
            allow_files = True,
            mandatory = False,
            default = [],
        ),
        "deps": attr.label_list(
            allow_files = False,
            mandatory = False,
            default = [],
        ),
        "env": attr.string_dict(
            default = {},
        ),
        "configure_cmd": attr.string(
            mandatory = False,
        ),
        "build_cmd": attr.string(
            mandatory = False,
        ),
        "install_cmd": attr.string(
            mandatory = False,
        ),
        "toolchain": attr.label(
            providers = [LfsToolchainInfo],
            mandatory = False,
        ),
        "binary_name": attr.string(
            mandatory = False,
            default = "",
        ),
        "create_runner": attr.bool(
            default = False,
        ),
        "phase": attr.string(
            mandatory = True,
            values = ["ch5", "ch6", "chroot", "image"],
        ),
        "_runner_template": attr.label(
            default = "//tools/scripts/templates:lfs_runner_script_template",
            allow_single_file = True,
        ),
        "_chroot_runner_template": attr.label(
            default = "//tools/scripts/templates:lfs_chroot_runner_script_template",
            allow_single_file = True,
        ),
        "_build_template": attr.label(
            default = "//tools/scripts/templates:lfs_package_build_template",
            allow_single_file = True,
        ),
        "_worker_launcher": attr.label(
            default = "//tools/podman:worker_launcher",
            executable = True,
            cfg = "exec",
        ),
        "_worker_flagfile_template": attr.label(
            default = "//tools/scripts/templates:worker_flagfile_template",
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
    """

    _lfs_package_rule(
        name = name,
        tags = tags,
        **kwargs
    )

    if test_cmd:
        test_name = name + "_test"
        test_package_name = name + "_test_package"

        test_build_cmd = kwargs.get("build_cmd", "make -j$(nproc)")
        if test_build_cmd:
            # Reset to $WORKDIR between build and test so test_cmd runs from a
            # known directory; a bare ' && ' would re-run any cd in build_cmd
            # from the wrong place and abort under set -e.
            combined_test_cmd = test_build_cmd + '\ncd "$WORKDIR"\n' + test_cmd
        else:
            combined_test_cmd = test_cmd

        configure_cmd = kwargs.get("configure_cmd", None)
        if not configure_cmd:
            configure_cmd = "true"

        _lfs_package_rule(
            name = test_package_name,
            srcs = kwargs.get("srcs", []),
            patches = kwargs.get("patches", []),
            phase = kwargs.get("phase", "chroot"),
            toolchain = kwargs.get("toolchain", None),
            env = kwargs.get("env", {}),
            configure_cmd = configure_cmd,
            build_cmd = combined_test_cmd,
            install_cmd = "true",
            deps = kwargs.get("deps", []),
            tags = ["manual"],
        )

        sh_test(
            name = test_name,
            srcs = ["//tools/scripts:test_wrapper.sh"],
            data = [":" + test_package_name],
            tags = tags + ["test"],
            size = "large",
        )
