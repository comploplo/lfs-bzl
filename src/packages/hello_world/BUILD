# 👋 Hello World Verification Tests
# Tests the LFS build infrastructure and validates each toolchain stage

load("//tools:lfs_build.bzl", "lfs_c_binary", "lfs_package")

# 1️⃣ Basic host build (uses your system's GCC)
lfs_package(
    name = "hello",
    srcs = ["hello.c"],
    build_cmd = "gcc hello.c -o hello",
    install_cmd = "install -D hello $LFS/tools/bin/hello",
    phase = "ch5",
    # binary_name defaults to "hello" (target name), making this runnable
)

# 2️⃣ Cross-toolchain build (uses Chapter 5 cross-compiler @ $LFS/tools/bin)
# 🎯 This validates the minimal cross-toolchain built in Chapter 5
lfs_c_binary(
    name = "hello_cross",
    srcs = ["hello.c"],
    binary_name = "hello-cross",
    phase = "ch5",
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

# --------------------------------------------------------------------------- #
# 4️⃣ Chroot toolchain validation (Podman worker - no sudo required)
# --------------------------------------------------------------------------- #

# Validates the Chapter 7 base toolchain by compiling and running code inside
# the chroot environment using the rootless Podman worker.
#
# Usage:
#   bazel build //packages/hello_world:hello_chroot

# Stage hello.c source into chroot
lfs_package(
    name = "stage_hello_in_sysroot",
    build_cmd = "true",
    configure_cmd = "true",
    install_cmd = """
        mkdir -p /tmp/hello_world
        cat > /tmp/hello_world/hello.c <<'EOF'
#include <stdio.h>

int main(void)
{
    printf("Hello from LFS Bazel Bootstrap (Podman worker)!\\n");
    printf("Chroot toolchain is working correctly.\\n");
    return 0;
}
EOF
    """,
    phase = "chroot",
    visibility = ["//visibility:public"],
    deps = ["//packages/chapter_07:chroot_prepare"],
)

# Compile and run hello.c inside chroot
lfs_package(
    name = "hello_chroot",
    build_cmd = """
        cd /tmp/hello_world
        gcc hello.c -o hello_chroot
        ./hello_chroot
    """,
    configure_cmd = "true",
    install_cmd = "true",
    phase = "chroot",
    visibility = ["//visibility:public"],
    deps = [
        ":stage_hello_in_sysroot",
        "//packages/chapter_07:chroot_prepare",
    ],
)
