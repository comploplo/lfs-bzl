# Hello World Verification Test
# Tests the basic LFS build infrastructure

load("//tools:lfs_build.bzl", "lfs_c_binary", "lfs_package")

lfs_package(
    name = "hello",
    srcs = ["hello.c"],
    build_cmd = "gcc hello.c -o hello",
    install_cmd = "install -D hello $LFS/tools/bin/hello",
    # binary_name defaults to "hello" (target name), making this runnable
)

# Cross-toolchain build of the same hello program (uses Chapter 5 toolchain).
lfs_c_binary(
    name = "hello_cross",
    srcs = ["hello.c"],
    binary_name = "hello-cross",
    toolchain = "//packages/chapter_05:cross_toolchain",
    deps = ["//packages/chapter_05:libstdcpp"],
)
