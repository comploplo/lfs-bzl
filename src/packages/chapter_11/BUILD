"""
Chapter 11: The End

Finalizes the LFS system with release identification files.
"""

load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# LFS Release Files
# --------------------------------------------------------------------------- #

lfs_script(
    name = "lfs_release_files",
    script = """
        # /etc/lfs-release - Simple version identifier
        echo "12.2" > /etc/lfs-release

        # /etc/lsb-release - Linux Standards Base compliance
        cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="12.2"
DISTRIB_CODENAME="lfs-bzl"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

        # /etc/os-release - systemd and desktop environment compatibility
        cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="12.2"
ID=lfs
PRETTY_NAME="Linux From Scratch 12.2"
VERSION_CODENAME="lfs-bzl"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
EOF
    """,
    deps = ["//packages/chapter_10"],
)

# --------------------------------------------------------------------------- #
# Chapter 11 Aggregate
# --------------------------------------------------------------------------- #

filegroup(
    name = "chapter_11",
    srcs = [":lfs_release_files"],
)
