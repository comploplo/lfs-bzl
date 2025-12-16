# 👋 Hello World Verification Tests
# Tests the LFS build infrastructure and validates each toolchain stage

load("//tools:lfs_macros.bzl", "lfs_c_binary")
load("//tools:lfs_package.bzl", "lfs_package")

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

# Compile and run hello.c inside chroot (Chapter 7 temporary tools)
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

# --------------------------------------------------------------------------- #
# 5️⃣ Final System toolchain validation (Chapter 8 GCC)
# --------------------------------------------------------------------------- #

# Validates the Chapter 8 final system toolchain by compiling and running code
# using the fully-built GCC compiler inside the chroot environment.
#
# This uses the native GCC built as part of Chapter 8, not the temporary
# cross-compiled tools from Chapter 6-7.
#
# Usage:
#   bazel build //packages/hello_world:hello_final
#
# Note: First run will build Chapter 8 dependencies. Subsequent runs are cached.
#
# For a quick validation of the Chapter 8 toolchain:
#   bazel build //packages/chapter_08:ch8_smoke_versions

lfs_package(
    name = "hello_final",
    build_cmd = """
        # Validate Chapter 8 GCC is available
        if ! command -v gcc &> /dev/null; then
            echo "" >&2
            echo "=========================================================" >&2
            echo "ERROR: GCC not found in PATH" >&2
            echo "=========================================================" >&2
            echo "" >&2
            echo "Chapter 8 toolchain is not built. Please build it first:" >&2
            echo "  bazel build //packages/chapter_08:gcc" >&2
            echo "" >&2
            echo "Or build all Chapter 8 packages:" >&2
            echo "  bazel build //packages/chapter_08:ch8_all" >&2
            echo "" >&2
            echo "For a quick validation after building:" >&2
            echo "  bazel build //packages/chapter_08:ch8_smoke_versions" >&2
            echo "" >&2
            exit 1
        fi

        # Verify GCC can actually compile (not just exist in PATH)
        echo 'int main(){return 0;}' > /tmp/gcc_check.c
        if ! gcc -o /tmp/gcc_check /tmp/gcc_check.c 2>/dev/null; then
            echo "" >&2
            echo "=========================================================" >&2
            echo "ERROR: GCC exists but cannot compile" >&2
            echo "=========================================================" >&2
            echo "" >&2
            echo "The toolchain may be incomplete. Try rebuilding:" >&2
            echo "  bazel build //packages/chapter_08:gcc" >&2
            echo "" >&2
            rm -f /tmp/gcc_check.c
            exit 1
        fi
        rm -f /tmp/gcc_check /tmp/gcc_check.c

        # Build hello_final (reduced verbosity - use hello_final_verbose for debugging)
        cat > /tmp/hello_final.c <<'EOF'
#include <stdio.h>

int main(void)
{
    printf("Hello from LFS Final System (Chapter 8)!\\n");
    printf("Built with native GCC from the complete LFS toolchain.\\n");
    return 0;
}
EOF
        gcc /tmp/hello_final.c -o /tmp/hello_final
        /tmp/hello_final
        rm -f /tmp/hello_final.c /tmp/hello_final
    """,
    configure_cmd = "true",
    create_runner = True,
    install_cmd = "true",
    phase = "chroot",
    visibility = ["//visibility:public"],
    deps = ["//packages/chapter_08:gcc"],
)

# Verbose version for debugging toolchain issues
# Usage: bazel build //packages/hello_world:hello_final_verbose
lfs_package(
    name = "hello_final_verbose",
    build_cmd = """
        # Same prerequisite validation as hello_final
        if ! command -v gcc &> /dev/null; then
            echo "ERROR: GCC not found. Build Chapter 8 first:" >&2
            echo "  bazel build //packages/chapter_08:gcc" >&2
            exit 1
        fi

        cat > /tmp/hello_final.c <<'EOF'
#include <stdio.h>

int main(void)
{
    printf("Hello from LFS Final System (Chapter 8)!\\n");
    printf("Built with native GCC from the complete LFS toolchain.\\n");
    return 0;
}
EOF
        echo "=== Compiling with verbose output ==="
        gcc -v /tmp/hello_final.c -o /tmp/hello_final
        echo ""
        echo "=== Running ==="
        /tmp/hello_final
        rm -f /tmp/hello_final.c /tmp/hello_final
    """,
    configure_cmd = "true",
    install_cmd = "true",
    phase = "chroot",
    tags = ["manual"],  # Only build when explicitly requested
    visibility = ["//visibility:public"],
    deps = ["//packages/chapter_08:gcc"],
)
