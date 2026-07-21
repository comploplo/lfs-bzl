# 🔧 LFS Bazel Build Tools Documentation

**Location:** `src/tools/`
**Purpose:** Custom Starlark rules and providers for building LFS packages with Bazel

This directory implements the "bridge" between Bazel's dependency management and LFS's traditional shell-based build system.

## 📑 Quick Navigation

- [Philosophy](#philosophy-managed-chaos)
- [Providers](#1-providers-providersbzl)
- [Build Rules](#2-build-rules-lfs_buildbzl)
  - [lfs_package](#lfs_package-rule)
  - [lfs_c_binary](#lfs_c_binary-macro)
  - [lfs_configure_make](#lfs_configure_make-macro)
  - [lfs_autotools](#lfs_autotools-macro)
  - [lfs_script](#lfs_script-macro)
- [Chroot Builds (Podman Worker)](#chroot-builds-podman-worker)
- [Environment Variables](#environment-variables-reference)
- [Examples](#file-layout-in-build-files)
- [Debugging](#debugging)

______________________________________________________________________

## 📁 Files Overview

| File / Dir | Purpose |
| -------------------- | -------------------------------------------------------------------------------- |
| `BUILD` | Package marker and exported `.bzl` entrypoints |
| `providers.bzl` | `LfsToolchainInfo` provider |
| `lfs_package.bzl` | Core `lfs_package` rule (Podman container and chroot modes) |
| `lfs_toolchain.bzl` | `lfs_toolchain` rule + default toolchain selection |
| `lfs_macros.bzl` | Convenience macros (`lfs_autotools`, `lfs_c_binary`, etc.) |
| `lfs_defaults.bzl` | Phase presets for configure/make/install defaults |
| `scripts/` | Shell helpers and utility scripts |
| `scripts/templates/` | All template scripts expanded by Starlark rules (build, runner, worker) |
| `podman/` | Rootless Podman worker used by every build phase (no sudo required) |

______________________________________________________________________

## 🎭 Philosophy: "Managed Chaos"

These rules implement our hybrid approach:

- **Bazel's Role:** Dependency tracking, caching, and scheduling
- **Rule's Role:** Set up LFS environment, execute traditional build commands

**Key Principle:** We don't force LFS into "pure" Bazel semantics. Instead, we use Bazel as a workflow orchestrator that respects LFS's traditional build patterns.

______________________________________________________________________

## 1. 📦 Providers (`providers.bzl`)

### `LfsToolchainInfo`

Custom provider that carries toolchain configuration between build targets.

**Fields:**

- `bin_path` (string): Path to prepend to `$PATH`
- `env` (dict): Environment variables to export

**Use Cases (consumed via `lfs_toolchain` rule):**

1. **Cross-Compiler Phase (Chapter 5):** Pass the newly-built cross-compiler to subsequent builds
1. **Temporary Tools Phase (Chapter 6):** Use the cross-compiled temporary tools
1. **Final System Phase (Chapter 7+):** Build inside chroot with full toolchain

**Example:**

```python
# Define a toolchain after building GCC Pass 1
# ($LFS_TGT is $(uname -m)-lfs-linux-gnu, e.g. aarch64-lfs-linux-gnu)
lfs_toolchain(
    name = "cross_toolchain",
    bin_path = "$LFS/tools/bin",
    env = {
        "CC": "$LFS_TGT-gcc",
        "CXX": "$LFS_TGT-g++",
    },
)

# Use it in subsequent builds
lfs_package(
    name = "glibc",
    srcs = ["@glibc//file"],
    configure_cmd = "./configure --prefix=/tools",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
    toolchain = ":cross_toolchain",  # Injects the custom toolchain
)
```

`lfs_toolchain` is defined in `lfs_toolchain.bzl`.

______________________________________________________________________

<a id="2-build-rules-lfs_buildbzl"></a>

## 2. 🏗️ Build Rules (`lfs_*.bzl`)

Load each rule or macro directly from the module that defines it:

```python
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_macros.bzl", "lfs_autotools", "lfs_configure_make", "lfs_c_binary")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")
load("//tools:lfs_script.bzl", "lfs_script")
```

### `lfs_package` (Rule)

The core rule that handles standard LFS package builds.

#### Attributes

| Attribute | Type | Required | Default | Description |
| -------------------- | ----------- | -------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name` | string | Yes | - | Target name |
| `srcs` | label_list | No | `[]` | Source files (tarballs or individual files) |
| `patches` | label_list | No | `[]` | Patch files applied with `patch -Np1` |
| `configure_cmd` | string | No | `None` | Configure command to run |
| `configure_cmd_file` | label | No | `None` | File containing configure commands (exclusive with `configure_cmd`) |
| `build_cmd` | string | No | `None` | Build command (typically `make`) |
| `build_cmd_file` | label | No | `None` | File containing build commands (exclusive with `build_cmd`) |
| `install_cmd` | string | No | `None` | Install command (typically `make install`) |
| `install_cmd_file` | label | No | `None` | File containing install commands (exclusive with `install_cmd`) |
| `phase` | string | No | `None` | Build phase: `"chroot"` uses worker chroot mode; other phases use worker container mode |
| `toolchain` | label | No | `None` | LfsToolchainInfo provider to inject |
| `deps` | label_list | No | `[]` | Other `lfs_package` targets that must finish first |
| `env` | string_dict | No | `{}` | Extra environment variables to export |
| `binary_name` | string | No | - | Binary name in `$LFS/tools/bin/` for executable targets (set `create_runner = True` to emit a runner; defaults to label name when runner requested) |
| `create_runner` | bool | No | `False` | Emit a runner script (uses `binary_name` if set, else the target label) |

#### Behavior

**Build Process:**

1. **Environment Setup**

   - Sets `$LFS` to `sysroot/`
   - Sets `$LC_ALL=POSIX`
   - Sets `$LFS_TGT=$(uname -m)-lfs-linux-gnu` (e.g. `aarch64-lfs-linux-gnu`)
   - Prepends `$LFS/tools/bin` to `$PATH`
   - Optionally injects custom toolchain environment

1. **Source Handling**

   - Supports multiple tarballs/files; tarballs auto-extract, files copy in place
   - Optional patches applied with `patch -Np1` after extraction

1. **Build Phases & Logging**

   - Runs in temporary directory (`mktemp -d`)
   - Streams stdout/stderr to `tracker/logs/<target>.log`
   - Executes: configure/build/install via inline strings *or* `*_cmd_file` scripts (files run with `bash` in the same working directory/environment)
   - Cleans up temp directory on exit

1. **Outputs**

   - Creates `<name>.done` marker file (for dependency tracking)
   - Installs artifacts to `sysroot/` (outside Bazel sandbox)
   - If `create_runner` is set: Creates executable runner script (uses `binary_name` if provided, otherwise the target name)

**Execution Requirements:**

- `no-sandbox`: Disabled to allow writing to `sysroot/` directory
- Runs with `set -euo pipefail` (exits on error)

#### Examples

**Simple Binary Build:**

```python
lfs_package(
    name = "hello",
    srcs = ["hello.c"],
    build_cmd = "gcc hello.c -o hello",
    install_cmd = "install -D hello $LFS/tools/bin/hello",
)
```

**Standard Autotools Package:**

```python
lfs_package(
    name = "binutils_pass1",
    srcs = ["@binutils//file"],
    configure_cmd = "./configure --prefix=/tools --with-sysroot=$LFS --target=$LFS_TGT",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
)
```

**With Custom Toolchain (Chapter 6):**

```python
lfs_package(
    name = "glibc",
    srcs = ["@glibc//file"],
    configure_cmd = "./configure --prefix=/usr --host=$LFS_TGT --build=$(../scripts/config.guess)",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make DESTDIR=$LFS install",
    toolchain = "//packages/chapter_05:cross_toolchain",
)
```

**Chroot Build (Chapter 7+):**

```python
lfs_package(
    name = "python",
    phase = "chroot",  # Triggers rootless Podman worker
    srcs = ["@python_src//file"],
    configure_cmd = "./configure --prefix=/usr --enable-shared --without-ensurepip",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
    deps = [":chroot_prepare"],
)
```

**Non-Executable Target (no binary output):**

```python
lfs_package(
    name = "linux_headers",
    srcs = ["@linux//file"],
    build_cmd = "make mrproper",
    install_cmd = "make headers && cp -rv usr/include $LFS/usr",
)
```

#### Executable Support

By default, `lfs_package` does **not** create a runner. Set `create_runner = True`
to emit a wrapper that allows:

```bash
bazel run //packages/hello_world:hello
```

**How It Works (Container-Mode Builds - Chapters 5-6):**

1. Creates a bash wrapper script at `bazel-bin/packages/hello_world/hello`
1. Script finds workspace root using `$BUILD_WORKSPACE_DIRECTORY` or walking up the directory tree
1. Executes `$WORKSPACE_ROOT/sysroot/tools/bin/<binary_name>` with arguments passed through

**How It Works (Chroot Builds - Chapters 7-8+):**

1. Creates a bash wrapper script that displays the build log
1. When you run `bazel run //packages/hello_world:hello_final`, it shows the chroot build output
1. The log file is located at `bazel-bin/packages/hello_world/hello_final.log`

**Example:**

```bash
$ bazel run //packages/hello_world:hello_final
=== Build output for @@//packages/hello_world:hello_final ===

Configuring hello_final...
Building hello_final...
Hello from LFS Final System (Chapter 8)!
Built with native GCC from the complete LFS toolchain.
Installing hello_final to /...
Successfully built hello_final
```

**To enable:** Add `create_runner = True` (optionally set `binary_name` to override
the script/binary name). Leave it unset for non-executable targets.

______________________________________________________________________

### `lfs_c_binary` (Macro)

Helper for simple C/C++-style builds using `$CC/$CXX` or `make`.
Emits a runner by default (same as `bazel run`) unless you override via
`create_runner` in `**kwargs`.

**Arguments**

- `name` (string, required)
- `srcs` (label_list, required): source files
- `toolchain` (label, optional): LfsToolchainInfo provider
- `prefix` (string, optional, default `/tools`): install prefix
- `binary_name` (string, optional): overrides output binary name
- `copts` / `ldopts` (list, optional): compiler/linker flags (direct compile path)
- `make_targets` (list, optional): if set, runs `make -j$(nproc) <targets>` and installs the resulting binary

If `make_targets` is empty, `lfs_c_binary` compiles `srcs` directly with `$CC`
and installs to `$LFS<prefix>/bin/<binary_name>`.

______________________________________________________________________

### `lfs_configure_make` (Macro)

Helper for the common out-of-tree `./configure && make && make install` flow.
Builds in `<build_subdir>` (default `build`) with parallel make and optional `DESTDIR`.

**Arguments**

- `name`, `srcs` (required)
- `configure_flags` (list, optional): appended to `../configure --prefix=<prefix>`
- `make_targets` (list, optional): if empty, runs default `make -j$(nproc)`
- `install_targets` (list, optional): defaults to `["install"]`
- `prefix` (string, default `/tools`)
- `destdir` (string, optional): if set, prepends `DESTDIR=<value>` to install step
- `toolchain` (optional `LfsToolchainInfo`)
- `build_subdir` (string, default `build`)
- `**kwargs` forwarded to `lfs_package` (deps, patches, env, binary_name, etc.)

______________________________________________________________________

### `lfs_autotools` (Macro)

Declarative wrapper that uses phase presets from `lfs_defaults.bzl` to avoid
long heredocs. Choose a phase (`"ch5"`, `"ch6"`, `"ch7"`) and provide only the
deltas (configure flags, make targets, install targets); it generates
configure/build/install commands with out-of-tree builds.

Each phase preset sets sensible defaults: prefix, destdir, build subdir, and
`-j$(nproc)` make flags.

Example:

```python
load("//tools:lfs_macros.bzl", "lfs_autotools")

lfs_autotools(
    name = "binutils_pass1",
    srcs = ["@binutils_src//file"],
    phase = "ch5",
    configure_flags = [
        "--with-sysroot=$LFS",
        "--target=$LFS_TGT",
        "--disable-nls",
        "--enable-gprofng=no",
        "--disable-werror",
    ],
)
```

______________________________________________________________________

### `lfs_script` (Macro)

A wrapper around `lfs_package` designed for executing arbitrary scripts in the LFS environment (e.g., for configuration, file creation, or cleanup).

**Arguments**

- `name` (string, required)
- `script` (string, required): The script content to execute.
- `srcs` (label_list, optional): Source files available to the script.
- `phase` (string, optional, default `"chroot"`): Build phase.
- `deps` (label_list, optional): Dependencies.
- `**kwargs`: Forwarded to `lfs_package`.

**Example**

```python
load("//tools:lfs_script.bzl", "lfs_script")

lfs_script(
    name = "create_hosts",
    script = """
        cat > /etc/hosts << "EOF"
127.0.0.1 localhost
EOF
    """,
)
```

______________________________________________________________________

## 🐳 Chroot Builds (Podman Worker)

**For Chapter 7+ builds**, use `lfs_package` with `phase="chroot"` to build inside a rootless Podman container.

### How It Works

1. **Set `phase="chroot"`** in your `lfs_package` target
1. Build triggers the rootless Podman worker (no sudo required!)
1. Worker creates a container that:
   - Mounts sysroot at `/lfs`
   - Mounts virtual filesystems (`/dev`, `/proc`, `/sys`, `/run`)
   - Runs as root inside container namespace (regular user on host)
1. Package builds inside chroot using temporary tools from Chapter 6

### Example

```python
lfs_package(
    name = "perl",
    phase = "chroot",  # This triggers Podman worker
    srcs = ["@perl_src//file"],
    configure_cmd = "./Configure -des -Dprefix=/usr ...",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
    deps = [":chroot_prepare"],
)
```

### Benefits

- ✅ **No sudo required** - Entire build runs as regular user
- ✅ **Network isolation** - Builds run with `--network=none`
- ✅ **Persistent worker** - Container stays alive across builds for performance
- ✅ **Serialized mutation** - One worker instance protects the shared sysroot

### Requirements

- Rootless Podman 3.0+ configured
- Test with: `podman run --rm hello-world`

______________________________________________________________________

## 🔐 Environment Variables Reference

The rules automatically set these environment variables:

| Variable | Value | Purpose |
| ----------- | ---------------------- | ------------------------------------------------------- |
| `$LFS` | `sysroot/` | Root of the LFS system being built (workspace-relative) |
| `$LC_ALL` | `POSIX` | Consistent locale for builds |
| `$LFS_TGT` | `$(uname -m)-lfs-linux-gnu` | Target triplet for cross-compilation (e.g. `aarch64-lfs-linux-gnu`) |
| `$PATH` | `$LFS/tools/bin:$PATH` | Find LFS tools before host tools |
| `$EXECROOT` | `$(pwd)` | Bazel execution root (for finding inputs) |
| `$WORK_DIR` | `$(mktemp -d)` | Temporary build directory |

**Toolchain Variables (if `toolchain` attribute provided):**

- Any custom `env` fields from `LfsToolchainInfo`
- `$PATH` is **overridden** with `toolchain.bin_path:$PATH`

______________________________________________________________________

## 🔗 Dependency Tracking

**Marker Files:**

- Each `lfs_package` target produces `<name>.done` marker file
- Used by Bazel to track completion and dependencies

**Example Dependency Chain:**

```python
lfs_package(
    name = "binutils_pass1",
    srcs = ["@binutils//file"],
    configure_cmd = "...",
    build_cmd = "...",
    install_cmd = "...",
)

lfs_package(
    name = "gcc_pass1",
    srcs = ["@gcc//file"],
    deps = [":binutils_pass1"],  # Wait for binutils to complete
    configure_cmd = "...",
    build_cmd = "...",
    install_cmd = "...",
)
```

Bazel ensures `binutils_pass1` completes before `gcc_pass1` starts.

______________________________________________________________________

## 📄 File Layout in BUILD Files

Recommended structure for package BUILD files:

```python
# Load the rules
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_macros.bzl", "lfs_autotools", "lfs_c_binary")

# Simple autotools package
lfs_autotools(
    name = "m4",
    srcs = ["@m4_src//file"],
    phase = "ch6",
    configure_flags = ["--host=$LFS_TGT"],
)

# Custom build (non-autotools)
lfs_package(
    name = "custom_pkg",
    srcs = ["@custom//file"],
    build_cmd = "make -f Makefile.custom",
    install_cmd = "make -f Makefile.custom install PREFIX=$LFS/tools",
)

# Toolchain definition (for Phase 3+)
lfs_toolchain(
    name = "cross_toolchain",
    bin_path = "$LFS/tools/bin",
    env = {
        "CC": "$LFS_TGT-gcc",
        "CXX": "$LFS_TGT-g++",
    },
)

# Simple C binary using $CC/$CXX (with optional make targets)
lfs_c_binary(
    name = "hello_from_macro",
    srcs = ["hello.c"],
    toolchain = "//packages/chapter_05:cross_toolchain",
)
```

______________________________________________________________________

## 🚧 Limitations & Future Work

### Current Limitations

1. **Shared Mutable Sysroot:** All phases write outside Bazel's sandbox to `sysroot/`

   - **Impact:** Remote execution is unavailable, and marker files must remain in sync with the sysroot
   - **Mitigation:** All phases run in Podman, and `.bazelrc` limits builds to one worker instance

1. **Binary Name Assumption:** Assumes binaries install to `$LFS/tools/bin/` or `$LFS/usr/bin/`

   - **Impact:** Libraries and headers should leave `create_runner` unset

1. **Logs in Execroot:** Build logs are written to `bazel-out/lfs-logs/` inside the Bazel execroot, not the workspace.

   - **Impact:** Logs are transient unless copied out.
   - **Mitigation:** View with `cat bazel-out/lfs-logs/<package>.log`

### Recent Enhancements

- [x] ✅ Rootless Podman worker for all phases (no sudo required!)
- [x] ✅ Persistent JSON worker protocol (container stays alive across builds)
- [x] ✅ Network isolation (`--network=none` for chroot builds)
- [x] ✅ Single-worker serialization for shared-sysroot safety

### Future Enhancements

- [ ] Mirror build logs into workspace (currently in execroot `bazel-out/lfs-logs/`)
- [ ] Better output capturing and logging
- [ ] Remote execution support for sandboxed builds

______________________________________________________________________

## 🧪 Testing

Verify the rules work with the hello world test:

```bash
# Build
bazel build //packages/hello_world:hello_cross

# Run
bazel run //packages/hello_world:hello_cross

# Check output
ls -l sysroot/tools/bin/hello
./sysroot/tools/bin/hello
```

**Expected Output:**

```
Hello from LFS Bazel Bootstrap!
Build system is working correctly.
```

______________________________________________________________________

## 🐛 Debugging

### View Generated Build Script

Add `--subcommands` to see the actual shell commands:

```bash
bazel build //packages/hello_world:hello_cross --subcommands
```

### Force Rebuild

```bash
bazel clean
bazel build //packages/hello_world:hello_cross
```

### Check Marker Files

```bash
ls -l bazel-bin/packages/hello_world/hello_cross.done
```

______________________________________________________________________

## 📖 Appendix: Related Documentation

- **[DESIGN.md](../DESIGN.md)** - Architecture and "Managed Chaos" philosophy
- **[docs/status.md](status.md)** - Build progress tracker
- **[LFS Book 13.0-systemd](https://www.linuxfromscratch.org/lfs/view/13.0-systemd/)** - Official build instructions
- **[Bazel Rules Tutorial](https://bazel.build/rules/rules-tutorial)** - Creating custom rules
