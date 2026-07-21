"""
Chapter 5 cross-toolchain.

Targets use Bazel primitives plus the LFS build macros to build the LFS
cross-toolchain (binutils/gcc pass 1, glibc, libstdc++) per the book.
"""

load("//tools:lfs_macros.bzl", "lfs_autotools")
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

# Linux API headers
# This step doesn't follow the autotools install pattern; it installs by copying
# headers into $LFS/usr after generating them.
lfs_package(
    name = "linux_headers",
    srcs = ["@linux_headers_src//file"],
    build_cmd = "make mrproper && make headers",
    configure_cmd = "true",
    install_cmd = "find usr/include -type f ! -name '*.h' -delete && mkdir -p $LFS/usr && cp -rv usr/include $LFS/usr",
    phase = "ch5",
    # Root the chapter on the ch4 skeleton so a fresh sysroot always gets the
    # merged-usr symlinks + directory tree before anything installs into it.
    deps = ["//packages/chapter_04:lfs_root_skeleton"],
)

# Binutils Pass 1 (configure + make + install via helper)
lfs_autotools(
    name = "binutils_pass1",
    srcs = ["@binutils_src//file"],
    configure_flags = [
        "--with-sysroot=$LFS",
        "--target=$LFS_TGT",
        "--disable-nls",
        "--enable-gprofng=no",
        "--disable-werror",
        "--enable-new-dtags",
        "--enable-default-hash-style=gnu",
    ],
    phase = "ch5",
    prefix = "/tools",
    destdir = "$LFS",
    # Root the chapter on the ch4 skeleton (see linux_headers).
    deps = ["//packages/chapter_04:lfs_root_skeleton"],
)

# GCC Pass 1 (with bundled gmp/mpfr/mpc)
lfs_package(
    name = "gcc_pass1",
    srcs = [
        "@gcc_src//file",
        "@gmp_src//file",
        "@mpc_src//file",
        "@mpfr_src//file",
    ],
    build_cmd = "( cd build && make -j$(nproc) )",
    configure_cmd = """
        for d in ../gmp-*/ ../mpfr-*/ ../mpc-*/ ; do
          [ -d "$d" ] || continue
          base="$(basename "$d")"
          pkg="${base%%-*}"
          rm -rf "$pkg"
          mv "$d" "$pkg"
        done
        # Key on LFS_TGT (target arch) not $(uname -m): build host may be aarch64.
        # Both arches default their lp64 multilib OS dir to lib64; point it at
        # lib so runtime libs land in /usr/lib (merged-usr, no lib64 on arm).
        case ${LFS_TGT%%-*} in
          x86_64)
            sed -e '/m64=/s/lib64/lib/' -i.orig gcc/config/i386/t-linux64
          ;;
          aarch64)
            sed -e '/lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
          ;;
        esac
        ( mkdir -p build && cd build && ../configure \\
          --target=$LFS_TGT \\
          --prefix=/tools \\
          --with-glibc-version=2.43 \\
          --with-sysroot=$LFS \\
          --with-newlib \\
          --without-headers \\
          --enable-default-pie \\
          --enable-default-ssp \\
          --disable-nls \\
          --disable-shared \\
          --disable-multilib \\
          --disable-threads \\
          --disable-libatomic \\
          --disable-libgomp \\
          --disable-libquadmath \\
          --disable-libssp \\
          --disable-libvtv \\
          --disable-libstdcxx \\
          --enable-languages=c,c++ )
    """,
    install_cmd = "( cd build && DESTDIR=$LFS make install )",
    phase = "ch5",
    deps = [
        ":binutils_pass1",
        ":linux_headers",
    ],
)

# Glibc
lfs_package(
    name = "glibc",
    srcs = ["@glibc_src//file"],
    build_cmd = "( cd build && make -j$(nproc) )",
    configure_cmd = """
        # Key on LFS_TGT (target arch) not $(uname -m): build host may be aarch64.
        case ${LFS_TGT%%-*} in
          i?86)
            ln -sfv ld-linux.so.2 $LFS/lib/ld-lsb.so.3
          ;;
          x86_64)
            mkdir -p $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64
            ln -sfv ../lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-lsb-x86-64.so.3
          ;;
        esac
        ( mkdir -p build && cd build && \\
          echo "rootsbindir=/usr/sbin" > configparms && \\
          ../configure \\
          --prefix=/usr \\
          --host=$LFS_TGT \\
          --build=$(../scripts/config.guess) \\
          --disable-nscd \\
          --enable-kernel=5.4 \\
          --with-headers=$LFS/usr/include \\
          libc_cv_slibdir=/usr/lib )
    """,
    install_cmd = """
        ( cd build && DESTDIR=$LFS make install )
        # Fix a hardcoded path in ldd (book: chapter05/glibc.html).
        sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
        # Sanity-check the cross toolchain per the book: the program must be
        # linked against the dynamic loader under /lib.
        echo 'int main(){}' | $LFS/tools/bin/$LFS_TGT-gcc -x c - -o a.out
        $LFS/tools/bin/$LFS_TGT-readelf -l a.out | grep ': /lib' \\
          || { echo "toolchain sanity check failed" >&2; exit 1; }
        rm -f a.out
        # Regenerate gcc's fixed headers now that glibc is installed.
        # mkheaders has hardcoded paths from --prefix=/tools, so symlink.
        ln -sfn $LFS/tools /tools
        $LFS/tools/libexec/gcc/$LFS_TGT/15.2.0/install-tools/mkheaders
        # gcc_pass1 was built with --without-headers, so its limits.h is
        # just glimits.h (bare definitions, MB_LEN_MAX=1, no PATH_MAX).
        # A proper limits.h chains to system headers via syslimits.h.
        # Wrap both copies with the limitx.h preamble and limity.h footer
        # so the cross-compiler picks up glibc's limits (PATH_MAX, etc.).
        _gcc_dir=$LFS/tools/lib/gcc/$LFS_TGT/15.2.0
        for d in include include-fixed; do
          _f="$_gcc_dir/$d/limits.h"
          [ -f "$_f" ] || continue
          mv "$_f" "$_f.bare"
          {
            cat <<'LIMITX'
#ifndef _GCC_LIMITS_H_
#define _GCC_LIMITS_H_
#ifndef _LIBC_LIMITS_H_
#include "syslimits.h"
#endif
LIMITX
            cat "$_f.bare"
            cat <<'LIMITY'
#else /* not _GCC_LIMITS_H_ */
#ifdef _GCC_NEXT_LIMITS_H
#include_next <limits.h>
#endif
#endif /* not _GCC_LIMITS_H_ */
LIMITY
          } > "$_f"
          rm "$_f.bare"
        done
    """,
    patches = ["@glibc_fhs_patch//file"],
    phase = "ch5",
    deps = [
        ":gcc_pass1",
        ":linux_headers",
    ],
)

# Libstdc++ (from GCC sources) - Build only the C++ standard library
lfs_package(
    name = "libstdcpp",
    srcs = [
        "@gcc_src//file",
    ],
    build_cmd = "( cd build && make -j$(nproc) )",
    configure_cmd = """
        ( mkdir -p build && cd build && \\
          ../libstdc++-v3/configure \\
            --host=$LFS_TGT \\
            --build=$(../config.guess) \\
            --prefix=/usr \\
            --libdir=/usr/lib \\
            --disable-multilib \\
            --disable-nls \\
            --disable-libstdcxx-pch \\
            --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0 )
    """,
    install_cmd = """
        ( cd build && DESTDIR=$LFS make install )
        # The .la files are harmful for cross-compilation (book: gcc-libstdc++.html).
        rm -fv $LFS/usr/lib{,64}/lib{stdc++{,exp,fs},supc++}.la
    """,
    phase = "ch5",
    deps = [
        ":glibc",
    ],
)

# Toolchain provider to hand to later chapters.
lfs_toolchain(
    name = "cross_toolchain",
    bin_path = "$LFS/tools/bin",
    env = {
        "CC": "$LFS_TGT-gcc",
        "CXX": "$LFS_TGT-g++",
    },
    deps = [
        ":binutils_pass1",
        ":gcc_pass1",
        ":glibc",
        ":libstdcpp",
        ":linux_headers",
    ],
)

filegroup(
    name = "chapter_05",
    srcs = [
        ":binutils_pass1",
        ":gcc_pass1",
        ":glibc",
        ":libstdcpp",
        ":linux_headers",
    ],
)
