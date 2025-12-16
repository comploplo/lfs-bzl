# 🔍 LFS Bazel Troubleshooting Guide

Common issues and solutions for building Linux From Scratch with Bazel.

## 📑 Quick Index

- [Build Issues](#-build-issues)
- [Chroot Problems](#-chroot-problems)
- [Dependency Errors](#-dependency-errors)
- [Performance Issues](#%EF%B8%8F-performance-issues)
- [Environment Problems](#-environment-problems)

______________________________________________________________________

## 🏗️ Build Issues

### Build fails with "command not found"

**Symptoms:**

```
/bin/bash: line 42: gcc: command not found
ERROR: Build did NOT complete successfully
```

**Causes:**

1. Previous chapter's packages not built
1. Toolchain provider not properly wired
1. `$PATH` not set correctly

**Solutions:**

```bash
# Check if Chapter 5 cross-toolchain exists
ls -la src/sysroot/tools/bin/x86_64-lfs-linux-gnu-gcc

# Check if Chapter 6 temporary tools exist
ls -la src/sysroot/usr/bin/gcc

# Rebuild from the beginning
cd src
bazel clean
bazel build //packages/chapter_05:cross_toolchain
bazel build //packages/chapter_06:all_temp_tools
```

______________________________________________________________________

### Build succeeds but binary doesn't exist

**Symptoms:**

```
bazel build //packages/hello_world:hello
# Build reports success, but...
./src/sysroot/tools/bin/hello  # File not found
```

**Causes:**

1. `install_cmd` didn't actually install the file
1. Wrong installation path
1. Build ran but install step was skipped

**Solutions:**

```bash
# Check build logs
cat bazel-out/lfs-logs/hello.log

# Look for "Installing" messages
grep -i "install" bazel-out/lfs-logs/hello.log

# Verify the install command in BUILD file
# Make sure it includes: install -D <binary> $LFS/tools/bin/<name>
```

______________________________________________________________________

### "Permission denied" writing to sysroot

**Symptoms:**

```
mkdir: cannot create directory 'sysroot/usr': Permission denied

================================================================================
ERROR: Sysroot Ownership Problem Detected
================================================================================
The sysroot directory has been changed to root ownership...
```

**Root Cause:**

This happens when you try to re-run Chapter 5-6 builds AFTER running Chapter 7's
`chroot_chown_root` step. This is expected behavior, not a bug!

**The Build Lifecycle:**

1. Chapter 5-6: Build as regular user → sysroot owned by user
1. Chapter 7: Run `chroot_chown_root` → sysroot owned by root
1. Attempting Chapter 5-6 again → FAILS (can't write to root-owned dirs)

**Solutions:**

**Option 1: Restore user ownership (recommended for development)**

```bash
# Reclaim ownership of sysroot
sudo chown -R $USER:$USER src/sysroot/

# Verify ownership
ls -ld src/sysroot/usr src/sysroot/tools
# Should show your user, not root

# Now you can re-run Chapter 5-6 builds
bazel build //packages/chapter_05:binutils_pass1
```

**Option 2: Create a checkpoint backup**

```bash
# Before running Chapter 7, create a backup at the Chapter 6 state
cd src
tar czf ../sysroot-ch6-backup.tar.gz sysroot/

# Later, to restore:
cd src
rm -rf sysroot/
tar xzf ../sysroot-ch6-backup.tar.gz
```

**Option 3: Use separate build environments**

```bash
# For iterative Chapter 5-6 development
git worktree add ../lfs-bzl-ch6 HEAD
cd ../lfs-bzl-ch6/src
bazel build //packages/chapter_06:all_temp_tools

# For Chapter 7+ work
cd original-repo/src
bazel build //packages/chapter_07:chroot_toolchain_phase
```

**Important Notes:**

- The build system now detects this issue automatically and provides guidance
- Restoring ownership UNDOES Chapter 7 changes (you'll need to re-run chroot_chown_root)
- This is a natural consequence of the LFS bootstrap process
- Consider your workflow: building forward (Ch5→Ch6→Ch7) vs iterating on early chapters

**See Also:**

- [docs/chroot.md](chroot.md) - Chapter 7 ownership lifecycle explained
- [docs/status.md](status.md) - Known issues

______________________________________________________________________

### Bazel cache issues / stale builds

**Symptoms:**

```
Build reports success but changes not reflected
Old version of binary runs
```

**Solutions:**

```bash
# Nuclear option: clean everything
bazel clean --expunge

# Less aggressive: clean specific target
bazel clean
bazel build //packages/chapter_06:bash

# Force rebuild without cache
bazel build --noremote_accept_cached //packages/chapter_06:bash
```

______________________________________________________________________

## 🚪 Chroot Problems

### "Permission denied" running chroot commands

**Symptoms:**

```
sudo: no tty present and no askpass program specified
ERROR: Build did NOT complete successfully
```

**Causes:**

1. Sudoers not configured for chroot helper
1. Wrong path in sudoers file
1. Sudoers syntax error

**Solutions:**

```bash
# 1. Find the absolute path to the helper script
realpath src/tools/lfs-chroot-helper.sh

# 2. Create sudoers entry (replace paths!)
sudo visudo -f /etc/sudoers.d/lfs-bazel-chroot

# Add this line (use YOUR username and path):
<user> ALL=(root) NOPASSWD: /home/user/lfs-bzl/src/tools/lfs-chroot-helper.sh

# 3. Validate sudoers syntax
sudo visudo -c

# 4. Test sudo access
sudo src/tools/lfs-chroot-helper.sh check-mounts $(pwd)/src/sysroot
```

______________________________________________________________________

### "Mount already exists" or busy mounts

**Symptoms:**

```
mount: /home/user/lfs-bzl/src/sysroot/dev: already mounted
[WARN] /path/to/sysroot/proc is busy, attempting lazy unmount
```

**Causes:**

1. Previous build didn't clean up mounts
1. Build interrupted (Ctrl+C)
1. Multiple parallel builds

**Solutions:**

```bash
# Check what's mounted
mount | grep sysroot

# Unmount everything
sudo src/tools/lfs-chroot-helper.sh unmount-vfs $(pwd)/src/sysroot

# If that fails, force unmount
sudo umount -l src/sysroot/dev/pts
sudo umount -l src/sysroot/dev
sudo umount -l src/sysroot/proc
sudo umount -l src/sysroot/sys
sudo umount -l src/sysroot/run

# Verify clean
mount | grep sysroot  # Should return nothing
```

______________________________________________________________________

### Chroot fails with "failed to run command"

**Symptoms:**

```
chroot: failed to run command '/bin/bash': No such file or directory
```

**Causes:**

1. Chapter 6 temporary tools not built
1. Bash not installed in sysroot
1. Missing library dependencies

**Solutions:**

```bash
# Check if bash exists
ls -la src/sysroot/usr/bin/bash

# Check if libraries exist
ls -la src/sysroot/usr/lib/libc.so*

# Rebuild Chapter 6
bazel build //packages/chapter_06:all_temp_tools

# Check bash can run (may need to set LD_LIBRARY_PATH)
LD_LIBRARY_PATH=src/sysroot/usr/lib src/sysroot/usr/bin/bash --version
```

______________________________________________________________________

### "Invalid argument" when mounting in chroot

**Symptoms:**

```
mount: /home/user/lfs-bzl/src/sysroot/proc: mount point does not exist.
mount: /home/user/lfs-bzl/src/sysroot/dev/pts: invalid argument
```

**Causes:**

1. Mount point directories don't exist
1. Kernel doesn't support devpts/proc
1. Running in container without privileges

**Solutions:**

```bash
# Create mount points
mkdir -p src/sysroot/{dev,proc,sys,run,dev/pts}

# Check kernel support
grep -E "devpts|proc|sysfs|tmpfs" /proc/filesystems

# If in container, make sure it has CAP_SYS_ADMIN
# Docker: docker run --privileged ...
# Podman: podman run --cap-add=SYS_ADMIN ...
```

______________________________________________________________________

## 🔗 Dependency Errors

### "Target not found" errors

**Symptoms:**

```
ERROR: no such target '//packages/chapter_05:cross_toolchain'
```

**Causes:**

1. Typo in target name
1. BUILD file doesn't define that target
1. Wrong package path

**Solutions:**

```bash
# List all targets in a package
bazel query //packages/chapter_05:all

# Search for a target by name
bazel query 'attr(name, ".*cross.*", //...)'

# Check if BUILD file exists
ls src/packages/chapter_05/BUILD
```

______________________________________________________________________

### Circular dependency errors

**Symptoms:**

```
ERROR: Circular dependency between ...
```

**Causes:**

1. Package A depends on B, B depends on A
1. Toolchain dependency cycles

**Solutions:**

```bash
# Visualize dependency graph
bazel query --output=graph 'deps(//packages/chapter_06:bash)' > graph.dot
dot -Tpng graph.dot -o graph.png

# Find dependency path between two targets
bazel query 'somepath(//packages/chapter_05:glibc, //packages/chapter_05:gcc_pass1)'

# Check BUILD files for deps = [...] that might cause cycles
```

______________________________________________________________________

### Missing source files

**Symptoms:**

```
ERROR: /path/to/BUILD:line:column: file '@binutils_src//file' does not exist
```

**Causes:**

1. Network error downloading source
1. Invalid SHA256 checksum
1. Upstream URL changed

**Solutions:**

```bash
# Check Bazel's download cache
ls -lh ~/.cache/bazel/_bazel_*/external/binutils_src/file

# Force re-download
bazel clean --expunge
bazel build //packages/chapter_05:binutils_pass1

# If checksum mismatch, update MODULE.bazel with new SHA256
# Download file manually to check:
wget https://ftpmirror.gnu.org/binutils/binutils-2.43.1.tar.xz
sha256sum binutils-2.43.1.tar.xz
```

______________________________________________________________________

## ⚡️ Performance Issues

### Builds are very slow

**Symptoms:**

- Each package takes 10+ minutes
- CPU not fully utilized
- Disk I/O is slow

**Solutions:**

```bash
# 1. Enable parallel make
# In BUILD files, ensure: make -j$(nproc)

# 2. Check system resources
htop  # Are all cores being used?
iostat -x 1  # Is disk bottlenecked?

# 3. Use faster storage
# Move workspace to SSD if on HDD

# 4. Increase Bazel parallelism
bazel build --jobs=8 //packages/chapter_06:all_temp_tools

# 5. Disable optimizations for testing
# In BUILD files, temporarily remove --enable-optimizations
```

______________________________________________________________________

### Out of memory (OOM) during GCC build

**Symptoms:**

```
ERROR: Worker process did not return a WorkResponse
# Or system becomes unresponsive, other processes killed
```

Check system logs:

```bash
journalctl --user -n 50 | grep -i oom
# Shows: "A process of this unit has been killed by the OOM killer"
```

**Root Cause:**

GCC is extremely memory-hungry. With unlimited parallelism (`make -j$(nproc)`), each
`cc1`/`cc1plus` compiler process can consume 1-2GB RAM. On a system with 16 cores,
this could require 16-32GB RAM simultaneously.

**Solutions:**

The gcc target in `chapter_08/BUILD` is already limited to `-j4` to prevent this:

```python
build_cmd = "cd build && make -j4",  # Limited to prevent OOM
```

If you still hit OOM:

```bash
# Option 1: Further reduce parallelism in chapter_08/BUILD
build_cmd = "cd build && make -j2",

# Option 2: Limit Bazel worker instances globally in .bazelrc
build --worker_max_instances=LfsChrootBuild=1

# Option 3: Add swap space temporarily
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
# After build: sudo swapoff /swapfile && sudo rm /swapfile
```

**Memory Requirements:**

- GCC build with `-j4`: ~8GB RAM recommended
- GCC build with `-j8`: ~16GB RAM recommended
- GCC build with `-j$(nproc)` on 16 cores: 16-32GB RAM

______________________________________________________________________

### Out of disk space

**Symptoms:**

```
No space left on device
```

**Solutions:**

```bash
# Check disk usage
df -h .
du -sh src/sysroot/

# Clean Bazel cache
bazel clean
# Or more aggressive:
bazel clean --expunge

# Remove build logs
rm -rf bazel-out/lfs-logs/*

# Strip debug symbols from binaries (saves GB)
find src/sysroot/usr/bin -type f -executable -exec strip --strip-unneeded {} \;
find src/sysroot/usr/lib -name "*.a" -exec strip --strip-debug {} \;
```

______________________________________________________________________

## 🌍 Environment Problems

### Host toolchain version too old

**Symptoms:**

```
ERROR: Chapter 2 version check failed
gcc version 4.7 is too old (need 4.8+)
```

**Solutions:**

```bash
# Check your versions
gcc --version
g++ --version
make --version

# On Ubuntu/Debian, update:
sudo apt update
sudo apt install build-essential gcc g++ make

# On older systems, install newer gcc from PPA:
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt update
sudo apt install gcc-11 g++-11
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 100
```

______________________________________________________________________

### Locale/encoding errors

**Symptoms:**

```
perl: warning: Setting locale failed.
perl: warning: Please check that your locale settings:
```

**Solutions:**

```bash
# Set proper locale
export LC_ALL=C
export LANG=C

# Or in your ~/.bashrc:
echo 'export LC_ALL=C' >> ~/.bashrc
echo 'export LANG=C' >> ~/.bashrc

# Generate locales (Ubuntu/Debian)
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8
```

______________________________________________________________________

### Bazel version mismatch

**Symptoms:**

```
ERROR: This build requires Bazel 6.0 or later
```

**Solutions:**

```bash
# Check Bazel version
bazel version

# Install latest Bazel (Bazelisk recommended)
npm install -g @bazel/bazelisk
# Or download from: https://github.com/bazelbuild/bazel/releases

# Use specific version with Bazelisk
echo "6.4.0" > .bazelversion
```

______________________________________________________________________

## 🧪 Expected Test Failures

This section documents test failures that are expected and acceptable according to the LFS 12.2 book. Understanding these expected failures helps distinguish between normal behavior and actual problems.

### Critical Test Suites

#### Glibc Tests (CRITICAL - DO NOT SKIP)

**Total Tests**: Over 5000 tests

**Known Acceptable Failures**:

- `io/tst-lchmod` - Always fails in chroot environment (passes in complete system)
- `nss/tst-nss-files-hosts-multi` - May timeout on slow systems
- `nptl/tst-thread-affinity*` - May timeout on slow systems
- Tests may fail on very old CPUs or kernels

**Debugging Timeout Failures**:

```bash
# Check for timeout failures in test output
grep "Timed out" bazel-bin/packages/chapter_08/glibc_test.log

# Re-run specific test with extended timeout
TIMEOUTFACTOR=10 make test t=nss/tst-nss-files-hosts-multi
```

**Acceptable Result**: A few failures out of 5000+ tests is normal and acceptable (up to ~10-20 failures).

**When to Worry**: Contact LFS support if more than 10-20 tests fail, or if core functionality tests (not just timeouts) fail.

#### GCC Tests (IMPORTANT - Long Running)

**Known Issues**:

- Test suite can take several hours to complete (1-4 hours depending on CPU)
- Some tests require specific CPU features and may be skipped
- No critical failures expected with proper configuration

**Test Summary**:

```bash
# GCC provides a test summary tool
../contrib/test_summary
```

**Expected Results**: Most tests pass. Some tests may be unsupported/skipped depending on CPU features (AVX, SSE, etc.) - this is normal and expected.

#### Binutils Tests (CRITICAL - MANDATORY)

**Known Acceptable Failures**:

- **12 tests in the gold test suite** fail when using `--enable-default-pie` and `--enable-default-ssp`
- This is expected per LFS book and does not indicate a problem

**When to Worry**: Contact LFS support if more than 12 tests fail in gold test suite, or if any tests fail outside the gold test suite.

### Package-Specific Test Issues

#### Autoconf

- Test suite broken by bash-5 and libtool-2.4.3
- Some failures expected but build is still usable

#### Coreutils

**Known Acceptable Failures in Chroot**:

- `preserve-mode.sh` - Fails in chroot (passes in complete system)
- `acl.sh` - Fails in chroot (passes in complete system)

**Root vs Non-Root**:

- Root tests run first: `make NON_ROOT_USERNAME=tester check-root`
- Non-root tests run as tester user

#### E2fsprogs

**Known Issues**:

- `m_assume_storage_prezeroed` may fail
- One test requires at least 256MB RAM

#### Expect

**Critical Pre-Test**:

```bash
# Verify PTY support before running tests
python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
```

- If this fails, Expect tests and all dependent test suites will fail
- PTY issues must be resolved before continuing

#### GMP

**Test Validation**:

```bash
# Count passing tests
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
```

- **Minimum**: At least 199 tests must pass
- If fewer pass, may need to reconfigure with `--host=none-linux-gnu`

#### Inetutils

**Known Failures in Chroot**:

- `libls.sh` - Fails in chroot (passes in complete system)
- `ping-localhost.sh` - Fails if host kernel doesn't have loopback configured

#### Libtool

**Known Issues**:

- 5 tests fail due to circular dependency (pass if rechecked after library installation)
- 2 tests trigger POSIX regex warnings in gawk

#### OpenSSL

**Known Failures**:

- `30-test_afalg.t` - Fails if host kernel lacks `CONFIG_CRYPTO_USER_API_HASH`
- This is a kernel configuration issue, not an OpenSSL problem

#### Python

**Test Behavior**:

- Tests may hang indefinitely without timeout
- Use `TESTOPTS="--timeout 120"` to set 2-minute timeout per test
- Some tests are flaky and will automatically re-run
- A few failures/retries are normal

#### Systemd

**Known Failures in Chroot**:

- `test-namespace` - Always fails in chroot
- Other failures depend on kernel configuration options
- Chroot limitations prevent some systemd features from working

#### Util-linux

**Pre-Test Adjustments**:

```bash
# Disable problematic test
sed -i '/test_mkfds/s/^/#/' tests/helpers/Makemodule.am
```

**Known Failures**:

- Hardlink tests fail without `CONFIG_CRYPTO_USER_API_HASH`
- lsfd inotify test fails without `CONFIG_NETLINK_DIAG`

**Warning**: Running tests as root can be harmful to the system. Tests require `CONFIG_SCSI_DEBUG` as module. Always run as tester user: `su tester -c "make -k check"`

#### Vim

**Test Output**:

- Test output is binary data - must redirect to file
- Look for "ALL TESTS PASSED" message in output file

```bash
su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" &> vim-test.log
grep "ALL TESTS PASSED" vim-test.log
```

#### Zstd

**Test Output**:

- Several places in test output show warnings
- There should be no actual test failures

### Packages That Cannot Test in Chroot

- **Acl**: Tests require extended attributes filesystem support (not available in standard chroot)
- **Kmod**: Test suite requires raw kernel headers (cannot run in chroot)
- **Meson**: Test suite requires packages outside LFS scope
- **Ncurses**: Test suite can only be run after installation (tests reside in `test/` directory)
- **Ninja**: Tests cannot run in chroot environment (require cmake)

### General Test Guidelines

1. **Critical Tests**: Never skip glibc, gcc, or binutils test suites
1. **Chroot Limitations**: Some tests fail only due to chroot environment restrictions
1. **Acceptable Failures**: A small number of failures is often acceptable
1. **System Requirements**: Some tests depend on kernel configuration or hardware features
1. **Performance**: Test suites can take hours on some packages (especially GCC)

### Running Tests

```bash
# Build all packages (includes ~60 inline tests)
bazel build //packages/chapter_08:all_chapter_08

# Run critical tests separately
bazel test //packages/chapter_08:critical_tests

# Run individual critical tests
bazel test //packages/chapter_08:glibc_test
bazel test //packages/chapter_08:gcc_test
bazel test //packages/chapter_08:binutils_test

# Quick smoke tests
bazel test //packages/chapter_08:smoke_tests
```

### Viewing Test Results

```bash
# View complete test log
cat bazel-bin/packages/chapter_08/glibc_test.log
cat bazel-bin/packages/chapter_08/gcc_test.log
cat bazel-bin/packages/chapter_08/binutils_test.log

# Search for failures
grep -i "fail" bazel-bin/packages/chapter_08/glibc_test.log
grep -i "error" bazel-bin/packages/chapter_08/gcc_test.log

# Count passes and failures
grep -c "PASS" bazel-bin/packages/chapter_08/glibc_test.log
grep -c "FAIL" bazel-bin/packages/chapter_08/glibc_test.log
```

### When to Worry About Test Failures

Contact LFS support or consult forums if:

- More than a few tests fail in critical packages (glibc, gcc, binutils)
- Completely unexpected failures (not documented here or in LFS book)
- Consistent failures across multiple packages
- Glibc fails more than ~10 tests out of 5000+

### References

- LFS Book Chapter 8: https://www.linuxfromscratch.org/lfs/view/12.2/chapter08/
- Test specifications from: `docs/lfs-book/chapter08/*.xml`

______________________________________________________________________

## 🆘 Getting Help

### Before asking for help

1. **Check the logs:**

   ```bash
   cat bazel-out/lfs-logs/<package>.log
   ```

1. **Run with verbose output:**

   ```bash
   bazel build --subcommands --verbose_failures //packages/chapter_07:perl
   ```

1. **Search for error message:**

   - Google the error
   - Check LFS mailing list archives
   - Search GitHub issues

### Where to get help

- **LFS Mailing Lists:** https://www.linuxfromscratch.org/mail.html
- **Reddit:** /r/linuxfromscratch
- **IRC:** #lfs-support on Libera.Chat
- **This project's GitHub:** https://github.com/user/lfs-bzl/issues

### When reporting issues

Include:

1. **Exact error message** (copy-paste, don't paraphrase)
1. **Build log** (`cat bazel-out/lfs-logs/package.log`)
1. **System info** (`uname -a`, `gcc --version`, `bazel version`)
1. **Steps to reproduce**
1. **What you've already tried**

______________________________________________________________________

## 📖 Appendix: Useful Commands

### Diagnostic Commands

```bash
# List all build targets
bazel query //...

# Show dependencies of a target
bazel query 'deps(//packages/chapter_06:bash)'

# Find which targets depend on a package
bazel query 'rdeps(//..., //packages/chapter_05:glibc)'

# Show all files in sysroot
tree -L 3 src/sysroot/

# Check mounted filesystems
mount | grep sysroot

# Verify toolchain paths
ls -la src/sysroot/tools/bin/
ls -la src/sysroot/usr/bin/

# Check Bazel cache size
du -sh ~/.cache/bazel/

# View Bazel execution log
less bazel-out/_tmp/actions/actions.log
```

### Reset/Cleanup Commands

```bash
# Clean build outputs (keeps cache)
bazel clean

# Clean everything (including download cache)
bazel clean --expunge

# Unmount all chroot mounts
sudo src/tools/lfs-chroot-helper.sh unmount-vfs $(pwd)/src/sysroot

# Reset sysroot ownership
sudo chown -R $USER:$USER src/sysroot/

# Start fresh (nuclear option)
bazel clean --expunge
rm -rf src/sysroot/
mkdir -p src/sysroot/{tools,usr,sources}
bazel build //packages/chapter_05:cross_toolchain
```

______________________________________________________________________

**Happy Building!** 🚀

If you encounter an issue not listed here, please contribute by opening a PR!
