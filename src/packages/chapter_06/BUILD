"""
Chapter 6: Cross-Compiling Temporary Tools

Builds temporary tools using the cross-toolchain from Chapter 5.
All packages install to $LFS/usr and use the cross-compiler.

This chapter builds 17 packages in dependency order:
- Tier 1: Foundation utilities (M4, Ncurses, Diffutils, Gzip, Xz, Sed)
- Tier 2: Core utilities (Bash, Grep, Patch, Tar)
- Tier 3: Advanced utilities (Coreutils, File, Findutils, Gawk, Make)
- Tier 4: Toolchain rebuild (Binutils Pass 2, GCC Pass 2)
"""

load("//tools:lfs_macros.bzl", "lfs_autotools", "lfs_configure_make")
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

###############################################################################
# TIER 1: Foundation Packages (No Dependencies)
###############################################################################

# M4 - Macro processor
lfs_configure_make(
    name = "m4",
    srcs = ["@m4_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Ncurses - Terminal handling library
# Complex multi-step build: needs host tic utility before cross-compilation
lfs_package(
    name = "ncurses",
    srcs = ["@ncurses_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        # Build host tic utility first (needed for cross-compilation)
        mkdir build
        pushd build
          ../configure AWK=gawk
          make -C include
          make -C progs tic
        popd

        # Configure for cross-compilation
        #
        # NOTE: The Chapter 5 cross-toolchain is sufficient for C builds, but it
        # cannot reliably link ncurses' C++ bindings (it lacks a proper shared
        # unwind/runtime). We disable the C++ bindings here; later toolchains
        # (Chapter 7+) can enable them if desired.
        ./configure --prefix=/usr \\
            --host=$LFS_TGT \\
            --build=$(./config.guess) \\
            --mandir=/usr/share/man \\
            --with-manpage-format=normal \\
            --with-shared \\
            --without-normal \\
            --without-cxx-binding \\
            --without-debug \\
            --without-ada \\
            --disable-stripping
    """,
    install_cmd = """
        make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
        ln -sfv libncursesw.so $LFS/usr/lib/libncurses.so
        sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $LFS/usr/include/curses.h
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
)

# Diffutils - File comparison utilities
lfs_autotools(
    name = "diffutils",
    srcs = ["@diffutils_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(./build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Gzip - Compression utility
lfs_autotools(
    name = "gzip",
    srcs = ["@gzip_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Xz - Compression utility
lfs_configure_make(
    name = "xz",
    srcs = ["@xz_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
        "--disable-static",
        "--docdir=/usr/share/doc/xz-5.6.2",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Sed - Stream editor
lfs_configure_make(
    name = "sed",
    srcs = ["@sed_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(./build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

###############################################################################
# TIER 2: Core Utilities (Minimal Dependencies)
###############################################################################

# Bash - Shell (depends on Ncurses)
lfs_package(
    name = "bash",
    srcs = ["@bash_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --build=$(sh support/config.guess) \\
            --host=$LFS_TGT \\
            --without-bash-malloc \\
            bash_cv_strtold_broken=no
    """,
    install_cmd = """
        make DESTDIR=$LFS install
        mkdir -p $LFS/bin
        ln -sfv bash $LFS/bin/sh
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
    deps = [":ncurses"],
)

# Grep - Text search utility
lfs_configure_make(
    name = "grep",
    srcs = ["@grep_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(./build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Patch - Patch utility
lfs_configure_make(
    name = "patch",
    srcs = ["@patch_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Tar - Archive utility
lfs_configure_make(
    name = "tar",
    srcs = ["@tar_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

###############################################################################
# TIER 3: Advanced Utilities
###############################################################################

# Coreutils - Core system utilities
# Needs post-install moves (chroot to /usr/sbin)
lfs_package(
    name = "coreutils",
    srcs = ["@coreutils_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        ./configure --prefix=/usr \\
            --host=$LFS_TGT \\
            --build=$(build-aux/config.guess) \\
            --enable-install-program=hostname \\
            --enable-no-install-program=kill,uptime \\
            gl_cv_macro_MB_CUR_MAX_good=y
    """,
    install_cmd = """
        make DESTDIR=$LFS install
        # Move chroot to sbin
        mv -v $LFS/usr/bin/chroot $LFS/usr/sbin
        mkdir -pv $LFS/usr/share/man/man8
        mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
        sed -i 's/"1"/"8"/' $LFS/usr/share/man/man8/chroot.8
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
)

# File - File type detection
# Requires host build for FILE_COMPILE
lfs_package(
    name = "file",
    srcs = ["@file_src//file"],
    build_cmd = "make FILE_COMPILE=$(pwd)/build/src/file",
    configure_cmd = """
        # Phase 1: Build host version for FILE_COMPILE
        mkdir build
        pushd build
          ../configure --disable-bzlib \\
              --disable-libseccomp \\
              --disable-xzlib \\
              --disable-zlib
          make
        popd

        # Phase 2: Cross-compile
        ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    """,
    install_cmd = """
        make DESTDIR=$LFS install
        rm -v $LFS/usr/lib/libmagic.la
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
)

# Findutils - File finding utilities
lfs_configure_make(
    name = "findutils",
    srcs = ["@findutils_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
        "--localstatedir=/var/lib/locate",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Gawk - Text processing
# Requires sed pre-step to remove extras
# NOTE: --without-mpfr avoids libtool .la file issues when MPFR is installed in sysroot
lfs_package(
    name = "gawk",
    srcs = ["@gawk_src//file"],
    build_cmd = "make -j$(nproc)",
    configure_cmd = """
        sed -i 's/extras//' Makefile.in
        ./configure --prefix=/usr \\
            --host=$LFS_TGT \\
            --build=$(build-aux/config.guess) \\
            --without-mpfr
    """,
    install_cmd = "make DESTDIR=$LFS install",
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
)

# Make - Build automation
lfs_configure_make(
    name = "make",
    srcs = ["@make_src//file"],
    configure_flags = [
        "--host=$LFS_TGT",
        "--build=$(build-aux/config.guess)",
        "--without-guile",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

###############################################################################
# TIER 4: Toolchain Rebuild
###############################################################################

# Binutils Pass 2 - Rebuild with all utilities available
# CRITICAL: Depends on all prior utilities for stable environment
lfs_package(
    name = "binutils_pass2",
    srcs = ["@binutils_src//file"],
    build_cmd = "( cd build && make -j$(nproc) )",
    configure_cmd = """
        sed '6031s/$$add_dir//' -i ltmain.sh
        ( mkdir -v build && cd build && ../configure \\
            --prefix=/usr \\
            --build=$(../config.guess) \\
            --host=$LFS_TGT \\
            --disable-nls \\
            --enable-shared \\
            --enable-gprofng=no \\
            --disable-werror \\
            --enable-64-bit-bfd \\
            --enable-new-dtags \\
            --enable-default-hash-style=gnu )
    """,
    install_cmd = """
        ( cd build && make DESTDIR=$LFS install )
        rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
    deps = [
        ":bash",
        ":coreutils",
        ":diffutils",
        ":file",
        ":findutils",
        ":gawk",
        ":grep",
        ":gzip",
        ":m4",
        ":make",
        ":ncurses",
        ":patch",
        ":sed",
        ":tar",
        ":xz",
    ],
)

# GCC Pass 2 - Full compiler with libstdc++
# Enables POSIX threads and builds full compiler
lfs_package(
    name = "gcc_pass2",
    srcs = [
        "@gcc_src//file",
        "@gmp_src//file",
        "@mpc_src//file",
        "@mpfr_src//file",
    ],
    build_cmd = "( cd build && make -j$(nproc) )",
    configure_cmd = """
        # Extract and rename bundled libraries
        for d in ../gmp-*/ ../mpfr-*/ ../mpc-*/ ; do
          [ -d "$d" ] || continue
          base="$(basename "$d")"
          pkg="${base%%-*}"
          rm -rf "$pkg"
          mv "$d" "$pkg"
        done

        # Fix lib64 -> lib on x86_64
        case $(uname -m) in
          x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
          ;;
        esac

        # Enable POSIX threads support
        sed '/thread_header =/s/@.*@/gthr-posix.h/' \\
            -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in

        # Out-of-tree build
        ( mkdir -v build && cd build && ../configure \\
            --build=$(../config.guess) \\
            --host=$LFS_TGT \\
            --target=$LFS_TGT \\
            LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \\
            --prefix=/usr \\
            --with-build-sysroot=$LFS \\
            --enable-default-pie \\
            --enable-default-ssp \\
            --disable-nls \\
            --disable-multilib \\
            --disable-libatomic \\
            --disable-libgomp \\
            --disable-libquadmath \\
            --disable-libsanitizer \\
            --disable-libssp \\
            --disable-libvtv \\
            --enable-languages=c,c++ )
    """,
    install_cmd = """
        ( cd build && make DESTDIR=$LFS install )
        ln -sfv gcc $LFS/usr/bin/cc
    """,
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
    deps = [":binutils_pass2"],
)

###############################################################################
# Toolchain Definition (For Chapter 7+ Chroot Builds)
###############################################################################

# 🚀 Temporary tools toolchain for Chapter 7+ (chroot environment)
# Uses GCC Pass 2 and Binutils Pass 2 built in this chapter
#
# ⚠️ IMPORTANT: This toolchain runs ON the LFS target, not the host!
#   - Binaries are linked against $LFS/usr/lib/libc.so (LFS glibc)
#   - Cannot execute on host system
#   - Requires chroot environment (Chapter 7) to use
#   - Will be consumed by lfs_chroot rule (not yet implemented)
#
# This target exists now to:
#   1. Document the toolchain we've built
#   2. Be ready for Chapter 7 chroot implementation
#   3. Serve as a dependency marker for what Chapter 6 provides
lfs_toolchain(
    name = "temp_tools_toolchain",
    bin_path = "$LFS/usr/bin",
    env = {
        "CC": "x86_64-lfs-linux-gnu-gcc",
        "CXX": "x86_64-lfs-linux-gnu-g++",
        "LFS_TGT": "x86_64-lfs-linux-gnu",
        "LD_LIBRARY_PATH": "$LFS/usr/lib",
    },
    deps = [
        ":all_temp_tools",
    ],
)

###############################################################################
# Convenience Target
###############################################################################

# Build all temporary tools
filegroup(
    name = "all_temp_tools",
    srcs = [
        ":bash",
        ":binutils_pass2",
        ":coreutils",
        ":diffutils",
        ":file",
        ":findutils",
        ":gawk",
        ":gcc_pass2",
        ":grep",
        ":gzip",
        ":m4",
        ":make",
        ":ncurses",
        ":patch",
        ":sed",
        ":tar",
        ":xz",
    ],
)
