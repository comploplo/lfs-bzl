load("//tools:lfs_build.bzl", "lfs_chroot_command", "lfs_chroot_extract_tarball", "lfs_chroot_step", "lfs_sysroot_stage_files", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

lfs_chroot_command(
    name = "test_chroot_echo",
    chroot_helper = "//tools:lfs_chroot_helper_script",
    cmd_file = "//tools/scripts:test_chroot_echo_script",
    lfs_sysroot = "//:lfs_sysroot_files",
    tags = [
        "manual",
        "requires-sudo",
    ],
    toolchain = "//packages/chapter_06:temp_tools_toolchain",
    visibility = ["//visibility:public"],
)

lfs_chroot_step(
    name = "chroot_mount_test",
    cmd_file = "//packages/chapter_07:chroot_mount_test.sh",
    tags = [
        "manual",
        "requires-sudo",
    ],
    deps = ["//packages/chapter_06:all_temp_tools"],  # Ensure a basic environment is present
)

# Note: chroot_smoke_test moved to //tools/scripts/tests:chroot_smoke_test

# --------------------------------------------------------------------------- #
# Chapter 7 prep steps (filesystem layout, ownership, cleanup)
# --------------------------------------------------------------------------- #

lfs_sysroot_stage_files(
    name = "stage_ch7_sources",
    srcs = [
        "@bison_src//file",
        "@gettext_src//file",
        "@perl_src//file",
        "@python_src//file",
        "@texinfo_src//file",
        "@util_linux_src//file",
    ],
    dest_rel = "sources",
    lfs_sysroot = "//:lfs_sysroot_files",
    tags = [
        "requires-sudo",
    ],
)

lfs_chroot_step(
    name = "chroot_create_dirs",
    cmd_file = "//tools/scripts:chroot_create_dirs_script",
    deps = ["//packages/chapter_06:all_temp_tools"],
)

lfs_chroot_step(
    name = "chroot_seed_files",
    cmd_file = "//tools/scripts:chroot_seed_files_script",
    deps = [
        ":chroot_create_dirs",
        "//packages/chapter_06:all_temp_tools",
    ],
)

lfs_chroot_step(
    name = "chroot_chown_root",
    cmd = """
set -euo pipefail
chown -R root:root /{usr,lib,var,etc,bin,sbin,tools}
case $(uname -m) in
  x86_64) if [ -d /lib64 ]; then chown -R root:root /lib64; fi ;;
esac
""",
    deps = [
        ":chroot_seed_files",
        "//packages/chapter_06:all_temp_tools",
    ],
)

lfs_chroot_step(
    name = "chroot_cleanup_tmp",
    cmd = """
set -euo pipefail
rm -rf /tmp/* /var/tmp/* || true
""",
    deps = [
        ":chroot_chown_root",
        "//packages/chapter_06:all_temp_tools",
    ],
)

lfs_chroot_step(
    name = "chroot_prepare",
    cmd = "true",
    deps = [
        ":chroot_cleanup_tmp",
        ":stage_ch7_sources",
    ],
)

# Toolchain representing the Chapter 7 chroot-built base system (/usr/bin).
# Downstream chapters can depend on this instead of the temporary tools toolchain.
lfs_toolchain(
    name = "chroot_base_toolchain",
    bin_path = "/usr/bin:/usr/sbin:/bin:/sbin",
    env = {
        "CC": "x86_64-lfs-linux-gnu-gcc",
        "CXX": "x86_64-lfs-linux-gnu-g++",
        "LFS_TGT": "x86_64-lfs-linux-gnu",
    },
    visibility = ["//visibility:public"],
    deps = [
        "//packages/chapter_06:temp_tools_toolchain",
    ],
)

# --------------------------------------------------------------------------- #
# Chapter 7 packages (built inside chroot using temporary tools toolchain)
# --------------------------------------------------------------------------- #

# --------------------------------------------------------------------------- #
# Chapter 7 packages (built inside chroot using temporary tools toolchain)
#
# PARALLELISM: These packages have minimal inter-dependencies and can build
# mostly in parallel. We use Bazel's resource semaphore to limit concurrent
# chroot operations to prevent resource contention.
#
# Dependency strategy:
# - All extractions depend on chroot_prepare (one-time setup)
# - Gettext builds first (provides i18n tools that may be used by others)
# - All other packages can build in parallel after gettext
# - Resource constraint limits concurrent chroot builds to 2
# --------------------------------------------------------------------------- #

# Extract all tarballs in parallel after chroot is prepared
lfs_chroot_extract_tarball(
    name = "extract_gettext",
    tarball_name = "gettext-0.22.5.tar.xz",
    deps = [":chroot_prepare"],
)

lfs_chroot_extract_tarball(
    name = "extract_bison",
    tarball_name = "bison-3.8.2.tar.xz",
    deps = [":chroot_prepare"],
)

lfs_chroot_extract_tarball(
    name = "extract_perl",
    tarball_name = "perl-5.40.0.tar.xz",
    deps = [":chroot_prepare"],
)

lfs_chroot_extract_tarball(
    name = "extract_python",
    tarball_name = "Python-3.12.4.tar.xz",
    deps = [":chroot_prepare"],
)

lfs_chroot_extract_tarball(
    name = "extract_texinfo",
    tarball_name = "texinfo-7.1.tar.xz",
    deps = [":chroot_prepare"],
)

lfs_chroot_extract_tarball(
    name = "extract_util_linux",
    tarball_name = "util-linux-2.40.2.tar.xz",
    deps = [":chroot_prepare"],
)

# Build gettext first (provides i18n tools)
lfs_chroot_step(
    name = "gettext",
    cmd = """
set -euo pipefail
cd /sources/gettext-0.22.5
./configure --disable-shared
make -j$(nproc)
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
""",
    deps = [":extract_gettext"],
)

# All other packages can build in parallel after gettext
lfs_chroot_step(
    name = "bison",
    cmd = """
set -euo pipefail
cd /sources/bison-3.8.2
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
make -j$(nproc)
make install
""",
    deps = [
        ":extract_bison",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

lfs_chroot_step(
    name = "perl",
    cmd = """
set -euo pipefail
cd /sources/perl-5.40.0
sh Configure -des -D prefix=/usr -D vendorprefix=/usr -D useshrplib \\
  -Dprivlib=/usr/lib/perl5/5.40/core_perl \\
  -Darchlib=/usr/lib/perl5/5.40/core_perl \\
  -Dsitelib=/usr/lib/perl5/5.40/site_perl \\
  -Dsitearch=/usr/lib/perl5/5.40/site_perl \\
  -Dvendorlib=/usr/lib/perl5/5.40/vendor_perl \\
  -Dvendorarch=/usr/lib/perl5/5.40/vendor_perl
make -j$(nproc)
make install
""",
    deps = [
        ":extract_perl",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

lfs_chroot_step(
    name = "python",
    cmd = """
set -euo pipefail
cd /sources/Python-3.12.4
./configure --prefix=/usr --enable-shared --without-ensurepip
make -j$(nproc)
make install
""",
    deps = [
        ":extract_python",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

lfs_chroot_step(
    name = "texinfo",
    cmd = """
set -euo pipefail
cd /sources/texinfo-7.1
./configure --prefix=/usr
make -j$(nproc)
make install
""",
    deps = [
        ":extract_texinfo",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

lfs_chroot_step(
    name = "util_linux",
    cmd = """
set -euo pipefail
cd /sources/util-linux-2.40.2
mkdir -pv /var/lib/hwclock
./configure --libdir=/usr/lib \\
  --runstatedir=/run \\
  --disable-chfn-chsh \\
  --disable-login \\
  --disable-nologin \\
  --disable-su \\
  --disable-setpriv \\
  --disable-runuser \\
  --disable-pylibmount \\
  --disable-static \\
  --disable-liblastlog2 \\
  --without-python \\
  ADJTIME_PATH=/var/lib/hwclock/adjtime \\
  --docdir=/usr/share/doc/util-linux-2.40.2
make -j$(nproc)
make install
""",
    deps = [
        ":extract_util_linux",
        ":gettext",  # Wait for gettext i18n tools
    ],
)

# Convenience aggregate to run all Chapter 7 builds in order (manual/sudo).
lfs_chroot_step(
    name = "chroot_toolchain_phase",
    cmd = "true",
    deps = [
        ":bison",
        ":perl",
        ":python",
        ":texinfo",
        ":util_linux",
    ],
)

# Chapter 7.14 cleanup (optional but recommended).
lfs_chroot_step(
    name = "chroot_cleanup",
    cmd = """
set -euo pipefail
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name '*.la' -delete
rm -rf /tools
rm -rf /tmp/* /var/tmp/* || true
""",
    deps = [":chroot_toolchain_phase"],
)

# Final convenience target for "Chapter 7 is done".
lfs_chroot_step(
    name = "chroot_finalize",
    cmd = "true",
    deps = [
        ":chroot_cleanup",
    ],
)

# Quick validation of core Chapter 7 toolchain inside chroot.
lfs_chroot_step(
    name = "chroot_smoke_versions",
    cmd = """
set -euo pipefail
bison --version | head -1
msgfmt --version | head -1
perl -V:version
python3 -V
info --version | head -1
lsblk --version | head -1
""",
    tags = [
        "manual",
        "requires-sudo",
    ],
    deps = [
        ":chroot_toolchain_phase",
    ],
)
