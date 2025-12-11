"""
Chapter 5 cross-toolchain scaffolding.

Targets use Bazel primitives plus the LFS build macros. Commands mirror the LFS
book but are staged for refinement once we run real builds.
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:lfs_build.bzl", "lfs_c_binary", "lfs_configure_make", "lfs_package", "lfs_toolchain")

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
lfs_package(
    name = "linux_headers",
    srcs = ["@linux_headers_src//file"],
    build_cmd = "make mrproper && make headers",
    install_cmd = "find usr/include -name '.*' -delete && cp -rv usr/include $LFS/usr",
)

# Binutils Pass 1 (configure + make + install via helper)
lfs_configure_make(
    name = "binutils_pass1",
    srcs = ["@binutils_src//file"],
    configure_flags = [
        "--with-sysroot=$LFS",
        "--target=$LFS_TGT",
        "--disable-nls",
        "--enable-gprofng=no",
        "--disable-werror",
    ],
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
    install_cmd = "( cd build && DESTDIR=$LFS make install-gcc && DESTDIR=$LFS make install-target-libgcc )",
    deps = [
        ":binutils_pass1",
        ":linux_headers",
    ],
)

# Glibc
lfs_configure_make(
    name = "glibc",
    srcs = ["@glibc_src//file"],
    configure_flags = [
        "--prefix=/usr",
        "--host=$LFS_TGT",
        "--build=$(../scripts/config.guess)",
        "--enable-kernel=4.19",
        "--with-headers=$LFS/usr/include",
        "--disable-werror",
        "libc_cv_slibdir=/usr/lib",
    ],
    destdir = "$LFS",
    deps = [
        ":gcc_pass1",
        ":linux_headers",
    ],
)

# Libstdc++ (from GCC sources)
lfs_package(
    name = "libstdcpp",
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
        ( mkdir -p build && cd build && ../libstdc++-v3/configure \\
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
)

lfs_c_binary(
    name = "toolchain_smoke",
    srcs = ["toolchain_smoke.c"],
    binary_name = "toolchain-smoke",
    toolchain = ":cross_toolchain",
)

sh_test(
    name = "toolchain_smoke_test",
    srcs = ["toolchain_smoke_test.sh"],
    args = ["$(location :toolchain_smoke)"],
    data = [":toolchain_smoke"],
)
