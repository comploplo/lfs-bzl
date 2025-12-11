# Design Document: The "Managed Chaos" Architecture

**Project:** `lfs-bazel-bootstrap`
**Target:** Linux From Scratch (System V), Version 12.x
**Build System:** Bazel (Orchestrator) + Make/Shell (Executor)

## 1. Core Philosophy: "Managed Chaos"

We are not trying to force LFS into a "pure" Bazel build (which would require rewriting thousands of Makefiles). Instead, we use Bazel as a **workflow engine**.

- **Bazel's Job:** dependency tracking, caching, parallelization, and artifact storage.
- **The Rule's Job:** To set up the specific, "dirty" environment (environment variables, paths, chroots) that LFS expects, and then execute the raw shell commands from the book.

**We are "bridging" the gap:**

- Standard Bazel: "I control the compiler flags."
- LFS Bazel: "I control the `PATH` and `ENV`, so the scripts *find* the right compiler."

______________________________________________________________________

## 2. Directory Structure

We use a three-tier layout to separate knowledge, tracking, and execution.

```text
~/lfs-bazel-bootstrap/
├── docs/                      # The Knowledge Base
│   ├── lfs-book/              # (Git Clone) The LFS XML/HTML source
│   └── notes.md               # Architecture decisions (like this file)
├── tracker/                   # Project State
│   ├── prompts/               # Saved prompts used for Gemini Coder
│   └── logs/                  # Build logs for debugging
└── src/                       # The Bazel Workspace
    ├── WORKSPACE              # Root Bazel definition
    ├── sysroot/               # THE ARTIFACT: Acts as $LFS (e.g., /mnt/lfs)
    │                          # NOTE: This is a folder *inside* the workspace.
    ├── tools/                 # The "Bridge" Logic (Starlark)
    │   ├── providers.bzl      # Toolchain definitions
    │   ├── lfs_build.bzl      # Host-side execution rule
    │   └── lfs_chroot.bzl     # Chroot execution rule
    └── packages/              # The Implementation
        ├── chapter_04/        # Setup (creating directories)
        ├── chapter_05/        # Cross-Toolchain (binutils, gcc, glibc)
        └── chapter_06/        # Final System (chroot environment)
```

______________________________________________________________________

## 3. The "Bridge" Architecture (Starlark Specs)

We avoid `rules_foreign_cc` to maintain granular control over the environment. We will implement three custom components.

### Component A: The Toolchain Provider (`tools/providers.bzl`)

This is a data object that passes "Build Capability" from one package to the next. It does not invoke a compiler; it carries the *location* of the compiler.

```python
LfsToolchainInfo = provider(
    fields = {
        "bin_path": "Path to the toolchain's bin directory (e.g., src/sysroot/tools/bin)",
        "env": "Dictionary of environment variables (CC, CXX, AR, etc.)",
    }
)
```

### Component B: The Host Bridge (`tools/lfs_build.bzl`)

**Used for:** Chapters 2–5 (Constructing the Cross-Toolchain).
**Execution Context:** The Host OS.

- **Inputs:** `srcs` (tarballs), `cmd` (shell script), optional `toolchain` (LfsToolchainInfo).
- **Logic:**
  1. Resolves inputs.
  1. Constructs an execution script.
  1. **Crucial Step:** If a `toolchain` dep is provided, it prepends `toolchain.bin_path` to the `$PATH` and exports `toolchain.env`.
  1. Runs the user's `cmd`.
- **Output:** A `.done` marker file to signal completion to Bazel.

### Component C: The Chroot Bridge (`tools/lfs_chroot.bzl`)

**Used for:** Chapter 6+ (Building the Final System).
**Execution Context:** Inside `src/sysroot` (via `chroot`).

- **Inputs:** `srcs`, `cmd`, `toolchain`.
- **Logic:**
  1. Generates an `inner.sh` (the build commands).
  1. Generates an `outer.sh` (the wrapper).
  1. `outer.sh` mounts virtual filesystems (This should be fleshed out during chapter 6)
  1. `outer.sh` calls `sudo chroot src/sysroot /tools/bin/env -i ... /inner.sh`.
  1. Cleans up mounts.
- **Requirement:** Must run with `tags = ["no-sandbox", "requires-fakeroot"]` (or configured sudo access).

______________________________________________________________________

## 4. The Workflow Stages

### Phase 1: Infrastructure

- Initialize `WORKSPACE` and `sysroot`.
- Implement the Starlark rules.
- **Verification:** Build a "Hello World" to `sysroot/tools` using the host compiler.

### Phase 2: The Cross-Toolchain (Chapter 5)

- **Goal:** Build the toolchain that runs on Host but targets LFS.
- **Mechanism:** Use `lfs_build` without a toolchain (uses Host GCC).
- **Key Packages:** Binutils (Pass 1), GCC (Pass 1), Linux Headers, Glibc, Libstdc++.

### Phase 3: The "Handover" (End of Chapter 5)

- **Goal:** Stop using Host GCC. Start using the GCC we just built.
- **Action:** Define a Bazel target `//packages/chapter_05:lfs_cross_toolchain` using `LfsToolchainInfo`.
- **Content:**
  - `bin_path`: `src/sysroot/tools/bin`
  - `env`: `CC="x86_64-lfs-linux-gnu-gcc"`, `LFS_TGT="..."`

### Phase 4: The Final System (Chapter 6+)

- **Goal:** Build the OS using the temporary toolchain inside the chroot.
- **Mechanism:** Use `lfs_chroot` rules.
- **Dependency:** All targets depend on `//packages/chapter_05:lfs_cross_toolchain`.
