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
# Uses rootless Podman worker (no sudo required).
filegroup(
    name = "bootstrap_ch7",
    srcs = ["//packages/chapter_07:chroot_cleanup"],
    visibility = ["//visibility:public"],
)
