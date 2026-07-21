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
        mkdir -p $LFS/{boot,dev,etc,home,mnt,opt,proc,root,run,srv,sys,tmp,var}
        mkdir -p $LFS/usr/{bin,lib,sbin}
        mkdir -p $LFS/usr/local/{bin,lib,sbin}
        # Merged-usr: bin/lib/sbin are symlinks into /usr, per book chapter 4.
        # -snf keeps this rerun-safe when the links already exist.
        for i in bin lib sbin; do
            ln -snfv usr/$i $LFS/$i
        done
        # Key on LFS_TGT (target arch), not $(uname -m): LFS_TGT names the arch
        # the sysroot is being built for (x86_64 or aarch64), the host may differ.
        case ${LFS_TGT%%-*} in
            x86_64) mkdir -pv $LFS/lib64 ;;
        esac
        touch $LFS/.lfs_root_marker
    """,
)
