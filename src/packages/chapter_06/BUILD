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
        "--build=$(../build-aux/config.guess)",
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
          ../configure --prefix=$LFS/tools AWK=gawk
          make -C include
          make -C progs tic
          install progs/tic $LFS/tools/bin
        popd

        # Configure for cross-compilation
        #
        # NOTE: The book uses --with-cxx-shared here, but the Chapter 5
        # cross-toolchain is sufficient for C builds only; it cannot reliably
        # link ncurses' C++ bindings (it lacks a proper shared unwind/runtime).
        # We substitute --without-cxx-binding; later toolchains (Chapter 7+)
        # can enable them if desired.
        # --with-build-cc=gcc: build the run-during-build helpers (make_keys,
        # make_hash) with the native Debian gcc, not the cross-compiler. Our
        # build container's glibc (2.36) is OLDER than the just-built LFS glibc
        # (2.43), so cross-CC helpers fail at runtime ("GLIBC_2.38 not found").
        # Must be set at configure time; `make BUILD_CC=gcc` does not propagate
        # through ncurses' recursive make. Target libs still use $LFS_TGT-gcc.
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
            --disable-stripping \\
            --with-build-cc=gcc \\
            AWK=gawk
    """,
    install_cmd = """
        make DESTDIR=$LFS install
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
        "gl_cv_func_strcasecmp_works=y",
        "--build=$(../build-aux/config.guess)",
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
        "--build=$(../build-aux/config.guess)",
        "--disable-static",
        "--docdir=/usr/share/doc/xz-5.8.2",
    ],
    phase = "ch6",
    prefix = "/usr",
    toolchain = "//packages/chapter_05:cross_toolchain",
    destdir = "$LFS",
)

# Sed - Stream editor
lfs_package(
    name = "sed",
    srcs = ["@sed_src//file"],
    configure_cmd = """
        mkdir -p build && cd build && ../configure --prefix=/usr \\
            --host=$LFS_TGT \\
            --build=$(../build-aux/config.guess)
    """,
    build_cmd = "make -C build -j$(nproc)",
    install_cmd = "make -C build DESTDIR=$LFS install",
    phase = "ch6",
    toolchain = "//packages/chapter_05:cross_toolchain",
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
            --without-bash-malloc
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
        "--build=$(../build-aux/config.guess)",
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
        "--build=$(../build-aux/config.guess)",
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
        "--build=$(../build-aux/config.guess)",
    ],
    env = {"FORCE_UNSAFE_CONFIGURE": "1"},
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
            --enable-no-install-program=kill,uptime
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
        # Phase 1: Build host version for FILE_COMPILE (use container's native gcc)
        mkdir build
        pushd build
          CC=gcc ../configure --disable-bzlib \\
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
        "--build=$(../build-aux/config.guess)",
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
        "--build=$(../build-aux/config.guess)",
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
        sed '6031s/$add_dir//' -i ltmain.sh
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

        # Fix lib64 -> lib. Key on LFS_TGT (target arch) not $(uname -m): the
        # build host may differ. Both arches default their lp64 multilib OS
        # dir to lib64; without the sed libgcc/libstdc++ install to /usr/lib64,
        # which ld.so never searches (merged-usr layout has no lib64 on arm).
        case ${LFS_TGT%%-*} in
          x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
          ;;
          aarch64)
            sed -e '/lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
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
        "CC": "$LFS_TGT-gcc",
        "CXX": "$LFS_TGT-g++",
        "LD_LIBRARY_PATH": "$LFS/usr/lib",
    },
    deps = [
        ":gcc_pass2",  # Last package in chapter 6
    ],
)

###############################################################################
# Convenience Target
###############################################################################

# Build all temporary tools
filegroup(
    name = "chapter_06",
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
