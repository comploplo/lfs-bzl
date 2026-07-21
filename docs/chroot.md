# 🚪 Chapter 7: Entering Chroot

**Status:** ✅ Complete (6 packages built)
**Build Environment:** Rootless Podman worker (no sudo required)
**Execution:** Inside chroot using temporary tools from Chapter 6

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

| Package | Purpose | Why Now? |
| -------------- | ---------------------------------------------------------- | ---------------------------------- |
| **Gettext** | Internationalization (i18n) and localization tools | Required by many Chapter 8 builds |
| **Bison** | Parser generator (creates compilers from grammar files) | Used by several build systems |
| **Perl** | Powerful scripting language | Many configure scripts use Perl |
| **Python** | Modern programming language | Modern build systems (Meson, etc.) |
| **Texinfo** | Documentation system (creates info, HTML, PDF from source) | Needed for package documentation |
| **Util-linux** | Essential system utilities (mount, lsblk, etc.) | Core system management tools |

## 🏗️ Build Process

### Prerequisites

Before building Chapter 7, ensure:

- ✅ Rootless Podman configured (test with `podman run --rm hello-world`)
- ✅ Chapter 6 temporary tools built: `bazel build //packages/chapter_06`
- Build Chapter 7 end-to-end: `bazel build //packages:bootstrap_ch7`
- Or run just Chapter 7: `bazel build //packages/chapter_07:chroot_cleanup`

### No Sudo Required!

Chapter 7 uses the rootless Podman worker system - the same system used for Chapter 8+. All builds run as a regular user with no sudo requirements.

**How it works:**

- Podman creates a rootless container with user namespaces
- Inside the container namespace, processes run as root
- Container mounts virtual filesystems (`/dev`, `/proc`, `/sys`, `/run`)
- All chroot operations happen inside the container (no host sudo needed)

### Build Commands

```bash
cd src

# 1. Prepare the chroot environment (create directories, seed files)
bazel build //packages/chapter_07:chroot_prepare

# 2. Build all Chapter 7 packages (serialized through the Podman worker)
bazel build //packages/chapter_07

# 3. Verify installations
bazel build //packages/chapter_07:chroot_smoke_versions

# 4. (Optional) Perform Chapter 7 cleanup (removes libtool archives, /tools)
bazel build //packages/chapter_07:chroot_cleanup
```

**Note:** No source staging needed! The `lfs_package` rule automatically extracts tarballs from Bazel's external repos.

### What Happens During Build

1. **Podman Worker Launch** - Rootless container starts with Bazel JSON worker protocol
1. **Environment Prep** - Directories created, essential files seeded (`/etc/passwd`, `/etc/group`, etc.)
1. **Virtual Filesystems** - Container mounts `/dev`, `/proc`, `/sys`, `/run`
1. **Package Extraction** - Tarballs extracted from Bazel external repos
1. **Build Execution** - Commands run inside chroot following LFS book
1. **Cleanup** - If requested, removes libtool archives and `/tools`

**Serialized worker:** These actions share one mutable sysroot, so `.bazelrc`
limits the `LfsWorkerBuild` mnemonic to one worker instance.

## 🔍 Build Details

### Chroot Infrastructure

Chapter 7 uses the `lfs_package` macro with `phase="chroot"` for all builds:

```python
lfs_package(
    name = "perl",
    phase = "chroot",
    srcs = ["@perl_src//file"],
    configure_cmd = "./Configure -des -Dprefix=/usr ...",
    build_cmd = "make -j$(nproc)",
    install_cmd = "make install",
    deps = [":chroot_prepare"],
)
```

**How it works:**

1. Worker launcher creates Podman container with Bazel JSON worker protocol
1. Container mounts sysroot at `/lfs` and virtual filesystems
1. Build script extracts source tarball and sets up environment
1. Executes configure, build, and install commands inside chroot
1. Creates `.done` marker file for Bazel caching
1. Worker stays alive across builds for performance

**Key Advantage:** No sudo required! Podman's user namespaces allow chroot operations without host privileges.

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

### Version Validation

Check all packages installed correctly:

```bash
bazel build //packages/chapter_07:chroot_smoke_versions
```

Expected output (in build log):

```
bison (GNU Bison) 3.8.2
msgfmt (GNU gettext-tools) 1.0
version='5.42.0';
Python 3.14.3
info (GNU texinfo) 7.2
lsblk from util-linux 2.41.3
```

## 🐛 Troubleshooting

### Podman worker won't start

**Problem:** Container fails to start or worker crashes.

**Solution:** Verify rootless Podman is configured:

```bash
podman --version  # Should be 3.0+
podman run --rm hello-world  # Test basic functionality
```

See [docs/troubleshooting.md](troubleshooting.md) for detailed Podman setup.

### Package build fails inside chroot

**Problem:** Build command fails with "command not found".

**Solution:** Ensure Chapter 6 temporary tools are fully built:

```bash
bazel build //packages/chapter_06
ls -la sysroot/usr/bin/  # Verify tools exist
```

### "configure: cannot execute" errors

**Problem:** Configure scripts fail with "cannot execute: required file not found".

**Solution:** Verify essential symlinks exist. The preparation step should create:

- `/bin` → `/usr/bin`
- `/bin/sh` → `/usr/bin/bash`
- `/bin/bash` → `/usr/bin/bash`

If missing, rebuild: `bazel build //packages/chapter_07:chroot_prepare`

______________________________________________________________________

## 🔄 Sysroot Ownership

**Good News:** With the Podman worker approach, sysroot ownership is no longer a concern!

### How Podman Solves Ownership Issues

- **Chapter 5-6:** Builds run in container mode and write to the mounted sysroot
- **Chapter 7+:** Podman uses user namespaces to run chroot operations as root inside the container
- **No chown needed:** Sysroot remains owned by your user throughout the entire build process

### Benefits

✅ **No sudo required** - Entire build runs as regular user
✅ **No ownership transitions** - Sysroot ownership never changes
✅ **Simpler iteration** - Can rebuild any chapter without permission issues
✅ **Better security** - No need to grant sudo permissions

______________________________________________________________________

## 📊 Package Details

### Gettext 1.0

- **Build Time:** ~2 minutes
- **Install Size:** ~50 MB
- **Purpose:** Provides `msgfmt`, `xgettext`, and other i18n tools

### Bison 3.8.2

- **Build Time:** ~1 minute
- **Install Size:** ~15 MB
- **Purpose:** Parser generator for building compilers

### Perl 5.42.0

- **Build Time:** ~3-5 minutes
- **Install Size:** ~150 MB
- **Purpose:** Scripting language used by many configure scripts

### Python 3.14.3

- **Build Time:** ~5-10 minutes (with optimizations)
- **Install Size:** ~400 MB
- **Purpose:** Required by Meson and modern build systems

### Texinfo 7.2

- **Build Time:** ~1 minute
- **Install Size:** ~30 MB
- **Purpose:** Creates documentation in various formats

### Util-linux 2.41.3

- **Build Time:** ~2 minutes
- **Install Size:** ~100 MB
- **Purpose:** Essential utilities like `mount`, `lsblk`, `fdisk`

## 📖 Appendix

### LFS Book Reference

- [Chapter 7.2 - Changing Ownership](https://www.linuxfromscratch.org/lfs/view/13.0-systemd/chapter07/changingowner.html)
- [Chapter 7.3 - Preparing Virtual Kernel File Systems](https://www.linuxfromscratch.org/lfs/view/13.0-systemd/chapter07/kernfs.html)
- [Chapter 7.4 - Entering the Chroot Environment](https://www.linuxfromscratch.org/lfs/view/13.0-systemd/chapter07/chroot.html)
- [Chapter 7.5-7.13 - Package Builds](https://www.linuxfromscratch.org/lfs/view/13.0-systemd/chapter07/gettext.html)

### Related Documentation

- **[docs/tools.md](tools.md)** - Chroot rule reference
- **[DESIGN.md](../DESIGN.md)** - Chroot architecture
- **[docs/status.md](status.md)** - Overall build status

______________________________________________________________________

**Status:** Chapter 7 complete; Chapters 8–11 and the bootable image are also implemented.
