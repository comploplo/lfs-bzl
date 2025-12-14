package(default_visibility = ["//visibility:public"])

filegroup(
    name = "lfs_sysroot_files",
    # Expand sysroot contents explicitly so Bazel tracks files instead of a raw directory.
    srcs = glob(
        [
            "sysroot/bin/**",
            "sysroot/boot/**",
            "sysroot/dev/**",
            "sysroot/etc/**",
            "sysroot/home/**",
            "sysroot/lib/**",
            "sysroot/lib64/**",
            "sysroot/media/**",
            "sysroot/mnt/**",
            "sysroot/opt/**",
            "sysroot/proc/**",
            "sysroot/run/**",
            "sysroot/sbin/**",
            "sysroot/sources/**",
            "sysroot/srv/**",
            "sysroot/sys/**",
            "sysroot/tmp/**",
            "sysroot/tools/**",
            "sysroot/usr/**",
            "sysroot/var/**",
        ],
        allow_empty = True,
        exclude_directories = 1,
    ),
    visibility = ["//visibility:public"],
)
