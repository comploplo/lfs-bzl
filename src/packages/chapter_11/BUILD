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

# --------------------------------------------------------------------------- #
# Bootable Disk Image Creation
# --------------------------------------------------------------------------- #

# Create disk image inside the LFS chroot using e2fsprogs
# Output: sysroot/lfs.img
lfs_script(
    name = "create_disk_image",
    script = """
        set -e
        echo "=============================================="
        echo "LFS Disk Image Creator"
        echo "=============================================="

        # Create 4GB sparse image file
        echo "Creating 4GB disk image at /lfs.img..."
        truncate -s 4G /lfs.img

        # Use mke2fs -d to create and populate in one step (no mount needed)
        echo "Creating ext4 filesystem and copying contents..."
        mke2fs -t ext4 -d / -L lfs-root /lfs.img \
            -E root_owner=0:0 \
            -N 0 \
            2>&1 | grep -v "^Copying files"

        echo ""
        echo "=============================================="
        echo "Success! Disk image created at sysroot/lfs.img"
        ls -lh /lfs.img
        echo ""
        echo "Boot with QEMU:"
        echo "  qemu-system-x86_64 \\\\"
        echo "    -m 2G -enable-kvm \\\\"
        echo "    -kernel sysroot/boot/vmlinuz-6.10.5-lfs-12.2 \\\\"
        echo "    -append 'root=/dev/sda rw console=ttyS0 init=/sbin/init' \\\\"
        echo "    -drive file=sysroot/lfs.img,format=raw \\\\"
        echo "    -nographic"
        echo ""
        echo "Exit QEMU with: Ctrl-a x"
        echo "=============================================="
    """,
    deps = [
        ":chapter_11",
        "//packages/chapter_08:e2fsprogs",
    ],
)

# Build everything including disk image
filegroup(
    name = "bootable",
    srcs = [
        ":chapter_11",
        ":create_disk_image",
    ],
)
