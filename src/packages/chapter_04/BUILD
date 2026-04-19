"""
Chapter 4: LFS directory skeleton setup.

Creates the initial directory structure in the sysroot inside the
Podman container.
"""

load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

lfs_script(
    name = "lfs_root_skeleton",
    phase = "ch5",
    script = """
        mkdir -p $LFS/{tools,build,sources}
        mkdir -p $LFS/{bin,boot,dev,home,lib,lib64,mnt,opt,proc,root,run,sbin,srv,sys,tmp,var}
        mkdir -p $LFS/usr/{bin,lib,sbin}
        mkdir -p $LFS/usr/local/{bin,lib,sbin}
        touch $LFS/.lfs_root_marker
    """,
)

filegroup(
    name = "lfs_root",
    srcs = [":lfs_root_skeleton"],
)
