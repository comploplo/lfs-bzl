# 🏗️ LFS 13.0 Build Status Tracker

**Overall Progress:** ██████████ 100% (All Chapters Complete!) 🎉

**Last Updated:** 2026-07-20
**Target:** Linux From Scratch 13.0 (systemd); complete build and boot verified on native aarch64/Apple Silicon
**Build System:** Bazel "Managed Chaos" Architecture
**Sudo Required:** ❌ No! Entire build runs with rootless Podman

## Design Decisions

| Decision | Choice | Rationale |
| ------------- | ------------ | ------------------------------------------------- |
| Init System | **systemd** | Modern, widely-used init system |
| Strip Command | **Skipped** | Optional per LFS book, preserves debug symbols |
| Test Failures | **Accepted** | Some tests fail in chroot - expected per LFS docs |

## Phase 1: Infrastructure ✅ COMPLETE

| Task | Status | Notes |
| ----------------- | ------ | ----------------------------------------------------- |
| Clone LFS Book | ✓ Done | Submodule pinned to 12.2 branch (recipes follow 13.0) |
| Tracker Setup | ✓ Done | Logs written to bazel-out/lfs-logs/ |
| Sysroot Structure | ✓ Done | tools/, sources/, build/ created |
| Starlark Rules | ✓ Done | lfs_package + macros; chroot via rootless Podman worker |
| Bazel Module | ✓ Done | Bzlmod `MODULE.bazel` setup complete |
| Hello World Test | ✓ Done | Builds, installs to sysroot/tools/bin |
| Bazel Run Support | ✓ Done | `bazel run` executes from sysroot |
| Host Prereq Check | ✓ Done | `bazel build //packages/chapter_02:version_check` |
| Podman Worker | ✓ Done | Rootless Bazel JSON worker (single instance) |

## Phase 2: Package Definitions (Chapter 3) ✅ COMPLETE

All ~100 package sources defined as `http_file` rules in `src/MODULE.bazel`.

## Phase 3: Directory Setup (Chapter 4) ✅ COMPLETE

| Task | Status | Notes |
| ------------------------------- | ------ | ------------------------------------------------------ |
| Create $LFS directory structure | ✓ Done | `//packages/chapter_04:lfs_root_skeleton` tar scaffold |
| Set up build environment | ✓ Done | `lfs_env_exports` generated env file |
| User configuration | ✓ Done | Using host user with rootless Podman |

## Phase 4: Cross-Toolchain (Chapter 5) ✅ COMPLETE

**Goal:** Build a toolchain in the worker container that targets LFS

| Package | Status | Notes |
| -------------------------- | ------- | ---------------------------------------------- |
| Binutils Pass 1 | ✅ Done | Uses lfs_autotools macro with phase="ch5" |
| GCC Pass 1 | ✅ Done | Bundled gmp/mpfr/mpc; creates libgcc_s symlink |
| Linux Headers | ✅ Done | Installs headers into `$LFS/usr/include` |
| Glibc | ✅ Done | Out-of-tree build targeting `$LFS/usr` |
| Libstdc++ | ✅ Done | From GCC tree; installs into `$LFS/usr/lib` |
| **LFS Toolchain Provider** | ✅ Done | `cross_toolchain` provider for later chapters |

## Phase 5: Temporary Tools (Chapter 6) ✅ COMPLETE

**Goal:** Build additional temporary tools using cross-toolchain

| Package | Status | Notes |
| --------------- | ------- | ---------------------------------- |
| M4 | ✅ Done | Macro processor |
| Ncurses | ✅ Done | Builds host tic before cross build |
| Bash | ✅ Done | Depends on ncurses |
| Coreutils | ✅ Done | Moves chroot binary to /usr/sbin |
| Diffutils | ✅ Done | |
| File | ✅ Done | Host FILE_COMPILE built first |
| Findutils | ✅ Done | |
| Gawk | ✅ Done | Prunes extras |
| Grep | ✅ Done | |
| Gzip | ✅ Done | |
| Make | ✅ Done | Without guile |
| Patch | ✅ Done | |
| Sed | ✅ Done | |
| Tar | ✅ Done | |
| Xz | ✅ Done | |
| Binutils Pass 2 | ✅ Done | Rebuild with full utils |
| GCC Pass 2 | ✅ Done | Enables POSIX threads |

## Phase 6: Chroot Base System (Chapter 7) ✅ COMPLETE

| Task | Status | Notes |
| -------------------------- | ------- | --------------------------------------------------------- |
| Implement Podman worker | ✅ Done | Rootless Bazel JSON worker in Podman container |
| Create chroot setup target | ✅ Done | chroot_prepare creates dirs, seeds files, symlinks |
| Verify chroot environment | ✅ Done | chroot_smoke_versions validates all package installations |
| Build Gettext | ✅ Done | i18n tools (version 1.0) |
| Build Bison | ✅ Done | Parser generator (version 3.8.2) |
| Build Perl | ✅ Done | Scripting language (version 5.42.0) |
| Build Python | ✅ Done | Modern build system requirement (version 3.14.3) |
| Build Texinfo | ✅ Done | Documentation system (version 7.2) |
| Build Util-linux | ✅ Done | System utilities (version 2.41.3) |
| Chapter 7 cleanup | ✅ Done | `chroot_cleanup` removes libtool archives + temp files |

## Phase 7: Final System (Chapter 8) ✅ COMPLETE

**Goal:** Build the complete OS inside chroot (79 packages)

| Phase | Packages | Status | Notes |
| ------------------------------ | -------- | ------- | --------------------------------------- |
| Phase 2: Core Foundation | 17 | ✅ Done | glibc, compression libs, test framework |
| Phase 3: Toolchain & Security | 16 | ✅ Done | binutils, gcc, security libs |
| Phase 4: Build System & Python | 24 | ✅ Done | perl, python, meson/ninja |
| Phase 5: System Services | 20 | ✅ Done | systemd, dbus, utilities |
| Phase 6: Final Packages | 2 | ✅ Done | util_linux, e2fsprogs |

**Critical Path:** glibc → binutils → gcc → everything else

**Aggregate Targets:**

- `//packages/chapter_08:chapter_08` - All 79 packages
- `//packages/chapter_08:toolchain` - Final system toolchain

### Test Coverage

| Metric | Count |
| ---------------------- | ----- |
| Packages with tests | 57 |
| Packages without tests | 22 |
| Test coverage | 73% |

### Expected Test Failures (Per LFS Book)

These failures are **expected and acceptable** - they occur due to chroot limitations:

| Package | Expected Failures | Reason |
| --------- | ------------------------------ | ------------------ |
| glibc | `io/tst-lchmod`, timeout tests | Chroot environment |
| binutils | ~12 gold linker tests | PIE/SSP enabled |
| gcc | Some analyzer tests | CPU-feature-dependent |
| coreutils | `preserve-mode.sh`, `acl.sh` | Chroot only |

See [docs/troubleshooting.md](troubleshooting.md) for full details on expected test failures.

## Phase 8: System Configuration (Chapter 9) ✅ COMPLETE

| Task | Status | Notes |
| --------------------- | ------- | ----------------------------------------- |
| Network configuration | ✅ Done | systemd-networkd (DHCP) |
| Locale setup | ✅ Done | /etc/locale.conf (en_US.UTF-8) |
| systemd configuration | ✅ Done | /etc/adjtime, /etc/vconsole.conf |
| /etc files | ✅ Done | /etc/hosts, /etc/fstab, /etc/shells, etc. |

## Phase 9: Making Bootable (Chapter 10) ✅ COMPLETE

| Task | Status | Notes |
| --------------- | ------- | ------------------------------------------------------------ |
| /etc/fstab | ✅ Done | Created in Chapter 9 (root by `LABEL=lfs-root`) |
| Kernel config | ✅ Done | systemd + initramfs + EFI/GPT via scripts/config |
| Linux kernel | ✅ Done | 6.18.10 built with systemd support, `CONFIG_LOCALVERSION` |
| initramfs | ✅ Done | `mkinitramfs` + LFS-built `cpio` (see below) |
| USB modprobe | ✅ Done | /etc/modprobe.d/usb.conf |
| GRUB bootloader | ✅ Done | Reference grub.cfg + UEFI `BOOTAA64.EFI` (aarch64; `BOOTX64.EFI` on x86_64) via grub-mkstandalone |

**Kernel installed at:** `/boot/vmlinuz-6.18.10-lfs-13.0-systemd`
**initramfs installed at:** `/boot/initramfs-6.18.10-lfs-13.0-systemd.img`

The canonical kernel-release string `6.18.10-lfs-13.0-systemd` is shared by
`uname -r`, `/usr/lib/modules/`, `vmlinuz-…`, and `initramfs-….img` so they all
agree.

## Phase 10: Finalization (Chapter 11) ✅ COMPLETE

| Task | Status | Notes |
| ---------------- | ------- | ----------------------------------------- |
| /etc/lfs-release | ✅ Done | Version identifier (13.0-systemd) |
| /etc/lsb-release | ✅ Done | Linux Standards Base compliance |
| /etc/os-release | ✅ Done | systemd/desktop environment compatibility |
| UEFI disk image | ✅ Done | `//packages/chapter_11:bootable` -> `sysroot/lfs-uefi.img` (self-booting) |
| Raw disk image | ✅ Done | `//packages/chapter_11:bootable_quick` (alias `:create_disk_image`, `-kernel` fallback) |

## 🎉 What's Next?

The LFS build is **complete**. The sysroot contains a bootable Linux 13.0-systemd system.

> Boot-verified 2026-07-07 on Apple Silicon (QEMU + hvf + edk2-aarch64-code.fd):
> UEFI → GRUB 2.14 (BOOTAA64.EFI) → Linux 6.18.10-lfs-13.0-systemd → initramfs →
> systemd reached Multi-User target and presented `lfs login:`.

**Primary — self-booting UEFI image (QEMU + aarch64 UEFI firmware):**

```bash
# Build the self-booting UEFI disk image -> sysroot/lfs-uefi.img
# (kernel + initramfs + GRUB EFI built in-chroot; container only packages the
#  GPT/FAT ESP via mtools/sgdisk/dd — rootless, no loop devices)
bazel build //packages/chapter_11:bootable

# Homebrew qemu ships the aarch64 UEFI firmware (edk2-aarch64-code.fd)
qemu-system-aarch64 -M virt -cpu host -accel hvf -m 4G \
  -drive if=pflash,format=raw,readonly=on,file="$(brew --prefix)/share/qemu/edk2-aarch64-code.fd" \
  -drive file=sysroot/lfs-uefi.img,format=raw,if=virtio \
  -nographic

# Exit QEMU: Ctrl-a x
# Note: the embedded GRUB config does not pin console=ttyAMA0 on the kernel
# command line; if no output appears after GRUB with -nographic, drop
# -nographic and add -device virtio-gpu-pci for a graphical console.
```

**Fast-iteration fallback — raw ext4 + `-kernel` injection:**

```bash
# Raw image (aliases: :bootable_quick or :create_disk_image)
bazel build //packages/chapter_11:bootable_quick

qemu-system-aarch64 -M virt -cpu host -accel hvf -m 4G \
  -kernel sysroot/boot/vmlinuz-6.18.10-lfs-13.0-systemd \
  -initrd sysroot/boot/initramfs-6.18.10-lfs-13.0-systemd.img \
  -append "root=LABEL=lfs-root rw console=ttyAMA0" \
  -drive file=sysroot/lfs.img,format=raw,if=virtio \
  -nographic

# Exit QEMU: Ctrl-a x
```

**To boot on real hardware:**

1. Write `sysroot/lfs-uefi.img` to a physical disk (it already contains a GPT,
   an EFI System Partition with `\EFI\BOOT\BOOTAA64.EFI`, and the ext4 root
   labeled `lfs-root`)
1. Boot the machine in UEFI mode — firmware picks up the removable-media
   fallback path automatically (no GRUB install / NVRAM entry needed)
1. Reboot!

**Optional next steps:**

- Build BLFS packages for additional functionality
- Add custom packages or configurations

## 📊 Build Logs

Build logs are written under the Bazel execroot in `bazel-out/lfs-logs/`.

```bash
# View logs for a specific package
cat bazel-out/lfs-logs/gcc.log

# List all build logs
ls -lh bazel-out/lfs-logs/
```

## ⚠️ Important: Cache Consistency

The sysroot and Bazel cache must stay in sync. If you need to rebuild:

```bash
# Always clean BOTH together
rm -rf sysroot/
bazel clean --expunge
```

If you clean only the Bazel cache but keep the sysroot, install scripts may fail when files already exist.

## 🚀 Quick Commands

```bash
cd src

# Build everything up to Chapter 11
bazel build //packages/chapter_05:cross_toolchain
bazel build //packages/chapter_06
bazel build //packages/chapter_07
bazel build //packages/chapter_08:chapter_08
bazel build //packages/chapter_09
bazel build //packages/chapter_10
bazel build //packages/chapter_11

# Create the primary self-booting UEFI image
bazel build //packages/chapter_11:bootable

# Test the cross-toolchain
bazel run //packages/hello_world:hello_cross

# No sudo required; all phases use the rootless Podman worker
```

## 📊 Progress Metrics

- **Packages Defined:** ~100 (100%)
- **Packages Built:** 107+ (100%)
- **Chapters Complete:** 11 of 11 (100%) 🎉
- **Lines of Starlark:** ~1,800 (modularized into focused files)
- **Verified release path:** aarch64 on Apple Silicon; x86_64 remains unverified end-to-end

## 📖 Related Documentation

- **[DESIGN.md](../DESIGN.md)** - Architecture overview
- **[docs/tools.md](tools.md)** - Build rules reference
- **[docs/chroot.md](chroot.md)** - Chapter 7: Entering Chroot guide
- **[docs/troubleshooting.md](troubleshooting.md)** - Common issues and expected test failures
