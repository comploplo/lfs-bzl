# 🔧 LFS Bazel Build Tools Documentation

**Location:** `src/tools/`
**Purpose:** Custom Starlark rules and providers for building LFS packages with Bazel

This directory implements the "bridge" between Bazel's dependency management and LFS's traditional shell-based build system.

## 📑 Quick Navigation

- [Philosophy](#philosophy-managed-chaos)
- [Providers](#1-providers-providersbzl)
- [Build Rules](#2-build-rules-lfs_buildbzl)
  - [lfs_package](#lfs_package-rule)
  - [lfs_autotools_package](#lfs_autotools_package-macro)
  - [lfs_c_binary](#lfs_c_binary-macro)
  - [lfs_configure_make](#lfs_configure_make-macro)
  - [lfs_autotools / lfs_plain_make](#lfs_autotools--lfs_plain_make-macros)
- [Chroot Builds (Podman Worker)](#chroot-builds-podman-worker)
- [Environment Variables](#environment-variables-reference)
- [Examples](#file-layout-in-build-files)
- [Debugging](#debugging)

______________________________________________________________________

## 📁 Files Overview

| File / Dir           | Purpose                                                                          |
| -------------------- | -------------------------------------------------------------------------------- |
| `BUILD`              | Package marker and exported `.bzl` entrypoints                                   |
| `providers.bzl`      | `LfsToolchainInfo` provider                                                      |
| `lfs_build.bzl`      | Backward-compatible re-export module (loads and re-exports everything)           |
| `lfs_package.bzl`    | Core `lfs_package` rule (supports both host builds and Podman worker for chroot) |
| `lfs_toolchain.bzl`  | `lfs_toolchain` rule + default toolchain selection                               |
| `lfs_macros.bzl`     | Convenience macros (`lfs_autotools`, `lfs_c_binary`, etc.)                       |
| `lfs_defaults.bzl`   | Phase presets for configure/make/install defaults                                |
| `scripts/`           | Shell helpers and generated-script templates                                     |
| `scripts/templates/` | Template scripts expanded by Starlark rules                                      |
| `podman/`            | Rootless Podman worker for Chapter 7+ chroot builds (no sudo required)           |

______________________________________________________________________

## 🎭 Philosophy: "Managed Chaos"

These rules implement our hybrid approach:

- **Bazel's Role:** Dependency tracking, caching, parallelization
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
lfs_toolchain(
    name = "cross_toolchain",
    bin_path = "$LFS/tools/bin",
    env = {
        "CC": "x86_64-lfs-linux-gnu-gcc",
        "CXX": "x86_64-lfs-linux-gnu-g++",
        "LFS_TGT": "x86_64-lfs-linux-gnu",
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

`lfs_toolchain` is defined in `lfs_toolchain.bzl` and re-exported from
`lfs_build.bzl` for backward compatibility.

______________________________________________________________________

<a id="2-build-rules-lfs_buildbzl"></a>

## 2. 🏗️ Build Rules (`lfs_build.bzl` and `lfs_*.bzl`)

`lfs_build.bzl` is the compatibility entrypoint: it re-exports rules/macros from
the modular implementation so existing BUILD files can keep using:

```python
load("//tools:lfs_build.bzl", "lfs_package", "lfs_autotools", "lfs_toolchain")
```

For more explicit imports, load from the specific module:

```python
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_macros.bzl", "lfs_autotools")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")
load("//tools:lfs_chroot.bzl", "lfs_chroot_command")
```

### `lfs_package` (Rule)

The core rule that handles standard LFS package builds.

#### Attributes

| Attribute            | Type        | Required | Default | Description                                                                                                                                         |
| -------------------- | ----------- | -------- | ------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`               | string      | Yes      | -       | Target name                                                                                                                                         |
| `srcs`               | label_list  | No       | `[]`    | Source files (tarballs or individual files)                                                                                                         |
| `patches`            | label_list  | No       | `[]`    | Patch files applied with `patch -Np1`                                                                                                               |
| `configure_cmd`      | string      | No       | `None`  | Configure command to run                                                                                                                            |
| `configure_cmd_file` | label       | No       | `None`  | File containing configure commands (exclusive with `configure_cmd`)                                                                                 |
| `build_cmd`          | string      | No       | `None`  | Build command (typically `make`)                                                                                                                    |
| `build_cmd_file`     | label       | No       | `None`  | File containing build commands (exclusive with `build_cmd`)                                                                                         |
| `install_cmd`        | string      | No       | `None`  | Install command (typically `make install`)                                                                                                          |
| `install_cmd_file`   | label       | No       | `None`  | File containing install commands (exclusive with `install_cmd`)                                                                                     |
| `phase`              | string      | No       | `None`  | Build phase: `"chroot"` triggers rootless Podman worker (Chapter 7+), otherwise builds on host                                                      |
| `toolchain`          | label       | No       | `None`  | LfsToolchainInfo provider to inject                                                                                                                 |
| `deps`               | label_list  | No       | `[]`    | Other `lfs_package` targets that must finish first                                                                                                  |
| `env`                | string_dict | No       | `{}`    | Extra environment variables to export                                                                                                               |
| `binary_name`        | string      | No       | -       | Binary name in `$LFS/tools/bin/` for executable targets (set `create_runner = True` to emit a runner; defaults to label name when runner requested) |
| `create_runner`      | bool        | No       | `False` | Emit a runner script (uses `binary_name` if set, else the target label)                                                                             |

#### Behavior

**Build Process:**

1. **Environment Setup**

   - Sets `$LFS` to `sysroot/`
   - Sets `$LC_ALL=POSIX`
   - Sets `$LFS_TGT=x86_64-lfs-linux-gnu`
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

**How It Works:**

1. Creates a bash wrapper script at `bazel-bin/packages/hello_world/hello`
1. Script finds workspace root using `$BUILD_WORKSPACE_DIRECTORY` or walking up the directory tree
1. Executes `$WORKSPACE_ROOT/sysroot/tools/bin/<binary_name>` with arguments passed through

**To enable:** Add `create_runner = True` (optionally set `binary_name` to override
the script/binary name). Leave it unset for non-executable targets.

______________________________________________________________________

### `lfs_autotools_package` (Macro)

Convenience macro for standard autotools packages (90% of LFS packages).

#### Arguments

| Argument          | Type           | Required | Default    | Description                                   |
| ----------------- | -------------- | -------- | ---------- | --------------------------------------------- |
| `name`            | string         | Yes      | -          | Target name                                   |
| `srcs`            | label_list     | Yes      | -          | Source tarball                                |
| `prefix`          | string         | No       | `"/tools"` | Install prefix                                |
| `configure_flags` | list\[string\] | No       | `[]`       | Additional configure flags                    |
| `make_flags`      | list\[string\] | No       | `[]`       | Additional make flags (default: `-j$(nproc)`) |
| `**kwargs`        | -              | No       | -          | Additional args passed to `lfs_package`       |

#### Example

Instead of writing:

```python
lfs_package(
    name = "m4",
    srcs = ["@m4//file"],
    configure_cmd = "./configure --prefix=/tools --host=$LFS_TGT",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
)
```

You can write:

```python
lfs_autotools_package(
    name = "m4",
    srcs = ["@m4//file"],
    configure_flags = ["--host=$LFS_TGT"],
)
```

**Generated Commands:**

- `configure_cmd`: `./configure --prefix=/tools --host=$LFS_TGT`
- `build_cmd`: `make -j$(nproc)`
- `install_cmd`: `make install`

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

### `lfs_autotools` / `lfs_plain_make` (Macros)

Declarative wrappers that use phase presets from `lfs_defaults.bzl` to avoid
long heredocs. Choose a phase (`"ch5"`, `"ch6"`, `"ch7"`) and provide only the
deltas (configure flags, make targets, install targets).

- `lfs_autotools`: generates configure/build/install commands with out-of-tree builds.
- `lfs_plain_make`: for packages that only need make + install.

Each phase preset sets sensible defaults: prefix, destdir, build subdir, and
`-j$(nproc)` make flags.

Example:

```python
load("//tools:lfs_build.bzl", "lfs_autotools")

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
- ✅ **Parallel builds** - Multiple packages can build simultaneously

### Requirements

- Rootless Podman 3.0+ configured
- Test with: `podman run --rm hello-world`

______________________________________________________________________

## 🗑️ Deprecated: Sudo-Based Chroot Rules

**DEPRECATED:** The following rules are legacy and should not be used for new code. Use `lfs_package` with `phase="chroot"` instead.

<details>
<summary>Click to expand deprecated chroot rules (for reference only)</summary>

### `lfs_chroot_command` (Rule) - DEPRECATED

**Use `lfs_package` with `phase="chroot"` instead.**

Legacy sudo-based rule for running commands inside chroot. Replaced by rootless Podman worker.

### `lfs_chroot_step` (Macro) - DEPRECATED

**Use `lfs_package` with `phase="chroot"` instead.**

Legacy wrapper around `lfs_chroot_command`. Requires sudo.

### `lfs_chroot_extract_tarball` (Macro) - DEPRECATED

**Not needed with `lfs_package`** - tarballs are extracted automatically.

</details>

______________________________________________________________________

## 🔐 Environment Variables Reference

The rules automatically set these environment variables:

| Variable    | Value                  | Purpose                                                 |
| ----------- | ---------------------- | ------------------------------------------------------- |
| `$LFS`      | `sysroot/`             | Root of the LFS system being built (workspace-relative) |
| `$LC_ALL`   | `POSIX`                | Consistent locale for builds                            |
| `$LFS_TGT`  | `x86_64-lfs-linux-gnu` | Target triplet for cross-compilation                    |
| `$PATH`     | `$LFS/tools/bin:$PATH` | Find LFS tools before host tools                        |
| `$EXECROOT` | `$(pwd)`               | Bazel execution root (for finding inputs)               |
| `$WORK_DIR` | `$(mktemp -d)`         | Temporary build directory                               |

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
load("//tools:lfs_build.bzl", "lfs_package", "lfs_autotools_package", "lfs_c_binary")

# Simple autotools package
lfs_autotools_package(
    name = "m4",
    srcs = ["@m4//file"],
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
        "CC": "x86_64-lfs-linux-gnu-gcc",
        "CXX": "x86_64-lfs-linux-gnu-g++",
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

1. **No Sandbox for Host Builds:** Chapter 5-6 builds run outside Bazel's sandbox to write to `sysroot/`

   - **Impact:** Less isolated, can't leverage remote execution for host builds
   - **Mitigation:** Chapter 7+ uses isolated Podman containers; host builds use isolated temp directory

1. **Binary Name Assumption:** Assumes binaries install to `$LFS/tools/bin/` or `$LFS/usr/bin/`

   - **Impact:** Libraries and headers should leave `create_runner` unset

1. **Logs in Execroot:** Build logs are written to `bazel-out/lfs-logs/` inside the Bazel execroot, not the workspace.

   - **Impact:** Logs are transient unless copied out.
   - **Mitigation:** View with `cat bazel-out/lfs-logs/<package>.log`

### Recent Enhancements

- [x] ✅ Rootless Podman worker for Chapter 7+ (no sudo required!)
- [x] ✅ Persistent JSON worker protocol (container stays alive across builds)
- [x] ✅ Network isolation (`--network=none` for chroot builds)
- [x] ✅ Parallel chroot builds supported

### Future Enhancements

- [ ] Mirror build logs into workspace (currently in execroot `bazel-out/lfs-logs/`)
- [ ] Better output capturing and logging
- [ ] Remote execution support for sandboxed builds

______________________________________________________________________

## 🧪 Testing

Verify the rules work with the hello world test:

```bash
# Build
bazel build //packages/hello_world:hello

# Run
bazel run //packages/hello_world:hello

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
bazel build //packages/hello_world:hello --subcommands
```

### Force Rebuild

```bash
bazel clean
bazel build //packages/hello_world:hello
```

### Check Marker Files

```bash
ls -l bazel-bin/packages/hello_world/hello.done
```

______________________________________________________________________

## 📖 Appendix: Related Documentation

- **[DESIGN.md](../DESIGN.md)** - Architecture and "Managed Chaos" philosophy
- **[docs/status.md](status.md)** - Build progress tracker
- **[LFS Book 12.2](https://www.linuxfromscratch.org/lfs/view/12.2/)** - Official build instructions
- **[Bazel Rules Tutorial](https://bazel.build/rules/rules-tutorial)** - Creating custom rules
