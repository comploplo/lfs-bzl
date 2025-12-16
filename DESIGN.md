# 🎭 Design Document: The "Managed Chaos" Architecture

**Project:** `lfs-bazel-bootstrap`
**Target:** Linux From Scratch 12.2 (systemd)
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

**Used for:** Chapter 7+ (Building the Final System).
**Execution Context:** Inside rootless Podman container running chroot.

- **Inputs:** `srcs`, `cmd`, `phase="chroot"`.
- **Logic:**
  1. Detects `phase="chroot"` and triggers Podman worker execution.
  1. Worker launcher creates rootless container with Bazel JSON worker protocol.
  1. Container mounts sysroot at `/lfs` and virtual filesystems (`/dev`, `/proc`, `/sys`, `/run`).
  1. Executes configure, build, and install commands inside chroot.
  1. Worker stays alive across builds for performance.
- **Key Feature:** No sudo required! Uses Podman user namespaces.

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
- **Mechanism:** Use `lfs_package` with `phase="chroot"` (Podman worker).
- **Packages:** gettext, bison, perl, python, texinfo, util-linux
- **Toolchain:** Temporary tools from Chapter 6 (available inside chroot)
- **No Sudo:** Rootless Podman worker handles all chroot operations

### Phase 6: 🎉 The Final System (Chapter 8+)

- **Goal:** Build the OS using the temporary toolchain inside the chroot.
- **Mechanism:** Use `lfs_package` with `phase="chroot"` (same Podman worker as Chapter 7).
- **Dependency:** All targets depend on `//packages/chapter_07:chroot_base_toolchain`.
- **No Sudo:** Entire build process runs as regular user with rootless Podman

______________________________________________________________________

## 5. 🔐 Security Model (Rootless Podman)

The rootless Podman worker provides secure isolation without sudo:

- **User namespaces:** Processes run as root inside container, regular user on host
- **Network isolation:** Builds run with `--network=none` (offline enforcement)
- **Filesystem isolation:** Only sysroot is mounted, rest of host filesystem is inaccessible
- **No sudo required:** Entire build process runs as regular user
- **Persistent worker:** JSON worker protocol amortizes container startup cost

### 🔑 Podman Setup

No sudoers configuration needed! Just ensure rootless Podman is configured:

```bash
podman --version  # Should be 3.0+
podman run --rm hello-world  # Test basic functionality
```

______________________________________________________________________

## 6. 📊 Build Lifecycle (Chapter 7+)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. User runs: bazel build //packages/chapter_07:perl       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Bazel resolves dependencies:                             │
│    - @perl_src//file (tarball from external repo)          │
│    - chroot_prepare (env setup)                             │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. lfs_package detects phase="chroot":                      │
│    - Generates build script                                 │
│    - Triggers Podman worker execution                       │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Worker launcher creates rootless Podman container:       │
│    - Mounts sysroot at /lfs                                 │
│    - Mounts external repos for source access                │
│    - Starts Bazel JSON worker protocol                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Worker mounts virtual filesystems inside container:      │
│    - /dev, /dev/pts, /proc, /sys, /run                      │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Worker executes build inside chroot:                     │
│    - Extracts tarball, configure, make, install             │
│    - Runs as root inside container (regular user on host)   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Creates perl.done marker file                            │
│    Worker stays alive for next build                        │
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
1. **Chapter 5-6 Host Builds:** Early toolchain builds run unsandboxed on host (Chapters 5-6). Chapter 7+ uses isolated Podman worker.
1. **Podman Requirement:** Chapter 7+ requires rootless Podman configured on the host system.

### Design Decisions

- **Init System:** Using systemd (not SysVinit) - more modern and widely adopted
- **Strip Command:** Skipped - optional per LFS book, preserves debug symbols
- **Expected Test Failures:** Some tests fail in chroot environment - this is documented and expected per LFS book

### Future Enhancements

- [ ] Add support for `rules_oci` to build container images from sysroot
- [ ] Implement build artifact caching beyond Bazel's local cache
- [x] ~~Add Chapter 8+ package definitions~~ (COMPLETE - 79 packages)
- [ ] Create automated tests for each chapter
- [ ] Support for BLFS (Beyond Linux From Scratch) packages
- [ ] Chapter 9: System configuration
- [ ] Chapter 10: Make bootable (kernel, GRUB)
- [ ] Chapter 11: Finalization and disk image

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
