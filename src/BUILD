package(default_visibility = ["//visibility:public"])

filegroup(
    name = "lfs_sysroot_files",
    # Expand sysroot contents explicitly so Bazel tracks files instead of a raw directory.
    srcs = glob(
        ["sysroot/**"],
        allow_empty = True,
        exclude_directories = 1,
    ),
    visibility = ["//visibility:public"],
)
