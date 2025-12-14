"""
Chapter 8: Building the Final System

Builds the final system packages inside the chroot environment.
All packages use the temporary tools from Chapter 6/7.

This chapter builds ~80 packages in phases:
- Phase 2: Core Foundation (~17 packages)
- Phase 3: Toolchain & Security (~16 packages)
- Phase 4: Build System & Python (~24 packages)
- Phase 5: System Services (~20 packages)
- Phase 6: Final Packages & Cleanup (~3 packages)
"""

load("//tools:lfs_build.bzl", "lfs_toolchain")
load("//tools:lfs_chroot.bzl", "lfs_chroot_extract_tarball", "lfs_chroot_step", "lfs_sysroot_stage_files")

package(default_visibility = ["//visibility:public"])

###############################################################################
# Source Staging - Stage all Chapter 8 sources into /sources
###############################################################################

lfs_sysroot_stage_files(
    name = "stage_ch8_sources",
    srcs = [
        # Phase 2: Core Foundation (17 packages)
        "@man_pages_src//file",
        "@iana_etc_src//file",
        "@glibc_src//file",
        "@glibc_fhs_patch//file",
        "@zlib_src//file",
        "@bzip2_src//file",
        "@bzip2_docs_patch//file",
        "@xz_src//file",
        "@lz4_src//file",
        "@zstd_src//file",
        "@file_src//file",
        "@readline_src//file",
        "@m4_src//file",
        "@bc_src//file",
        "@flex_src//file",
        "@tcl_src//file",
        "@expect_src//file",
        "@expect_gcc14_patch//file",
        "@dejagnu_src//file",
        "@pkgconf_src//file",

        # Phase 3: Toolchain & Security (16 packages)
        "@binutils_src//file",
        "@gmp_src//file",
        "@mpfr_src//file",
        "@mpc_src//file",
        "@attr_src//file",
        "@acl_src//file",
        "@libcap_src//file",
        "@libxcrypt_src//file",
        "@shadow_src//file",
        "@gcc_src//file",
        "@ncurses_src//file",
        "@sed_src//file",
        "@psmisc_src//file",
        "@gettext_src//file",
        "@bison_src//file",
        "@grep_src//file",

        # Phase 4: Build System & Python (24 packages)
        "@bash_src//file",
        "@libtool_src//file",
        "@gdbm_src//file",
        "@gperf_src//file",
        "@expat_src//file",
        "@inetutils_src//file",
        "@less_src//file",
        "@perl_src//file",
        "@xml_parser_src//file",
        "@intltool_src//file",
        "@autoconf_src//file",
        "@automake_src//file",
        "@openssl_src//file",
        "@kmod_src//file",
        "@libelf_src//file",
        "@libffi_src//file",
        "@python_src//file",
        "@flit_core_src//file",
        "@wheel_src//file",
        "@setuptools_src//file",
        "@ninja_src//file",
        "@meson_src//file",
        "@coreutils_src//file",
        "@coreutils_i18n_patch//file",
        "@check_src//file",

        # Phase 5: System Services (18 packages - skipping systemd/dbus)
        "@diffutils_src//file",
        "@gawk_src//file",
        "@findutils_src//file",
        "@groff_src//file",
        "@grub_src//file",
        "@gzip_src//file",
        "@iproute2_src//file",
        "@kbd_src//file",
        "@kbd_backspace_patch//file",
        "@libpipeline_src//file",
        "@make_src//file",
        "@patch_src//file",
        "@tar_src//file",
        "@texinfo_src//file",
        "@vim_src//file",
        "@markupsafe_src//file",
        "@jinja2_src//file",
        "@man_db_src//file",
        "@procps_ng_src//file",

        # Phase 6: Final Packages (3 packages)
        "@util_linux_src//file",
        "@e2fsprogs_src//file",
        "@sysklogd_src//file",
    ],
    dest_rel = "sources",
    lfs_sysroot = "//:lfs_sysroot_files",
    tags = ["requires-sudo"],
    deps = [],  # Chapter 7 already built, sysroot ready
)

###############################################################################
# PHASE 2: Core Foundation Packages (17 packages)
###############################################################################

# 8.3 Man-pages - Linux manual pages (data only)
lfs_chroot_extract_tarball(
    name = "extract_man_pages",
    tarball_name = "man-pages-6.9.1.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "man_pages",
    cmd = """
set -euo pipefail
cd /sources/man-pages-6.9.1
make prefix=/usr install
rm -v /usr/share/man/man3/crypt*
""",
    deps = [":extract_man_pages"],
)

# 8.4 Iana-Etc - Network protocol data (data only)
lfs_chroot_extract_tarball(
    name = "extract_iana_etc",
    tarball_name = "iana-etc-20240806.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "iana_etc",
    cmd = """
set -euo pipefail
cd /sources/iana-etc-20240806
cp services protocols /etc
""",
    deps = [":extract_iana_etc"],
)

# 8.5 Glibc - C library (CRITICAL - test suite available: make check)
# Note: This is a complex multi-step build with locale generation
lfs_chroot_extract_tarball(
    name = "extract_glibc",
    tarball_name = "glibc-2.40.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "glibc",
    cmd = """
set -euo pipefail
cd /sources/glibc-2.40

# Apply FHS patch
patch -Np1 -i ../glibc-2.40-fhs-1.patch

# Create build directory
mkdir -v build
cd build

# Configure ldconfig and sln utilities
echo "rootsbindir=/usr/sbin" > configparms

# Configure glibc
../configure --prefix=/usr \\
             --disable-werror \\
             --enable-kernel=4.19 \\
             --enable-stack-protector=strong \\
             --disable-nscd \\
             libc_cv_slibdir=/usr/lib

# Build
make

# Install
# Create ld.so.conf to prevent warning
touch /etc/ld.so.conf

# Skip outdated sanity check
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile

# Install glibc
make install

# Fix hardcoded path in ldd script
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd

# Install locale configuration
mkdir -pv /usr/lib/locale
localedef -i C -f UTF-8 C.UTF-8
localedef -i en_US -f UTF-8 en_US.UTF-8

# Create nsswitch.conf
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

# Create /etc/ld.so.conf
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

# Create /etc/ld.so.conf.d directory
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
""",
    deps = [":extract_glibc"],
)

# 8.8 Zlib - Compression library (test suite: make check)
# Note: Zlib uses custom configure script (not autoconf)
lfs_chroot_extract_tarball(
    name = "extract_zlib",
    tarball_name = "zlib-1.3.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "zlib",
    cmd = """
set -euo pipefail
cd /sources/zlib-1.3.1

# Configure (custom configure script, not autoconf)
./configure --prefix=/usr

# Build
make -j$(nproc)

# Install
make install

# Remove static library
rm -fv /usr/lib/libz.a
""",
    deps = [
        ":extract_zlib",
        ":glibc",
    ],
)

# 8.9 Bzip2 - Compression library (complex custom Makefile)
lfs_chroot_extract_tarball(
    name = "extract_bzip2",
    tarball_name = "bzip2-1.0.8.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "bzip2",
    cmd = """
set -euo pipefail
cd /sources/bzip2-1.0.8

# Apply documentation patch
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch

# Fix symlinks to be relative
sed -i 's@\\(ln -s -f \\)$(PREFIX)/bin/@\\1@' Makefile

# Fix man page location
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

# Build shared library first
make -f Makefile-libbz2_so
make clean

# Build static library and utilities
make -j$(nproc)

# Install
make PREFIX=/usr install

# Install shared library
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so

# Install shared bzip2 binary
cp -v bzip2-shared /usr/bin/bzip2

# Create symlinks
for i in /usr/bin/{bzcat,bunzip2}; do
    ln -sfv bzip2 $i
done

# Remove static library
rm -fv /usr/lib/libbz2.a
""",
    deps = [
        ":extract_bzip2",
        ":glibc",
    ],
)

# 8.10 Xz - Compression library (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_xz",
    tarball_name = "xz-5.6.2.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "xz",
    cmd = """
set -euo pipefail
cd /sources/xz-5.6.2

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/xz-5.6.2

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_xz",
        ":glibc",
    ],
)

# 8.11 Lz4 - Compression library (make-based)
lfs_chroot_extract_tarball(
    name = "extract_lz4",
    tarball_name = "lz4-1.10.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "lz4",
    cmd = """
set -euo pipefail
cd /sources/lz4-1.10.0

# Build
make -j$(nproc) BUILD_STATIC=no PREFIX=/usr

# Install
make BUILD_STATIC=no PREFIX=/usr install
""",
    deps = [
        ":extract_lz4",
        ":glibc",
    ],
)

# 8.12 Zstd - Compression library (make-based, test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_zstd",
    tarball_name = "zstd-1.5.6.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "zstd",
    cmd = """
set -euo pipefail
cd /sources/zstd-1.5.6

# Build
make -j$(nproc) prefix=/usr

# Install
make prefix=/usr install

# Remove static library
rm -v /usr/lib/libzstd.a
""",
    deps = [
        ":extract_zstd",
        ":glibc",
    ],
)

# 8.13 File - File type identification (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_file",
    tarball_name = "file-5.45.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "file",
    cmd = """
set -euo pipefail
cd /sources/file-5.45

# Configure
./configure --prefix=/usr --disable-static

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_file",
        ":glibc",
        ":zlib",
    ],
)

# 8.14 Readline - Command line editing library
# Note: Requires ncurses (not available in Phase 2), but can use curses fallback
lfs_chroot_extract_tarball(
    name = "extract_readline",
    tarball_name = "readline-8.2.13.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "readline",
    cmd = """
set -euo pipefail
cd /sources/readline-8.2.13

# Prevent library renaming issues
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install

# Remove rpath
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --with-curses \\
            --docdir=/usr/share/doc/readline-8.2.13

# Build
make SHLIB_LIBS="-lncursesw" -j$(nproc)

# Install
make SHLIB_LIBS="-lncursesw" install

# Install documentation
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.2.13 || true
""",
    deps = [
        ":extract_readline",
        ":glibc",
    ],
)

# 8.15 M4 - Macro processor (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_m4",
    tarball_name = "m4-1.4.19.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "m4",
    cmd = """
set -euo pipefail
cd /sources/m4-1.4.19

# Configure
./configure --prefix=/usr

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_m4",
        ":glibc",
    ],
)

# 8.16 Bc - Arbitrary precision calculator (test suite: make check)
# Note: Bc uses custom configure script (not autoconf)
lfs_chroot_extract_tarball(
    name = "extract_bc",
    tarball_name = "bc-6.7.6.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "bc",
    cmd = """
set -euo pipefail
cd /sources/bc-6.7.6

# Configure (custom configure script, not autoconf)
# -G = generate GNU bc compatible behavior
# -O3 = optimization level 3
# -r = readline support
CC=gcc ./configure -G -O3 -r

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_bc",
        ":glibc",
        ":readline",
    ],
)

# 8.17 Flex - Lexical analyzer (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_flex",
    tarball_name = "flex-2.6.4.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "flex",
    cmd = """
set -euo pipefail
cd /sources/flex-2.6.4

# Create build directory
mkdir -v build
cd build

# Configure (out-of-tree build)
../configure --prefix=/usr \\
             --disable-static \\
             --docdir=/usr/share/doc/flex-2.6.4

# Build
make -j$(nproc)

# Install
make install

# Create compatibility symlinks for lex
ln -sv flex /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1
""",
    deps = [
        ":extract_flex",
        ":glibc",
        ":m4",
    ],
)

# 8.18 Tcl - Tool Command Language (test suite: make test)
# Note: Complex subdirectory build with config file fixes
lfs_chroot_extract_tarball(
    name = "extract_tcl",
    tarball_name = "tcl8.6.14-src.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "tcl",
    cmd = """
set -euo pipefail
cd /sources/tcl8.6.14

# Configure (build happens in unix subdirectory)
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr \\
            --mandir=/usr/share/man \\
            --disable-rpath

# Build
make -j$(nproc)

# Fix config files to reference install directories
sed -e "s|$SRCDIR/unix|/usr/lib|" \\
    -e "s|$SRCDIR|/usr/include|" \\
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.7|/usr/lib/tdbc1.1.7|" \\
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/generic|/usr/include|" \\
    -e "s|$SRCDIR/pkgs/tdbc1.1.7/library|/usr/lib/tcl8.6|" \\
    -e "s|$SRCDIR/pkgs/tdbc1.1.7|/usr/include|" \\
    -i pkgs/tdbc1.1.7/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.2.4|/usr/lib/itcl4.2.4|" \\
    -e "s|$SRCDIR/pkgs/itcl4.2.4/generic|/usr/include|" \\
    -e "s|$SRCDIR/pkgs/itcl4.2.4|/usr/include|" \\
    -i pkgs/itcl4.2.4/itclConfig.sh

# Install
make install

# Make library writable for debugging symbols
chmod -v u+w /usr/lib/libtcl8.6.so

# Install private headers (needed by Expect)
make install-private-headers

# Create symlink
ln -sfv tclsh8.6 /usr/bin/tclsh

# Rename conflicting man page
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3
""",
    deps = [
        ":extract_tcl",
        ":glibc",
        ":zlib",
    ],
)

# 8.19 Expect - Automating interactive programs (CRITICAL - requires PTY)
# Test suite: make test
lfs_chroot_extract_tarball(
    name = "extract_expect",
    tarball_name = "expect5.45.4.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "expect",
    cmd = """
set -euo pipefail
cd /sources/expect5.45.4

# Note: PTY check would go here in production
# python3 -c 'from pty import spawn; spawn(["echo", "ok"])'

# Apply GCC 14 compatibility patch
patch -Np1 -i /sources/expect-5.45.4-gcc14-1.patch

# Configure
./configure --prefix=/usr \\
            --with-tcl=/usr/lib \\
            --enable-shared \\
            --disable-rpath \\
            --mandir=/usr/share/man \\
            --with-tclinclude=/usr/include

# Build
make -j$(nproc)

# Install
make install

# Create compatibility symlink
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
""",
    deps = [
        ":extract_expect",
        ":glibc",
        ":tcl",
    ],
)

# 8.20 DejaGNU - Testing framework (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_dejagnu",
    tarball_name = "dejagnu-1.6.3.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "dejagnu",
    cmd = """
set -euo pipefail
cd /sources/dejagnu-1.6.3

# Configure
./configure --prefix=/usr

# Build documentation
makeinfo --html --no-split -o doc/dejagnu.html doc/dejagnu.texi
makeinfo --plaintext -o doc/dejagnu.txt doc/dejagnu.texi

# Install
make install

# Install documentation
install -v -dm755 /usr/share/doc/dejagnu-1.6.3
install -v -m644 doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
""",
    deps = [
        ":expect",
        ":extract_dejagnu",
        ":glibc",
    ],
)

# 8.21 Pkgconf - pkg-config implementation
lfs_chroot_extract_tarball(
    name = "extract_pkgconf",
    tarball_name = "pkgconf-2.3.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "pkgconf",
    cmd = """
set -euo pipefail
cd /sources/pkgconf-2.3.0

# Create build directory
mkdir -v build
cd build

# Configure (out-of-tree build)
../configure --prefix=/usr \\
             --disable-static

# Build
make -j$(nproc)

# Install
make install

# Create pkg-config compatibility symlinks
ln -sv pkgconf /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
""",
    deps = [
        ":extract_pkgconf",
        ":glibc",
    ],
)

###############################################################################
# Phase 2 Aggregate Target
###############################################################################

filegroup(
    name = "phase2_core_foundation",
    srcs = [
        ":bc",
        ":bzip2",
        ":dejagnu",
        ":expect",
        ":file",
        ":flex",
        ":glibc",
        ":iana_etc",
        ":lz4",
        ":m4",
        ":man_pages",
        ":pkgconf",
        ":readline",
        ":tcl",
        ":xz",
        ":zlib",
        ":zstd",
    ],
)

# Final System Toolchain (available after Phase 2)
# This toolchain uses the rebuilt glibc and provides the final system paths.
# Phase 3+ packages can use this instead of the Chapter 7 cross-toolchain.
lfs_toolchain(
    name = "final_toolchain",
    bin_path = "/usr/bin:/usr/sbin:/bin:/sbin",
    env = {
        "CC": "gcc",
        "CXX": "g++",
    },
    visibility = ["//visibility:public"],
    deps = [":glibc"],
)

###############################################################################
# PHASE 3: Toolchain & Security Packages (16 packages)
###############################################################################

# 8.22 Binutils - Final linker and assembler (CRITICAL - test suite available: make check)
# Note: Out-of-tree build required, multiple configure options
lfs_chroot_extract_tarball(
    name = "extract_binutils",
    tarball_name = "binutils-2.43.1.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "binutils",
    cmd = """
set -euo pipefail
cd /sources/binutils-2.43.1

# Out-of-tree build required
mkdir -v build
cd build

# Configure
../configure --prefix=/usr \\
             --sysconfdir=/etc \\
             --enable-gold \\
             --enable-ld=default \\
             --enable-plugins \\
             --enable-shared \\
             --disable-werror \\
             --enable-64-bit-bfd \\
             --enable-new-dtags \\
             --with-system-zlib \\
             --enable-default-hash-style=gnu

# Build
make -j$(nproc) tooldir=/usr

# Install
make tooldir=/usr install

# Remove useless static libraries
rm -fv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a
""",
    deps = [
        ":extract_binutils",
        ":glibc",
        ":zlib",
    ],
)

# 8.23 GMP - Math library for GCC (CRITICAL - test suite available: make check)
lfs_chroot_extract_tarball(
    name = "extract_gmp",
    tarball_name = "gmp-6.3.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gmp",
    cmd = """
set -euo pipefail
cd /sources/gmp-6.3.0

# Configure
./configure --prefix=/usr \\
            --enable-cxx \\
            --disable-static \\
            --docdir=/usr/share/doc/gmp-6.3.0

# Build
make -j$(nproc)
make html

# Install
make install
make install-html
""",
    deps = [
        ":extract_gmp",
        ":glibc",
    ],
)

# 8.24 MPFR - Math library for GCC (CRITICAL - test suite available: make check)
lfs_chroot_extract_tarball(
    name = "extract_mpfr",
    tarball_name = "mpfr-4.2.1.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "mpfr",
    cmd = """
set -euo pipefail
cd /sources/mpfr-4.2.1

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --enable-thread-safe \\
            --docdir=/usr/share/doc/mpfr-4.2.1

# Build
make -j$(nproc)
make html

# Install
make install
make install-html
""",
    deps = [
        ":extract_mpfr",
        ":glibc",
        ":gmp",
    ],
)

# 8.25 MPC - Math library for GCC (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_mpc",
    tarball_name = "mpc-1.3.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "mpc",
    cmd = """
set -euo pipefail
cd /sources/mpc-1.3.1

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/mpc-1.3.1

# Build
make -j$(nproc)
make html

# Install
make install
make install-html
""",
    deps = [
        ":extract_mpc",
        ":glibc",
        ":gmp",
        ":mpfr",
    ],
)

# 8.26 Attr - Extended file attributes (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_attr",
    tarball_name = "attr-2.5.2.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "attr",
    cmd = """
set -euo pipefail
cd /sources/attr-2.5.2

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --sysconfdir=/etc \\
            --docdir=/usr/share/doc/attr-2.5.2

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_attr",
        ":glibc",
    ],
)

# 8.27 Acl - Access control lists (test suite depends on coreutils)
lfs_chroot_extract_tarball(
    name = "extract_acl",
    tarball_name = "acl-2.3.2.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "acl",
    cmd = """
set -euo pipefail
cd /sources/acl-2.3.2

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/acl-2.3.2

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":attr",
        ":extract_acl",
        ":glibc",
    ],
)

# 8.28 Libcap - POSIX capabilities library (test suite: make test)
# Note: Make-based, requires sed to prevent static library installation
lfs_chroot_extract_tarball(
    name = "extract_libcap",
    tarball_name = "libcap-2.70.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libcap",
    cmd = """
set -euo pipefail
cd /sources/libcap-2.70

# Prevent static library installation
sed -i '/install -m.*STA/d' libcap/Makefile

# Build
make -j$(nproc) prefix=/usr lib=lib

# Install
make prefix=/usr lib=lib install
""",
    deps = [
        ":attr",
        ":extract_libcap",
        ":glibc",
    ],
)

# 8.29 Libxcrypt - Modern password hashing library (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_libxcrypt",
    tarball_name = "libxcrypt-4.4.36.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libxcrypt",
    cmd = """
set -euo pipefail
cd /sources/libxcrypt-4.4.36

# Configure
./configure --prefix=/usr \\
            --enable-hashes=strong,glibc \\
            --enable-obsolete-api=no \\
            --disable-static \\
            --disable-failure-tokens

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_libxcrypt",
        ":glibc",
    ],
)

# 8.30 Shadow - Password management utilities
# Note: Complex configuration with sed patches and custom install
lfs_chroot_extract_tarball(
    name = "extract_shadow",
    tarball_name = "shadow-4.16.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "shadow",
    cmd = """
set -euo pipefail
cd /sources/shadow-4.16.0

# Disable groups program (coreutils provides better version)
sed -i 's/groups$$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\\.1 / /'   {} \\;
find man -name Makefile.in -exec sed -i 's/getspnam\\.3 / /' {} \\;
find man -name Makefile.in -exec sed -i 's/passwd\\.5 / /'   {} \\;

# Configure login.defs: YESCRYPT encryption, /var/mail location, clean PATH
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \\
    -e 's:/var/spool/mail:/var/mail:' \\
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}' \\
    -i etc/login.defs

# Create passwd file placeholder
touch /usr/bin/passwd

# Configure
./configure --sysconfdir=/etc \\
            --disable-static \\
            --with-{b,yes}crypt \\
            --without-libbsd \\
            --with-group-name-max-length=32

# Build
make -j$(nproc)

# Install
make exec_prefix=/usr install
make -C man install-man

# Enable shadowed passwords
pwconv
grpconv
""",
    deps = [
        ":extract_shadow",
        ":glibc",
        ":libxcrypt",
    ],
)

# 8.31 GCC - Final system compiler (CRITICAL - test suite available: make check)
# Note: Most complex package - needs GMP/MPFR/MPC dependencies
lfs_chroot_extract_tarball(
    name = "extract_gcc",
    tarball_name = "gcc-14.2.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gcc",
    cmd = """
set -euo pipefail
cd /sources/gcc-14.2.0

# Fix lib64 directory on x86_64
case $(uname -m) in
  x86_64)
    sed -e '/m64=/s/lib64/lib/' \\
        -i.orig gcc/config/i386/t-linux64
  ;;
esac

# Out-of-tree build required
mkdir -v build
cd build

# Configure GCC
../configure --prefix=/usr \\
             LD=ld \\
             --enable-languages=c,c++ \\
             --enable-default-pie \\
             --enable-default-ssp \\
             --enable-host-pie \\
             --disable-multilib \\
             --disable-bootstrap \\
             --disable-fixincludes \\
             --with-system-zlib

# Build
make -j$(nproc)

# Install
make install

# Create cc symlink
ln -svr /usr/bin/gcc /usr/bin/cc

# Create FHS-compatible liblto_plugin symlink
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/14.2.0/liblto_plugin.so \\
        /usr/lib/bfd-plugins/
""",
    deps = [
        ":binutils",
        ":extract_gcc",
        ":glibc",
        ":gmp",
        ":mpc",
        ":mpfr",
        ":zlib",
    ],
)

# 8.32 Ncurses - Terminal handling library
# Note: Complex DESTDIR install to avoid shell crash during library replacement
lfs_chroot_extract_tarball(
    name = "extract_ncurses",
    tarball_name = "ncurses-6.5.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "ncurses",
    cmd = """
set -euo pipefail
cd /sources/ncurses-6.5

# Configure
./configure --prefix=/usr \\
            --mandir=/usr/share/man \\
            --with-shared \\
            --without-debug \\
            --without-normal \\
            --with-cxx-shared \\
            --enable-pc-files \\
            --with-pkg-config-libdir=/usr/lib/pkgconfig

# Build
make -j$(nproc)

# Install to DESTDIR to avoid shell crash
make DESTDIR=$PWD/dest install
install -vm755 dest/usr/lib/libncursesw.so.6.5 /usr/lib
rm -v dest/usr/lib/libncursesw.so.6.5

# Edit curses.h for wide-character ABI
sed -e 's/^#if.*XOPEN.*$/#if 1/' \\
    -i dest/usr/include/curses.h

# Copy everything else
cp -av dest/* /

# Create compatibility symlinks for non-wide libraries
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done

# Create old-style linker script for compatibility
ln -sfv libncursesw.so /usr/lib/libcurses.so

# Install documentation
cp -v -R doc/html /usr/share/doc/ncurses-6.5 || true
""",
    deps = [
        ":extract_ncurses",
        ":gcc",
        ":glibc",
    ],
)

# 8.33 Sed - Stream editor (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_sed",
    tarball_name = "sed-4.9.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "sed",
    cmd = """
set -euo pipefail
cd /sources/sed-4.9

# Configure
./configure --prefix=/usr

# Build
make -j$(nproc)
make html

# Install
make install
install -d -m755 /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
""",
    deps = [
        ":extract_sed",
        ":gcc",
        ":glibc",
    ],
)

# 8.34 Psmisc - Process utilities (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_psmisc",
    tarball_name = "psmisc-23.7.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "psmisc",
    cmd = """
set -euo pipefail
cd /sources/psmisc-23.7

# Configure
./configure --prefix=/usr

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_psmisc",
        ":gcc",
        ":glibc",
        ":ncurses",
    ],
)

# 8.35 Gettext - Internationalization framework (test suite: make check - long!)
lfs_chroot_extract_tarball(
    name = "extract_gettext",
    tarball_name = "gettext-0.22.5.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gettext",
    cmd = """
set -euo pipefail
cd /sources/gettext-0.22.5

# Configure
./configure --prefix=/usr \\
            --disable-static \\
            --docdir=/usr/share/doc/gettext-0.22.5

# Build
make -j$(nproc)

# Install
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
""",
    deps = [
        ":acl",
        ":extract_gettext",
        ":gcc",
        ":glibc",
    ],
)

# 8.36 Bison - Parser generator (test suite: make check)
lfs_chroot_extract_tarball(
    name = "extract_bison",
    tarball_name = "bison-3.8.2.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "bison",
    cmd = """
set -euo pipefail
cd /sources/bison-3.8.2

# Configure
./configure --prefix=/usr \\
            --docdir=/usr/share/doc/bison-3.8.2

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_bison",
        ":gcc",
        ":glibc",
        ":m4",
    ],
)

# 8.37 Grep - Pattern matching utility (test suite: make check)
# Note: Suppress egrep/fgrep deprecation warning
lfs_chroot_extract_tarball(
    name = "extract_grep",
    tarball_name = "grep-3.11.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "grep",
    cmd = """
set -euo pipefail
cd /sources/grep-3.11

# Remove warning about egrep/fgrep that breaks tests
sed -i "s/echo/#echo/" src/egrep.sh

# Configure
./configure --prefix=/usr

# Build
make -j$(nproc)

# Install
make install
""",
    deps = [
        ":extract_grep",
        ":gcc",
        ":glibc",
    ],
)

###############################################################################
# Phase 3 Aggregate Target
###############################################################################

filegroup(
    name = "phase3_toolchain_security",
    srcs = [
        ":acl",
        ":attr",
        ":binutils",
        ":bison",
        ":gcc",
        ":gettext",
        ":gmp",
        ":grep",
        ":libcap",
        ":libxcrypt",
        ":mpc",
        ":mpfr",
        ":ncurses",
        ":psmisc",
        ":sed",
        ":shadow",
    ],
)
###############################################################################
# Phase 4: Build System & Python (24 packages)
###############################################################################

# 8.36 Bash - Bourne-Again Shell
lfs_chroot_extract_tarball(
    name = "extract_bash",
    tarball_name = "bash-5.2.32.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "bash",
    cmd = """
set -euo pipefail
cd /sources/bash-5.2.32
./configure --prefix=/usr \
            --without-bash-malloc \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.2.32
make -j$(nproc)
make install
""",
    deps = [
        ":extract_bash",
        ":glibc",
        ":readline",
    ],
)

# 8.37 Libtool - Generic library support script
lfs_chroot_extract_tarball(
    name = "extract_libtool",
    tarball_name = "libtool-2.4.7.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libtool",
    cmd = """
set -euo pipefail
cd /sources/libtool-2.4.7
./configure --prefix=/usr
make -j$(nproc)
make install
rm -fv /usr/lib/libltdl.a
""",
    deps = [
        ":bash",
        ":extract_libtool",
        ":glibc",
    ],
)

# 8.38 GDBM - GNU Database Manager
lfs_chroot_extract_tarball(
    name = "extract_gdbm",
    tarball_name = "gdbm-1.24.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gdbm",
    cmd = """
set -euo pipefail
cd /sources/gdbm-1.24
./configure --prefix=/usr \
            --disable-static \
            --enable-libgdbm-compat
make -j$(nproc)
make install
""",
    deps = [
        ":bash",
        ":extract_gdbm",
        ":glibc",
    ],
)

# 8.39 Gperf - Perfect hash function generator
lfs_chroot_extract_tarball(
    name = "extract_gperf",
    tarball_name = "gperf-3.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gperf",
    cmd = """
set -euo pipefail
cd /sources/gperf-3.1
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.1
make -j$(nproc)
make install
""",
    deps = [
        ":bash",
        ":extract_gperf",
        ":glibc",
    ],
)

# 8.40 Expat - XML parser library
lfs_chroot_extract_tarball(
    name = "extract_expat",
    tarball_name = "expat-2.6.2.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "expat",
    cmd = """
set -euo pipefail
cd /sources/expat-2.6.2
./configure --prefix=/usr \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.6.2
make -j$(nproc)
make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.6.2
""",
    deps = [
        ":bash",
        ":extract_expat",
        ":glibc",
    ],
)

# 8.41 Inetutils - Network utilities
lfs_chroot_extract_tarball(
    name = "extract_inetutils",
    tarball_name = "inetutils-2.5.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "inetutils",
    cmd = """
set -euo pipefail
cd /sources/inetutils-2.5
./configure --prefix=/usr \
            --bindir=/usr/bin \
            --localstatedir=/var \
            --disable-logger \
            --disable-whois \
            --disable-rcp \
            --disable-rexec \
            --disable-rlogin \
            --disable-rsh \
            --disable-servers
make -j$(nproc)
make install
mv -v /usr/{,s}bin/ifconfig
""",
    deps = [
        ":bash",
        ":extract_inetutils",
        ":glibc",
    ],
)

# 8.42 Less - Text file viewer
lfs_chroot_extract_tarball(
    name = "extract_less",
    tarball_name = "less-661.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "less",
    cmd = """
set -euo pipefail
cd /sources/less-661
./configure --prefix=/usr --sysconfdir=/etc
make -j$(nproc)
make install
""",
    deps = [
        ":bash",
        ":extract_less",
        ":glibc",
        ":ncurses",
    ],
)

# 8.43 Perl - Practical Extraction and Report Language
lfs_chroot_extract_tarball(
    name = "extract_perl",
    tarball_name = "perl-5.40.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "perl",
    cmd = """
set -euo pipefail
cd /sources/perl-5.40.0
export BUILD_ZLIB=False
export BUILD_BZIP2=0
sh Configure -des \
             -D prefix=/usr \
             -D vendorprefix=/usr \
             -D privlib=/usr/lib/perl5/5.40/core_perl \
             -D archlib=/usr/lib/perl5/5.40/core_perl \
             -D sitelib=/usr/lib/perl5/5.40/site_perl \
             -D sitearch=/usr/lib/perl5/5.40/site_perl \
             -D vendorlib=/usr/lib/perl5/5.40/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.40/vendor_perl \
             -D man1dir=/usr/share/man/man1 \
             -D man3dir=/usr/share/man/man3 \
             -D pager="/usr/bin/less -isR" \
             -D useshrplib \
             -D usethreads
make -j$(nproc)
make install
unset BUILD_ZLIB BUILD_BZIP2
""",
    deps = [
        ":bash",
        ":extract_perl",
        ":gdbm",
        ":glibc",
    ],
)

# 8.44 XML::Parser - Perl module for parsing XML
lfs_chroot_extract_tarball(
    name = "extract_xml_parser",
    tarball_name = "XML-Parser-2.47.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "xml_parser",
    cmd = """
set -euo pipefail
cd /sources/XML-Parser-2.47
perl Makefile.PL
make
make install
""",
    deps = [
        ":expat",
        ":extract_xml_parser",
        ":perl",
    ],
)

# 8.45 Intltool - Internationalization tool
lfs_chroot_extract_tarball(
    name = "extract_intltool",
    tarball_name = "intltool-0.51.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "intltool",
    cmd = """
set -euo pipefail
cd /sources/intltool-0.51.0
sed -i 's:\\\\${:\\\\$\\{:' intltool-update.in
./configure --prefix=/usr
make
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
""",
    deps = [
        ":extract_intltool",
        ":perl",
        ":xml_parser",
    ],
)

# 8.46 Autoconf - Automatic configure script builder
lfs_chroot_extract_tarball(
    name = "extract_autoconf",
    tarball_name = "autoconf-2.72.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "autoconf",
    cmd = """
set -euo pipefail
cd /sources/autoconf-2.72
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":extract_autoconf",
        ":m4",
        ":perl",
    ],
)

# 8.47 Automake - Makefile generator
lfs_chroot_extract_tarball(
    name = "extract_automake",
    tarball_name = "automake-1.17.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "automake",
    cmd = """
set -euo pipefail
cd /sources/automake-1.17
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.17
make -j$(nproc)
make install
""",
    deps = [
        ":autoconf",
        ":extract_automake",
    ],
)

# 8.48 OpenSSL - SSL/TLS cryptography library
lfs_chroot_extract_tarball(
    name = "extract_openssl",
    tarball_name = "openssl-3.3.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "openssl",
    cmd = """
set -euo pipefail
cd /sources/openssl-3.3.1
./config --prefix=/usr \
         --openssldir=/etc/ssl \
         --libdir=lib \
         shared \
         zlib-dynamic
make
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.3.1
cp -vfr doc/* /usr/share/doc/openssl-3.3.1
""",
    deps = [
        ":extract_openssl",
        ":perl",
    ],
)

# 8.49 Kmod - Kernel module tools
lfs_chroot_extract_tarball(
    name = "extract_kmod",
    tarball_name = "kmod-33.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "kmod",
    cmd = """
set -euo pipefail
cd /sources/kmod-33
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --with-openssl \
            --with-xz \
            --with-zstd \
            --with-zlib \
            --disable-manpages
make
make install

for target in depmod insmod modinfo modprobe rmmod; do
  ln -sfv ../bin/kmod /usr/sbin/$target
  rm -fv /usr/bin/$target
done
""",
    deps = [
        ":extract_kmod",
        ":openssl",
        ":xz",
        ":zlib",
        ":zstd",
    ],
)

# 8.50 Libelf - ELF object file access library
lfs_chroot_extract_tarball(
    name = "extract_libelf",
    tarball_name = "elfutils-0.191.tar.bz2",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libelf",
    cmd = """
set -euo pipefail
cd /sources/elfutils-0.191
./configure --prefix=/usr \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
make
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
""",
    deps = [
        ":extract_libelf",
        ":glibc",
    ],
)

# 8.51 Libffi - Foreign Function Interface library
lfs_chroot_extract_tarball(
    name = "extract_libffi",
    tarball_name = "libffi-3.4.6.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libffi",
    cmd = """
set -euo pipefail
cd /sources/libffi-3.4.6
./configure --prefix=/usr \
            --disable-static \
            --with-gcc-arch=native
make
make install
""",
    deps = [
        ":extract_libffi",
        ":glibc",
    ],
)

# 8.52 Python - Programming language
lfs_chroot_extract_tarball(
    name = "extract_python",
    tarball_name = "Python-3.12.5.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "python",
    cmd = """
set -euo pipefail
cd /sources/Python-3.12.5
./configure --prefix=/usr \
            --enable-shared \
            --with-system-expat \
            --enable-optimizations
make
make install

cat > /etc/pip.conf << 'PIPEOF'
[global]
root-user-action = ignore
disable-pip-version-check = true
PIPEOF
""",
    deps = [
        ":expat",
        ":extract_python",
        ":libffi",
        ":openssl",
    ],
)

# 8.53 Flit-Core - Python build backend
lfs_chroot_extract_tarball(
    name = "extract_flit_core",
    tarball_name = "flit_core-3.9.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "flit_core",
    cmd = """
set -euo pipefail
cd /sources/flit_core-3.9.0
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist flit_core
""",
    deps = [
        ":extract_flit_core",
        ":python",
    ],
)

# 8.54 Wheel - Python wheel packaging
lfs_chroot_extract_tarball(
    name = "extract_wheel",
    tarball_name = "wheel-0.44.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "wheel",
    cmd = """
set -euo pipefail
cd /sources/wheel-0.44.0
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links=dist wheel
""",
    deps = [
        ":extract_wheel",
        ":flit_core",
    ],
)

# 8.55 Setuptools - Python package development
lfs_chroot_extract_tarball(
    name = "extract_setuptools",
    tarball_name = "setuptools-72.2.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "setuptools",
    cmd = """
set -euo pipefail
cd /sources/setuptools-72.2.0
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist setuptools
""",
    deps = [
        ":extract_setuptools",
        ":wheel",
    ],
)

# 8.56 Ninja - Small build system
lfs_chroot_extract_tarball(
    name = "extract_ninja",
    tarball_name = "ninja-1.12.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "ninja",
    cmd = """
set -euo pipefail
cd /sources/ninja-1.12.1
export NINJAJOBS=$(nproc)
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;' src/ninja.cc
python3 configure.py --bootstrap
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
""",
    deps = [
        ":extract_ninja",
        ":python",
    ],
)

# 8.57 Meson - Build system
lfs_chroot_extract_tarball(
    name = "extract_meson",
    tarball_name = "meson-1.5.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "meson",
    cmd = """
set -euo pipefail
cd /sources/meson-1.5.1
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
""",
    deps = [
        ":extract_meson",
        ":ninja",
        ":setuptools",
    ],
)

# 8.58 Coreutils - Core utilities
lfs_chroot_extract_tarball(
    name = "extract_coreutils",
    tarball_name = "coreutils-9.5.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "coreutils",
    cmd = """
set -euo pipefail
cd /sources/coreutils-9.5
patch -Np1 -i ../coreutils-9.5-i18n-2.patch
autoreconf -fiv
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr \
            --enable-no-install-program=kill,uptime
make
make install
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
""",
    deps = [
        ":acl",
        ":attr",
        ":bash",
        ":extract_coreutils",
        ":glibc",
        ":gmp",
        ":openssl",
    ],
)

# 8.59 Check - Unit testing framework
lfs_chroot_extract_tarball(
    name = "extract_check",
    tarball_name = "check-0.15.2.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "check",
    cmd = """
set -euo pipefail
cd /sources/check-0.15.2
./configure --prefix=/usr --disable-static
make
make docdir=/usr/share/doc/check-0.15.2 install
""",
    deps = [
        ":extract_check",
        ":glibc",
    ],
)

###############################################################################
# Phase 5: System Services (20 packages)
###############################################################################

# 8.60 Diffutils - Utilities for comparing files
lfs_chroot_extract_tarball(
    name = "extract_diffutils",
    tarball_name = "diffutils-3.10.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "diffutils",
    cmd = """
set -euo pipefail
cd /sources/diffutils-3.10
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":bash",
        ":extract_diffutils",
        ":glibc",
    ],
)

# 8.61 Gawk - GNU Awk
lfs_chroot_extract_tarball(
    name = "extract_gawk",
    tarball_name = "gawk-5.3.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gawk",
    cmd = """
set -euo pipefail
cd /sources/gawk-5.3.0
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
make
rm -f /usr/bin/gawk-5.3.0
make install
ln -sv gawk.1 /usr/share/man/man1/awk.1
mkdir -pv /usr/share/doc/gawk-5.3.0
cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-5.3.0
""",
    deps = [
        ":bash",
        ":extract_gawk",
        ":glibc",
    ],
)

# 8.62 Findutils - Directory traversal utilities
lfs_chroot_extract_tarball(
    name = "extract_findutils",
    tarball_name = "findutils-4.10.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "findutils",
    cmd = """
set -euo pipefail
cd /sources/findutils-4.10.0
./configure --prefix=/usr --localstatedir=/var/lib/locate
make
make install
""",
    deps = [
        ":bash",
        ":extract_findutils",
        ":glibc",
    ],
)

# 8.63 Groff - Document formatting system
lfs_chroot_extract_tarball(
    name = "extract_groff",
    tarball_name = "groff-1.23.0.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "groff",
    cmd = """
set -euo pipefail
cd /sources/groff-1.23.0
PAGE=letter ./configure --prefix=/usr
make
make install
""",
    deps = [
        ":bash",
        ":extract_groff",
        ":gcc",
        ":glibc",
    ],
)

# 8.64 GRUB - Bootloader
lfs_chroot_extract_tarball(
    name = "extract_grub",
    tarball_name = "grub-2.12.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "grub",
    cmd = """
set -euo pipefail
cd /sources/grub-2.12
unset {C,CPP,CXX,LD}FLAGS
echo depends bli part_gpt > grub-core/extra_deps.lst
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --disable-efiemu \
            --disable-werror
make
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
""",
    deps = [
        ":bash",
        ":extract_grub",
        ":glibc",
    ],
)

# 8.65 Gzip - Compression utility
lfs_chroot_extract_tarball(
    name = "extract_gzip",
    tarball_name = "gzip-1.13.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "gzip",
    cmd = """
set -euo pipefail
cd /sources/gzip-1.13
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":bash",
        ":extract_gzip",
        ":glibc",
    ],
)

# 8.66 IPRoute2 - Networking utilities
lfs_chroot_extract_tarball(
    name = "extract_iproute2",
    tarball_name = "iproute2-6.10.0.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "iproute2",
    cmd = """
set -euo pipefail
cd /sources/iproute2-6.10.0
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
make NETNS_RUN_DIR=/run/netns
make SBINDIR=/usr/sbin install
mkdir -pv /usr/share/doc/iproute2-6.10.0
cp -v COPYING README* /usr/share/doc/iproute2-6.10.0
""",
    deps = [
        ":bash",
        ":extract_iproute2",
        ":glibc",
        ":libelf",
    ],
)

# 8.67 Kbd - Keyboard utilities
lfs_chroot_extract_tarball(
    name = "extract_kbd",
    tarball_name = "kbd-2.6.4.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "kbd",
    cmd = """
set -euo pipefail
cd /sources/kbd-2.6.4
patch -Np1 -i ../kbd-2.6.4-backspace-1.patch
sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
./configure --prefix=/usr --disable-vlock
make
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.6.4
""",
    deps = [
        ":bash",
        ":extract_kbd",
        ":glibc",
    ],
)

# 8.68 Libpipeline - Pipeline manipulation library
lfs_chroot_extract_tarball(
    name = "extract_libpipeline",
    tarball_name = "libpipeline-1.5.7.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "libpipeline",
    cmd = """
set -euo pipefail
cd /sources/libpipeline-1.5.7
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":extract_libpipeline",
        ":glibc",
    ],
)

# 8.69 Make - Build automation tool
lfs_chroot_extract_tarball(
    name = "extract_make",
    tarball_name = "make-4.4.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "make",
    cmd = """
set -euo pipefail
cd /sources/make-4.4.1
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":bash",
        ":extract_make",
        ":glibc",
    ],
)

# 8.70 Patch - Patch application utility
lfs_chroot_extract_tarball(
    name = "extract_patch",
    tarball_name = "patch-2.7.6.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "patch",
    cmd = """
set -euo pipefail
cd /sources/patch-2.7.6
./configure --prefix=/usr
make
make install
""",
    deps = [
        ":bash",
        ":extract_patch",
        ":glibc",
    ],
)

# 8.71 Tar - Archiving utility
lfs_chroot_extract_tarball(
    name = "extract_tar",
    tarball_name = "tar-1.35.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "tar",
    cmd = """
set -euo pipefail
cd /sources/tar-1.35
FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr
make
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35
""",
    deps = [
        ":bash",
        ":extract_tar",
        ":glibc",
    ],
)

# 8.72 Texinfo - Documentation system
lfs_chroot_extract_tarball(
    name = "extract_texinfo",
    tarball_name = "texinfo-7.1.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "texinfo",
    cmd = """
set -euo pipefail
cd /sources/texinfo-7.1
./configure --prefix=/usr
make
make install
make TEXMF=/usr/share/texmf install-tex
""",
    deps = [
        ":bash",
        ":extract_texinfo",
        ":glibc",
        ":perl",
    ],
)

# 8.73 Vim - Text editor
lfs_chroot_extract_tarball(
    name = "extract_vim",
    tarball_name = "vim-9.1.0660.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "vim",
    cmd = """
set -euo pipefail
cd /sources/vim-9.1.0660
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr
make
make install
ln -sv vim /usr/bin/vi
for L in /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.0660
cat > /etc/vimrc << 'VIMEOF'
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
VIMEOF
""",
    deps = [
        ":bash",
        ":extract_vim",
        ":glibc",
        ":ncurses",
    ],
)

# 8.74 MarkupSafe - Python package
lfs_chroot_extract_tarball(
    name = "extract_markupsafe",
    tarball_name = "MarkupSafe-2.1.5.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "markupsafe",
    cmd = """
set -euo pipefail
cd /sources/MarkupSafe-2.1.5
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist Markupsafe
""",
    deps = [
        ":extract_markupsafe",
        ":python",
    ],
)

# 8.75 Jinja2 - Python templating engine
lfs_chroot_extract_tarball(
    name = "extract_jinja2",
    tarball_name = "jinja2-3.1.4.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "jinja2",
    cmd = """
set -euo pipefail
cd /sources/jinja2-3.1.4
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
pip3 install --no-index --no-user --find-links dist Jinja2
""",
    deps = [
        ":extract_jinja2",
        ":markupsafe",
    ],
)

# 8.76 Systemd - System and service manager (SKIPPED - sysvinit build)
# 8.77 D-Bus - Message bus system (SKIPPED - systemd dependency)

# 8.78 Man-DB - Manual page database
lfs_chroot_extract_tarball(
    name = "extract_man_db",
    tarball_name = "man-db-2.12.1.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "man_db",
    cmd = """
set -euo pipefail
cd /sources/man-db-2.12.1
./configure --prefix=/usr \
            --docdir=/usr/share/doc/man-db-2.12.1 \
            --sysconfdir=/etc \
            --disable-setuid \
            --enable-cache-owner=bin \
            --with-browser=/usr/bin/lynx \
            --with-vgrind=/usr/bin/vgrind \
            --with-grap=/usr/bin/grap
make
make install
""",
    deps = [
        ":extract_man_db",
        ":gdbm",
        ":groff",
        ":less",
        ":libpipeline",
    ],
)

# 8.79 Procps-ng - Process monitoring utilities
lfs_chroot_extract_tarball(
    name = "extract_procps_ng",
    tarball_name = "procps-ng-4.0.4.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "procps_ng",
    cmd = """
set -euo pipefail
cd /sources/procps-ng-4.0.4
./configure --prefix=/usr \
            --docdir=/usr/share/doc/procps-ng-4.0.4 \
            --disable-static \
            --disable-kill
make
make install
""",
    deps = [
        ":extract_procps_ng",
        ":glibc",
        ":ncurses",
    ],
)

###############################################################################
# Phase 6: Final Packages (3 packages)
###############################################################################

# 8.80 Util-linux - System utilities
lfs_chroot_extract_tarball(
    name = "extract_util_linux",
    tarball_name = "util-linux-2.40.2.tar.xz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "util_linux",
    cmd = """
set -euo pipefail
cd /sources/util-linux-2.40.2
./configure --bindir=/usr/bin \
            --libdir=/usr/lib \
            --runstatedir=/run \
            --sbindir=/usr/sbin \
            --disable-chfn-chsh \
            --disable-login \
            --disable-nologin \
            --disable-su \
            --disable-setpriv \
            --disable-runuser \
            --disable-pylibmount \
            --disable-static \
            --disable-liblastlog2 \
            --without-python \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.40.2
make
make install
""",
    deps = [
        ":extract_util_linux",
        ":glibc",
        ":libcap",
        ":ncurses",
    ],
)

# 8.81 E2fsprogs - Ext2/3/4 filesystem utilities
lfs_chroot_extract_tarball(
    name = "extract_e2fsprogs",
    tarball_name = "e2fsprogs-1.47.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "e2fsprogs",
    cmd = """
set -euo pipefail
cd /sources/e2fsprogs-1.47.1
mkdir -v build
cd build
../configure --prefix=/usr \
             --sysconfdir=/etc \
             --enable-elf-shlibs \
             --disable-libblkid \
             --disable-libuuid \
             --disable-uuidd \
             --disable-fsck
make
make install
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
""",
    deps = [
        ":extract_e2fsprogs",
        ":glibc",
        ":util_linux",
    ],
)

# 8.83 Sysklogd - System logging daemon
lfs_chroot_extract_tarball(
    name = "extract_sysklogd",
    tarball_name = "sysklogd-2.6.1.tar.gz",
    deps = [":stage_ch8_sources"],
)

lfs_chroot_step(
    name = "sysklogd",
    cmd = """
set -euo pipefail
cd /sources/sysklogd-2.6.1
./configure --prefix=/usr \
            --sysconfdir=/etc \
            --runstatedir=/run \
            --without-logger
make
make install
cat > /etc/syslog.conf << 'SYSLOGEOF'
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
SYSLOGEOF
""",
    deps = [
        ":extract_sysklogd",
        ":glibc",
    ],
)
