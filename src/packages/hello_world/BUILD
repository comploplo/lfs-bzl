# 👋 Hello World Verification Tests
# Tests the LFS build infrastructure and validates each toolchain stage

load("//tools:lfs_build.bzl", "lfs_c_binary", "lfs_chroot_command", "lfs_package")

# 1️⃣ Basic host build (uses your system's GCC)
lfs_package(
    name = "hello",
    srcs = ["hello.c"],
    build_cmd = "gcc hello.c -o hello",
    install_cmd = "install -D hello $LFS/tools/bin/hello",
    # binary_name defaults to "hello" (target name), making this runnable
)

# 2️⃣ Cross-toolchain build (uses Chapter 5 cross-compiler @ $LFS/tools/bin)
# 🎯 This validates the minimal cross-toolchain built in Chapter 5
lfs_c_binary(
    name = "hello_cross",
    srcs = ["hello.c"],
    binary_name = "hello-cross",
    toolchain = "//packages/chapter_05:cross_toolchain",
    deps = ["//packages/chapter_05:libstdcpp"],
)

# 3️⃣ Temporary tools toolchain (Chapter 6 GCC Pass 2 @ $LFS/usr/bin)
# 🚀 NOTE: This toolchain is cross-compiled to run ON the LFS target (not the host!)
#    It cannot be validated with a simple host-side build. Validation will occur
#    in Chapter 7 when we enter the chroot environment and use these tools to
#    build the final system.
#
# The key difference:
#   - Ch 5 cross_toolchain: Runs on HOST, targets LFS (can run on host) ✅
#   - Ch 6 temp_tools_toolchain: Runs on LFS, targets LFS (needs chroot) 🔒
#
# Toolchain target: //packages/chapter_06:temp_tools_toolchain

# 4️⃣ Chroot run using the Chapter 7 base toolchain
# Copies hello.c into the sysroot then compiles and runs it inside the chroot
lfs_package(
    name = "stage_hello_in_sysroot",
    srcs = ["hello.c"],
    build_cmd = "true",
    install_cmd = "install -D \"$EXECROOT/packages/hello_world/hello.c\" $LFS/tmp/hello_world/hello.c",
    deps = ["//packages/chapter_07:chroot_toolchain_phase"],
)

lfs_chroot_command(
    name = "hello_chroot",
    chroot_helper = "//tools:lfs_chroot_helper_script",
    cmd = """
set -euo pipefail
cd /tmp/hello_world
$CC hello.c -o hello_chroot
./hello_chroot
""",
    lfs_sysroot = "//:lfs_sysroot_files",
    tags = [
        "manual",
        "requires-sudo",
    ],
    toolchain = "//packages/chapter_07:chroot_base_toolchain",
    visibility = ["//visibility:public"],
    deps = [
        ":stage_hello_in_sysroot",
        "//packages/chapter_07:chroot_toolchain_phase",
    ],
)
