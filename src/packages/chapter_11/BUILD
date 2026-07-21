"""
Chapter 11: The End

Finalizes the LFS system with release identification files.
"""

load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//tools:lfs_script.bzl", "lfs_script")

package(default_visibility = ["//visibility:public"])

# --------------------------------------------------------------------------- #
# LFS Release Files
# --------------------------------------------------------------------------- #

lfs_script(
    name = "lfs_release_files",
    script = """
        # /etc/lfs-release - Simple version identifier
        echo "13.0-systemd" > /etc/lfs-release

        # /etc/lsb-release - Linux Standards Base compliance
        cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="13.0-systemd"
DISTRIB_CODENAME="lfs-bzl"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

        # /etc/os-release - systemd and desktop environment compatibility
        cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="13.0-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 13.0-systemd"
VERSION_CODENAME="lfs-bzl"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="stable"
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

# Primary boot path: a genuinely self-booting UEFI GPT disk. The LFS chroot
# builds all bootable content (kernel, initramfs, GRUB EFI binary); this step
# runs container-side (Debian tools, rootless, NO loop devices) and does only
# mechanical byte assembly of a GPT disk with fixed offsets.
# Output: sysroot/lfs-uefi.img
lfs_script(
    name = "create_bootable_disk",
    phase = "image",
    script = """
        set -euo pipefail
        ESP_MB=64
        # Fixed GPT layout in 512-byte sectors: ESP at 1MiB, root at 65MiB.
        ESP_START=2048
        ROOT_START=133120

        rm -f /lfs/lfs.img /lfs/lfs-uefi.img

        # Stage a clean copy of the sysroot on container-local disk first.
        # /lfs carries the worker's live bind mounts (/dev, /proc, /sys, /run,
        # /execroot, /tmp -> /build_tmp, the repo cache + external dir under
        # /Users) and mke2fs -d has no exclude mechanism, so populating
        # straight from /lfs would snapshot them all into the root image.
        # /tools (cross toolchain) and build/sources are build-time only.
        STAGE=/tmp/rootfs
        rm -rf "$STAGE"
        mkdir "$STAGE"
        tar -C /lfs \\
            --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run \\
            --exclude=./tmp --exclude=./execroot --exclude=./Users \\
            --exclude=./tools --exclude=./build --exclude=./sources \\
            --exclude=./lfs.img --exclude=./lfs-uefi.img \\
            --exclude=./.lfs_root_marker --exclude=./.fseventsd \\
            -cf - . | tar -C "$STAGE" -xf -
        mkdir -p "$STAGE"/{proc,sys,dev,run,tmp}
        chmod 1777 "$STAGE/tmp"

        # Size the root fs from what it must hold: +30% fs overhead/headroom.
        ROOT_MB=$(( $(du -sm "$STAGE" | cut -f1) * 13 / 10 + 256 ))
        TOTAL_MB=$((1 + ESP_MB + ROOT_MB + 1))

        rm -f /tmp/root.ext4
        mke2fs -q -t ext4 -L lfs-root -d "$STAGE" -N 0 -E root_owner=0:0 /tmp/root.ext4 ${ROOT_MB}M
        rm -rf "$STAGE"

        rm -f /tmp/esp.img
        truncate -s ${ESP_MB}M /tmp/esp.img
        mkfs.fat -F 32 -n EFI /tmp/esp.img
        mmd   -i /tmp/esp.img ::/EFI ::/EFI/BOOT
        case $(uname -m) in
          x86_64) efi_binary=BOOTX64.EFI ;;
          aarch64) efi_binary=BOOTAA64.EFI ;;
          *) echo "unsupported EFI fallback binary: $(uname -m)" >&2; exit 1 ;;
        esac
        mcopy -i /tmp/esp.img "/lfs/boot/EFI/BOOT/$efi_binary" "::/EFI/BOOT/$efi_binary"

        truncate -s ${TOTAL_MB}M /lfs/lfs-uefi.img
        sgdisk -Z /lfs/lfs-uefi.img
        sgdisk -n 1:${ESP_START}:+${ESP_MB}M -t 1:EF00 -c 1:EFI \\
               -n 2:${ROOT_START}:0          -t 2:8300 -c 2:lfs-root \\
               /lfs/lfs-uefi.img

        # Offsets are MiB-aligned (2048 sectors = 1MiB); bs=1M instead of
        # bs=512 avoids millions of tiny writes onto the virtiofs sysroot.
        dd if=/tmp/esp.img   of=/lfs/lfs-uefi.img bs=1M seek=$((ESP_START  / 2048)) conv=notrunc
        dd if=/tmp/root.ext4 of=/lfs/lfs-uefi.img bs=1M seek=$((ROOT_START / 2048)) conv=notrunc
        rm -f /tmp/root.ext4 /tmp/esp.img
        sync

        sgdisk -p /lfs/lfs-uefi.img
        ls -lh /lfs/lfs-uefi.img

        echo ""
        echo "=============================================="
        echo "Success! Self-booting UEFI disk at sysroot/lfs-uefi.img"
        echo ""
        echo "Boot with QEMU using the matching UEFI firmware for $(uname -m)."
        echo ""
        echo "Exit QEMU with: Ctrl-a x"
        echo "=============================================="
    """,
    deps = [
        ":chapter_11",
        "//packages/blfs",
        "//packages/chapter_10:efi_bootloader",
    ],
)

# Fast-iteration fallback boot: raw ext4 image booted via QEMU -kernel
# injection (no bootloader in the image). Kept for quick dev iteration.
# Output: sysroot/lfs.img
lfs_script(
    name = "create_disk_image",
    script = """
        set -e
        echo "=============================================="
        echo "LFS Disk Image Creator (fast-iteration fallback)"
        echo "=============================================="

        # Stale images from prior :bootable / :bootable_quick runs sit at the
        # chroot root and must not be ingested into the new image.
        rm -f /lfs.img /lfs-uefi.img

        # Stage a clean copy on container-local disk first (/tmp is a bind of
        # the container's /build_tmp overlay, outside the sysroot). The chroot
        # root has live bind mounts (/dev, /proc, /sys, /run, /execroot, the
        # repo cache + external dir under /Users) and mke2fs -d has no exclude
        # mechanism. /tools and build/sources are build-time only.
        STAGE=/tmp/rootfs
        rm -rf "$STAGE"
        mkdir "$STAGE"
        tar -C / \\
            --exclude=./proc --exclude=./sys --exclude=./dev --exclude=./run \\
            --exclude=./tmp --exclude=./execroot --exclude=./Users \\
            --exclude=./tools --exclude=./build --exclude=./sources \\
            --exclude=./.lfs_root_marker --exclude=./.fseventsd \\
            -cf - . | tar -C "$STAGE" -xf -
        mkdir -p "$STAGE"/{proc,sys,dev,run,tmp}
        chmod 1777 "$STAGE/tmp"

        echo "Creating 4GB disk image..."
        rm -f /tmp/lfs.img
        truncate -s 4G /tmp/lfs.img

        # Use mke2fs -d to create and populate in one step (no mount needed)
        echo "Creating ext4 filesystem and copying contents..."
        mke2fs -t ext4 -d "$STAGE" -L lfs-root /tmp/lfs.img \
            -E root_owner=0:0 \
            -N 0 \
            2>&1 | grep -v "^Copying files"
        rm -rf "$STAGE"

        mv /tmp/lfs.img /lfs.img

        echo ""
        echo "=============================================="
        echo "Success! Disk image created at sysroot/lfs.img"
        ls -lh /lfs.img
        echo ""
        echo "Boot with QEMU using the matching system emulator for $(uname -m)."
        echo ""
        echo "Exit QEMU with: Ctrl-a x"
        echo "=============================================="
    """,
    deps = [
        ":chapter_11",
        "//packages/chapter_08:e2fsprogs",
    ],
)

# Build everything including the self-booting UEFI disk (primary boot path)
filegroup(
    name = "bootable",
    srcs = [
        ":chapter_11",
        ":create_bootable_disk",
    ],
)

# Build everything including the raw ext4 image (fast-iteration fallback boot)
filegroup(
    name = "bootable_quick",
    srcs = [
        ":chapter_11",
        ":create_disk_image",
    ],
)

# --------------------------------------------------------------------------- #
# Boot Smoke Test
# --------------------------------------------------------------------------- #
#
# Boots sysroot/lfs-uefi.img in QEMU (-snapshot, image untouched) and fails
# unless it reaches a root shell with DHCP networking. The image is not a
# tracked Bazel output, so this runs unsandboxed/uncached ("local"/"external")
# against whatever :bootable last produced. Tagged "manual" to keep a
# multi-minute VM boot out of blanket `bazel test //...` runs:
#   bazel test //packages/chapter_11:boot_test

sh_test(
    name = "boot_test",
    size = "large",
    srcs = ["//tools/scripts:boot_test.sh"],
    tags = [
        "external",
        "local",
        "manual",
    ],
)
