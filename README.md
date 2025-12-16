# 🏗️ LFS Bazel Bootstrap

Build **Linux From Scratch** using Bazel! This hybrid build system combines the dependency management and caching power of Bazel with the traditional shell/make-based LFS build process.

**What makes this special?** Instead of forcing LFS into pure Bazel semantics, we use Bazel as a smart orchestrator that respects the LFS book's traditional build patterns while adding modern CI/CD capabilities.

## 🎯 What Is This Project?

This project implements the entire [Linux From Scratch 12.2](https://www.linuxfromscratch.org/) build process using Bazel build rules. It creates a complete Linux system from source code, demonstrating:

- **Three-stage bootstrap** from your host system to a fully independent OS
- **Hermetic builds** with proper dependency tracking
- **Incremental compilation** using Bazel's caching
- **Reproducible results** across different build environments

Perfect for learning about Linux internals, build systems, or just building your own custom Linux distribution!

## 📦 Repository Layout

```
lfs-bzl/
├── src/                    # Bazel workspace root
│   ├── packages/           # LFS chapter implementations
│   │   ├── chapter_05/     # Cross-toolchain (5 packages)
│   │   ├── chapter_06/     # Temporary tools (17 packages)
│   │   ├── chapter_07/     # Chroot preparation (6 packages)
│   │   ├── chapter_08/     # Final system (79 packages) 🎉
│   │   └── hello_world/    # Toolchain validation tests
│   ├── tools/              # Custom Bazel rules (lfs_build.bzl, etc.)
│   ├── sysroot/            # 🎯 Build artifacts (your LFS system!)
│   └── MODULE.bazel        # Source package definitions
└── docs/                   # Documentation and design notes
```

## ⚙️ Requirements

Before you begin, you'll need:

- **Bazel** 6.0+ with bzlmod enabled
- **Podman** (rootless mode) for Chapter 7-8+ container-based builds
- **Host toolchain** meeting LFS Chapter 2 requirements:
  - GCC 4.8+, g++, make, bash, coreutils, etc.
  - Run `bazel test //packages/chapter_02:version_check_test` to verify your environment.
- **Disk space:** ~10GB for sources and build artifacts
- **No sudo required!** Entire build runs as regular user with rootless Podman

## 🚀 Quickstart

```bash
# IMPORTANT: Bazel workspace root is `src/` (commands won't work from repo root)
cd src

# 1️⃣ Verify your host toolchain meets LFS requirements
bazel test //packages/chapter_02:version_check_test

# 2️⃣ Build the cross-toolchain (Chapter 5)
bazel build //packages/chapter_05:cross_toolchain

# 3️⃣ Build all temporary tools (Chapter 6)
bazel build //packages/chapter_06:all_temp_tools

# 4️⃣ Build Chapter 7 chroot base system (rootless Podman worker - no sudo!)
bazel build //packages/chapter_07:chroot_toolchain_phase

# 5️⃣ Build Chapter 8 final system (79 packages - rootless Podman worker)
bazel build //packages/chapter_08:ch8_all

# 🧪 Validate each toolchain stage:
bazel build //packages/hello_world:hello_cross  # Cross Toolchain (Ch 5) ✅
bazel build //packages/hello_world:hello_chroot # Chroot Tools (Ch 7) ✅
bazel build //packages/hello_world:hello_final  # Final System (Ch 8) ✅
```

**Build Artifacts Location:** `src/sysroot/`

- Chapter 5 cross-toolchain: `src/sysroot/tools/bin/`
- Chapter 6 temporary tools: `src/sysroot/usr/bin/`, `src/sysroot/usr/lib/`
- Chapter 7+ final system: `src/sysroot/` (root filesystem)

## 🔧 Toolchain Hierarchy (The Three-Stage Bootstrap)

This project builds **three distinct toolchains** in sequence, each more capable than the last. This mirrors the traditional LFS bootstrap process:

### 1️⃣ Host Toolchain (Your System)

- **Location:** Your native system (`/usr/bin/gcc`, etc.)
- **Purpose:** Bootstrap the cross-toolchain (Chapter 5)
- **Verified by:** `bazel test //packages/chapter_02:version_check_test`
- **Limitation:** Contaminated by host system; not reproducible

### 2️⃣ Cross Toolchain (Chapter 5) 🎯

- **Bazel Target:** `//packages/chapter_05:cross_toolchain`
- **Location:** `$LFS/tools/bin` (e.g., `x86_64-lfs-linux-gnu-gcc`)
- **Purpose:** Build temporary tools (Chapter 6) that run on host but target LFS
- **Key Components:**
  - Binutils Pass 1 (assembler, linker)
  - GCC Pass 1 (C/C++ compiler, minimal libc)
  - Linux API headers
  - Glibc (C library)
  - Libstdc++ (C++ standard library)
- **Validation:** `bazel run //packages/hello_world:hello_cross`
- **Why?** Isolates from host system contamination

### 3️⃣ Temporary Tools Toolchain (Chapter 6) 🚀

- **Bazel Target:** `//packages/chapter_06:temp_tools_toolchain`
- **Location:** `$LFS/usr/bin` (rebuilt `gcc`, `binutils`, etc.)
- **Purpose:** Full-featured temporary toolchain with POSIX threads, ready for chroot
- **Key Components:**
  - Binutils Pass 2 (rebuilt with complete utilities)
  - GCC Pass 2 (full compiler with threading support)
  - 17 core utilities (bash, coreutils, make, grep, etc.)
- **IMPORTANT:** 🔒 This toolchain is cross-compiled to run **ON the LFS target**, not the host!
  - Cannot run directly on host system (binaries are linked against LFS glibc)
  - Requires chroot environment to execute
  - Validation happens in Chapter 7 when building inside chroot

### 4️⃣ Final System Toolchain (Chapter 8) 🎉

- **Bazel Target:** `//packages/chapter_08:toolchain`
- **Location:** `$LFS/usr/bin` (native GCC, built inside chroot)
- **Purpose:** The complete, self-hosting toolchain for the final system
- **Key Components:**
  - Native GCC 14.2 (built inside chroot, no host dependencies)
  - Native Binutils 2.43.1
  - Glibc 2.40
  - 79 total packages (compression, security, python, systemd, etc.)
- **Validation:** `bazel build //packages/hello_world:hello_final`
- **Result:** A fully independent, bootable Linux system!

### 🎯 How They Work Together

```
Host GCC → builds → Cross Toolchain (Ch 5)
                        ↓
          Cross Toolchain → builds → Temp Tools (Ch 6)
                                          ↓
                      Temp Tools → builds → Chroot Base (Ch 7)
                                                  ↓
                            Chroot Base → builds → Final System (Ch 8)
                                                        ↓
                                                  Bootable Linux! 🐧
```

Each stage removes dependency on the previous, creating a fully independent system.

**Validation targets at each stage:**

- `//packages/hello_world:hello_cross` - Cross toolchain (runs on host)
- `//packages/hello_world:hello_chroot` - Chroot tools (runs in container)
- `//packages/hello_world:hello_final` - Final system GCC (builds deps if needed, cached after)

## 🐳 Hybrid Build Architecture

This project uses a unique hybrid approach across different LFS chapters:

### Chapters 5-6: Native Host Builds

- Run directly on your host system
- Write to staging sysroot (`src/sysroot/`)
- No containers, no sudo required
- Fast, simple, cached by Bazel

### 🚀 Chapters 7-8+: Rootless Podman Worker (No Sudo!)

- Persistent Bazel JSON worker running in rootless Podman container
- Container mounts staging sysroot at `/lfs`
- All builds run as regular user (no sudo required!)
- Fast: container stays alive across builds, amortizing startup cost
- Isolated: `--network=none` enforces offline builds
- Mounts virtual filesystems (`/dev`, `/proc`, `/sys`, `/run`) inside container

**The Result:** Modern container-based workflow with zero sudo requirements for the entire build process.

## 🏗️ Build Progress

Current implementation status:

- ✅ **Chapter 5:** Cross-toolchain (5 packages) - Native host builds
- ✅ **Chapter 6:** Temporary tools (17 packages) - Native host builds
- ✅ **Chapter 7:** Chroot base system (6 packages) - Rootless Podman worker
- ✅ **Chapter 8:** Final system (79 packages) - Rootless Podman worker
- ⏳ **Chapter 9-11:** Configuration, kernel, bootloader (planned)

**Design Decisions:**

- **Init System:** systemd (not SysVinit)
- **Strip Command:** Skipped (optional per LFS book)
- **Expected Test Failures:** Some tests fail in chroot - this is documented and expected per LFS book

See [docs/status.md](docs/status.md) for detailed progress tracking.

## ⚠️ Common Pitfalls

### First-time Podman Setup

The rootless Podman worker (used for Chapter 7-8+) requires initial setup:

**Symptom**: Podman commands fail or container can't start

**Solution**: Ensure Podman is installed and configured for rootless mode:

```bash
# Check Podman version
podman --version  # Should be 3.0+

# Test rootless container
podman run --rm hello-world
```

**Best practice**: Build container image before starting chroot builds:

```bash
cd src
bazel run //tools/podman:container_image
```

See [docs/troubleshooting.md](docs/troubleshooting.md) for detailed setup and troubleshooting.

## 🔄 Cleanup and Restart

### Starting Fresh (Full Rebuild)

To completely restart the build from scratch:

```bash
cd src

# 1️⃣ Remove the entire sysroot directory
rm -rf sysroot/

# 2️⃣ Clean Bazel's cache (optional, for a truly clean build)
bazel clean --expunge

# 3️⃣ Rebuild the complete bootstrap (Chapter 5 → 6 → 7)
# Build cross-toolchain (Chapter 5) - ~5-10 minutes
bazel build //packages/chapter_05:cross_toolchain

# Build temporary tools (Chapter 6) - ~30-45 minutes
bazel build //packages/chapter_06:all_temp_tools

# Build Chapter 7 chroot base system - ~5-10 minutes
bazel build //packages/chapter_07:chroot_toolchain_phase
```

**Expected total rebuild time:** ~1-2 hours depending on hardware (parallel builds used automatically)

**Note**: No sudo required! The Podman worker handles all containerization internally.

### Restarting from a Specific Chapter

You don't need to start from scratch if you want to iterate on a later chapter:

**Restart Chapter 6 only:**

```bash
# Remove Chapter 6 artifacts
rm -rf sysroot/usr/

# Rebuild Chapter 6
bazel clean  # Clear Bazel's action cache
bazel build //packages/chapter_06:all_temp_tools
```

**Restart Chapter 7 only:**

```bash
# Remove Chapter 7 artifacts
rm -rf sysroot/{bin,sbin,lib,lib64,etc,var}
rm -rf sysroot/usr/bin/{bison,perl,python3,makeinfo}

# Rebuild Chapter 7
bazel clean
bazel build //packages/chapter_07:chroot_finalize
```

### Clean Build vs Incremental Build

**Clean build (start from scratch):**

```bash
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"
rm -rf sysroot/
bazel clean --expunge
bazel build //packages/chapter_06:all_temp_tools
```

**Incremental build (preserve sysroot):**

```bash
# Just rebuild a specific target
bazel build //packages/chapter_06:m4

# Or clean Bazel's cache but keep sysroot
bazel clean
bazel build //packages/chapter_06:all_temp_tools
```

**Best practice:** Use incremental builds during development. Only do clean builds when troubleshooting or starting fresh.

## 💻 Development Notes

### How Builds Work

- **Unsandboxed execution:** Builds run outside Bazel's sandbox to write into `src/sysroot/`
- **Build logs:** Written to `bazel-out/lfs-logs/<target>.log` in the Bazel execroot
- **Dependency tracking:** Each package creates a `.done` marker file for Bazel

### Project Structure

- **Chapter mapping:** Each LFS chapter maps to a package directory (`src/packages/chapter_XX/`)
- **Custom rules:** All build logic lives in `src/tools/lfs_build.bzl`
- **Source definitions:** Package URLs and checksums in `src/MODULE.bazel`

## 📚 Documentation

### Core Documentation

- **[DESIGN.md](DESIGN.md)** - Architecture and "Managed Chaos" philosophy
- **[docs/status.md](docs/status.md)** - Build progress tracker
- **[docs/tools.md](docs/tools.md)** - Bazel rules reference
- **[docs/troubleshooting.md](docs/troubleshooting.md)** - Common issues and solutions

### Chapter Guides

- **[docs/chroot.md](docs/chroot.md)** - Chapter 7: Entering Chroot (detailed guide)

## 🤝 Contributing

This is a personal learning project, but feedback and suggestions are welcome! File issues or PRs on GitHub.

## 📄 License

This project is licensed under the **Apache License 2.0** - see the [LICENSE](LICENSE) file for details.

### Third-Party Licenses

This repository includes the [Linux From Scratch 12.2 book](https://www.linuxfromscratch.org/) as a Git submodule in `docs/lfs-book/` for reference purposes. The LFS book has its own separate licensing:

- **Book text:** [Creative Commons Attribution-NonCommercial-ShareAlike 2.0](https://creativecommons.org/licenses/by-nc-sa/2.0/)
- **Code/instructions:** [MIT License](https://opensource.org/licenses/MIT)

See `docs/lfs-book/appendices/license.xml` for the full LFS license details.

## 📖 Appendix: Resources

### Official Guides

- [Linux From Scratch 12.2 Book](https://www.linuxfromscratch.org/lfs/view/stable/) - The source material
- [Bazel Documentation](https://bazel.build/docs) - Build system reference

### Community

- [LFS Mailing Lists](https://www.linuxfromscratch.org/mail.html) - Get help from LFS community
- [/r/linuxfromscratch](https://reddit.com/r/linuxfromscratch) - Reddit community
