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
│   │   └── ...
│   ├── tools/              # Custom Bazel rules (lfs_build.bzl, etc.)
│   ├── sysroot/            # 🎯 Build artifacts (your LFS system!)
│   └── MODULE.bazel        # Source package definitions
└── docs/                   # Documentation and design notes
```

## ⚙️ Requirements

Before you begin, you'll need:

- **Bazel** 6.0+ with bzlmod enabled
- **Host toolchain** meeting LFS Chapter 2 requirements:
  - GCC 4.8+, g++, make, bash, coreutils, etc.
  - Run `bazel test //packages/chapter_02:version_check_test` to verify
- **Disk space:** ~10GB for sources and build artifacts
- **For Chapter 7+:** sudo access for chroot operations

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

# 4️⃣ Stage sources for chroot builds (Chapter 7)
bazel build //packages/chapter_07:stage_ch7_sources

# 5️⃣ Run all Chapter 7 chroot steps (requires sudo)
bazel build //packages:bootstrap_ch7

# 🧪 Validate the cross-toolchain:
bazel run //packages/hello_world:hello_cross  # Uses Cross Toolchain (Ch 5) ✅
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

### 4️⃣ Final System Toolchain (Chapter 7+) 🎉

- **Location:** `$LFS/usr/bin` (native GCC, built inside chroot)
- **Purpose:** Build the complete final system (Chapter 8+)
- **Built inside chroot:** Uses the temporary tools to compile itself
- **Result:** A fully independent, bootable Linux system!

### 🎯 How They Work Together

```
Host GCC → builds → Cross Toolchain (Ch 5)
                        ↓
          Cross Toolchain → builds → Temp Tools (Ch 6)
                                          ↓
                      Temp Tools → builds → Final System (Ch 7+)
                                                  ↓
                                            Bootable Linux! 🐧
```

Each stage removes dependency on the previous, creating a fully independent system.

## 🏗️ Build Progress

Current implementation status:

- ✅ **Chapter 5:** Cross-toolchain (5 packages)
- ✅ **Chapter 6:** Temporary tools (17 packages)
- ✅ **Chapter 7:** Chroot preparation (6 packages)
- 🚧 **Chapter 8:** Final system packages (in progress)
- ⏳ **Chapter 9-11:** Configuration, kernel, bootloader (planned)

See [docs/status.md](docs/status.md) for detailed progress tracking.

## ⚠️ Common Pitfalls

### Sysroot Ownership After Chapter 7

After running Chapter 7 builds, the sysroot ownership changes to root:root. This
prevents re-running Chapter 5-6 builds as a regular user.

**Symptom**: "Permission denied" errors when building Chapter 5-6 after Chapter 7

**Detection**: The build system automatically detects this and shows a recovery message

**Recovery**:

```bash
sudo chown -R $USER:$USER src/sysroot/
```

**Why this happens**: Chapter 7's `chroot_chown_root` prepares the chroot environment
by changing ownership. This is expected LFS behavior.

**Best practice**: Build linearly (Ch5 → Ch6 → Ch7 → Ch8+) without going backwards.
If you need to iterate on early chapters, restore ownership as shown above.

See [docs/troubleshooting.md](docs/troubleshooting.md) for detailed recovery procedures.

## 🔄 Cleanup and Restart

### Starting Fresh (Full Rebuild: Chapter 7 → Nothing → Chapter 7)

To completely restart the build from scratch after completing Chapter 7:

```bash
cd src

# 1️⃣ IMPORTANT: Unmount virtual filesystems first (Chapter 7 mounts /dev, /proc, etc.)
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"

# 2️⃣ Verify all mounts are cleared (should show nothing)
findmnt | grep sysroot

# 3️⃣ Remove the entire sysroot directory
rm -rf sysroot/

# 4️⃣ Clean Bazel's cache (optional, for a truly clean build)
bazel clean --expunge

# 5️⃣ Rebuild the complete bootstrap (Chapter 5 → 6 → 7)
# Build cross-toolchain (Chapter 5) - ~5-10 minutes
bazel build //packages/chapter_05:cross_toolchain

# Build temporary tools (Chapter 6) - ~30-45 minutes
bazel build //packages/chapter_06:all_temp_tools

# Stage sources for chroot builds (Chapter 7 prep)
bazel build //packages/chapter_07:stage_ch7_sources

# Run all Chapter 7 chroot steps (requires sudo) - ~15-20 minutes
bazel build //packages:bootstrap_ch7
```

**⚠️ WARNING:** Always unmount before removing sysroot! Removing mounted filesystems can corrupt your host system.

```bash
# Always unmount first:
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"
```

**Expected total rebuild time:** ~1-2 hours depending on hardware (parallel builds used automatically)

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
# Unmount first!
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"

# Remove Chapter 7 artifacts
rm -rf sysroot/{bin,sbin,lib,lib64,etc,var}
rm -rf sysroot/usr/bin/{bison,perl,python3,makeinfo}

# Rebuild Chapter 7
bazel clean
bazel build //packages/chapter_07:chroot_finalize
```

### Checking Mount Status

Before cleanup, always check if virtual filesystems are mounted:

```bash
# Check current mounts
findmnt | grep sysroot

# Check refcount (should not exist or be 0)
cat src/sysroot/tmp/.lfs-mount-refcount 2>/dev/null

# If mounts exist, unmount them (run until refcount reaches 0)
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"
```

**Why this matters:** Chapter 7+ operations mount `/dev`, `/proc`, `/sys`, `/run`, etc. into the sysroot. These must be unmounted before cleanup to avoid:

- Permission errors during `rm -rf`
- Accidentally affecting your host system
- Resource leaks

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

### Debugging

```bash
# View build commands
bazel build //packages/chapter_05:binutils_pass1 --subcommands

# Force rebuild
bazel clean
bazel build //packages/chapter_05:cross_toolchain

# Check logs
cat bazel-out/lfs-logs/binutils_pass1.log
```

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
