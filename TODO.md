# Code Review Findings

Review date: 2026-02-17

## Critical

| # | Issue | Location |
|---|-------|----------|
| 1 | **systemd srcs ordering bug**: `@systemd_man_pages//file` listed before `@systemd_src//file`, but lfs_package uses the first tarball to set SRC_DIR. Build cds into the wrong directory. | chapter_08/BUILD:1603 |
| 2 | **Disk image recursive inclusion**: `truncate -s 4G /lfs.img` then `mke2fs -d /` copies the entire root including `/lfs.img` into itself. | chapter_11/BUILD |
| 3 | **bzip2 double-patching**: `patches` attr applies the install_docs patch, then `configure_cmd` applies the same patch again via `patch -Np1`. Second apply will fail. | chapter_08/BUILD:199,213 |
| 4 | **coreutils broken patch reference**: `configure_cmd` references `coreutils-9.5-i18n-2.patch` by relative name, but the patch is applied via `patches` from the execroot. File won't exist at that path. | chapter_08/BUILD:1293 |
| 5 | **Containerfile COPY path wrong**: `COPY scripts/worker.py` but file is at `worker.py` relative to the build context (tools/podman/). | podman/Containerfile:19 |
| 6 | **MAKEFLAGS not shell-expanded**: `-j$(nproc)` passed as literal string via `env -i` to subprocess.run. Never expanded. Fix: `f'-j{os.cpu_count()}'`. | podman/worker.py:246 |
| 7 | **Fstab / disk image mismatch**: Fstab uses `/dev/sda1` and `/dev/sda2`, but the disk image has no partition table. QEMU boots as `/dev/sda`. Init will fail to remount. | chapter_09/BUILD:212 |

## High Priority

### Starlark Rules

| # | Issue | Location |
|---|-------|----------|
| 8 | **No phase validation**: `phase` attr is free-form string. `phase = "ch7"` silently treated as non-chroot. Add `values = ["ch5", "ch6", "chroot"]`. | lfs_package.bzl:332 |
| 9 | **Eager depset flattening**: `.to_list()` called at analysis time on depsets. O(n^2) across 80-package chain. Use `depset(transitive=...)` passed to inputs. | lfs_package.bzl:79, lfs_toolchain.bzl:51 |
| 10 | **Stale lfs_chroot.bzl export**: `exports_files` references nonexistent file. Causes Bazel loading error. | tools/BUILD:6 |
| 11 | **phase_defaults() silent fallback**: Unknown phases fall back to ch6 defaults. Typo `"chroo"` gets wrong destdir/prefix. Should `fail()`. | lfs_defaults.bzl:38 |
| 12 | **Test package drops cmd file attrs**: `configure_cmd_file`, `build_cmd_file`, `install_cmd_file` not forwarded to test target. Test gets `"true"` instead. | lfs_package.bzl:420 |

### BUILD Files

| # | Issue | Location |
|---|-------|----------|
| 13 | **lfs_configure_make forces out-of-tree builds**: Default `build_subdir = "build"` does `mkdir build && cd build && ../configure`. Many packages (m4, xz, sed, grep, etc.) expect in-tree builds per LFS book. | lfs_macros.bzl:62 |
| 14 | **Chapter 7 util_linux missing path flags**: No `--bindir=/usr/bin --sbindir=/usr/sbin` or `--prefix=/usr`. Autotools defaults to `/usr/local/...`. | chapter_07/BUILD:279 |
| 15 | **Chapter 8 groff missing :perl dep**: Groff uses perl scripts during build. | chapter_08/BUILD:1401 |
| 16 | **Chapter 8 grub missing deps**: Needs `:bison`, `:flex`, `:python`. | chapter_08/BUILD:1422 |
| 17 | **Chapter 8 systemd missing :libelf dep** | chapter_08/BUILD:1653 |

### Podman Worker

| # | Issue | Location |
|---|-------|----------|
| 18 | **No response on JSON decode error**: Logs to stderr but no stdout response. Bazel hangs. | worker.py:321 |
| 19 | **--privileged is overly broad**: Could use `--cap-add SYS_ADMIN --cap-add SYS_CHROOT` instead. | worker_launcher.sh.tpl:95 |
| 20 | **Timeout doesn't kill child processes**: subprocess.run timeout kills chroot but not make/gcc inside. Use `start_new_session=True` + `os.killpg`. | worker.py:258 |

## Medium Priority

### Security

| # | Issue | Location |
|---|-------|----------|
| 21 | **Command injection via env values**: `export {}="{}"` with double quotes. Values with `"`, `$`, backticks break out. Use single quotes or shell-escape. | lfs_package.bzl:100 |
| 22 | **SELinux disabled, no seccomp**: `--security-opt label=disable` and `--privileged` relax container isolation. Document as known relaxation. | worker_launcher.sh.tpl:97 |

### Correctness

| # | Issue | Location |
|---|-------|----------|
| 23 | **Chapter 9 targets depend on :toolchain not //packages/chapter_08**: inputrc, shells, systemd configs could execute before chapter 8 completes. | chapter_09/BUILD |
| 24 | **4GB disk image may be too small**: Full LFS with kernel docs can exceed 4GB. LFS book recommends 10GB+. | chapter_11/BUILD |
| 25 | **Missing kernel config options**: AUTOFS_FS, SECCOMP, EXT4_FS, BLK_DEV_LOOP not explicitly enabled. May be covered by defconfig but not guaranteed. | chapter_10/BUILD |
| 26 | **Worker missing output field in responses**: Failed builds show no inline diagnostics in Bazel. Include stderr tail. | worker.py:292 |
| 27 | **_create_tester_user unreachable except**: `check=False` means CalledProcessError never raised. except block is dead code. | worker.py:175 |
| 28 | **gcc_pass1 uses --enable-default-ssp**: Not prescribed by LFS 12.2 for pass 1. | chapter_05/BUILD:95 |
| 29 | **destdir = "/" for chroot phase**: `DESTDIR=/ make install` installs to `//usr`. Consider empty string and omitting DESTDIR entirely. | lfs_defaults.bzl:29 |
| 30 | **shell_config missing dep on locale_config**: /etc/profile sources /etc/locale.conf but no declared dependency. | chapter_09/BUILD |
| 31 | **inetutils and intltool missing test commands**: LFS book prescribes `make check` for both. | chapter_08/BUILD |
| 32 | **kbd missing test command**: LFS book says `make check`. | chapter_08/BUILD:1474 |
| 33 | **Runner template inconsistency**: Host runner checks WORKSPACE only; chroot runner checks both WORKSPACE and WORKSPACE.bazel. | lfs_runner_script.sh:12 |

### Documentation

| # | Issue | Location |
|---|-------|----------|
| 34 | **DESIGN.md outdated**: Chapters 9-11 missing. Stale "future work" checkboxes. References removed lfs-chroot-helper.sh. Appendix missing lfs_script.bzl, lfs_macros.bzl, lfs_toolchain.bzl. | DESIGN.md |
| 35 | **README references stale targets**: chroot_toolchain_phase and chroot_finalize may not exist. Line 326 mentions sudo despite "no sudo" claim. | README.md:277,318,326 |
| 36 | **README says "Bazel 6.0+"**: bzlmod with rules_python 1.7.0 likely requires Bazel 7.x. | README.md:44 |
| 37 | **Stale docstring reference**: References lfs_chroot.bzl which no longer exists. | lfs_toolchain.bzl:14 |

## Low Priority

### Code Cleanup

| # | Issue | Location |
|---|-------|----------|
| 38 | **WORK_DIR vs WORKDIR confusion**: Two different directories with near-identical names. Rename WORK_DIR to LFS_TMPDIR. | lfs_package_build.sh.tpl:144,158 |
| 39 | **Hardcoded kernel version in 6+ places**: Should be a Starlark constant. | chapter_10, chapter_09, README |
| 40 | **Hardcoded x86_64-lfs-linux-gnu**: Should be a template parameter from the toolchain. | lfs_package_build.sh.tpl:47 |
| 41 | **Hardcoded sysroot path**: `sysroot_path = "sysroot"` should be a constant or toolchain attr. | lfs_package.bzl:71 |
| 42 | **Dead MODULE.bazel entries**: sysklogd_src and sysvinit_consolidated_patch defined but unused. | MODULE.bazel:549,605 |
| 43 | **Duplicate gcc tarball**: gcc_src and libstdcpp_src download identical gcc-14.2.0.tar.xz. | MODULE.bazel |
| 44 | **_render_test is a no-op**: Returns input unchanged. Remove or implement. | lfs_macros.bzl:111 |
| 45 | **Redundant phase assignment**: `phase = ctx.attr.phase` read twice. | lfs_package.bzl:182,207 |
| 46 | **lfs_script.bzl not in exports_files** | tools/BUILD |
| 47 | **lfs_script.bzl abuses install_cmd**: Script runs as install_cmd; prints misleading "Installing..." echo. | lfs_script.bzl:36 |
| 48 | **ch8_smoke_versions uses /tmp/**: Could use $PWD instead. | chapter_08/BUILD:1845 |
| 49 | **ch8_smoke_versions should use lfs_script**: Uses lfs_package with no srcs as a pure script. | chapter_08/BUILD:1822 |
| 50 | **Magic line number in binutils_pass2**: `sed '6031s/...'` is version-specific and fragile. | chapter_06/BUILD:323 |

### Infrastructure

| # | Issue | Location |
|---|-------|----------|
| 51 | **Single mirror URLs**: Most packages have one URL. Add GNU mirrors or anduin.linuxfromscratch.org as fallback. | MODULE.bazel |
| 52 | **No Python linting in pre-commit**: worker.py, worker_test.py, version_check_test.py unlinted. Add ruff or flake8. | .pre-commit-config.yaml |
| 53 | **Shallow worker test coverage**: Missing timeout, signal, JSON decode, script staging, integration tests. | worker_test.py |
| 54 | **lfs_runner_script.sh missing set -euo pipefail**: Chroot runner has it; host runner does not. | lfs_runner_script.sh:1 |
| 55 | **Container name collision risk**: `lfs-worker-$(date +%s)-$$` could collide. Add $RANDOM. | worker_launcher.sh.tpl:36 |
| 56 | **build_container.sh fallback path broken**: Direct execution resolves PODMAN_DIR incorrectly. | build_container.sh:17 |
| 57 | **Trap quoting in build template**: `trap "rm -rf $WORK_DIR" EXIT` expands at definition time. Use single quotes. | lfs_package_build.sh.tpl:146 |
| 58 | **requestId default of 0**: Missing requestId is a protocol violation. Should log a warning. | worker.py:229 |
| 59 | **Redundant chapter 6/7 deps**: chroot_seed_files and chroot_cleanup_tmp redundantly declare //packages/chapter_06. | chapter_07/BUILD |
| 60 | **Hello world source duplication**: stage_hello_in_sysroot inlines C source with different message than hello.c. | hello_world/BUILD |
