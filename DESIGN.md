# 🎭 Design Document: The "Managed Chaos" Architecture

**Project:** `lfs-bazel-bootstrap`
**Target:** Linux From Scratch (System V), Version 12.x
**Build System:** Bazel (Orchestrator) + Make/Shell (Executor)

## 1. 🧠 Core Philosophy: "Managed Chaos"

We are not trying to force LFS into a "pure" Bazel build (which would require rewriting thousands of Makefiles). Instead, we use Bazel as a **workflow engine**.

- **Bazel's Job:** dependency tracking, caching, parallelization, and artifact storage.
- **The Rule's Job:** To set up the specific, "dirty" environment (environment variables, paths, chroots) that LFS expects, and then execute the raw shell commands from the book.

### 🌉 We are "bridging" the gap:

- **Standard Bazel:** "I control the compiler flags."
- **LFS Bazel:** "I control the `PATH` and `ENV`, so the scripts *find* the right compiler."

This hybrid approach gives us the best of both worlds: Bazel's orchestration with LFS's battle-tested build recipes.

______________________________________________________________________

## 2. 📁 Directory Structure

We use a three-tier layout to separate knowledge, tracking, and execution.

```text
~/lfs-bazel-bootstrap/
├── docs/                      # 📚 The Knowledge Base
│   ├── lfs-book/              # (Git Clone) The LFS XML/HTML source
│   ├── status.md              # Build progress tracker
│   ├── tools.md               # Bazel rules reference
│   └── troubleshooting.md     # Common issues and solutions
└── src/                       # 🔧 The Bazel Workspace
    ├── WORKSPACE              # Root Bazel definition
    ├── MODULE.bazel           # Bzlmod package definitions
    ├── sysroot/               # 🎯 THE ARTIFACT: Acts as $LFS (e.g., /mnt/lfs)
    │                          # NOTE: This is a folder *inside* the workspace.
    ├── tools/                 # 🌉 The "Bridge" Logic (Starlark)
    │   ├── providers.bzl      # Toolchain definitions
    │   ├── lfs_build.bzl      # Host-side + chroot execution rules
    │   └── lfs_defaults.bzl   # Phase presets (ch5/ch6/ch7)
    └── packages/              # 📦 The Implementation
        ├── chapter_04/        # Setup (creating directories)
        ├── chapter_05/        # Cross-Toolchain (binutils, gcc, glibc)
        ├── chapter_06/        # Temporary Tools (17 packages)
        └── chapter_07/        # Chroot preparation (6 packages)
```

______________________________________________________________________

## 3. 🌉 The "Bridge" Architecture (Starlark Specs)

We avoid `rules_foreign_cc` to maintain granular control over the environment. We implement three custom components.

### Component A: 📦 The Toolchain Provider (`tools/providers.bzl`)

This is a data object that passes "Build Capability" from one package to the next. It does not invoke a compiler; it carries the *location* of the compiler.

```python
LfsToolchainInfo = provider(
    fields = {
        "bin_path": "Path to the toolchain's bin directory (e.g., src/sysroot/tools/bin)",
        "env": "Dictionary of environment variables (CC, CXX, AR, etc.)",
    }
)
```

### Component B: 🏗️ The Host Bridge (`tools/lfs_build.bzl`)

**Used for:** Chapters 2–5 (Constructing the Cross-Toolchain).
**Execution Context:** The Host OS.

- **Inputs:** `srcs` (tarballs), `cmd` (shell script), optional `toolchain` (LfsToolchainInfo).
- **Logic:**
  1. Resolves inputs.
  1. Constructs an execution script.
  1. **Crucial Step:** If a `toolchain` dep is provided, it prepends `toolchain.bin_path` to the `$PATH` and exports `toolchain.env`.
  1. Runs the user's `cmd`.
- **Output:** A `.done` marker file to signal completion to Bazel.

### Component C: 🚪 The Chroot Bridge (`tools/lfs_build.bzl`)

**Used for:** Chapter 6+ (Building the Final System).
**Execution Context:** Inside `src/sysroot` (via `chroot`).

- **Inputs:** `srcs`, `cmd`, `toolchain`.
- **Logic:**
  1. Generates an `inner.sh` (the build commands).
  1. Generates a `wrapper.sh` (invokes the chroot helper).
  1. `wrapper.sh` calls `sudo lfs-chroot-helper.sh exec-chroot <sysroot> <inner.sh>`.
  1. Helper manages mount/unmount of virtual filesystems.
- **Requirement:** Must run with `tags = ["manual", "requires-sudo"]`.

______________________________________________________________________

## 4. 🔄 The Workflow Stages

### Phase 1: 🏗️ Infrastructure

- Initialize `WORKSPACE` and `sysroot`.
- Implement the Starlark rules.
- **Verification:** Build a "Hello World" to `sysroot/tools` using the host compiler.

### Phase 2: 🎯 The Cross-Toolchain (Chapter 5)

- **Goal:** Build the toolchain that runs on Host but targets LFS.
- **Mechanism:** Use `lfs_package` without a toolchain (uses Host GCC).
- **Key Packages:** Binutils (Pass 1), GCC (Pass 1), Linux Headers, Glibc, Libstdc++.

### Phase 3: 🤝 The "Handover" (End of Chapter 5)

- **Goal:** Stop using Host GCC. Start using the GCC we just built.
- **Action:** Define a Bazel target `//packages/chapter_05:cross_toolchain` using `LfsToolchainInfo`.
- **Content:**
  - `bin_path`: `$LFS/tools/bin`
  - `env`: `CC="x86_64-lfs-linux-gnu-gcc"`, `LFS_TGT="..."`

### Phase 4: 🚀 Temporary Tools (Chapter 6)

- **Goal:** Build 17 core utilities using the cross-toolchain.
- **Mechanism:** Use `lfs_package` with `toolchain = "//packages/chapter_05:cross_toolchain"`.
- **Result:** Temporary tools installed to `$LFS/usr/bin`.
- **Key Components:** bash, coreutils, make, grep, binutils pass 2, gcc pass 2

### Phase 5: 🚪 Entering Chroot (Chapter 7)

- **Goal:** Build essential packages inside the chroot environment.
- **Mechanism:** Use `lfs_chroot_command` and `lfs_chroot_step` rules.
- **Packages:** gettext, bison, perl, python, texinfo, util-linux
- **Toolchain:** `//packages/chapter_06:temp_tools_toolchain` (runs inside chroot)

### Phase 6: 🎉 The Final System (Chapter 8+)

- **Goal:** Build the OS using the temporary toolchain inside the chroot.
- **Mechanism:** Use `lfs_chroot` rules.
- **Dependency:** All targets depend on `//packages/chapter_07:chroot_prepare`.

______________________________________________________________________

## 5. 🔐 Security Model (Chroot Helper)

The `lfs-chroot-helper.sh` script is designed with security in mind:

- **Allowlist-based:** Only 4 operations allowed (mount-vfs, unmount-vfs, exec-chroot, check-mounts)
- **Path validation:** All paths must be absolute and exist
- **Idempotent mounts:** Safe to call multiple times
- **No arbitrary execution:** Scripts are read from files, not passed as arguments
- **Minimal sudo surface:** Only the helper needs sudo, not the entire Bazel process

### 🔑 Sudoers Configuration

```bash
# /etc/sudoers.d/lfs-bazel-chroot
<user> ALL=(root) NOPASSWD: /path/to/repo/src/tools/lfs-chroot-helper.sh
```

______________________________________________________________________

## 6. 📊 Build Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User runs: bazel build //packages/chapter_07:perl       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Bazel resolves dependencies:                             │
│    - stage_ch7_sources                                      │
│    - extract_perl                                           │
│    - temp_tools_toolchain (provides env)                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. lfs_chroot_step generates:                               │
│    - inner.sh (contains build commands + env)               │
│    - wrapper.sh (calls chroot helper)                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. wrapper.sh calls:                                        │
│    sudo lfs-chroot-helper.sh exec-chroot $LFS /tmp/inner.sh │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Helper mounts virtual filesystems:                       │
│    - /dev, /dev/pts, /proc, /sys, /run                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Helper enters chroot and executes inner.sh               │
│    - Extraction, configure, make, install                   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Creates perl.done marker file                            │
│    Bazel caches the result                                  │
└─────────────────────────────────────────────────────────────┘
```

______________________________________________________________________

## 7. 🎨 Design Principles

### Principle 1: **Minimal Abstraction**

Don't hide what the LFS book does. Let users see the actual `./configure && make && make install` commands.

### Principle 2: **Escape Hatches**

Every macro (`lfs_autotools`, `lfs_configure_make`) is just a convenience. You can always drop to `lfs_package` for full control.

### Principle 3: **Progressive Enhancement**

Start with simple rules, add features as needed. The `lfs_package` rule handles 90% of cases; specialized rules handle the rest.

### Principle 4: **Fail Fast, Fail Loud**

Build errors should be obvious. Use `set -euo pipefail` in all scripts. Log everything to `bazel-out/lfs-logs/`.

### Principle 5: **Reproducibility > Convenience**

If a build works on one machine but not another, that's a bug. Dependency tracking must be explicit.

______________________________________________________________________

## 8. 🚧 Known Limitations & Future Work

### Current Limitations

1. **No Remote Execution:** Builds run outside Bazel's sandbox, so they can't leverage remote execution or strict hermetic builds.
1. **Sudo Requirement:** Chapter 7+ requires sudo for chroot operations.
1. **No Parallel Chroot Builds:** The chroot helper uses locking, but parallel builds inside chroot are not tested.

### Future Enhancements

- [ ] Add support for `rules_oci` to build container images from sysroot
- [ ] Implement build artifact caching beyond Bazel's local cache
- [ ] Add Chapter 8+ package definitions
- [ ] Create automated tests for each chapter
- [ ] Support for BLFS (Beyond Linux From Scratch) packages

______________________________________________________________________

## 📖 Appendix: Key Files

### Implementation

- **[tools/lfs_build.bzl](src/tools/lfs_build.bzl)** - Core build rules
- **[tools/providers.bzl](src/tools/providers.bzl)** - Toolchain provider
- **[tools/lfs_defaults.bzl](src/tools/lfs_defaults.bzl)** - Phase presets
- **[tools/lfs-chroot-helper.sh](src/tools/lfs-chroot-helper.sh)** - Chroot helper script

### Documentation

- **[docs/tools.md](docs/tools.md)** - Comprehensive rules reference
- **[docs/status.md](docs/status.md)** - Build progress tracker
- **[docs/chroot.md](docs/chroot.md)** - Chapter 7: Entering Chroot guide
- **[docs/troubleshooting.md](docs/troubleshooting.md)** - Common issues and solutions
