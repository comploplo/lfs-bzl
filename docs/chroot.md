# 🚪 Chapter 7: Entering Chroot

**Status:** ✅ Complete (6 packages built)
**Build Environment:** Inside chroot using temporary tools from Chapter 6

## 🎯 Overview

Chapter 7 marks a critical transition in the LFS bootstrap process. We enter the chroot environment and build essential tools that will be used to compile the final system in Chapter 8+.

### Why Chroot?

The chroot (change root) operation isolates our build environment:

- **Prevents contamination** from the host system
- **Forces use** of our temporary tools (not host tools)
- **Creates a controlled** environment for the final system build
- **Simulates** the environment of a bootable LFS system

### The 6 Essential Packages

These packages are required by Chapter 8 build scripts but weren't needed in Chapter 6:

| Package        | Purpose                                                    | Why Now?                           |
| -------------- | ---------------------------------------------------------- | ---------------------------------- |
| **Gettext**    | Internationalization (i18n) and localization tools         | Required by many Chapter 8 builds  |
| **Bison**      | Parser generator (creates compilers from grammar files)    | Used by several build systems      |
| **Perl**       | Powerful scripting language                                | Many configure scripts use Perl    |
| **Python**     | Modern programming language                                | Modern build systems (Meson, etc.) |
| **Texinfo**    | Documentation system (creates info, HTML, PDF from source) | Needed for package documentation   |
| **Util-linux** | Essential system utilities (mount, lsblk, etc.)            | Core system management tools       |

## 🏗️ Build Process

### Prerequisites

Before building Chapter 7, ensure:

1. ✅ Chapter 5 cross-toolchain is built (`//packages/chapter_05:cross_toolchain`)
1. ✅ Chapter 6 temporary tools are built (`//packages/chapter_06:all_temp_tools`)
1. ✅ Sudo access configured for the chroot helper script

### Sudo Configuration

The chroot helper requires sudo. Add this to `/etc/sudoers.d/lfs-bazel-chroot`:

```bash
<your-user> ALL=(root) NOPASSWD: /path/to/lfs-bzl/src/tools/lfs-chroot-helper.sh
```

Replace `/path/to/lfs-bzl` with your actual repository path and `<your-user>` with your username.

### Build Commands

```bash
cd src

# 1. Stage sources into the chroot environment
bazel build //packages/chapter_07:stage_ch7_sources

# 2. Prepare the chroot environment (create directories, seed files)
bazel build //packages/chapter_07:chroot_prepare

# 3. Build all Chapter 7 packages
bazel build //packages/chapter_07:chroot_toolchain_phase

# 4. Verify installations
bazel run //packages/chapter_07:chroot_smoke_versions
```

### What Happens During Build

1. **Source Staging** - Tarballs copied to `$LFS/sources/`
1. **Environment Prep** - Directories created, essential files seeded (`/etc/passwd`, `/etc/group`, etc.)
1. **Virtual Filesystems** - Chroot helper mounts `/dev`, `/proc`, `/sys`, `/run`
1. **Package Extraction** - Each tarball extracted inside chroot
1. **Build Execution** - Standard `./configure && make && make install` inside chroot
1. **Cleanup** - Temporary files removed, ownership corrected

## 🔍 Build Details

### Chroot Infrastructure

Chapter 7 uses the `lfs_chroot_step` macro for all builds:

```python
lfs_chroot_step(
    name = "perl",
    cmd = """
        cd /sources/perl-5.40.0
        ./Configure -des -Dprefix=/usr ...
        make -j$(nproc)
        make install
    """,
    deps = [":extract_perl"],  # Extraction happens first
)
```

**How it works:**

1. Generates `inner.sh` with build commands and environment setup
1. Generates `wrapper.sh` that calls the chroot helper
1. Helper script mounts virtual filesystems (if not already mounted)
1. Enters chroot and executes `inner.sh`
1. Creates `.done` marker file for Bazel caching

### Environment Inside Chroot

```bash
HOME="/root"
LC_ALL="C"
PATH="/usr/bin:/usr/sbin:/bin:/sbin"
TERM="linux"
LFS="/"  # Inside chroot, we ARE the root!
```

The `temp_tools_toolchain` from Chapter 6 provides additional environment variables.

## 🧪 Testing

### Smoke Test

Verify the chroot environment works:

```bash
bazel test //packages/chapter_07:chroot_smoke_test
```

This test:

- Mounts virtual filesystems
- Enters chroot
- Runs basic commands (`bash --version`, `id`)
- Unmounts cleanly

### Version Validation

Check all packages installed correctly:

```bash
bazel run //packages/chapter_07:chroot_smoke_versions
```

Expected output:

```
bison (GNU Bison) 3.8.2
gettext (GNU gettext-runtime) 0.22.5
version='5.40.0';
Python 3.12.4
texi2any (GNU texinfo) 7.1
lsblk from util-linux 2.40.2
```

## 🐛 Troubleshooting

### "Permission denied" errors

**Problem:** Chroot helper can't be executed with sudo.

**Solution:** Check sudoers configuration:

```bash
sudo visudo -c  # Validate syntax
sudo -l         # List your sudo permissions
```

### "Mount already exists" errors

**Problem:** Virtual filesystems from previous build still mounted.

**Solution:** Unmount manually:

```bash
sudo src/tools/lfs-chroot-helper.sh unmount-vfs $(pwd)/src/sysroot
```

### Package build fails inside chroot

**Problem:** Build command fails with "command not found".

**Solution:** Ensure Chapter 6 temporary tools are fully built:

```bash
bazel build //packages/chapter_06:all_temp_tools
ls -la src/sysroot/usr/bin/  # Verify tools exist
```

### Chroot helper script not found

**Problem:** `lfs-chroot-helper.sh` path is relative, not absolute.

**Solution:** Use absolute path in sudoers and wrapper scripts.

## 📊 Package Details

### Gettext 0.22.5

- **Build Time:** ~2 minutes
- **Install Size:** ~50 MB
- **Purpose:** Provides `msgfmt`, `xgettext`, and other i18n tools

### Bison 3.8.2

- **Build Time:** ~1 minute
- **Install Size:** ~15 MB
- **Purpose:** Parser generator for building compilers

### Perl 5.40.0

- **Build Time:** ~3-5 minutes
- **Install Size:** ~150 MB
- **Purpose:** Scripting language used by many configure scripts

### Python 3.12.4

- **Build Time:** ~5-10 minutes (with optimizations)
- **Install Size:** ~400 MB
- **Purpose:** Required by Meson and modern build systems

### Texinfo 7.1

- **Build Time:** ~1 minute
- **Install Size:** ~30 MB
- **Purpose:** Creates documentation in various formats

### Util-linux 2.40.2

- **Build Time:** ~2 minutes
- **Install Size:** ~100 MB
- **Purpose:** Essential utilities like `mount`, `lsblk`, `fdisk`

## 🔜 Next Steps

After completing Chapter 7:

1. **Backup your sysroot** - Create a tarball of `src/sysroot/` for safety
1. **Move to Chapter 8** - Build the final system (~80 packages)
1. **Stripping** - Remove debug symbols to save space (optional)

## 📖 Appendix

### LFS Book Reference

- [Chapter 7.2 - Changing Ownership](https://www.linuxfromscratch.org/lfs/view/12.2/chapter07/changingowner.html)
- [Chapter 7.3 - Preparing Virtual Kernel File Systems](https://www.linuxfromscratch.org/lfs/view/12.2/chapter07/kernfs.html)
- [Chapter 7.4 - Entering the Chroot Environment](https://www.linuxfromscratch.org/lfs/view/12.2/chapter07/chroot.html)
- [Chapter 7.5-7.13 - Package Builds](https://www.linuxfromscratch.org/lfs/view/12.2/chapter07/gettext.html)

### Related Documentation

- **[docs/tools.md](tools.md)** - Chroot rule reference
- **[DESIGN.md](../DESIGN.md)** - Chroot architecture
- **[docs/status.md](status.md)** - Overall build status

______________________________________________________________________

**Status:** Chapter 7 complete! Ready for Chapter 8. 🎉
