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

- ✅ Sudo access configured for the chroot helper script
- Build Chapter 7 end-to-end: `bazel build //packages:bootstrap_ch7`
- Or run just Chapter 7: `bazel build //packages/chapter_07:chroot_finalize`

### Sudo Configuration

The chroot helper requires sudo. Add this to `/etc/sudoers.d/lfs-bazel-chroot`:

```bash
<your-user> ALL=(root) NOPASSWD: /path/to/lfs-bzl/src/tools/scripts/lfs_chroot_helper.sh
```

Replace `/path/to/lfs-bzl` with your actual repository path and `<your-user>` with your username.

Note: `NOPASSWD` is convenient for Bazel, but it effectively grants privileged
operations to your user via this helper. Only do this on a machine you trust,
and prefer a dedicated dev VM.

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

# 5. (Optional, destructive) Perform Chapter 7 cleanup (removes /tools)
bazel build //packages/chapter_07:chroot_finalize
```

Note: `//packages/chapter_07:stage_ch7_sources` uses the sudo allowlisted chroot helper
to copy tarballs into the sysroot, since the Chapter 7 preparation steps may leave the
sysroot root-owned.

### What Happens During Build

1. **Source Staging** - Tarballs copied to `$LFS/sources/`
1. **Environment Prep** - Directories created, essential files seeded (`/etc/passwd`, `/etc/group`, etc.)
1. **Virtual Filesystems** - Chroot helper mounts `/dev`, `/proc`, `/sys`, `/run`
1. **Package Extraction** - Each tarball extracted inside chroot
1. **Build Execution** - Commands follow the LFS book for each package
1. **Cleanup** - If requested, removes docs, `.la`, and `/tools`

**Parallel Build Support**: Chapter 7 packages build in parallel. Use `--jobs=N` to control
concurrency if needed. Mount locking prevents conflicts automatically.

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

For longer sequences, keep BUILD files readable by moving the commands into a
`.sh` and using `cmd_file` on `lfs_chroot_step`.

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
msgfmt (GNU gettext-tools) 0.22.5
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
sudo tools/scripts/lfs_chroot_helper.sh unmount-vfs "$(pwd)/sysroot"
```

If you want to keep mounts between steps, set `LFS_CHROOT_KEEP_MOUNTS=1` for
build actions:

```bash
bazel build //packages/chapter_07:chroot_toolchain_phase --action_env=LFS_CHROOT_KEEP_MOUNTS=1
```

### Package build fails inside chroot

**Problem:** Build command fails with "command not found".

**Solution:** Ensure Chapter 6 temporary tools are fully built:

```bash
bazel build //packages/chapter_06:all_temp_tools
ls -la sysroot/usr/bin/  # Verify tools exist
```

### Chroot helper script not found

**Problem:** `lfs_chroot_helper.sh` path is relative, not absolute.

**Solution:** Use absolute path in sudoers and wrapper scripts.

______________________________________________________________________

## 🔄 Sysroot Ownership Lifecycle

Chapter 7's `chroot_chown_root` step changes ownership of the entire sysroot to
root:root. This is required for chroot operations but has implications for your
workflow.

### The Three Ownership States

**State 1: Chapter 5-6 (User-Owned)**

```bash
$ ls -ld src/sysroot/{usr,tools,lib}
drwxrwxr-x user user src/sysroot/usr
drwxrwxr-x user user src/sysroot/tools
drwxrwxr-x user user src/sysroot/lib
```

- Regular user can write to sysroot
- Chapter 5-6 builds work normally
- Cannot enter chroot as unprivileged user

**State 2: Chapter 7+ (Root-Owned)**

```bash
$ ls -ld src/sysroot/{usr,tools,lib}
drwxr-xr-x root root src/sysroot/usr
drwxr-xr-x root root src/sysroot/tools
drwxr-xr-x root root src/sysroot/lib
```

- Only root can write to sysroot
- Chapter 7+ chroot builds work normally
- Chapter 5-6 builds FAIL with "Permission denied"

**State 3: Restored User Ownership (Development)**

```bash
$ sudo chown -R $USER:$USER src/sysroot/
$ ls -ld src/sysroot/{usr,tools,lib}
drwxrwxr-x user user src/sysroot/usr
drwxrwxr-x user user src/sysroot/tools
drwxrwxr-x user user src/sysroot/lib
```

- Back to State 1 (can iterate on Chapter 5-6)
- Must re-run `chroot_chown_root` to return to State 2

### Automatic Detection

The build system automatically detects ownership problems when running
Chapter 5-6 targets:

```bash
$ bazel build //packages/chapter_05:binutils_pass1

================================================================================
ERROR: Sysroot Ownership Problem Detected
================================================================================
[...detailed recovery message...]

RECOVERY:
  Run this command to restore user ownership:

    sudo chown -R $USER:$USER /path/to/sysroot
```

### Best Practices

**For Linear Builds (Ch5 → Ch6 → Ch7 → Ch8):**

- Build forward only, no need to restore ownership
- Create backup after Chapter 6 if you want a rollback point

**For Iterative Development:**

- Use git worktrees for isolated environments
- Or restore ownership as needed between chapter contexts
- Document your current state (user-owned vs root-owned)

**For CI/CD:**

- Build in a single pass (no ownership changes needed)
- Use fresh checkout for each build
- Or use containers with proper permissions

### Troubleshooting FAQ

**Q: Why doesn't Bazel prevent this?**

A: Bazel's dependency graph doesn't enforce ordering across chapters. You can
re-run earlier targets after later ones complete. The ownership check
detects this and provides guidance.

**Q: Can we automate the recovery?**

A: No. Automatic `sudo chown` would be a security risk. The build system
provides clear instructions for manual recovery.

**Q: Will this affect Chapter 8+ builds?**

A: No. Chapter 8+ uses chroot (runs as root inside chroot), so ownership
doesn't matter. This only affects Chapter 5-6 (unsandboxed host builds).

______________________________________________________________________

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

1. **Backup your sysroot** - Create a tarball of `sysroot/` for safety
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
