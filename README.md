# LFS Bazel Bootstrap

Hybrid build system that drives the Linux From Scratch (LFS) book with Bazel. Bazel handles dependency orchestration and caching; actual builds run via shell/make into a workspace-local sysroot.

## Repository Layout

- `src/` — Bazel workspace, Starlark rules, BUILD files, sysroot under `src/sysroot/`.
- `docs/` — LFS book sources (DocBook).

## Requirements

- Bazel with bzlmod enabled (repo cache defaults to `~/.cache/bazel/_bazel_repo_cache`).
- Host toolchain matching LFS Chapter 2 (gcc, g++, make, etc.).
- Offline builds beyond declared archive fetches.
- Validate host prerequisites: `bazel test //packages/chapter_02:version_check_test` (runs the Chapter 2 version checks).

## 🚀 Quickstart

```bash
cd src

# 1️⃣ Verify your host toolchain meets LFS requirements
bazel test //packages/chapter_02:version_check_test

# 2️⃣ Build the cross-toolchain (Chapter 5)
bazel build //packages/chapter_05:cross_toolchain

# 3️⃣ Build all temporary tools (Chapter 6)
bazel build //packages/chapter_06:all_temp_tools

# 🧪 Validate the cross-toolchain:
bazel run //packages/hello_world:hello_cross  # Uses Cross Toolchain (Ch 5) ✅
```

**Artifacts Location:** `src/sysroot/`

- Chapter 5 cross-toolchain: `src/sysroot/tools/bin/`
- Chapter 6 temporary tools: `src/sysroot/usr/bin/`, `src/sysroot/usr/lib/`

## 🔧 Toolchain Hierarchy (The Three-Stage Bootstrap)

This project builds **three distinct toolchains** in sequence, each more capable than the last:

### 1️⃣ Host Toolchain (Your System)

- **Location:** Your native system (`/usr/bin/gcc`, etc.)
- **Purpose:** Bootstrap the cross-toolchain (Chapter 5)
- **Verified by:** `bazel test //packages/chapter_02:version_check_test`

### 2️⃣ Cross Toolchain (Chapter 5) 🎯

- **Bazel Target:** `//packages/chapter_05:cross_toolchain`
- **Location:** `$LFS/tools/bin` (e.g., `x86_64-lfs-linux-gnu-gcc`)
- **Purpose:** Build temporary tools (Chapter 6) that run on host but target LFS
- **Key Components:**
  - Binutils Pass 1 (assembler, linker)
  - GCC Pass 1 (C/C++ compiler, no full libc yet)
  - Linux API headers
  - Glibc (minimal C library)
  - Libstdc++ (C++ standard library)
- **Validation:** `bazel run //packages/hello_world:hello_cross`

### 3️⃣ Temporary Tools Toolchain (Chapter 6) 🚀

- **Bazel Target:** `//packages/chapter_06:temp_tools_toolchain`
- **Location:** `$LFS/usr/bin` (rebuilt `x86_64-lfs-linux-gnu-gcc`)
- **Purpose:** Full-featured temporary toolchain with POSIX threads, ready for chroot
- **Key Components:**
  - Binutils Pass 2 (rebuilt with complete utilities)
  - GCC Pass 2 (full compiler with threading support)
  - 15 core utilities (bash, coreutils, make, etc.)
- **IMPORTANT:** 🔒 This toolchain is cross-compiled to run **ON the LFS target**, not the host!
  - Cannot run directly on host system (binaries are linked against LFS glibc)
  - Requires chroot environment to execute
  - Validation happens in Chapter 7 when building inside chroot

### 🎯 How They Work Together

```
Host GCC → builds → Cross Toolchain (Ch 5)
                        ↓
          Cross Toolchain → builds → Temp Tools (Ch 6)
                                          ↓
                      Temp Tools → builds → Final System (Ch 7+)
```

## Development Notes

- Builds run unsandboxed to write into `src/sysroot/`.
- Logs live under the Bazel execroot: `$OUTPUT_BASE/execroot/_main/tracker/logs/`.
- Chapter mapping for packages: Chapter 5 → `src/packages/chapter_05/`; Chapter 6 → `src/packages/chapter_06/`.
