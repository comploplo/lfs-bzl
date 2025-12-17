"""
Chapter 5 cross-toolchain scaffolding.

Targets use Bazel primitives plus the LFS build macros. Commands mirror the LFS
book but are staged for refinement once we run real builds.
"""

load("//tools:lfs_macros.bzl", "lfs_autotools")
load("//tools:lfs_package.bzl", "lfs_package")
load("//tools:lfs_toolchain.bzl", "lfs_toolchain")

package(default_visibility = ["//visibility:public"])

# Shared bundle of archives for convenience.
filegroup(
    name = "toolchain_archives",
    srcs = [
        "@binutils_src//file",
        "@gcc_src//file",
        "@glibc_src//file",
        "@gmp_src//file",
        "@linux_headers_src//file",
        "@mpc_src//file",
        "@mpfr_src//file",
    ],
)

# Linux API headers
# This step doesn't follow the autotools install pattern; it installs by copying
# headers into $LFS/usr after generating them.
lfs_package(
    name = "linux_headers",
    srcs = ["@linux_headers_src//file"],
    build_cmd = "make mrproper && make headers",
    configure_cmd = "true",
    install_cmd = "find usr/include -name '.*' -delete && cp -rv usr/include $LFS/usr",
    phase = "ch5",
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
    ],
    phase = "ch5",
    prefix = "/tools",
    destdir = "$LFS",
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
    build_cmd = "( cd build && make -j$(nproc) all-gcc && make -j$(nproc) all-target-libgcc )",
    configure_cmd = """
        for d in ../gmp-*/ ../mpfr-*/ ../mpc-*/ ; do
          [ -d "$d" ] || continue
          base="$(basename "$d")"
          pkg="${base%%-*}"
          rm -rf "$pkg"
          mv "$d" "$pkg"
        done
        ( mkdir -p build && cd build && ../configure \\
          --target=$LFS_TGT \\
          --prefix=/tools \\
          --with-sysroot=$LFS \\
          --with-newlib \\
          --without-headers \\
          --enable-initfini-array \\
          --enable-languages=c,c++ \\
          --disable-nls \\
          --disable-shared \\
          --disable-multilib \\
          --disable-decimal-float \\
          --disable-threads \\
          --disable-libatomic \\
          --disable-libgomp \\
          --disable-libquadmath \\
          --disable-libssp \\
          --disable-libvtv \\
          --disable-libstdcxx-pch \\
          --disable-bootstrap \\
          --enable-default-pie \\
          --enable-default-ssp )
    """,
    install_cmd = """
        ( cd build && DESTDIR=$LFS make install-gcc && DESTDIR=$LFS make install-target-libgcc )
        # Provide libgcc_s for glibc build; stage1 gcc builds only libgcc.a.
        ln -sf libgcc.a $LFS/tools/lib/gcc/$LFS_TGT/14.2.0/libgcc_s.a
    """,
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
        ( mkdir -p build && cd build && ../configure \\
          --prefix=/usr \\
          --host=$LFS_TGT \\
          --build=$(../scripts/config.guess) \\
          --enable-kernel=4.19 \\
          --with-headers=$LFS/usr/include \\
          --disable-werror \\
          libc_cv_slibdir=/usr/lib )
    """,
    install_cmd = """
        ( cd build && DESTDIR=$LFS make install )
        case $(uname -m) in
          x86_64)
            mkdir -p $LFS/lib64
            ln -sf ../usr/lib/ld-linux-x86-64.so.2 $LFS/lib64/ld-linux-x86-64.so.2
          ;;
          *)
            mkdir -p $LFS/lib
            ln -sf usr/lib/ld-linux.so.2 $LFS/lib/ld-linux.so.2
          ;;
        esac
    """,
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
            --disable-multilib \\
            --disable-nls \\
            --disable-libstdcxx-threads \\
            --disable-libstdcxx-pch \\
            --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/14.2.0 )
    """,
    install_cmd = "( cd build && DESTDIR=$LFS make install )",
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
        "CC": "x86_64-lfs-linux-gnu-gcc",
        "CXX": "x86_64-lfs-linux-gnu-g++",
        "LFS_TGT": "x86_64-lfs-linux-gnu",
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
