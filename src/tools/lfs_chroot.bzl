"""
LFS Chroot Operations

This module provides rules and macros for executing commands inside the LFS
chroot environment. Used for Chapter 7+ builds where commands must run inside
the constructed system.

Public API:
- lfs_chroot_command: Rule for executing commands inside chroot
- lfs_sysroot_stage_files: Rule for copying host files into sysroot
- lfs_chroot_step: Macro wrapper with sane defaults
- lfs_chroot_extract_tarball: Macro for extracting tarballs in chroot

Related modules:
- providers.bzl: Defines LfsToolchainInfo provider
- lfs_toolchain.bzl: Provides toolchain management
- scripts/lfs_chroot_helper.sh: Privileged helper script
"""

load("//tools:lfs_toolchain.bzl", "default_package_toolchain")
load("//tools:providers.bzl", "LfsToolchainInfo")

def _lfs_chroot_command_impl(ctx):
    """Implementation of the lfs_chroot_command rule.

    Executes a shell script inside the LFS chroot environment using the
    privileged chroot helper.

    Args:
      ctx: Rule context with command, environment, and dependencies

    Returns:
        DefaultInfo with done marker and runnable wrapper
    """
    sysroot_path = "sysroot"

    # Use short_path for workspace-relative path (e.g., "src/tools/scripts/lfs_chroot_helper.sh")
    # The wrapper script will compute the absolute path at runtime
    chroot_helper_path = ctx.file.chroot_helper.short_path

    output = ctx.actions.declare_file(ctx.label.name + ".done")
    script_file = ctx.actions.declare_file(ctx.label.name + ".sh")
    wrapper_script_file = ctx.actions.declare_file(ctx.label.name + "_wrapper.sh")
    runnable_script = ctx.actions.declare_file(ctx.label.name)

    if not ctx.attr.cmd and not ctx.file.cmd_file:
        fail("{}: specify cmd or cmd_file".format(ctx.label))
    if ctx.attr.cmd and ctx.file.cmd_file:
        fail("{}: choose either cmd or cmd_file, not both".format(ctx.label))

    env_lines = [
        'export HOME="/root"',
        'export LC_ALL="C"',
        'export TERM="${TERM:-linux}"',
        'export LFS="/"',
        'export PATH="/usr/bin:/usr/sbin:/bin:/sbin"',
    ]

    toolchain_files = []
    if ctx.attr.toolchain:
        toolchain_info = ctx.attr.toolchain[LfsToolchainInfo]
        toolchain_files = ctx.attr.toolchain[DefaultInfo].files.to_list()
        if toolchain_info.bin_path:
            env_lines.append('export PATH="{}:$PATH"'.format(toolchain_info.bin_path))
        for key, value in toolchain_info.env.items():
            env_lines.append('export {}="{}"'.format(key, value))

    for key, value in ctx.attr.env.items():
        env_lines.append('export {}="{}"'.format(key, value))

    cmd_inputs = []
    env_header = "#!/bin/bash\nset -euo pipefail\n" + "\n".join(env_lines) + "\n\n"

    if ctx.file.cmd_file:
        cmd_inputs.append(ctx.file.cmd_file)
        ctx.actions.run_shell(
            inputs = [ctx.file.cmd_file],
            outputs = [script_file],
            command = """cat > "{out}" <<'EOF'
{env_header}
EOF
cat "{cmd_file}" >> "{out}"
chmod +x "{out}"
""".format(
                out = script_file.path,
                env_header = env_header,
                cmd_file = ctx.file.cmd_file.path,
            ),
        )
    else:
        user_cmd = ctx.attr.cmd or ""
        ctx.actions.write(
            output = script_file,
            content = env_header + user_cmd + "\n",
            is_executable = True,
        )

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = wrapper_script_file,
        substitutions = {
            "{sysroot_dir}": sysroot_path,
            "{helper_abs_path}": chroot_helper_path,
            "{script_file_build_path}": script_file.path,
            "{script_file_run_path}": script_file.short_path,
            "{label}": ctx.label.name,
            "{output_path}": output.path,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        inputs = [script_file, wrapper_script_file, ctx.file.chroot_helper] +
                 ctx.files.data +
                 toolchain_files +
                 cmd_inputs +
                 depset(transitive = [d.files for d in ctx.attr.deps]).to_list(),
        outputs = [output],
        command = "bash {}".format(wrapper_script_file.path),
        mnemonic = "LfsChrootCommand",
        progress_message = "Executing chroot command: {}".format(ctx.label.name),
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    # Create a runnable script that can be executed with 'bazel run'
    # This re-runs the chroot command and shows output
    ctx.actions.write(
        output = runnable_script,
        content = """#!/bin/bash
# Runnable wrapper for {label}
# This script re-executes the chroot command and displays output

set -euo pipefail

# Bazel provides runfiles - find the wrapper script
if [[ -n "${{RUNFILES_DIR:-}}" ]]; then
    WRAPPER_SCRIPT="$RUNFILES_DIR/_main/{wrapper_path}"
elif [[ -n "${{RUNFILES_MANIFEST_FILE:-}}" ]]; then
    WRAPPER_SCRIPT=$(grep -F " _main/{wrapper_path} " "$RUNFILES_MANIFEST_FILE" | cut -d' ' -f1)
else
    # Fallback: assume we're in the workspace
    SCRIPT_DIR=$(cd "$(dirname "${{BASH_SOURCE[0]}}")" && pwd)
    WORKSPACE_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
    WRAPPER_SCRIPT="$WORKSPACE_ROOT/{wrapper_path}"
fi

if [[ ! -f "$WRAPPER_SCRIPT" ]]; then
    echo "Error: Cannot find wrapper script: $WRAPPER_SCRIPT" >&2
    echo "RUNFILES_DIR=${{RUNFILES_DIR:-<not set>}}" >&2
    echo "PWD=$(pwd)" >&2
    exit 1
fi

# Execute the wrapper script
exec bash "$WRAPPER_SCRIPT"
""".format(
            label = ctx.label.name,
            wrapper_path = wrapper_script_file.short_path,
        ),
        is_executable = True,
    )

    return [DefaultInfo(
        files = depset([output]),
        executable = runnable_script,
        runfiles = ctx.runfiles(files = [script_file, wrapper_script_file, ctx.file.chroot_helper] +
                                        ctx.files.data +
                                        toolchain_files +
                                        depset(transitive = [d.files for d in ctx.attr.deps]).to_list()),
    )]

lfs_chroot_command = rule(
    implementation = _lfs_chroot_command_impl,
    doc = """
    Executes a shell command inside the LFS chroot environment.

    This rule uses the privileged chroot helper script to set up and execute
    commands inside the chroot. It handles mounting virtual filesystems and
    setting a clean environment.

    Example:
        ```python
        lfs_chroot_command(
            name = "build_package",
            cmd = \"\"\"
                cd /sources/package-1.0
                ./configure --prefix=/usr
                make
                make install
            \"\"\",
            lfs_sysroot = "//:lfs_sysroot_files",
            deps = ["//packages/chapter_06:all_temp_tools"],
            tags = ["manual", "requires-sudo"],
        )
        ```

    Important: Requires sudo access to the chroot helper script.
    """,
    attrs = {
        "cmd": attr.string(
            doc = "The shell commands to execute inside the chroot.",
            mandatory = False,
        ),
        "cmd_file": attr.label(
            doc = "File containing commands to execute inside the chroot (exclusive with cmd).",
            allow_single_file = True,
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
            mandatory = False,
            default = "//tools/scripts:lfs_chroot_helper_script",
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
            default = "//tools/scripts:lfs_chroot_command_wrapper_template",
            allow_single_file = True,
        ),
    },
    executable = True,
)

def _lfs_sysroot_stage_files_impl(ctx):
    """Stage host files into the sysroot using the privileged chroot helper.

    This is used for Chapter 7 source staging because the sysroot becomes
    root-owned during chroot preparation, making unprivileged host-side copies
    impossible.

    Args:
        ctx: Rule context with source files and destination

    Returns:
        DefaultInfo with done marker
    """
    sysroot_path = "sysroot"
    chroot_helper_path = ctx.file.chroot_helper.short_path

    output = ctx.actions.declare_file(ctx.label.name + ".done")
    wrapper_script_file = ctx.actions.declare_file(ctx.label.name + "_wrapper.sh")

    if not ctx.files.srcs:
        fail("{}: specify at least one src".format(ctx.label))

    src_paths = "\n".join(['  "{}"'.format(f.path) for f in ctx.files.srcs])

    ctx.actions.expand_template(
        template = ctx.file._wrapper_template,
        output = wrapper_script_file,
        substitutions = {
            "{sysroot_dir}": sysroot_path,
            "{helper_abs_path}": chroot_helper_path,
            "{dest_rel}": ctx.attr.dest_rel,
            "{src_paths}": src_paths,
            "{label}": ctx.label.name,
            "{output_path}": output.path,
        },
        is_executable = True,
    )

    ctx.actions.run_shell(
        inputs = [wrapper_script_file, ctx.file.chroot_helper] +
                 ctx.files.srcs +
                 depset(transitive = [d.files for d in ctx.attr.deps]).to_list(),
        outputs = [output],
        command = "bash {}".format(wrapper_script_file.path),
        mnemonic = "LfsSysrootStageFiles",
        progress_message = "Staging files into sysroot: {}".format(ctx.label.name),
        execution_requirements = {
            "no-sandbox": "1",
        },
    )

    return [DefaultInfo(
        files = depset([output]),
    )]

lfs_sysroot_stage_files = rule(
    implementation = _lfs_sysroot_stage_files_impl,
    doc = """Copies host files into sysroot/<dest_rel> via the sudo allowlisted helper.

    Used for staging source tarballs and other files into the sysroot when the
    sysroot directory is owned by root.

    Example:
        ```python
        lfs_sysroot_stage_files(
            name = "stage_sources",
            srcs = ["@perl_src//file", "@python_src//file"],
            dest_rel = "sources",
            lfs_sysroot = "//:lfs_sysroot_files",
        )
        ```
    """,
    attrs = {
        "srcs": attr.label_list(
            doc = "Files to copy into sysroot/<dest_rel> (copied by basename).",
            allow_files = True,
            mandatory = True,
        ),
        "dest_rel": attr.string(
            doc = "Destination directory relative to sysroot (default: sources).",
            default = "sources",
        ),
        "lfs_sysroot": attr.label(
            doc = "The label of the filegroup representing the LFS sysroot directory.",
            allow_files = True,
            mandatory = True,
        ),
        "chroot_helper": attr.label(
            doc = "The label of the filegroup representing the lfs-chroot-helper.sh script.",
            allow_single_file = True,
            mandatory = False,
            default = "//tools/scripts:lfs_chroot_helper_script",
        ),
        "deps": attr.label_list(
            doc = "Other targets that must complete before staging runs.",
            default = [],
        ),
        "_wrapper_template": attr.label(
            default = "//tools/scripts:lfs_sysroot_stage_files_wrapper_template",
            allow_single_file = True,
        ),
    },
)

def lfs_chroot_step(
        name,
        cmd = None,
        cmd_file = None,
        toolchain = None,
        env = {},
        lfs_sysroot = "//:lfs_sysroot_files",
        chroot_helper = "//tools/scripts:lfs_chroot_helper_script",
        tags = [],
        **kwargs):
    """
    Macro wrapper for lfs_chroot_command with sane defaults.

    Provides convenient defaults for common chroot operations. Automatically
    adds manual and requires-sudo tags.

    Example:
        ```python
        lfs_chroot_step(
            name = "install_gettext",
            cmd_file = ":install_gettext.sh",
            deps = [":extract_gettext"],
        )
        ```

    Args:
        name: Target name
        cmd: Inline command string (exclusive with cmd_file)
        cmd_file: Command script file (exclusive with cmd)
        toolchain: LfsToolchainInfo provider (default: auto-detected)
        env: Additional environment variables
        lfs_sysroot: Sysroot filegroup label
        chroot_helper: Chroot helper script label
        tags: Additional tags (manual/requires-sudo added automatically)
        **kwargs: Additional arguments passed to lfs_chroot_command
    """
    merged_tags = ["manual", "requires-sudo"] + tags
    resolved_toolchain = toolchain if toolchain else default_package_toolchain()
    lfs_chroot_command(
        name = name,
        cmd = cmd,
        cmd_file = cmd_file,
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
    Uses the chroot_extract_tarball.sh script to perform the extraction.

    Example:
        ```python
        lfs_chroot_extract_tarball(
            name = "extract_perl",
            tarball_name = "perl-5.40.0.tar.xz",
            deps = [":stage_ch7_sources"],
        )
        ```

    Args:
      name: Target name
      tarball_name: Name of the tarball file (e.g., "perl-5.40.0.tar.xz")
      dest: Destination directory (default: /sources)
      toolchain: LfsToolchainInfo provider (default: auto-detected)
      env: Additional environment variables
      tags: Build tags
      **kwargs: Additional arguments passed to lfs_chroot_step
    """
    env_vars = dict(env)
    env_vars.update({
        "TARBALL_NAME": tarball_name,
        "TARBALL_DEST": dest,
    })

    lfs_chroot_step(
        name = name,
        cmd_file = "//tools/scripts:chroot_extract_tarball_script",
        toolchain = toolchain,
        env = env_vars,
        tags = tags,
        **kwargs
    )
