package(default_visibility = ["//visibility:public"])

# Aggregate targets for convenience.

# Chroot smoke check (versions) and hello chroot runner.
filegroup(
    name = "smoke_check",
    srcs = [
        "//packages/chapter_07:chroot_smoke_versions",
        "//packages/hello_world:hello_chroot",
    ],
    visibility = ["//visibility:public"],
)

# One-shot build of everything needed to finish Chapter 7.
#
# Note: Chapter 7 steps require sudo and are tagged accordingly.
filegroup(
    name = "bootstrap_ch7",
    srcs = ["//packages/chapter_07:chroot_finalize"],
    visibility = ["//visibility:public"],
)

# Toolchain provider labels for quick reference.
filegroup(
    name = "toolchains",
    srcs = [
        "//packages/chapter_05:cross_toolchain",
        "//packages/chapter_06:temp_tools_toolchain",
        "//packages/chapter_07:chroot_base_toolchain",
    ],
)
